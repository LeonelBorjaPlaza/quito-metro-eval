#=========================================================
#  monitor_distances.R
#  Workstream A. Distances from each REMMAQ monitor to the nearest
#  Metro Line 1 station and to the line, under (1) the coordinates
#  in the paper's distance layer Distancia_REMMAQ_Metro.gpkg, and
#  (2) documented site locations where a public source gives one.
#  Also the range of distances within the 0.01-degree cell each
#  coarse published coordinate allows (truncated or rounded).
#  Changes no distance used by the pipeline.
#
#  Run from air_quality/ with the system sf (sf is not in renv.lock;
#  --vanilla skips the renv activation in .Rprofile):
#    Rscript --vanilla code/local/diagnostics/monitor_distances.R > ../logs/aq_monitor_distances.log 2>&1
#  Inputs:  data/for_maps/{Distancia_REMMAQ_Metro,MetroStations,MetroLine}.gpkg
#  Output:  output/local/diagnostics/monitor_distances/
#=========================================================

suppressMessages(library(sf))
print(sf_extSoftVersion())

maps    <- file.path("data", "for_maps")
out_dir <- file.path("output", "local", "diagnostics", "monitor_distances")
stopifnot(dir.exists(maps))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

UTM <- 32717   # WGS 84 / UTM zone 17S, metres

mon  <- st_zm(st_read(file.path(maps, "Distancia_REMMAQ_Metro.gpkg"), quiet = TRUE))
sta  <- st_transform(st_zm(st_read(file.path(maps, "MetroStations.gpkg"), quiet = TRUE)), UTM)
line <- st_transform(st_zm(st_read(file.path(maps, "MetroLine.gpkg"), quiet = TRUE)), UTM)
stopifnot(nrow(sta) == 15, nrow(line) == 1, nrow(mon) == 9, st_crs(mon) == st_crs(4326))
cat("Metro layers CRS (custom, read by PROJ):\n",
    st_crs(st_read(file.path(maps, "MetroStations.gpkg"), quiet = TRUE))$proj4string, "\n")
# Station points should lie on the line; report how far they are from it
sta_off_m <- round(as.numeric(st_distance(sta, line)), 1)
cat("Metro station points: distance to the line geometry, metres:\n")
print(setNames(sta_off_m, sta$Name))

dist_km <- function(lon, lat) {
  p <- st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), UTM)
  d_sta <- as.numeric(st_distance(p, sta))
  list(station_km = min(d_sta) / 1000,
       nearest = sta$Name[which.min(d_sta)],
       line_km = as.numeric(st_distance(p, line)) / 1000)
}

# Decimal places of each published coordinate (0.01-degree values are coarse)
ndec <- function(x) {
  t <- sub("0+$", "", formatC(abs(x), format = "f", digits = 6))
  nchar(sub("^[0-9]*\\.?", "", t))
}

xy <- st_coordinates(mon)
pub <- data.frame(station = mon$Station, lon = xy[, 1], lat = xy[, 2],
                  layer_hub = mon$HubName, layer_hubdist_km = mon$HubDist)
