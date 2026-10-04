# Compare candidate historic-center polygons (workstream B, amendment 2 preparation).
# Scratch only: reads candidate polygons fetched to the scratchpad, the Waze grid and the
# Step 1 geography. Reads no Waze outcome. Run from congestion/.
source("Scripts/Congestion/step1_helpers.R")
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
sf_use_s2(TRUE)
SIRES <- st_crs(st_read(file.path(S, "limite_plan_chq_a.geojson"), quiet = TRUE))  # placeholder, replaced below
prj <- paste(readLines(unz(file.path(S, "limite_plan_chq_a.zip"), "limite_plan_chq_a.prj"), warn = FALSE), collapse = "")
SIRES <- st_crs(prj)

one <- function(x, id, label, source) {
  g <- st_union(st_make_valid(st_geometry(st_transform(st_zm(x), 4326))))
  st_sf(id = id, label = label, source = source, geometry = g)
}
osm <- st_read(file.path(S, "osm_chq.osm"), layer = "multipolygons", quiet = TRUE)
osm_whc <- osm[!is.na(osm$osm_way_id) & osm$osm_way_id == "1077782502", ]
osm_par <- osm[!is.na(osm$osm_id) & osm$osm_id == "89703", ]
stopifnot(nrow(osm_whc) == 1, nrow(osm_par) == 1)
pu <- st_read(file.path(S, "parr/parr_urbana_ord002/parr_urbana_ord002_a.shp"), quiet = TRUE)
pr <- st_read(file.path(S, "parr/PARROQUIAS_REF.shp"), quiet = TRUE)
name_col <- function(d) names(d)[sapply(d, function(v) is.character(v) && any(grepl("CENTRO HIST", toupper(v))))][1]
pu_col <- name_col(pu); pr_col <- name_col(pr)
cat("parish name columns:", pu_col, pr_col, "\n")
pu_c <- pu[grepl("CENTRO HIST", toupper(pu[[pu_col]])), ]
pr_c <- pr[grepl("CENTRO HIST", toupper(pr[[pr_col]])), ]
cat("parish rows:", nrow(pu_c), nrow(pr_c), "\n")
print(st_drop_geometry(pu_c)); print(st_drop_geometry(pr_c))

shp_dir <- file.path(tempdir(), "chq"); unzip(file.path(S, "limite_plan_chq_a.zip"), exdir = shp_dir)
plan_shp <- st_read(file.path(shp_dir, "limite_plan_chq_a.shp"), quiet = TRUE)

cand <- rbind(
  one(st_read(file.path(S, "area_historica_chq.geojson"), quiet = TRUE), "G_AH",
      "GeoQuito: Area Historica Centro Historico de Quito (patrimonio layer 6)", "GeoQuito web_reference_dmot/patrimonio MapServer/6, OBJECTID 41"),
  one(plan_shp, "G_PLAN", "GeoQuito: limite_plan_chq_a (Plan de Accion boundary)", "GeoQuito item 979cde91eb6440d6bab77bd01a72ea1e"),
  one(pu_c, "G_PARR", "GeoQuito: parroquia urbana Centro Historico (ord. 002)", "store road_safety/raw/2026-09-25_geoquito_parroquias/parr_urbana_ord002.zip"),
  one(pr_c, "G_PARR_REF", "GeoQuito: Parroquias DMQ (PARROQUIAS_REF) Centro Historico", "store road_safety/raw/2026-09-25_geoquito_parroquias/PARROQUIAS_REF.zip"),
  one(osm_whc, "O_WHC", "OSM way 1077782502 'Ciudad de Quito' (WHC, traced from UNESCO 173425)", "OpenStreetMap, ODbL"),
  one(osm_par, "O_PARR", "OSM relation 89703 'Centro Historico' (admin_level 9)", "OpenStreetMap, ODbL"))
