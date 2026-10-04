# Step 1, item 3b. Pre-period analysis panel under plan v2 sections 1 to 4 and Amendment 1.
# Five data states: (a) delivered and valid; (b) absent in a delivered month, coded 0 under
# provisional zero coding; (c) sentinel or flag-rule key, missing; (d) the 2025 delivery gap,
# outside this window; (e) cells with no pre-period record, excluded.
# Fixed composition: a cell-month (unit-month) exists only if every hour (cell-hour) is valid.
# Two flag rules for the primary outcome (Amendment 1, 2026-09-27):
#   amended (primary): sentinels and the six negative auxiliary ratios make a key missing;
#     severe persistence above 100 makes only the severe outcomes missing.
#   plan (sensitivity): the original rule, where severe persistence above 100 also makes it missing.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_loader.R")
con <- duck()
geo <- build_groups(con)
cells <- geo$cells

# Geography reconciliation with the Phase B assignment (tracked cell_groups.rds).
phase_b <- as.data.table(sf::st_drop_geometry(readRDS("Output/Waze/inventory/cell_groups.rds")))[, .(grid_id, group_b = group)]
recon <- merge(cells[, .(grid_id, group)], phase_b, by = "grid_id", all = TRUE)
geography_mismatch <- recon[is.na(group) | is.na(group_b) | group != group_b]
stopifnot(nrow(geography_mismatch) == 0L)
group_counts <- cells[, .N, by = group][order(group)]

# Outcome records, pre period only, through the single loader.
num_cols <- c("avg_jam_speedkmh", "avg_jam_speed_ratio", "avg_freeflow", "tci", "tci_severe", "tci_osm_ratio",
              "tci_waze_ratio", "tci_severe_osm_ratio", "tci_severe_waze_ratio", "tc_spread", "tc_severe_spread",
              "tc_spread_osm_ratio", "tc_spread_waze_ratio", "tc_severe_spread_osm_ratio", "tc_severe_spread_waze_ratio",
              "tc_persistance_ratio", "tc_severe_persistance_ratio", "freeflow_speed", "speed", "t_speed_ratio")
rec <- load_pre_outcomes(con, num_cols)
stopifnot(!anyDuplicated(rec[, .(grid_id, date, hour_of_day)]), all(rec$grid_id %in% cells$grid_id))

# State (c). Sentinels in any field, negative auxiliary ratios, severe persistence above 100.
sentinel_by_col <- rec[, lapply(.SD, function(v) sum(v %in% SENTINELS)), .SDcols = num_cols]
rec[, sentinel := Reduce(`|`, lapply(.SD, function(v) v %in% SENTINELS)), .SDcols = num_cols]
rec[, negative := Reduce(`|`, lapply(.SD, function(v) !is.na(v) & v < 0)), .SDcols = FLAG_NEGATIVE]
rec[, persistence := !is.na(get(FLAG_ABOVE_100)) & get(FLAG_ABOVE_100) > 100]
rec[, primary_na := is.na(tci_osm_ratio)]
rec[, status := fifelse(sentinel, "sentinel", fifelse(negative, "negative ratio",
                 fifelse(primary_na, "primary NA", fifelse(persistence, "persistence only", "clean"))))]
key_status <- rec[, .N, by = status][order(status)]
flag_by_col <- rec[, lapply(.SD, function(v) sum(!is.na(v) & v < 0 & !(v %in% SENTINELS))), .SDcols = FLAG_NEGATIVE]
flag_by_col[, (FLAG_ABOVE_100) := rec[persistence == TRUE, .N]]
RULES <- c(amended = "persistence only makes severe outcomes missing (primary)",
           plan = "original plan rule: persistence above 100 makes every outcome missing (sensitivity)")
invalid_status <- list(amended = c("sentinel", "negative ratio", "primary NA"),
                       plan = c("sentinel", "negative ratio", "primary NA", "persistence only"))

