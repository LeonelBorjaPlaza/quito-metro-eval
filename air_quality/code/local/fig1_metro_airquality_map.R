# =============================================================================
# Figure 1. Quito Metro Line 1 and the air quality monitoring network
# Quito Metro air quality project
#
# Inputs  (in data/for_maps):
#   Distancia_REMMAQ_Metro.gpkg  REMMAQ monitors, EPSG:4326, field HubDist (km)
#   MetroLine.gpkg               Metro Line 1 geometry, local TMQ projection
#   MetroStations.gpkg           15 metro stations, local TMQ projection
#
# Output  (in output/maps):
#   fig1_metro_airquality_map.png  (600 dpi raster)
#   fig1_metro_airquality_map.pdf  (vector, basemap embedded as raster)
#
# Notes:
#   The metro line and stations arrive in Quito's local TMQ projection while the
#   monitors are in lon/lat. Everything is reprojected to Web Mercator for a
#   clean tile overlay. Web Mercator distortion is negligible here because Quito
#   sits on the equator, so the scale bar is accurate.
# =============================================================================

## ---- 0. Packages ------------------------------------------------------------
# First run only:
#   install.packages(c("sf","ggplot2","dplyr","ggspatial","ggrepel",
#                       "maptiles","tidyterra","rnaturalearth",
#                       "rnaturalearthdata","patchwork"))
#   renv::snapshot()
suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(dplyr)
  library(ggspatial)
  library(ggrepel)
  library(maptiles)
  library(tidyterra)
  library(rnaturalearth)
  library(patchwork)
})

## ---- 1. Parameters ----------------------------------------------------------
PROJECT_ROOT <- here::here()  # was the absolute OneDrive path; relative to the module root since 2026-09-24
DATA_MAPS    <- file.path(PROJECT_ROOT, "data", "for_maps")
OUT_DIR      <- file.path(PROJECT_ROOT, "output", "maps")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

NEAR_THRESHOLD_KM <- 1.0              # monitors within this distance count as near corridor
DROP_STATIONS     <- c("El Camal")    # El Camal removed to match the 8-station paper panel
BASEMAP_PROVIDER  <- "CartoDB.Positron"  # alts: "CartoDB.PositronNoLabels",
                                          #       "Esri.WorldShadedRelief" (terrain),
                                          #       "OpenStreetMap", "Esri.WorldImagery"
BASEMAP_ZOOM      <- 12               # higher = sharper but more tiles
MAP_CRS           <- 3857             # Web Mercator for tile overlay
PAD_X             <- 0.12             # horizontal padding around monitor extent
PAD_Y             <- 0.05             # vertical padding
SHOW_EQUATOR      <- TRUE             # draw the equator only if it sits near the top of the map

col_line <- "#222222"  # metro line and metro stations
col_near <- "#D55E00"  # near corridor monitors (Okabe-Ito, colorblind safe)
col_far  <- "#0072B2"  # far monitors

# legend labels (near label shows the threshold and stays in sync with it)
lab_near <- sprintf("Monitor, near corridor (< %g km)", NEAR_THRESHOLD_KM)
lab_far  <- "Monitor, far from corridor"

## ---- 2. Read and harmonize --------------------------------------------------
read_first <- function(file) {
  p <- file.path(DATA_MAPS, file)
  st_read(p, layer = st_layers(p)$name[1], quiet = TRUE)
}

mon  <- read_first("Distancia_REMMAQ_Metro.gpkg")
line <- st_zm(read_first("MetroLine.gpkg"))      # drop Z and M dimensions
sta  <- st_zm(read_first("MetroStations.gpkg"))

mon <- mon |>
  filter(!Station %in% DROP_STATIONS) |>
  mutate(
    klass = if_else(HubDist < NEAR_THRESHOLD_KM, lab_near, lab_far),
    klass = factor(klass, levels = c(lab_near, lab_far)),
    lab   = sprintf("%s\n%.2f km", Station, HubDist)
  )

