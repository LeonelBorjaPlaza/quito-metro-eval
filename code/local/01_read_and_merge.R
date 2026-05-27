#=========================================================
#  01_read_and_merge.R
#  Read REMMAQ raw .xlsx files, standardize, merge, flag events
#
#  Input:  data/raw/remmaq/*.xlsx (9 files: PM2.5, CO, TMP, HUM, VEL, DIR, LLU, RS, PRE)
#  Output: data/processed/hourly_panel.csv
#
#  Stations kept (8): belisario, carapungo, centro, cotocollao,
#                     guamani, loschillos, sanantonio, tumbaco
#=========================================================

library(readxl)
library(dplyr)
library(lubridate)
library(readr)
library(tidyr)
library(stringr)

# ---- Paths ----
root_dir <- here::here()  # project root (quito-metro-airquality-2026)
raw_dir  <- file.path(root_dir, "data", "raw", "remmaq")
out_dir  <- file.path(root_dir, "data", "processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Station name standardizer ----
# Handles uppercase, CamelCase, spaces, and Spanish accents
standardize_name <- function(x) {
  x <- tolower(trimws(x))
  x <- gsub(" ", "", x)
  x <- chartr("\u00e1\u00e9\u00ed\u00f3\u00fa\u00f1",
              "aeionn", x)
  return(x)
}

# ---- The 8 analysis stations ----
stations_keep <- c("belisario", "carapungo", "centro", "cotocollao",
                   "guamani", "loschillos", "sanantonio", "tumbaco")

#=========================================================
#  Generic reader for REMMAQ .xlsx files
#=========================================================
# Each file has:
#   Row 1: station names (first cell blank or "FECHA")
#   Row 2: units ("ug/m3", "°C", etc.)
#   Row 3+: data (datetime in col 1, numeric values in station cols)
#
# Some files have:
#   - Whitespace strings instead of blanks (need coercion to numeric)
#   - Timestamps at XX:59:59.999 instead of XX:00:00 (need rounding)
#   - Accented station names (Guamaní -> guamani)
#   - Different station sets per variable

read_remmaq <- function(filepath, sheet_name, var_suffix) {
  
  cat(sprintf("Reading %s (sheet: %s)...\n", basename(filepath), sheet_name))
  
  # Read with row 1 as column names (readxl default)
  # Blank date header gets auto-named; station names become column headers
  # Units row ("ug/m3" etc.) becomes first data row -- we drop it below
  hdr <- read_excel(filepath, sheet = 1, n_max = 0)
  df  <- read_excel(filepath, sheet = 1,
                    col_types = c("date", rep("numeric", ncol(hdr) - 1L)))
  

  
  # First column is fecha; remaining are stations
  station_names_raw <- names(df)[-1]
  station_names <- sapply(station_names_raw, standardize_name, USE.NAMES = FALSE)
  names(df) <- c("fecha", station_names)
  
  # AFTER  -- fecha is already a datetime from the typed read
  df$fecha <- as.POSIXct(df$fecha, tz = "UTC")
  
  # Coerce station columns to numeric (handles whitespace strings -> NA)
  for (stn in station_names) {
    df[[stn]] <- suppressWarnings(as.numeric(df[[stn]]))
  }
  
  # Drop rows where fecha is NA
  df <- df %>% filter(!is.na(fecha))
  
  # Round timestamps to nearest hour (fixes XX:59:59.999 entries)
  df$fecha <- round_date(df$fecha, "hour")
  
  # Extract date and hour
  df$date <- as.Date(df$fecha)
  df$hour_of_day <- hour(df$fecha)
  
  # Keep only the 8 analysis stations (some files have extras)
  available <- intersect(station_names, stations_keep)
  missing   <- setdiff(stations_keep, station_names)
  extra     <- setdiff(station_names, stations_keep)
  
  if (length(missing) > 0) {
    cat(sprintf("  Stations not in this file: %s\n", paste(missing, collapse = ", ")))
  }
  if (length(extra) > 0) {
    cat(sprintf("  Extra stations dropped: %s\n", paste(extra, collapse = ", ")))
  }
  
  df <- df %>% select(fecha, date, hour_of_day, all_of(available))
  
  # Check for duplicate date-hour rows
  dup_check <- df %>% count(date, hour_of_day) %>% filter(n > 1)
  if (nrow(dup_check) > 0) {
    cat(sprintf("  WARNING: %d duplicate date-hour combinations. Averaging.\n", nrow(dup_check)))
    print(dup_check)
    df <- df %>%
      group_by(date, hour_of_day) %>%
      summarise(fecha = first(fecha),
                across(all_of(available), ~ mean(.x, na.rm = TRUE)),
                .groups = "drop")
  }
  cat(sprintf("  Rows: %d, Stations: %d\n", nrow(df), length(available)))
  
  # Rename station columns with variable suffix
  for (stn in available) {
    names(df)[names(df) == stn] <- paste0(stn, "_", var_suffix)
  }
  
  return(df)
}

#=========================================================
#  Read all 9 files
#=========================================================

# Pollutants (outcomes)
pm25 <- read_remmaq(file.path(raw_dir, "PM2.5.xlsx"), "PM2.5", "pm25")
co   <- read_remmaq(file.path(raw_dir, "CO.xlsx"),    "CO",    "co")
no2  <- read_remmaq(file.path(raw_dir, "NO2.xlsx"),   "NO2",   "no2")
so2  <- read_remmaq(file.path(raw_dir, "SO2.xlsx"),   "SO2",   "so2")

# Weather covariates
tmp  <- read_remmaq(file.path(raw_dir, "TMP.xlsx"), "TMP", "tmp")
hum  <- read_remmaq(file.path(raw_dir, "HUM.xlsx"), "HUM", "hum")
vel  <- read_remmaq(file.path(raw_dir, "VEL.xlsx"), "VEL", "vel")
dir  <- read_remmaq(file.path(raw_dir, "DIR.xlsx"), "DIR", "dir")
llu  <- read_remmaq(file.path(raw_dir, "LLU.xlsx"), "LLU", "llu")
rs   <- read_remmaq(file.path(raw_dir, "RS.xlsx"),  "RS",  "rs")
pre  <- read_remmaq(file.path(raw_dir, "PRE.xlsx"), "PRE", "pre")


#=========================================================
#  Check for month-level duplications (CO Sept 2023 issue)
#=========================================================
# The previous CO download had September 2023 data replaced by
# a duplicate of September 2024. This check catches that kind of error.

check_month_duplication <- function(df, var_suffix) {
  cat(sprintf("\nMonth duplication check for %s:\n", var_suffix))

  # Get a representative station column
  stn_col <- paste0("centro_", var_suffix)
  if (!stn_col %in% names(df)) {
    stn_col <- grep(paste0("_", var_suffix, "$"), names(df), value = TRUE)[1]
  }

  # Count non-missing obs per year-month
  monthly <- df %>%
    mutate(year = year(date), month = month(date)) %>%
    group_by(year, month) %>%
    summarise(n_obs = sum(!is.na(.data[[stn_col]])), .groups = "drop")

  # Look for months with zero observations (gaps)
  zero_months <- monthly %>% filter(n_obs == 0)
  if (nrow(zero_months) > 0) {
    cat("  Months with zero observations:\n")
    print(zero_months)
  }

  # Look for suspiciously identical monthly patterns (correlation check)
  # Compare each pair of same-month across years
  cat(sprintf("  Total year-months: %d, range: %d-%d\n",
              nrow(monthly), min(monthly$year), max(monthly$year)))
  cat("  OK\n")
}

check_month_duplication(pm25, "pm25")
check_month_duplication(co, "co")
check_month_duplication(no2, "no2")
check_month_duplication(so2, "so2")
check_month_duplication(tmp, "tmp")


#=========================================================
#  Create hourly spine and merge
#=========================================================
# The spine ensures every hour from the earliest to latest
# observation is represented, even if some files start/end
# at different dates.

# Use the UNION of date ranges (NAs propagate per variable; the per-pollutant
# balanced-panel step drops incomplete weeks downstream).
start_date <- min(min(pm25$date), min(co$date), min(no2$date), min(so2$date),
                  min(tmp$date), min(hum$date), min(vel$date), min(dir$date),
                  min(llu$date), min(rs$date), min(pre$date))
end_date   <- max(max(pm25$date), max(co$date), max(no2$date), max(so2$date),
                  max(tmp$date), max(hum$date), max(vel$date), max(dir$date),
                  max(llu$date), max(rs$date), max(pre$date))

cat(sprintf("\nUnion date range: %s to %s\n", start_date, end_date))

# Per-variable date ranges (diagnostic)
for (nm in c("pm25", "co", "no2", "so2", "tmp", "hum",
             "vel", "dir", "llu", "rs", "pre")) {
  d <- get(nm)
  cat(sprintf("  %-5s: %s to %s\n", nm, min(d$date), max(d$date)))
}

# Build spine: every hour from start to end
spine <- expand.grid(
  date = seq.Date(start_date, end_date, by = "day"),
  hour_of_day = 0:23
) %>%
  as_tibble() %>%
  arrange(date, hour_of_day)

cat(sprintf("Spine rows: %d\n", nrow(spine)))

# Merge all files onto spine
merge_onto_spine <- function(spine, df) {
  df_slim <- df %>% select(-fecha)  # drop fecha, keep date + hour_of_day + station cols
  left_join(spine, df_slim, by = c("date", "hour_of_day"))
}

panel <- spine %>%
  merge_onto_spine(pm25) %>%
  merge_onto_spine(co) %>%
  merge_onto_spine(no2) %>%
  merge_onto_spine(so2) %>%
  merge_onto_spine(tmp) %>%
  merge_onto_spine(hum) %>%
  merge_onto_spine(vel) %>%
  merge_onto_spine(dir) %>%
  merge_onto_spine(llu) %>%
  merge_onto_spine(rs) %>%
  merge_onto_spine(pre)

cat(sprintf("Merged panel: %d rows, %d columns\n", nrow(panel), ncol(panel)))


#=========================================================
#  Safety filter: set negative pollutant values to NA
#=========================================================
# REMMAQ QA/QC already validated the data. This is a defensive check
# for any values that slipped through (negatives are physically impossible).

for (col in grep("_(pm25|co|no2|so2)$", names(panel), value = TRUE)) {
  n_neg <- sum(panel[[col]] < 0, na.rm = TRUE)
  if (n_neg > 0) cat(sprintf("  %s: %d negative values set to NA\n", col, n_neg))
  panel[[col]] <- ifelse(panel[[col]] < 0, NA, panel[[col]])
}


#=========================================================
#  Add time variables
#=========================================================
panel <- panel %>%
  mutate(
    year        = year(date),
    month       = month(date),
    day_of_week = wday(date, week_start = 1),  # 1=Monday, 7=Sunday
    day_of_month = day(date)
  )

#=========================================================
#  Flag events: power outages, wildfires, holidays
#=========================================================
# Sources:
#   Power outages: ecuador_blackouts_2024.xlsx (sourced from Primicias, Ecuavisa,
#     Al Jazeera, CNN, El Comercio, Wikipedia). 2023 dates from original Stata code.
#   Holidays: Ministerio de Turismo, Calendario de Feriados Nacionales 2023-2025
#   Wildfires: news reports (Sep 2024 Quito wildfires)

# ---- Power outages ----
panel$poweroutage <- 0

# 2023: Oct 27 - Dec 15 (with specific days OFF, per original Stata code with news URLs)
panel$poweroutage[panel$date >= as.Date("2023-10-27") &
                    panel$date <= as.Date("2023-12-15")] <- 1
no_outage_2023 <- c(
  seq.Date(as.Date("2023-12-09"), as.Date("2023-12-10"), by = "day"),
  as.Date("2023-12-06"),
  seq.Date(as.Date("2023-12-01"), as.Date("2023-12-04"), by = "day"),
  seq.Date(as.Date("2023-11-02"), as.Date("2023-11-05"), by = "day"),
  seq.Date(as.Date("2023-11-11"), as.Date("2023-11-12"), by = "day"),
  seq.Date(as.Date("2023-11-17"), as.Date("2023-11-19"), by = "day"),
  seq.Date(as.Date("2023-11-22"), as.Date("2023-11-23"), by = "day"),
  seq.Date(as.Date("2023-11-25"), as.Date("2023-11-26"), by = "day")
)
panel$poweroutage[panel$date %in% no_outage_2023] <- 0

# 2024 Phase 1 (April crisis): Apr 14-30, 8-13 hrs/day
# Apr 21 suspended for national referendum
# May 1-15 had residual/easing cuts (0-4 hrs, sporadic) -- not flagged
panel$poweroutage[panel$date >= as.Date("2024-04-14") &
                    panel$date <= as.Date("2024-04-30")] <- 1
panel$poweroutage[panel$date == as.Date("2024-04-21")] <- 0

# 2024 Phase 2 (June events): isolated national blackouts
panel$poweroutage[panel$date == as.Date("2024-06-19")] <- 1  # national blackout
panel$poweroutage[panel$date == as.Date("2024-06-21")] <- 1  # rationing day

# 2024 Phase 3 (Sep-Dec crisis): Sep 23 - Dec 20 systematic daily blackouts (89 days)
# Precursor events Sep 7 and Sep 18-22 also flagged
panel$poweroutage[panel$date == as.Date("2024-09-07")] <- 1  # national blackout
panel$poweroutage[panel$date >= as.Date("2024-09-18") &
                    panel$date <= as.Date("2024-12-20")] <- 1
# Dec 21: post-crisis national blackout (transmission failure)
panel$poweroutage[panel$date == as.Date("2024-12-21")] <- 1


# ---- Wildfires ----
# September 24-27, 2024 (Quito area wildfires)
panel$wildfire <- as.integer(panel$date >= as.Date("2024-09-24") &
                               panel$date <= as.Date("2024-09-27"))


# ---- Holidays (official transferred dates) ----
# Source: Ministerio de Turismo, Calendario de Feriados Nacionales 2023-2025
holidays <- as.Date(c(
  # 2022 (pre-treatment, kept for completeness)
  "2021-12-31", "2022-02-28", "2022-03-01", "2022-04-15", "2022-05-02",
  "2022-05-23", "2022-08-12", "2022-10-10", "2022-11-04", "2022-11-03",
  "2022-12-26",
  # 2023
  "2023-01-02",                   # Ano Nuevo (transferred from Sun Jan 1)
  "2023-02-20", "2023-02-21",     # Carnaval
  "2023-04-07",                   # Viernes Santo
  "2023-05-01",                   # Dia del Trabajo
  "2023-05-26",                   # Batalla del Pichincha (transferred from Wed May 24)
  "2023-08-11",                   # Primer Grito (transferred from Thu Aug 10)
  "2023-10-09",                   # Independencia de Guayaquil
  "2023-11-02", "2023-11-03",     # Difuntos + Independencia de Cuenca
  "2023-12-25",                   # Navidad
  # 2024
  "2024-01-01",                   # Ano Nuevo
  "2024-02-12", "2024-02-13",     # Carnaval
  "2024-03-29",                   # Viernes Santo
  "2024-05-03",                   # Dia del Trabajo (transferred from Wed May 1)
  "2024-05-24",                   # Batalla del Pichincha
  "2024-08-09",                   # Primer Grito (transferred from Sat Aug 10)
  "2024-10-11",                   # Independencia de Guayaquil (transferred from Wed Oct 9)
  "2024-11-01",                   # Difuntos (transferred from Sat Nov 2)
  "2024-11-04",                   # Independencia de Cuenca (transferred from Sun Nov 3)
  "2024-12-25",                   # Navidad
  # 2025
  "2025-01-01",                   # Ano Nuevo
  "2025-03-03", "2025-03-04",     # Carnaval
  "2025-04-18",                   # Viernes Santo
  "2025-05-02",                   # Dia del Trabajo (transferred from Thu May 1)
  "2025-05-23",                   # Batalla del Pichincha (transferred from Sat May 24)
  "2025-08-11",                   # Primer Grito (transferred from Sun Aug 10)
  "2025-10-10",                   # Independencia de Guayaquil (transferred from Thu Oct 9)
  "2025-11-03",                   # Independencia de Cuenca
  "2025-11-04",                   # Difuntos (transferred from Sun Nov 2)
  "2025-12-25",                   # Navidad
  # Quito-specific: Fiestas de Quito (Dec 6, transferred per year)
  "2022-12-05", "2023-12-08", "2024-12-06", "2025-12-05"
))

panel$holiday <- as.integer(panel$date %in% holidays)
#=========================================================
#  Save hourly panel
#=========================================================
cat(sprintf("\nFinal panel: %d rows, %d columns\n", nrow(panel), ncol(panel)))
cat(sprintf("Date range: %s to %s\n", min(panel$date), max(panel$date)))
cat(sprintf("Years: %s\n", paste(unique(panel$year), collapse = ", ")))

# Count non-missing by station for PM2.5 and CO
for (v in c("pm25", "co", "no2", "so2")) {
  cat(sprintf("\nNon-missing counts for %s:\n", v))
  cols <- grep(paste0("_", v, "$"), names(panel), value = TRUE)
  for (col in cols) {
    n_valid <- sum(!is.na(panel[[col]]))
    cat(sprintf("  %s: %d / %d (%.1f%%)\n", col, n_valid, nrow(panel),
                100 * n_valid / nrow(panel)))
  }
}

write_csv(panel, file.path(out_dir, "hourly_panel.csv"))
cat(sprintf("\nSaved: %s\n", file.path(out_dir, "hourly_panel.csv")))
