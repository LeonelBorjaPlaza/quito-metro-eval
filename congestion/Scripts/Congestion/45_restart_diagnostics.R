# Amendment 6: four diagnostics for a restart with finer data, after the stop of 2026-10-01. Pre period only
# (January 2022 to November 2023). They reopen nothing: no new estimator or outcome, the default synthetic
# control (redesign_forecast.R, sc), the 22 main-pool tiles, proportions, and the zone approved on 2026-10-01.
#  1. Noise over time: lag-1 autocorrelation of monthly forecast errors and the variance ratio
#     Var(nine-month mean error) / (monthly error variance / 9), placebo tiles; CENTER's holdout errors.
#  2. Noise over space and observation: rolling-origin RMSE against unit size (road length, cells) and the
#     2022 share of cell-hours with a record, for the tiles, CENTER and CORRIDOR; CORRIDOR's smallest
#     signable fall by the 0.92 measure, rescaled to its size.
#  3. A known change: hour labels (weekday profile), then hours 20 and 21 inside and outside the zone
#     around the pico y placa change of 2023-04-10.
#  4. Where CENTER's June to October 2023 drift sits: rings by distance to stations, BELISARIO, and tiles by
#     distance from the line, against the calendar of shocks.
# Inputs: Data/Waze/redesign/{units,checks,zone,contest}.rds (41 to 44), Data/Waze/step1/panel_pre.rds (21),
#   Data/Waze/amend2/geography.rds (31), the pre-only block through step1_loader.R (hours 20 and 21 and the
#   weekday profile), the 2022 road-length file through load_coverage_2022, docs/calendar_shocks.csv.
# Outputs: Output/restart_diagnostics/d1_* to d4_* (aggregates only; tiles unnamed), and
#   Data/Waze/redesign/restart_diagnostics.rds (ignored).
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_loader.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
source("Scripts/Congestion/redesign_forecast.R")
OUT <- "Output/restart_diagnostics"; dir.create(OUT, showWarnings = FALSE)
u <- readRDS(file.path(REDESIGN_DATA, "units.rds"))
ck <- readRDS(file.path(REDESIGN_DATA, "checks.rds"))
zone <- readRDS(file.path(REDESIGN_DATA, "zone.rds"))$zone
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
pr <- panel$rules$amended
SCALE <- u$scale$decision; stopifnot(SCALE == "proportions")
METHOD <- fread(file.path(REDESIGN_OUT, "contest_decision.csv"))$winner; stopifnot(METHOD == "sc")
main <- u$unit_meta[type == "donor tile", unit]; stopifnot(length(main) == 22L)
N_CORES <- 4L
pml <- function(X, FUN) { r <- parallel::mclapply(X, FUN, mc.cores = N_CORES); check_parallel(r, length(X)); r }
lag1 <- function(dt) {  # pooled lag-1 correlation of errors within units over calendar-adjacent usable months
  x <- copy(dt)[order(unit, month)]
  x[, `:=`(prev = shift(error), adj = match(month, PRE_MONTHS) - shift(match(month, PRE_MONTHS)) == 1L), by = unit]
  x <- x[!is.na(prev) & adj == TRUE]
  c(pairs = nrow(x), lag1 = if (nrow(x) > 2) cor(x$error, x$prev) else NA_real_)
}

# CORRIDOR as a unit: CORRIDOR cells (BELISARIO rebuilt), provider 2022 OSM length weights, composition rule.
con <- duck(); cov <- load_coverage_2022(con); rg <- redesign_groups(con, geog); DBI::dbDisconnect(con, shutdown = TRUE)
corr_cells <- merge(rg$groups[group == "CORRIDOR" & grid_id %in% pr$cells$grid_id, .(grid_id)], cov[, .(grid_id, weight_m = osm_sum_length)], by = "grid_id")[weight_m > 0]
corr_series <- rbindlist(lapply(c("peak", "morning", "evening"), function(b) {
  x <- merge(pr$cell_block[block == b, .(grid_id, date, value)], corr_cells, by = "grid_id")
  x[, .(unit = "CORRIDOR", value = if (anyNA(value)) NA_real_ else sum(weight_m * value) / sum(weight_m)), by = date][, block := b]
}))
stopifnot(!anyNA(corr_series$value))
series <- rbind(u$series, corr_series[, .(unit, date, value, block)])

