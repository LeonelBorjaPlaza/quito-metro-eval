# Item D.4 and plan section 9a, guard 3: where the synthetic CENTER's donors are. For each pool, the full
# pre-period augsynth fit and the plain synthetic control: donors and synthetic weight by zonal
# administration and by distance from the line (under 2 km, 2 to 4 km, over 4 km), the weighted mean
# distance from the line, and a map of donor cells. Effective weights can be negative and sum to one;
# absolute-weight shares are given next to them.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
ft <- readRDS(file.path(AMEND2_DATA, "fits.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
SIRES <- st_crs(geog$sires)
POOLS <- c("primary_screened", "primary_unscreened", "low_exposure_screened", "low_exposure_unscreened")

w <- ft$weights[rule == "amended" & target == "CENTER" & fit == "full pre" & pool %in% POOLS]
w <- merge(w, geog$cell_attr, by = "grid_id")
w[, band := dist_band(km_to_line)]
w[, abs_share := abs(effective_weight) / sum(abs(effective_weight)), by = .(pool, estimator)]
summ <- function(by) w[, .(donors = .N, donors_weight_above_0.001 = sum(abs(effective_weight) > 0.001),
  synthetic_weight = sum(effective_weight), abs_weight_share = sum(abs_share)), by = c("pool", "estimator", by)][order(pool, estimator, -abs_weight_share)]
by_zonal <- summ("zonal_administration")
by_band <- summ("band")
mean_dist <- w[, .(weighted_mean_km_to_line = sum(effective_weight * km_to_line),
                   abs_weighted_mean_km_to_line = sum(abs_share * km_to_line),
                   pool_mean_km_to_line = mean(km_to_line), min_km_to_line = min(km_to_line)), by = .(pool, estimator)]
stopifnot(by_band[, abs(sum(synthetic_weight) - 1) < 1e-6, by = .(pool, estimator)]$V1)

fwrite(by_zonal, file.path(AMEND2_OUT, "donor_geography_by_zonal_administration.csv"))
fwrite(by_band, file.path(AMEND2_OUT, "donor_geography_by_distance_band.csv"))
fwrite(mean_dist, file.path(AMEND2_OUT, "donor_geography_mean_distance.csv"))

hex <- st_transform(st_as_sf(fread(grid_path, colClasses = "character"), wkt = "h3_geometry_r8", crs = 4326), SIRES)
mw <- merge(hex, w[estimator == "ascm" & pool %in% c("primary_screened", "primary_unscreened"),
                   .(grid_id, pool, effective_weight)], by = "grid_id")
line <- st_transform(st_zm(st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)), SIRES)
ctr <- st_transform(st_sfc(geog$polygons$CENTER, crs = 4326), SIRES)
lim <- max(abs(mw$effective_weight))
p <- ggplot() + geom_sf(data = hex, fill = NA, colour = "grey92", linewidth = 0.05) +
  geom_sf(data = mw, aes(fill = effective_weight), colour = "grey70", linewidth = 0.05) +
  geom_sf(data = line, colour = "black", linewidth = 0.5) + geom_sf(data = ctr, fill = NA, colour = "#b2182b", linewidth = 0.6) +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b", limits = c(-lim, lim), name = "Effective\nweight") +
  facet_wrap(~pool) + coord_sf(xlim = st_bbox(mw)[c(1, 3)], ylim = st_bbox(mw)[c(2, 4)], crs = SIRES, datum = NA) +
  labs(title = "Donor cells of the synthetic CENTER, full pre-period augsynth fit (amended flag rule)",
       subtitle = "Every pool member is drawn; colour is its effective weight (negative in blue). Black: Line 1. Red outline: CENTER polygon.",
       caption = "Polygon: Municipio del DMQ, GeoQuito. H3 resolution 8.", x = NULL, y = NULL) +
  theme_minimal(base_size = 9)
ggsave(file.path(AMEND2_OUT, "map_donors.png"), p, width = 11, height = 7, dpi = 150, bg = "white")
print(by_band[estimator == "ascm"]); print(mean_dist); print(by_zonal[estimator == "ascm" & pool == "primary_screened"])
