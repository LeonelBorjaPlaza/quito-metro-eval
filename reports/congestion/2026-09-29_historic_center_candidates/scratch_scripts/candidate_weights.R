# Road-length weights each candidate would give its hexagons (rule B.4), and the share of each candidate's
# road length that lies inside the UNESCO map's core or buffer colour. Scratch only; no Waze outcome is read.
source("Scripts/Congestion/step1_helpers.R")
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
prj <- paste(readLines(unz(file.path(S, "limite_plan_chq_a.zip"), "limite_plan_chq_a.prj"), warn = FALSE), collapse = "")
SIRES <- st_crs(prj)
j <- jsonlite::fromJSON(file.path(S, "osm_roads_20220101.json"), simplifyVector = FALSE)$elements
drive <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
           "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link")
j <- j[sapply(j, function(e) e$tags$highway %in% drive)]
roads <- st_transform(st_sf(osm_id = sapply(j, `[[`, "id"),
  geometry = st_sfc(lapply(j, function(e) st_linestring(do.call(rbind, lapply(e$geometry, function(p) c(p$lon, p$lat))))), crs = 4326)), SIRES)
cand <- st_transform(st_read(file.path(S, "candidates.gpkg"), quiet = TRUE), SIRES)
cand <- cand[cand$id %in% c("O_WHC", "G_PARR", "G_AH", "O_PARR"), ]
con <- duck(); G <- build_groups(con); DBI::dbDisconnect(con, shutdown = TRUE)
grid <- fread(grid_path, colClasses = "character")
hex <- st_transform(merge(st_as_sf(grid, wkt = "h3_geometry_r8", crs = 4326), G$cells[, .(grid_id, group)], by = "grid_id"), SIRES)
ringu <- st_union(hex[hex$grid_id %in% G$rings$CENTER, ]); ringu <- st_sf(id = "RING7", geometry = st_sfc(ringu, crs = SIRES))
cand <- st_sf(id = cand$id, geometry = st_geometry(cand)); units_ <- rbind(cand, ringu)
# UNESCO pixel mask, placed as in overlay_final.R.
ov <- readRDS(file.path(S, "overlay_final.rds")); aff <- readRDS(file.path(S, "georef_affine.rds"))
read_ppm <- function(f) {
  con <- file(f, "rb"); on.exit(close(con)); hdr <- character(0)
  while (length(hdr) < 4) { l <- readLines(con, n = 1); hdr <- c(hdr, strsplit(l, "\\s+")[[1]]) }
  w <- as.integer(hdr[2]); h <- as.integer(hdr[3])
  aperm(array(as.integer(readBin(con, "raw", n = w * h * 3)), dim = c(3, w, h)), c(3, 2, 1)) / 255
}
img <- read_ppm(file.path(S, "unesco_r100-1.ppm"))
R <- img[, , 1]; G_ <- img[, , 2]; B <- img[, , 3]
col_any <- (R > 0.85 & G_ > 0.5 & G_ < 0.85 & B < 0.65) | (B > 0.75 & R < 0.65 & G_ < 0.8)
boxsum <- function(m, k) {
  h <- (k - 1) %/% 2; I <- matrix(0, nrow(m) + 1, ncol(m) + 1); I[-1, -1] <- t(apply(apply(m * 1, 2, cumsum), 1, cumsum))
  r <- seq_len(nrow(m)); cc <- seq_len(ncol(m))
  ra <- pmax(r - h, 1); rb <- pmin(r + h, nrow(m)); ca <- pmax(cc - h, 1); cb <- pmin(cc + h, ncol(m))
  I[rb + 1, cb + 1] - I[ra, cb + 1] - I[rb + 1, ca] + I[ra, ca]
}
any_m <- { d <- boxsum(col_any, 9) > 0; boxsum(!d, 9) == 0 }
in_unesco <- function(xy) {
  col <- round((xy[, 1] + ov$shift[1] - aff$E0) * aff$px_m / 1000); row <- round((aff$N0 - (xy[, 2] + ov$shift[2])) * aff$py_m / 1000)
  ok <- col >= 12 & col <= 1587 & row >= 12 & row <= 1440
  out <- rep(NA, nrow(xy)); out[ok] <- any_m[cbind(row[ok], col[ok])]; out
}
res <- list(); wts <- list()
for (i in seq_len(nrow(units_))) {
  u <- units_[i, ]
  pr <- suppressWarnings(st_intersection(roads, st_geometry(u)))
  pr <- pr[st_geometry_type(pr) %in% c("LINESTRING", "MULTILINESTRING"), ]
  L <- sum(as.numeric(st_length(pr)))
  # share of road length in UNESCO colour: sample points every 10 m
  pts <- st_coordinates(st_line_sample(st_cast(st_geometry(pr), "LINESTRING"), density = 1 / 10))
  iu <- in_unesco(pts[, 1:2])
  # weights: road length inside the unit, by hexagon
  ph <- suppressWarnings(st_intersection(pr, hex[, c("grid_id", "group")]))
  ph$len <- as.numeric(st_length(ph))
  w <- as.data.table(st_drop_geometry(ph))[, .(len = sum(len)), by = .(grid_id, group)][, w := len / sum(len)][order(-w)]
  wts[[u$id]] <- w[, unit := u$id]
  res[[i]] <- data.table(unit = u$id, drivable_road_km = round(L / 1000, 2), share_in_unesco_core_or_buffer = round(mean(iu, na.rm = TRUE), 3),
    n_hex_positive = nrow(w), top_hex_weight = round(w$w[1], 3), hex_weight_ge_5pct = sum(w$w >= 0.05),
    weight_on_ring7_cells = round(sum(w[grid_id %in% G$rings$CENTER]$w), 3),
    weight_by_group = paste(w[, .(s = round(sum(w), 3)), by = group][, paste(group, s, sep = ":")], collapse = " "))
}
res <- rbindlist(res); print(res)
saveRDS(list(res = res, wts = rbindlist(wts)), file.path(S, "candidate_weights.rds"))
