#=========================================================
#  02_build_weekly_panels.R
#  Build balanced weekly station panels for PM2.5 and CO
#
#  Input:  data/processed/hourly_panel.csv
#  Output: data/processed/pm25_completepanel_peakweekly.csv
#          data/processed/CO_completepanel_peakweekly.csv
#
#  Pipeline per pollutant:
#    1. Filter to peak hours (7-9am, 5-7pm weekdays)
#    2. Drop event days (power outages, wildfires)
#    3. Collapse to station-day means
#    4. Reshape to long format (station as unit)
#    5. Keep 8 analysis stations, drop pre-Dec 2022
#    6. Build weekly covariate panel (with wind direction u/v decomposition)
#    7. Interpolate short gaps (1-2 weeks) in covariates
#    8. Collapse pollutant to weekly means
#    9. Interpolate short gaps (1-2 weeks) in ln(pollutant)
#   10. Regression-impute remaining gaps (San Antonio)
#   11. Balance panel: keep only weeks where all stations report
#   12. Add treatment indicators and week labels
#=========================================================

library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(stringr)

# ---- Paths ----
root_dir <- here::here()
proc_dir <- file.path(root_dir, "data", "processed")


#=========================================================
#  Load hourly panel
#=========================================================
cat("Loading hourly panel...\n")
panel <- read_csv(file.path(proc_dir, "hourly_panel.csv"),
                  show_col_types = FALSE)

# ---- The 8 analysis stations ----
stations_keep <- c("belisario", "carapungo", "centro", "cotocollao",
                   "guamani", "loschillos", "sanantonio", "tumbaco")

# Distance from each station to the metro corridor (km)
station_distances <- tibble(
  estacion = stations_keep,
  dist_station = c(0.768, 7.637, 0.610, 5.212, 4.035, 8.618, 9.558, 16.650)
)


#=========================================================
#  STEP 1: Filter to peak hours
#=========================================================
# Peak hours: 7-9am (hours 7,8,9) and 5-7pm (hours 17,18,19)
# Matches Stata: keep if inlist(hour_of_day, 7, 8, 9, 17, 18, 19)

peak <- panel %>%
  filter(hour_of_day %in% c(7, 8, 9, 17, 18, 19),
         day_of_week %in% 1:5)

cat(sprintf("After peak-hour + weekday filter: %d rows (from %d)\n",
            nrow(peak), nrow(panel)))

#=========================================================
#  STEP 2: Reshape from wide to long (station as unit)
#=========================================================
# Each variable has columns like belisario_pm25, centro_pm25, etc.
# Reshape so each row is one station-hour observation.

# Identify all variable suffixes
var_suffixes <- c("pm25", "co", "no2", "so2",
                  "tmp", "hum", "vel", "dir", "llu", "rs", "pre")

# Build the long panel
peak_long <- peak %>%
  select(date, hour_of_day, year, month, day_of_week, day_of_month,
         poweroutage, wildfire, holiday,
         any_of(paste0(rep(stations_keep, each = length(var_suffixes)),
                       "_", var_suffixes))) %>%
  pivot_longer(
    cols = -c(date, hour_of_day, year, month, day_of_week, day_of_month,
              poweroutage, wildfire, holiday),
    names_to = c("estacion", ".value"),
    names_pattern = "^(.+)_([^_]+)$"
  )

cat(sprintf("Long panel: %d rows, %d columns\n", nrow(peak_long), ncol(peak_long)))


#=========================================================
#  STEP 3: Drop event days and early data
#=========================================================
peak_long <- peak_long %>%
  filter(date >= as.Date("2022-12-01"))

cat(sprintf("After dropping events and pre-Dec 2022: %d rows\n", nrow(peak_long)))


