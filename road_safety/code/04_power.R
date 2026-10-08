# Item 6: minimum detectable effects (MDE) from pre-period data only.
# Run from road_safety/ after 02_spatial.R: Rscript code/04_power.R  (about 5 to 10 minutes on 8 cores)
# Reads crashes only through load_pre(): January 2021 to November 2023. No post-opening value enters.
#
# Method, per design (treated unit x comparison pool x time unit x outcome x estimator x window):
# 1. Fake openings inside the pre-period. P1 (9 months): fake openings July 2022 to March 2023,
#    each with at least 18 training months (quarterly: 3 fake openings, at least 6 training quarters).
#    P2 (20 months): a single placement, training January 2021 to March 2022 (quarterly: 5 training
#    quarters and 6 post quarters, since the P2 quarters run March 2025 to August 2026).
# 2. Inject a proportional effect into the treated unit's fake-post counts: binomial thinning for
#    decreases, added Poisson draws for increases; R_DRAWS draws per effect and fake opening.
# 3. Estimate with SDID (synthdid, each unit's series divided by its training mean) or a Poisson
#    model with unit and period fixed effects (fixest::fepois). Statistic: |effect| divided by the
#    unit's pre-period fit error (SDID: SD of the training gap; Poisson: SD of the training log ratio
#    of observed to fitted counts).
# 4. Rank-based two-sided p-value against in-space placebos (each donor as fake treated, fitted on the
#    other donors): p = (1 + #placebos at least as extreme) / (J + 1). Smallest attainable p = 1/(J+1).
# 5. Power = share of fake openings x draws with p <= alpha. MDE = smallest effect on the grid from
#    which power stays at or above 80 percent, for decreases and increases separately. An MDE is
#    reported only if the design passes a size gate at delta = 0 (see size_fails) and 1/(J+1) <= alpha.
# P2 is also checked with a circular block bootstrap (blocks of 3 months) of each unit's gap to the
# equal-weight donor mean, as in congestion/Scripts/Congestion/03_preperiod_power.R, with and
# without the pre-period linear trend of the gap.
# Donor pools come from the GeoQuito parish polygons (code/power_units.R). Pool A is the approved
# rule; O1 to O3 and the no-BRT variants are options for Leonel, not approved.
source("code/helpers.R")
suppressPackageStartupMessages({ library(synthdid); library(fixest) })
out <- "output/power"
# Timing tests (RS_MAX_DESIGNS set) write to a temporary folder, never over the full tables.
if (nzchar(Sys.getenv("RS_MAX_DESIGNS"))) out <- file.path(tempdir(), "power_timing_test")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# Fixed before any run.
SEED <- 20260925L
R_DRAWS <- 10L
BOOT_DRAWS <- 2000L
DELTAS <- c(-0.5, -0.4, -0.3, -0.25, -0.2, -0.15, -0.1, -0.05, 0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5)
ALPHAS <- c(0.05, 0.10)
N_CORES <- as.integer(Sys.getenv("RS_CORES", "8"))

source("code/power_units.R")
stopifnot(RUN_START == PRE_START)  # the in-space runs use the full pre-period only
# Pool A candidates: urban parishes whose polygon lies at least 1.5 km from the line (members of pool A
# and those within 500 m of qualifying), with the polygon distance, pre-period volume, the donor
# screen and the BRT flags (no crash rows).
screen_pass <- function(d) {
  s <- d[, .(mean = .N / length(months), months_with_crash = uniqueN(t_month)), by = parish_code]
  s[, passes_screen := mean >= MIN_DONOR_MEAN & 1 - months_with_crash / length(months) <= MAX_DONOR_ZERO_SHARE][]
}
cand <- merge(ptab[urban == TRUE & polygon_dist_line_km >= 1.5,
                   .(parish_code, parish, polygon_dist_line_km, wholly_beyond_2km,
                     brt_core_crosses_part_beyond_2km, brt_any_crosses_part_beyond_2km)],
              screen_pass(pre[!is.na(parish_code)])[, .(parish_code, pre_crashes_per_month = round(mean, 2), passes_screen)],
              by = "parish_code", all.x = TRUE)[order(-polygon_dist_line_km)]
