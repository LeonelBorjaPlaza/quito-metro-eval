# Item D.2: four pre-period drift checks, reported without changing the primary specification.
# (a) June to November 2022 as a fake window, trained on the other 17 pre-period months, penalty frozen
#     from the training-period tuning in 33 (June 2022 was the month of the national strike).
# (b) June to November 2023 holdout gaps by month for CORRIDOR and BELISARIO (from 33).
# (c) The backdated fit with June 2023 as treatment date is the holdout itself (Amendment 4, item 7).
# (d) Observation density: valid delivered hour slots per cell-month (all 24 hours, as in the donor
#     eligibility rule) for the heaviest donors and for the CENTER cells, January 2022 to November 2023.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
pn <- readRDS(file.path(AMEND2_DATA, "panel.rds"))
ft <- readRDS(file.path(AMEND2_DATA, "fits.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
r <- pn$rules$amended
FAKE <- as.integer(c(202206, 202207, 202208, 202209, 202210, 202211))
POOLS <- c("primary_screened", "primary_unscreened")

# (a) Fake window. The frozen penalty was tuned on January 2022 to May 2023, which contains this window,
# so the check is not out of sample for tuning. Weights, unit intercepts and the ridge step depend only on
# the fitting months, not on their order, so the window can be predicted from months on both sides
# (checked with check_order_invariance_1e6 from amend2_helpers.R).
target_y <- function(u) { x <- r$series[unit == u & block == "peak"][order(date)]; setNames(x$value, x$date) }
fake <- rbindlist(lapply(c("CENTER", "BELISARIO_RW", "CORRIDOR"), function(u) rbindlist(lapply(POOLS, function(p) {
  f <- ft$fits[[paste("amended", p, u, sep = "|")]]
  y1 <- target_y(u); Y0 <- r$Y0_all[f$donors, , drop = FALSE]
  fit_m <- available(y1, setdiff(PRE_MONTHS, FAKE)); win <- available(y1, FAKE)
  check_order_invariance_1e6(y1, Y0, fit_m, win, f$lambda)
  rbindlist(list(
    fit_asc(y1, Y0, fit_m, win, f$lambda)$path[, estimator := "ascm"],
    fit_asc(y1, Y0, fit_m, win, method = "scm")$path[, estimator := "scm"]))[, `:=`(target = u, pool = p, lambda = f$lambda)]
}))))
fake[, strike_month := month == 202206L]
fake_stats <- fake[period == "post", .(n = .N, rmse = rmse(gap), bias = mean(gap), bias_without_june = mean(gap[!strike_month]),
  rmse_without_june = rmse(gap[!strike_month]), gap_june = if (any(strike_month)) gap[strike_month] else NA_real_, same_sign = length(unique(sign(gap))) == 1L),
  by = .(target, pool, estimator)]
fake_fit <- fake[period == "fit", .(train_rmspe = rmse(gap)), by = .(target, pool, estimator)]
fake_stats <- merge(fake_stats, fake_fit, by = c("target", "pool", "estimator"))

# (b) and (c) Holdout gaps by month (augsynth, plain SCM and DiD), June to November 2023.
holdout_gaps <- ft$paths[rule == "amended" & fit == "holdout" & period == "post" & pool %in% POOLS,
                         .(target, pool, estimator, month, actual, synthetic, gap)]
holdout_stats <- ft$comparison[rule == "amended" & fit == "holdout" & pool %in% POOLS,
                               .(target, pool, estimator, holdout_rmse, holdout_bias)]

# (d) Observation density.
slots <- CJ(grid_id = unique(r$slots$grid_id), date = PRE_MONTHS)
slots <- r$slots[slots, on = .(grid_id, date)][is.na(n), n := 0L]
slope_per_year <- function(n, d) { t <- seq_along(d) / 12; unname(coef(lm(n ~ t))[2]) }  # descriptive slope only, no test
density_donors <- rbindlist(lapply(POOLS, function(p) {
  w <- ft$weights[rule == "amended" & pool == p & target == "CENTER" & estimator == "ascm" & fit == "full pre"]
  top <- w[order(-abs(effective_weight))][1:10]
  x <- slots[grid_id %in% top$grid_id][order(grid_id, date)]
  s <- x[, .(slots_first6 = mean(n[date <= 202206L]), slots_last6 = mean(n[date >= 202306L]),
             slope_per_year = slope_per_year(n, date), min_slots = min(n), max_slots = max(n)), by = grid_id]
  merge(top[, .(pool = p, grid_id, effective_weight)], s, by = "grid_id")[order(-abs(effective_weight))]
}))
cw <- geog$unit_cells[unit == "CENTER" & kept == TRUE, .(grid_id, weight)]
density_monthly <- rbindlist(list(
  merge(slots[grid_id %in% cw$grid_id], cw, by = "grid_id")[, .(series = "CENTER cells, road-weighted mean",
    slots = sum(weight * n), min_cell = min(n)), by = date],
  rbindlist(lapply(POOLS, function(p) {
    top <- density_donors[pool == p]
    merge(slots[grid_id %in% top$grid_id], top[, .(grid_id, a = abs(effective_weight) / sum(abs(effective_weight)))], by = "grid_id")[,
      .(series = paste("10 heaviest donors, |weight|-weighted mean,", p), slots = sum(a * n), min_cell = min(n)), by = date]
  }))))[order(series, date)]
density_summary <- density_monthly[, .(slots_first6 = mean(slots[date <= 202206L]), slots_last6 = mean(slots[date >= 202306L]),
  slope_per_year = slope_per_year(slots, date), min_cell_any_month = min(min_cell)), by = series]
# Per-donor slot counts are cell-level descriptives of the Waze records: kept in the ignored data folder;
# the committed summary carries only the range of the heaviest donors' slopes.
donor_range <- density_donors[, .(series = paste("10 heaviest donors, |weight|-weighted mean,", pool),
  donor_slope_min = min(slope_per_year), donor_slope_max = max(slope_per_year)), by = pool][, pool := NULL]
density_summary <- merge(density_summary, donor_range, by = "series", all.x = TRUE)

saveRDS(list(fake = fake, fake_stats = fake_stats, holdout_gaps = holdout_gaps, holdout_stats = holdout_stats,
             density_donors = density_donors, density_monthly = density_monthly, density_summary = density_summary),
        file.path(AMEND2_DATA, "drift.rds"))
fwrite(fake[, .(target, pool, estimator, lambda, month, period, actual, synthetic, gap, strike_month)], file.path(AMEND2_OUT, "drift_a_fake_window_paths.csv"))
fwrite(fake_stats, file.path(AMEND2_OUT, "drift_a_fake_window_stats.csv"))
fwrite(holdout_gaps, file.path(AMEND2_OUT, "drift_bc_holdout_gaps.csv"))
fwrite(density_donors, file.path(AMEND2_DATA, "drift_d_density_top_donors.csv"))  # ignored
fwrite(density_monthly, file.path(AMEND2_OUT, "drift_d_density_monthly.csv"))
fwrite(density_summary, file.path(AMEND2_OUT, "drift_d_density_summary.csv"))

dm <- copy(density_monthly)[, d := as.Date(paste0(date, "01"), "%Y%m%d")]
stopifnot(max(dm$d) < as.Date("2023-12-01"))
g <- ggplot(dm, aes(d, slots, colour = series)) + geom_line() + geom_point(size = 0.8) +
  labs(title = "Valid delivered hour slots per cell-month (of 24), January 2022 to November 2023",
       subtitle = "A slot is delivered only when Waze recorded a jam in that cell-hour, so density mixes congestion and observation.",
       x = NULL, y = "Slots per cell-month", colour = NULL) + theme_minimal(base_size = 9) + theme(legend.position = "bottom", legend.direction = "vertical")
ggsave(file.path(AMEND2_OUT, "drift_d_density.png"), g, width = 9, height = 5.5, dpi = 150, bg = "white")
print(fake_stats); print(holdout_stats[target %in% c("CENTER", "CORRIDOR", "BELISARIO_RW", "BELISARIO_EQ")]); print(density_summary); print(density_donors)
