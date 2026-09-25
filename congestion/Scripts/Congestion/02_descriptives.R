# Descriptive work only. No treatment model, post coefficient, or counterfactual fit.
# First run 02_prepare_blocks.R once. All Waze reads below use its deduplicated files.
source("Scripts/Congestion/descriptive_helpers.R")
setDTthreads(4)
con <- connect_clean()
q <- function(sql) as.data.table(DBI::dbGetQuery(con, sql))
spatial <- readRDS("Output/Waze/inventory/cell_groups.rds")
cells <- as.data.table(st_drop_geometry(spatial))
coverage <- q("SELECT grid_id, count(*) n_ever,
  count(*) FILTER (WHERE date BETWEEN 202201 AND 202311) n_pre FROM all_roadtype GROUP BY grid_id")
cells <- merge(cells, coverage, by = "grid_id", all.x = TRUE)
cells[is.na(n_ever), `:=`(n_ever = 0, n_pre = 0)]
cells[, `:=`(never_observed = n_ever == 0, no_pre = n_pre == 0, pre_slots = n_pre / 23)]
cells[, eligible := !never_observed & !(group == "REST" & no_pre)]
cells[, saturated := eligible & group == "REST" & pre_slots >= 20]
exclusions <- cells[, .(grid_cells = .N, never_observed = sum(never_observed),
  no_pre_including_never = sum(no_pre), observed_but_no_pre = sum(!never_observed & no_pre),
  retained = sum(eligible), saturated20 = sum(saturated), threshold12 = sum(eligible & group == "REST" & pre_slots >= 12)), by = group]
stopifnot(sum(cells$never_observed) == 740)
saveRDS(cells, file.path(out, "cell_eligibility.rds"))

# One concentration table, based on preserved multiplicity, never on reloaded raw data.
singleton <- rbindlist(lapply(c("all_roadtype", "large"), function(b) rbindlist(lapply(
  c("grid_id", "date", "hour_of_day"), function(dim) {
    z <- q(sprintf("SELECT %s category, count(*) n, sum((raw_multiplicity=1)::INTEGER) singletons FROM %s GROUP BY %s", dim, b, dim))
    z[, share := singletons / n]
    setorder(z, -singletons, category)
    k <- ceiling(.05 * nrow(z))
    data.table(block = b, dimension = dim, categories = nrow(z), singleton_keys = sum(z$singletons),
      min_singleton_share = min(z$share), max_singleton_share = max(z$share),
      all_singleton_categories = sum(z$share == 1), no_singleton_categories = sum(z$share == 0),
      top5pct_categories = k, top5pct_singleton_share = sum(z$singletons[1:k]) / sum(z$singletons),
      top5pct_key_share = sum(z$n[1:k]) / sum(z$n), largest_category = as.character(z$category[1]))
  }))))

records <- q("SELECT grid_id, date::INTEGER date, hour_of_day::INTEGER AS hour,
  tci_osm_ratio, tci_severe_osm_ratio, avg_jam_speed_ratio, tc_spread, avg_freeflow,
  tc_spread_osm_ratio < 0 AND tc_spread_osm_ratio NOT IN (-998,-999) bad_spread FROM all_roadtype")
for (v in c(outcomes, "avg_freeflow")) set(records, which(records[[v]] %in% c(-998, -999)), v, NA_real_)
records[, present := TRUE]
lattice <- CJ(grid_id = cells[eligible == TRUE, grid_id], date = dates, hour = 0:23)
d <- merge(lattice, records, by = c("grid_id", "date", "hour"), all.x = TRUE)
d[, present := !is.na(present)]
d[present == FALSE, c("tci_osm_ratio", "tci_severe_osm_ratio", "tc_spread") := list(0, 0, 0)]
d[, bad_spread := !is.na(bad_spread) & bad_spread]
d[date %in% gap, c(outcomes, "avg_freeflow") := rep(list(NA_real_), 5)]
d[, valid_presence := fifelse(date %in% gap, NA_real_, as.numeric(present))]
d <- merge(d, cells[, .(grid_id, group, saturated)], by = "grid_id")
stopifnot(d[date %in% gap, all(is.na(tci_osm_ratio))])
rm(lattice, records); gc()
blocks <- list(Morning = c(7L, 8L), Evening = c(17L, 18L), Night = 0:4,
               Peak = c(7L, 8L, 17L, 18L), All_hours = 0:23)
cm <- rbindlist(lapply(names(blocks), function(b) {
  z <- d[hour %in% blocks[[b]], c(lapply(.SD, safe_mean), list(presence = safe_mean(valid_presence),
    delivered_slots = if (all(is.na(valid_presence))) NA_real_ else as.numeric(sum(present)))),
    by = .(grid_id, group, saturated, date), .SDcols = c(outcomes, "avg_freeflow")]
  z[, block := b]; z
}))
expanded <- rbind(cm[, series := group], cm[saturated == TRUE][, series := "REST_saturated"])
series <- expanded[, c(lapply(.SD, safe_mean), list(n_cells = .N,
  jam_speed_cells = sum(!is.na(avg_jam_speed_ratio)), freeflow_cells = sum(!is.na(avg_freeflow)))),
  by = .(series, date, block), .SDcols = c(outcomes, "avg_freeflow", "presence", "delivered_slots")]
series[, month := date_month(date)]
setorder(series, series, block, date)
saveRDS(cm, file.path(out, "cell_month_blocks.rds"))
saveRDS(series, file.path(out, "group_series.rds"))

for (v in outcomes) {
  p <- ggplot(series[block %in% c("Morning", "Evening", "Night")], aes(month, .data[[v]], colour = series)) +
    geom_line(linewidth = .5, na.rm = TRUE) + facet_wrap(~block, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = cols) + labs(x = NULL, y = labels[[v]], colour = NULL,
      title = paste(labels[[v]], "by equal-weight cell group"), subtitle = "Morning 7,8; evening 17,18; night 0-4. All days, not weekday-only.", caption = cal_caption)
  save_plot(calendar(p), paste0("series_", v))
}
monitor_long <- melt(series[series %in% c("CENTER", "BELISARIO") & block %in% c("Morning", "Evening", "Night")],
  id.vars = c("month", "series", "block"), measure.vars = outcomes, variable.name = "outcome")
save_plot(calendar(ggplot(monitor_long, aes(month, value, colour = series)) + geom_line(na.rm = TRUE) +
  facet_grid(outcome ~ block, scales = "free_y", labeller = labeller(outcome = labels)) +
  scale_colour_manual(values = cols) + labs(x = NULL, y = NULL, colour = NULL,
    title = "Seven-cell neighborhoods around rounded published monitor points", caption = cal_caption)), "monitor_neighborhoods", 12, 9)

# Free flow is a selected-record diagnostic, not an analysis outcome or TCI denominator.
ff <- series[block %in% c("Peak", "Night", "All_hours")]
save_plot(calendar(ggplot(ff, aes(month, avg_freeflow, colour = series)) + geom_line(na.rm = TRUE) +
  facet_wrap(~block, ncol = 1) + scale_colour_manual(values = cols) + labs(x = NULL, y = "Free-flow speed (km/h)",
  title = "Delivered free-flow diagnostic, conditional on records", colour = NULL, caption = cal_caption)), "freeflow_diagnostic")
proxy <- melt(series[block %in% c("Peak", "Night", "All_hours")], id.vars = c("month", "series", "block"),
  measure.vars = c("presence", "tc_spread"), variable.name = "proxy")
save_plot(calendar(ggplot(proxy, aes(month, value, colour = series)) + geom_line(na.rm = TRUE) +
  facet_grid(proxy ~ block, scales = "free_y") + scale_colour_manual(values = cols) +
  labs(x = NULL, y = NULL, colour = NULL, title = "Indirect reporting/traffic proxies, not user or jam counts", caption = cal_caption)), "penetration_proxies", 12, 7)

# Equal cell and hour weights imply exact marginal = presence * record-conditional intensity.
decomp <- series[series %in% c("REST", "REST_saturated") & block %in% c("Peak", "Morning", "Evening")]
decomp[, conditional_intensity := fifelse(presence > 0, tci_osm_ratio / presence, NA_real_)]
decomp[, identity_error := tci_osm_ratio - presence * conditional_intensity]
saveRDS(decomp, file.path(out, "rest_decomposition.rds"))
z <- melt(decomp[block == "Peak"], id.vars = c("month", "series"), measure.vars = c("presence", "conditional_intensity", "tci_osm_ratio"))
save_plot(calendar(ggplot(z, aes(month, value, colour = series)) + geom_line(na.rm = TRUE) +
  facet_wrap(~variable, ncol = 1, scales = "free_y") + scale_colour_manual(values = cols) +
  labs(x = NULL, y = NULL, colour = NULL, title = "REST peak TCI: presence and conditional intensity", caption = cal_caption)), "rest_decomposition")

# Hour profiles: each cell-month has equal weight. December 2023 is never in pre.
profiles <- d[(date >= 202201 & date <= 202311) | (date >= 202501 & !date %in% gap)]
profiles <- rbind(profiles[group %in% c("CENTER", "REST")][, series := group],
                  profiles[saturated == TRUE][, series := "REST_saturated"])
profiles[, period := fifelse(date <= 202311, "Pre: Jan 2022-Nov 2023", "2025: Jan and May-Dec")]
profiles <- profiles[, .(tci_osm_ratio = mean(tci_osm_ratio)), by = .(series, period, hour)]
save_plot(ggplot(profiles, aes(hour, tci_osm_ratio, colour = series)) + geom_line() + geom_point(size = 1) +
  facet_wrap(~period) + scale_x_continuous(breaks = seq(0, 23, 3)) + scale_colour_manual(values = cols) +
  theme_minimal() + theme(legend.position = "bottom") + labs(x = "Hour of day (all days)", y = labels[["tci_osm_ratio"]],
  colour = NULL, title = "Hour profiles, not differences or treatment effects", caption = "Feb-Apr 2025 excluded. Calendar shading does not apply to an hour-of-day axis."), "hour_profiles", 11, 5)

# Maps contain all delivered geometry for context; excluded cells never enter an aggregate.
spatial <- merge(spatial, as.data.frame(cells[, .(grid_id, eligible, never_observed, no_pre, pre_slots, saturated)]), by = "grid_id")
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), 4326)
stations <- st_transform(st_zm(st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)), 4326)
monitors <- st_read("Data/spatial/Distancia_REMMAQ_Metro.gpkg", quiet = TRUE)
monitors <- monitors[monitors$Station %in% c("Centro", "Belisario"), ]
base_map <- function(p) p + geom_sf(data = line, colour = "black", linewidth = .45, inherit.aes = FALSE) +
  geom_sf(data = monitors, shape = 21, fill = "white", size = 2.8, inherit.aes = FALSE) +
  geom_sf_text(data = monitors, aes(label = Station), nudge_x = .025, size = 3, inherit.aes = FALSE) +
  theme_minimal(base_size = 10) + labs(x = NULL, y = NULL, caption = "Black: MetroLine.gpkg. White points: rounded REMMAQ coordinates, not verified monitor cells. No time axis.")