# State (e): the fixed population is every cell with at least one pre-period record.
cells[, pre_record := grid_id %in% rec$grid_id]
stopifnot(cells[group %in% c("CENTER", "BELISARIO"), all(pre_record)])
pop0 <- cells[pre_record == TRUE]
population_counts <- merge(group_counts, pop0[, .(population = .N), by = group], by = "group", all.x = TRUE)
unit_cells <- list(CENTER = geo$rings$CENTER, BELISARIO = geo$rings$BELISARIO, CORRIDOR = pop0[group == "CORRIDOR", grid_id])

# 2022 jam-derived coverage screen (plan section 3): range across the fourteen target cells.
cov <- load_coverage_2022(con)
pop0 <- merge(pop0, cov[, .(grid_id, cov_2022 = perc_waze_coverage)], by = "grid_id", all.x = TRUE)
target_cov <- pop0[group %in% c("CENTER", "BELISARIO"), .(grid_id, group, cov_2022)]
stopifnot(!anyNA(target_cov$cov_2022))
cov_range <- range(target_cov$cov_2022)
hours_all <- sort(unique(unlist(HOURS)))

pool_defs <- list(
  primary_unscreened = quote(t20 & complete),
  primary_screened = quote(t20 & cov_ok & complete),
  threshold12_unscreened = quote(t12 & complete),
  threshold12_screened = quote(t12 & cov_ok & complete),
  all_rest_unscreened = quote(rest & complete),
  all_rest_screened = quote(rest & cov_ok & complete),
  low_exposure_unscreened = quote(t20 & low_exposure & complete),
  low_exposure_screened = quote(t20 & low_exposure & cov_ok & complete))

