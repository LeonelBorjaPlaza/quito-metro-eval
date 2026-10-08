# Item 6, second inference route: MDE under conformal inference (Chernozhukov, Wuthrich and Zhu),
# from pre-period data only. Run from road_safety/ after 02_spatial.R: Rscript code/04b_power_conformal.R
#
# Why: with donors beyond 2 km of the line, in-space placebos give at most 17 donors (parish
# polygons), so their smallest attainable p-value 1/(J+1) is above 0.05 for every pool (04_power.R).
# Conformal inference permutes time, not donors: its smallest attainable p-value is 1/T
# (T = training + evaluation months), whatever J is, so it also works with the approved pool A (J = 5).
#
# Method, per design (treated area x donor pool x outcome x weights x statistic; P1 only, monthly,
# because quarters give T <= 11 and a floor of 1/9 or worse):
# 1. The same fake openings, injections and draws as 04_power.R (P1: 9 fake openings, July 2022 to
#    March 2023, 9 months each; with a January 2022 start, 3 fake openings, January to March 2023). P2 is not simulated: its single placement would have 20 evaluation
#    months out of 35, and with more than half the series in the evaluation window a statistic built
#    on absolute residuals cannot detect a level shift (code review pass 2, CRITICAL 1).
# 2. Each unit's series is divided by its training mean. Under the null of no effect the model is fitted
#    on all T months: "did" = treated minus the donor mean, with an intercept; "sc" = synthdid-style
#    synthetic control weights (synthdid:::sc.weight.fw, intercept, ridge zeta = H^(1/4) x noise level,
#    no sparsification), fitted on all T.
# 3. Residuals u_t and two statistics over the evaluation months: "mean_abs" = mean |u_t| (the default
#    in Chernozhukov, Wuthrich and Zhu) and "abs_mean" = |mean u_t| (aimed at level shifts); p = share of
#    the T cyclic time shifts of u with a statistic at least as large. Smallest attainable p = 1/T.
# 4. Power, size gate and MDE labels as in 04_power.R. The fake effect at delta = 0 uses weights fitted
#    on the training months only.
# The simulation is likely pessimistic for the real P1 test: fake openings give T = 27 to 35 (21 to 23
# with a 2022 start), while the real P1 panel has T = 44 (32 with a 2022 start), so the real test has a
# finer p-value grid and a smaller evaluation share of the series.
# Seeds: each design is seeded by its position in a fixed canonical grid (default pools, or pool B),
# not by its position in the run, so a design gets the same draws whichever pools are run.
# With RS_OPENINGS=all (candidate designs, Leonel 2026-09-27) the 9-month fake window is placed at every
# position inside the panel (15 placements with the 2022 start, T = 23 each), training on the other
# months, before and after the window; seeds then come from a third canonical grid (SEED + 30000).
source("code/helpers.R")
suppressPackageStartupMessages(library(synthdid))
# Options (defaults reproduce the committed output/power/conformal_* files):
#   RS_POOLS     comma-separated pool names, from donor_sets and donor_sets_b (code/power_units.R)
#   RS_PRE_START first pre-period month, for example 2022-01-01 (see code/power_units.R)
#   RS_TAG       subfolder of output/power/ for the results of a non-default run
#   RS_OPENINGS  "forward" (default: fake openings after a minimum training period) or "all"
#   RS_TREATED, RS_OUTCOMES  comma-separated treated areas and outcomes (defaults: the three pooled
#                areas; all_crashes, injury_or_fatal, pedestrian)
out <- if (nzchar(Sys.getenv("RS_TAG"))) file.path("output/power", Sys.getenv("RS_TAG")) else "output/power"
if (nzchar(Sys.getenv("RS_MAX_DESIGNS"))) out <- file.path(tempdir(), "power_timing_test")  # timing tests
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# Fixed before any run (same values as 04_power.R).
SEED <- 20260925L
R_DRAWS <- 10L
DELTAS <- c(-0.5, -0.4, -0.3, -0.25, -0.2, -0.15, -0.1, -0.05, 0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5)
ALPHAS <- c(0.05, 0.10)
N_CORES <- as.integer(Sys.getenv("RS_CORES", "8"))
source("code/power_units.R")
# A non-default run (other pools or another start) must write to its own subfolder.
OPEN_MODE <- if (nzchar(Sys.getenv("RS_OPENINGS"))) Sys.getenv("RS_OPENINGS") else "forward"
env_list <- function(v, default) if (nzchar(Sys.getenv(v))) strsplit(Sys.getenv(v), ",")[[1]] else default
TREATED_RUN <- env_list("RS_TREATED", c("pooled_500m", "pooled_1km", "corridor_500m"))
OUTCOMES_RUN <- env_list("RS_OUTCOMES", c("all_crashes", "injury_or_fatal", "pedestrian"))
OUTCOMES_ALL <- c("all_crashes", "injury_or_fatal", "pedestrian", "urban_street_all", "urban_street_injury",
                  "urban_street_nms_all", "urban_street_nms_injury")
