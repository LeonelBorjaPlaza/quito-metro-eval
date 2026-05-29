# ============================================================================
#  03_clean_era5.R
#  Stage 3 of the LAC city-wide satellite pipeline.
#
#  R port of the original Stata script 3_cleanERAS.do.
#
#  Reads the merged ERA5-Land weekly panel produced by Stage 2b
#  (data/processed/satellite/era5l_weekly.csv), applies the same
#  cleaning steps the Stata version applied, and writes a tidy
#  analysis-ready covariates panel for use by the Stage 4 pollutant
#  panel-building scripts.
#
#  Steps mirror the Stata script:
#    1. Drop GEE-export artifact columns (system:index, .geo)
#    2. Standardize column names to lowercase (ID_UC_G0 -> id_uc_g0, etc.)
#    3. Remove exact and near-duplicate rows
#    4. Clip small negative values to zero (evap_week_mm, soilW1_mean)
#    5. Winsorize 13 weather controls at p99 (adds *_w columns)
#    6. Drop cities with >20% missingness in ANY of the 13 controls
#    7. Linearly interpolate remaining missing values within each city's
#       time series (sorted by iso_year then iso_week)
#    8. Strip accents from country/city names to ASCII
#
#  Output: data/processed/satellite/era5l_cleaned.csv
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(zoo)        # na.approx for linear interpolation
  library(stringi)    # stri_trans_general for accent stripping
  library(here)
})

# ---- Paths -----------------------------------------------------------------
ROOT_DIR <- here::here()
INFILE   <- file.path(ROOT_DIR, "data", "processed", "satellite", "era5l_weekly.csv")
OUTFILE  <- file.path(ROOT_DIR, "data", "processed", "satellite", "era5l_cleaned.csv")

if (!file.exists(INFILE)) {
  stop(sprintf("Input not found: %s\nRun 02b_merge.py first.", INFILE))
}

# ---- Controls used throughout ----------------------------------------------
CONTROLS <- c(
  "calm_pct", "evap_week_mm", "rain_freq_pct", "rh2m_mean",
  "soilT1_mean", "soilW1_mean", "solar_week_MJ", "sp_mean",
  "t2m_mean", "tp_week_mm", "wind10m_dir", "wind10m_max", "wind10m_speed_mean"
)
MISSING_THRESHOLD <- 0.20  # drop cities with >20% missing in any control
WINSORIZE_PCTILE  <- 0.99  # upper tail winsorization

# ============================================================================
# Step 1: Read merged ERA5
# ============================================================================
cat("Reading:", INFILE, "\n")
df <- read_csv(INFILE, show_col_types = FALSE)
cat("  Rows in     :", nrow(df), "\n")
cat("  Columns in  :", ncol(df), "\n")

# ============================================================================
# Step 2: Drop GEE-export artifacts, rename to lowercase
# ============================================================================
# GEE export adds `system:index` and `.geo` columns. The column names that
# come through readr may be `system:index` and `.geo` — use backticks.
df <- df %>%
  select(-any_of(c("system:index", ".geo"))) %>%
  rename_with(~ tolower(.x), .cols = any_of(c("ID_UC_G0", "GC_CNT_GAD", "GC_UCN_MAI")))

# ============================================================================
# Step 3: Deduplicate
# ============================================================================
n_before <- nrow(df)
df <- df %>% distinct()
cat("  Exact dupes removed:", n_before - nrow(df), "\n")

# Near-duplicate check mirrors Stata's `duplicates drop ... force` — keep one
# row per (city, week) using the first occurrence. After exact-dup removal this
# should already be a no-op for clean data, but mirror the safety net.
n_before <- nrow(df)
df <- df %>%
  arrange(id_uc_g0, iso_year, iso_week) %>%
  distinct(id_uc_g0, iso_year, iso_week, .keep_all = TRUE)
n_near <- n_before - nrow(df)
if (n_near > 0) cat("  Near-dupes removed:", n_near, "\n")