spatial$map_group <- ifelse(spatial$eligible, spatial$group, "Excluded")
save_plot(base_map(ggplot(spatial) + geom_sf(aes(fill = map_group), colour = NA) +
  scale_fill_manual(values = c(cols, Excluded = "#eeeeee")) + labs(fill = NULL, title = "Provisional groups after exclusions")), "map_groups", 7, 9)
save_plot(base_map(ggplot(spatial) + geom_sf(aes(fill = pre_slots), colour = NA) +
  scale_fill_viridis_c() + labs(fill = "Slots / month", title = "Pre-period delivered hour slots per cell, Jan 2022-Nov 2023")), "map_density", 7, 9)
spatial$donor_status <- ifelse(spatial$saturated, "REST: >=20", ifelse(spatial$eligible & spatial$group == "REST", "REST: <20", "Not eligible REST"))
save_plot(base_map(ggplot(spatial) + geom_sf(aes(fill = donor_status), colour = NA) +
  scale_fill_manual(values = c("REST: >=20" = "#00856a", "REST: <20" = "#c7d9d4", "Not eligible REST" = "#eeeeee")) +
  labs(fill = NULL, title = "Saturated donor flag from pre-period coverage only")), "map_saturated_donors", 7, 9)

pre <- expanded[date >= 202201 & date <= 202311 & block %in% c("Morning", "Evening", "Night")]
pre_long <- melt(pre, id.vars = c("grid_id", "series", "date", "block", "tci_osm_ratio"), measure.vars = setdiff(outcomes, "tci_osm_ratio"), variable.name = "outcome")
pre_long <- rbind(pre_long, pre[, .(grid_id, series, date, block, tci_osm_ratio, outcome = "tci_osm_ratio", value = tci_osm_ratio)])
pre_summary <- pre_long[, .(mean = safe_mean(value), SD = sd(value, na.rm = TRUE),
  zero_congestion_cell_month_share = mean(tci_osm_ratio == 0), defined_cell_months = sum(!is.na(value))), by = .(series, block, outcome)]
