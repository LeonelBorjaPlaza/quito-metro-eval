# Shared Phase B setup. Source from the repository root; no Arrow is loaded.
stopifnot(file.exists("AGENTS.md"))
Sys.setenv(TZ = "America/New_York")
.libPaths(c(normalizePath("Output/Waze/_environment/R-library"), .libPaths()))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(ggplot2))
options(width = 160, digits = 15)
inventory_dir <- "Output/Waze/inventory"
dir.create(inventory_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("Output/Waze/_cache", recursive = TRUE, showWarnings = FALSE)
parquet_path <- "Data/Waze/raw/grids_quito_hourly_2019-2025.parquet"
csv_path <- "Data/Waze/raw/grids_quito_hourly_2019-2025.csv"
grid_path <- "Data/Waze/raw/grids_polygons.csv"
connect_waze <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  DBI::dbExecute(con, "SET threads = 4")
  DBI::dbExecute(con, "SET memory_limit = '4GB'")
  DBI::dbExecute(con, paste("SET temp_directory =", DBI::dbQuoteString(con, normalizePath("Output/Waze/_cache"))))
  DBI::dbExecute(con, paste("SET extension_directory =", DBI::dbQuoteString(con,
    normalizePath("Output/Waze/_environment/duckdb_extensions"))))
  DBI::dbExecute(con, "SET autoinstall_known_extensions = false")
  DBI::dbExecute(con, "LOAD h3")
  DBI::dbExecute(con, paste("CREATE VIEW raw AS SELECT * FROM read_parquet(", DBI::dbQuoteString(con, parquet_path), ")"))
  con
}
md_table <- function(x) {
  x <- as.data.frame(x)
  x[] <- lapply(x, function(v) gsub("|", "/", as.character(v), fixed = TRUE))
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(v) paste0("| ", paste(v, collapse = " | "), " |")))
}
fmt_n <- function(x) format(x, scientific = FALSE, trim = TRUE, big.mark = ",")
fmt <- function(x, digits = 6L) ifelse(is.na(x), "NA", trimws(formatC(x, digits = digits, format = "g")))
period_of <- function(x) ifelse(x < 202312, "Pre-opening",
  ifelse(x <= 202408, "P1", ifelse(x <= 202412, "Disruption", "P2")))
hour_block <- function(x) ifelse(x %in% c(7L, 8L), "Morning peak",
  ifelse(x %in% c(17L, 18L), "Evening peak", ifelse(x %in% c(22L, 23L, 0:5), "Night", "Other")))
date_month <- function(x) as.Date(paste0(substr(x, 1, 4), "-", substr(x, 5, 6), "-01"))
mark_calendar <- function(plot) plot +
  annotate("rect", xmin = as.Date("2024-09-01"), xmax = as.Date("2025-01-01"),
           ymin = -Inf, ymax = Inf, fill = "grey45", alpha = 0.14) +
  geom_vline(xintercept = as.Date("2023-12-01"), linetype = "dashed", colour = "#a33b20") +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank())

