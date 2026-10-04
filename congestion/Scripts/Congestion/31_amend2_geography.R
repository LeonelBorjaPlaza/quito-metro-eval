# Amendments 2 and 4: units built from the historic-center polygons, road-length weights, group
# precedence, the buffer around the new CENTER, donor status changes, and where each new CENTER cell
# sits against the frozen coverage range (category only). Reads no Waze outcome: geography, OSM roads,
# the 2022 road-length file (through the Step 1 loader) and the Step 1 panel's cell table.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_loader.R")
source("Scripts/Congestion/amend2_helpers.R")
# Planar operations run in SIRES-DMQ; areas are computed in named projections (s2 stays on for build_groups).

# 1. Store deliveries: checksums, and the two downloads of GeoQuito feature 41 must be the same file.
for (d in unique(dirname(unlist(GEO)))) check_delivery(d)
stopifnot(identical(sha256(GEO$center), sha256(GEO$center_twin)))
SIRES <- sires_crs()

# 2. Polygons. CENTER: GeoQuito feature 41. CORE (descriptive): OSM way 1077782502, volunteer-traced.
center_poly <- st_read(GEO$center, quiet = TRUE)
stopifnot(nrow(center_poly) == 1, center_poly$OBJECTID == 41)
osm <- st_read(GEO$osm_chq, layer = "multipolygons", quiet = TRUE)
core_poly <- osm[!is.na(osm$osm_way_id) & osm$osm_way_id == OSM_WHC_WAY, ]
osm_parish <- osm[!is.na(osm$osm_id) & osm$osm_id == "89703", ]
stopifnot(nrow(core_poly) == 1, nrow(osm_parish) == 1)
td <- file.path(tempdir(), "parr"); unzip(GEO$parishes_urban, exdir = td); unzip(GEO$parishes_rural, exdir = td)
parr_u <- st_read(list.files(td, "parr_urbana.*\\.shp$", recursive = TRUE, full.names = TRUE), quiet = TRUE)
parr_r <- st_read(list.files(td, "parr_rural.*\\.shp$", recursive = TRUE, full.names = TRUE), quiet = TRUE)
plan_dir <- file.path(tempdir(), "plan_shp"); unzip(GEO$plan_shp, exdir = plan_dir)
plan_poly <- st_read(file.path(plan_dir, "limite_plan_chq_a.shp"), quiet = TRUE)
# Repaired only if invalid: st_make_valid on a valid polygon still moves vertices (about 1 m2 on feature 41).
geom1 <- function(x) { g <- st_geometry(st_zm(x)); if (!all(st_is_valid(g))) g <- st_make_valid(g); st_union(g) }
polys <- list(
  CENTER = list(g = geom1(center_poly), label = "GeoQuito Área Histórica Centro Histórico de Quito (feature 41)", role = "CENTER (primary)"),
  CORE = list(g = geom1(core_poly), label = "OSM way 1077782502, World Heritage property (volunteer-traced)", role = "secondary, descriptive"),
  parish = list(g = geom1(parr_u[parr_u$dpa_despar == "CENTRO HISTORICO", ]), label = "GeoQuito parish Centro Histórico (ordinance 002)", role = "not used"),
  osm_parish = list(g = geom1(osm_parish), label = "OSM relation 89703, Centro Histórico (admin_level 9)", role = "not used"),
  plan = list(g = geom1(plan_poly), label = "GeoQuito Plan de Acción boundary (limite_plan_chq_a)", role = "not used"))
polygon_areas <- rbindlist(lapply(names(polys), function(k) {
  g <- polys[[k]]$g
  data.table(polygon = k, label = polys[[k]]$label, role = polys[[k]]$role,
             area_ha_sires_dmq = as.numeric(st_area(st_transform(g, SIRES))) / 1e4,
             area_ha_wgs84_ellipsoid = as.numeric(st_area(st_transform(g, LAEA))) / 1e4,
             crs_note = "SIRES-DMQ: municipal transverse Mercator (planar). WGS 84 ellipsoid: Lambert azimuthal equal-area on WGS 84 centred on Quito")
}))
# The SIRES-DMQ area must reproduce GeoQuito's own STArea field for feature 41.
starea_ha <- center_poly[[grep("STArea", names(center_poly), value = TRUE)[1]]] / 1e4
stopifnot(length(starea_ha) == 1, abs(polygon_areas[polygon == "CENTER", area_ha_sires_dmq] - starea_ha) < 0.01)
polygon_areas[polygon == "CENTER", geoquito_starea_ha := starea_ha]