setorder(pre_summary, series, block, outcome)
ps <- series[date >= 202201 & date <= 202311 & block == "Peak"]
correlations <- rbindlist(lapply(c("CENTER", "BELISARIO"), function(target) rbindlist(lapply(
  c("CORRIDOR", "RING", "REST", "REST_saturated"), function(donor) {
    a <- ps[series == target, .(date, treated = tci_osm_ratio)]
    b <- ps[series == donor, .(date, donor = tci_osm_ratio)]
    z <- merge(a, b, by = "date")
    data.table(target, comparator = donor, months = nrow(z), correlation = cor(z$treated, z$donor))
  }))))
comparison <- rbindlist(lapply(c("CENTER", "BELISARIO"), function(target) rbindlist(lapply(
  c("CORRIDOR", "RING", "REST", "REST_saturated"), function(donor) {
    z <- ps[series %in% c(target, donor), .(month, series, tci_osm_ratio)]
    z[, `:=`(target = target, comparator = donor)]; z
  }))))
save_plot(calendar(ggplot(comparison, aes(month, tci_osm_ratio, colour = series)) + geom_line() +
  facet_grid(target ~ comparator, scales = "free_y") + scale_colour_manual(values = cols) +
  labs(x = NULL, y = labels[["tci_osm_ratio"]], colour = NULL, title = "Pre-only peak trajectories: no synthetic-control fit",
    caption = "Jan 2022-Nov 2023 only. Opening, disruption and delivery gap lie outside this axis. CORRIDOR/RING are diagnostic comparators, not approved donors."), TRUE), "pre_donor_comparison", 13, 7)