make_spatial_groups <- function(con) {
  grids <- fread(grid_path, colClasses = "character")
  stopifnot(!anyDuplicated(grids$grid_id))
  DBI::dbWriteTable(con, "grid_reference", as.data.frame(grids))
  h3 <- as.data.table(DBI::dbGetQuery(con, paste(
    "SELECT grid_id, h3_is_valid_cell(grid_id) valid_h3, h3_get_resolution(grid_id) resolution,",
    "h3_cell_to_boundary_wkb(grid_id) h3_wkb, h3_cell_to_latlng(grid_id)[1] latitude,",
    "h3_cell_to_latlng(grid_id)[2] longitude FROM grid_reference ORDER BY grid_id")))
  setkey(grids, grid_id); setkey(h3, grid_id)
  delivered <- st_as_sf(grids, wkt = "h3_geometry_r8", crs = 4326)
  # WKB preserves precision; the extension's WKT printer rounds to six decimals.
  rebuilt <- st_as_sfc(structure(h3$h3_wkb,class="WKB"),crs=4326)
  # UTM 17S is used only for metric geometric comparisons, never assigned to a source.
  a <- st_transform(delivered, 32717); b <- st_transform(rebuilt, 32717)
  boundary_m <- as.numeric(st_distance(a, b, by_element = TRUE, which = "Hausdorff"))
  area_relative <- abs(as.numeric(st_area(a)) - as.numeric(st_area(b))) / as.numeric(st_area(b))
  stations <- st_transform(st_zm(st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)), 4326)
  monitors <- st_read("Data/spatial/Distancia_REMMAQ_Metro.gpkg", quiet = TRUE)
  st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE) # Verify alignment remains readable.
  points <- st_as_sf(as.data.frame(h3), coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  distance_station <- st_distance(points, stations)
  nearest_station_m <- apply(as.matrix(distance_station), 1, min)
  sf_distance_m <- as.numeric(distance_station[, stations$Name == "San Francisco"])
  bel_distance_m <- as.numeric(st_distance(points, monitors[monitors$Station == "Belisario", ]))
  membership <- rbindlist(lapply(c("Centro", "Belisario"), function(name) {
    point <- monitors[monitors$Station == name, ]
    xy <- st_coordinates(point)[1, ]
    seed <- DBI::dbGetQuery(con, "SELECT h3_latlng_to_cell_string(?, ?, 8) seed",
                           params = list(unname(xy["Y"]), unname(xy["X"])))$seed
    disk <- DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) grid_id", params = list(seed))$grid_id
    data.table(group = if (name == "Centro") "CENTER" else "BELISARIO", published_point_seed = seed,
               grid_id = sort(disk), in_delivered_grid = disk[order(disk)] %in% grids$grid_id)
  }))
  stopifnot(all(membership$in_delivered_grid), !anyDuplicated(membership$grid_id))
  group <- ifelse(nearest_station_m <= 1000, "CORRIDOR", ifelse(nearest_station_m <= 2000, "RING", "REST"))
  group[h3$grid_id %in% membership[group == "CENTER", grid_id]] <- "CENTER"
  group[h3$grid_id %in% membership[group == "BELISARIO", grid_id]] <- "BELISARIO"
  # Both monitor neighborhoods take priority, then all station buffers, then the ring.
  attributes <- data.table(grid_id = h3$grid_id, group, latitude = h3$latitude, longitude = h3$longitude,
    nearest_station_m, san_francisco_m = sf_distance_m, belisario_published_point_m = bel_distance_m,
    original_center_buffer = sf_distance_m <= 1000, original_belisario_buffer = bel_distance_m <= 1000,
    valid_h3 = h3$valid_h3, resolution = h3$resolution, boundary_hausdorff_m = boundary_m,
    relative_area_error = area_relative, valid_polygon = st_is_valid(delivered),
    centroid_in_request_box = h3$latitude >= -0.45 & h3$latitude <= 0.05 &
      h3$longitude >= -78.62 & h3$longitude <= -78.30)
  boundary_box <- st_as_sfc(st_bbox(c(xmin = -78.62, ymin = -0.45, xmax = -78.30, ymax = 0.05), crs = st_crs(4326)))
  attributes[, intersects_request_box := lengths(st_intersects(delivered, boundary_box)) > 0L]
  attributes[, within_request_box := lengths(st_within(delivered, boundary_box)) > 0L]
  DBI::dbWriteTable(con, "cell_groups", as.data.frame(attributes))
  spatial <- st_sf(as.data.frame(attributes), geometry = st_geometry(delivered))
  saveRDS(spatial, file.path(inventory_dir, "cell_groups.rds"))
  fwrite(attributes, file.path(inventory_dir, "cell_groups.csv"))
  list(cells = attributes, neighborhoods = membership, bounds = st_bbox(delivered), stations = stations,
       monitors = monitors, groups = attributes[, .(grid_cells = .N), by = group][order(group)])
}
