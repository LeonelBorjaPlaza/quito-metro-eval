# P1 estimates (December 2023 to August 2024), as pre-registered in road_safety/docs/analysis_plan_amendment_1.md
# (approved for P1 by Leonel on 2026-10-01; frozen at branch commit f161d18). Run from road_safety/ after
# 02_spatial.R and 08_gradient.R: Rscript code/11_p1_estimates.R
# Reads pre-period rows (load_pre) and P1 rows (load_p1) only; nothing after August 2024.
# Writes output/p1/ (aggregates only; the small-count rule of amendment section 4.6, condition 7, applies:
# a specification is estimated only if every series has at least 5 crashes in every pre-period quarter of kept months,
# and no count is published, only estimates, intervals and p-values; P1 counts by zone are rounded to 5):
#   estimates.csv        one row per specification: estimate, 90 and 95 percent intervals, what they rule
#                        out, p-value and floor, the drift rule with its forward fake effects, the size check
#   direction_rule.csv   the main specification's direction rule, its three conditions and the wording
#   leave_one_out.csv    I4: the range over the 39 leave-one-parish-out estimates
#   not_run.csv          specifications not run for P1, with the reason
#   p1_counts.csv        P1 crashes by zone and severity, rounded to 5 (context)
#   main_series.png      the main specification's monthly indices, with the national shocks marked
#   missing_time_share.csv  share of crashes with no recorded time (J2 keeps them as daytime), and at exactly 00:00
#   described_only.csv   secondary outcomes (pedestrian, motorcycle, bus, bicycle) and stations one by one: the
#                        estimate with its fake effects for context, no p-value or interval (plan section 4)
#   recording_composition.csv  share of records from non-territorial recording units by zone, pre-period and P1
#                        (plan section 8, rule 4); shares withheld where either part has fewer than 5 records
#   session_info.txt
# The drift rule compares tau and the fake effects on each specification's own scale (index points; log
# points for F1 and F2; counts x 100 for F3).
# Method (amendment sections 2, 4.1 to 4.4): proportional scale (each series divided by its mean over the
# kept pre-period months); gap = treated index - comparator index; under the null the model (an intercept,
# or synthetic-control weights for E3) is fitted on all kept months; statistic |mean residual over P1|
# (mean |residual| for I6); circular shifts over the kept months; p = share at least as extreme; floor 1/T;
# 5 percent level. Intervals invert the same test over constant proportional effects d (treated P1 counts
# divided by 1 + d). Estimate: tau = mean gap in P1 - mean gap in the pre-period; percent of the
# counterfactual = 100 tau / (mean treated index in P1 - tau). Drift rule (signed): a fall passes only if
# tau < 0 and below every forward fake effect, a rise only if tau > 0 and above every forward fake effect,
# compared on the index scale (100 tau); forward fake effects use the specification's own months (12
# training months with the 2022 start, 18 with 2021); none -> "not assessable". Size check: the 9-month
# (or the specification's P1 length) window at every position inside the kept pre-period, at d = 0;
# fails when more than max(alpha, 1/n) of the n placements reject.
source("code/helpers.R")
suppressPackageStartupMessages(library(synthdid))
stopifnot(file.exists(CENTRO_GEOJSON), substr(system2("sha256sum", shQuote(CENTRO_GEOJSON), stdout = TRUE), 1, 64) == CENTRO_SHA256,
          file.exists("output/power/gradient/placebo_stations.csv"))
out <- "output/p1"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
SEED <- 20261004L
B <- 2000L
DGRID <- round(seq(-0.90, 2.00, by = 0.005), 3)  # proportional effects tested for the intervals
ALPHA <- 0.05

pre <- load_pre(CRASHES_SPATIAL); p1 <- load_p1(CRASHES_SPATIAL)
d <- rbind(pre, p1)
stopifnot(max(d$fecha) <= P1_END, !anyNA(d$road_type))
d[, m := month_start(fecha)]
ALL_M <- seq(as.Date("2021-01-01"), as.Date("2024-08-01"), by = "month")
P1_M <- ALL_M[ALL_M >= P1_START]
stopifnot(length(P1_M) == 9L)
d[, t := match(m, ALL_M)]
stopifnot(!anyNA(d$t))

# ---- Roles (as in 10_preperiod_checks.R) -----------------------------------------------------------
ptab <- fread(PARISHES_TABLE)
distant <- ptab[wholly_beyond_2km == TRUE & brt_core_crosses_part_beyond_2km == FALSE, parish_code]
stopifnot(length(distant) == 39L)
cn_codes <- ptab[brt_any_crosses_part_beyond_2km == TRUE & !brt_core_crosses_part_beyond_2km, parish_code]
CALDERON <- ptab[parish == "CALDERON", parish_code]
scr <- pre[parish_code %in% distant, .(m = .N / 35, z = 1 - uniqueN(month_start(fecha)) / 35), by = parish_code]
poolB <- scr[m >= 3 & z <= 0.2, parish_code]
stopifnot(length(poolB) == 9L, CALDERON %in% distant, all(intersect(cn_codes, distant) %in% poolB))
d[, zone := fcase(dist_station_m < 1000, "treated", dist_station_m < 2000, "ring", parish_code %in% distant, "distant",
                  !is.na(parish_code), "intermediate", default = "outside")]