mon  <- st_transform(mon,  MAP_CRS)
line <- st_transform(line, MAP_CRS)
sta  <- st_transform(sta,  MAP_CRS)

# label coordinates (avoids relying on the sf geometry column name)
mon_xy <- cbind(st_drop_geometry(mon), st_coordinates(mon))

## ---- 3. Extent and basemap --------------------------------------------------
bb <- st_bbox(mon)
dx <- bb["xmax"] - bb["xmin"]
dy <- bb["ymax"] - bb["ymin"]
bb["xmin"] <- bb["xmin"] - dx * PAD_X
bb["xmax"] <- bb["xmax"] + dx * PAD_X
bb["ymin"] <- bb["ymin"] - dy * PAD_Y
bb["ymax"] <- bb["ymax"] + dy * PAD_Y

# Equator: include it only when it sits at or near the top of the map, i.e. just
# above San Antonio de Pichincha. Skipped automatically if the extent changes so
# the equator would fall far off-frame.
eq_y <- st_coordinates(st_transform(st_sfc(st_point(c(-78.5, 0)), crs = 4326),
                                    MAP_CRS))[1, "Y"]
show_eq <- SHOW_EQUATOR &&
           eq_y >= bb["ymax"] - dy * 0.15 &&   # not far below the top edge
           eq_y <= bb["ymax"] + dy * 0.30       # not far above the top edge
if (show_eq) bb["ymax"] <- max(bb["ymax"], eq_y + dy * 0.025)  # headroom for the label

if (show_eq) {
  eq_line <- st_sfc(st_linestring(rbind(c(bb["xmin"], eq_y),
                                        c(bb["xmax"], eq_y))), crs = MAP_CRS)
  eq_lab_x <- bb["xmin"] + (bb["xmax"] - bb["xmin"]) * 0.27
  eq_layers <- list(
    geom_sf(data = eq_line, color = "grey25", linetype = "22", linewidth = 0.5),
    annotate("label", x = eq_lab_x, y = eq_y, label = "Equator  0\u00b0",
             size = 2.8, fontface = "italic", color = "grey20",
             fill = alpha("white", 0.7), label.size = 0,
             label.padding = unit(0.1, "lines"))
  )
} else {
  eq_layers <- NULL
}

ext <- st_as_sfc(bb)

basemap <- get_tiles(ext, provider = BASEMAP_PROVIDER, zoom = BASEMAP_ZOOM,
                     crop = TRUE, cachedir = tempdir())

## ---- 4. Main map ------------------------------------------------------------
main <- ggplot() +
  geom_spatraster_rgb(data = basemap, maxcell = 5e6) +

  # equator (drawn only when near the top of the map; otherwise eq_layers is NULL)
  eq_layers +

  # metro line: white casing under a dark line so it reads on any basemap
  geom_sf(data = line, color = "white",  linewidth = 2.2) +
  geom_sf(data = line, aes(color = "Metro Line 1"), linewidth = 1.0) +

  # metro stations
  geom_sf(data = sta, aes(color = "Metro station"), size = 1.2) +

  # monitors, colored by role
  geom_sf(data = mon, aes(fill = klass), shape = 21, color = "white",
          size = 4.2, stroke = 0.7) +

  # labels with leader lines, repelled to avoid overlap
  geom_label_repel(
    data = mon_xy, aes(X, Y, label = lab),
    size = 2.9, fontface = "bold", label.size = 0,
    fill = alpha("white", 0.72), label.padding = unit(0.12, "lines"),
    box.padding = 0.5, min.segment.length = 0,
    segment.color = "grey40", segment.size = 0.3,
    max.overlaps = Inf, seed = 1
  ) +

  scale_color_manual(
    values = c("Metro Line 1" = col_line, "Metro station" = col_line),
    breaks = c("Metro Line 1", "Metro station"), name = NULL,
    guide  = guide_legend(order = 1)
  ) +
  scale_fill_manual(
    values = c(col_near, col_far) |> setNames(c(lab_near, lab_far)),
    name = NULL, guide = guide_legend(order = 2, override.aes = list(size = 4))
  ) +

  annotation_scale(location = "bl", width_hint = 0.22, style = "ticks",
                   line_col = "grey20", text_col = "grey20") +
  annotation_north_arrow(location = "tr", which_north = "true",
                         height = unit(0.9, "cm"), width = unit(0.9, "cm"),
                         style = north_arrow_minimal()) +

  coord_sf(xlim = c(bb["xmin"], bb["xmax"]),
           ylim = c(bb["ymin"], bb["ymax"]),
           expand = FALSE, crs = MAP_CRS) +
  theme_void(base_size = 11) +
  theme(
    legend.position   = c(0.99, 0.86),
    legend.justification = c(1, 1),
    legend.background = element_rect(fill = alpha("white", 0.85), color = "grey70"),
    legend.margin     = margin(4, 6, 4, 6),
    legend.spacing.y  = unit(1, "pt"),
    panel.border      = element_rect(color = "grey50", fill = NA, linewidth = 0.5),
    plot.margin       = margin(2, 2, 2, 2)
  )