stopifnot(nzchar(Sys.getenv("RS_TAG")) || (!nzchar(Sys.getenv("RS_POOLS")) && RUN_START == PRE_START &&
            OPEN_MODE == "forward" && !nzchar(Sys.getenv("RS_TREATED")) && !nzchar(Sys.getenv("RS_OUTCOMES")) &&
            !nzchar(Sys.getenv("RS_DROP_MONTHS"))),
          format(RUN_START) %in% c("2021-01-01", "2022-01-01"), OPEN_MODE %in% c("forward", "all"),
          all(TREATED_RUN %in% c("pooled_500m", "pooled_1km", "corridor_500m")), all(OUTCOMES_RUN %in% OUTCOMES_ALL))

# Fake openings: 9-month fake P1 windows ending by November 2023, with at least 18 training months
# for the 2021 start (July 2022 to March 2023, as before) or 12 for a 2022 start (January to March 2023).
MIN_TRAIN <- if (RUN_START == PRE_START) 18L else 12L  # by the start, not the panel length, so left-out months do not change it
windows <- list(P1 = list(opens = if (OPEN_MODE == "all") 1:(length(months) - 9L + 1L) else (MIN_TRAIN + 1L):(length(months) - 9L + 1L),
                          H = 9L))
stopifnot(length(windows$P1$opens) >= 1L)
all_sets <- c(donor_sets, donor_sets_b, donor_sets_c, donor_sets_g, donor_sets_d)
pools_run <- if (nzchar(Sys.getenv("RS_POOLS"))) strsplit(Sys.getenv("RS_POOLS"), ",")[[1]] else names(donor_sets)
stopifnot(all(pools_run %in% names(all_sets)))

inject <- function(y, delta) {
  if (delta < 0) rbinom(length(y), y, 1 + delta) else if (delta > 0) y + rpois(length(y), delta * y) else y
}
# Weights on donors (rows 1..n-1) for the treated (row n), fitted on the columns in `cols`.
weights_of <- function(Y, cols, variant, H) {
  n <- nrow(Y)
  if (variant == "did") return(rep(1 / (n - 1L), n - 1L))
  noise <- sd(apply(Y[-n, cols, drop = FALSE], 1, diff))
  zeta <- H^(1 / 4) * noise  # same rule for the training fit and the all-T fit (H = evaluation months)
  synthdid:::sc.weight.fw(t(Y[, cols, drop = FALSE]), zeta = zeta, intercept = TRUE,
                          min.decrease = 1e-5 * noise, max.iter = 10000)$lambda
}
gap_of <- function(Y, w) Y[nrow(Y), ] - colSums(w * Y[-nrow(Y), , drop = FALSE])
conformal_p <- function(Y, post, variant) {
  Tn <- ncol(Y)
  stopifnot(length(post) < Tn / 2)
  u <- gap_of(Y, weights_of(Y, seq_len(Tn), variant, length(post)))
  u <- u - mean(u)
  shifted <- lapply(0:(Tn - 1L), function(j) u[((post - 1L + j) %% Tn) + 1L])
  S1 <- vapply(shifted, function(x) mean(abs(x)), 0)
  S2 <- vapply(shifted, function(x) abs(mean(x)), 0)
  c(mean_abs = mean(S1 >= S1[1] - 1e-12), abs_mean = mean(S2 >= S2[1] - 1e-12))
}

run_design <- function(i) {
  g <- designs[i]
  set.seed(g$seed)
  C_full <- count_matrix(treated_sets[[g$treated]], all_sets[[g$pool]], g$outcome, "month")
  w <- windows[[g$window]]
  res <- list()
  for (k in w$opens) {
    # "forward": training = the months before the window, panel cut after it; "all": the whole panel,
    # training = every month outside the window.
    cols <- if (OPEN_MODE == "all") seq_len(ncol(C_full)) else seq_len(k - 1L + w$H)
    post <- k:(k + w$H - 1L)
    train <- setdiff(seq_along(cols), post)
    C <- C_full[, cols, drop = FALSE]
    base <- rowMeans(C[, train, drop = FALSE])
    keep <- base > 0
    if (!keep[nrow(C)] || sum(keep) < 2L) next
    C <- C[keep, , drop = FALSE]; base <- base[keep]
    w_pre <- weights_of(C / base, train, g$variant, w$H)
    for (delta in DELTAS) for (r in seq_len(if (delta == 0) 1L else R_DRAWS)) {
      Ci <- C
      Ci[nrow(C), post] <- inject(C[nrow(C), post], delta)
      Y <- Ci / base
      gp <- gap_of(Y, w_pre)
      pv <- conformal_p(Y, post, g$variant)
      res[[length(res) + 1L]] <- data.table(fake_open = k, T = length(cols), delta = delta, draw = r,
                                            statistic = names(pv), p = unname(pv),
                                            effect = mean(gp[post]) - mean(gp[train]),
                                            donors_used = nrow(C) - 1L)
    }
  }
  cbind(g, fake_openings = length(w$opens), rbindlist(res))
}