# ---- 1. Noise over time ----
nine <- ck$nine[, .(unit, month, error)]
ratio_of <- function(x, k) { eb <- x[, .(m = mean(error)), by = unit]$m; var(eb) / (var(x$error) / k) }
d1 <- rbindlist(list(
  data.table(series = "placebo tiles, nine-month forecasts (fit usable months 1-12, forecast 13-21)", units = uniqueN(nine$unit),
             months_per_unit = 9L, t(lag1(nine)), variance_ratio = ratio_of(nine, 9)),
  data.table(series = "placebo tiles, one-month-ahead rolling-origin errors (contest, cut-offs 12-20)", units = length(main), months_per_unit = 9L,
             t(lag1(readRDS(file.path(REDESIGN_DATA, "contest.rds"))$forecasts[method == METHOD & horizon == 1, .(unit = target, month, error)])),
             variance_ratio = NA_real_),
  {
    ce <- ck$holdout[unit == "CENTER" & scale == SCALE, .(unit, month, error)]
    data.table(series = "CENTER, June to October 2023 holdout errors (fit to May 2023)", units = 1L, months_per_unit = nrow(ce), t(lag1(ce)),
               variance_ratio = mean(ce$error)^2 / (mean(ce$error^2) / nrow(ce)))
  }), fill = TRUE)
# The ratios have different ceilings: the tile ratio (centred) is at most 9, CENTER's (uncentred, one series)
# at most 5; the normalized value (ratio - 1) / (k - 1) runs from 0 (pure month-to-month noise) to 1 (pure
# persistent error) in both.
d1[, ceiling := c(9, NA, 5)][, ratio_normalized := (variance_ratio - 1) / (ceiling - 1)]
d1[, note := c(paste("variance ratio across tiles: Var(tile mean error) / (Var(all monthly errors) / 9); near 1 = month-to-month noise,",
                     "well above 1 = persistent error; the pooled lag-1 correlation mixes persistent differences in tile mean error with month-to-month dependence"),
               "consecutive one-month-ahead errors come from successive cut-offs",
               "single unit, uncentred: 5 x (mean error)^2 / mean squared monthly error; not directly comparable with the tile ratio (see ratio_normalized); 4 adjacent pairs")]

# ---- 2. Noise over space and observation ----
targets <- c(main, "CENTER", "CORRIDOR")
mats <- level_mats(series, targets)
ro <- rbindlist(pml(targets, function(t) rbindlist(lapply(12:20, function(cut) {
  fit_m <- USABLE_MONTHS[seq_len(cut)]; fc_m <- USABLE_MONTHS[(cut + 1):min(cut + 3, length(USABLE_MONTHS))]
  forecast_one(METHOD, t, setdiff(main, t), mats, fit_m, fc_m, SCALE)[, `:=`(unit = t, cutoff = cut)]
}))))
stopifnot(nrow(ro) == length(targets) * sum(pmin(length(USABLE_MONTHS) - 12:20, 3L)))
cellsets <- rbind(u$unit_cells[unit %in% c(main, "CENTER"), .(unit, grid_id, weight_m)], corr_cells[, .(unit = "CORRIDOR", grid_id, weight_m)])
slots22 <- pr$slots[date %between% c(202201L, 202212L)]
obs <- merge(cellsets[, .(unit, grid_id)], slots22, by = "grid_id", allow.cartesian = TRUE)[, .(records = sum(n)), by = unit]
# Road length on one basis for every unit: the provider's whole-cell 2022 OSM length (CENTER's in-polygon OSM
# weights are not used here). Observation: valid records (after the flag rule) per cell-hour slot in 2022.
size <- merge(cellsets[, .(unit, grid_id)], cov[, .(grid_id, osm_m = osm_sum_length)], by = "grid_id")[, .(cells = .N, road_km = sum(osm_m, na.rm = TRUE) / 1000), by = unit]
size <- merge(size, obs, by = "unit")[, obs_share_2022 := records / (cells * 24 * 12)][, records := NULL]
d2 <- merge(ro[, .(rmse = sqrt(mean(error^2)), mean_error = mean(error), forecasts = .N), by = unit], size, by = "unit")
d2[, type := fifelse(unit %in% main, "tile", unit)]
d2[, road_km_note := "provider 2022 all_roadtype OSM length, whole cells"]
tiles2 <- d2[type == "tile"]
fit_road <- lm(log(rmse) ~ log(road_km), data = tiles2); fit_cells <- lm(log(rmse) ~ log(cells), data = tiles2)
fit_obs <- lm(log(rmse) ~ obs_share_2022, data = tiles2)
coef_row <- function(f, term, what) data.table(regression = what, n = nobs(f), slope = unname(coef(f)[term]),
  ci95_low = confint(f)[term, 1], ci95_high = confint(f)[term, 2])
