# Final overlay: candidates, H3 grid, CENTER ring, stations, line, landmarks, over the UNESCO 2019 map
# (document 173425) as a semi-transparent underlay. The underlay is placed by its printed 1 km grid and
# then moved by the offset between its orange core and the OSM WHC trace (the trace matches the official
# corner intersections; see check_core_corners.R). Nothing is digitized: pixel classes are used only to
# report, per candidate, the share of its area the UNESCO map colours as core or buffer, and rough map areas.
source("Scripts/Congestion/step1_helpers.R")
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
prj <- paste(readLines(unz(file.path(S, "limite_plan_chq_a.zip"), "limite_plan_chq_a.prj"), warn = FALSE), collapse = "")
SIRES <- st_crs(prj)
read_ppm <- function(f) {
  con <- file(f, "rb"); on.exit(close(con)); hdr <- character(0)
  while (length(hdr) < 4) { l <- readLines(con, n = 1); hdr <- c(hdr, strsplit(l, "\\s+")[[1]]) }
  w <- as.integer(hdr[2]); h <- as.integer(hdr[3])
  aperm(array(as.integer(readBin(con, "raw", n = w * h * 3)), dim = c(3, w, h)), c(3, 2, 1)) / 255
}
img <- read_ppm(file.path(S, "unesco_r100-1.ppm"))
aff <- readRDS(file.path(S, "georef_affine.rds"))
cand <- st_transform(st_read(file.path(S, "candidates.gpkg"), quiet = TRUE), SIRES)
shift <- unname(aff$oc - st_coordinates(st_centroid(st_geometry(cand[cand$id == "O_WHC", ])))[1, ])
# Map frame: columns 12..1587, rows 12..1440.
c0 <- 12; c1 <- 1587; r0 <- 12; r1 <- 1440
E_of <- function(col) aff$E0 + col * 1000 / aff$px_m - shift[1]
N_of <- function(row) aff$N0 - row * 1000 / aff$py_m - shift[2]
sub <- img[r0:r1, c0:c1, ]
R <- sub[, , 1]; G_ <- sub[, , 2]; B <- sub[, , 3]
orange <- R > 0.85 & G_ > 0.5 & G_ < 0.85 & B < 0.65
blue <- B > 0.75 & R < 0.65 & G_ < 0.8
# Morphological closing with a 9-pixel box, to absorb the map's line work inside the fills.
boxsum <- function(m, k) {
  h <- (k - 1) %/% 2; I <- matrix(0, nrow(m) + 1, ncol(m) + 1); I[-1, -1] <- apply(apply(m * 1, 2, cumsum), 1, cumsum) |> t()
  r <- seq_len(nrow(m)); cc <- seq_len(ncol(m))
  ra <- pmax(r - h, 1); rb <- pmin(r + h, nrow(m)); ca <- pmax(cc - h, 1); cb <- pmin(cc + h, ncol(m))
  I[rb + 1, cb + 1] - I[ra, cb + 1] - I[rb + 1, ca] + I[ra, ca]
}
close_mask <- function(m, k = 9) { d <- boxsum(m, k) > 0; boxsum(!d, k) == 0 }
core_m <- close_mask(orange); any_m <- close_mask(orange | blue)
ha_px <- (1000 / aff$px_m) * (1000 / aff$py_m) / 1e4
cat("UNESCO map, rough areas from pixels after closing (ha): core", round(sum(core_m) * ha_px, 1),
    " core+buffer", round(sum(any_m) * ha_px, 1), " buffer only", round(sum(any_m & !core_m) * ha_px, 1), "\n")
# Share of each candidate that the map colours as core, or as core or buffer (every 2nd pixel).
ri <- seq(1, nrow(sub), 2); ci <- seq(1, ncol(sub), 2)
g <- CJ(r = ri, c = ci)
g[, `:=`(E = E_of(c + c0 - 1), N = N_of(r + r0 - 1), core = core_m[cbind(r, c)], any = any_m[cbind(r, c)])]
pts <- st_as_sf(g, coords = c("E", "N"), crs = SIRES)
share <- rbindlist(lapply(seq_len(nrow(cand)), function(i) {
  inn <- st_intersects(pts, cand[i, ], sparse = FALSE)[, 1]
  inside_frame <- as.numeric(st_area(st_intersection(st_geometry(cand[i, ]),
    st_as_sfc(st_bbox(c(xmin = E_of(c0), xmax = E_of(c1), ymin = N_of(r1), ymax = N_of(r0)), crs = SIRES))))) /
    as.numeric(st_area(cand[i, ]))
  data.table(id = cand$id[i], share_in_map_frame = round(inside_frame, 3),
             share_coloured_core = round(mean(g$core[inn]), 3), share_coloured_core_or_buffer = round(mean(g$any[inn]), 3),
             unesco_core_or_buffer_covered_ha = round(sum(g$any & inn) * ha_px * 4, 1))
}))
print(share)
saveRDS(list(shift = shift, share = share, core_ha = sum(core_m) * ha_px, any_ha = sum(any_m) * ha_px),
        file.path(S, "overlay_final.rds"))