designs <- CJ(treated = TREATED_RUN, pool = pools_run, outcome = OUTCOMES_RUN, variant = c("did", "sc"),
              window = "P1", sorted = FALSE)
# The gradient "pool" has a single unit (the outer ring): synthetic-control weights would equal DID's.
designs <- designs[!(pool %in% c(names(donor_sets_g), names(donor_sets_d)) & variant == "sc")]  # one-unit pools
# The outer ring (1 to 2 km from a station) is the gradient's control only for the 1 km catchments.
stopifnot(!any(designs$pool %in% names(donor_sets_g)) || all(designs[pool %in% names(donor_sets_g), treated] == "pooled_1km"))
designs[, J := vapply(pool, function(p) uniqueN(all_sets[[p]]$unit), 0L)]
# Canonical grids: the default design grid (unchanged, so default seeds are SEED + 10000 + row) and the
# same grid over pool B.
canon_grid <- function(pools) CJ(treated = c("pooled_500m", "pooled_1km", "corridor_500m"), pool = pools,
                                 outcome = c("all_crashes", "injury_or_fatal", "pedestrian"), variant = c("did", "sc"),
                                 window = "P1", sorted = FALSE)
dkey <- function(d) paste(d$treated, d$pool, d$outcome, d$variant, d$window)
canon_a <- dkey(canon_grid(names(donor_sets))); canon_b <- dkey(canon_grid(names(donor_sets_b)))
# canon_c follows names(all_sets); a pool added later must be appended to a new grid, or the candidate
# seeds of every later pool shift.
canon_c <- dkey(CJ(treated = c("pooled_500m", "pooled_1km", "corridor_500m"), pool = names(c(donor_sets, donor_sets_b, donor_sets_c, donor_sets_g)),
                   outcome = OUTCOMES_ALL, variant = c("did", "sc"), window = "P1", sorted = FALSE))
# Forward runs of the candidate pools and outcomes (outside the default and pool B grids) use SEED + 50000.
# The amendment's pooled comparator (donor_sets_d) has its own grid: SEED + 60000 (all placements) or
# SEED + 61000 (forward), so the committed candidate seeds do not move.
canon_d <- dkey(CJ(treated = c("pooled_500m", "pooled_1km", "corridor_500m"), pool = names(donor_sets_d),
                   outcome = OUTCOMES_ALL, variant = c("did", "sc"), window = "P1", sorted = FALSE))
designs[, seed := if (OPEN_MODE == "all") fifelse(pool %in% names(donor_sets_d), SEED + 60000L + match(dkey(.SD), canon_d),
                                                  SEED + 30000L + match(dkey(.SD), canon_c)) else
          fcase(pool %in% names(donor_sets_d), SEED + 61000L + match(dkey(.SD), canon_d),
                pool %in% names(donor_sets) & dkey(.SD) %in% canon_a, SEED + 10000L + match(dkey(.SD), canon_a),
                pool %in% names(donor_sets_b) & dkey(.SD) %in% canon_b, SEED + 20000L + match(dkey(.SD), canon_b),
                default = SEED + 50000L + match(dkey(.SD), canon_c))]
stopifnot(!anyNA(designs$seed), !anyDuplicated(designs$seed))
todo <- seq_len(nrow(designs))
if (nzchar(Sys.getenv("RS_MAX_DESIGNS"))) todo <- head(todo, as.integer(Sys.getenv("RS_MAX_DESIGNS")))  # timing tests only
cat("Conformal designs:", length(todo), "\n")
t0 <- Sys.time()
runs <- parallel::mclapply(todo, run_design, mc.cores = N_CORES, mc.preschedule = FALSE)
failed <- which(!vapply(runs, is.data.table, TRUE))
if (length(failed)) stop("Designs failed in parallel workers: ", paste(todo[failed], collapse = ", "))
sims <- rbindlist(runs)
stopifnot(uniqueN(sims[, .(treated, pool, outcome, variant, window)]) == length(todo))
keys <- c("treated", "pool", "outcome", "variant", "statistic", "window", "J")
cat("Simulation time:", format(round(Sys.time() - t0, 1)), "\n")

