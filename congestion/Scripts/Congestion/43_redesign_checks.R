# Amendment 5, items 7 and 8 (pre-period parts), with the contest winner and the decided scale.
#  1. CENTER's June to October 2023 forecast errors (fit on usable months to May 2023) against every
#     placebo tile's errors for the same months; the same on the other scale, to see whether the drift
#     survives the change of scale. The CENTER piece is also the anchored estimate's pre-period part.
#  2. Size of the CWZ test on placebo tiles: statistic |mean residual| over a 6-month pseudo-P1, circular
#     shifts of the residual sequence, model refit on all periods under the null; pseudo-openings placed
#     so that T >= 20 (usable months 15-20 with T = 20, and 16-21 with T = 21). Rejection at 5 percent.
#  3. Empirical MDE from nine-month placebo forecast errors (fit on usable months 1-12, forecast 13-21).
#  4. Rings: rolling-origin forecast errors against the main donor tiles.
#  5. Jam speed: how CENTER's main index and jam-speed index move together (pre period).
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
source("Scripts/Congestion/redesign_forecast.R")
u <- readRDS(file.path(REDESIGN_DATA, "units.rds"))
contest <- fread(file.path(REDESIGN_OUT, "contest_decision.csv"))
contest_overall <- fread(file.path(REDESIGN_OUT, "contest_overall.csv"))
SCALE <- u$scale$decision; METHOD <- contest$winner
OTHER_SCALE <- setdiff(c("levels", "proportions"), SCALE)
main <- u$unit_meta[type == "donor tile", unit]
N_CORES <- 4L
# Parallel map that stops if a worker died (check_parallel in redesign_helpers.R).
pml <- function(X, FUN) { r <- parallel::mclapply(X, FUN, mc.cores = N_CORES); check_parallel(r, length(X)); r }

# 1. CENTER against the placebo tiles, June to October 2023.
FIT_TO_MAY23 <- USABLE_MONTHS[USABLE_MONTHS <= 202305L]
JUN_OCT23 <- USABLE_MONTHS[USABLE_MONTHS >= 202306L]
stopifnot(identical(JUN_OCT23, c(202306L, 202307L, 202308L, 202309L, 202310L)))
mats_c <- level_mats(u$series, c("CENTER", main))
holdout <- rbindlist(lapply(c(SCALE, OTHER_SCALE), function(sc) rbindlist(c(
  list(forecast_one(METHOD, "CENTER", main, mats_c, FIT_TO_MAY23, JUN_OCT23, sc)[, unit := "CENTER"]),
  pml(main, function(t) forecast_one(METHOD, t, setdiff(main, t), mats_c, FIT_TO_MAY23, JUN_OCT23, sc)[, unit := t])))[, scale := sc]))
hs <- holdout[, .(mean_error = mean(error), rmse = sqrt(mean(error^2)), mean_error_index_points = mean(error_index_points),
                  negative_months = sum(error < 0)), by = .(scale, unit)]
center_place <- hs[, {
  c0 <- .SD[unit == "CENTER"]; p <- .SD[unit != "CENTER"]
  .(center_mean_error = c0$mean_error, center_rmse = c0$rmse, center_mean_error_index_points = c0$mean_error_index_points,
    center_negative_months = c0$negative_months, tiles = nrow(p),
    tiles_mean_error_at_or_below_center = sum(p$mean_error <= c0$mean_error),
    tiles_abs_mean_error_at_least_center = sum(abs(p$mean_error) >= abs(c0$mean_error)),
    tiles_rmse_at_least_center = sum(p$rmse >= c0$rmse),
    tile_mean_error_min = min(p$mean_error), tile_mean_error_median = median(p$mean_error), tile_mean_error_max = max(p$mean_error))
}, by = scale]