d2_fits <- rbindlist(list(coef_row(fit_road, "log(road_km)", "log RMSE on log road length, tiles"),
                          coef_row(fit_cells, "log(cells)", "log RMSE on log cells with weight, tiles (not meaningful: 20 of 22 tiles have 7 cells)"),
                          coef_row(fit_obs, "obs_share_2022", "log RMSE on 2022 share of cell-hour slots with a valid record, tiles")))
d2_fits[, interval := "classical OLS t interval, descriptive"]
d2_extra <- d2[type != "tile", .(unit, rmse, road_km)]
d2_extra[, predicted_rmse_from_tile_road_fit := exp(predict(fit_road, newdata = d2_extra))]
# CORRIDOR's smallest signable fall by the 0.92 measure, with tile nine-month errors rescaled to CORRIDOR's
# road length by the fitted slope b (error proportional to road_km^b). Assumption, labeled in the report.
b <- unname(coef(fit_road)[2])
eb <- merge(ck$nine[, .(mean_error = mean(error)), by = unit], tiles2[, .(unit, road_km)], by = "unit")
L_corr <- d2[unit == "CORRIDOR", road_km]
mde_of <- function(e) {
  crit <- unname(quantile(abs(e), 0.95)); grid_d <- seq(0, 3 * max(abs(e)) + crit, length.out = 4001)
  c(crit = crit, red = grid_d[which(vapply(-grid_d, function(d) mean(abs(e + d) > crit), 0) >= 0.8)[1]])
}
corr_pre <- series[unit == "CORRIDOR" & block == "peak" & date %in% USABLE_MONTHS, mean(value)]
corr_nine <- forecast_one(METHOD, "CORRIDOR", main, mats, USABLE_MONTHS[1:12], USABLE_MONTHS[13:21], SCALE)
# CORRIDOR (455 km) lies far beyond the tiles' size range (at most about 116 km): every rescaled row is an
# extrapolation. Rows: the fitted slope, slope 0 (no size effect), both interval bounds, and the slope refit
# without the tile with the largest RMSE (high leverage; a sensitivity chosen after seeing the fit).
out_tile <- tiles2[which.max(rmse), unit]
b_wo <- unname(coef(lm(log(rmse) ~ log(road_km), data = tiles2[unit != out_tile]))[2])
ci_b <- confint(fit_road)["log(road_km)", ]
B_ROWS <- c(fitted = b, `slope 0` = 0, `interval low` = unname(ci_b[1]), `interval high` = unname(ci_b[2]), `refit without largest-RMSE tile` = b_wo)
m_tiles <- mde_of(eb$mean_error)
d2_mde <- rbind(
  data.table(unit = "tiles (as in mde_empirical.csv)", slope_row = NA_character_, slope_b_used = NA_real_, critical_value = m_tiles[["crit"]],
             mde_reduction_share = m_tiles[["red"]], unit_pre_mean = NA_real_, mde_reduction_index_points = NA_real_),
  rbindlist(lapply(names(B_ROWS), function(k) {
    m <- mde_of(eb$mean_error * (L_corr / eb$road_km)^B_ROWS[[k]])
    data.table(unit = "CORRIDOR (tile errors rescaled to its road length; extrapolation beyond the tile size range)", slope_row = k,
               slope_b_used = B_ROWS[[k]], critical_value = m[["crit"]], mde_reduction_share = m[["red"]], unit_pre_mean = corr_pre,
               mde_reduction_index_points = m[["red"]] * corr_pre)
  })))