# 3. Grid, Step 1 groups and population (cells with a pre-period record).
con <- duck(); geo <- build_groups(con)
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
pop <- panel$rules$amended$cells[, .(grid_id, group, nearest_station_m)]
hex <- merge(st_as_sf(fread(grid_path, colClasses = "character"), wkt = "h3_geometry_r8", crs = 4326),
             geo$cells[, .(grid_id, group)], by = "grid_id")
roads <- read_roads()

# 4. Road-length weights inside each polygon, by cell, with the 1 m tolerance (Amendment 4).
unit_weights <- function(unit, poly) {
  r <- road_by_cell(st_sfc(poly, crs = 4326), roads, hex, SIRES)
  r <- merge(r, geo$cells[, .(grid_id, step1_group = group)], by = "grid_id")
  r[, `:=`(unit = unit, kept = road_m >= MIN_ROAD_M)]
  r[kept == TRUE, weight := road_m / sum(road_m)]
  r[order(-road_m)]
}
w_center <- unit_weights("CENTER", polys$CENTER$g)
w_core <- unit_weights("CORE", polys$CORE$g)
# Every OSM way the weights need must be in the snapshot: both polygons lie inside the Overpass box.
osm_box <- st_as_sfc(st_bbox(c(xmin = -78.540, xmax = -78.485, ymin = -0.250, ymax = -0.190), crs = 4326))
stopifnot(all(sapply(c("CENTER", "CORE"), function(k) st_within(st_sfc(polys[[k]]$g, crs = 4326), osm_box, sparse = FALSE)[1, 1])))
center_cells <- w_center[kept == TRUE, grid_id]
stopifnot(all(center_cells %in% pop$grid_id), all(w_core[kept == TRUE, grid_id] %in% pop$grid_id))
# BELISARIO, road-weighted (Amendment 4, item 5): the provider's 2022 all_roadtype OSM length per cell,
# the denominator of each cell's own tci_osm_ratio. The OSM snapshot does not reach BELISARIO.
cov <- load_coverage_2022(con)
w_bel <- cov[grid_id %in% geo$rings$BELISARIO, .(grid_id, road_m = osm_sum_length)]
stopifnot(nrow(w_bel) == 7L, all(w_bel$road_m > 0))
w_bel[, `:=`(unit = "BELISARIO_RW", step1_group = "BELISARIO", kept = TRUE, weight = road_m / sum(road_m))]
eq <- function(unit, cells, grp) data.table(grid_id = cells, road_m = NA_real_, step1_group = grp, unit = unit,
                                            kept = TRUE, weight = 1 / length(cells))
corridor_new <- setdiff(pop[group == "CORRIDOR", grid_id], center_cells)
unit_cells <- rbindlist(list(w_center, w_core, eq("RING7", geo$rings$CENTER, "CENTER"), w_bel,
                             eq("BELISARIO_EQ", geo$rings$BELISARIO, "BELISARIO"), eq("CORRIDOR", corridor_new, "CORRIDOR")),
                        use.names = TRUE, fill = TRUE)
unit_cells[, weight_source := fcase(unit %in% c("CENTER", "CORE"), "OSM 2022-01-01 drivable road length inside the polygon",
                                    unit == "BELISARIO_RW", "provider 2022 all_roadtype OSM length of the whole cell",
                                    default = "equal weights")]