# Composition diagnostic: fast-road record support / all-road record support. Not road length share.
fast <- q("SELECT grid_id, date::INTEGER date, count(*) fast_slots FROM large GROUP BY grid_id,date")
fast_orphans <- q("SELECT count(*) fast_keys_without_allroad, count(DISTINCT l.grid_id) cells
  FROM large l ANTI JOIN all_roadtype a USING(grid_id,date,hour_of_day)")
fc <- merge(cm[block == "All_hours", .(grid_id, group, saturated, date, delivered_slots)], fast, by = c("grid_id", "date"), all.x = TRUE)
fc[is.na(fast_slots), fast_slots := 0]
fc[date %in% gap, fast_slots := NA_real_]
fc <- rbind(fc[, series := group], fc[saturated == TRUE][, series := "REST_saturated"])
fast_series <- fc[, .(all_slots = sum(delivered_slots), fast_slots = sum(fast_slots)), by = .(series, date)]
fast_series[, `:=`(fast_support_ratio = fast_slots / all_slots, month = date_month(date))]
save_plot(calendar(ggplot(fast_series, aes(month, fast_support_ratio, colour = series)) + geom_line(na.rm = TRUE) +
  scale_colour_manual(values = cols) + labs(x = NULL, y = "Fast-road / all-road delivered slots", colour = NULL,
  title = "Speed-class support diagnostic, not functional road composition", caption = cal_caption)), "fast_road_support", 11, 5)

# Negative auxiliary spread: compare primary TCI with the adjacent calendar months.
# Genuine absent slots are zero; outside support and delivery gaps remain NA.
bad <- q("SELECT grid_id,date::INTEGER date,hour_of_day::INTEGER AS hour,tci_osm_ratio AS current,
  tc_spread_osm_ratio auxiliary FROM all_roadtype WHERE tc_spread_osm_ratio < 0 AND tc_spread_osm_ratio NOT IN (-998,-999)")
seqd <- d[, .(grid_id, hour, date, present, bad_spread, tci_osm_ratio)]
setorder(seqd, grid_id, hour, date)
seqd[, `:=`(previous = shift(tci_osm_ratio), following = shift(tci_osm_ratio, type = "lead")), by = .(grid_id, hour)]
seqd[, adjacent := (previous + following) / 2]
seqd[, deviation := tci_osm_ratio - adjacent]
seqd[, scaled_abs_deviation := abs(deviation) / (1 + adjacent)]
usable <- seqd[present & !date %in% gap & !is.na(adjacent)]
anomaly_summary <- usable[, .(rows = .N, median_tci = median(tci_osm_ratio), median_adjacent = median(adjacent),
  median_deviation = median(deviation), median_abs_deviation = median(abs(deviation)),
  p95_abs_deviation = quantile(abs(deviation), .95), median_scaled_abs = median(scaled_abs_deviation),
  outside_adjacent_range = mean(tci_osm_ratio < pmin(previous, following) | tci_osm_ratio > pmax(previous, following))), by = bad_spread]
anomaly_details <- merge(bad, seqd[, .(grid_id, date, hour, previous, following, adjacent, deviation)], by = c("grid_id", "date", "hour"), all.x = TRUE)
anomaly_details[, excluded_gap := date %in% gap]
bad_groups <- merge(bad,cells[,.(grid_id,group,eligible,saturated)],by="grid_id")[,
  .(flagged_rows=.N,retained_rows=sum(eligible),saturated_rows=sum(saturated)),by=group]
reference <- usable[bad_spread == FALSE, .(reference_scaled=median(scaled_abs_deviation)), by=.(grid_id,hour)]
matched <- merge(usable[bad_spread == TRUE],reference,by=c("grid_id","hour"))
matched_summary <- matched[,.(flagged_rows=.N,flagged_median_scaled=median(scaled_abs_deviation),
  same_cell_hour_reference_median=median(reference_scaled),share_above_own_reference=mean(scaled_abs_deviation>reference_scaled))]
saveRDS(anomaly_details, file.path(out, "negative_spread_adjacent_months.rds"))
bad_month <- d[, .(bad_rows = if (date[1] %in% gap) NA_real_ else as.numeric(sum(bad_spread))), by = date]
bad_month[, month := date_month(date)]
save_plot(calendar(ggplot(bad_month, aes(month, bad_rows)) + geom_col(fill = "#8856a7") +
  labs(x = NULL, y = "Flagged delivered keys", title = "Negative auxiliary OSM spread ratio, retained-cell support", caption = cal_caption)), "negative_spread_timing", 11, 4)
plotbad <- usable[bad_spread == TRUE]
save_plot(ggplot(plotbad, aes(adjacent, tci_osm_ratio)) + geom_point(alpha = .3, size = .7) + geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  theme_minimal() + labs(x = "Mean primary TCI in adjacent calendar months (%)", y = "Primary TCI in flagged row (%)",
  title = "Primary TCI on rows with negative auxiliary spread ratios", caption = "Both neighbors required. Delivery-gap months excluded. This comparison has no time axis or treatment contrast."), "negative_spread_comparison", 7, 6)

# A descriptive construction-period inspection, deliberately without attributing a cause.
construction <- series[date >= 202201 & date <= 202311 & series %in% c("CENTER", "BELISARIO", "REST", "REST_saturated") & block == "Peak"]
cz <- melt(construction, id.vars = c("month", "series"), measure.vars = c("tci_osm_ratio", "tc_spread", "presence"))
save_plot(calendar(ggplot(cz, aes(month, value, colour = series)) + geom_line() +
  facet_wrap(~variable, ncol = 1, scales = "free_y") + scale_colour_manual(values = cols) +
  labs(x = NULL, y = NULL, colour = NULL, title = "Construction-period inspection: a signature is not a closure diagnosis",
  caption = "Pre-opening only. No dated closure log supplied. Opening/disruption/gap lie outside this axis."), TRUE), "construction_preperiod")

annual <- series[!date %in% gap & block %in% c("Peak", "Night", "All_hours")][,
  c(lapply(.SD, safe_mean), list(months = .N)), by = .(series, block, year = date %/% 100),
  .SDcols = c(outcomes, "presence", "avg_freeflow")]
ff_steps <- series[block == "All_hours" & date %in% c(202311,202312,202408,202409), .(series, date, avg_freeflow)]
support <- series[block %in% c("Morning", "Evening", "Night") & !date %in% gap,
  .(total_cells = n_cells[1], min_jam_speed_cells = min(jam_speed_cells), max_jam_speed_cells = max(jam_speed_cells)), by = .(series, block)]
result <- list(exclusions = exclusions, singleton = singleton, pre_summary = pre_summary,
  correlations = correlations, annual = annual, freeflow_levels = ff_steps, jam_speed_support = support,
  anomaly_summary = anomaly_summary, matched_anomalies = matched_summary, bad_groups = bad_groups,
  fast_orphans = fast_orphans, flagged_total = nrow(bad), flagged_gap = sum(bad$date %in% gap),
  flagged_comparable = nrow(plotbad), profiles = profiles, fast_series = fast_series,
  neighborhoods = cells[group %in% c("CENTER", "BELISARIO"), .(group, grid_id, eligible)],
  gap = gap, session = sessionInfo())
saveRDS(result, file.path(out, "descriptive_summary.rds"))
DBI::dbDisconnect(con, shutdown = TRUE)
message("Descriptive tables and figures complete. Run 02_report.R and 02_audit_descriptives.R next.")
