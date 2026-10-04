# Which OSM highway classes reproduce the provider's 2022 all_roadtype OSM length per cell?
# Scratch only. Reads the 2022 rows of roadlengths_quito.csv (pre-period) and prints aggregates only.
source("Scripts/Congestion/step1_helpers.R")
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
j <- jsonlite::fromJSON(file.path(S, "osm_roads_20220101.json"), simplifyVector = FALSE)$elements
roads <- st_sf(osm_id = sapply(j, `[[`, "id"), highway = sapply(j, function(e) e$tags$highway),
  geometry = st_sfc(lapply(j, function(e) st_linestring(do.call(rbind, lapply(e$geometry, function(p) c(p$lon, p$lat))))), crs = 4326))
drive <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
           "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link")
sets <- list(drivable = drive, drivable_service = c(drive, "service"), all_highway = unique(roads$highway))
grid <- fread(grid_path, colClasses = "character")
hex <- st_as_sf(grid, wkt = "h3_geometry_r8", crs = 4326)
box <- st_as_sfc(st_bbox(c(xmin = -78.540, xmax = -78.485, ymin = -0.250, ymax = -0.190), crs = 4326))
hex <- hex[st_within(hex, box, sparse = FALSE)[, 1], ]
rl <- fread(roadlength_path)[year == 2022 & roadtype == "all_roadtype", .(grid_id, osm_prov = osm_sum_length)]
pieces <- suppressWarnings(st_intersection(roads, hex[, "grid_id"]))
pieces$len <- as.numeric(st_length(pieces))
pl <- as.data.table(st_drop_geometry(pieces))
res <- rbindlist(lapply(names(sets), function(s) {
  x <- pl[highway %in% sets[[s]], .(osm_ours = sum(len)), by = grid_id]
  m <- merge(data.table(grid_id = hex$grid_id), x, by = "grid_id", all.x = TRUE)[is.na(osm_ours), osm_ours := 0]
  m <- merge(m, rl, by = "grid_id")[osm_prov > 0]
  data.table(set = s, cells = nrow(m), total_ratio_ours_over_provider = round(sum(m$osm_ours) / sum(m$osm_prov), 3),
             median_cell_ratio = round(median(m$osm_ours / m$osm_prov), 3),
             p10 = round(quantile(m$osm_ours / m$osm_prov, 0.1), 3), p90 = round(quantile(m$osm_ours / m$osm_prov, 0.9), 3),
             corr = round(cor(m$osm_ours, m$osm_prov), 3))
}))
print(res)
saveRDS(res, file.path(S, "osm_class_calibration.rds"))
