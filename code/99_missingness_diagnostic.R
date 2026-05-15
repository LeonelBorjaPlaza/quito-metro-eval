#=========================================================
#  99_missingness_diagnostic.R
#  Per-pollutant CSV of station-week raw missingness vs
#  inclusion in the balanced analysis panel. For conversation
#  with the data manager about possible recovery (PM2.5 first).
#  Run after 01 and 02.
#=========================================================

library(dplyr)
library(readr)
library(lubridate)
library(tidyr)
library(stringr)

root_dir <- here::here()
proc_dir <- file.path(root_dir, "data", "processed")
out_dir  <- file.path(root_dir, "output", "diagnostics")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

stations_keep <- c("belisario", "carapungo", "centro", "cotocollao",
                   "guamani", "loschillos", "sanantonio", "tumbaco")

cat("Loading hourly panel...\n")
hourly <- read_csv(file.path(proc_dir, "hourly_panel.csv"),
                   show_col_types = FALSE)

diagnose_pollutant <- function(pol, panel_file) {
  cat(sprintf("\n=== %s ===\n", toupper(pol)))
  
  var_cols <- grep(paste0("_", pol, "$"), names(hourly), value = TRUE)
  
  # Same sample restrictions as the analysis pipeline:
  # peak hours (7-9, 17-19), weekdays (Mon-Fri), from Dec 2022
  peak <- hourly %>%
    filter(hour_of_day %in% c(7, 8, 9, 17, 18, 19),
           day_of_week %in% 1:5,
           date >= as.Date("2022-12-01"))
  
  peak_long <- peak %>%
    select(date, hour_of_day, all_of(var_cols)) %>%
    pivot_longer(all_of(var_cols),
                 names_to = "stn_col", values_to = "value") %>%
    mutate(estacion = sub(paste0("_", pol, "$"), "", stn_col)) %>%
    filter(estacion %in% stations_keep)
  
  weekly_raw <- peak_long %>%
    mutate(week_date = floor_date(date, "week", week_start = 1)) %>%
    group_by(estacion, week_date) %>%
    summarise(
      raw_n_obs   = sum(!is.na(value)),
      raw_n_total = n(),
      .groups     = "drop"
    ) %>%
    mutate(
      raw_pct_obs = raw_n_obs / raw_n_total,
      raw_missing = raw_n_obs == 0,
      week_label  = paste0(year(week_date), "w",
                           sprintf("%02d", isoweek(week_date))),
      pollutant   = pol
    )
  
  if (file.exists(panel_file)) {
    bal <- read_csv(panel_file, show_col_types = FALSE)
    bal_weeks <- bal %>%
      distinct(estacion, week_date) %>%
      mutate(in_balanced_panel = TRUE)
  } else {
    bal_weeks <- tibble(estacion = character(), week_date = as.Date(character()),
                        in_balanced_panel = logical())
  }
  
  result <- weekly_raw %>%
    left_join(bal_weeks, by = c("estacion", "week_date")) %>%
    mutate(in_balanced_panel = ifelse(is.na(in_balanced_panel), FALSE,
                                      in_balanced_panel)) %>%
    arrange(estacion, week_date) %>%
    select(pollutant, estacion, week_date, week_label,
           raw_n_obs, raw_n_total, raw_pct_obs, raw_missing,
           in_balanced_panel)
  
  out_file <- file.path(out_dir, sprintf("missingness_%s.csv", toupper(pol)))
  write_csv(result, out_file)
  cat(sprintf("Wrote: %s (%d rows)\n", basename(out_file), nrow(result)))
  
  summary_by_station <- result %>%
    group_by(estacion) %>%
    summarise(
      n_weeks_total        = n(),
      n_raw_missing        = sum(raw_missing),
      raw_missing_pct      = round(100 * n_raw_missing / n_weeks_total, 1),
      n_dropped_from_panel = sum(!in_balanced_panel),
      dropped_pct          = round(100 * n_dropped_from_panel / n_weeks_total, 1),
      .groups = "drop"
    )
  
  cat("\nSummary by station:\n")
  print(summary_by_station)
  
  invisible(result)
}

diagnose_pollutant("pm25", file.path(proc_dir, "pm25_completepanel_peakweekly.csv"))
diagnose_pollutant("co",   file.path(proc_dir, "CO_completepanel_peakweekly.csv"))
diagnose_pollutant("no2",  file.path(proc_dir, "NO2_completepanel_peakweekly.csv"))
diagnose_pollutant("so2",  file.path(proc_dir, "SO2_completepanel_peakweekly.csv"))

cat(sprintf("\n=== Done. Diagnostics in: %s ===\n", out_dir))