# 2. CWZ size check on placebo tiles (pre period only).
cwz_stat <- function(resid, post_idx) abs(mean(resid[post_idx]))
cwz_p <- function(resid, post_idx) {
  T <- length(resid); s0 <- cwz_stat(resid, post_idx)
  s <- vapply(0:(T - 1), function(k) cwz_stat(resid[((seq_len(T) - 1 + k) %% T) + 1], post_idx), 0)
  mean(s >= s0 - 1e-12)
}
null_residuals <- function(target, donors, mats, months, scale) {
  # Under the sharp null the model is refit on all T periods; residuals are actual minus synthetic.
  fm <- as.character(months); units <- c(target, donors)
  P <- scale_block(mats$peak[units, , drop = FALSE], months, scale)
  S <- cbind(scale_block(mats$morning[units, , drop = FALSE], months, scale)[, fm, drop = FALSE],
             scale_block(mats$evening[units, , drop = FALSE], months, scale)[, fm, drop = FALSE])
  colnames(S) <- c(paste0("m", fm), paste0("e", fm))
  stopifnot(METHOD == "sc")   # the size check is defined for the contest winner; extend if another wins
  w <- fit_asc(S[target, ], S[donors, , drop = FALSE], colnames(S), NULL, method = "scm")$weights[donors]
  P[target, fm] - colSums(w * P[donors, fm, drop = FALSE])
}
OPENINGS <- list(list(months = USABLE_MONTHS[1:20], post = 15:20), list(months = USABLE_MONTHS[1:21], post = 16:21))
cwz <- rbindlist(pml(main, function(t) rbindlist(lapply(seq_along(OPENINGS), function(k) {
  o <- OPENINGS[[k]]
  r <- null_residuals(t, setdiff(main, t), mats_c, o$months, SCALE)
  p <- cwz_p(r, o$post)
  data.table(unit = t, opening = k, T = length(o$months), pseudo_p1 = paste(range(o$months[o$post]), collapse = "-"),
             p_value = p, smallest_attainable_p = 1 / length(o$months), reject_5pct = p <= 0.05)
}))))
# Leonel, 2026-10-01: each opening is judged on its own against the 10 percent rule; the pooled row does not count.
cwz_summary <- cwz[, .(tests = .N, rejections_5pct = sum(reject_5pct), rejection_rate = mean(reject_5pct)), by = .(T, smallest_attainable_p)]
cwz_summary[, rule := sprintf("one pseudo-opening: %d of %d rejected; %s the 10 percent rule", rejections_5pct, tests,
                              fifelse(rejection_rate <= 0.10, "meets", "fails"))]
cwz_summary <- rbind(cwz_summary, cwz[, .(T = NA_integer_, smallest_attainable_p = NA_real_, tests = .N, rejections_5pct = sum(reject_5pct),
                                           rejection_rate = mean(reject_5pct), rule = "pooled after seeing the results; does not count (Leonel, 2026-10-01)")])

# 3. Empirical MDE: nine-month mean forecast errors of placebo tiles.
FIT12 <- USABLE_MONTHS[1:12]; FC9 <- USABLE_MONTHS[13:21]
nine <- rbindlist(pml(main, function(t) forecast_one(METHOD, t, setdiff(main, t), mats_c, FIT12, FC9, SCALE)[, unit := t]))
ebar <- nine[, .(mean_error = mean(error)), by = unit]$mean_error
crit <- unname(quantile(abs(ebar), 0.95, type = 7))
power_at <- function(d) mean(abs(ebar + d) > crit)
grid_d <- seq(0, 3 * max(abs(ebar)) + crit, length.out = 4001)
mde_red <- grid_d[which(vapply(-grid_d, power_at, 0) >= 0.8)[1]]
mde_inc <- grid_d[which(vapply(grid_d, power_at, 0) >= 0.8)[1]]
center_mean <- u$pre_means[unit == "CENTER" & block == "peak", pre_mean]
mde <- data.table(scale = SCALE, method = METHOD, tiles = length(ebar), fit_months = "usable months 1-12 (2022-01 to 2023-01, June 2022 out)",
  forecast_months = paste(range(FC9), collapse = " to "), mean_error_sd = sd(ebar), critical_value_q95_abs = crit,
  mde_reduction = mde_red, mde_increase = mde_inc, center_pre_mean = center_mean,
  mde_reduction_index_points = if (SCALE == "proportions") mde_red * center_mean else mde_red,
  mde_increase_index_points = if (SCALE == "proportions") mde_inc * center_mean else mde_inc,
  definition = "smallest shift d with share of tiles |mean error + d| > c at least 0.8, c = 95th percentile of |mean error|; two-sided 5 percent, power 0.80, empirical over placebo tiles")

