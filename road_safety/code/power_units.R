# Units for the power scripts (04_power.R, 04b_power_conformal.R): pre-period crashes through
# load_pre(), treated areas, donor pools with their screens, and the count matrix builder.
# Sourced after code/helpers.R. Writes nothing.
# Donor screens, fixed before any run:
MIN_DONOR_MEAN <- 3        # donor screen: at least 3 crashes (all types) per month on average, pre-period
MAX_DONOR_ZERO_SHARE <- 0.2  # and at most 20 percent of pre-period months with no crash (plan item 6)

pre <- load_pre(CRASHES_SPATIAL)
months <- seq(PRE_START, month_start(PRE_END), by = "month")
quarters <- seq(as.Date("2021-03-01"), as.Date("2023-09-01"), by = "3 months")
pre[, `:=`(t_month = match(month_start(fecha), months), t_quarter = match(quarter_start(fecha), quarters),
           all_crashes = TRUE)]
stopifnot(!anyNA(pre$t_month), length(months) == 35L, length(quarters) == 11L)

# ---- Units ---------------------------------------------------------------------------------
# Parishes come from the GeoQuito polygons (02_spatial.R): membership by point in polygon, urban by
# the official INEC DPA code (170101 to 170132), "wholly beyond 2 km" by the polygon's distance to
# the line, BRT crossing by trunk corridor length inside the parish part beyond 2 km (> 100 m).
ptab <- fread(PARISHES_TABLE)
stopifnot(nrow(ptab) == 65L)
urban_codes <- ptab[urban == TRUE, parish_code]
wholly_codes <- ptab[wholly_beyond_2km == TRUE, parish_code]
brt_core_codes <- ptab[brt_core_crosses_part_beyond_2km == TRUE, parish_code]      # Trolebus, Ecovia
brt_any_codes <- ptab[brt_any_crosses_part_beyond_2km == TRUE, parish_code]        # plus Central Norte
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG, quiet = TRUE)), CRS_UTM))
# Resolution-7 cells wholly beyond 2 km: distance from the cell polygon (not its centre) to the line.
con <- connect_duckdb()
duckdb::duckdb_register(con, "r7", data.frame(h3_r7 = unique(pre$h3_r7)))
r7 <- as.data.table(DBI::dbGetQuery(con, "SELECT h3_r7, h3_cell_to_boundary_wkt(h3_r7) AS wkt FROM r7"))
DBI::dbDisconnect(con, shutdown = TRUE)
r7[, polygon_dist_line_m := as.numeric(st_distance(st_transform(st_as_sfc(wkt, crs = 4326), CRS_UTM), line))]
# The H3 WKT is (lng lat): if the order were swapped, the centroid latitudes would be near -78, not near 0.
stopifnot(all(abs(st_coordinates(suppressWarnings(st_centroid(st_as_sfc(r7$wkt, crs = 4326))))[, 2]) < 0.7))
r7_far <- r7[polygon_dist_line_m > 2000, h3_r7]
r7_urban <- pre[, .(u = mean(zona %in% "URBANA")), by = h3_r7][u > 0.5, h3_r7]

# Each unit set: crash rows labelled with a unit name. The urban-street outcomes (candidate 1, Leonel
# 2026-09-27) drop crashes whose PRINCIPAL or SECUNDARIA names a fast road (01_build.R's list);
# "_nms" also drops those naming Av. Mariscal Sucre (sensitivity). Not used by the default runs.
tag <- function(d, unit) d[, .(unit = unit, t_month, t_quarter, all_crashes, injury_or_fatal, pedestrian,
                               urban_street_all = !fast_road, urban_street_injury = injury_or_fatal & !fast_road,
                               urban_street_nms_all = !fast_road & !av_mariscal_sucre,
                               urban_street_nms_injury = injury_or_fatal & !fast_road & !av_mariscal_sucre)]
treated_sets <- list(
  pooled_500m = tag(pre[catchment_500 == TRUE], "treated"),
  pooled_1km = tag(pre[catchment_1km == TRUE], "treated"),
  corridor_500m = tag(pre[corridor_500 == TRUE], "treated"))
