# Amendment 5, items 2, 4, 10 and 11: tiles, pools, treated units, rings, the jam-speed outcome and the
# yearly adoption check. Pre period only (the panel is built by the pre-only loader; road lengths are
# read for 2019 to 2022 only). Series are saved in levels; the scale decision (40) is applied downstream.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_loader.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
scale <- fread(file.path(REDESIGN_OUT, "scale_decision.csv"))
stopifnot(nrow(scale) == 1L, scale$decision %in% c("levels", "proportions"))
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
pr <- panel$rules$amended
stopifnot(!is.null(pr$speed_block))
con <- duck()
cov <- load_coverage_2022(con)
tl <- build_tiles(con, pr, geog, cov)
BLOCKS <- c("peak", "morning", "evening")

# 1. Tile series and pools.
elig <- tl$tiles[donor_eligible == TRUE, tile]
ts <- rbindlist(lapply(BLOCKS, function(b) tile_series(pr$cell_block, tl$members[tile %in% elig], b)[, block := b]))
complete <- ts[, .(complete = !anyNA(value)), by = tile][complete == TRUE, tile]
tl$tiles[, complete_pre := tile %in% complete]
tl$tiles[, pool := fcase(donor_eligible & complete_pre & dmq, "main (DMQ)",
                         donor_eligible & complete_pre & !dmq, "check (neighbouring municipalities)",
                         default = NA_character_)]
main <- tl$tiles[pool == "main (DMQ)", tile]
# Amendment 5, item 4: tiles from neighbouring municipalities would join the main pool if fewer than 20
# DMQ tiles qualified. That branch is not implemented: the script stops instead, so the case is seen.
stopifnot(length(main) >= 20L)
# The scale test (40) must have used exactly this pool.
stopifnot(setequal(main, fread(file.path(REDESIGN_OUT, "scale_tiles.csv"))$tile))
counts <- rbindlist(list(
  data.table(step = "tiles touching the delivered grid", tiles = nrow(tl$tiles)),
  data.table(step = "all seven cells in the grid", tiles = tl$tiles[, sum(complete_in_grid)]),
  data.table(step = "quality: at least 4 of 7 cells saturated (mean >= 20 valid slots per month)", tiles = tl$tiles[, sum(complete_in_grid & quality)]),
  data.table(step = "and no cell in CENTER, its buffer, CORRIDOR, RING or BELISARIO", tiles = tl$tiles[, sum(complete_in_grid & quality & !excluded_group)]),
  data.table(step = "and complete peak, morning and evening index, January 2022 to November 2023", tiles = tl$tiles[, sum(donor_eligible & complete_pre)]),
  data.table(step = "main pool: in the DMQ (at least 4 cell centroids in the parish layers)", tiles = length(main)),
  data.table(step = "  of which valleys (Tumbaco, Los Chillos, Calderón)", tiles = tl$tiles[pool == "main (DMQ)", sum(valley)]),
  data.table(step = "  of which low exposure (every cell more than 4 km from any station)", tiles = tl$tiles[pool == "main (DMQ)", sum(low_exposure)]),
  data.table(step = "check pool: neighbouring municipalities", tiles = tl$tiles[pool == "check (neighbouring municipalities)", .N])))

# 2. Treated units and rings: cells with weights.
cw_center <- geog$unit_cells[unit == "CENTER" & kept == TRUE, .(grid_id, weight_m = road_m)]
rg <- redesign_groups(con, geog)   # BELISARIO rebuilt around the Colegio San Gabriel cell (item 11)
cw_bel <- merge(data.table(grid_id = rg$belisario), cov[, .(grid_id, weight_m = osm_sum_length)], by = "grid_id")
stopifnot(all(rg$belisario %in% pr$cells$grid_id))
stopifnot(nrow(cw_center) == 15L, nrow(cw_bel) == 7L)
stations <- st_transform(st_zm(st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)), 4326)
stopifnot(nrow(stations) == 15L)
# Segments: north, centre and south by station latitude (five stations each), an approximation of the
# line's station order, since the line runs roughly north to south.
st_lat <- st_coordinates(stations)[, 2]
seg_of_station <- cut(rank(-st_lat, ties.method = "first"), c(0, 5, 10, 15), labels = c("north", "centre", "south"))
cells_xy <- as.data.table(DBI::dbGetQuery(con, "SELECT grid_id, h3_cell_to_latlng(grid_id)[1] lat, h3_cell_to_latlng(grid_id)[2] lon, h3_cell_to_parent(grid_id, 7) AS tile FROM g"))
DBI::dbDisconnect(con, shutdown = TRUE)
pts <- st_as_sf(cells_xy, coords = c("lon", "lat"), crs = 4326)
cells_xy[, segment := as.character(seg_of_station[apply(st_distance(pts, stations), 1, which.min)])]
cells_xy <- merge(cells_xy, rg$groups[, .(grid_id, group, step1_group)], by = "grid_id")
cells_xy <- merge(cells_xy, cov[, .(grid_id, osm_m = osm_sum_length)], by = "grid_id", all.x = TRUE)
popcells <- pr$cells$grid_id
# Rings use the distance groups: cells of CENTER's buffer enter only if their group is CORRIDOR or RING
# (the four buffer cells that were REST stay out of every ring and every pool).
ring_cells <- cells_xy[grid_id %in% popcells & !is.na(osm_m) & osm_m > 0 &
                       ((group == "CORRIDOR") | (group == "RING") ),
                       .(grid_id, ring = fifelse(group == "CORRIDOR", "corridor (up to 1 km)", "1 to 2 km"), segment, tile, weight_m = osm_m)]
