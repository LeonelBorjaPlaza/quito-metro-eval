# Shared setup for the Amendment 2 to 4 work (plan docs/analysis_plan.md): the historic-center units,
# pre period only. Source after step1_helpers.R. No outcome dated December 2023 or later is read:
# every outcome comes from the Step 1 panel, which is built by the pre-only loader.
AMEND2_LABEL <- "zero coding (provider's method: an absent record is no Waze-recorded congestion)"
AMEND2_DATA <- "Data/Waze/amend2"                 # ignored derived data
AMEND2_OUT <- "Output/step1_amendment2"           # committed aggregates, maps and specification
for (d in c(AMEND2_DATA, AMEND2_OUT)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Store deliveries, through the committed symlinks in Data/geo/ (read-only).
GEO <- list(
  center = "Data/geo/centro_historico_poligono/quito_historic_area.geojson",            # GeoQuito feature 41
  center_twin = "Data/geo/historic_center_geography/area_historica_chq.geojson",        # same feature, second download
  plan_shp = "Data/geo/historic_center_geography/limite_plan_chq_a.zip",                # holds the SIRES-DMQ .prj
  osm_chq = "Data/geo/historic_center_geography/osm_chq.osm",                           # WHC way 1077782502
  roads = "Data/geo/osm_roads_20220101/osm_roads_20220101.json",                        # OSM as of 2022-01-01
  parishes_urban = "Data/geo/geoquito_parroquias/parr_urbana_ord002.zip",
  parishes_rural = "Data/geo/geoquito_parroquias/parr_rural_conali.zip")
OSM_WHC_WAY <- "1077782502"
DRIVABLE <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
              "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link")
MIN_ROAD_M <- 1   # Amendment 4: a cell belongs to a polygon unit only with at least 1 m of drivable road inside
DIST_BANDS_KM <- c(2, 4)
# Ellipsoidal areas: Lambert azimuthal equal-area on WGS 84, centred on Quito (equal-area, so areas are
# ellipsoidal areas; no lwgeom in the project library).
LAEA <- st_crs("+proj=laea +lat_0=-0.22 +lon_0=-78.51 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs")
sires_crs <- function() {
  td <- file.path(tempdir(), "plan_shp"); unzip(GEO$plan_shp, exdir = td)
  st_crs(paste(readLines(file.path(td, "limite_plan_chq_a.prj"), warn = FALSE), collapse = ""))
}

# Verifies a store delivery against its own SHA256SUMS before use.
check_delivery <- function(dir) {
  sums <- fread(file.path(dir, "SHA256SUMS"), header = FALSE, col.names = c("sha256", "file"))
  sums[, file := sub("^\\./", "", file)]
  got <- sha256(file.path(dir, sums$file))
  if (!identical(unname(got), sums$sha256)) stop("Checksum mismatch in ", dir)
  invisible(nrow(sums))
}

read_roads <- function() {
  j <- jsonlite::fromJSON(GEO$roads, simplifyVector = FALSE)$elements
  hw <- vapply(j, function(e) e$tags$highway %||% NA_character_, "")
  j <- j[hw %in% DRIVABLE]
  st_sf(osm_id = vapply(j, function(e) as.character(e$id), ""), highway = vapply(j, function(e) e$tags$highway, ""),
        geometry = st_sfc(lapply(j, function(e) st_linestring(do.call(rbind, lapply(e$geometry, function(p) c(p$lon, p$lat))))),
                          crs = 4326))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# Drivable road metres inside `poly`, by H3 cell, measured in SIRES-DMQ.
road_by_cell <- function(poly, roads, hex, crs) {
  poly <- st_transform(poly, crs); roads <- st_transform(roads, crs); hex <- st_transform(hex, crs)
  # Intersections can return GEOMETRYCOLLECTIONs (a road that crosses and touches an edge) or points;
  # line parts are extracted, never dropped, and total length must be conserved across the cell split.
  lines_only <- function(x) {
    x <- x[!st_is_empty(x), ]
    gc <- st_geometry_type(x) == "GEOMETRYCOLLECTION"
    if (any(gc)) x <- rbind(x[!gc, ], suppressWarnings(st_collection_extract(x[gc, ], "LINESTRING")))
    x[st_geometry_type(x) %in% c("LINESTRING", "MULTILINESTRING"), ]
  }
  inside <- lines_only(suppressWarnings(st_intersection(roads, st_geometry(poly))))
  pieces <- lines_only(suppressWarnings(st_intersection(inside, hex[, "grid_id"])))
  pieces$road_m <- as.numeric(st_length(pieces))
  stopifnot(abs(sum(pieces$road_m) - sum(as.numeric(st_length(inside)))) < 1)
  as.data.table(st_drop_geometry(pieces))[, .(road_m = sum(road_m)), by = grid_id][order(-road_m)]
}

# Weighted unit-month: a unit-month exists only if every positive-weight cell is valid (plan section 1).
unit_series <- function(cell_block, cells_w, blk = "peak") {
  x <- merge(cell_block[block == blk & grid_id %in% cells_w$grid_id], cells_w[, .(grid_id, weight)], by = "grid_id")
  stopifnot(x[, uniqueN(grid_id), by = date][, all(V1 == nrow(cells_w))], abs(sum(cells_w$weight) - 1) < 1e-9)
  x[, .(value = if (anyNA(value)) NA_real_ else sum(weight * value), n_missing_cells = sum(is.na(value)),
        reason = if (anyNA(value)) paste(sort(unique(reason[is.na(value)])), collapse = "+") else "valid"), by = date][order(date)]
}

# Order-invariance check with tolerance 1e-6 (absolute), used in 33 and 34 instead of the Step 1 helper's
# 1e-8 relative tolerance: at the grid-minimum penalty (about 2e-5) the near-interpolating ridge solve moves
# the intercept by about 1e-8 when the months are reordered (predictions by about 6e-9), while fits at
# ordinary penalties agree to about 1e-13. Needs step1_fit_helpers.R.
check_order_invariance_1e6 <- function(y1, Y0, fit_months, post_months, lambda, seed = 20260927, tol = 1e-6) {
  set.seed(seed)
  a <- fit_asc(y1, Y0, fit_months, post_months, lambda); b <- fit_asc(y1, Y0, sample(fit_months), post_months, lambda)
  stopifnot(max(abs(a$weights - b$weights)) < tol, abs(a$intercept - b$intercept) < tol,
            max(abs(a$path[period == "post", synthetic] - b$path[period == "post", synthetic])) < tol)
  invisible(TRUE)
}

# Distance bands from the line's alignment (not from stations, which define the low-exposure pool).
dist_band <- function(km) cut(km, c(-Inf, DIST_BANDS_KM, Inf), labels = c("under 2 km", "2 to 4 km", "over 4 km"), right = FALSE)
