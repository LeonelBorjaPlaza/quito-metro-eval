# Pool B diagnostics and comparison (Leonel, 2026-09-27). Pre-period only. Run from road_safety/
# after 04b_power_conformal.R has been run for pool B with both starts (see RUNBOOK):
#   Rscript code/06_pool_b.R
# Writes output/power/pool_b/: filters.csv (parishes removed by each filter and the donor count),
# fast_road_shares.csv (share of pre-period crashes on fast roads, donors against treated areas;
# diagnostic only, no exclusion), comparison.csv (donors, fake effect, conformal size check at 5 and
# 10 percent and MDEs for pool B next to O1 and O2, under the 2022 and 2021 starts).
source("code/helpers.R")
source("code/power_units.R")  # default start (January 2021): screens use the full pre-period
stopifnot(RUN_START == PRE_START, length(months) == 35L)
out <- "output/power/pool_b"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# 1. Filters, step by step (parish counts; the screen uses January 2021 to November 2023).
scr <- pre[!is.na(parish_code), .(mean = .N / length(months), months_with_crash = uniqueN(t_month)), by = parish_code]
scr[, `:=`(fails_mean = mean < MIN_DONOR_MEAN, fails_zero = 1 - months_with_crash / length(months) > MAX_DONOR_ZERO_SHARE)]
p <- merge(ptab[, .(parish_code, parish, urban, wholly_beyond_2km, brt_core_crosses_part_beyond_2km,
                    brt_any_crosses_part_beyond_2km)], scr, by = "parish_code", all.x = TRUE)
p[is.na(mean), `:=`(mean = 0, fails_mean = TRUE, fails_zero = TRUE)]
s0 <- p
s1 <- s0[wholly_beyond_2km == TRUE]
s2 <- s1[brt_core_crosses_part_beyond_2km == FALSE]
s3 <- s2[fails_mean == FALSE & fails_zero == FALSE]
s4 <- s3[brt_any_crosses_part_beyond_2km == FALSE]
filters <- data.table(
  step = c("all parishes (GeoQuito polygons)", "not entirely beyond 2 km of the line",
           "crossed by the Trolebus or Ecovia trunk (more than 100 m inside)",
           "volume screen (fewer than 3 crashes a month, or more than 20 percent of months with none)",
           "primary pool B (donors)", "sensitivity: crossed by the Central Norte MetroBus",
           "pool B without Central Norte-crossed donors"),
  parishes_removed = c(NA, nrow(s0) - nrow(s1), nrow(s1) - nrow(s2), nrow(s2) - nrow(s3), NA, nrow(s3) - nrow(s4), NA),
  parishes_left = c(nrow(s0), nrow(s1), nrow(s2), nrow(s3), nrow(s3), nrow(s4), nrow(s4)),
  urban_left = c(sum(s0$urban), sum(s1$urban), sum(s2$urban), sum(s3$urban), sum(s3$urban), sum(s4$urban), sum(s4$urban)))
stopifnot(setequal(s3$parish, unique(donor_sets_b$B_parishes_beyond_2km$unit)),
          setequal(s4$parish, unique(donor_sets_b$B_no_central_norte$unit)))
save_csv(filters, file.path(out, "filters.csv"))
screen_detail <- s2[, .(parish, urban, pre_crashes_per_month = round(mean, 2), fails_mean, fails_zero,
                        passes_screen = !fails_mean & !fails_zero)][order(-pre_crashes_per_month)]
screen_detail[, pre_crashes_per_month := fifelse(pre_crashes_per_month * length(months) < 5, NA_real_, pre_crashes_per_month)]
save_csv(screen_detail, file.path(out, "screen_detail.csv"))