ring_cells[, unit := paste(ring, segment, tile, sep = " | ")]

unit_cells <- rbindlist(list(cw_center[, .(unit = "CENTER", grid_id, weight_m)], cw_bel[, .(unit = "BELISARIO", grid_id, weight_m)],
                             ring_cells[, .(unit, grid_id, weight_m)],
                             tl$members[tile %in% c(main, tl$tiles[pool == "check (neighbouring municipalities)", tile]) & weight_m > 0,
                                        .(unit = tile, grid_id, weight_m)]))
unit_series <- function(blk) {
  x <- merge(pr$cell_block[block == blk, .(grid_id, date, value)], unit_cells, by = "grid_id", allow.cartesian = TRUE)
  x[, .(value = if (anyNA(value)) NA_real_ else sum(weight_m * value) / sum(weight_m)), by = .(unit, date)][, block := blk]
}
series <- rbindlist(lapply(BLOCKS, unit_series))
# Jam-speed index: congested-length-weighted mean of avg_jam_speed_ratio; missing when the main index is
# missing (composition rule) or when no jam was recorded in the unit-month.
sp <- merge(pr$speed_block[block == "peak"], unit_cells, by = "grid_id", allow.cartesian = TRUE)
speed <- sp[, .(speed = sum(weight_m * tci_speed_sum) / sum(weight_m * tci_sum)), by = .(unit, date)]
speed <- merge(series[block == "peak", .(unit, date, value)], speed, by = c("unit", "date"), all.x = TRUE)
speed[is.na(value), speed := NA_real_]
unit_meta <- rbindlist(list(
  data.table(unit = "CENTER", type = "treated"), data.table(unit = "BELISARIO", type = "treated"),
  unique(ring_cells[, .(unit, type = "ring", ring, segment)]),
  tl$tiles[!is.na(pool), .(unit = tile, type = fifelse(pool == "main (DMQ)", "donor tile", "check tile"), valley, low_exposure,
                           mean_km_to_line, min_km_to_station)]), fill = TRUE)
ring_complete <- series[unit %in% ring_cells$unit, .(complete = !anyNA(value)), by = unit]
unit_meta <- merge(unit_meta, ring_complete, by = "unit", all.x = TRUE)
pre_means <- series[date %in% USABLE_MONTHS, .(pre_mean = mean(value)), by = .(unit, block)]

# 3. Adoption check: yearly increments of cumulative jam length (waze_sum_length), 2019 to 2022 only.
con <- duck(); wl <- load_waze_length_to_2022(con); DBI::dbDisconnect(con, shutdown = TRUE)
# Waze length is whole-cell, so the denominator is each unit's whole-cell 2022 OSM length, held fixed
# across years (CENTER's in-polygon weights are not used here). A cell with no row in a year has no
# recorded jam extent yet and counts as 0; the number of such cell-years is reported.
adopt_units <- merge(unique(unit_cells[unit %in% c("CENTER", main), .(unit, grid_id)]), cov[, .(grid_id, osm_m = osm_sum_length)], by = "grid_id")
road_fixed <- adopt_units[, .(road_m = sum(osm_m, na.rm = TRUE)), by = unit]
adopt <- merge(CJ(grid_id = unique(adopt_units$grid_id), year = 2019:2022), wl[, .(grid_id, year, waze_sum_length)],
               by = c("grid_id", "year"), all.x = TRUE)
