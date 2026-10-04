# Shared setup for Step 1 of analysis plan v2 (docs/analysis_plan.md). Source from congestion/.
# Step 1 is pre-period only: no outcome dated December 2023 or later is read or written.
stopifnot(file.exists("AGENTS.md"))
Sys.setenv(TZ = "America/Guayaquil")
.libPaths(c(normalizePath("Output/Waze/_environment/R-library"), .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
})
options(width = 160)

# Calendar (plan section 5). Months are integers YYYYMM, as delivered.
PRE_FIRST <- 202201L
PRE_LAST <- 202311L
PRE_MONTHS <- as.integer(format(seq(as.Date("2022-01-01"), as.Date("2023-11-01"), by = "month"), "%Y%m"))
TRAIN_MONTHS <- PRE_MONTHS[PRE_MONTHS <= 202305L]    # tuning and training, January 2022 to May 2023
HOLDOUT_MONTHS <- PRE_MONTHS[PRE_MONTHS >= 202306L]  # terminal holdout, June to November 2023
DEC22_MONTHS <- PRE_MONTHS[PRE_MONTHS >= 202212L]    # December 2022 start sensitivity
stopifnot(length(PRE_MONTHS) == 23L, length(TRAIN_MONTHS) == 17L, length(HOLDOUT_MONTHS) == 6L,
          length(DEC22_MONTHS) == 12L)

# Hours (plan section 4; paper 02_build_weekly_panels.R lines 59-61). Weekdays only per the provider.
HOURS <- list(peak = c(7L, 8L, 9L, 17L, 18L, 19L), morning = 7:9, evening = 17:19, night = 0:4)

# Units (plan section 2). Seeds are the H3 r8 cells holding the published monitor points.
SEEDS <- c(CENTER = "8866d33885fffff", BELISARIO = "8866d33aa3fffff")

# Flag rule (plan section 1): contaminated keys are missing for every outcome.
FLAG_NEGATIVE <- c("tci_waze_ratio", "tci_severe_waze_ratio", "tc_spread_osm_ratio", "tc_spread_waze_ratio",
                   "tc_severe_spread_osm_ratio", "tc_severe_spread_waze_ratio")
FLAG_ABOVE_100 <- "tc_severe_persistance_ratio"
SENTINELS <- c(-998, -999)

# Donor rules (plan section 3).
SLOT_THRESHOLD <- 20
SLOT_THRESHOLD_SENS <- 12
LOW_EXPOSURE_M <- 4000

ZERO_LABEL <- "provisional zero coding"
STEP1_DATA <- "Data/Waze/step1"          # ignored derived data
STEP1_OUT <- "Output/Waze/step1"         # diagnostics
FREEZE_DIR <- "Output/step1_freeze"      # committed frozen specification
for (d in c(STEP1_DATA, STEP1_OUT, FREEZE_DIR, "Output/Waze/_cache")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

grid_path <- "Data/Waze/raw/grids_polygons.csv"
raw_parquet <- "Data/Waze/raw/grids_quito_hourly_2019-2025.parquet"
roadlength_path <- "Data/Waze/raw/roadlengths_quito.csv"
pre_block <- "Data/Waze/parquet_step1/all_roadtype_pre.parquet"

duck <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  DBI::dbExecute(con, "SET threads = 4")
  DBI::dbExecute(con, "SET memory_limit = '4GB'")
  DBI::dbExecute(con, paste("SET temp_directory =", DBI::dbQuoteString(con, normalizePath("Output/Waze/_cache"))))
  DBI::dbExecute(con, paste("SET extension_directory =", DBI::dbQuoteString(con,
    normalizePath("Output/Waze/_environment/duckdb_extensions"))))
  DBI::dbExecute(con, "SET autoinstall_known_extensions = false")
  DBI::dbExecute(con, "LOAD h3")
  con
}

sha256 <- function(path) unname(sapply(path, function(p)
  strsplit(system2("sha256sum", shQuote(normalizePath(p)), stdout = TRUE), " ")[[1]][1]))

# Cell geography. Same rules as make_spatial_groups() in inventory_helpers.R, rebuilt here
# without its side effect of rewriting the tracked Output/Waze/inventory/cell_groups.rds.
build_groups <- function(con) {
  grids <- fread(grid_path, colClasses = "character", select = "grid_id")
  stopifnot(!anyDuplicated(grids$grid_id))
  DBI::dbWriteTable(con, "grid_reference", as.data.frame(grids), overwrite = TRUE)
  h3 <- as.data.table(DBI::dbGetQuery(con, paste(
    "SELECT grid_id, h3_is_valid_cell(grid_id) valid_h3, h3_get_resolution(grid_id) resolution,",
    "h3_cell_to_latlng(grid_id)[1] latitude, h3_cell_to_latlng(grid_id)[2] longitude",
    "FROM grid_reference ORDER BY grid_id")))
  stopifnot(all(h3$valid_h3), all(h3$resolution == 8L))
  stations <- st_transform(st_zm(st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)), 4326)
  monitors <- st_transform(st_zm(st_read("Data/spatial/Distancia_REMMAQ_Metro.gpkg", quiet = TRUE)), 4326)
  points <- st_as_sf(as.data.frame(h3), coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  nearest_station_m <- apply(as.matrix(st_distance(points, stations)), 1, min)
  seeds <- sapply(c(CENTER = "Centro", BELISARIO = "Belisario"), function(name) {
    xy <- st_coordinates(monitors[monitors$Station == name, ])[1, ]
    DBI::dbGetQuery(con, "SELECT h3_latlng_to_cell_string(?, ?, 8) seed",
                    params = list(unname(xy["Y"]), unname(xy["X"])))$seed
  })
  stopifnot(identical(unname(seeds), unname(SEEDS)))  # plan section 2 seeds
  rings <- lapply(SEEDS, function(s)
    sort(DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) grid_id", params = list(s))$grid_id))
  stopifnot(all(lengths(rings) == 7L), all(unlist(rings) %in% h3$grid_id), !anyDuplicated(unlist(rings)))
  group <- ifelse(nearest_station_m <= 1000, "CORRIDOR", ifelse(nearest_station_m <= 2000, "RING", "REST"))
  group[h3$grid_id %in% rings$CENTER] <- "CENTER"
  group[h3$grid_id %in% rings$BELISARIO] <- "BELISARIO"
  cells <- data.table(grid_id = h3$grid_id, group, latitude = h3$latitude, longitude = h3$longitude,
                      nearest_station_m)
  seed_xy <- cells[match(SEEDS, grid_id), .(longitude, latitude)]
  seed_pts <- st_as_sf(as.data.frame(seed_xy), coords = c("longitude", "latitude"), crs = 4326)
  d <- units::drop_units(st_distance(points, seed_pts))
  cells[, `:=`(dist_center_seed_m = d[, 1], dist_belisario_seed_m = d[, 2])]
  list(cells = cells, rings = rings, stations = stations, monitors = monitors)
}

md_table <- function(x, digits = 4L) {
  x <- as.data.frame(x)
  x[] <- lapply(x, function(v) if (is.double(v)) formatC(v, digits = digits, format = "f") else as.character(v))
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(v) paste0("| ", paste(v, collapse = " | "), " |")))
}