curves <- sims[, .(power_05 = mean(p <= 0.05), power_10 = mean(p <= 0.10), runs = .N,
                   fake_openings = fake_openings[1], openings_run = uniqueN(fake_open), T_min = min(T),
                   donors_used_min = min(donors_used)), by = c(keys, "delta")]
save_csv(curves, file.path(out, "conformal_power_curves.csv"))
mde <- function(delta, power, sign) {
  x <- data.table(delta, power)[sign * delta > 0][order(abs(delta))]
  ok <- rev(cumprod(rev(x$power >= 0.8))) == 1
  if (!any(ok)) NA_real_ else abs(x$delta[which(ok)[1]])
}
size_fails <- function(null_rej, n_open, alpha) if (n_open == 1L) null_rej > 0 else null_rej > max(alpha, 1 / n_open)
label_mde <- function(m, attainable, size_fail) {
  fifelse(!attainable, "not attainable", fifelse(size_fail, "size fails", fifelse(is.na(m), "> 50", as.character(round(100 * m)))))
}
tab <- curves[, .(T_min = T_min[1], smallest_attainable_p_worst_case = round(1 / T_min[1], 4),
                  fake_openings = fake_openings[1], openings_run = min(openings_run), donors_used_min = min(donors_used_min),
                  null_rejection_05 = power_05[delta == 0], null_rejection_10 = power_10[delta == 0],
                  m_dec_05 = mde(delta, power_05, -1), m_inc_05 = mde(delta, power_05, 1),
                  m_dec_10 = mde(delta, power_10, -1), m_inc_10 = mde(delta, power_10, 1)), by = keys]
tab[, `:=`(sf05 = mapply(size_fails, null_rejection_05, fake_openings, 0.05),
           sf10 = mapply(size_fails, null_rejection_10, fake_openings, 0.10))]
tab[, `:=`(mde_decrease_05_pct = label_mde(m_dec_05, smallest_attainable_p_worst_case <= 0.05, sf05),
           mde_increase_05_pct = label_mde(m_inc_05, smallest_attainable_p_worst_case <= 0.05, sf05),
           mde_decrease_10_pct = label_mde(m_dec_10, smallest_attainable_p_worst_case <= 0.10, sf10),
           mde_increase_10_pct = label_mde(m_inc_10, smallest_attainable_p_worst_case <= 0.10, sf10))]
tab[, c("m_dec_05", "m_inc_05", "m_dec_10", "m_inc_10", "sf05", "sf10") := NULL]
fake <- sims[delta == 0 & statistic == "mean_abs", .(fake_effect_mean_pct = round(100 * mean(effect), 1), fake_effect_min_pct = round(100 * min(effect), 1),
                           fake_effect_max_pct = round(100 * max(effect), 1)), by = setdiff(keys, "statistic")]
tab <- merge(tab, fake, by = setdiff(keys, "statistic"))
tab[, note := fcase(pool %in% names(donor_sets_c), "candidate: composite donors (Leonel 2026-09-27; not approved)",
                    pool %in% names(donor_sets_g), "candidate: gradient, conformal route (Leonel 2026-09-27; not approved)",
                    pool %in% names(donor_sets_d), "amendment 1 main comparator: distant parishes pooled (not approved)",
                    pool %in% names(donor_sets_b), "pool B (Leonel 2026-09-27; plan not yet approved)",
                    pool != "A_urban_parishes_beyond_2km", "earlier option pool", default = "")]
tab[openings_run < fake_openings, note := paste0(note, fifelse(note == "", "", "; "), "some fake openings skipped (zero training mean)")]
setorder(tab, window, treated, pool, outcome, variant, statistic)
save_csv(tab, file.path(out, "conformal_mde_table.csv"))
save_csv(sims[delta == 0, .(treated, pool, outcome, variant, statistic, window, J, fake_open, T,
                            fake_effect_pct = round(100 * effect, 1), p)],
         file.path(out, "conformal_placebo_in_time_null.csv"))
writeLines(c(capture.output(sessionInfo()), paste("seed", SEED), paste("cores", N_CORES),
             paste("pre-period start", format(months[1])), if (OPEN_MODE != "forward") paste("openings mode", OPEN_MODE),
             if (nzchar(Sys.getenv("RS_DROP_MONTHS"))) paste("months left out", Sys.getenv("RS_DROP_MONTHS")),
             paste("fake openings", paste(format(months[windows$P1$opens]), collapse = " "))),
           file.path(out, "conformal_session_info.txt"))
print(tab[, .(treated, pool = substr(pool, 1, 2), outcome, variant, statistic, J,
              dec05 = mde_decrease_05_pct, inc05 = mde_increase_05_pct, dec10 = mde_decrease_10_pct,
              inc10 = mde_increase_10_pct, null10 = null_rejection_10, fake = fake_effect_mean_pct)])