d2_mde[, corridor_own_nine_month_mean_error := fifelse(is.na(slope_row), NA_real_, mean(corr_nine$error))]

# ---- 3. A known change ----
con <- duck()
rec <- load_pre_outcomes(con, c("tci_osm_ratio", "tci_waze_ratio", "tci_severe_waze_ratio", "tc_spread_osm_ratio",
                                "tc_spread_waze_ratio", "tc_severe_spread_osm_ratio", "tc_severe_spread_waze_ratio"))
DBI::dbDisconnect(con, shutdown = TRUE)
# Validity as in the panel's amended rule (sentinels in these fields, negative auxiliary ratios, primary NA).
# Sentinels in fields not loaded here are not checked; the panel found none in the pre period.
stopifnot(sum(unlist(panel$sentinel_by_col)) == 0)
rec[, invalid := is.na(tci_osm_ratio) | Reduce(`|`, lapply(.SD, function(v) !is.na(v) & v < 0)), .SDcols = FLAG_NEGATIVE]
popc <- pr$cells$grid_id
n_cells <- length(popc)
prof <- rec[invalid == FALSE & grid_id %in% popc, .(sum_tci = sum(tci_osm_ratio)), by = hour_of_day]
prof[, mean_tci := sum_tci / (n_cells * length(PRE_MONTHS))][, sum_tci := NULL]
prof <- prof[order(hour_of_day)]
peaks <- data.table(morning_peak_hour = prof[hour_of_day < 12][which.max(mean_tci), hour_of_day],
                    evening_peak_hour = prof[hour_of_day >= 12][which.max(mean_tci), hour_of_day],
                    night_minimum_hour = prof[which.min(mean_tci), hour_of_day])
# Hours 20 and 21: fixed composition = population cells valid at both hours in all 23 months (decided on
# missingness only); zone membership by cell centroid; weights = provider 2022 OSM length.
H <- c(20L, 21L)
lat <- CJ(grid_id = popc, date = PRE_MONTHS, hour_of_day = H)
lat <- rec[hour_of_day %in% H, .(grid_id, date, hour_of_day, tci_osm_ratio, invalid)][lat, on = .(grid_id, date, hour_of_day)]
lat[is.na(invalid), `:=`(invalid = FALSE, tci_osm_ratio = 0)]
keep <- lat[, .(ok = !any(invalid)), by = grid_id][ok == TRUE, grid_id]
SIRES <- st_crs(geog$sires)
pts <- st_transform(st_centroid(st_as_sf(fread(grid_path, colClasses = "character")[grid_id %in% keep], wkt = "h3_geometry_r8", crs = 4326)), SIRES)
inzone <- data.table(grid_id = pts$grid_id, in_zone = st_within(pts, st_geometry(zone), sparse = FALSE)[, 1])
w <- merge(inzone, cov[, .(grid_id, weight_m = osm_sum_length)], by = "grid_id")[!is.na(weight_m) & weight_m > 0]
g <- merge(lat[invalid == FALSE & grid_id %in% w$grid_id], w, by = "grid_id")
zm <- g[, .(value = sum(weight_m * tci_osm_ratio) / sum(weight_m)), by = .(hour_of_day, date, in_zone)]
gap <- dcast(zm, hour_of_day + date ~ in_zone, value.var = "value")[, gap := `TRUE` - `FALSE`]
BEFORE <- PRE_MONTHS[PRE_MONTHS <= 202303L]; AFTER <- PRE_MONTHS[PRE_MONTHS >= 202305L]
did_at <- function(gp, before, after) mean(gp[date %in% after, gap]) - mean(gp[date %in% before, gap])
# Windows: Leonel's (main); the same without June 2022 and November 2023 (Amendment 5, item 6); and the same
# calendar months in both years (May and July to October 2022 against May and July to October 2023), against
# seasonality. Noise: the main contrast at every placebo split inside the before window (k = 4 to 14, so one
# split falls at March 2023, the month before the change); a rank among 11 placebos has smallest p 1/12.
WINDOWS <- list(main = list(BEFORE, AFTER),
                `without June 2022 and November 2023` = list(setdiff(BEFORE, EXCL_MONTHS), setdiff(AFTER, EXCL_MONTHS)),
                `same calendar months` = list(c(202205L, 202207L:202210L), c(202305L, 202307L:202310L)))