save_csv(cand, file.path(out, "pool_A_candidates.csv"))
save_csv(pool_summary, file.path(out, "donor_pools.csv"))
save_csv(rbindlist(lapply(names(donor_sets), function(p)
  donor_sets[[p]][, .(pool = p, pre_crashes_per_month = round(.N / length(months), 2)), by = .(donor = unit)])),
  file.path(out, "donor_units.csv"))
print(pool_summary)


# ---- Estimators: return c(effect, pre-period fit error) for the last row as treated -----------
# SDID unit weights (omega) depend only on training data and time weights (lambda) only on donors,
# so an injection into the treated unit's post period leaves both unchanged, and the estimate is
# c(-omega, 1)' Y c(-lambda, 1/H) (synthdid's own formula). prep_sdid fits once; tau_of re-evaluates.
prep_sdid <- function(C, T0) {
  base <- rowMeans(C[, seq_len(T0), drop = FALSE])
  keep <- base > 0
  if (!keep[nrow(C)] || sum(keep) < 3L) return(NULL)
  C <- C[keep, , drop = FALSE]; base <- base[keep]
  Y <- C / base
  n <- nrow(Y); H <- ncol(Y) - T0
  est <- suppressWarnings(synthdid_estimate(Y, N0 = n - 1L, T0 = T0))
  w <- attr(est, "weights")
  tvec <- c(-w$lambda, rep(1 / H, H))
  donor_part <- sum(w$omega * (Y[-n, , drop = FALSE] %*% tvec))
  gap <- Y[n, seq_len(T0)] - colSums(w$omega * Y[-n, seq_len(T0), drop = FALSE])
  tau_of <- function(y_treated) sum(y_treated / base[n] * tvec) - donor_part
  stopifnot(abs(tau_of(C[n, ]) - as.numeric(est)) < 1e-8)
  list(tau_of = tau_of, s = sd(gap))
}
fit_sdid <- function(C, T0) {
  pr <- prep_sdid(C, T0)
  if (is.null(pr)) c(NA_real_, NA_real_) else c(pr$tau_of(C[nrow(C), ]), pr$s)
}
fit_pois <- function(C, T0) {
  keep <- rowSums(C) > 0
  if (!keep[nrow(C)] || sum(C[nrow(C), seq_len(T0)]) == 0) return(c(NA_real_, NA_real_))
  C <- C[keep, , drop = FALSE]
  n <- nrow(C)
  d <- data.table(unit = rep(seq_len(n), ncol(C)), t = rep(seq_len(ncol(C)), each = n), y = as.vector(C))
  d[, D := as.integer(unit == n & t > T0)]
  m <- tryCatch(fepois(y ~ D | unit + t, d, notes = FALSE, warn = FALSE), error = function(e) NULL)
  if (is.null(m) || !"D" %in% names(coef(m))) return(c(NA_real_, NA_real_))
  d[obs(m), mu := fitted(m)]
  tr <- d[unit == n & t <= T0]
  c(unname(coef(m)["D"]), sd(log((tr$y + 0.5) / (tr$mu + 0.5))))
}
fitters <- list(sdid = fit_sdid, poisson = fit_pois)
stat_of <- function(f) if (anyNA(f) || f[2] <= 0) NA_real_ else abs(f[1]) / f[2]

inject <- function(y, delta) {
  if (delta < 0) rbinom(length(y), y, 1 + delta) else if (delta > 0) y + rpois(length(y), delta * y) else y
}

windows <- list(
  P1 = list(month = list(opens = 19:27, H = 9L), quarter = list(opens = 7:9, H = 3L)),
  P2 = list(month = list(opens = 16L, H = 20L), quarter = list(opens = 6L, H = 6L)))

