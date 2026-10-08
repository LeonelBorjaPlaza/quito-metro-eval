# Item 5: pre-period descriptives, January 2021 to November 2023 only.
# Run from road_safety/ after 02_spatial.R: Rscript code/03_descriptives.R
# Reads crashes only through load_pre(). Tables to output/descriptives/*.csv, figures as PNG.
source("code/helpers.R")
out <- "output/descriptives"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

pre <- load_pre(CRASHES_SPATIAL)
bands <- c("0-500m", "500-1000m", "1-2km", "over2km")
stopifnot(all(pre$band %in% bands))
pre[, band := factor(band, levels = bands)]
pre[, `:=`(month = month_start(fecha), quarter = quarter_start(fecha),
           fatal = severity == "fatal", all_crashes = TRUE)]
months <- seq(PRE_START, month_start(PRE_END), by = "month")
stopifnot(length(months) == 35L)
# Opening-aligned quarters wholly inside the pre-period: March 2021 to November 2023.
quarters <- seq(as.Date("2021-03-01"), as.Date("2023-09-01"), by = "3 months")
stopifnot(length(quarters) == 11L)

outcomes <- c(crashes = "all_crashes", injury_or_fatal = "injury_or_fatal", fatal = "fatal",
              pedestrian = "pedestrian", motorcycle = "any_motorcycle", bus = "any_bus",
              bicycle = "any_bicycle")
count_by <- function(d, by) {
  d[, lapply(outcomes, function(e) sum(get(e))), by = by]
}

# 1. Monthly counts, citywide and by distance band (bands complete with zeros).
city <- merge(data.table(month = months), count_by(pre, "month"), by = "month", all.x = TRUE)
setnafill(city, fill = 0L, cols = names(outcomes))
save_csv(city, file.path(out, "monthly_citywide.csv"))
band_m <- merge(CJ(band = factor(bands, levels = bands), month = months),
                count_by(pre, c("band", "month")), by = c("band", "month"), all.x = TRUE)
setnafill(band_m, fill = 0L, cols = names(outcomes))
save_csv(band_m, file.path(out, "monthly_by_band.csv"))
areas <- rbindlist(lapply(c("catchment_500", "catchment_1km", "corridor_500", "corridor_1km", "beyond_2km_line"),
  function(a) {
    x <- merge(data.table(month = months), count_by(pre[get(a) == TRUE], "month"), by = "month", all.x = TRUE)
    setnafill(x, fill = 0L, cols = names(outcomes))
    x[, area := a][]
  }))
save_csv(areas, file.path(out, "monthly_by_treated_area.csv"))

# 2. Severity mix and involvement, by pre-period year (2023 is January to November).
pre[, pre_year := fifelse(year == 2023L, "2023 (Jan-Nov)", as.character(year))]
mix <- pre[, .(crashes = .N,
               damage_only = sum(severity == "damage_only"), injury = sum(severity == "injury"),
               fatal = sum(severity == "fatal"), deaths = sum(fallecidos, na.rm = TRUE),
               injured = sum(lesionados), pedestrian = sum(pedestrian),
               motorcycle = sum(any_motorcycle), bus = sum(any_bus), bicycle = sum(any_bicycle),
               scooter = sum(n_scooter > 0L)), by = pre_year]
mix <- rbind(mix, pre[, .(pre_year = "All pre-period", crashes = .N,
               damage_only = sum(severity == "damage_only"), injury = sum(severity == "injury"),
               fatal = sum(severity == "fatal"), deaths = sum(fallecidos, na.rm = TRUE),
               injured = sum(lesionados), pedestrian = sum(pedestrian),
               motorcycle = sum(any_motorcycle), bus = sum(any_bus), bicycle = sum(any_bicycle),
               scooter = sum(n_scooter > 0L))])
share_cols <- setdiff(names(mix), c("pre_year", "crashes", "deaths", "injured"))
mix[, paste0("share_", share_cols) := lapply(.SD, function(x) round(x / crashes, 4)), .SDcols = share_cols]
save_csv(mix, file.path(out, "severity_and_involvement_by_year.csv"))
save_csv(pre[, .(crashes = .N), by = .(tipologia)][order(-crashes)], file.path(out, "typology.csv"))
save_csv(pre[, .(crashes = .N, injury_or_fatal = sum(injury_or_fatal), pedestrian = sum(pedestrian)),
             by = band][order(band)][, share_injury_or_fatal := round(injury_or_fatal / crashes, 4)][
               , share_pedestrian := round(pedestrian / crashes, 4)][],
         file.path(out, "severity_by_band.csv"))

