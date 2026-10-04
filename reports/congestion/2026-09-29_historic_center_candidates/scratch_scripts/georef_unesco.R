# Place the UNESCO 2019 map (document 173425) under the candidate polygons as a visual reference.
# The raster is positioned by its own printed 1 km grid. Nothing is digitized from it.
# Also counts the orange (core) and blue (buffer) fill pixels, converted to hectares with the grid scale,
# as a rough check of the map against the official 70.43 and 304.82 ha (scratch only).
source("Scripts/Congestion/step1_helpers.R")
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
read_ppm <- function(f) {
  con <- file(f, "rb"); on.exit(close(con))
  hdr <- character(0)
  while (length(hdr) < 4) { l <- readLines(con, n = 1); hdr <- c(hdr, strsplit(l, "\\s+")[[1]]) }
  w <- as.integer(hdr[2]); h <- as.integer(hdr[3])
  v <- readBin(con, "raw", n = w * h * 3)
  a <- array(as.integer(v), dim = c(3, w, h))
  aperm(a, c(3, 2, 1)) / 255  # [row, col, channel]
}
img <- read_ppm(file.path(S, "unesco_r100-1.ppm"))
H <- dim(img)[1]; W <- dim(img)[2]
dark <- (img[, , 1] + img[, , 2] + img[, , 3]) / 3 < 0.35
col_frac <- colMeans(dark); row_frac <- rowMeans(dark)
# Grid lines and the frame are long dark runs; keep peaks, then merge adjacent pixels.
peaks <- function(fr, thr) { i <- which(fr > thr); if (!length(i)) return(integer()); g <- cumsum(c(1, diff(i) > 2)); as.integer(round(tapply(i, g, mean))) }
vc <- peaks(col_frac, 0.5); hr <- peaks(row_frac, 0.5)
cat("vertical lines at px:", vc, "\nhorizontal lines at px:", hr, "\n")
saveRDS(list(vc = vc, hr = hr, col_frac = col_frac, row_frac = row_frac), file.path(S, "georef_lines.rds"))

# Affine placement from the printed grid: columns 12..1587 = E 496705..500705; rows 259..1440 = N 9977075..9974075.
px_m <- mean(diff(vc[1:5])); py_m <- mean(diff(hr[3:6]))
E0 <- 496705 - (vc[1]) * 1000 / px_m          # easting at column 0
N0 <- 9977075 + (hr[3]) * 1000 / py_m         # northing at row 0
cat("pixels per km:", round(px_m, 2), round(py_m, 2), "\n")
xy_of <- function(col, row) cbind(E = E0 + col * 1000 / px_m, N = N0 - row * 1000 / py_m)
R <- img[, , 1]; G_ <- img[, , 2]; B <- img[, , 3]
orange <- R > 0.85 & G_ > 0.5 & G_ < 0.85 & B < 0.65
blue <- B > 0.75 & R < 0.65 & G_ < 0.8
ha_per_px <- (1000 / px_m) * (1000 / py_m) / 1e4
cat("fill pixels -> ha (rough, line work excluded): orange", round(sum(orange) * ha_per_px, 1),
    " blue", round(sum(blue) * ha_per_px, 1), " orange+blue", round((sum(orange) + sum(blue)) * ha_per_px, 1), "\n")
oi <- which(orange, arr.ind = TRUE)
oc <- colMeans(xy_of(oi[, "col"], oi[, "row"]))
cand <- st_read(file.path(S, "candidates.gpkg"), quiet = TRUE)
prj <- paste(readLines(unz(file.path(S, "limite_plan_chq_a.zip"), "limite_plan_chq_a.prj"), warn = FALSE), collapse = "")
SIRES <- st_crs(prj)
whc <- st_transform(cand[cand$id == "O_WHC", ], SIRES)
wc <- st_coordinates(st_centroid(st_geometry(whc)))[1, ]
cat("centroid of orange core pixels (map grid):", round(oc), "\ncentroid of OSM WHC (SIRES):", round(wc),
    "\nmap minus OSM (m):", round(oc - wc), "\n")
# Compare with PSAD56 Quito TM for the same point.
tmq56 <- st_crs("+proj=tmerc +lat_0=0 +lon_0=-78.5 +k=1.0004584 +x_0=500000 +y_0=10000000 +ellps=intl +towgs84=-60.31,245.935,31.008,-12.324,-3.755,7.37,0.447 +units=m +no_defs")
w56 <- st_coordinates(st_transform(st_centroid(st_geometry(whc)), tmq56))[1, ]
cat("OSM WHC centroid in PSAD56 Quito TM:", round(w56), " map minus that (m):", round(oc - w56), "\n")
saveRDS(list(E0 = E0, N0 = N0, px_m = px_m, py_m = py_m, oc = oc), file.path(S, "georef_affine.rds"))