run_design <- function(i) {
  g <- designs[i]
  setDTthreads(1L); setFixest_nthreads(1L)
  set.seed(SEED + i)
  C_full <- count_matrix(treated_sets[[g$treated]], donor_sets[[g$pool]], g$outcome, g$time)
  J <- nrow(C_full) - 1L
  stopifnot(J == g$J)
  w <- windows[[g$window]][[g$time]]
  fit <- fitters[[g$estimator]]
  res <- list()
  for (k in w$opens) {
    cols <- seq_len(k - 1L + w$H); T0 <- k - 1L
    C <- C_full[, cols, drop = FALSE]
    placebo <- vapply(seq_len(J), function(j) stat_of(fit(C[c(setdiff(seq_len(J), j), j), , drop = FALSE], T0)), 0)
    placebo <- placebo[!is.na(placebo)]
    pr <- if (g$estimator == "sdid") prep_sdid(C, T0) else NULL
    for (delta in DELTAS) for (r in seq_len(if (delta == 0) 1L else R_DRAWS)) {
      Ci <- C
      post <- (T0 + 1L):ncol(C)
      Ci[nrow(C), post] <- inject(C[nrow(C), post], delta)
      f <- if (g$estimator == "sdid") {
        if (is.null(pr)) c(NA_real_, NA_real_) else c(pr$tau_of(Ci[nrow(C), ]), pr$s)
      } else fit(Ci, T0)
      # Spot check of the SDID shortcut on an injected matrix: a full refit must give the same effect.
      if (g$estimator == "sdid" && !is.null(pr) && k == w$opens[1] && delta == -0.2 && r == 1L)
        stopifnot(abs(fit_sdid_refit(Ci, T0) - f[1]) < 1e-8)
      s <- stat_of(f)
      p <- if (is.na(s)) NA_real_ else (1 + sum(placebo >= s)) / (length(placebo) + 1)
      # Estimated effect as a proportion of the training level (SDID on the index; Poisson exp(b) - 1).
      effect <- if (g$estimator == "sdid") f[1] else exp(f[1]) - 1
      res[[length(res) + 1L]] <- data.table(fake_open = k, delta = delta, draw = r, p = p, effect = effect,
                                            placebos = length(placebo))
    }
  }
  cbind(g, fake_openings = length(w$opens), rbindlist(res))
}
fit_sdid_refit <- function(C, T0) {
  base <- rowMeans(C[, seq_len(T0), drop = FALSE])
  Y <- (C / base)[base > 0, , drop = FALSE]
  as.numeric(suppressWarnings(synthdid_estimate(Y, N0 = nrow(Y) - 1L, T0 = T0)))
}

# ---- Designs ---------------------------------------------------------------------------------
pooled <- CJ(treated = c("pooled_500m", "pooled_1km", "corridor_500m"),
             pool = names(donor_sets), time = c("month", "quarter"),
             outcome = c("all_crashes", "injury_or_fatal", "pedestrian"),
             estimator = c("sdid", "poisson"), window = c("P1", "P2"), sorted = FALSE)
by_station <- CJ(treated = paste0("station_1km: ", stations), pool = "O1_urban_parish_parts_beyond_2km",
                 time = "month", outcome = c("all_crashes", "injury_or_fatal"), estimator = "sdid", window = "P1",
                 sorted = FALSE)
designs <- rbind(pooled, by_station)
designs[, J := vapply(pool, function(p) uniqueN(donor_sets[[p]]$unit), 0L)]
# With J donors the smallest attainable p-value is 1/(J+1). Designs that cannot reach 0.10 are
# reported as such and not simulated.
designs[, attainable := 1 / (J + 1) <= max(ALPHAS)]
todo <- which(designs$attainable)
if (nzchar(Sys.getenv("RS_MAX_DESIGNS"))) todo <- head(todo, as.integer(Sys.getenv("RS_MAX_DESIGNS")))  # timing tests only
cat("Designs:", nrow(designs), "of which simulated:", length(todo), "\n")
t0 <- Sys.time()
runs <- parallel::mclapply(todo, run_design, mc.cores = N_CORES, mc.preschedule = FALSE)
failed <- which(!vapply(runs, is.data.table, TRUE))
if (length(failed)) stop("Designs failed in parallel workers: ", paste(todo[failed], collapse = ", "),
                         "\n", paste(vapply(runs[failed], function(x) paste(format(x), collapse = " "), ""), collapse = "\n"))
