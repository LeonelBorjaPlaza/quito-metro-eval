# Item 4: spatial frame. Run from road_safety/ after 01_build.R: Rscript code/02_spatial.R
# Assigns every crash to (a) its H3 resolution-8 cell, with the same DuckDB h3 function as
# congestion (h3_latlng_to_cell_string(lat, lng, 8)), and its resolution-7 parent; (b) the nearest
# Line 1 station, its distance and a distance band; (c) corridor flags at 500 m (primary) and
# 1 km (sensitivity) of the line; (d) its parish from the GeoQuito polygons, with the outside-district
# and parish-mismatch flags, and parish geometry facts (distance to the line, BRT trunk corridors).
# Distances in UTM 17S (EPSG:32717).
# Assignment only: summaries by area below use pre-period rows only (load_pre()).
source("code/helpers.R")

crashes <- read_parquet(CRASHES_BUILD)  # all dates: assignment only, nothing summarised by area here

stations <- st_transform(st_zm(st_read(STATIONS_GPKG, quiet = TRUE)), CRS_UTM)
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG, quiet = TRUE)), CRS_UTM))
stopifnot(nrow(stations) == 15L, !anyNA(stations$Name), !anyDuplicated(stations$Name))
stations$station_id <- seq_len(nrow(stations))  # south-north order of the layer is not assumed

