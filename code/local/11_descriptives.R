#=========================================================
#  11_descriptives.R
#  Paper-ready descriptive outputs:
#    - Summary statistics (station × pollutant × pre/post)
#    - Sample construction flow
#    - Treatment timeline
#    - Time series figure (4-panel)
#=========================================================

library(dplyr)
library(readr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(stringr)

# ---- Paths ----
root_dir <- here::here()
proc_dir <- file.path(root_dir, "data", "processed")
out_tables_dir  <- file.path(root_dir, "output", "tables")
out_figures_dir <- file.path(root_dir, "output", "figures")
dir.create(out_tables_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(out_figures_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Constants ----
stations_keep <- c("belisario", "carapungo", "centro", "cotocollao",
                   "guamani", "loschillos", "sanantonio", "tumbaco")

station_distances <- tibble(
  estacion = stations_keep,
  dist_corridor_km = c(0.768, 7.637, 0.610, 5.212,
                       4.035, 8.618, 9.558, 16.650)
)

TREATMENT_DATE <- as.Date("2023-12-01")
BLACKOUT_START <- as.Date("2024-09-18")
BLACKOUT_END   <- as.Date("2024-12-20")

pollutants <- c("pm25", "co", "no2", "so2")
pollutant_labels <- c(pm25 = "PM[2.5]~~(mu*g/m^3)",
                      co   = "CO~~(mg/m^3)",
                      no2  = "NO[2]~~(mu*g/m^3)",
                      so2  = "SO[2]~~(mu*g/m^3)")

# ---- Load data ----
cat("Loading panels...\n")
hourly <- read_csv(file.path(proc_dir, "hourly_panel.csv"), show_col_types = FALSE)

panels <- list(
  pm25 = read_csv(file.path(proc_dir, "pm25_completepanel_peakweekly.csv"),
                  show_col_types = FALSE),
  co   = read_csv(file.path(proc_dir, "CO_completepanel_peakweekly.csv"),
                  show_col_types = FALSE),
  no2  = read_csv(file.path(proc_dir, "NO2_completepanel_peakweekly.csv"),
                  show_col_types = FALSE),
  so2  = read_csv(file.path(proc_dir, "SO2_completepanel_peakweekly.csv"),
                  show_col_types = FALSE)
)


#---------------------------------------------------------
# 1. Summary stats: station x pollutant x pre/post
#---------------------------------------------------------
cat("\nBuilding summary statistics table...\n")

summary_stats <- bind_rows(lapply(pollutants, function(pol) {
  panel <- panels[[pol]]
  outcome_col <- paste0(pol, "_imp")
  raw_col     <- pol
  
  panel %>%
    mutate(period = ifelse(week_date < TREATMENT_DATE, "pre", "post")) %>%
    group_by(estacion, period) %>%
    summarise(
      n_weeks      = n(),
      n_obs_raw    = sum(!is.na(.data[[raw_col]])),
      pct_imputed  = round(100 * (n_weeks - n_obs_raw) / n_weeks, 1),
      mean_level   = round(mean(.data[[outcome_col]], na.rm = TRUE), 2),
      sd_level     = round(sd(.data[[outcome_col]], na.rm = TRUE), 2),
      median_level = round(median(.data[[outcome_col]], na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    mutate(pollutant = pol)
})) %>%
  left_join(station_distances, by = "estacion") %>%
  select(pollutant, estacion, dist_corridor_km, period,
         n_weeks, n_obs_raw, pct_imputed,
         mean_level, sd_level, median_level) %>%
  arrange(pollutant, estacion, desc(period))   # pre first, then post

write_csv(summary_stats,
          file.path(out_tables_dir, "descriptives_summary_stats.csv"))
cat(sprintf("  Wrote: descriptives_summary_stats.csv (%d rows)\n",
            nrow(summary_stats)))


#---------------------------------------------------------
# 2. Sample construction
#---------------------------------------------------------
cat("\nBuilding sample construction table...\n")

compute_construction <- function(pol) {
  cols <- grep(paste0("_", pol, "$"), names(hourly), value = TRUE)
  stns_in_data <- sub(paste0("_", pol, "$"), "", cols)
  stns_used <- intersect(stns_in_data, stations_keep)
  
  hourly_long <- hourly %>%
    filter(date >= as.Date("2022-12-01")) %>%
    select(date, hour_of_day, day_of_week, all_of(cols)) %>%
    pivot_longer(all_of(cols), names_to = "stn_col", values_to = "value") %>%
    mutate(estacion = sub(paste0("_", pol, "$"), "", stn_col)) %>%
    filter(estacion %in% stns_used)
  
  raw_obs     <- sum(!is.na(hourly_long$value))
  peak_obs    <- sum(!is.na(hourly_long$value[
    hourly_long$hour_of_day %in% c(7,8,9,17,18,19)]))
  weekday_obs <- sum(!is.na(hourly_long$value[
    hourly_long$hour_of_day %in% c(7,8,9,17,18,19) &
      hourly_long$day_of_week %in% 1:5]))
  
  panel <- panels[[pol]]
  outcome_col <- paste0(pol, "_imp")
  raw_col     <- pol
  balanced_obs      <- nrow(panel)
  balanced_stations <- n_distinct(panel$estacion)
  balanced_weeks    <- n_distinct(panel$week_id)
  imputed_obs       <- sum(is.na(panel[[raw_col]]) & !is.na(panel[[outcome_col]]))
  
  tibble(
    pollutant              = pol,
    n_stations             = length(stns_used),
    raw_hourly_obs         = raw_obs,
    after_peak_hour_filter = peak_obs,
    after_weekday_filter   = weekday_obs,
    balanced_obs           = balanced_obs,
    balanced_stations      = balanced_stations,
    balanced_weeks         = balanced_weeks,
    imputed_obs            = imputed_obs,
    pct_imputed            = round(100 * imputed_obs / balanced_obs, 1)
  )
}

sample_construction <- bind_rows(lapply(pollutants, compute_construction))

write_csv(sample_construction,
          file.path(out_tables_dir, "descriptives_sample_construction.csv"))
cat(sprintf("  Wrote: descriptives_sample_construction.csv\n"))
print(sample_construction)


#---------------------------------------------------------
# 3. Treatment timeline
#---------------------------------------------------------
cat("\nBuilding treatment timeline table...\n")

data_end_max <- max(do.call(c, lapply(panels, function(p) max(p$week_date))))

data_start_min <- min(do.call(c, lapply(panels, function(p) min(p$week_date))))


periods <- list(
  list(name = "Pre-treatment",
       start = data_start_min, end = TREATMENT_DATE - 1),
  list(name = "Period 1 (post, pre-blackout)",
       start = TREATMENT_DATE, end = BLACKOUT_START - 1),
  list(name = "Phase 3 blackout (excluded in SDID donut)",
       start = BLACKOUT_START, end = BLACKOUT_END),
  list(name = "Period 2 (post, post-blackout)",
       start = BLACKOUT_END + 1, end = data_end_max)
)

timeline <- bind_rows(lapply(periods, function(p) {
  weeks_per_pol <- sapply(pollutants, function(pol) {
    panel <- panels[[pol]]
    n_distinct(panel$week_date[panel$week_date >= p$start &
                                 panel$week_date <= p$end])
  })
  
  tibble(
    period       = p$name,
    start_date   = p$start,
    end_date     = p$end,
    n_weeks_pm25 = weeks_per_pol["pm25"],
    n_weeks_co   = weeks_per_pol["co"],
    n_weeks_no2  = weeks_per_pol["no2"],
    n_weeks_so2  = weeks_per_pol["so2"]
  )
}))

write_csv(timeline,
          file.path(out_tables_dir, "descriptives_treatment_timeline.csv"))
cat(sprintf("  Wrote: descriptives_treatment_timeline.csv\n"))
print(timeline)


#---------------------------------------------------------
# 4. Time series figure (4-panel)
#---------------------------------------------------------
cat("\nBuilding time series figure...\n")

ts_data <- bind_rows(lapply(pollutants, function(pol) {
  panel <- panels[[pol]]
  outcome_col <- paste0(pol, "_imp")
  panel %>%
    select(estacion, week_date, all_of(outcome_col)) %>%
    rename(value = !!outcome_col) %>%
    mutate(pollutant = pol)
}))

# Save underlying time series data
write_csv(ts_data,
          file.path(out_tables_dir, "descriptives_time_series_data.csv"))
cat(sprintf("  Wrote: descriptives_time_series_data.csv (%d rows)\n",
            nrow(ts_data)))

ts_data <- ts_data %>%
  mutate(
    pollutant_label = factor(pollutant,
                             levels = c("pm25", "co", "no2", "so2"),
                             labels = pollutant_labels[c("pm25","co","no2","so2")]),
    station_group = case_when(
      estacion == "centro"    ~ "Centro (treated)",
      estacion == "belisario" ~ "Belisario (key donor)",
      TRUE                    ~ "Other stations"
    ),
    station_group = factor(station_group,
                           levels = c("Centro (treated)",
                                      "Belisario (key donor)",
                                      "Other stations"))
  )

p_ts <- ggplot(ts_data, aes(x = week_date, y = value, group = estacion,
                            color = station_group, alpha = station_group,
                            linewidth = station_group)) +
  annotate("rect",
           xmin = BLACKOUT_START, xmax = BLACKOUT_END,
           ymin = -Inf, ymax = Inf,
           alpha = 0.15, fill = "gray60") +
  geom_vline(xintercept = TREATMENT_DATE, linetype = "dashed",
             color = "gray30", linewidth = 0.5) +
  geom_line() +
  scale_color_manual(values = c("Centro (treated)"      = "#E41A1C",
                                "Belisario (key donor)" = "#377EB8",
                                "Other stations"        = "gray50")) +
  scale_alpha_manual(values = c("Centro (treated)"      = 1.0,
                                "Belisario (key donor)" = 0.9,
                                "Other stations"        = 0.45)) +
  scale_linewidth_manual(values = c("Centro (treated)"      = 0.85,
                                    "Belisario (key donor)" = 0.75,
                                    "Other stations"        = 0.4)) +
  facet_wrap(~ pollutant_label, scales = "free_y",
             labeller = label_parsed, ncol = 2) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL,
       y = "Weekly mean of peak-hour weekday levels",
       color = NULL, alpha = NULL, linewidth = NULL,
       caption = paste("Vertical dashed line: Metro Quito opening",
                       "(Dec 1, 2023). Shaded region: Phase 3 power outages",
                       "(Sep 18 - Dec 20, 2024).")) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1),
        strip.text = element_text(size = 12, face = "bold"),
        plot.caption = element_text(hjust = 0, size = 9, color = "gray30"))

ggsave(file.path(out_figures_dir, "descriptives_time_series.png"),
       plot = p_ts, width = 11, height = 7.5, dpi = 200)
ggsave(file.path(out_figures_dir, "descriptives_time_series.pdf"),
       plot = p_ts, width = 11, height = 7.5)
cat(sprintf("  Wrote: descriptives_time_series.png and .pdf\n"))


cat("\n=== Descriptives complete ===\n")
cat(sprintf("Tables in: %s\n", out_tables_dir))
cat(sprintf("Figures in: %s\n", out_figures_dir))