sims <- rbindlist(runs)
stopifnot(uniqueN(sims[, .(treated, pool, time, outcome, estimator, window)]) == length(todo))
cat("Simulation time:", format(round(Sys.time() - t0, 1)), "\n")
keys <- c("treated", "pool", "time", "outcome", "estimator", "window", "J")
# A failed fit counts as a non-rejection.
save_csv(sims[, .(power_05 = mean(!is.na(p) & p <= 0.05), power_10 = mean(!is.na(p) & p <= 0.10),
                  runs = .N, failed_fits = sum(is.na(p)), placebos_min = min(placebos), fake_openings = fake_openings[1]),
              by = c(keys, "delta")],
         file.path(out, "power_curves.csv"))

# MDE: the smallest |delta| from which power stays at or above 80 percent for every larger |delta|
# in that direction. NA when no effect up to 50 percent gets there.
mde <- function(delta, power, sign) {
  x <- data.table(delta, power)[sign * delta > 0][order(abs(delta))]
  ok <- rev(cumprod(rev(x$power >= 0.8))) == 1
  if (!any(ok)) NA_real_ else abs(x$delta[which(ok)[1]])
}
# Size gate: with n fake openings, the design fails if it rejects at delta = 0 in more than
# max(alpha, 1/n) of them (a single placement fails on any rejection). With 3 quarterly openings one
# rejection in three passes, and 9 overlapping monthly openings are weak evidence of correct size.
size_fails <- function(null_rej, n_open, alpha) if (n_open == 1L) null_rej > 0 else null_rej > max(alpha, 1 / n_open)
label_mde <- function(m, attainable, size_fail) {
  fifelse(!attainable, "not attainable", fifelse(size_fail, "size fails", fifelse(is.na(m), "> 50", as.character(round(100 * m)))))
}
curves <- fread(file.path(out, "power_curves.csv"))
tab <- curves[, .(
  placebos_min = min(placebos_min), fake_openings = fake_openings[1],
  null_rejection_05 = power_05[delta == 0], null_rejection_10 = power_10[delta == 0],
  m_dec_05 = mde(delta, power_05, -1), m_inc_05 = mde(delta, power_05, 1),
  m_dec_10 = mde(delta, power_10, -1), m_inc_10 = mde(delta, power_10, 1),
  failed_fits = sum(failed_fits)), by = keys]
tab[, smallest_attainable_p := round(1 / (placebos_min + 1), 4)]
tab[, `:=`(size_fails_05 = mapply(size_fails, null_rejection_05, fake_openings, 0.05),
           size_fails_10 = mapply(size_fails, null_rejection_10, fake_openings, 0.10))]
tab[, `:=`(mde_decrease_05_pct = label_mde(m_dec_05, 1 / (placebos_min + 1) <= 0.05, size_fails_05),
           mde_increase_05_pct = label_mde(m_inc_05, 1 / (placebos_min + 1) <= 0.05, size_fails_05),
           mde_decrease_10_pct = label_mde(m_dec_10, 1 / (placebos_min + 1) <= 0.10, size_fails_10),
           mde_increase_10_pct = label_mde(m_inc_10, 1 / (placebos_min + 1) <= 0.10, size_fails_10))]
tab[, c("m_dec_05", "m_inc_05", "m_dec_10", "m_inc_10") := NULL]
# Fake effects with nothing injected: what the pre-period alone produces at each fake opening.
fake <- sims[delta == 0, .(fake_effect_mean_pct = round(100 * mean(effect, na.rm = TRUE), 1),
                           fake_effect_min_pct = round(100 * min(effect, na.rm = TRUE), 1),
                           fake_effect_max_pct = round(100 * max(effect, na.rm = TRUE), 1)), by = keys]