## ---- 5. Locator inset (Ecuador within South America) ------------------------
world <- ne_countries(scale = "medium", returnclass = "sf")
sam   <- world |> filter(continent == "South America")
ecu   <- world |> filter(admin == "Ecuador")
quito <- st_sfc(st_point(c(-78.50, -0.22)), crs = 4326)

inset <- ggplot() +
  geom_sf(data = sam, fill = "grey92", color = "grey65", linewidth = 0.2) +
  geom_sf(data = ecu, fill = col_near, color = "grey40", linewidth = 0.2) +
  geom_sf(data = quito, color = "black", size = 1.1) +
  coord_sf(xlim = c(-82, -34), ylim = c(-56, 13), expand = FALSE) +
  theme_void() +
  theme(panel.border     = element_rect(color = "grey50", fill = NA, linewidth = 0.4),
        panel.background = element_rect(fill = "white", color = NA))

## ---- 6. Compose and export --------------------------------------------------
fig <- main +
  inset_element(inset, left = 0.73, bottom = 0.015,
                right = 0.985, top = 0.215, align_to = "full")

asp <- as.numeric((bb["ymax"] - bb["ymin"]) / (bb["xmax"] - bb["xmin"]))
W_mm <- 160
H_mm <- min(W_mm * asp, 285)   # cap height to fit a page; scale in LaTeX as needed

ggsave(file.path(OUT_DIR, "fig1_metro_airquality_map.png"), fig,
       width = W_mm, height = H_mm, units = "mm", dpi = 600, bg = "white")
ggsave(file.path(OUT_DIR, "fig1_metro_airquality_map.pdf"), fig,
       width = W_mm, height = H_mm, units = "mm", device = cairo_pdf, bg = "white")

message("Saved to: ", OUT_DIR)
message(sprintf("Figure size: %.0f x %.0f mm (aspect %.2f)", W_mm, H_mm, asp))

# -----------------------------------------------------------------------------
# LaTeX caption (paste into the Data section). Adjust the basemap credit if you
# switch BASEMAP_PROVIDER (Esri tiles need an Esri/source credit instead).
#
# \begin{figure}[htbp]
#   \centering
#   \includegraphics[width=0.75\textwidth]{figs/fig1_metro_airquality_map.pdf}
#   \caption{Quito's Metro Line 1 (dark line) and its stations (small points),
#   with the air quality monitors used in the analysis. Monitors near the
#   corridor (orange) and the donor pool of distant monitors (blue) are labeled
#   with their straight-line distance to the nearest metro station.
#   The dashed line marks the equator (0$^\circ$ latitude).
#   Basemap: \textcopyright{} OpenStreetMap contributors, \textcopyright{} CARTO.}
#   \label{fig:map}
# \end{figure}
# -----------------------------------------------------------------------------