pts <- st_transform(st_as_sf(crashes[, .(crash_id, lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
nearest <- st_nearest_feature(pts, stations)
crashes[, `:=`(
  nearest_station = stations$Name[nearest],
  dist_station_m = as.numeric(st_distance(pts, stations[nearest, ], by_element = TRUE)),
  dist_line_m = as.numeric(st_distance(pts, line))
)]
crashes[, band := cut(dist_station_m, c(0, 500, 1000, 2000, Inf), right = FALSE,
                      labels = c("0-500m", "500-1000m", "1-2km", "over2km"))]
crashes[, `:=`(
  catchment_500 = dist_station_m < 500,
  catchment_1km = dist_station_m < 1000,
  corridor_500 = dist_line_m < 500,
  corridor_1km = dist_line_m < 1000,
  beyond_2km_line = dist_line_m > 2000
)]

# H3 cells, as in congestion (inventory_helpers.R: h3_latlng_to_cell_string(lat, lng, 8)).
con <- connect_duckdb()
duckdb::duckdb_register(con, "p", as.data.frame(crashes[, .(crash_id, lat, lon)]))
h3 <- as.data.table(DBI::dbGetQuery(con, paste(
  "SELECT crash_id, h3_latlng_to_cell_string(lat, lon, 8) AS h3_r8,",
  "h3_cell_to_parent(h3_latlng_to_cell_string(lat, lon, 8), 7) AS h3_r7 FROM p")))
DBI::dbDisconnect(con, shutdown = TRUE)
crashes <- merge(crashes, h3, by = "crash_id", sort = TRUE)
stopifnot(nrow(crashes) == nrow(h3), !anyNA(crashes$h3_r8))

# Parish from the GeoQuito polygons (65 parishes; urban = INEC DPA codes 170101 to 170132).
stopifnot(substr(system2("sha256sum", shQuote(PARISH_ZIP), stdout = TRUE), 1, 64) == PARISH_SHA256,
          substr(system2("sha256sum", shQuote(BRT_OSM), stdout = TRUE), 1, 64) == BRT_SHA256,
          isTRUE(l10n_info()$`UTF-8`))  # the name normalisation below needs a UTF-8 locale
parishes <- st_transform(st_read(paste0("/vsizip/", normalizePath(PARISH_ZIP)), quiet = TRUE), CRS_UTM)
stopifnot(nrow(parishes) == 65L, all(st_is_valid(parishes)), !anyDuplicated(parishes$dpa_parroq),
          !anyDuplicated(parishes$dpa_despar))
parishes$parish_code <- as.integer(parishes$dpa_parroq)
parishes$parish_urban <- parishes$parish_code >= 170101L & parishes$parish_code <= 170132L
stopifnot(sum(parishes$parish_urban) == 32L)
# Points rebuilt from the table in its current order (it was re-sorted by the H3 merge above).
pts_now <- st_transform(st_as_sf(crashes[, .(crash_id, lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
stopifnot(identical(pts_now$crash_id, crashes$crash_id))
hit <- st_intersects(pts_now, parishes)
# A point on a shared edge matches two parishes; it goes to the first in file order (counted below).
first_hit <- vapply(hit, function(i) if (length(i)) i[1] else NA_integer_, 0L)
norm_name <- function(x) gsub("\\s+", " ", trimws(gsub("\\s*\\(.*\\)", "", toupper(chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", x)))))
polygon_names <- norm_name(parishes$dpa_despar)
crashes[, `:=`(
  parish_code = parishes$parish_code[first_hit],
  parroquia_polygon = parishes$dpa_despar[first_hit],
  parish_urban = parishes$parish_urban[first_hit],
  flag_outside_district = is.na(first_hit),
  flag_parish_mismatch = fifelse(is.na(first_hit) | is.na(parroquia), NA,
                                 norm_name(parroquia) != norm_name(parishes$dpa_despar[first_hit])),
  parroquia_name_unknown = !is.na(parroquia) & !norm_name(parroquia) %in% polygon_names
)]

# BRT trunk corridors from the OSM relations (network Metrobus-Q): Trolebus (refs C1, C4, C6) and
# Ecovia (E1, E1R, E3, E4, E6), as Leonel asked, and the Central Norte MetroBus (relations 2021069 and
# 85969) as an addition. The operator-tagged TROLEBUS, ECOVIA, CENTRAL NORTE and SUR ORIENTAL
# relations and the other Metrobus-Q refs are feeder or integration routes; every relation and the
# reason for its selection is listed in output/spatial/brt_relations.csv (public OSM data).
osm <- st_read(BRT_OSM, layer = "multilinestrings", quiet = TRUE)
osm_tag <- function(k) { v <- rep(NA_character_, nrow(osm)); i <- grepl(paste0("\"", k, "\"=>"), osm$other_tags)
  v[i] <- sub(paste0(".*\"", k, "\"=>\"([^\"]*)\".*"), "\\1", osm$other_tags[i]); v }
rel <- data.table(osm_id = osm$osm_id, name = osm$name, route = osm_tag("route"), ref = osm_tag("ref"),
                  network = osm_tag("network"), operator = osm_tag("operator"), from = osm_tag("from"),
                  to = osm_tag("to"))
core <- rel$network %in% "Metrobus-Q" & rel$ref %in% c("C1", "C4", "C6", "E1", "E1R", "E3", "E4", "E6")
cn <- rel$osm_id %in% c("2021069", "85969")
so <- rel$operator %in% "SUR ORIENTAL"
stopifnot(sum(core) == 16L, sum(cn) == 2L, !any(core & cn))
osm_utm <- st_transform(osm, CRS_UTM)
rel[, `:=`(length_km = round(as.numeric(st_length(osm_utm)) / 1000, 2),
           selected = fcase(core, "trunk: Trolebus or Ecovia", cn, "trunk: Central Norte (addition)", default = "not selected"),
           reason = fcase(core, "Metrobus-Q trunk ref (C1, C4, C6, E1, E1R, E3, E4, E6)",
                          cn, "MetroBus Ofelia-Marin corridor relations",
                          so, "SUR ORIENTAL feeder routes (refs A01, A112, A77) to Quitumbe station",
                          rel$operator %in% c("TROLEBUS", "ECOVIA", "CENTRAL NORTE"), "operator-tagged feeder route (ref prefixed by the operator)",
                          rel$network %in% "Metrobus-Q", "Metrobus-Q feeder, integration or local route (not a trunk ref)",
                          default = "no network, feeder route"))]
save_csv(rel[order(selected, operator, ref)], "output/spatial/brt_relations.csv")
brt_core <- st_union(osm_utm[core, ])
brt_cn <- st_union(osm_utm[cn, ])
brt_so <- st_union(osm_utm[so, ])

# Parish geometry facts (no crash data): distance of the polygon to the line, and BRT trunk length
# (route km, both directions where they use different streets) inside the whole parish and inside
# its part beyond 2 km of the line. A donor counts as "crossed" when a trunk corridor runs more
# than 100 m inside it; flags use unrounded lengths. The length within 50 m of the part (a corridor
# running along a parish edge) and the Sur Oriental feeder length are reported, not used.
BRT_CROSS_MIN_M <- 100
# Parish by parish: st_difference on the whole set drops empty results and would misalign rows.
buf2 <- st_buffer(line, 2000)
beyond <- do.call(c, lapply(seq_len(nrow(parishes)), function(i) {
  d <- st_difference(st_geometry(parishes)[i], buf2)
  if (length(d) == 0L) st_sfc(st_polygon(), crs = CRS_UTM) else st_union(d)
}))
stopifnot(length(beyond) == nrow(parishes),
          all(as.numeric(st_area(beyond)) <= as.numeric(st_area(parishes)) + 1))
len_in <- function(g, lines) vapply(seq_along(g), function(i) {
  if (st_is_empty(g[i])) return(0)
  x <- suppressWarnings(st_intersection(g[i], lines)); if (length(x)) sum(as.numeric(st_length(x))) else 0 }, 0)
dist_m <- as.numeric(st_distance(parishes, line))
core_m <- len_in(beyond, brt_core)
cn_m <- len_in(beyond, brt_cn)
core50_m <- len_in(st_buffer(beyond, 50), brt_core)
cn50_m <- len_in(st_buffer(beyond, 50), brt_cn)
ptab <- data.table(
  parish_code = parishes$parish_code, parish = parishes$dpa_despar, urban = parishes$parish_urban,
  area_km2 = round(as.numeric(st_area(parishes)) / 1e6, 2),
  area_beyond_2km_km2 = round(as.numeric(st_area(beyond)) / 1e6, 2),
  polygon_dist_line_km = round(dist_m / 1000, 3),
  brt_core_km_in_parish = round(len_in(st_geometry(parishes), brt_core) / 1000, 3),
  brt_core_m_beyond_2km = round(core_m, 1),
  brt_central_norte_m_beyond_2km = round(cn_m, 1),
  brt_core_m_within_50m_of_part = round(core50_m, 1),
  brt_central_norte_m_within_50m_of_part = round(cn50_m, 1),
  sur_oriental_feeders_m_beyond_2km = round(len_in(beyond, brt_so), 1),
  wholly_beyond_2km = dist_m > 2000,
  brt_core_crosses_part_beyond_2km = core_m > BRT_CROSS_MIN_M,
  brt_any_crosses_part_beyond_2km = core_m + cn_m > BRT_CROSS_MIN_M)
save_csv(ptab[order(-urban, parish_code)], PARISHES_TABLE)

# Fast-road flags confirmed against road geometry (fix approved by Leonel, 2026-10-01; plan amendment
# of 2026-10-01). The name flags of 01_build.R are kept as they are; the confirmed flags keep a name match
# only when the crash lies within 1 km of an OSM way (2022-01-01 layer, ROADS_OSM) carrying a fast-road
# name, the E35 ref or the name Av. Oswaldo Guayasamin (OSM's name for part of the Interoceanica), and a
# Mariscal Sucre match only within 1 km of a way named (Avenida) Mariscal Sucre. Assignment only, every
# date; nothing is summarised here. road_type: "fast" for a confirmed fast-road or Mariscal Sucre crash,
# "city" otherwise (used for the split between city streets and fast roads).
stopifnot(file.exists(ROADS_OSM), substr(system2("sha256sum", shQuote(ROADS_OSM), stdout = TRUE), 1, 64) == ROADS_SHA256)
FAST_ROAD_PATTERN <- paste0("SIMON BOLIVAR|INTEROCEANICA|RUTA VIVA|PANAMERICANA|AUTOPISTA GENERAL RUMINAHUI|",
                            "CORDOVA GALARZA|^E ?-?35$|INTERVALLES")  # as in 01_build.R
roads <- st_transform(st_read(ROADS_OSM, layer = "lines", quiet = TRUE), CRS_UTM)
road_nm <- gsub("\\s+", " ", trimws(toupper(chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", roads$name))))
road_ref <- ifelse(grepl('"ref"=>"', roads$other_tags), sub('.*"ref"=>"([^"]*)".*', "\\1", roads$other_tags), NA_character_)
fast_ways <- (!is.na(road_nm) & !grepl("^PASAJE", road_nm) & (grepl(FAST_ROAD_PATTERN, road_nm) | grepl("^(AV\\.|AVENIDA) OSWALDO GUAYASAMIN", road_nm))) |
  (!is.na(road_ref) & grepl("(^|;)\\s*E ?-?35\\s*($|;)", road_ref))
ms_ways <- !is.na(road_nm) & road_nm %in% c("MARISCAL SUCRE", "AVENIDA MARISCAL SUCRE")
pts_now <- st_transform(st_as_sf(crashes[, .(crash_id, lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
stopifnot(identical(pts_now$crash_id, crashes$crash_id))
crashes[, `:=`(dist_fast_way_m = as.numeric(st_distance(pts_now, st_union(roads[fast_ways, ]))),
               dist_ms_way_m = as.numeric(st_distance(pts_now, st_union(roads[ms_ways, ]))))]
crashes[, `:=`(fast_road_confirmed = fast_road & dist_fast_way_m <= 1000,
               ms_confirmed = av_mariscal_sucre & dist_ms_way_m <= 1000)]
crashes[, road_type := fifelse(fast_road_confirmed | ms_confirmed, "fast", "city")]

write_parquet(crashes, CRASHES_SPATIAL)

# District-wide assignment rates, all dates (completeness, not outcomes by area). Per-year counts of
# the parish flags are in 05_completeness.R.
rates <- data.table(
  item = c("crashes", "with H3 r8 cell", "with nearest station", "with distance to line",
           "inside a parish polygon", "outside every parish polygon (flag_outside_district)",
           "on a shared parish edge (matched two parishes; first in file order kept)",
           "recorded PARROQUIA differs from the polygon (flag_parish_mismatch)",
           "flag_parish_mismatch not assessable (outside, or PARROQUIA missing)",
           "recorded PARROQUIA not among the 65 polygon names after normalisation"),
  n = c(nrow(crashes), sum(!is.na(crashes$h3_r8)), sum(!is.na(crashes$nearest_station)),
        sum(!is.na(crashes$dist_line_m)), sum(!crashes$flag_outside_district),
        sum(crashes$flag_outside_district), sum(lengths(hit) > 1L),
        sum(crashes$flag_parish_mismatch, na.rm = TRUE), sum(is.na(crashes$flag_parish_mismatch)),
        sum(crashes$parroquia_name_unknown)))
save_csv(rates, "output/spatial/assignment_rates.csv")

# Geometry of the treated areas (no crash data).
st_xy <- st_coordinates(stations)
circle <- function(r) st_union(st_buffer(stations, r))
geom <- data.table(
  area = c("station circles 500 m (union)", "station circles 1 km (union)",
           "station circles 500 m (sum, with overlap)", "station circles 1 km (sum, with overlap)",
           "corridor 500 m of line", "corridor 1 km of line", "within 2 km of line"),
  km2 = c(as.numeric(st_area(circle(500))), as.numeric(st_area(circle(1000))),
          15 * pi * 0.5^2 * 1e6, 15 * pi * 1^2 * 1e6,
          as.numeric(st_area(st_buffer(line, 500))), as.numeric(st_area(st_buffer(line, 1000))),
          as.numeric(st_area(st_buffer(line, 2000)))) / 1e6)
geom <- rbind(geom, data.table(area = "line length (km)", km2 = as.numeric(st_length(line)) / 1000))
save_csv(geom, "output/spatial/treated_area_geometry.csv")
d <- as.matrix(dist(st_xy[, 1:2]))
diag(d) <- Inf
save_csv(data.table(station_id = stations$station_id, station = stations$Name,
                    x_utm17s = round(st_xy[, 1]), y_utm17s = round(st_xy[, 2]),
                    nearest_other_station_m = round(apply(d, 1, min))),
         "output/spatial/stations.csv")

# Pre-period counts (January 2021 to November 2023) by band, corridor, station and parish.
pre <- load_pre(CRASHES_SPATIAL)
save_csv(pre[, .(crashes = .N, injury_or_fatal = sum(injury_or_fatal), pedestrian = sum(pedestrian)),
             by = band][order(band)], "output/spatial/pre_counts_by_band.csv")
# Treated areas, with and without crashes at repeated exact points (possible default locations).
area_counts <- function(label, sel) pre[, .(unit = label, crashes = sum(sel), injury_or_fatal = sum(sel & injury_or_fatal),
                                            pedestrian = sum(sel & pedestrian),
                                            crashes_at_repeated_points = sum(sel & flag_repeated_point),
                                            crashes_excluding_repeated_points = sum(sel & !flag_repeated_point))]
save_csv(rbind(
  area_counts("corridor 500 m", pre$corridor_500), area_counts("corridor 1 km", pre$corridor_1km),
  area_counts("station catchments 500 m (pooled)", pre$catchment_500),
  area_counts("station catchments 1 km (pooled)", pre$catchment_1km),
  area_counts("beyond 2 km of line", pre$beyond_2km_line),
  area_counts("whole district", rep(TRUE, nrow(pre)))),
  "output/spatial/pre_counts_by_treated_area.csv")
save_csv(merge(data.table(station = stations$Name, station_id = stations$station_id),
               pre[catchment_1km == TRUE, .(crashes_1km = .N, crashes_500m = sum(catchment_500),
                                            injury_or_fatal_1km = sum(injury_or_fatal), pedestrian_1km = sum(pedestrian)),
                   by = .(station = nearest_station)], by = "station", all.x = TRUE)[order(station_id)],
         "output/spatial/pre_counts_by_station.csv")
# Recorded parish (PARROQUIA, unreliable before mid-2022 per the audit). Counts per distance class
# only; shares are withheld for parishes with fewer than 5 crashes (single-record attributes).
by_parish <- pre[, .(crashes = .N, within_500m_line = sum(dist_line_m < 500),
                     within_2km_line = sum(!beyond_2km_line), beyond_2km_line = sum(beyond_2km_line),
                     at_repeated_points = sum(flag_repeated_point),
                     share_zona_urbana = round(mean(zona %in% "URBANA"), 3),
                     share_zona_missing = round(mean(is.na(zona)), 3)), by = parroquia][order(-crashes)]
by_parish[crashes < 5L, `:=`(share_zona_urbana = NA_real_, share_zona_missing = NA_real_)]
# Labels with fewer than 5 crashes are grouped, so this table cannot be differenced against the
# polygon table to locate single records (code review pass 3).
by_parish <- rbind(by_parish[crashes >= 5L],
                   by_parish[crashes < 5L, .(parroquia = "other labels (fewer than 5 crashes each)", crashes = sum(crashes),
                                             within_500m_line = sum(within_500m_line), within_2km_line = sum(within_2km_line),
                                             beyond_2km_line = sum(beyond_2km_line), at_repeated_points = sum(at_repeated_points),
                                             share_zona_urbana = NA_real_, share_zona_missing = NA_real_)])
save_csv(by_parish, "output/spatial/pre_counts_by_parish.csv")
# Parish from the polygon (the basis of the donor pools from 2026-09-25 on). Counts only; rural
# parishes with fewer than 5 pre-period crashes are grouped (single-record detail).
pp <- merge(ptab[, .(parish_code, parish, urban, wholly_beyond_2km)],
            pre[!is.na(parish_code), .(crashes = .N, within_2km_line = sum(!beyond_2km_line),
                                       beyond_2km_line = sum(beyond_2km_line)), by = parish_code],
            by = "parish_code", all.x = TRUE)
setnafill(pp, fill = 0L, cols = c("crashes", "within_2km_line", "beyond_2km_line"))
small <- pp[urban == FALSE & crashes < 5L]
# The pre-period crashes outside every parish polygon (1 to 4) are merged into the grouped row, so the
# table sums to the district total and they cannot be derived by subtraction (Leonel, 2026-10-01).
outside <- pre[is.na(parish_code), .(crashes = .N, within_2km_line = sum(!beyond_2km_line), beyond_2km_line = sum(beyond_2km_line))]
pp <- rbind(pp[!(urban == FALSE & crashes < 5L)],
            small[, .(parish_code = NA_integer_,
                      parish = "other rural parishes (fewer than 5 crashes each) and crashes outside every parish polygon",
                      urban = FALSE, wholly_beyond_2km = NA, crashes = sum(crashes) + outside$crashes,
                      within_2km_line = sum(within_2km_line) + outside$within_2km_line,
                      beyond_2km_line = sum(beyond_2km_line) + outside$beyond_2km_line)])
stopifnot(sum(pp$crashes) == nrow(pre))
save_csv(pp[order(-urban, -crashes)], "output/spatial/pre_counts_by_parish_polygon.csv")
cat("Wrote", CRASHES_SPATIAL, "with", nrow(crashes), "crashes. Pre-period rows summarised:", nrow(pre), "\n")
print(geom)