save_csv(sims[delta == 0, .(treated, pool, time, outcome, estimator, window, J, fake_open,
                            fake_effect_pct = round(100 * effect, 1), p)],
         file.path(out, "placebo_in_time_null.csv"))
tab <- merge(tab, fake, by = keys, all.x = TRUE)
tab <- merge(designs[, c(keys, "attainable"), with = FALSE], tab, by = keys, all.x = TRUE)
tab[attainable == FALSE, `:=`(smallest_attainable_p = round(1 / (J + 1), 4),
                      mde_decrease_05_pct = "not attainable", mde_increase_05_pct = "not attainable",
                      mde_decrease_10_pct = "not attainable", mde_increase_10_pct = "not attainable")]
tab[, note := fifelse(!attainable, "1/(J+1) > 0.10: no test can reject at 0.05 or 0.10; not simulated",
              fifelse(smallest_attainable_p > 0.05, "1/(J+1) > 0.05: only alpha 0.10 attainable", ""))]
tab[attainable & window == "P2", note := paste0(note, "; P2 in time rests on one fake placement (training Jan 2021 to Mar 2022): illustrative")]
tab[grepl("^station", treated), note := paste0(note, "; uses option pool O1, not the approved pool A (J = ",
  uniqueN(donor_sets$A_urban_parishes_beyond_2km$unit), ")")]
tab[, note := sub("^; ", "", note)]
lvl <- rbindlist(lapply(names(treated_sets), function(t) treated_sets[[t]][, .(
  treated = t, pre_crashes_per_month = round(.N / length(months), 2),
  pre_injury_or_fatal_per_month = round(sum(injury_or_fatal) / length(months), 2),
  pre_pedestrian_per_month = round(sum(pedestrian) / length(months), 2))]))
tab <- merge(tab, lvl, by = "treated", all.x = TRUE)
setcolorder(tab, c(keys, "attainable", "placebos_min", "smallest_attainable_p", "fake_openings",
                   "mde_decrease_05_pct", "mde_increase_05_pct", "mde_decrease_10_pct", "mde_increase_10_pct",
                   "null_rejection_05", "null_rejection_10", "fake_effect_mean_pct", "fake_effect_min_pct",
                   "fake_effect_max_pct"))
setorder(tab, window, treated, pool, outcome, time, estimator)
save_csv(tab, file.path(out, "mde_table.csv"))