# ============================================================================
# Step 4: Clip small negatives
# ============================================================================
df <- df %>%
  mutate(
    evap_week_mm = if_else(!is.na(evap_week_mm) & evap_week_mm < 0, 0, evap_week_mm),
    soilW1_mean  = if_else(!is.na(soilW1_mean)  & soilW1_mean  < 0, 0, soilW1_mean)
  )

# ============================================================================
# Step 5: Winsorize at p99 (creates *_w columns)
# ============================================================================
for (v in CONTROLS) {
  if (!v %in% names(df)) {
    warning(sprintf("Control variable %s not found; skipping winsorization.", v))
    next
  }
  p99 <- quantile(df[[v]], probs = WINSORIZE_PCTILE, na.rm = TRUE)
  new_name <- paste0(v, "_w")
  df[[new_name]] <- pmin(df[[v]], p99, na.rm = FALSE)
}
cat("  Winsorized:", length(CONTROLS), "controls at p99\n")

# ============================================================================
# Step 6: Drop cities with >20% missing in any control
# ============================================================================
cities_before <- length(unique(df$id_uc_g0))

# Per-city missingness share for each control
miss_shares <- df %>%
  group_by(id_uc_g0) %>%
  summarise(across(all_of(CONTROLS), ~ mean(is.na(.x))), .groups = "drop")

# Mark any city where any control exceeds the threshold
miss_shares <- miss_shares %>%
  mutate(drop_city = if_any(all_of(CONTROLS), ~ .x > MISSING_THRESHOLD))

cities_to_drop <- miss_shares %>% filter(drop_city) %>% pull(id_uc_g0)
cat("  Cities flagged for dropping (>20% missing in any control):",
    length(cities_to_drop), "\n")

df <- df %>% filter(!(id_uc_g0 %in% cities_to_drop))
cat("  Cities retained:", length(unique(df$id_uc_g0)),
    "of", cities_before, "\n")

# ============================================================================
# Step 7: Linear interpolation within each city (sorted by iso_year, iso_week)
# ============================================================================
fill_linear <- function(y) {
  # If all NA, return as is. Otherwise linear interpolate; do not extrapolate
  # past the ends (na.rm = FALSE preserves leading/trailing NAs).
  if (all(is.na(y))) return(y)
  zoo::na.approx(y, na.rm = FALSE)
}

df <- df %>%
  arrange(id_uc_g0, iso_year, iso_week) %>%
  group_by(id_uc_g0) %>%
  mutate(across(all_of(CONTROLS), fill_linear)) %>%
  ungroup()

# Optional sanity: how many cells were filled?
n_filled <- df %>%
  summarise(across(all_of(CONTROLS), ~ sum(is.na(.x)))) %>%
  unlist() %>%
  sum()
cat("  Residual NAs after interpolation across all controls:", n_filled, "\n")

# ============================================================================
# Step 8: Strip accents from city/country names to ASCII
# ============================================================================
if ("gc_ucn_mai" %in% names(df)) {
  df <- df %>%
    mutate(gc_ucn_mai_clean = stringi::stri_trans_general(gc_ucn_mai, "Latin-ASCII"))
}
if ("gc_cnt_gad" %in% names(df)) {
  df <- df %>%
    mutate(gc_cnt_gad_clean = stringi::stri_trans_general(gc_cnt_gad, "Latin-ASCII"))
}

# ============================================================================
# Save
# ============================================================================
cat("\nFinal panel:\n")
cat("  Rows        :", nrow(df), "\n")
cat("  Columns     :", ncol(df), "\n")
cat("  Cities      :", length(unique(df$id_uc_g0)), "\n")
cat("  Year range  :", min(df$iso_year, na.rm = TRUE), "to",
    max(df$iso_year, na.rm = TRUE), "\n")

write_csv(df, OUTFILE)
cat("\nWrote:", OUTFILE, "\n")