pub$decimals <- pmax(ndec(pub$lon), ndec(pub$lat))
res <- do.call(rbind, lapply(seq_len(nrow(pub)), function(i) {
  d <- dist_km(pub$lon[i], pub$lat[i])
  data.frame(nearest_station = d$nearest, station_km = d$station_km, line_km = d$line_km)
}))
pub <- cbind(pub, res)
pub$check_vs_layer_km <- pub$station_km - pub$layer_hubdist_km
pub$check_ratio <- pub$check_vs_layer_km / pub$layer_hubdist_km
# HubDist matches the nearest hub; the small positive residual grows with
# distance (about 0.06 percent), the UTM 17S scale factor at Quito, which
# lies about 2.5 degrees east of the zone's central meridian.
stopifnot(all(pub$nearest_station == pub$layer_hub), all(abs(pub$check_vs_layer_km) < 0.02))
cat("Published coordinates (layer):\n"); print(pub, digits = 4)
write.csv(pub, file.path(out_dir, "monitor_distances_published.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")

# Documented sites (public sources, see the report). OSM objects looked up
# with Nominatim on 2026-10-01: centroid and bounding box.
#   Belisario: the monitor is on the terrace of the Colegio San Gabriel
#     administration building (CORPAIRE, "Caracteristicas de la REMMAQ");
#     the campus is OSM way 282603573.
#   Centro: Radio Municipal terrace, Garcia Moreno 751 y Sucre; proxied by
#     the Iglesia de la Compania (OSM way 673869411), which stands on that
#     corner. This is the church's centroid, not the street corner.
alt <- data.frame(
  station = c("Belisario", "Centro"),
  site    = c("Colegio San Gabriel campus, OSM way 282603573",
              "Iglesia de la Compania, OSM way 673869411 (proxy for Garcia Moreno y Sucre)"),
  lon = c(-78.4971865, -78.5138343),
  lat = c(-0.1834573, -0.2207891),
  bb_lat_min = c(-0.1850312, -0.2210810), bb_lat_max = c(-0.1825270, -0.2204368),
  bb_lon_min = c(-78.4985793, -78.5140981), bb_lon_max = c(-78.4953236, -78.5135235)
)
alt <- cbind(alt, do.call(rbind, lapply(seq_len(nrow(alt)), function(i) {
  d <- dist_km(alt$lon[i], alt$lat[i])
  p0 <- pub[pub$station == alt$station[i], ]
  stopifnot(nrow(p0) == 1)
  # range over the OSM bounding box (grid approximation, 41 x 41 points)
  grid <- expand.grid(lon = seq(alt$bb_lon_min[i], alt$bb_lon_max[i], length.out = 41),
                      lat = seq(alt$bb_lat_min[i], alt$bb_lat_max[i], length.out = 41))
  gp <- st_transform(st_as_sf(grid, coords = c("lon", "lat"), crs = 4326), UTM)
  gs <- apply(st_distance(gp, sta), 1, min) / 1000
  gl <- as.numeric(st_distance(gp, line)) / 1000
  off <- as.numeric(st_distance(
    st_transform(st_sfc(st_point(c(alt$lon[i], alt$lat[i])), crs = 4326), UTM),
    st_transform(st_sfc(st_point(c(p0$lon, p0$lat)), crs = 4326), UTM))) / 1000
  data.frame(offset_from_published_km = off, nearest_station = d$nearest,
             station_km = d$station_km, line_km = d$line_km,
             bbox_station_km_min = min(gs), bbox_station_km_max = max(gs),
             bbox_line_km_min = min(gl), bbox_line_km_max = max(gl),
             bbox_all_truncate_to_published = all(trunc(round(grid$lon * 100, 6)) / 100 == p0$lon &
                                                  trunc(round(grid$lat * 100, 6)) / 100 == p0$lat),
             bbox_share_rounding_to_published = mean(round(grid$lon, 2) == p0$lon & round(grid$lat, 2) == p0$lat),
             truncated_lon = trunc(round(alt$lon[i] * 100, 6)) / 100,
             truncated_lat = trunc(round(alt$lat[i] * 100, 6)) / 100,
             rounded_lon = round(alt$lon[i], 2), rounded_lat = round(alt$lat[i], 2))
})))
cat("\nDocumented sites:\n"); print(alt, digits = 5)
write.csv(alt, file.path(out_dir, "monitor_distances_documented_sites.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")

# Range of distances inside the cell a two-decimal coordinate allows.
# Truncated toward zero: true value lies 0 to 0.01 degrees further from zero
# (west in longitude, south in latitude here). Rounded: within +-0.005.
# All coordinates here are negative, so truncation toward zero puts the true
# value further from zero; sign() keeps that right in general.
cells <- do.call(rbind, lapply(which(pub$decimals <= 2), function(i) {
  g <- seq(0, 1, length.out = 101)
  do.call(rbind, lapply(c("truncated", "rounded"), function(rule) {
    if (rule == "truncated") { lons <- pub$lon[i] + sign(pub$lon[i]) * 0.01 * g
                               lats <- pub$lat[i] + sign(pub$lat[i]) * 0.01 * g }
    else { lons <- pub$lon[i] + 0.01 * (g - 0.5); lats <- pub$lat[i] + 0.01 * (g - 0.5) }
    grid <- expand.grid(lon = lons, lat = lats)
    pts <- st_transform(st_as_sf(grid, coords = c("lon", "lat"), crs = 4326), UTM)
    ds <- apply(st_distance(pts, sta), 1, min) / 1000
    dl <- as.numeric(st_distance(pts, line)) / 1000
    data.frame(station = pub$station[i], rule = rule,
               station_km_min = min(ds), station_km_max = max(ds),
               line_km_min = min(dl), line_km_max = max(dl),
               share_of_cell_station_km_below_1 = mean(ds < 1))
  }))
}))
cat("\nDistance ranges within the coordinate cell:\n"); print(cells, digits = 3)
write.csv(cells, file.path(out_dir, "monitor_distances_cell_ranges.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")