# Check the GeoJSON download of the plan boundary against the shapefile.
plan_gj <- one(st_read(file.path(S, "limite_plan_chq_a.geojson"), quiet = TRUE), "x", "x", "x")
cat("plan boundary: shapefile vs geojson symmetric difference (ha):",
    round(as.numeric(st_area(st_sym_difference(plan_gj, cand[cand$id == "G_PLAN", ]))) / 1e4, 3), "\n")

cand$area_ha_geodesic <- round(as.numeric(st_area(cand)) / 1e4, 2)
cand$area_ha_sires <- round(as.numeric(st_area(st_transform(cand, SIRES))) / 1e4, 2)
cand$n_parts <- sapply(st_geometry(cand), function(g) length(st_cast(st_sfc(g), "POLYGON")))
cat("\nAreas\n"); print(st_drop_geometry(cand)[, c("id", "area_ha_geodesic", "area_ha_sires", "n_parts")])

# Pairwise overlap: intersection area as a share of each row's area, and intersection over union.
ids <- cand$id; ov <- list()
for (i in seq_along(ids)) for (j in seq_along(ids)) if (i < j) {
  a <- cand[i, ]; b <- cand[j, ]
  inter <- suppressWarnings(st_intersection(st_geometry(a), st_geometry(b)))
  ia <- if (length(inter)) sum(as.numeric(st_area(inter))) / 1e4 else 0
  ua <- as.numeric(st_area(st_union(st_geometry(a), st_geometry(b)))) / 1e4
  ov[[length(ov) + 1]] <- data.table(a = ids[i], b = ids[j], inter_ha = round(ia, 2),
    share_of_a = round(ia / a$area_ha_geodesic, 3), share_of_b = round(ia / b$area_ha_geodesic, 3), iou = round(ia / ua, 3))
}
ov <- rbindlist(ov); cat("\nOverlaps\n"); print(ov)

# Landmarks (OSM ids from the Overpass queries saved in the scratchpad).
lm_json <- c(jsonlite::fromJSON(file.path(S, "osm_landmarks1.json"))$elements |> list(),
             jsonlite::fromJSON(file.path(S, "osm_landmarks2.json"))$elements |> list())
el <- rbindlist(lapply(lm_json, function(e) data.table(type = e$type, id = as.character(e$id),
  lat = ifelse(is.na(e$lat), e$center$lat, e$lat), lon = ifelse(is.na(e$lon), e$center$lon, e$lon))), fill = TRUE)
lm <- data.table(
  landmark = c("Plaza Grande", "San Francisco (plaza)", "Santo Domingo (church)", "La Compania (church)",
               "San Blas (church)", "San Juan (church)", "El Tejar (church)", "San Roque (neighbourhood)"),
  expected = c(rep("core", 4), rep("wider", 4)),
  type = c("way", "way", "way", "way", "way", "node", "way", "relation"),
  id = c("24734054", "376087703", "673325435", "673869411", "721293007", "346195755", "555827084", "14059444"))