d3 <- rbindlist(lapply(H, function(h) {
  gp <- gap[hour_of_day == h]
  plac <- vapply(4:14, function(k) did_at(gp, BEFORE[1:k], BEFORE[(k + 1):length(BEFORE)]), 0)
  rbindlist(lapply(names(WINDOWS), function(wn) {
    est <- did_at(gp, WINDOWS[[wn]][[1]], WINDOWS[[wn]][[2]])
    exp_sign <- if (h == 20L) 1 else -1
    data.table(hour = h, window = wn, expected_sign = if (h == 20L) "+" else "-", cells_in_zone = w[, sum(in_zone)], cells_outside = w[, sum(!in_zone)],
      in_zone_before_mean = mean(gp[date %in% WINDOWS[[wn]][[1]], `TRUE`]),
      change_in_gap = est, change_pct_of_in_zone_before = 100 * est / mean(gp[date %in% WINDOWS[[wn]][[1]], `TRUE`]),
      sign_matches_expected = sign(est) == exp_sign,
      placebo_splits = if (wn == "main") length(plac) else NA_integer_, placebo_max_abs = if (wn == "main") max(abs(plac)) else NA_real_,
      abs_change_exceeds_all_placebos = if (wn == "main") abs(est) > max(abs(plac)) else NA,
      placebos_at_least_as_large = if (wn == "main") sum(abs(plac) >= abs(est)) else NA_integer_,
      rank_p = if (wn == "main") (1 + sum(abs(plac) >= abs(est))) / (length(plac) + 1) else NA_real_,
      smallest_attainable_p_of_rank = if (wn == "main") 1 / (length(plac) + 1) else NA_real_)
  }))
}))
# Event-time view: gap by month relative to April 2023 (month 0 = April 2023, left out of the contrast).
event <- gap[, .(hour_of_day, month = date, months_from_april_2023 = match(date, PRE_MONTHS) - match(202304L, PRE_MONTHS), gap)]
d3_cells <- data.table(population_cells = n_cells, cells_valid_at_20_and_21_all_months = length(keep), cells_with_weight = nrow(w))

# ---- 4. Where the drift sits ----
JUN_OCT23 <- USABLE_MONTHS[USABLE_MONTHS >= 202306L]; FIT_TO_MAY23 <- USABLE_MONTHS[USABLE_MONTHS <= 202305L]
ring_units <- u$unit_meta[type == "ring" & complete == TRUE, unit]
mats4 <- level_mats(u$series, c("CENTER", "BELISARIO", ring_units, main))
hold <- rbindlist(pml(c("CENTER", "BELISARIO", ring_units, main), function(t)
  forecast_one(METHOD, t, setdiff(main, t), mats4, FIT_TO_MAY23, JUN_OCT23, SCALE)[, unit := t]))
