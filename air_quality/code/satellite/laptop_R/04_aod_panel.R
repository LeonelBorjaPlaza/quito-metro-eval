# ============================================================================
#  04_aod_panel.R
#  Stage 4 of the LAC city-wide satellite pipeline.
#
#  R port of the original Stata script 4_AOD_panel.do.
#
#  Merges weekly AOD with cleaned ERA5 covariates, applies AOD quality
#  filters, takes the log, performs short-gap imputation (regression +
#  linear interpolation fallback), and writes the final panel.
#
#  Design change from the Stata original:
#    The original script applied the blackout (2024-W16:18) and wildfire
#    (2024-W39+) exclusions inline, and saved only cities with a perfectly
#    balanced panel. The new pipeline keeps the FULL panel with event-period
#    FLAGS instead. The Stage 5 analysis script chooses one of three samples:
#       (a) pre-blackout (everything < 2024-W16)
#       (b) full period (everything; flag events in graphs)
#       (c) donut (drop event weeks; otherwise full)
#    and applies the balancing filter per sample.
#
#  Output: data/processed/satellite/panel_aod.csv
#    one row per (city × ISO week)
#    columns include raw aod_mean, ln_aod, imputed ln_aod_imp, imputed flag,
#    event flags (event_blackout, event_wildfires), treatment indicator (post),
#    and all winsorized ERA5 controls.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(zoo)        # na.approx for linear interpolation fallback
  library(fixest)     # feols for fixed-effects regression imputation
  library(here)
})

# ---- Paths -----------------------------------------------------------------
ROOT_DIR <- here::here()
AOD_IN   <- file.path(ROOT_DIR, "data", "processed", "satellite", "aod_weekly.csv")
ERA5_IN  <- file.path(ROOT_DIR, "data", "processed", "satellite", "era5l_cleaned.csv")
OUTFILE  <- file.path(ROOT_DIR, "data", "processed", "satellite", "panel_aod.csv")

stopifnot(file.exists(AOD_IN), file.exists(ERA5_IN))

# ---- Constants used throughout ---------------------------------------------
# Treatment: Metro opened ISO week 48 of 2023 (week containing Dec 1, Fri)
POST_YEAR <- 2023
POST_WEEK <- 48

# Event flags (informational; Stage 5 decides whether to filter)
BLACKOUT_YEAR  <- 2024
BLACKOUT_WEEKS <- 16:18         # April 2024 power outages
WILDFIRE_YEAR  <- 2024
WILDFIRE_WEEK_MIN <- 39         # Sept 2024+ wildfires & quality degradation

# AOD quality filters
MIN_VALID_PIXELS <- 100
MAX_AOD          <- 1.5
MIN_AOD          <- 0           # also drop exact zeros

# Imputation parameters
MAX_GAP_LEN <- 2                # only impute gaps of 1-2 weeks

# Winsorized ERA5 controls used as imputation regressors
CONTROLS_W <- c(
  "calm_pct_w", "evap_week_mm_w", "rain_freq_pct_w", "rh2m_mean_w",
  "soilT1_mean_w", "soilW1_mean_w", "solar_week_MJ_w", "sp_mean_w",
  "t2m_mean_w", "tp_week_mm_w", "wind10m_dir_w", "wind10m_max_w",
  "wind10m_speed_mean_w"
)

# ============================================================================
# Step 1: Load AOD weekly and rename to short names
# ============================================================================
cat("Reading:", AOD_IN, "\n")
aod <- read_csv(AOD_IN, show_col_types = FALSE) %>%
  rename(
    aod_mean   = Optical_Depth_055_mean,
    finefrac   = FineModeFraction_mean,
    fineaod    = fine_mode_aod_mean,
    aod_uncert = AOD_Uncertainty_mean,
    angstrom   = `AngstromExp_470-780_mean`,
    colwv      = Column_WV_mean,
    valid_px   = n_valid_px_sum,
    total_px   = n_total_px_sum,
  ) %>%
  # Lowercase the UCDB columns to match ERA5 cleaned
  rename_with(~ tolower(.x),
              .cols = any_of(c("ID_UC_G0", "GC_CNT_GAD", "GC_UCN_MAI"))) %>%
  # Drop GEE-export artifacts if present
  select(-any_of(c("system:index", ".geo", "source_file"))) %>%
  # Deduplicate (Stage 2b should have done this; cheap safety net)
  distinct(id_uc_g0, iso_year, iso_week, .keep_all = TRUE)