# 4. Rings: rolling-origin forecasts (same cut-offs and horizons as the contest) against the main tiles.
ring_units <- u$unit_meta[type == "ring" & complete == TRUE, unit]
mats_r <- level_mats(u$series, c(ring_units, main))
ring_jobs <- CJ(target = ring_units, cutoff = 12:20)
ring_fc <- rbindlist(pml(seq_len(nrow(ring_jobs)), function(i) {
  j <- ring_jobs[i]; fit_m <- USABLE_MONTHS[seq_len(j$cutoff)]
  fc_m <- USABLE_MONTHS[(j$cutoff + 1):min(j$cutoff + 3, length(USABLE_MONTHS))]
  cbind(j, forecast_one(METHOD, j$target, main, mats_r, fit_m, fc_m, SCALE))
}))
ring_fc <- merge(ring_fc, u$unit_meta[, .(target = unit, ring, segment)], by = "target")
ring_summary <- ring_fc[, .(units = uniqueN(target), forecasts = .N, mse = mean(error^2), mean_signed_error = mean(error)), by = .(ring, segment)]
ring_summary <- rbind(ring_summary, data.table(ring = "placebo donor tiles (contest)", segment = "all",
  units = length(main), forecasts = NA_integer_, mse = contest_overall[method == METHOD, mse],
  mean_signed_error = contest_overall[method == METHOD, mean_signed_error]))

# 5. Jam speed against the main index within CENTER and the tiles (pre period, usable months).
sp <- merge(u$speed[date %in% USABLE_MONTHS], data.table(unit = c("CENTER", main)), by = "unit")
sp_cor <- sp[, .(months_with_speed = sum(!is.na(speed)), cor_levels = cor(value, speed, use = "complete.obs")), by = unit]
speed_summary <- data.table(center_months_with_speed = sp_cor[unit == "CENTER", months_with_speed],
  center_cor_index_speed = sp_cor[unit == "CENTER", cor_levels],
  tiles_median_cor_index_speed = median(sp_cor[unit != "CENTER", cor_levels], na.rm = TRUE),
  tiles_with_all_21_speed_months = sp_cor[unit != "CENTER", sum(months_with_speed == 21L)])

saveRDS(list(holdout = holdout, center_place = center_place, cwz = cwz, nine = nine, mde = mde, ring_fc = ring_fc,
             ring_summary = ring_summary, speed = sp_cor), file.path(REDESIGN_DATA, "checks.rds"))
fwrite(center_place, file.path(REDESIGN_OUT, "check_center_vs_placebo_jun_oct_2023.csv"))
fwrite(holdout[unit == "CENTER", .(scale, month, actual, forecast, error, error_index_points, fit_mean)], file.path(REDESIGN_OUT, "check_center_jun_oct_2023_paths.csv"))
fwrite(cwz_summary, file.path(REDESIGN_OUT, "check_cwz_size.csv"))
fwrite(mde, file.path(REDESIGN_OUT, "mde_empirical.csv"))
# Distribution behind the MDE (aggregates only, so the report's figures trace to a committed file).
eb <- nine[, .(abs_mean_error = abs(mean(error)), fit_mean = fit_mean[1]), by = unit]
fwrite(data.table(tiles = nrow(eb),
  abs_mean_error_median = median(eb$abs_mean_error), abs_mean_error_p75 = unname(quantile(eb$abs_mean_error, 0.75)),
  abs_mean_error_p90 = unname(quantile(eb$abs_mean_error, 0.90)), abs_mean_error_max = max(eb$abs_mean_error),
  abs_mean_error_second_largest = sort(eb$abs_mean_error, decreasing = TRUE)[2],
  tile_fit_mean_min = min(eb$fit_mean), tile_fit_mean_median = median(eb$fit_mean), tile_fit_mean_max = max(eb$fit_mean),
  center_pre_mean_usable_months = center_mean,
  note = "fit means are over usable months 1-12; CENTER's mean is over all 21 usable months"),
  file.path(REDESIGN_OUT, "mde_empirical_distribution.csv"))
fwrite(ring_summary, file.path(REDESIGN_OUT, "check_rings_forecast.csv"))
fwrite(speed_summary, file.path(REDESIGN_OUT, "check_speed.csv"))
print(center_place); print(cwz_summary); print(mde); print(ring_summary); print(speed_summary)