stations <- sort(unique(pre$nearest_station))
for (s in stations) treated_sets[[paste0("station_1km: ", s)]] <- tag(pre[catchment_1km == TRUE & nearest_station == s], "treated")

by_parish <- function(d) d[, tag(.SD, parroquia_polygon), by = parroquia_polygon][, parroquia_polygon := NULL][]
pool_A <- pre[parish_code %in% intersect(urban_codes, wholly_codes)]
pool_O1 <- pre[parish_code %in% urban_codes & beyond_2km_line == TRUE]
pool_O2 <- pre[!is.na(parish_code) & beyond_2km_line == TRUE]
# Donor rows lie beyond 2 km of the line and treated rows within 1 km of a station or 500 m of the
# line, so they never overlap; parish names are unique in the layer (02_spatial.R checks both).
stopifnot(all(pool_A$beyond_2km_line), all(pool_O2$beyond_2km_line),
          all(pre[catchment_1km | corridor_500, dist_line_m] < 2000), !anyDuplicated(ptab$parish))
donor_sets <- list(
  # Rule of Leonel's 2026-09-25 approval, replaced by pool B on 2026-09-27: urban parishes wholly
  # beyond 2 km of the line (parish polygons). Kept for the committed default outputs.
  A_urban_parishes_beyond_2km = by_parish(pool_A),
  # Options for Leonel's decision, not approved:
  O1_urban_parish_parts_beyond_2km = by_parish(pool_O1),
  O2_O1_plus_rural_parish_parts = by_parish(pool_O2),
  O3_urban_h3_r7_beyond_2km = pre[h3_r7 %in% intersect(r7_far, r7_urban)][, tag(.SD, h3_r7), by = h3_r7][, h3_r7 := NULL][],
  # Without donors crossed by the BRT trunk corridors (Leonel's decision 5): Trolebus and Ecovia;
  # "_cn" also drops those crossed by the Central Norte MetroBus (an addition).
  # (A without Trolebus/Ecovia-crossed donors is identical to A: none is crossed, so it is not run.)
  O1_no_brt = by_parish(pool_O1[!parish_code %in% brt_core_codes]),
  O2_no_brt = by_parish(pool_O2[!parish_code %in% brt_core_codes]),
  O1_no_brt_cn = by_parish(pool_O1[!parish_code %in% brt_any_codes]),
  O2_no_brt_cn = by_parish(pool_O2[!parish_code %in% brt_any_codes]))
screen <- function(d) {
  zero <- d[, .N, by = .(unit, t_month)][, .(months_with_crash = .N), by = unit]
  keep <- merge(d[, .(mean = .N / length(months)), by = unit], zero, by = "unit")[
    mean >= MIN_DONOR_MEAN & 1 - months_with_crash / length(months) <= MAX_DONOR_ZERO_SHARE, unit]
  d[unit %in% keep]
}
donor_sets <- lapply(donor_sets, screen)

# Pool B (Leonel, 2026-09-27, replacing the urban-only rule): all parishes, urban and rural, wholly
# beyond 2 km of the line; parishes crossed by the Trolebus or Ecovia trunk excluded (none of the
# wholly-beyond parishes is; Guamani, counted as crossed, is not wholly beyond 2 km anyway); those
# crossed by the Central Norte MetroBus dropped in a sensitivity. Same volume screen. Kept apart from
# donor_sets so that the default runs of 04_power.R and 04b_power_conformal.R are unchanged.
pool_B <- pre[parish_code %in% setdiff(wholly_codes, brt_core_codes)]
donor_sets_b <- lapply(list(
  B_parishes_beyond_2km = by_parish(pool_B),
  B_no_central_norte = by_parish(pool_B[!parish_code %in% brt_any_codes])), screen)