cat("  AOD rows:", nrow(aod), "  cities:", length(unique(aod$id_uc_g0)), "\n")

# ============================================================================
# Step 2: Load cleaned ERA5 and merge
# ============================================================================
cat("\nReading:", ERA5_IN, "\n")
era5 <- read_csv(ERA5_IN, show_col_types = FALSE) %>%
  # Keep id keys + winsorized controls + identifiers we don't already have
  select(id_uc_g0, iso_year, iso_week, all_of(CONTROLS_W))

cat("  ERA5 rows:", nrow(era5), "  cities:", length(unique(era5$id_uc_g0)), "\n")

merged <- aod %>% inner_join(era5, by = c("id_uc_g0", "iso_year", "iso_week"))
cat("\n  Merged rows:", nrow(merged),
    "  cities:", length(unique(merged$id_uc_g0)), "\n")

# ============================================================================
# Step 3: Treatment indicator + event flags
# ============================================================================
panel <- merged %>%
  mutate(
    post = iso_year > POST_YEAR |
           (iso_year == POST_YEAR & iso_week >= POST_WEEK),
    event_blackout  = iso_year == BLACKOUT_YEAR & iso_week %in% BLACKOUT_WEEKS,
    event_wildfires = iso_year == WILDFIRE_YEAR & iso_week >= WILDFIRE_WEEK_MIN,
  )

# ============================================================================
# Step 4: AOD quality filters (set to NA, do not drop rows)
# ============================================================================
# No additional QA at panel level - trust GEE-side QA mask (AOD_QA bits0-2==1
# & bits5-7==0 applied at pixel-level retrieval). This matches Stata's
# 4_AOD_panel.do which uses valid_pixels and aod<1.5 thresholds only as
# diagnostic counts inside preserve/restore blocks, never as production filters.
panel <- panel %>%
  mutate(
    ln_aod = if_else(!is.na(aod_mean) & aod_mean > 0, log(aod_mean), NA_real_),
  )

cat("\n  AOD non-missing after GEE QA: ", sum(!is.na(panel$aod_mean)),
    " / ", nrow(panel), "\n")

# ============================================================================
# Step 5: Build continuous week index (wdate) and lag/lead
# ============================================================================
# wdate: monotonic integer from (iso_year, iso_week). Allows L1/F1 ordering.
panel <- panel %>%
  mutate(wdate = iso_year * 53L + iso_week) %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    L1_lnaod = lag(ln_aod),
    F1_lnaod = lead(ln_aod),
  ) %>%
  ungroup()

# ============================================================================
# Step 6: Identify gaps and flag short gaps (1-2 weeks)
# ============================================================================
# Run-length encoding of NA streaks within each city.
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    is_na = is.na(ln_aod),
    # rle group id: increments each time we transition between NA and non-NA
    grp = cumsum(is_na != lag(is_na, default = !first(is_na)))
  ) %>%
  group_by(id_uc_g0, grp) %>%
  mutate(gap_len = if (first(is_na)) n() else 0L) %>%
  group_by(id_uc_g0) %>%
  mutate(short_gap = is_na & gap_len >= 1L & gap_len <= MAX_GAP_LEN) %>%
  ungroup() %>%
  select(-is_na, -grp)

n_short <- sum(panel$short_gap, na.rm = TRUE)
n_long  <- sum(is.na(panel$ln_aod), na.rm = TRUE) - n_short
cat("  Short gaps (1-2 wk) eligible for imputation:", n_short, "\n")
cat("  Long  gaps (3+ wk) will remain NA:        ", n_long,  "\n")

