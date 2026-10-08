# Candidate designs (Leonel, 2026-09-27): tables for the choice among pool B, composite donors (C),
# the urban-street outcome and the gradient design. Pre-period only, January 2022 start.
# Run from road_safety/ after the candidates run of 04b_power_conformal.R (see RUNBOOK):
#   Rscript code/07_candidates.R
# Writes output/power/candidates/:
#   composites.csv, composites_dropped.csv  the composite donors built by code/composites.R
#   donor_counts.csv          donors per pool
#   urban_street_removed.csv  crashes removed by the urban-street outcomes, per treated area and donor
#   weights.csv, fit_monthly.csv, fit_summary.csv  donor weights and pre-period fit (all 23 months)
#   comparison.csv            fake effect, size check (15 placements; the 3 forward ones as a subset), MDEs
source("code/helpers.R")
suppressPackageStartupMessages(library(synthdid))
Sys.setenv(RS_PRE_START = "2022-01-01")  # composites and screens still use January 2021 to November 2023
source("code/power_units.R")
stopifnot(RUN_START == as.Date("2022-01-01"), length(months) == 23L)
out <- "output/power/candidates"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
small <- function(k) fifelse(k >= 1L & k <= 4L, NA_integer_, k)  # counts of 1 to 4 withheld

# 1. Composites and donor counts.
save_csv(composites, file.path(out, "composites.csv"))
save_csv(composite_dropped, file.path(out, "composites_dropped.csv"))
pools <- c("B_parishes_beyond_2km", "B_no_central_norte", "C_pool_b_plus_composites", "C_no_central_norte",
           "O1_urban_parish_parts_beyond_2km", "O2_O1_plus_rural_parish_parts")
all_sets <- c(donor_sets, donor_sets_b, donor_sets_c)
save_csv(data.table(pool = pools, donors = vapply(pools, function(p) uniqueN(all_sets[[p]]$unit), 0L),
                     smallest_rank_p_in_space = round(1 / (vapply(pools, function(p) uniqueN(all_sets[[p]]$unit), 0L) + 1), 4)),
         file.path(out, "donor_counts.csv"))

# 2. Crashes removed by the urban-street outcomes (January 2022 to November 2023).
removed <- function(d, unit_label, kind) d[, .(
  unit = unit_label, kind = kind, all_crashes = small(.N),
  removed_fast_road = small(sum(!urban_street_all)), removed_fast_road_or_mariscal_sucre = small(sum(!urban_street_nms_all)),
  injury_or_fatal = small(sum(injury_or_fatal)),
  injury_removed_fast_road = small(sum(injury_or_fatal & !urban_street_injury)),
  injury_removed_fast_road_or_mariscal_sucre = small(sum(injury_or_fatal & !urban_street_nms_injury)))]
# The "or Mariscal Sucre" columns are withheld where their difference from the fast-road column is
# 1 to 4 (a withheld count would otherwise be recoverable by subtraction; code review pass 5).
hide_diff <- function(d) d[, `:=`(
  removed_fast_road_or_mariscal_sucre = fifelse(between(removed_fast_road_or_mariscal_sucre - removed_fast_road, 1L, 4L) |
                                                  is.na(removed_fast_road), NA_integer_, removed_fast_road_or_mariscal_sucre),
  injury_removed_fast_road_or_mariscal_sucre = fifelse(between(injury_removed_fast_road_or_mariscal_sucre - injury_removed_fast_road, 1L, 4L) |
                                                         is.na(injury_removed_fast_road), NA_integer_, injury_removed_fast_road_or_mariscal_sucre))][]
dc <- donor_sets_c$C_pool_b_plus_composites
rem <- rbind(removed(treated_sets$pooled_1km, "station catchments 1 km (pooled)", "treated"),
             removed(donor_sets_g$G_outer_ring_1_2km, "ring 1 to 2 km from the nearest station", "gradient outer band"),
             rbindlist(lapply(sort(unique(dc$unit)), function(u)
               removed(dc[unit == u], u, fifelse(grepl("^COMPOSITE", u), "donor (composite)", "donor (pool B)")))))