build_rule <- function(rule) {
  r <- copy(rec)[, reason := fifelse(status %in% invalid_status[[rule]], status, "valid")]
  pop <- copy(pop0)
  # Delivered-slot eligibility after the flag rule: mean valid records per cell-month over 23 months.
  slots <- r[reason == "valid", .(n = .N), by = .(grid_id, date)]
  slots <- slots[CJ(grid_id = pop$grid_id, date = PRE_MONTHS), on = .(grid_id, date)][is.na(n), n := 0L]
  pop <- merge(pop, slots[, .(slots_mean = mean(n)), by = grid_id], by = "grid_id")

  # Completed lattice. Absent cell-hours are 0 (provisional zero coding).
  lat <- CJ(grid_id = pop$grid_id, date = PRE_MONTHS, hour_of_day = hours_all)
  lat <- r[, .(grid_id, date, hour_of_day, tci_osm_ratio, reason)][lat, on = .(grid_id, date, hour_of_day)]
  lat[is.na(reason), `:=`(reason = "absent, zero", tci_osm_ratio = 0)]
  lat[!reason %in% c("valid", "absent, zero"), tci_osm_ratio := NA_real_]
  stopifnot(lat[reason %in% c("valid", "absent, zero"), all(tci_osm_ratio >= 0 & tci_osm_ratio <= 100)])

  cell_block <- rbindlist(lapply(names(HOURS), function(b) lat[hour_of_day %in% HOURS[[b]], .(
    block = b, value = if (anyNA(tci_osm_ratio)) NA_real_ else mean(tci_osm_ratio),
    reason = if (anyNA(tci_osm_ratio)) paste(sort(unique(reason[is.na(tci_osm_ratio)])), collapse = "+") else "valid",
    n_hours = .N), by = .(grid_id, date)]))
  stopifnot(all(cell_block$n_hours == lengths(HOURS)[cell_block$block]))
  cell_block[, n_hours := NULL]

  # Aggregate units: equal cell weights, every cell valid or the unit-month is missing.
  unit_month <- rbindlist(lapply(names(unit_cells), function(u) cell_block[grid_id %in% unit_cells[[u]], .(
    unit = u, value = if (anyNA(value)) NA_real_ else mean(value), n_cells = .N,
    n_missing_cells = sum(is.na(value)),
    reason = if (anyNA(value)) paste(sort(unique(reason[is.na(value)])), collapse = "+") else "valid"), by = .(block, date)]))
  stopifnot(all(unit_month$n_cells == lengths(unit_cells)[unit_month$unit]))
  unit_month[, log_value := fifelse(!is.na(value) & value > 0, log(value), NA_real_)]
  valid_unit_months <- dcast(unit_month[, .(valid = sum(!is.na(value)), missing = sum(is.na(value)),
    log_undefined = sum(!is.na(value) & value <= 0)), by = .(unit, block)], unit ~ block,
    value.var = c("valid", "missing", "log_undefined"))

  # Donor pools (plan section 3). Donors must be complete in the peak block over the pre period.
  peak_missing <- cell_block[block == "peak", .(missing_months = sum(is.na(value)),
    missing_train = sum(is.na(value) & date %in% TRAIN_MONTHS),
    missing_holdout = sum(is.na(value) & date %in% HOLDOUT_MONTHS),
    reasons = paste(sort(unique(reason[is.na(value)])), collapse = "; ")), by = grid_id]
  pop <- merge(pop, peak_missing, by = "grid_id")
  pop[, `:=`(
    rest = group == "REST",
    t20 = group == "REST" & slots_mean >= SLOT_THRESHOLD,
    t12 = group == "REST" & slots_mean >= SLOT_THRESHOLD_SENS,
    cov_ok = !is.na(cov_2022) & cov_2022 >= cov_range[1] & cov_2022 <= cov_range[2],
    complete = missing_months == 0L,
    low_exposure = nearest_station_m > LOW_EXPOSURE_M)]
  for (p in names(pool_defs)) pop[, (paste0("pool_", p)) := eval(pool_defs[[p]])]
  pool_counts <- rbindlist(lapply(names(pool_defs), function(p) {
    base <- sub("_(un)?screened$", "", p)
    eligible <- switch(base, primary = pop$t20, threshold12 = pop$t12, all_rest = pop$rest,
                       low_exposure = pop$t20 & pop$low_exposure)
    screened <- grepl("_screened$", p)
    data.table(rule = rule, pool = p, eligible = sum(eligible),
               removed_by_coverage = if (screened) sum(eligible & !pop$cov_ok) else 0L,
               removed_incomplete = sum(eligible & (!screened | pop$cov_ok) & !pop$complete),
               donors = sum(pop[[paste0("pool_", p)]]))
  }))
  stopifnot(pool_counts[, all(eligible - removed_by_coverage - removed_incomplete == donors)])
  donor_missing <- pop[group == "REST", .(grid_id, slots_mean, cov_2022, t20, t12, cov_ok, missing_months,
                                          missing_train, missing_holdout, reasons)]
  # cell_block (every population cell) and slots (valid records per cell-month) are kept for the
  # Amendment 2 units, which mix cells of several Step 1 groups (32_amend2_panel.R).
  # speed_block (Amendment 5 secondary outcome): per cell-month and block, over valid records with a
  # recorded jam, the sum of tci_osm_ratio and of tci_osm_ratio times avg_jam_speed_ratio, so units can
  # form a congested-length-weighted jam speed.
  speed_block <- rbindlist(lapply(names(HOURS), function(b) r[reason == "valid" & hour_of_day %in% HOURS[[b]] & tci_osm_ratio > 0,
    .(block = b, tci_sum = sum(tci_osm_ratio), tci_speed_sum = sum(tci_osm_ratio * avg_jam_speed_ratio)), by = .(grid_id, date)]))
  list(rule = rule, description = RULES[[rule]], cells = pop, unit_month = unit_month,
       cell_block = cell_block, slots = slots, speed_block = speed_block,
       donor_month = cell_block[grid_id %in% pop[group == "REST", grid_id]],
       valid_unit_months = valid_unit_months, pool_counts = pool_counts, donor_missing = donor_missing)
}
by_rule <- lapply(setNames(names(RULES), names(RULES)), build_rule)

panel <- list(label = ZERO_LABEL, months = PRE_MONTHS, hours = HOURS, seeds = SEEDS, rings = geo$rings,
  unit_cells = unit_cells, rules = by_rule, cov_range = cov_range, target_cov = target_cov,
  key_status = key_status, sentinel_by_col = sentinel_by_col, flag_by_col = flag_by_col,
  population_counts = population_counts, geography_mismatch = geography_mismatch)