adopt <- merge(adopt_units[, .(unit, grid_id)], adopt, by = "grid_id", allow.cartesian = TRUE)
missing_rows <- adopt[, .(cells = .N, cells_without_row = sum(is.na(waze_sum_length))), by = .(group = fifelse(unit == "CENTER", "CENTER", "main-pool donor tiles"), year)]
adopt <- adopt[, .(waze_m = sum(fifelse(is.na(waze_sum_length), 0, waze_sum_length))), by = .(unit, year)]
adopt <- merge(adopt, road_fixed, by = "unit")[order(unit, year)]
adopt[, cum_share := waze_m / road_m][, increment := cum_share - shift(cum_share), by = unit]
adopt_summary <- rbind(
  adopt[unit == "CENTER" & !is.na(increment), .(group = "CENTER", year, median_increment = increment, p25 = NA_real_, p75 = NA_real_, units = 1L)],
  adopt[unit != "CENTER" & !is.na(increment), .(group = "main-pool donor tiles", median_increment = median(increment),
        p25 = quantile(increment, 0.25), p75 = quantile(increment, 0.75), units = .N), by = year], use.names = TRUE)

saveRDS(list(scale = scale, tiles = tl$tiles, members = tl$members, unit_cells = unit_cells, unit_meta = unit_meta,
             series = series, speed = speed, pre_means = pre_means, ring_cells = ring_cells, adopt = adopt),
        file.path(REDESIGN_DATA, "units.rds"))
fwrite(counts, file.path(REDESIGN_OUT, "tile_counts.csv"))
fwrite(adopt_summary, file.path(REDESIGN_OUT, "adoption_check.csv"))
fwrite(missing_rows[order(group, year)], file.path(REDESIGN_OUT, "adoption_check_missing_rows.csv"))
fwrite(unit_meta[type == "ring", .(units = .N, complete = sum(complete)), by = .(ring, segment)], file.path(REDESIGN_OUT, "ring_units.csv"))
fwrite(tl$tiles[!is.na(pool), .(tile, pool, valley, low_exposure, saturated_cells, mean_km_to_line = round(mean_km_to_line, 2))],
       file.path(REDESIGN_OUT, "donor_tiles.csv"))

# Map: tiles by pool over the grid, with the line and CENTER.
SIRES <- st_crs(geog$sires)
grid_sf <- st_transform(st_as_sf(fread(grid_path, colClasses = "character"), wkt = "h3_geometry_r8", crs = 4326), SIRES)
grid_sf <- merge(grid_sf, tl$members[, .(grid_id, tile)], by = "grid_id")
tile_sf <- aggregate(grid_sf["tile"], by = list(tile = grid_sf$tile), FUN = function(x) x[1])[, "tile"]
tile_sf <- merge(tile_sf, tl$tiles[, .(tile, pool = fifelse(is.na(pool), "not used", pool), valley)], by = "tile")
tile_sf$shown <- ifelse(tile_sf$pool == "main (DMQ)" & tile_sf$valley, "main pool, valley", tile_sf$pool)
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
p <- ggplot() + geom_sf(data = tile_sf, aes(fill = shown), colour = "grey70", linewidth = 0.1) +
  geom_sf(data = line, colour = "black", linewidth = 0.6) +
  geom_sf(data = st_transform(st_sfc(geog$polygons$CENTER, crs = 4326), SIRES), fill = NA, colour = "#b2182b", linewidth = 0.6) +
  scale_fill_manual(values = c(`main (DMQ)` = "#4daf4a", `main pool, valley` = "#a6d96a", `check (neighbouring municipalities)` = "#80b1d3", `not used` = "white"), name = NULL) +
  labs(title = "H3 resolution-7 donor tiles (Amendment 5)", subtitle = sprintf("Main pool %d tiles; scale decision: %s.", length(main), scale$decision),
       caption = "Polygon: Municipio del DMQ, GeoQuito.", x = NULL, y = NULL) + theme_minimal(base_size = 9)
ggsave(file.path(REDESIGN_OUT, "map_tiles.png"), p, width = 8, height = 9, dpi = 150, bg = "white")
print(counts); print(adopt_summary); print(unit_meta[type == "ring", .(units = .N, complete = sum(complete)), by = .(ring, segment)])
cat("CENTER pre-period mean (peak):", pre_means[unit == "CENTER" & block == "peak", pre_mean], "\n")