meta <- rbind(data.table(unit = c("CENTER", "BELISARIO"), group = c("CENTER", "BELISARIO")),
              u$unit_meta[type == "ring", .(unit, group = paste(ring, segment, sep = ", "))],
              u$unit_meta[type == "donor tile", .(unit, group = paste("tiles,", cut(mean_km_to_line, c(-Inf, 5, 10, Inf),
                labels = c("under 5 km from the line", "5 to 10 km", "over 10 km"), right = FALSE)))])
hold <- merge(hold, meta, by = "unit")
d4 <- hold[, .(units = uniqueN(unit), mean_error = mean(error), share_negative = mean(error < 0)), by = group][order(group)]
d4_month <- dcast(hold[, .(mean_error = mean(error)), by = .(group, month)], group ~ month, value.var = "mean_error")
# Calendar events that touch the June to October 2023 window: an event with an end overlaps it if it starts by
# 2023-10-31 and ends on or after 2023-06-01; a dated change without an end counts only if it falls inside it.
cal <- fread("docs/calendar_shocks.csv", colClasses = "character")[, .(event, start, end, months_marked)]
cal[, s := as.Date(ifelse(nchar(start) == 7, paste0(start, "-01"), start))]
cal[, e := as.Date(ifelse(is.na(end) | end == "", NA_character_, ifelse(nchar(end) == 7, paste0(end, "-28"), end)))]
W0 <- as.Date("2023-06-01"); W1 <- as.Date("2023-10-31")
# Only the event and its start are written, so no date from December 2023 on appears in a committed output
# (the no-post check scans for such tokens); full dates are in docs/calendar_shocks.csv.
d4_calendar <- cal[s <= W1 & ((is.na(e) & s >= W0) | (!is.na(e) & e >= W0)),
                   .(event, start, continues_past_window = !is.na(e) & e > W1)]

saveRDS(list(d1 = d1, ro = ro, d2 = d2, d2_fits = d2_fits, d2_mde = d2_mde, prof = prof, peaks = peaks, d3 = d3, gap = gap, event = event,
             hold = hold, d4 = d4, d4_calendar = d4_calendar), file.path(REDESIGN_DATA, "restart_diagnostics.rds"))
fwrite(d1, file.path(OUT, "d1_noise_over_time.csv"))
fwrite(d2[order(type, road_km), .(unit = fifelse(type == "tile", "tile", unit), type, cells, road_km = round(road_km, 2), obs_share_2022, rmse, mean_error, forecasts, road_km_note)],
       file.path(OUT, "d2_noise_by_unit.csv"))
fwrite(d2_fits, file.path(OUT, "d2_noise_fits.csv"))
fwrite(d2_extra, file.path(OUT, "d2_center_corridor_vs_tile_fit.csv"))
fwrite(d2_mde, file.path(OUT, "d2_corridor_mde.csv"))
fwrite(prof, file.path(OUT, "d3_weekday_profile_by_hour.csv"))
fwrite(peaks, file.path(OUT, "d3_hour_label_check.csv"))
fwrite(d3, file.path(OUT, "d3_pico_y_placa_hours_20_21.csv"))
fwrite(d3_cells, file.path(OUT, "d3_cells.csv"))
fwrite(gap[, .(hour_of_day, month = date, in_zone = `TRUE`, outside = `FALSE`, gap)], file.path(OUT, "d3_monthly_zone_series.csv"))
fwrite(d4, file.path(OUT, "d4_drift_by_group.csv"))
fwrite(d4_month, file.path(OUT, "d4_drift_by_group_month.csv"))
fwrite(d4_calendar, file.path(OUT, "d4_calendar_events_in_window.csv"))
fwrite(event, file.path(OUT, "d3_event_time_gap.csv"))
print(d1); print(d2_fits); print(d2_extra); print(d2_mde); print(peaks); print(d3); print(d3_cells); print(d4); print(d4_month)
