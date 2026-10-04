# Shared setup for the item D redesign (plan Amendment 5, proposed). Pre period only: every outcome
# comes from the Step 1 panel (built by the pre-only loader) and the Amendment 2 geography.
# Source after step1_helpers.R and amend2_helpers.R.
REDESIGN_DATA <- "Data/Waze/redesign"   # ignored derived data
REDESIGN_OUT <- "Output/redesign"       # committed aggregates, maps and decisions
for (d in c(REDESIGN_DATA, REDESIGN_OUT)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Amendment 5, item 6: June 2022 (national strike) and November 2023 (power rationing) leave the
# weight fit and the permutation set. October 2023 stays.
EXCL_MONTHS <- c(202206L, 202311L)
USABLE_MONTHS <- setdiff(PRE_MONTHS, EXCL_MONTHS)
stopifnot(length(USABLE_MONTHS) == 21L)
VALLEY_ZONALS <- c("TUMBACO", "LOS CHILLOS", "CALDERON")
MIN_SATURATED_CELLS <- 4L   # a tile is kept when at least 4 of its 7 cells meet the saturation rule
TILE_RES <- 7L
DMQ_OUTSIDE <- "outside the DMQ parish layers"

# Amendment 5, item 11: the Belisario monitor stands on the roof of Colegio San Gabriel's administrative
# building (Av. América). The whole campus outline (OSM way 282603573, 15 vertices) lies in H3 cell
# 8866d338c9fffff, a neighbour of the seed built from the published coordinates rounded to 0.01 degrees
# (8866d33aa3fffff). The BELISARIO ring is rebuilt around the campus cell. Cells of the old ring that
# are not in the new one return to their distance group (CORRIDOR within 1 km of a station, RING within
# 2 km, otherwise REST).
BELISARIO_SEED_REDESIGN <- "8866d338c9fffff"
redesign_groups <- function(con, geog) {
  ring <- sort(DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) g", params = list(BELISARIO_SEED_REDESIGN))$g)
  stopifnot(length(ring) == 7L)
  g <- merge(copy(geog$groups_new), geog$cell_attr[, .(grid_id, km_to_nearest_station)], by = "grid_id")
  dist_group <- function(km) fifelse(km <= 1, "CORRIDOR", fifelse(km <= 2, "RING", "REST"))
  reverted <- g[group == "BELISARIO" & !grid_id %in% ring, grid_id]
  stopifnot(!any(reverted %in% geog$buffer_cells))   # reverted cells are far from CENTER's buffer
  g[grid_id %in% reverted, group := dist_group(km_to_nearest_station)]
  stopifnot(!any(ring %in% g[group == "CENTER", grid_id]))
  g[grid_id %in% ring, group := "BELISARIO"]
  list(groups = g[, .(grid_id, step1_group, group)], belisario = ring)
}

# H3 resolution-7 tiles of the delivered grid (Amendment 5, item 4).
# Composition: the tile's seven resolution-8 children. A tile is complete when all seven children are
# delivered grid cells. Cells with no pre-period record (plan section 1, state e) carry no weight.
# Index: total jam length over total road length = the mean of the cell indices weighted by the
# provider's 2022 all_roadtype OSM length. Weight-zero cells do not enter the composition rule.
build_tiles <- function(con, pr, geog, cov) {
  grid <- fread(grid_path, colClasses = "character", select = "grid_id")
  DBI::dbWriteTable(con, "g", as.data.frame(grid), overwrite = TRUE)
  par <- as.data.table(DBI::dbGetQuery(con, sprintf("SELECT grid_id, h3_cell_to_parent(grid_id, %d) AS tile FROM g", TILE_RES)))
  par[, tile := as.character(tile)]
  # h3_cell_to_parent on a string cell returns the parent as a string in the h3 extension; check width.
  stopifnot(all(nchar(par$tile) == 15L))
  kids <- unique(par$tile)
  DBI::dbWriteTable(con, "t", data.frame(tile = kids), overwrite = TRUE)
  ch <- as.data.table(DBI::dbGetQuery(con, "SELECT tile, unnest(h3_cell_to_children(tile, 8)) AS grid_id FROM t"))
  ch[, grid_id := as.character(grid_id)]
  stopifnot(ch[, .N, by = tile][, all(N == 7L)])
  rg <- redesign_groups(con, geog)
  m <- merge(ch, rg$groups[, .(grid_id, group)], by = "grid_id", all.x = TRUE)
  m <- merge(m, geog$cell_attr[, .(grid_id, zonal_administration, km_to_line, km_to_nearest_station)], by = "grid_id", all.x = TRUE)
  cells <- pr$cells[, .(grid_id, slots_mean, in_pop = TRUE)]
  m <- merge(m, cells, by = "grid_id", all.x = TRUE)
  m[is.na(in_pop), in_pop := FALSE]
  m <- merge(m, cov[, .(grid_id, osm_m = osm_sum_length)], by = "grid_id", all.x = TRUE)
  m[, `:=`(in_grid = !is.na(group), saturated = in_pop & !is.na(slots_mean) & slots_mean >= SLOT_THRESHOLD)]
  m[, weight_m := fifelse(in_pop & !is.na(osm_m) & osm_m > 0, osm_m, 0)]
  tiles <- m[, .(
    cells_in_grid = sum(in_grid), cells_in_population = sum(in_pop), saturated_cells = sum(saturated),
    road_m = sum(weight_m), excluded_group = any(group %in% c("CENTER", "BUFFER", "CORRIDOR", "RING", "BELISARIO")),
    dmq_cells = sum(!is.na(zonal_administration) & zonal_administration != DMQ_OUTSIDE),
    valley_cells = sum(zonal_administration %in% VALLEY_ZONALS),
    min_km_to_station = suppressWarnings(min(km_to_nearest_station, na.rm = TRUE)),
    mean_km_to_line = mean(km_to_line, na.rm = TRUE)), by = tile]
  tiles[, `:=`(complete_in_grid = cells_in_grid == 7L, quality = saturated_cells >= MIN_SATURATED_CELLS,
               dmq = dmq_cells >= 4L, valley = valley_cells >= 4L, low_exposure = min_km_to_station > LOW_EXPOSURE_M / 1000)]
  tiles[, donor_eligible := complete_in_grid & quality & !excluded_group & road_m > 0]
  list(tiles = tiles[order(tile)], members = m[order(tile, grid_id)])
}

# mclapply returns NULL or a try-error for a worker that died (for example out of memory); rbindlist would
# drop such jobs silently. Stop instead.
check_parallel <- function(res, n_jobs) {
  bad <- vapply(res, function(x) is.null(x) || inherits(x, "try-error"), TRUE)
  if (length(res) != n_jobs || any(bad)) stop("parallel jobs lost or failed: ", sum(bad), " of ", n_jobs)
  invisible(res)
}

# Road-weighted tile series for one block; a tile-month exists only if every positive-weight cell is valid.
tile_series <- function(cell_block, members, blk = "peak") {
  w <- members[weight_m > 0, .(tile, grid_id, weight_m)]
  x <- merge(cell_block[block == blk, .(grid_id, date, value)], w, by = "grid_id")
  # Every weighted cell must be present in every month (the panel holds all population cells).
  need <- w[, .(n_need = .N), by = tile]
  got <- x[, .(n_got = uniqueN(grid_id)), by = .(tile, date)]
  stopifnot(all(merge(got, need, by = "tile")[, n_got == n_need]), nrow(got) == nrow(need) * length(PRE_MONTHS))
  x[, .(value = if (anyNA(value)) NA_real_ else sum(weight_m * value) / sum(weight_m)), by = .(tile, date)]
}