# ============================================================================
# Step 7a: Regression-based imputation (fixed-effects on city)
# ============================================================================
# areg ln_aod L1_lnaod F1_lnaod controls, absorb(id_uc_g0)
# Estimation sample: non-missing ln_aod, L1, F1, and all controls.
est_data <- panel %>%
  filter(!is.na(ln_aod), !is.na(L1_lnaod), !is.na(F1_lnaod),
         !if_any(all_of(CONTROLS_W), is.na))

fml <- as.formula(
  paste0("ln_aod ~ L1_lnaod + F1_lnaod + ",
         paste(CONTROLS_W, collapse = " + "),
         " | id_uc_g0")
)
cat("\n  Estimating imputation regression on", nrow(est_data), "obs ...\n")
mod <- fixest::feols(fml, data = est_data, notes = FALSE)

# Predict for the short-gap rows where lag/lead and controls are available.
controls_have_na <- rowSums(is.na(panel[, CONTROLS_W, drop = FALSE])) > 0
pred_mask <- panel$short_gap &
  is.na(panel$ln_aod) &
  !is.na(panel$L1_lnaod) &
  !is.na(panel$F1_lnaod) &
  !controls_have_na
pred_mask[is.na(pred_mask)] <- FALSE

panel$lnaod_hat <- NA_real_
if (any(pred_mask)) {
  pred_data <- panel[pred_mask, ]
  panel$lnaod_hat[pred_mask] <- predict(mod, newdata = pred_data)
}
n_reg_imp <- sum(!is.na(panel$lnaod_hat))
cat("  Imputed via regression :", n_reg_imp, "\n")

# ============================================================================
# Step 7b: Linear interpolation fallback (still only short gaps)
# ============================================================================
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    lnaod_ip = zoo::na.approx(ln_aod, x = wdate, na.rm = FALSE),
    lnaod_ip = if_else(short_gap, lnaod_ip, NA_real_),
  ) %>%
  ungroup()

# ============================================================================
# Step 7c: Combine: ln_aod_imp = original where present, else regression, else interp.
# ============================================================================
panel <- panel %>%
  mutate(
    ln_aod_imp = case_when(
      !is.na(ln_aod)             ~ ln_aod,
      short_gap & !is.na(lnaod_hat) ~ lnaod_hat,
      short_gap & !is.na(lnaod_ip)  ~ lnaod_ip,
      TRUE                        ~ NA_real_
    ),
    imputed = is.na(ln_aod) & !is.na(ln_aod_imp),
  )

n_imp_total <- sum(panel$imputed, na.rm = TRUE)
cat("  Total imputed (regression + interp):", n_imp_total, "\n")

# ============================================================================
# Step 8: Per-city imputation summary
# ============================================================================
city_summary <- panel %>%
  group_by(id_uc_g0) %>%
  summarise(
    n_total    = n(),
    n_imputed  = sum(imputed, na.rm = TRUE),
    pct_imputed = 100 * n_imputed / n_total,
    .groups = "drop"
  )

cat("\n  Per-city imputation rate: median",
    round(median(city_summary$pct_imputed, na.rm = TRUE), 2), "% / max",
    round(max(city_summary$pct_imputed, na.rm = TRUE), 2), "%\n")

# ============================================================================
# Step 9: Drop helper columns and save
# ============================================================================
out <- panel %>%
  select(-L1_lnaod, -F1_lnaod, -lnaod_hat, -lnaod_ip, -gap_len)

cat("\nFinal panel:\n")
cat("  Rows         :", nrow(out), "\n")
cat("  Columns      :", ncol(out), "\n")
cat("  Cities       :", length(unique(out$id_uc_g0)), "\n")
cat("  Year range   :", min(out$iso_year, na.rm = TRUE), "to",
    max(out$iso_year, na.rm = TRUE), "\n")
cat("  Non-missing ln_aod_imp :", sum(!is.na(out$ln_aod_imp)),
    sprintf(" (%.1f%%)\n", 100 * mean(!is.na(out$ln_aod_imp))))

write_csv(out, OUTFILE)
cat("\nWrote:", OUTFILE, "\n")