# Cross-table rule (verifier on 0210ed2): output/power/pool_b/fast_road_shares.csv gives January 2021
# to November 2023 counts, so a 2022-2023 cell here would reveal its 2021 counterpart by subtraction.
# A cell is withheld when that 2021 counterpart is 1 to 4.
y21 <- pre[fecha < RUN_START]
rows21 <- function(u) {
  if (u == "station catchments 1 km (pooled)") return(y21[catchment_1km == TRUE])
  if (u == "ring 1 to 2 km from the nearest station") return(y21[dist_station_m >= 1000 & dist_station_m < 2000])
  if (grepl("^COMPOSITE", u)) return(y21[parish_code %in% comp_groups[[match(u, vapply(comp_groups, comp_name, ""))]]])
  stopifnot(u %in% y21$parroquia_polygon | u %in% ptab$parish)
  y21[parroquia_polygon == u]
}
hide_2021 <- function(d) {
  d <- copy(d)
  small21 <- function(k) k >= 1L & k <= 4L
  for (i in seq_len(nrow(d))) {
    r <- rows21(d$unit[i]); inj <- r[injury_or_fatal == TRUE]
    if (small21(nrow(r))) set(d, i, "all_crashes", NA_integer_)
    if (small21(sum(r$fast_road))) set(d, i, "removed_fast_road", NA_integer_)
    if (small21(sum(r$fast_road | r$av_mariscal_sucre)) || small21(sum(r$av_mariscal_sucre)))
      set(d, i, "removed_fast_road_or_mariscal_sucre", NA_integer_)
    if (small21(nrow(inj))) set(d, i, "injury_or_fatal", NA_integer_)
    if (small21(sum(inj$fast_road))) set(d, i, "injury_removed_fast_road", NA_integer_)
    if (small21(sum(inj$fast_road | inj$av_mariscal_sucre)) || small21(sum(inj$av_mariscal_sucre)))
      set(d, i, "injury_removed_fast_road_or_mariscal_sucre", NA_integer_)
  }
  d
}
save_csv(hide_diff(hide_2021(rem)), file.path(out, "urban_street_removed.csv"))

# 3. Donor weights and pre-period fit on all 23 months: synthetic control with an intercept, as in
# 04b_power_conformal.R (weights_of, same zeta rule with H = 9), and equal (DID) weights.
weights_of <- function(Y, cols, variant, H) {  # identical to 04b_power_conformal.R
  n <- nrow(Y)
  if (variant == "did") return(rep(1 / (n - 1L), n - 1L))
  noise <- sd(apply(Y[-n, cols, drop = FALSE], 1, diff))
  zeta <- H^(1 / 4) * noise
  synthdid:::sc.weight.fw(t(Y[, cols, drop = FALSE]), zeta = zeta, intercept = TRUE,
                          min.decrease = 1e-5 * noise, max.iter = 10000)$lambda
}
fit_pools <- c("B_parishes_beyond_2km", "C_pool_b_plus_composites")
fit_outcomes <- c("all_crashes", "injury_or_fatal", "urban_street_all", "urban_street_injury")
wt <- list(); fm <- list(); fs <- list()
for (p in fit_pools) for (oc in fit_outcomes) for (v in c("sc", "did")) {
  C <- count_matrix(treated_sets$pooled_1km, all_sets[[p]], oc, "month")
  base <- rowMeans(C); keep <- base > 0
  Y <- (C / base)[keep, , drop = FALSE]
  w <- weights_of(Y, seq_len(ncol(Y)), v, 9L)
  synth0 <- colSums(w * Y[-nrow(Y), , drop = FALSE])
  gap <- Y[nrow(Y), ] - synth0
  synth <- synth0 + mean(gap)  # with the intercept, so the fitted series has the treated mean
  if (v == "sc") wt[[length(wt) + 1L]] <- data.table(pool = p, outcome = oc, donor = rownames(Y)[-nrow(Y)],
                                                      weight = round(w, 4))
  # Monthly series only for all crashes and injury or fatal crashes: with the published totals, an
  # urban-street index would reveal monthly fast-road counts of 1 to 4 (re-verification of 85f1e93).
  if (oc %in% c("all_crashes", "injury_or_fatal")) fm[[length(fm) + 1L]] <- data.table(pool = p, outcome = oc, variant = v, month = format(months),
                                      treated_index = round(Y[nrow(Y), ], 3), synthetic_index = round(synth, 3))
  fs[[length(fs) + 1L]] <- data.table(pool = p, outcome = oc, variant = v, donors_used = nrow(Y) - 1L,
                                      donors_dropped_zero_mean = sum(!keep),
                                      rmse_of_gap = round(sqrt(mean((gap - mean(gap))^2)), 3),
                                      correlation = round(cor(Y[nrow(Y), ], synth), 3),
                                      donors_weight_over_5pct = sum(w > 0.05),
                                      largest_weight = round(max(w), 3),
                                      largest_weight_donor = rownames(Y)[which.max(w)])
}
save_csv(rbindlist(wt)[order(pool, outcome, -weight)], file.path(out, "weights.csv"))
save_csv(rbindlist(fm), file.path(out, "fit_monthly.csv"))
save_csv(rbindlist(fs), file.path(out, "fit_summary.csv"))