# Underlay raster: keep colour, fade to 45 percent.
ras <- sub; alpha <- 0.45
ras <- 1 - alpha * (1 - ras)
ras_rgb <- rgb(ras[, , 1], ras[, , 2], ras[, , 3]); dim(ras_rgb) <- dim(ras)[1:2]
con <- duck(); G <- build_groups(con); DBI::dbDisconnect(con, shutdown = TRUE)
grid <- fread(grid_path, colClasses = "character")
hex <- st_transform(merge(st_as_sf(grid, wkt = "h3_geometry_r8", crs = 4326), G$cells[, .(grid_id, group)], by = "grid_id"), SIRES)
xlim <- c(496805, 500605); ylim <- c(9973400, 9977200)
bb <- st_as_sfc(st_bbox(c(xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2]), crs = SIRES))
hexs <- hex[st_intersects(hex, bb, sparse = FALSE)[, 1], ]
ring <- hex[hex$grid_id %in% G$rings$CENTER, ]
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
sta <- st_transform(G$stations, SIRES); mon <- st_transform(G$monitors[G$monitors$Station %in% c("Centro", "Belisario"), ], SIRES)
lm <- readRDS(file.path(S, "compare_candidates.rds"))$lm
el <- rbindlist(lapply(c("osm_landmarks1.json", "osm_landmarks2.json"), function(f) {
  e <- jsonlite::fromJSON(file.path(S, f))$elements
  data.table(osm = paste(e$type, e$id), lat = ifelse(is.na(e$lat), e$center$lat, e$lat), lon = ifelse(is.na(e$lon), e$center$lon, e$lon))
}))
lm <- merge(lm[, .(landmark, expected, osm)], unique(el), by = "osm")
lm_sf <- st_transform(st_as_sf(lm, coords = c("lon", "lat"), crs = 4326), SIRES)
show <- cand[cand$id %in% c("G_AH", "G_PARR", "O_WHC", "O_PARR", "G_PLAN"), ]
cols <- c(G_AH = "#d7301f", G_PLAN = "#555555", G_PARR = "#1f78b4", O_WHC = "#e6550d", O_PARR = "#31a354")
ltys <- c(G_AH = "solid", G_PLAN = "dotted", G_PARR = "solid", O_WHC = "solid", O_PARR = "dashed")
labs_ <- c(G_AH = "G_AH  GeoQuito Area Historica CHQ (515 ha)", G_PLAN = "G_PLAN  GeoQuito Plan de Accion limit (1,417 ha)",
           G_PARR = "G_PARR  GeoQuito parish Centro Historico (374 ha)", O_WHC = "O_WHC  OSM World Heritage trace (72 ha)",
           O_PARR = "O_PARR  OSM parish relation 89703 (371 ha)")
p <- ggplot() +
  annotation_raster(ras_rgb, xmin = E_of(c0), xmax = E_of(c1), ymin = N_of(r1), ymax = N_of(r0)) +
  geom_sf(data = hexs, fill = NA, colour = "grey35", linewidth = 0.25) +
  geom_sf(data = ring, fill = NA, colour = "goldenrod3", linewidth = 0.9, linetype = "longdash") +
  geom_sf(data = show, aes(colour = id, linetype = id), fill = NA, linewidth = 0.9) +
  geom_sf(data = line, colour = "black", linewidth = 0.7) +
  geom_sf(data = sta, shape = 21, fill = "white", colour = "black", size = 2.2) +
  geom_sf(data = mon, shape = 17, colour = "black", size = 2.6) +
  geom_sf(data = lm_sf, aes(shape = expected), colour = "black", size = 2.2, stroke = 0.9) +
  geom_sf_text(data = lm_sf, aes(label = landmark), size = 2.3, nudge_y = 70) +
  scale_shape_manual(values = c(core = 8, wider = 4), name = "Landmark (expected area)") +
  scale_colour_manual(values = cols, labels = labs_, name = "Candidate") +
  scale_linetype_manual(values = ltys, labels = labs_, name = "Candidate") +
  coord_sf(crs = SIRES, datum = SIRES, xlim = xlim, ylim = ylim, expand = FALSE) +
  labs(title = "Historic-center candidates over the UNESCO 2019 map (orange: core, blue: buffer zone)",
       subtitle = paste0("SIRES-DMQ metres. Underlay placed by its printed grid, then moved ", round(-shift[1]), " m E and ",
                         round(-shift[2]), " m N to match the OSM trace, which fits the official corner streets.\n",
                         "Grey: H3 r8 cells. Gold dashed: the seven-cell CENTER ring. Black: Line 1, stations (circles), monitors (triangles)."),
       x = NULL, y = NULL, caption = "Sources: GeoQuito (DMQ), OpenStreetMap contributors (ODbL), UNESCO WHC document 173425 (visual reference only).") +
  theme_minimal(base_size = 9) + theme(panel.grid.major = element_line(colour = "grey75", linewidth = 0.15))
ggsave(file.path(S, "candidates_overlay_unesco.png"), p, width = 12, height = 10, dpi = 150, bg = "white")
cat("written\n")
