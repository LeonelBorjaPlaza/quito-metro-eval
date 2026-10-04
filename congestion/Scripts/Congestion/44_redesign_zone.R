# Amendment 5, item 4: the pico y placa zone, traced by code from its official boundary streets (Quito
# Informa, 2023-04-10): Av. Morán Valverde to the south; Calle de los Narcisos, Av. Córdova Galarza and
# Av. Simón Bolívar to the north; Av. Simón Bolívar to the east; Av. Mariscal Sucre to the west.
# Streets come from the stored OSM major roads as of 2022-01-01 (road_safety delivery, through
# Data/geo/). In OSM each street breaks into pieces at junctions (name changes, unnamed links, dual
# carriageways), so the streets are buffered by d metres, the enclosed hole that contains reference points
# in the city (La Carolina park and Plaza de la Independencia) is taken, and it is grown back by d. d is the
# smallest of 25, 50, 100, 150 and 250 m that closes the ring; if none does, the script stops (the plan's
# fallback is the parish approximation, labeled as such).
# Output: the polygon (ignored derived data) and a map. Leonel approved the zone on 2026-10-01 as a record for a
# restart, with the straight-segment closure; the only zone-based use is restart diagnostic 3 (45).
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
check_delivery("Data/geo/osm_major_roads_20220101_dmq")
SIRES <- sires_crs()
L <- st_transform(st_read("Data/geo/osm_major_roads_20220101_dmq/osm_major_roads_20220101_dmq.osm", layer = "lines", quiet = TRUE), SIRES)
BOUNDARY <- c("Mor[aá]n Valverde", "Narcisos", "C[oó]rdova Galarza", "Sim[oó]n Bol[ií]var", "Mariscal Sucre")
B <- L[Reduce(`|`, lapply(BOUNDARY, function(rx) grepl(rx, L$name))), ]
stopifnot(all(sapply(BOUNDARY, function(rx) any(grepl(rx, B$name)))))
# The named streets leave one gap in the south-east: Av. Morán Valverde ends short of Av. Simón Bolívar
# (2022 OSM; the street itself is complete). Leonel's decision of 2026-10-01: close it with a straight
# segment from the eastern end of Av. Morán Valverde (its vertex with the largest easting) to the nearest
# point of Av. Simón Bolívar. The segment is our assumption, not part of the official text; it is labeled
# on the map and in the plan (Amendment 6).
mv <- st_union(st_geometry(B[grepl("Mor[aá]n Valverde", B$name), ]))
sb <- st_union(st_geometry(B[grepl("Sim[oó]n Bol[ií]var", B$name), ]))
mv_xy <- st_coordinates(mv)
mv_east <- st_sfc(st_point(mv_xy[which.max(mv_xy[, "X"]), c("X", "Y")]), crs = SIRES)
C <- st_sfc(st_nearest_points(mv_east, sb)[1], crs = SIRES)
gap_m <- as.numeric(st_length(C))
connector_names <- sprintf("assumed straight segment, %.0f m, from the eastern end of Av. Morán Valverde to the nearest point of Av. Simón Bolívar", gap_m)
lines_all <- st_union(c(st_geometry(B), C))
ref <- st_transform(st_sfc(st_point(c(-78.4855, -0.1810)), st_point(c(-78.51209, -0.22012)), crs = 4326), SIRES)  # La Carolina; Plaza de la Independencia (OSM way 24734054)
trace_log <- list()
trace_with <- function(d) {
  holes <- lapply(st_cast(st_union(st_buffer(lines_all, d)), "POLYGON"), function(p) if (length(p) > 1) lapply(p[-1], function(r) st_polygon(list(r))) else list())
  holes <- st_sfc(unlist(holes, recursive = FALSE), crs = SIRES)
  in1 <- if (length(holes)) which(st_contains(holes, ref[1], sparse = FALSE)[, 1]) else integer()
  in2 <- if (length(holes)) which(st_contains(holes, ref[2], sparse = FALSE)[, 1]) else integer()
  hit <- intersect(in1, in2)
  reason <- if (!length(holes)) "no enclosed hole" else if (!length(in1) && !length(in2)) "neither reference point in an enclosed hole (ring open)" else
    if (!length(hit)) "the reference points fall in different holes" else if (length(hit) == 1L) "closed" else "more than one hole holds both points"
  trace_log[[length(trace_log) + 1]] <<- data.table(buffer_m = d, holes = length(holes), result = reason)
  if (length(hit) != 1L) return(NULL)
  st_buffer(holes[hit], d)
}
BUFFERS_M <- c(25, 50, 100, 150, 250)
zone_geom <- NULL
for (d in BUFFERS_M) { zone_geom <- trace_with(d); if (!is.null(zone_geom)) { buffer_m <- d; break } }
fwrite(rbindlist(trace_log), file.path(REDESIGN_OUT, "zone_buffer_trace.csv"))
if (is.null(zone_geom)) stop("The boundary streets do not close a ring around the reference points with any buffer up to 250 m; use the parish fallback")
zone <- st_sf(name = "pico y placa zone (traced from the official boundary streets, OSM 2022)", geometry = zone_geom)
zone_area_ha <- as.numeric(st_area(zone)) / 1e4

geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
stations <- st_transform(st_zm(st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)), SIRES)
st_in <- st_within(stations, zone, sparse = FALSE)[, 1]
ctr <- st_transform(st_sfc(geog$polygons$CENTER, crs = 4326), SIRES)
mon <- st_transform(st_zm(st_read("Data/spatial/Distancia_REMMAQ_Metro.gpkg", quiet = TRUE)), SIRES)
bel <- mon[mon$Station == "Belisario", ]
summary_tab <- data.table(zone_area_ha = zone_area_ha, buffer_m = buffer_m, gap_closure = connector_names, gap_m = gap_m, stations_inside = sum(st_in), stations_total = length(st_in),
  stations_outside = paste(stations$Name[!st_in], collapse = "; "),
  center_polygon_inside = st_within(ctr, zone, sparse = FALSE)[1, 1],
  center_area_share_inside = as.numeric(st_area(st_intersection(ctr, st_geometry(zone)))) / as.numeric(st_area(ctr)),
  belisario_point_inside = st_within(bel, zone, sparse = FALSE)[1, 1],
  status = "approved by Leonel on 2026-10-01 as a record for a restart, with the straight-segment closure; used only by restart diagnostic 3 (45)")
saveRDS(list(zone = zone, summary = summary_tab), file.path(REDESIGN_DATA, "zone.rds"))
fwrite(summary_tab, file.path(REDESIGN_OUT, "zone_summary.csv"))

line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
bb <- st_bbox(st_buffer(zone, 2500))
others <- L[st_intersects(L, st_as_sfc(bb), sparse = FALSE)[, 1], ]
p <- ggplot() +
  geom_sf(data = others, colour = "grey80", linewidth = 0.2) +
  geom_sf(data = zone, fill = "#fdae61", alpha = 0.35, colour = "#d7191c", linewidth = 0.8) +
  geom_sf(data = B, aes(colour = sub(".*(Mor[aá]n Valverde|Narcisos|C[oó]rdova Galarza|Sim[oó]n Bol[ií]var|Mariscal Sucre).*", "\\1", name)), linewidth = 0.5) +
  geom_sf(data = C, colour = "magenta", linewidth = 1.3) +
  geom_sf(data = line, colour = "black", linewidth = 0.6) +
  geom_sf(data = stations, shape = 21, fill = "white", size = 1.6) +
  geom_sf(data = ctr, fill = NA, colour = "#2166ac", linewidth = 0.6) +
  coord_sf(crs = SIRES, datum = NA, xlim = bb[c(1, 3)], ylim = bb[c(2, 4)]) +
  labs(title = "Pico y placa zone traced from its official boundary streets (OSM, 2022-01-01)",
       subtitle = sprintf("Zone %.0f ha (closing buffer %d m). Stations inside: %d of %d (outside: %s). Blue: CENTER polygon. Black: Line 1.\nMagenta: our assumption, a straight segment of %.0f m closing the south-east gap (Morán Valverde to Simón Bolívar).",
                          zone_area_ha, buffer_m, sum(st_in), length(st_in), summary_tab$stations_outside, gap_m),
       colour = "Boundary street", caption = "Streets: © OpenStreetMap contributors (ODbL). Boundary definition: Quito Informa, 10 April 2023.",
       x = NULL, y = NULL) + theme_minimal(base_size = 9)
ggsave(file.path(REDESIGN_OUT, "map_pico_y_placa_zone.png"), p, width = 8, height = 11, dpi = 150, bg = "white")
print(summary_tab)