centro <- st_transform(st_read(CENTRO_GEOJSON, quiet = TRUE), CRS_UTM)
pts <- st_transform(st_as_sf(d[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
d[, centro := lengths(st_within(pts, centro)) > 0]
ps <- fread("output/power/gradient/placebo_stations.csv")
xy <- st_coordinates(pts)
d[, placebo := apply(sqrt(outer(xy[, 1], ps$x_utm, "-")^2 + outer(xy[, 2], ps$y_utm, "-")^2), 1, min) < 2000]
d[, night := !is.na(minute_of_day) & (minute_of_day >= 23L * 60L | minute_of_day < 5L * 60L)]
# I3: points shared by 3 or more pre-period records (pre-period only, so P1 outcomes do not decide what is dropped);
# crashes at those points are dropped in every month.
shared_pts <- pre[, .N, by = .(lon, lat)][N >= 3L, .(lon, lat)]
d[, pt_n := 0L][shared_pts, on = .(lon, lat), pt_n := 3L]
stopifnot(!any(d$placebo & d$zone %in% c("treated", "ring")))  # placebo highways lie in comparator and intermediate areas
d[, fast_name := fast_road | av_mariscal_sucre]          # H1: name-only flag
d[, fast_conf := road_type == "fast"]

LOO_PC <- NA_integer_  # parish left out in I4
# ---- Unit selectors and outcomes -----------------------------------------------------------------
fastcol <- function(h1) if (h1) "fast_name" else "fast_conf"
unit_rows <- function(u, h1 = FALSE) {
  fc <- fastcol(h1)
  if (startsWith(u, "st:")) return(d[zone == "treated" & nearest_station == substring(u, 4)])  # one station's 1 km catchment (nearest station, disjoint)
  switch(u,
    treated = d[zone == "treated"], b500 = d[catchment_500 == TRUE], corr500 = d[corridor_500 == TRUE], corr1k = d[corridor_1km == TRUE],
    ring = d[zone == "ring"], intermediate = d[zone == "intermediate"], centro = d[centro == TRUE],
    treated_city = d[zone == "treated" & !get(fc)], treated_fast = d[zone == "treated" & get(fc)],
    ring_city = d[zone == "ring" & !get(fc)], ring_fast = d[zone == "ring" & get(fc)],
    near_fast = d[zone %in% c("treated", "ring") & get(fc)], treated_ring = d[zone %in% c("treated", "ring")],
    distant = d[zone == "distant"], poolB = d[parish_code %in% poolB], distant_noCN = d[zone == "distant" & !parish_code %in% cn_codes],
    distant_noCal = d[zone == "distant" & parish_code != CALDERON], distant_minus = d[zone == "distant" & parish_code != LOO_PC], distant_fast = d[zone == "distant" & get(fc)],
    placebo_fast = d[placebo == TRUE & get(fc)], stop("unknown unit ", u))
}
outcome_rows <- function(x, oc) switch(oc, injury = x[injury_or_fatal == TRUE], all = x, damage = x[injury_or_fatal == FALSE],
  pedestrian = x[pedestrian == TRUE], motorcycle = x[any_motorcycle == TRUE], bus = x[any_bus == TRUE], bicycle = x[any_bicycle == TRUE])
monthly <- function(x) tabulate(x$t, length(ALL_M))

# ---- Core: gap, conformal p, estimate, interval ------------------------------------------------------
weights_sc <- function(Y, cols, H) {  # synthdid-style synthetic-control weights with an intercept (as 04b)
  n <- nrow(Y); noise <- sd(apply(Y[-n, cols, drop = FALSE], 1, diff))
  synthdid:::sc.weight.fw(t(Y[, cols, drop = FALSE]), zeta = H^(1 / 4) * noise, intercept = TRUE,
                          min.decrease = 1e-5 * noise, max.iter = 10000)$lambda
}
# S: list(Tc = treated counts over kept periods, C = comparator count matrix (rows units), post = indices,
# train = indices, weights = "pooled" | "did" | "sc", scale = "index" | "log" | "level" | "poisson",
# stat = "abs_mean" | "mean_abs", trend = NULL or list(b, tpos) for J1, season = NULL or month-of-year vector)
build_Y <- function(S, dlt) {
  Tc <- S$Tc; Tc[S$post] <- Tc[S$post] / (1 + dlt)
  M <- rbind(S$C, Tc)
  if (S$scale == "index") { base <- rowMeans(M[, S$train, drop = FALSE]); keep <- base > 0; keep[length(keep)] <- TRUE
    (M / base)[keep, , drop = FALSE] }  # comparator units with no crash in the training months are left out (as in 04b)
  else if (S$scale == "log") log(M)
  else M
}
gap_of <- function(S, Y, w) Y[nrow(Y), ] - colSums(w * Y[-nrow(Y), , drop = FALSE])
wts <- function(S, Y, cols) {
  J <- nrow(Y) - 1L
  if (S$weights == "sc") weights_sc(Y, cols, length(S$post)) else rep(1 / J, J)
}
adjust <- function(S, g, null = FALSE) {  # J1 detrending (fixed slope) and I7 seasonal adjustment
  if (!is.null(S$trend)) g <- g - S$trend$b * (S$trend$tpos - mean(S$trend$tpos[S$train]))
  if (!is.null(S$season)) {  # month-of-year means of the gap: pre-period (training) months for the estimate; all kept months
    # for the null model of the test (section 4.1: the null model is fitted on all months). A month absent from the
    # fitting months uses their overall mean.
    fm <- if (null) seq_along(g) else S$train
    mo <- S$season; mm <- tapply(g[fm], mo[fm], mean); adj <- unname(mm[as.character(mo)]); adj[is.na(adj)] <- mean(g[fm]); g <- g - adj }
  g
}
resid_null <- function(S, dlt) {
  if (S$scale == "poisson") {
    Tc <- S$Tc; Tc[S$post] <- Tc[S$post] / (1 + dlt)
    cnt <- c(colSums(S$C), Tc); n <- length(Tc)
    df <- data.frame(y = cnt, unit = rep(c("c", "t"), each = n), per = factor(rep(seq_len(n), 2)))
    f <- suppressWarnings(glm(y ~ unit + per, family = quasipoisson(), data = df))
    r <- log(pmax(Tc, 1e-9)) - log(fitted(f)[df$unit == "t"])
    return(r - mean(r))
  }
  Y <- build_Y(S, dlt)
  g <- adjust(S, gap_of(S, Y, wts(S, Y, seq_len(ncol(Y)))), null = TRUE)
  g - mean(g)
}
pval <- function(S, dlt = 0) {
  u <- resid_null(S, dlt); Tn <- length(u)
  sh <- lapply(0:(Tn - 1L), function(j) u[((S$post - 1L + j) %% Tn) + 1L])
  st <- vapply(sh, function(x) if (S$stat == "mean_abs") mean(abs(x)) else abs(mean(x)), 0)
  mean(st >= st[1] - 1e-12)
}
estimate <- function(S) {
  if (S$scale == "poisson") {
    cnt <- c(colSums(S$C), S$Tc); n <- length(S$Tc)
    df <- data.frame(y = cnt, unit = rep(c("c", "t"), each = n), per = factor(rep(seq_len(n), 2)),
                     treat = c(rep(0, n), as.integer(seq_len(n) %in% S$post)))
    f <- suppressWarnings(glm(y ~ unit + per + treat, family = quasipoisson(), data = df))
    b <- unname(coef(f)["treat"]); return(list(tau = b, pct = 100 * (exp(b) - 1)))
  }
  Y <- build_Y(S, 0)
  g <- adjust(S, gap_of(S, Y, wts(S, Y, S$train)))
  tau <- mean(g[S$post]) - mean(g[S$train])
  pct <- switch(S$scale, index = 100 * tau / (mean(Y[nrow(Y), S$post]) - tau), log = 100 * (exp(tau) - 1),
                level = 100 * tau / (mean(Y[nrow(Y), S$post]) - tau))
  list(tau = tau, pct = pct)
}
interval <- function(S, alpha) {
  ok <- vapply(DGRID, function(x) pval(S, x) > alpha, TRUE); acc <- DGRID[ok]
  if (!length(acc)) return(c(lo = NA, hi = NA, lo_open = FALSE, hi_open = FALSE, pieces = 0))
  # the accepted set need not be one interval: its bounds are reported, with the number of separate pieces
  c(lo = 100 * min(acc), hi = 100 * max(acc), lo_open = min(acc) <= min(DGRID), hi_open = max(acc) >= max(DGRID),
    pieces = sum(diff(c(FALSE, ok)) == 1))
}
rules_out <- function(iv) {
  if (is.na(iv["lo"])) return("empty set at this level")
  lo <- if (iv["lo_open"] == 1) "rules out no fall" else if (iv["lo"] >= 0) "rules out any fall" else sprintf("rules out falls larger than %.1f percent", -iv["lo"])
  hi <- if (iv["hi_open"] == 1) "rules out no rise" else if (iv["hi"] <= 0) "rules out any rise" else sprintf("rules out rises larger than %.1f percent", iv["hi"])
  if (grepl("no (fall|rise)$", lo) || grepl("no (fall|rise)$", hi)) return(paste(lo, hi, sep = "; "))
  paste(lo, sub("^rules out ", "", hi), sep = " and ")  # the plan's wording: "rules out falls larger than a and rises larger than b"
}

# ---- Building a specification ------------------------------------------------------------------------
# kept months: pre-period from `start`, minus `drop`; P1 minus `drop`. Quarterly (G8): opening-aligned
# quarters of kept months, a quarter's value = mean of its kept months x 3.
make_spec <- function(target, comparator, outcome = "injury", weights = "pooled", scale = "index", start = "2022-01-01",
                      drop = c("2022-06-01", "2023-11-01"), stat = "abs_mean", filt = NULL, h1 = FALSE, freq = "month",
                      comp_units = NULL, season = FALSE) {
  keep_m <- ALL_M[ALL_M >= as.Date(start) & !ALL_M %in% as.Date(drop)]
  getrows <- function(u) { x <- outcome_rows(unit_rows(u, h1), outcome); if (!is.null(filt)) { kp <- eval(filt, x); x <- x[kp] }; x }
  Tser <- monthly(getrows(target))
  Cser <- if (!is.null(comp_units)) {
    base <- outcome_rows(d[parish_code %in% comp_units], outcome); if (!is.null(filt)) { kp <- eval(filt, base); base <- base[kp] }
    t(vapply(comp_units, function(pc) tabulate(base[parish_code == pc]$t, length(ALL_M)), numeric(length(ALL_M))))
  } else matrix(monthly(getrows(comparator)), nrow = 1)
  idx <- match(keep_m, ALL_M)
  if (freq == "quarter") {
    q <- quarter_start(keep_m); qs <- sort(unique(q[q >= as.Date("2022-03-01")]))
    agg <- function(v) vapply(qs, function(qq) 3 * mean(v[idx[q == qq]]), 0)
    Tc <- agg(Tser); C <- t(apply(Cser, 1, agg)); if (nrow(Cser) == 1) C <- matrix(agg(Cser[1, ]), nrow = 1)
    per <- qs
  } else { Tc <- Tser[idx]; C <- Cser[, idx, drop = FALSE]; per <- keep_m }
  if (nrow(C) > 1L) C <- C[rowSums(C[, per < P1_START, drop = FALSE]) > 0, , drop = FALSE]  # E2, E3: parishes with crashes in the kept pre-period
  post <- which(per >= P1_START); train <- which(per < P1_START)
  # small-count rule (plan section 5): every pre-period quarter of kept months, in target and comparator, at least 5 crashes
  pre_k <- keep_m < P1_START; qk <- quarter_start(keep_m[pre_k])
  okq <- function(v) all(tapply(v[idx[pre_k]], qk, sum) >= 5)
  ok <- okq(Tser) && (if (!is.null(comp_units)) okq(colSums(Cser)) else okq(Cser[1, ]))
  list(Tc = Tc, C = C, post = post, train = train, weights = weights, scale = scale, stat = stat, per = per, freq = freq,
       start = start, ok = ok, trend = NULL, season = if (season) as.integer(format(per, "%m")) else NULL,
       tpos = match(per, ALL_M))
}
# forward fake effects (own months): openings after MIN_TRAIN kept pre months, window = P1 length
fake_forward <- function(S) {
  tr <- S$train; H <- length(S$post); mt <- (if (S$start == "2021-01-01") 18L else 12L) %/% (if (S$freq == "quarter") 3L else 1L)
  if (length(tr) < mt + H) return(numeric())
  vapply((mt + 1L):(length(tr) - H + 1L), function(k) {
    Sk <- S; Sk$Tc <- S$Tc[tr]; Sk$C <- S$C[, tr, drop = FALSE]; Sk$post <- k:(k + H - 1L); Sk$train <- seq_len(k - 1L)
    Sk$tpos <- S$tpos[tr]; if (!is.null(S$season)) Sk$season <- S$season[tr]
    Sk$Tc <- Sk$Tc[seq_len(k + H - 1L)]; Sk$C <- Sk$C[, seq_len(k + H - 1L), drop = FALSE]
    if (!is.null(Sk$season)) Sk$season <- Sk$season[seq_len(k + H - 1L)]
    100 * estimate(Sk)$tau
  }, 0)
}
size_check <- function(S) {
  tr <- S$train; H <- length(S$post); n <- length(tr) - H + 1L
  if (n < 2L) return(c(n = 0, r05 = NA, r10 = NA, fmin = NA, fmax = NA))
  ps <- vapply(seq_len(n), function(k) {
    Sk <- S; Sk$Tc <- S$Tc[tr]; Sk$C <- S$C[, tr, drop = FALSE]; Sk$post <- k:(k + H - 1L); Sk$train <- setdiff(seq_along(tr), Sk$post)
    if (!is.null(S$season)) Sk$season <- S$season[tr]
    c(pval(Sk, 0), 100 * estimate(Sk)$tau)
  }, c(0, 0))
  c(n = n, r05 = sum(ps[1, ] <= 0.05), r10 = sum(ps[1, ] <= 0.10), fmin = min(ps[2, ]), fmax = max(ps[2, ]))
}
gate <- function(k, n, a) if (is.na(k) || n == 0) "size not checked" else if (k / n > max(a, 1 / n)) "fails" else "passes"
bound <- function(iv, side) if (iv[[paste0(side, "_open")]] == 1) NA_real_ else round(iv[[side]], 1)  # open bound: NA (rule 6)
drift_rule <- function(tau100, fakes) {
  if (!length(fakes)) return("not assessable")
  if (tau100 < 0 && tau100 < min(fakes)) "passes (fall)" else if (tau100 > 0 && tau100 > max(fakes)) "passes (rise)" else "does not pass"
}
run <- function(id, label, S, size = TRUE) {
  if (!S$ok) return(data.table(id = id, label = label, note = "counts too small (a pre-period quarter with fewer than 5 crashes)"))
  e <- estimate(S)
  if (!is.finite(e$tau)) { message('estimate not defined: ', id); return(data.table(id = id, label = label, note = 'estimate not defined')) }
  p <- pval(S, 0); i90 <- interval(S, 0.10); i95 <- interval(S, 0.05)
  ff <- fake_forward(S); stopifnot(!anyNA(ff)); sc <- if (size) size_check(S) else c(n = 0, r05 = NA, r10 = NA, fmin = NA, fmax = NA)
  data.table(id = id, label = label, periods = length(S$per), floor = round(1 / length(S$per), 4),
             estimate_pct = round(e$pct, 1), tau_x100_own_scale = round(100 * e$tau, 2), p_value = round(p, 4),
             rejects_5pct = p <= ALPHA,
             ci90_low = bound(i90, "lo"), ci90_high = bound(i90, "hi"), rules_out_90 = rules_out(i90),
             ci95_low = bound(i95, "lo"), ci95_high = bound(i95, "hi"), rules_out_95 = rules_out(i95),
             ci90_pieces = i90[["pieces"]], ci95_pieces = i95[["pieces"]],
             forward_fake_effects = if (length(ff)) paste(round(ff, 1), collapse = "; ") else "none",
             drift_rule = drift_rule(100 * e$tau, ff),
             inside_fake_effects_range = if (sc[["n"]] > 0) sprintf("%.1f to %.1f", sc[["fmin"]], sc[["fmax"]]) else "none",
             size_placements = sc[["n"]], size_rejections_05 = sc[["r05"]], size_rejections_10 = sc[["r10"]],
             size_check_05 = gate(sc[["r05"]], sc[["n"]], 0.05), size_check_10 = gate(sc[["r10"]], sc[["n"]], 0.10), note = "")
}

# ---- The specifications -------------------------------------------------------------------------------
I3 <- quote(pt_n < 3L); J2 <- quote(!night)
specs <- list(
  A1 = list("Main: treated 1 km, injury or fatal, vs distant parishes pooled", make_spec("treated", "distant")),
  A2 = list("All crashes", make_spec("treated", "distant", "all")),
  A3 = list("Damage only (secondary)", make_spec("treated", "distant", "damage")),
  A4 = list("Injury or fatal, city streets", make_spec("treated_city", "distant")),
  A5 = list("All crashes, city streets", make_spec("treated_city", "distant", "all")),
  A6 = list("Damage only, city streets", make_spec("treated_city", "distant", "damage")),
  A7 = list("Injury or fatal, fast roads in the treated area", make_spec("treated_fast", "distant")),
  A8 = list("All crashes, fast roads in the treated area", make_spec("treated_fast", "distant", "all")),
  B1 = list("500 m catchments", make_spec("b500", "distant")),
  B2 = list("Corridor within 500 m of the line", make_spec("corr500", "distant")),
  B3 = list("Corridor within 1 km of the line", make_spec("corr1k", "distant")),
  B4 = list("Historic center, all crashes", make_spec("centro", "distant", "all")),
  B5 = list("Historic center, injury or fatal", make_spec("centro", "distant")),
  B6 = list("Historic center, damage only", make_spec("centro", "distant", "damage")),
  C1 = list("Ring 1 to 2 km, injury or fatal", make_spec("ring", "distant")),
  C2 = list("Ring, all crashes", make_spec("ring", "distant", "all")),
  C3 = list("Ring, damage only", make_spec("ring", "distant", "damage")),
  C4 = list("Ring, city streets, injury or fatal", make_spec("ring_city", "distant")),
  C5 = list("Ring, fast roads, injury or fatal", make_spec("ring_fast", "distant")),
  C6 = list("Intermediate zone, injury or fatal", make_spec("intermediate", "distant")),
  C7 = list("Intermediate zone, all crashes", make_spec("intermediate", "distant", "all")),
  C8 = list("Fast roads near the line, injury or fatal", make_spec("near_fast", "distant")),
  C9 = list("Fast roads near the line, all crashes", make_spec("near_fast", "distant", "all")),
  C10 = list("Fast roads near the line vs distant fast roads, injury or fatal", make_spec("near_fast", "distant_fast")),
  C11 = list("Fast roads near the line vs placebo-highway fast roads, injury or fatal", make_spec("near_fast", "placebo_fast")),
  C11_all = list("Fast roads near the line vs placebo-highway fast roads, all crashes (headline 4, appendix)", make_spec("near_fast", "placebo_fast", "all")),
  C12 = list("Treated area and ring together, injury or fatal", make_spec("treated_ring", "distant")),
  D1 = list("Fast roads vs city streets within the treated area, injury or fatal", make_spec("treated_fast", "treated_city")),
  E1 = list("Pool B, pooled", make_spec("treated", "poolB")),
  E2 = list("Equal weights over the distant parishes", make_spec("treated", NULL, weights = "did", comp_units = distant)),
  E3 = list("Synthetic-control weights over the distant parishes", make_spec("treated", NULL, weights = "sc", comp_units = distant)),
  E4 = list("Distant parishes without the Central Norte-crossed", make_spec("treated", "distant_noCN")),
  E5 = list("Gradient: treated area vs the ring", make_spec("treated", "ring")),
  E6 = list("Distant parishes without Calderon", make_spec("treated", "distant_noCal")),
  F1 = list("Log scale", make_spec("treated", "distant", scale = "log")),
  F2 = list("Poisson, area and month fixed effects", make_spec("treated", "distant", scale = "poisson")),
  F3 = list("Raw counts (level)", make_spec("treated", "distant", scale = "level")),
  G3 = list("Pre-period from January 2021", make_spec("treated", "distant", start = "2021-01-01")),
  G4 = list("December 2023 dropped", make_spec("treated", "distant", drop = c("2022-06-01", "2023-11-01", "2023-12-01"))),
  G5 = list("September and October 2023 dropped (anticipation)", make_spec("treated", "distant", drop = c("2022-06-01", "2023-09-01", "2023-10-01", "2023-11-01"))),
  G8 = list("Quarterly", make_spec("treated", "distant", freq = "quarter")),
  I3 = list("Crashes at exact points shared by 3 or more records dropped", make_spec("treated", "distant", filt = I3)),
  I6 = list("Default statistic, mean |residual|", make_spec("treated", "distant", stat = "mean_abs")),
  I7 = list("Seasonality: month-of-year adjustment", make_spec("treated", "distant", season = TRUE)),
  J2 = list("Night crashes (23:00 to 05:00) left out", make_spec("treated", "distant", filt = J2)),
  J3 = list("April and May 2024 left out", make_spec("treated", "distant", drop = c("2022-06-01", "2023-11-01", "2024-04-01", "2024-05-01"))),
  K1 = list("June 2022 and November 2023 kept", make_spec("treated", "distant", drop = character()))
)
# H1: the name-only fast-road flag for A4 to A8, C4, C5, C8 to C11
h1 <- list(A4 = c("treated_city", "distant", "injury"), A5 = c("treated_city", "distant", "all"), A6 = c("treated_city", "distant", "damage"),
           A7 = c("treated_fast", "distant", "injury"), A8 = c("treated_fast", "distant", "all"), C4 = c("ring_city", "distant", "injury"),
           C5 = c("ring_fast", "distant", "injury"), C8 = c("near_fast", "distant", "injury"), C9 = c("near_fast", "distant", "all"),
           C10 = c("near_fast", "distant_fast", "injury"), C11 = c("near_fast", "placebo_fast", "injury"),
           C11_all = c("near_fast", "placebo_fast", "all"))
for (k in names(h1)) specs[[paste0("H1_", k)]] <- list(paste("H1 (name-only flag):", specs[[k]][[1]]),
                                                         make_spec(h1[[k]][1], h1[[k]][2], h1[[k]][3], h1 = TRUE))
res <- rbindlist(lapply(names(specs), function(k) run(k, specs[[k]][[1]], specs[[k]][[2]])), fill = TRUE)
# F3's level effect, in crashes a month, would give the exact P1 total together with the percent, undoing the rounding of
# p1_counts.csv (condition 7); it is withheld. Its drift rule is computed on the unrounded value.
res[id == "F3", `:=`(tau_x100_own_scale = NA_real_, note = "level effect withheld (small-count rule, condition 7)")]

# ---- J1: continued drift, for A1 (amendment section 4.2) ----------------------------------------------
S <- specs$A1[[2]]
Y0 <- build_Y(S, 0); g0 <- gap_of(S, Y0, wts(S, Y0, S$train))
tp <- S$tpos; trn <- S$train
fit <- lm(g0[trn] ~ tp[trn]); bhat <- unname(coef(fit)[2]); r0 <- unname(resid(fit))
block_boot <- function(x, L = 3L) { n <- length(x); s <- sample.int(n - L + 1L, ceiling(n / L), replace = TRUE); unlist(lapply(s, function(i) x[i:(i + L - 1L)]))[seq_len(n)] }
set.seed(SEED + 1L)
sb <- replicate(B, { g <- block_boot(r0); unname(coef(lm(g ~ tp[trn]))[2]) })
bset <- c(bhat - quantile(sb, 0.975), bhat - quantile(sb, 0.025))
bgrid <- seq(bset[1], bset[2], length.out = 41)
SJ <- S; SJ$trend <- list(b = bhat, tpos = tp)
eJ <- estimate(SJ)
acc <- unique(unlist(lapply(bgrid, function(b) { Sb <- S; Sb$trend <- list(b = b, tpos = tp); DGRID[vapply(DGRID, function(x) pval(Sb, x) > 0.05, TRUE)] })))
ivJ <- if (length(acc)) c(lo = 100 * min(acc), hi = 100 * max(acc), lo_open = min(acc) <= min(DGRID), hi_open = max(acc) >= max(DGRID)) else c(lo = NA, hi = NA, lo_open = FALSE, hi_open = FALSE)
res <- rbind(res, data.table(id = "J1", label = "Continued drift (A1), interval of at least 90 percent coverage", periods = length(S$per),
                             floor = round(1 / length(S$per), 4), estimate_pct = round(eJ$pct, 1), tau_x100_own_scale = round(100 * eJ$tau, 2),
                             ci90_low = bound(ivJ, "lo"), ci90_high = bound(ivJ, "hi"), rules_out_90 = rules_out(ivJ),
                             note = sprintf("slope %.2f index points per month; 95 percent slope set %.2f to %.2f; union of 95 percent conformal sets",
                                            100 * bhat, 100 * bset[1], 100 * bset[2])), fill = TRUE)

# ---- I4: leave one distant parish out -------------------------------------------------------------------
loo <- rbindlist(lapply(distant, function(pc) {
  LOO_PC <<- pc; Sx <- make_spec("treated", "distant_minus")  # A1 with one parish removed from the pooled comparator
  stopifnot(Sx$ok)
  e <- estimate(Sx); data.table(parish_left_out = pc, estimate_pct = e$pct, p_value = pval(Sx, 0))
}))
save_csv(data.table(spec = "I4", parishes = nrow(loo), floor = round(1 / 30, 4), estimate_min_pct = round(min(loo$estimate_pct), 1),
                    estimate_max_pct = round(max(loo$estimate_pct), 1), p_min = round(min(loo$p_value), 4), p_max = round(max(loo$p_value), 4),
                    estimates_same_sign_as_A1 = sum(sign(loo$estimate_pct) == sign(res[id == "A1", estimate_pct]))),
         file.path(out, "leave_one_out.csv"))

# ---- Direction rule for A1 (sections 4.3 and 4.6) ----------------------------------------------------------
g <- function(k, col) res[id == k][[col]]
raw <- function(k) if (k == "J1") eJ$pct else estimate(specs[[k]][[2]])$pct  # unrounded, for the comparisons
a1 <- raw("A1"); sgn <- sign(a1)
further <- function(x) if (sgn < 0) a1 < x else a1 > x
cond1 <- sign(raw("J1")) == sgn
cond2r <- further(raw("C1")); cond2i <- further(raw("C6"))
cond3a <- sign(raw("J2")) == sgn; cond3b <- sign(raw("J3")) == sgn
drift_ok <- grepl("^passes", g("A1", "drift_rule")); rej <- g("A1", "rejects_5pct")
met <- cond1 && cond2r && cond2i && cond3a && cond3b
failed <- c(if (!rej) "the confirmatory test does not reject at the 5 percent level",
            if (!cond1) "condition 1: the continued-drift estimate (J1) has the other sign",
            if (!cond2r) "condition 2: the ring's estimate (C1) is as far or further in the same direction",
            if (!cond2i) "condition 2: the in-between zone's estimate (C6) is as far or further in the same direction",
            if (!cond3a) "condition 3: without night crashes (J2) the sign changes",
            if (!cond3b) "condition 3: without April and May 2024 (J3) the sign changes",
            if (!drift_ok) "the drift rule: the estimate does not lie beyond zero and beyond every forward fake effect in its direction")
dirword <- if (sgn < 0) "fall" else "rise"
wording <- if (!rej) {
  sprintf("no detectable change; the interval %s", g("A1", "rules_out_95"))
} else if (!drift_ok) {
  sprintf("a change of %.1f percent that cannot be told apart from the pre-period drift (a rule resting on one forward opening)", a1)
} else if (met) {
  sprintf("a %s of %.1f percent, 95 percent interval: %s", dirword, abs(a1), g("A1", "rules_out_95"))
} else {
  sprintf("a change of %.1f percent, 95 percent interval: %s, with no clear direction", a1, g("A1", "rules_out_95"))
}
ring_opposite <- sign(raw("C1")) == -sgn
save_csv(data.table(main_estimate_pct = round(a1, 1), p_value = g("A1", "p_value"), rejects_at_5pct = rej, drift_rule = g("A1", "drift_rule"),
                    cond1_continued_drift_same_sign = cond1, cond2_beyond_ring = cond2r, cond2_beyond_in_between_zone = cond2i,
                    cond3_without_night = cond3a, cond3_without_april_may = cond3b, direction_described = rej && drift_ok && met,
                    checks_that_failed = if (length(failed)) paste(failed, collapse = " | ") else "none",
                    ring_moves_opposite = ring_opposite, combined_treated_and_ring_pct = if (ring_opposite) g("C12", "estimate_pct") else NA_real_,
                    wording = wording, size_check_note = sprintf("10 percent size check: %s of %s placements reject (%s); one rejection fewer would have %s",
                      g("A1", "size_rejections_10"), g("A1", "size_placements"), g("A1", "size_check_10"),
                      if (gate(g("A1", "size_rejections_10") - 1, g("A1", "size_placements"), 0.10) == "passes") "passed" else "still failed")),
         file.path(out, "direction_rule.csv"))
save_csv(res, file.path(out, "estimates.csv"))
# ---- Described only (plan section 4; amendment section 3): secondary outcomes and stations one by one -----------
# Each against the distant parishes pooled, with the main specification's months. The estimate is given with the
# forward fake effects and the range of the inside placements' fake effects for context; no p-value or interval.
describe <- function(id, label, S) {
  if (!S$ok) return(data.table(id = id, label = label, note = "counts too small (a pre-period quarter with fewer than 5 crashes)"))
  e <- estimate(S); if (!is.finite(e$tau)) return(data.table(id = id, label = label, note = "estimate not defined"))
  ff <- fake_forward(S); sc <- size_check(S)
  data.table(id = id, label = label, estimate_pct = round(e$pct, 1),
             forward_fake_effects = if (length(ff)) paste(round(ff, 1), collapse = "; ") else "none",
             inside_fake_effects_range = if (sc[["n"]] > 0) sprintf("%.1f to %.1f", sc[["fmin"]], sc[["fmax"]]) else "none",
             note = "described only")
}
sec <- c(S1 = "pedestrian", S2 = "motorcycle", S3 = "bus", S4 = "bicycle")
stations <- sort(unique(pre$nearest_station)); stopifnot(length(stations) == 15L)
desc <- rbind(
  rbindlist(lapply(names(sec), function(k) describe(k, sprintf("Treated 1 km, %s crashes (any severity)", sec[[k]]), make_spec("treated", "distant", sec[[k]]))), fill = TRUE),
  rbindlist(lapply(seq_along(stations), function(i) rbindlist(list(
    describe(sprintf("ST%02d_injury", i), sprintf("Station %s, 1 km (nearest station), injury or fatal", stations[i]), make_spec(paste0("st:", stations[i]), "distant")),
    describe(sprintf("ST%02d_all", i), sprintf("Station %s, 1 km (nearest station), all crashes", stations[i]), make_spec(paste0("st:", stations[i]), "distant", "all"))), fill = TRUE)), fill = TRUE),
  fill = TRUE)
save_csv(desc, file.path(out, "described_only.csv"))

# ---- Recording composition by zone (plan section 8, rule 4): a diagnostic, reported next to the estimate ----------
# Share of records from non-territorial recording units: a squad or directorate by JEFATURA (plan: "JEFATURA type"),
# or a DISTRITO other than the five territorial districts (squads also appear under territorial districts). All
# crashes, pre-period January 2022 to November 2023 against P1. A share is withheld where either part has fewer than
# 5 records (condition 7). Counts are not published. Crash-ID format: whether every record carries a numeric ID.
TERR <- c("DISTRITO CENTRO", "DISTRITO NORTE", "DISTRITO SUR", "DISTRITO VALLES", "EJE VIAL")
stopifnot(!anyNA(d$distrito), !anyNA(d$jefatura))
d[, distrito_n := toupper(trimws(distrito))]
stopifnot(all(d$distrito_n %in% c(TERR, "GRUPOS OPERATIVOS", "DIRECCION DE FISCALIZACION", "SECRETARIA DE MOVILIDAD", "DIRECCION DE SEGURIDAD VIAL")))  # the audit's nine values
d[, non_territorial := !distrito_n %in% TERR |
    grepl("^GRUPO|GOMEPAP|FISCALIZACION|BICI|JUDICIAL|SEGURIDAD VIAL|SECRETARIA", toupper(trimws(jefatura)))]
rc <- d[fecha >= as.Date("2022-01-01") & zone %in% c("treated", "ring", "distant"),
        .(n = .N, k = sum(non_territorial), all_numeric_id = all(grepl("^[0-9]+$", crash_id))),
        by = .(zone, period = fifelse(fecha >= P1_START, "P1", "pre-period"))]
rc[, share_non_territorial_pct := fifelse(k >= 5 & n - k >= 5, round(100 * k / n, 1), NA_real_)]
rc[, note := fifelse(is.na(share_non_territorial_pct), "withheld: fewer than 5 records in one part", "")]
save_csv(rc[order(zone, -rank(period)), .(zone, period, share_non_territorial_pct, all_numeric_id, note)], file.path(out, "recording_composition.csv"))

save_csv(data.table(id = c("G1", "G2", "G6", "G7", "I1", "I2", "I5"),
                    reason = c("P2 (January 2025 to August 2026): not covered by the approval of 2026-10-01",
                               "P2 as calendar 2025: not covered by the approval",
                               "day-exact disruption window: the disruption (September to December 2024) lies after P1",
                               "recording blocks: none falls in the P1 panel with the 2022 start (October to December 2021 precede it; October 2024 and August 2025 follow P1)",
                               "merged into J1", "replaced by the calendar (J2, J3, G4)",
                               "full window with the disruption: the disruption lies after P1")), file.path(out, "not_run.csv"))

# ---- P1 counts by zone, rounded to 5 (context) ------------------------------------------------------------
pc <- d[t >= match(P1_START, ALL_M) & zone != "outside", .(crashes = .N), by = .(zone, severity = fifelse(injury_or_fatal, "injury or fatal", "damage only"))]
pc <- rbind(pc, d[t >= match(P1_START, ALL_M) & centro == TRUE, .(zone = "historic center", crashes = .N), by = .(severity = fifelse(injury_or_fatal, "injury or fatal", "damage only"))])
pc[, crashes := as.integer(5L * round(crashes / 5))]
save_csv(pc[order(zone, severity)], file.path(out, "p1_counts.csv"))

# ---- Figure: the main specification's indices, shocks marked -----------------------------------------------
S <- specs$A1[[2]]; Y <- build_Y(S, 0)
full_m <- ALL_M[ALL_M >= as.Date("2022-01-01")]  # left-out months as gaps, so the lines break there
fig <- data.table(month = rep(full_m, 2) + 14,  # mid-month, so the shock bars line up with the months they touch
 index = c(Y[2, ][match(full_m, S$per)], Y[1, ][match(full_m, S$per)]),
                  series = rep(c("Treated area (1 km of a station)", "Distant parishes (pooled)"), each = length(full_m)))
shocks <- data.table(x = as.Date(c("2022-06-13", "2023-10-27", "2024-01-08", "2024-04-16", "2024-06-28")),
                     xend = as.Date(c("2022-06-30", "2024-02-23", "2024-04-06", "2024-05-01", "2024-08-31")),
                     lab = c("Strike", "Power rationing", "Night curfew", "Power cuts", "Gasoline subsidy cut"))
shocks[, y := min(fig$index, na.rm = TRUE) - 0.04 * (seq_len(.N) %% 3 + 1)]  # spans drawn as bars below the series (amendment section 4.4)
pl <- ggplot(fig, aes(month, index, colour = series)) +
  annotate("rect", xmin = P1_START, xmax = P1_END, ymin = -Inf, ymax = Inf, alpha = 0.08) +
  geom_vline(data = shocks, aes(xintercept = x), linetype = "dotted", colour = "grey40", linewidth = 0.4) +
  geom_text(data = shocks, aes(x = x, y = Inf, label = lab), inherit.aes = FALSE, angle = 90, hjust = 1.1, vjust = -0.4, size = 2.6, colour = "grey30") +
  geom_segment(data = shocks, aes(x = x, xend = xend, y = y, yend = y), inherit.aes = FALSE, linewidth = 1.2, colour = "grey55") +
  geom_line(linewidth = 0.7, na.rm = TRUE) + geom_point(size = 1.3, na.rm = TRUE) +
  scale_colour_manual(values = c("#5B6B7A", "#C2410C")) +
  labs(x = NULL, y = "Monthly crashes / pre-period mean", colour = NULL,
       title = "Injury or fatal crashes: treated area and distant parishes",
       subtitle = "Shaded: P1 (Dec 2023 to Aug 2024). Gaps: June 2022 and November 2023, left out of the panel.\nGrey bars: how long each shock lasted (the gasoline subsidy cut continues past August 2024).\nPoints at mid-month.") +
  theme_minimal(base_size = 10) + theme(legend.position = "top")
stopifnot(all(S$Tc >= 5), all(S$C >= 5))  # monthly counts behind the figure are not small
ggsave(file.path(out, "main_series.png"), pl, width = 8, height = 4.2, dpi = 150)
save_csv(d[, .(share_no_recorded_time_pct = round(100 * mean(is.na(minute_of_day)), 1),
              share_at_00_00_pct = round(100 * mean(minute_of_day %in% 0L), 1)), by = .(period = fifelse(fecha >= P1_START, "P1", "pre-period"))],
         file.path(out, "missing_time_share.csv"))
writeLines(c(capture.output(sessionInfo()), paste("seed", SEED), paste("bootstrap draws", B),
             paste("rows read: pre-period", nrow(pre), "; P1", nrow(p1)), paste("latest date read", format(max(d$fecha)))),
           file.path(out, "session_info.txt"))
print(res[, .(id, estimate_pct, p_value, ci95_low, ci95_high, drift_rule, size_check_10, note)])