# 2. Fast-road shares (diagnostic): donors of pool B against the treated areas, pre-period.
# The flag is name-based (a fast road named in PRINCIPAL or SECUNDARIA) and has not been checked against
# road geometry. Shares that correspond to 1 to 4 crashes are withheld (small cells).
small <- function(k, n) fifelse(k >= 1L & k <= 4L, NA_real_, round(k / n, 3))
fr <- function(d, label, kind) d[, .(unit = label, kind = kind, pre_crashes = .N,
                                     share_fast_road = small(sum(fast_road), .N),
                                     share_av_mariscal_sucre = small(sum(av_mariscal_sucre), .N))]
shares <- rbind(
  fr(pre[catchment_1km == TRUE], "station catchments 1 km (pooled)", "treated"),
  fr(pre[catchment_500 == TRUE], "station catchments 500 m (pooled)", "treated"),
  fr(pre[corridor_500 == TRUE], "corridor 500 m of line", "treated"),
  rbindlist(lapply(sort(s3$parish), function(x)
    fr(pre[parroquia_polygon == x], x, fifelse(x %in% s4$parish, "donor (pool B)", "donor (pool B; Central Norte-crossed)")))))
save_csv(shares, file.path(out, "fast_road_shares.csv"))

# 3. Comparison of pools under both starts (conformal inference, level-shift statistic).
size_fails <- function(null_rej, n_open, alpha) if (n_open == 1L) null_rej > 0 else null_rej > max(alpha, 1 / n_open)
cmp <- rbindlist(lapply(c(start2022 = "2022-01", start2021 = "2021-01"), function(st) {
  tag <- paste0("pool_b_start", substr(st, 1, 4))
  x <- fread(file.path("output/power", tag, "conformal_mde_table.csv"))
  x[, pre_start := st]
}))
cmp <- cmp[statistic == "abs_mean" & outcome %in% c("all_crashes", "injury_or_fatal")]
runs <- rbindlist(lapply(c(start2022 = "2022-01", start2021 = "2021-01"), function(st) {
  x <- fread(file.path("output/power", paste0("pool_b_start", substr(st, 1, 4)), "conformal_power_curves.csv"))
  x[statistic == "abs_mean" & delta == 0.05, .(pre_start = st, treated, outcome, pool, variant, runs_per_effect_size = runs)]
}))
cmp <- merge(cmp, runs, by = c("pre_start", "treated", "outcome", "pool", "variant"))
# With n fake openings a design passes when at most max(alpha, 1/n) of them reject with no effect; with
# n = 3 (2022 start) one rejection in three passes, and n < 1/alpha in every run here, so "passes" is weak.
cmp[, `:=`(size_check_05 = fifelse(mapply(size_fails, null_rejection_05, fake_openings, 0.05), "fails", "passes"),
           size_check_10 = fifelse(mapply(size_fails, null_rejection_10, fake_openings, 0.10), "fails", "passes"),
           null_rejections_05 = paste(round(null_rejection_05 * fake_openings), "of", fake_openings),
           null_rejections_10 = paste(round(null_rejection_10 * fake_openings), "of", fake_openings))]
cmp <- cmp[, .(pre_start, treated, outcome, pool, J, weights = variant, fake_openings, T_min,
               fake_effect_mean_pct, fake_effect_min_pct, fake_effect_max_pct,
               null_rejections_05, size_check_05, null_rejections_10, size_check_10, runs_per_effect_size,
               mde_decrease_05_pct, mde_increase_05_pct, mde_decrease_10_pct, mde_increase_10_pct)]
pool_order <- c("B_parishes_beyond_2km", "B_no_central_norte", "O1_urban_parish_parts_beyond_2km", "O2_O1_plus_rural_parish_parts")
cmp <- cmp[order(-rank(pre_start), treated, outcome, match(pool, pool_order), weights)]
save_csv(cmp, file.path(out, "comparison.csv"))
print(filters)
print(shares)
print(cmp[treated == "pooled_1km", .(pre_start, outcome, pool = substr(pool, 1, 12), J, weights, fake_effect_mean_pct,
                                    null_rejections_05, null_rejections_10, runs_per_effect_size,
                                    mde_decrease_05_pct, mde_increase_05_pct, mde_decrease_10_pct, mde_increase_10_pct)])