# 3. Hour of day and weekday.
hours <- merge(data.table(hour = 0:23), pre[, .(crashes = .N, injury_or_fatal = sum(injury_or_fatal),
                                                pedestrian = sum(pedestrian)), by = hour],
               by = "hour", all.x = TRUE)
setnafill(hours, fill = 0L, cols = c("crashes", "injury_or_fatal", "pedestrian"))
save_csv(hours, file.path(out, "hour_of_day.csv"))
wd <- pre[, .(crashes = .N, injury_or_fatal = sum(injury_or_fatal), pedestrian = sum(pedestrian)),
          by = weekday][order(weekday)]
wd[, weekday_name := c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")[weekday]]
save_csv(wd, file.path(out, "weekday.csv"))

# 4. Share of unit-periods with zero crashes, for each candidate unit.
# Cell universes: (i) cells with at least one pre-period crash anywhere in the district (this
# understates zeros); (ii) every resolution-8 cell whose centre lies within 2 km of the line.
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG, quiet = TRUE)), CRS_UTM))
buffer_wkt <- st_as_text(st_transform(st_buffer(line, 2500), 4326))
con <- connect_duckdb()
near_cells <- as.data.table(DBI::dbGetQuery(con, paste0(
  "SELECT h3_r8, h3_cell_to_lat(h3_r8) AS lat, h3_cell_to_lng(h3_r8) AS lon FROM (",
  "SELECT unnest(h3_polygon_wkt_to_cells_string('", buffer_wkt, "', 8)) AS h3_r8)")))
DBI::dbDisconnect(con, shutdown = TRUE)
centres <- st_transform(st_as_sf(near_cells, coords = c("lon", "lat"), crs = 4326), CRS_UTM)
near_cells[, dist_line_m := as.numeric(st_distance(centres, line))]
near_cells <- near_cells[dist_line_m <= 2000]

pre[, parroquia_urban := parroquia %in% pre[, .(u = mean(zona %in% "URBANA")), by = parroquia][u > 0.5, parroquia]]
unit_defs <- list(
  "H3 r8 cells with any pre crash" = list(d = pre, key = "h3_r8", universe = unique(pre$h3_r8)),
  "H3 r8 cells, centre within 2 km of line (all)" = list(d = pre, key = "h3_r8", universe = near_cells$h3_r8),
  "H3 r7 parents with any pre crash" = list(d = pre, key = "h3_r7", universe = unique(pre$h3_r7)),
  "Station catchments 500 m (nearest station)" = list(d = pre[catchment_500 == TRUE], key = "nearest_station",
                                                      universe = unique(pre$nearest_station)),
  "Station catchments 1 km (nearest station)" = list(d = pre[catchment_1km == TRUE], key = "nearest_station",
                                                     universe = unique(pre$nearest_station)),
  "Distance bands" = list(d = pre, key = "band", universe = bands),
  "Pooled catchment 500 m" = list(d = pre[catchment_500 == TRUE][, pooled_unit := "pooled"], key = "pooled_unit", universe = "pooled"),
  "Pooled catchment 1 km" = list(d = pre[catchment_1km == TRUE][, pooled_unit := "pooled"], key = "pooled_unit", universe = "pooled"),
  "Corridor 500 m of line" = list(d = pre[corridor_500 == TRUE][, pooled_unit := "pooled"], key = "pooled_unit", universe = "pooled"),
  "Parishes, urban" = list(d = pre[parroquia_urban == TRUE], key = "parroquia",
                           universe = unique(pre[parroquia_urban == TRUE, parroquia])),
  "Parishes, all" = list(d = pre, key = "parroquia", universe = unique(pre$parroquia)))
zero_rows <- list()
for (nm in names(unit_defs)) for (tu in c("month", "quarter")) for (oc in c("crashes", "injury_or_fatal", "pedestrian")) {
  def <- unit_defs[[nm]]
  periods <- if (tu == "month") months else quarters
  d <- def$d[get(tu) %in% periods & (if (oc == "crashes") TRUE else get(oc))]
  cnt <- d[, .(n = .N), by = c(def$key, tu)]
  setnames(cnt, c("unit", "period", "n"))
  grid <- merge(CJ(unit = def$universe, period = periods), cnt, by = c("unit", "period"), all.x = TRUE)
  grid[is.na(n), n := 0L]
  zero_rows[[length(zero_rows) + 1L]] <- data.table(
    unit_type = nm, time_unit = tu, outcome = oc, units = length(def$universe), periods = length(periods),
    mean_count = round(mean(grid$n), 3), median_count = median(grid$n),
    share_zero = round(mean(grid$n == 0L), 4),
    share_units_all_zero = round(mean(grid[, all(n == 0L), by = unit]$V1), 4))
}
zeros <- rbindlist(zero_rows)
save_csv(zeros, file.path(out, "zero_share_by_unit.csv"))