saveRDS(panel, file.path(STEP1_DATA, "panel_pre.rds"))

# Geography map: every delivered cell by group, with the line, stations and monitors.
prim <- by_rule$amended$cells
grid_sf <- st_as_sf(fread(grid_path, colClasses = "character"), wkt = "h3_geometry_r8", crs = 4326)
grid_sf <- merge(grid_sf, cells[, .(grid_id, group, pre_record)], by = "grid_id")
grid_sf$shown <- ifelse(grid_sf$pre_record, grid_sf$group, "no pre-period record")
grid_sf$shown[grid_sf$grid_id %in% prim[pool_primary_unscreened == TRUE, grid_id]] <- "REST donor (threshold 20)"
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), 4326)
mon <- geo$monitors[geo$monitors$Station %in% c("Centro", "Belisario"), ]
fills <- c(CENTER = "#bc3b32", BELISARIO = "#225ea8", CORRIDOR = "#8856a7", RING = "#d89920",
           REST = "#e3e3e3", `REST donor (threshold 20)` = "#00856a", `no pre-period record` = "white")
p <- ggplot() + geom_sf(data = grid_sf, aes(fill = shown), colour = "grey75", linewidth = 0.05) +
  geom_sf(data = line, colour = "black", linewidth = 0.5) +
  geom_sf(data = geo$stations, shape = 21, fill = "white", size = 1.3) +
  geom_sf(data = mon, shape = 24, fill = "yellow", size = 2.2) +
  scale_fill_manual(values = fills, name = NULL) +
  labs(title = "Step 1 units and donors, H3 resolution 8",
       subtitle = "CENTER and BELISARIO: published monitor cell plus six neighbours. CORRIDOR: centroid within 1 km of a station. RING: 1-2 km.",
       caption = paste("Triangles: published Centro and Belisario points (rounded to 0.01 degrees). Circles: Line 1 stations.",
                       "Green: threshold-20 donors complete in the pre period under the amended flag rule, before the coverage screen.",
                       "No historic-center boundary or road layer is available.", sep = "\n")) +
  coord_sf(xlim = c(-78.60, -78.40), ylim = c(-0.36, -0.08)) + theme_minimal(base_size = 9)
ggsave(file.path(STEP1_OUT, "map_units_donors.png"), p, width = 8, height = 9, dpi = 150)

# Summary for the report.
txt <- c("# Step 1 panel summary", "",
  sprintf("Pre period %d to %d, %s. Generated by Scripts/Congestion/21_step1_panel.R.", PRE_FIRST, PRE_LAST, ZERO_LABEL), "",
  "## Geography", "", md_table(population_counts), "",
  sprintf("Cells whose group differs from Phase B cell_groups.rds: %d.", nrow(geography_mismatch)), "",
  "## Record status, pre period (all_roadtype keys)", "", md_table(key_status), "",
  "Keys are counted once, by the first status that applies: sentinel, negative ratio, primary NA, persistence only.", "",
  "Sentinel values by column:", "", md_table(sentinel_by_col), "",
  "Flag-rule values by column (non-sentinel negatives; persistence above 100):", "", md_table(flag_by_col), "")
for (r in names(RULES)) txt <- c(txt,
  sprintf("## Valid unit-months (23 possible), %s rule: %s", r, RULES[[r]]), "", md_table(by_rule[[r]]$valid_unit_months), "")
txt <- c(txt, "## Coverage screen (2022, all_roadtype, jam-derived coverage)", "",
  sprintf("Target-cell range of perc_waze_coverage: %.4f to %.4f. All %d target cells have a 2022 value; per-cell values stay in the ignored panel file.",
          cov_range[1], cov_range[2], nrow(target_cov)), "",
  "## Donor pools", "", md_table(rbindlist(lapply(by_rule, `[[`, "pool_counts"))), "")
writeLines(txt, file.path(STEP1_OUT, "panel_summary.md"))
DBI::dbDisconnect(con, shutdown = TRUE)
cat(txt, sep = "\n")
