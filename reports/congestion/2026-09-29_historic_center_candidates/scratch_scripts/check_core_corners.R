# Check the OSM WHC trace against the textual corner points of the nucleo central
# (Plan de Accion del Centro Historico, technical document, pachq.txt lines 17802-17835).
suppressPackageStartupMessages({ library(sf); library(data.table) })
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
prj <- paste(readLines(unz(file.path(S, "limite_plan_chq_a.zip"), "limite_plan_chq_a.prj"), warn = FALSE), collapse = "")
SIRES <- st_crs(prj)
j <- jsonlite::fromJSON(file.path(S, "osm_streets.json"), simplifyVector = FALSE)$elements
streets <- st_sf(name = sapply(j, function(e) e$tags$name),
  geometry = st_sfc(lapply(j, function(e) st_linestring(do.call(rbind, lapply(e$geometry, function(p) c(p$lon, p$lat))))), crs = 4326))
streets <- st_transform(streets, SIRES)
pick <- function(rx) st_union(streets[grepl(rx, streets$name), ])
pairs <- list(
  c("SW", "^Chimborazo$", "24 de Mayo"), c("NW", "Mires", "^Olmedo$"), c("NW", "Mej[ií]a", "^Chimborazo$"),
  c("NW", "Mej[ií]a", "Mires"), c("NW", "Imbabura", "^Olmedo$"), c("NW", "Imbabura", "Manab"),
  c("NE", "Manab", "Mont[uú]far"), c("SE", "Mont[uú]far", "Vicente Rocafuerte"), c("SE", "Vicente Rocafuerte", "Paredes"),
  c("SE", "Paredes", "Morales"))
cand <- st_transform(st_read(file.path(S, "candidates.gpkg"), quiet = TRUE), SIRES)
whc_b <- st_cast(st_geometry(cand[cand$id == "O_WHC", ]), "MULTILINESTRING")
aff <- readRDS(file.path(S, "georef_affine.rds"))
shift <- aff$oc - st_coordinates(st_centroid(st_geometry(cand[cand$id == "O_WHC", ])))[1, ]
whc_shift <- st_set_crs(st_geometry(whc_b) + shift, SIRES)
out <- rbindlist(lapply(pairs, function(p) {
  a <- pick(p[2]); b <- pick(p[3])
  np <- st_nearest_points(a, b); gap <- as.numeric(st_length(np))
  pt <- st_centroid(np)  # the crossing point, or the midpoint of the closest approach
  data.table(corner = p[1], streets = paste(p[2], "x", p[3]), street_gap_m = round(gap),
             dist_to_osm_whc_boundary_m = round(as.numeric(st_distance(pt, whc_b))),
             dist_if_trace_shifted_to_unesco_grid_m = round(as.numeric(st_distance(pt, whc_shift))))
}))
print(out)
cat("shift applied (m):", round(shift), "\n")
saveRDS(out, file.path(S, "core_corners.rds"))