#=========================================================
#  STEP 4: Collapse to station-day means (over peak hours)
#=========================================================
daily <- peak_long %>%
  group_by(estacion, date) %>%
  summarise(
    across(c(pm25, co, no2, so2, tmp, hum, vel, dir, llu, rs, pre),
           ~ mean(.x, na.rm = TRUE)),
    across(c(holiday, wildfire, poweroutage),
           ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # NaN from all-NA groups -> NA
  mutate(across(c(pm25, co, no2, so2, tmp, hum, vel, dir, llu, rs, pre),
                ~ ifelse(is.nan(.x), NA, .x)))

cat(sprintf("Daily panel: %d rows\n", nrow(daily)))


#=========================================================
#  STEP 5: Add treatment and time variables
#=========================================================
daily <- daily %>%
  mutate(
    treated = as.integer(estacion == "centro"),
    post    = as.integer(date >= as.Date("2023-12-01")),
    year    = year(date),
    month   = month(date)
  ) %>%
  left_join(station_distances, by = "estacion") %>%
  mutate(station_id = as.integer(factor(estacion, levels = stations_keep)))


#=========================================================
#  STEP 6: Build weekly covariate panel
#  (separate from pollutant to allow different imputation)
#=========================================================

# ---- Wind direction: decompose to u/v before averaging ----
daily <- daily %>%
  mutate(
    rad_dir = dir * pi / 180,
    u_comp  = sin(rad_dir),
    v_comp  = cos(rad_dir)
  )

# ISO week variable
daily$week_iso <- as.integer(floor_date(daily$date, "week", week_start = 1))
# Use Monday-based weeks (matching Stata's wofd default)
# Convert to a simple integer for panel operations
daily <- daily %>%
  mutate(week_date = floor_date(date, "week", week_start = 1))


# ---- Collapse covariates to weekly means ----
covars_weekly <- daily %>%
  group_by(station_id, estacion, week_date) %>%
  summarise(
    tmp = mean(tmp, na.rm = TRUE),
    hum = mean(hum, na.rm = TRUE),
    vel = mean(vel, na.rm = TRUE),
    llu = mean(llu, na.rm = TRUE),
    rs  = mean(rs,  na.rm = TRUE),
    pre = mean(pre, na.rm = TRUE),
    u_comp = mean(u_comp, na.rm = TRUE),
    v_comp = mean(v_comp, na.rm = TRUE),
    poweroutage = mean(poweroutage, na.rm = TRUE),
    wildfire    = mean(wildfire, na.rm = TRUE),
    holiday     = mean(holiday, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    across(c(tmp, hum, vel, llu, rs, pre, u_comp, v_comp),
           ~ ifelse(is.nan(.x), NA, .x))
  )

# Reconstruct mean wind direction from u/v components
covars_weekly <- covars_weekly %>%
  mutate(
    dir = atan2(u_comp, v_comp) * 180 / pi,
    dir = ifelse(dir < 0, dir + 360, dir)
  ) %>%
  select(-u_comp, -v_comp)


#=========================================================
#  STEP 7: Interpolate short covariate gaps (1-2 weeks)
#=========================================================

interpolate_short_gaps <- function(df, var, max_gap = 2) {
  # Identify contiguous missing runs per station
  df <- df %>%
    arrange(station_id, week_date) %>%
    group_by(station_id) %>%
    mutate(
      is_miss   = is.na(.data[[var]]),
      gap_start = is_miss & !lag(is_miss, default = FALSE),
      gap_id    = cumsum(gap_start)
    ) %>%
    group_by(station_id, gap_id) %>%
    mutate(
      gap_len = ifelse(is_miss, cumsum(is_miss), 0),
      max_gap_len = ifelse(any(is_miss), max(gap_len), 0)
    ) %>%
    ungroup() %>%
    mutate(
      short_gap = is_miss & max_gap_len <= max_gap & max_gap_len > 0
    )

  # Linear interpolation within each station
  df <- df %>%
    group_by(station_id) %>%
    mutate(
      interp_val = approx(as.numeric(week_date), .data[[var]],
                          xout = as.numeric(week_date), rule = 1)$y
    ) %>%
    ungroup()

  # Fill only short gaps
  imp_var <- paste0(var, "_imp")
  df[[imp_var]] <- ifelse(df$short_gap, df$interp_val, df[[var]])

  # Clean up temp columns
  df <- df %>% select(-is_miss, -gap_start, -gap_id, -gap_len,
                      -max_gap_len, -short_gap, -interp_val)
  return(df)
}

# Interpolate each covariate
covar_names <- c("tmp", "hum", "vel", "dir", "llu", "rs", "pre")
for (v in covar_names) {
  cat(sprintf("Interpolating short gaps in %s...\n", v))
  covars_weekly <- interpolate_short_gaps(covars_weekly, v, max_gap = 2)
}

# Diagnostic: missingness after interpolation
cat("\nCovariate missingness after interpolation:\n")
for (v in covar_names) {
  imp_col <- paste0(v, "_imp")
  n_miss <- sum(is.na(covars_weekly[[imp_col]]))
  cat(sprintf("  %s_imp: %d missing (%.1f%%)\n", v, n_miss,
              100 * n_miss / nrow(covars_weekly)))
}


#=========================================================
#  STEP 8-12: Build complete weekly panel per pollutant
#=========================================================

build_weekly_panel <- function(daily_data, covars, pollutant,
                               drop_sanantonio = FALSE) {

  pol <- pollutant  # "pm25" or "co"
  cat(sprintf("\n===== Building weekly panel for %s =====\n", toupper(pol)))

  # ---- Which stations to use ----
  if (drop_sanantonio) {
    stns <- setdiff(stations_keep, "sanantonio")
    cat("  Dropping San Antonio\n")
  } else {
    stns <- stations_keep
  }

  # ---- Collapse pollutant to weekly ----
  pol_weekly <- daily_data %>%
    filter(estacion %in% stns) %>%
    group_by(station_id, estacion, week_date) %>%
    summarise(
      !!pol := mean(.data[[pol]], na.rm = TRUE),
      treated = first(treated),
      post    = max(post),
      poweroutage = mean(poweroutage, na.rm = TRUE),
      wildfire    = mean(wildfire, na.rm = TRUE),
      holiday     = mean(holiday, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(!!pol := ifelse(is.nan(.data[[pol]]), NA, .data[[pol]]))

  # ---- Missingness diagnostics (before interpolation) ----
  cat("\nMissingness by station (before interpolation):\n")
  miss_diag <- pol_weekly %>%
    group_by(station_id, estacion) %>%
    summarise(
      n_total = n(),
      n_miss  = sum(is.na(.data[[pol]])),
      pct_miss = round(100 * n_miss / n_total, 1),
      .groups = "drop"
    )
  print(miss_diag)

  # ---- Interpolate short gaps (1-2 weeks) in log space ----
  ln_pol <- paste0("ln_", pol)
  pol_weekly[[ln_pol]] <- log(pol_weekly[[pol]])

  pol_weekly <- interpolate_short_gaps(pol_weekly, ln_pol, max_gap = 2)

  # Back-transform: imputed values in levels
  pol_imp <- paste0(pol, "_imp")
  ln_imp  <- paste0(ln_pol, "_imp")
  pol_weekly[[pol_imp]] <- exp(pol_weekly[[ln_imp]])
  # For non-imputed rows, use original value
  pol_weekly[[pol_imp]] <- ifelse(is.na(pol_weekly[[pol_imp]]),
                                  pol_weekly[[pol]],
                                  pol_weekly[[pol_imp]])
  # If original was not NA, keep original
  pol_weekly[[pol_imp]] <- ifelse(!is.na(pol_weekly[[pol]]),
                                  pol_weekly[[pol]],
                                  pol_weekly[[pol_imp]])

  # ---- Missingness diagnostics (after short-gap interpolation) ----
  cat("\nMissingness by station (after short-gap interpolation):\n")
  miss_diag2 <- pol_weekly %>%
    group_by(station_id, estacion) %>%
    summarise(
      n_miss_imp = sum(is.na(.data[[pol_imp]])),
      .groups = "drop"
    )
  print(miss_diag2)


  # ---- Regression imputation for San Antonio (if kept) ----
  if (!drop_sanantonio) {
    sa_miss <- sum(is.na(pol_weekly[[pol_imp]][pol_weekly$estacion == "sanantonio"]))
    if (sa_miss > 0) {
      cat(sprintf("\nRegression-imputing %d missing weeks for San Antonio\n", sa_miss))

      # Merge covariates
      pol_weekly <- pol_weekly %>%
        left_join(covars %>% select(station_id, week_date,
                                    tmp_imp, hum_imp, vel_imp, dir_imp,
                                    llu_imp, rs_imp, pre_imp),
                  by = c("station_id", "week_date"))

      # Reshape wide for regression: each station's pollutant as a column
      wide <- pol_weekly %>%
        select(week_date, estacion, all_of(pol_imp)) %>%
        pivot_wider(names_from = estacion, values_from = all_of(pol_imp),
                    names_prefix = paste0(pol_imp, "_"))

      # Add San Antonio's own weather covariates as regression predictors.
      # (Prior versions used Guamani's weather as a workaround; San Antonio
      # has complete weather coverage on the analysis window, so using its
      # own is both more accurate and methodologically cleaner.)
      sa_covars <- covars %>%
        filter(estacion == "sanantonio") %>%
        select(week_date, tmp_imp, hum_imp, vel_imp, dir_imp,
               llu_imp, rs_imp, pre_imp)
      wide <- wide %>% left_join(sa_covars, by = "week_date")

      # Regression: predict San Antonio from other control stations + weather
      # Exclude Centro and Belisario (potentially treated)
      sa_col <- paste0(pol_imp, "_sanantonio")
      pred_cols <- c(
        paste0(pol_imp, "_", c("carapungo", "cotocollao", "guamani",
                                "loschillos", "tumbaco")),
        "tmp_imp", "hum_imp", "vel_imp", "dir_imp",
        "llu_imp", "rs_imp", "pre_imp"
      )

      # Check which predictor columns exist
      pred_cols <- intersect(pred_cols, names(wide))

      formula_str <- paste(sa_col, "~", paste(pred_cols, collapse = " + "))
      reg_sa <- lm(as.formula(formula_str), data = wide, na.action = na.exclude)

      # Predict and fill
      wide$sa_hat <- predict(reg_sa, newdata = wide)
      wide[[sa_col]] <- ifelse(is.na(wide[[sa_col]]), wide$sa_hat, wide[[sa_col]])
      wide$sa_hat <- NULL

      # Reshape back to long
      pol_wide_cols <- grep(paste0("^", pol_imp, "_"), names(wide), value = TRUE)
      pol_weekly_new <- wide %>%
        select(week_date, all_of(pol_wide_cols)) %>%
        pivot_longer(cols = all_of(pol_wide_cols),
                     names_to = "estacion",
                     values_to = paste0(pol_imp, "_new"),
                     names_prefix = paste0(pol_imp, "_"))

      # Update pol_weekly with imputed values
      pol_weekly <- pol_weekly %>%
        left_join(pol_weekly_new, by = c("week_date", "estacion")) %>%
        mutate(!!pol_imp := coalesce(.data[[paste0(pol_imp, "_new")]],
                                     .data[[pol_imp]])) %>%
        select(-all_of(paste0(pol_imp, "_new")),
               -any_of(c("tmp_imp", "hum_imp", "vel_imp", "dir_imp",
                          "llu_imp", "rs_imp", "pre_imp")))
    }
  }


  # ---- Balance panel: keep only weeks where ALL stations report ----
  n_stations <- length(stns)
  balanced <- pol_weekly %>%
    group_by(week_date) %>%
    mutate(n_reporting = sum(!is.na(.data[[pol_imp]]))) %>%
    ungroup() %>%
    filter(n_reporting == n_stations) %>%
    select(-n_reporting)

  cat(sprintf("\nBalanced panel: %d obs (%d stations x %d weeks)\n",
              nrow(balanced), n_stations, nrow(balanced) / n_stations))


  # ---- Merge imputed covariates ----
  balanced <- balanced %>%
    left_join(covars %>% select(station_id, week_date,
                                tmp_imp, hum_imp, vel_imp, dir_imp,
                                llu_imp, rs_imp, pre_imp),
              by = c("station_id", "week_date"))


  # ---- Build gap-free week_id and week_label ----
  week_map <- balanced %>%
    distinct(week_date) %>%
    arrange(week_date) %>%
    mutate(
      week_id    = row_number(),
      year       = isoyear(week_date),
      weeknum    = isoweek(week_date),
      week_label = paste0(year, "w", sprintf("%02d", weeknum))
    )

  balanced <- balanced %>%
    left_join(week_map, by = "week_date")


  # ---- Reconstruct treatment flags ----
  # Treatment week: 2023w48 -- ISO week containing Dec 1, 2023 (Fri)
  t_int <- week_map$week_id[week_map$week_label == "2023w48"]
  if (length(t_int) == 0) {
    # Find closest week
    t_int <- week_map$week_id[week_map$week_date ==
                               floor_date(as.Date("2023-12-01"), "week", week_start = 1)]
  }
  t_int <- t_int[1]

  balanced <- balanced %>%
    mutate(
      post_period     = as.integer(week_id >= t_int),
      pre_period      = as.integer(week_id < t_int),
      treated         = as.integer(post_period == 1 &
                                     estacion %in% c("centro", "belisario")),
      treated_centro  = as.integer(post_period == 1 & estacion == "centro")
    )

  cat(sprintf("Treatment week (t_int): %d (%s)\n", t_int,
              week_map$week_label[week_map$week_id == t_int]))
  cat(sprintf("Pre-treatment weeks: %d, Post-treatment weeks: %d\n",
              sum(week_map$week_id < t_int), sum(week_map$week_id >= t_int)))

  return(balanced)
}


#=========================================================
#  Build PM2.5 panel (all 8 stations, San Antonio imputed)
#=========================================================
pm25_panel <- build_weekly_panel(daily, covars_weekly, "pm25",
                                 drop_sanantonio = FALSE)

write_csv(pm25_panel, file.path(proc_dir, "pm25_completepanel_peakweekly.csv"))
cat(sprintf("Saved: %s\n", file.path(proc_dir, "pm25_completepanel_peakweekly.csv")))


#=========================================================
#  Build CO panel (7 stations, San Antonio dropped)
#=========================================================
# San Antonio has no CO data -- matches Stata code: drop if station_id == 7
co_panel <- build_weekly_panel(daily, covars_weekly, "co",
                                drop_sanantonio = TRUE)

write_csv(co_panel, file.path(proc_dir, "CO_completepanel_peakweekly.csv"))
cat(sprintf("Saved: %s\n", file.path(proc_dir, "CO_completepanel_peakweekly.csv")))



#=========================================================
#  Build NO2 panel (San Antonio not measured -> dropped)
#=========================================================
no2_panel <- build_weekly_panel(daily, covars_weekly, "no2",
                                drop_sanantonio = TRUE)

write_csv(no2_panel, file.path(proc_dir, "NO2_completepanel_peakweekly.csv"))
cat(sprintf("Saved: %s\n", file.path(proc_dir, "NO2_completepanel_peakweekly.csv")))


#=========================================================
#  Build SO2 panel (assume San Antonio not measured -> dropped)
#=========================================================
so2_panel <- build_weekly_panel(daily, covars_weekly, "so2",
                                drop_sanantonio = TRUE)

write_csv(so2_panel, file.path(proc_dir, "SO2_completepanel_peakweekly.csv"))
cat(sprintf("Saved: %s\n", file.path(proc_dir, "SO2_completepanel_peakweekly.csv")))

#=========================================================
#  Final summary
#=========================================================
cat("\n===== DONE =====\n")
cat(sprintf("PM2.5 panel: %d obs, %d weeks, 8 stations\n",
            nrow(pm25_panel), n_distinct(pm25_panel$week_id)))
cat(sprintf("CO panel:    %d obs, %d weeks, 7 stations\n",
            nrow(co_panel), n_distinct(co_panel$week_id)))
cat(sprintf("Output dir:  %s\n", proc_dir))

cat(sprintf("PM2.5 panel: %d obs, %d weeks, 8 stations\n",
            nrow(pm25_panel), n_distinct(pm25_panel$week_id)))
cat(sprintf("CO panel:    %d obs, %d weeks, 7 stations\n",
            nrow(co_panel), n_distinct(co_panel$week_id)))
cat(sprintf("NO2 panel:   %d obs, %d weeks\n",
            nrow(no2_panel), n_distinct(no2_panel$week_id)))
cat(sprintf("SO2 panel:   %d obs, %d weeks\n",
            nrow(so2_panel), n_distinct(so2_panel$week_id)))
cat(sprintf("Output dir:  %s\n", proc_dir))