# ---- P2 check: circular block bootstrap of gaps to the equal-weight donor mean (monthly) --------
# Two variants: "stationary" (gaps demeaned, as in congestion 03_preperiod_power.R) and
# "linear_trend" (the pre-period linear trend of each gap is kept and extended into P2, so a drift
# between treated area and donors counts against the design). Delta = 0 gives the size.
# One set of circular block starts (blocks of 3 months) per replicate, applied to every unit, so the
# treated and placebo gaps keep their joint dependence (they share the donor mean and common shocks).
block_index <- function(Tn, n, L = 3L) {
  starts <- sample.int(Tn, ceiling(n / L), replace = TRUE)
  (as.vector(t(outer(starts, 0:(L - 1L), "+")))[seq_len(n)] - 1L) %% Tn + 1L
}
set.seed(SEED)
T_pre <- length(months); H2 <- 20L; tt <- seq_len(T_pre + H2)
boot <- rbindlist(lapply(c("pooled_500m", "pooled_1km", "corridor_500m"), function(tr) {
  rbindlist(lapply(pool_summary[smallest_attainable_p <= max(ALPHAS), pool], function(pl) {
    rbindlist(lapply(c("all_crashes", "injury_or_fatal", "pedestrian"), function(oc) {
      C <- count_matrix(treated_sets[[tr]], donor_sets[[pl]], oc, "month")
      C <- C[rowMeans(C) > 0, , drop = FALSE]
      stopifnot(rownames(C)[nrow(C)] == "treated")
      Y <- C / rowMeans(C)
      n <- nrow(Y)
      gaps <- lapply(seq_len(n), function(u) {
        others <- if (u == n) seq_len(n - 1L) else setdiff(seq_len(n - 1L), u)
        Y[u, ] - colMeans(Y[others, , drop = FALSE])
      })
      rbindlist(lapply(c("stationary", "linear_trend"), function(variant) {
        comp <- lapply(gaps, function(g) {
          if (variant == "stationary") list(res = g - mean(g), trend = rep(0, length(tt)))
          else { m <- lm(g ~ seq_len(T_pre)); list(res = resid(m), trend = coef(m)[1] + coef(m)[2] * tt) }
        })
        stats <- replicate(BOOT_DRAWS, {
          ix <- block_index(T_pre, T_pre + H2)
          vapply(comp, function(cp) {
            z <- cp$res[ix] + cp$trend
            c(mean(z[(T_pre + 1L):(T_pre + H2)]) - mean(z[seq_len(T_pre)]), sd(z[seq_len(T_pre)]))
          }, numeric(2))
        }, simplify = "array")
        rbindlist(lapply(DELTAS, function(delta) {
          rej <- vapply(seq_len(BOOT_DRAWS), function(b) {
            s <- abs(stats[1, , b] + c(rep(0, n - 1L), delta)) / stats[2, , b]
            (1 + sum(s[-n] >= s[n])) / n
          }, 0)
          data.table(treated = tr, pool = pl, outcome = oc, variant = variant, J = n - 1L, delta = delta,
                     power_05 = mean(rej <= 0.05), power_10 = mean(rej <= 0.10))
        }))
      }))
    }))
  }))
}))
# Size gate for the bootstrap: the rank test's exact level at alpha is floor(alpha (J+1)) / (J+1); the
# design fails if the null rejection exceeds that level by more than two Monte Carlo standard errors.
boot_size_fails <- function(null_rej, J, alpha) {
  lev <- floor(alpha * (J + 1)) / (J + 1)
  null_rej > lev + 2 * sqrt(lev * (1 - lev) / BOOT_DRAWS)
}
boot_mde <- boot[, .(
  exact_level_10 = round(floor(0.10 * (J[1] + 1)) / (J[1] + 1), 4),
  null_rejection_05 = power_05[delta == 0], null_rejection_10 = power_10[delta == 0],
  null_rejection_10_mc_se = round(sqrt(power_10[delta == 0] * (1 - power_10[delta == 0]) / BOOT_DRAWS), 4),
  mde_decrease_05_pct = label_mde(mde(delta, power_05, -1), 1 / (J[1] + 1) <= 0.05, boot_size_fails(power_05[delta == 0], J[1], 0.05)),
  mde_increase_05_pct = label_mde(mde(delta, power_05, 1), 1 / (J[1] + 1) <= 0.05, boot_size_fails(power_05[delta == 0], J[1], 0.05)),
  mde_decrease_10_pct = label_mde(mde(delta, power_10, -1), 1 / (J[1] + 1) <= 0.10, boot_size_fails(power_10[delta == 0], J[1], 0.10)),
  mde_increase_10_pct = label_mde(mde(delta, power_10, 1), 1 / (J[1] + 1) <= 0.10, boot_size_fails(power_10[delta == 0], J[1], 0.10))),
  by = .(treated, pool, outcome, variant, J)]
boot_mde[, benchmark := "equal-weight donor mean; not SDID or Poisson; no Poisson noise on the injected effect"]
save_csv(boot, file.path(out, "p2_block_bootstrap_curves.csv"))
save_csv(boot_mde, file.path(out, "p2_block_bootstrap_mde.csv"))
writeLines(c(capture.output(sessionInfo()), paste("seed", SEED), paste("cores", N_CORES)),
           file.path(out, "session_info.txt"))
print(tab[window == "P1" & time == "month" & !grepl("^station", treated) & attainable,
          .(treated, pool, outcome, estimator, J, mde_decrease_10_pct, mde_increase_10_pct, null_rejection_10, fake_effect_mean_pct)])
print(boot_mde[, .(treated, pool, outcome, variant, null_rejection_10, mde_decrease_10_pct, mde_increase_10_pct)])