lm <- merge(lm, unique(el), by = c("type", "id"), sort = FALSE)
stopifnot(nrow(lm) == 8)
lm_sf <- st_as_sf(lm, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
inside <- st_intersects(lm_sf, cand, sparse = FALSE); colnames(inside) <- cand$id
lm_tab <- cbind(lm[, .(landmark, expected, osm = paste(type, id))], as.data.table(ifelse(inside, "in", "-")))
cat("\nLandmarks\n"); print(lm_tab)

# Hexagon grid and Step 1 groups.
con <- duck(); G <- build_groups(con); DBI::dbDisconnect(con, shutdown = TRUE)
grid <- fread(grid_path, colClasses = "character")
hex <- st_as_sf(grid, wkt = "h3_geometry_r8", crs = 4326)
hex <- merge(hex, G$cells[, .(grid_id, group)], by = "grid_id")
hex_tab <- rbindlist(lapply(seq_len(nrow(cand)), function(i) {
  hit <- st_intersects(hex, cand[i, ], sparse = FALSE)[, 1]
  h <- hex[hit, ]
  ia <- as.numeric(st_area(st_intersection(st_geometry(h), st_geometry(cand[i, ])))) / 1e4
  data.table(id = cand$id[i], n_hex = nrow(h), n_hex_over_10pct = sum(ia / (as.numeric(st_area(h)) / 1e4) > 0.10),
             groups = paste(names(table(h$group)), table(h$group), sep = ":", collapse = " "),
             center_ring_cells_hit = sum(h$grid_id %in% G$rings$CENTER),
             center_seed_hit = SEEDS[["CENTER"]] %in% h$grid_id)
}))
cat("\nHexagons touched\n"); print(hex_tab)
cat("H3 r8 cell area (ha), median over grid:", round(median(as.numeric(st_area(hex))) / 1e4, 2), "\n")

saveRDS(list(cand = cand, ov = ov, lm = lm_tab, hex = hex_tab), file.path(S, "compare_candidates.rds"))
st_write(cand, file.path(S, "candidates.gpkg"), delete_dsn = TRUE, quiet = TRUE)

# Overlay map in SIRES-DMQ with the same 1 km grid as the UNESCO map (eastings 496705 + k*1000,
# northings 9974075 + k*1000), so the two can be compared by eye.
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
st_ <- st_transform(G$stations, SIRES); mon <- st_transform(G$monitors[G$monitors$Station %in% c("Centro", "Belisario"), ], SIRES)
ring <- st_transform(hex[hex$grid_id %in% G$rings$CENTER, ], SIRES)
xlim <- c(496705, 500705); ylim <- c(9973575, 9977775)
bb <- st_as_sfc(st_bbox(c(xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2]), crs = SIRES))
hexs <- st_transform(hex, SIRES); hexs <- hexs[st_intersects(hexs, bb, sparse = FALSE)[, 1], ]
cs <- st_transform(cand, SIRES)
cols <- c(G_AH = "#d7301f", G_PLAN = "#999999", G_PARR = "#1f78b4", G_PARR_REF = "#6a3d9a", O_WHC = "#ff7f00", O_PARR = "#33a02c")
ltys <- c(G_AH = "solid", G_PLAN = "dotted", G_PARR = "solid", G_PARR_REF = "dashed", O_WHC = "solid", O_PARR = "dotdash")
p <- ggplot() +
  geom_sf(data = hexs, fill = NA, colour = "grey80", linewidth = 0.2) +
  geom_sf(data = ring, fill = "khaki", alpha = 0.35, colour = "goldenrod", linewidth = 0.3) +
  geom_sf(data = cs, aes(colour = id, linetype = id), fill = NA, linewidth = 0.8) +
  geom_sf(data = line, colour = "black", linewidth = 0.6) +
  geom_sf(data = st_, shape = 21, fill = "white", colour = "black", size = 2) +
  geom_sf(data = mon, shape = 17, colour = "black", size = 2.5) +
  geom_sf(data = st_transform(lm_sf, SIRES), aes(shape = expected), colour = "black", size = 2) +
  scale_shape_manual(values = c(core = 8, wider = 4), name = "Landmark (expected area)") +
  scale_colour_manual(values = cols, name = "Candidate") + scale_linetype_manual(values = ltys, name = "Candidate") +
  coord_sf(crs = SIRES, datum = SIRES, xlim = xlim, ylim = ylim, expand = FALSE) +
  scale_x_continuous(breaks = seq(496705, 500705, 1000)) + scale_y_continuous(breaks = seq(9974075, 9977075, 1000)) +
  labs(title = "Candidate historic-center polygons, H3 r8 grid and the seven-cell CENTER ring (khaki)",
       subtitle = "SIRES-DMQ coordinates with the 1 km grid of the UNESCO 2019 map (document 173425). Line, stations (circles), monitors (triangles).",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 9) + theme(panel.grid.major = element_line(colour = "grey60", linewidth = 0.2), legend.position = "right")
ggsave(file.path(S, "candidates_overlay.png"), p, width = 11, height = 9, dpi = 150, bg = "white")
cat("map written\n")