# Figures. Reference palette (dataviz skill): blue ordinal ramp for distance bands.
ink <- "#3d3d3a"; grid_col <- "#e8e7e1"
theme_rs <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.3),
        text = element_text(colour = ink), axis.text = element_text(colour = "#6b6a64"),
        plot.title.position = "plot", legend.position = "top",
        plot.background = element_rect(fill = "white", colour = NA))
covid <- annotate("rect", xmin = as.Date("2021-01-01"), xmax = as.Date("2021-12-31"), ymin = -Inf, ymax = Inf,
                  fill = "#f1f0ea")
covid_lab <- annotate("text", x = as.Date("2021-07-01"), y = Inf, vjust = 1.5, size = 3, colour = "#6b6a64",
                      label = "2021: COVID-19 recovery period")
save_png <- function(p, f, w = 8, h = 4.2) ggsave(file.path(out, f), p, width = w, height = h, dpi = 150, bg = "white")

long_city <- melt(city[, .(month, `All crashes` = crashes, `Injury or fatal` = injury_or_fatal, Pedestrian = pedestrian)],
                  id.vars = "month")
save_png(ggplot(long_city, aes(month, value, colour = variable)) + covid + covid_lab +
  geom_line(linewidth = 0.7) + geom_point(size = 1) +
  scale_colour_manual(values = c("#2a78d6", "#eb6834", "#1baf7a"), name = NULL) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Crashes per month, Quito district, January 2021 to November 2023",
       x = NULL, y = "Crashes per month", caption = "Source: AMT crash matrix (2026-09-23). Pre-opening months only.") +
  theme_rs, "monthly_citywide.png")
band_cols <- c("0-500m" = "#0d366b", "500-1000m" = "#1c5cab", "1-2km" = "#3987e5", "over2km" = "#86b6ef")
save_png(ggplot(band_m, aes(month, crashes, colour = band)) + covid + covid_lab +
  geom_line(linewidth = 0.7) +
  scale_colour_manual(values = band_cols, name = "Distance to nearest station") +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Crashes per month by distance to the nearest Line 1 station, pre-opening",
       x = NULL, y = "Crashes per month", caption = "Source: AMT crash matrix. Distances in UTM 17S.") +
  theme_rs, "monthly_by_band.png")
mix_long <- melt(mix[pre_year != "All pre-period", .(pre_year, `Damage only` = share_damage_only,
                                                     Injury = share_injury, Fatal = share_fatal)], id.vars = "pre_year")
save_png(ggplot(mix_long, aes(pre_year, value, fill = variable)) +
  geom_col(width = 0.6, colour = "white", linewidth = 0.5) +
  scale_fill_manual(values = c("#86b6ef", "#2a78d6", "#0d366b"), name = NULL) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Severity mix of recorded crashes, by year (pre-opening)", x = NULL, y = "Share of crashes") +
  theme_rs, "severity_by_year.png", w = 6)
save_png(ggplot(hours, aes(hour, crashes)) + geom_col(fill = "#2a78d6", width = 0.8) +
  scale_x_continuous(breaks = seq(0, 23, 3)) +
  labs(title = "Crashes by hour of day, pre-opening", x = "Hour of day", y = "Crashes") + theme_rs,
  "hour_of_day.png", w = 7)
save_png(ggplot(wd, aes(factor(weekday_name, levels = weekday_name), crashes)) + geom_col(fill = "#2a78d6", width = 0.7) +
  labs(title = "Crashes by weekday, pre-opening", x = NULL, y = "Crashes") + theme_rs, "weekday.png", w = 7)
zplot <- zeros[time_unit == "month"]
zplot[, unit_type := factor(unit_type, levels = rev(names(unit_defs)))]
save_png(ggplot(zplot, aes(share_zero, unit_type, colour = outcome)) +
  geom_point(size = 2.5) +
  scale_colour_manual(values = c(crashes = "#2a78d6", injury_or_fatal = "#eb6834", pedestrian = "#1baf7a"),
                      labels = c("All crashes", "Injury or fatal", "Pedestrian"), name = NULL) +
  scale_x_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(title = "Share of unit-months with zero crashes, pre-opening", x = "Share of unit-months with zero crashes", y = NULL) +
  theme_rs + theme(panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.3)),
  "zero_share_by_unit.png", w = 8, h = 4.8)
print(zeros[time_unit == "month" & outcome == "crashes"])
cat("Pre-period crashes:", nrow(pre), "in", length(months), "months.\n")