# Candidate 2: composite donors (code/composites.R). Candidate 3, conformal route: the metro's own
# gradient, crashes within 1 km of a station against the ring 1 to 2 km from the nearest station, as a
# single-unit "pool" (DID weight 1), so the gap is the inner index minus the outer index.
source("code/composites.R")
donor_sets_g <- list(G_outer_ring_1_2km = tag(pre[dist_station_m >= 1000 & dist_station_m < 2000], "outer ring 1-2 km"))
# Amendment 1 (2026-10-01): the main comparator, all parishes entirely beyond 2 km of the line (no volume
# screen), pooled into one series (crash-weighted).
donor_sets_d <- list(D_distant_pooled = tag(pool_B, "distant parishes (pooled)"))
stopifnot(!anyNA(pre$fast_road), !anyNA(pre$av_mariscal_sucre))

pool_summary <- rbindlist(lapply(names(donor_sets), function(p) donor_sets[[p]][, .(
  pool = p, donors_after_screen = uniqueN(unit), smallest_attainable_p = round(1 / (uniqueN(unit) + 1), 4),
  mean_crashes_per_donor_month = round(.N / uniqueN(unit) / length(months), 2))]))

# Optional later start of the pre-period (RS_PRE_START, for example 2022-01-01). Donors are screened
# on the full pre-period above, so the donor set is the same under every start; the series are then
# cut to start at RS_PRE_START. Quarterly designs are not built for a later start.
RUN_START <- if (nzchar(Sys.getenv("RS_PRE_START"))) as.Date(Sys.getenv("RS_PRE_START")) else PRE_START
stopifnot(RUN_START >= PRE_START)
if (RUN_START > PRE_START) {
  off <- match(RUN_START, months) - 1L
  stopifnot(!is.na(off))
  shift <- function(d) d[t_month > off][, `:=`(t_month = t_month - off, t_quarter = NA_integer_)][]
  treated_sets <- lapply(treated_sets, shift)
  donor_sets <- lapply(donor_sets, shift)
  donor_sets_b <- lapply(donor_sets_b, shift)
  donor_sets_c <- lapply(donor_sets_c, shift)
  donor_sets_g <- lapply(donor_sets_g, shift)
  donor_sets_d <- lapply(donor_sets_d, shift)
  months <- months[months >= RUN_START]
  quarters <- as.Date(character())
}
# Optional months left out of the panel (RS_DROP_MONTHS, comma-separated, for example
# 2022-06-01,2023-11-01: the June 2022 strike and the start of the 2023 power rationing; Leonel,
# 2026-10-01). Their rows are removed and the remaining months renumbered, so they are out of the
# permutation set and the fake openings alike. Quarterly designs are not built then.
if (nzchar(Sys.getenv("RS_DROP_MONTHS"))) {
  drop_m <- as.Date(strsplit(Sys.getenv("RS_DROP_MONTHS"), ",")[[1]])
  stopifnot(!anyNA(drop_m), all(drop_m %in% months))
  keep_t <- which(!months %in% drop_m)
  renum <- function(d) d[t_month %in% keep_t][, `:=`(t_month = match(t_month, keep_t), t_quarter = NA_integer_)][]
  treated_sets <- lapply(treated_sets, renum)
  donor_sets <- lapply(donor_sets, renum); donor_sets_b <- lapply(donor_sets_b, renum)
  donor_sets_c <- lapply(donor_sets_c, renum); donor_sets_g <- lapply(donor_sets_g, renum); donor_sets_d <- lapply(donor_sets_d, renum)
  months <- months[keep_t]
  quarters <- as.Date(character())
}

# Count matrix: rows = donors (sorted) then the treated unit last; columns = periods.
count_matrix <- function(tr, dn, outcome, time) {
  d <- rbind(dn, tr)[get(outcome) == TRUE & !is.na(get(paste0("t_", time)))]
  np <- if (time == "month") length(months) else length(quarters)
  units <- c(sort(unique(dn$unit)), "treated")
  m <- matrix(0L, length(units), np, dimnames = list(units, NULL))
  cnt <- d[, .N, by = .(unit, t = get(paste0("t_", time)))]
  m[cbind(match(cnt$unit, units), cnt$t)] <- cnt$N
  m
}