# 5. Group precedence and the buffer (Amendment 4, item 2).
ring_in_center <- data.table(grid_id = geo$rings$CENTER, in_new_center = geo$rings$CENTER %in% center_cells)
stopifnot(all(ring_in_center$in_new_center))  # Amendment 4, item 2
neighbours <- unique(unlist(lapply(center_cells, function(s)
  DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) g", params = list(s))$g)))
buffer_cells <- setdiff(neighbours, center_cells)
DBI::dbDisconnect(con, shutdown = TRUE)
groups_new <- copy(geo$cells[, .(grid_id, step1_group = group)])
groups_new[, group := fifelse(grid_id %in% center_cells, "CENTER", fifelse(grid_id %in% buffer_cells & step1_group == "REST", "BUFFER", step1_group))]
group_changes <- groups_new[step1_group != group | grid_id %in% buffer_cells,
                            .(grid_id, step1_group, new_group = group, in_buffer = grid_id %in% buffer_cells)][order(new_group, grid_id)]
# Donor status changes: any REST cell in a frozen pool that now falls in the buffer.
pool_cols <- grep("^pool_", names(panel$rules$amended$cells), value = TRUE)
donor_changes <- rbindlist(lapply(names(panel$rules), function(r) {
  x <- panel$rules[[r]]$cells[grid_id %in% buffer_cells & group == "REST"]
  if (!nrow(x)) return(NULL)
  melt(x[, c("grid_id", pool_cols), with = FALSE], id.vars = "grid_id", variable.name = "pool", value.name = "was_member")[
    was_member == TRUE][, `:=`(rule = r, pool = sub("^pool_", "", pool), change = "removed: in the buffer around the new CENTER")]
}), fill = TRUE)

# 6. Coverage position of each new CENTER cell against the frozen range (category only, no values).
rng <- panel$cov_range
center_cov <- merge(data.table(grid_id = center_cells), cov[, .(grid_id, v = perc_waze_coverage)], by = "grid_id", all.x = TRUE)
center_cov[, position := fcase(is.na(v), "no 2022 value", v < rng[1], "below", v > rng[2], "above", default = "inside")]
center_cov[, v := NULL]
center_cov <- merge(center_cov, groups_new[, .(grid_id, step1_group)], by = "grid_id")[order(position, grid_id)]

# 7. Attributes of REST cells for the donor geography: zonal administration and distance from the line.
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
cent <- st_transform(st_as_sf(geo$cells, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE), SIRES)
zon <- rbind(st_sf(zonal = parr_u$AD_ZONAL, geometry = st_geometry(st_transform(parr_u, SIRES))),
             st_sf(zonal = parr_r$A_ZONAL, geometry = st_geometry(st_transform(st_zm(parr_r), SIRES))))
hit <- st_intersects(cent, zon)
# A centroid can fall in an urban and a rural parish where the two layers overlap: kept when both
# name the same zonal administration, labeled otherwise.
zonal_of <- function(i) {
  z <- unique(as.character(zon$zonal[i]))
  if (!length(z)) "outside the DMQ parish layers" else if (length(z) == 1L) z else paste("ambiguous:", paste(sort(z), collapse = " / "))
}
cell_attr <- data.table(grid_id = geo$cells$grid_id, n_parish_hits = lengths(hit),
  zonal_administration = vapply(hit, zonal_of, ""),
  km_to_line = as.numeric(apply(st_distance(cent, line), 1, min)) / 1000,
  km_to_nearest_station = geo$cells$nearest_station_m / 1000)

saveRDS(list(label = AMEND2_LABEL, polygons = lapply(polys, `[[`, "g"), unit_cells = unit_cells, center_cells = center_cells,
             core_cells = w_core[kept == TRUE, grid_id], corridor_cells = corridor_new, buffer_cells = buffer_cells,
             groups_new = groups_new, ring_in_center = ring_in_center, donor_changes = donor_changes,
             center_cov = center_cov, cell_attr = cell_attr, polygon_areas = polygon_areas, sires = SIRES$wkt),
        file.path(AMEND2_DATA, "geography.rds"))

# 8. Committed tables and map.
fwrite(polygon_areas, file.path(AMEND2_OUT, "polygon_areas.csv"))
# BELISARIO_RW road metres are the provider's per-cell values: only the weights are written.
fwrite(unit_cells[, .(unit, grid_id, step1_group, road_m = fifelse(unit == "BELISARIO_RW", NA_real_, round(road_m, 1)),
                      kept, weight = round(weight, 6), weight_source)],
       file.path(AMEND2_OUT, "unit_cells_weights.csv"))
fwrite(group_changes, file.path(AMEND2_OUT, "group_changes.csv"))
fwrite(if (is.null(donor_changes) || !nrow(donor_changes)) data.table(note = "no donor in any frozen pool lies in the buffer") else donor_changes,
       file.path(AMEND2_OUT, "donor_status_changes.csv"))
fwrite(ring_in_center, file.path(AMEND2_OUT, "ring_cells_in_new_center.csv"))
fwrite(center_cov, file.path(AMEND2_OUT, "center_cells_coverage_position.csv"))

hs <- st_transform(hex, SIRES)
show <- hs[hs$grid_id %in% c(center_cells, buffer_cells, corridor_new, geo$cells[group == "RING", grid_id]), ]
show$role <- fcase(show$grid_id %in% center_cells, "CENTER (road inside polygon)", show$grid_id %in% buffer_cells, "buffer (no donor, no placebo)",
                   show$grid_id %in% corridor_new, "CORRIDOR", default = "RING")
show <- merge(show, w_center[kept == TRUE, .(grid_id, weight)], by = "grid_id", all.x = TRUE)
bb <- st_bbox(st_buffer(st_transform(st_sfc(polys$CENTER$g, crs = 4326), SIRES), 1500))
p <- ggplot() +
  geom_sf(data = show, aes(fill = role), colour = "grey40", linewidth = 0.2, alpha = 0.55) +
  geom_sf_text(data = show[!is.na(show$weight), ], aes(label = sprintf("%.2f", weight)), size = 2.4) +
  geom_sf(data = st_transform(st_sfc(polys$CENTER$g, crs = 4326), SIRES), fill = NA, colour = "#b2182b", linewidth = 0.9) +
  geom_sf(data = st_transform(st_sfc(polys$CORE$g, crs = 4326), SIRES), fill = NA, colour = "#e66101", linewidth = 0.7, linetype = "dashed") +
  geom_sf(data = line, colour = "black", linewidth = 0.6) +
  geom_sf(data = st_transform(geo$stations, SIRES), shape = 21, fill = "white", size = 1.8) +
  scale_fill_manual(values = c(`CENTER (road inside polygon)` = "#f4a582", `buffer (no donor, no placebo)` = "#bababa",
                               CORRIDOR = "#b2abd2", RING = "#fee08b"), name = NULL) +
  coord_sf(crs = SIRES, datum = SIRES, xlim = bb[c(1, 3)], ylim = bb[c(2, 4)]) +
  labs(title = "CENTER under Amendments 2 and 4: GeoQuito Área Histórica (red) and road-length weights by cell",
       subtitle = "Numbers: share of drivable road length (OSM, 2022-01-01) inside the polygon. Dashed: World Heritage outline (OSM, volunteer-traced; descriptive unit).",
       caption = "Polygon: Municipio del DMQ, GeoQuito. Roads and outline: © OpenStreetMap contributors (ODbL). SIRES-DMQ metres.", x = NULL, y = NULL) +
  theme_minimal(base_size = 9)
ggsave(file.path(AMEND2_OUT, "map_center_units.png"), p, width = 9, height = 8, dpi = 150, bg = "white")

cat("CENTER cells:", length(center_cells), " CORE cells:", length(w_core[kept == TRUE, grid_id]),
    " buffer cells:", length(buffer_cells), " new CORRIDOR:", length(corridor_new), "\n")
print(polygon_areas[, .(polygon, area_ha_sires_dmq, area_ha_wgs84_ellipsoid)])
print(ring_in_center); print(group_changes[, .N, by = .(step1_group, new_group)])
print(center_cov[, .N, by = position]); print(if (is.null(donor_changes)) "no donor changes" else donor_changes[, .N, by = .(rule, pool)])
print(unit_cells[, .(cells = sum(kept), dropped_under_1m = sum(!kept), top_weight = max(weight, na.rm = TRUE)), by = unit])
print(cell_attr[, .N, by = .(n_parish_hits, ambiguous = grepl("^ambiguous", zonal_administration))])