# 4. Comparison table (conformal route, level-shift statistic, 1 km catchments, P1).
tab <- fread("output/power/candidates_2022/conformal_mde_table.csv")[statistic == "abs_mean"]
nul <- fread("output/power/candidates_2022/conformal_placebo_in_time_null.csv")[statistic == "abs_mean"]
stopifnot(all(tab$fake_openings == 15L), all(tab$openings_run == 15L), all(tab$treated == "pooled_1km"))
# The forward subset comes from a forward-mode run (training before the window only, T = 21 to 23).
nul_fwd <- fread("output/power/candidates_2022_forward/conformal_placebo_in_time_null.csv")[statistic == "abs_mean"]
stopifnot(setequal(unique(nul_fwd$fake_open), 13:15))
fwd <- nul_fwd[, .(forward_rejections_05 = sprintf("%d of %d", sum(p <= 0.05), .N),
                   forward_rejections_10 = sprintf("%d of %d", sum(p <= 0.10), .N)),
               by = .(treated, pool, outcome, variant)]
n_tab <- nrow(tab)
tab <- merge(tab, fwd, by = c("treated", "pool", "outcome", "variant"))
stopifnot(nrow(tab) == n_tab)
tab[, `:=`(rej05 = round(null_rejection_05 * fake_openings), rej10 = round(null_rejection_10 * fake_openings))]
size_fails <- function(k, n, alpha) k / n > max(alpha, 1 / n)
cmp <- tab[, .(
  design = fcase(pool %like% "^G_", "gradient (inner 0-1 km minus outer 1-2 km), conformal",
                 pool %like% "^C_", "composite donors", pool %like% "^B_", "pool B", default = "earlier pool"),
  pool, outcome, variant, donors = J, fake_effect_mean_pct, fake_effect_min_pct, fake_effect_max_pct,
  null_rejections_05 = sprintf("%d of %d", rej05, fake_openings), null_rejections_10 = sprintf("%d of %d", rej10, fake_openings),
  size_check_05 = fifelse(size_fails(rej05, fake_openings, 0.05), "fails", "passes"),
  size_check_10 = fifelse(size_fails(rej10, fake_openings, 0.10), "fails", "passes"),
  forward_rejections_05, forward_rejections_10, runs_per_effect_size = fake_openings * 10L,
  smallest_p_simulated = smallest_attainable_p_worst_case,
  mde_decrease_05_pct, mde_increase_05_pct, mde_decrease_10_pct, mde_increase_10_pct)]
grad <- "output/power/gradient/gradient_rows.csv"  # from 08_gradient.R (run before this script)
if (file.exists(grad)) cmp <- rbind(cmp, fread(grad), fill = TRUE) else {
  warning("gradient rows missing: output/power/gradient/gradient_rows.csv (run 08_gradient.R first)")
  cmp <- rbind(cmp, data.table(design = "gradient (inner 0-1 km minus outer 1-2 km), placebo corridors",
                               pool = "placebo corridors: 08_gradient.R not run"), fill = TRUE)
}
cmp[, passes_both_size_checks := size_check_05 %in% "passes" & size_check_10 %in% "passes"]
setorder(cmp, outcome, design, pool, variant)
save_csv(cmp, file.path(out, "comparison.csv"))
print(cmp[outcome %in% c("injury_or_fatal", "urban_street_injury"),
          .(pool = substr(pool, 1, 12), outcome, variant, donors, fake_effect_mean_pct, null_rejections_05, null_rejections_10,
            mde_decrease_05_pct, mde_increase_05_pct)])
