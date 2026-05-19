# ============================================================================
#  04_so2_panel.R
#  Stage 4 of the LAC city-wide satellite pipeline.
#
#  Builds the weekly Sentinel-5P SO2 panel as a placebo / falsification
#  outcome for the Quito Metro evaluation. SO2 sources in cities are
#  predominantly industrial (power plants, smelters, heavy fuel) rather
#  than passenger transit, so a credible identification of the metro's
#  effect on traffic-related pollutants (AOD, CO, NO2) should NOT show
#  up on SO2.
#
#  Structure mirrors 04_co_panel.R and 04_no2_panel.R:
#    - Merge SO2 weekly with cleaned ERA5
#    - Winsorize SO2 at p99 before log
#    - Short-gap imputation (1-2 weeks) via regression + linear fallback
#    - Event flags tagged inline; balance / event filtering in Stage 5
#
#  Output: data/processed/satellite/panel_so2.csv
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(zoo)
  library(fixest)
  library(here)
})

# ---- Paths -----------------------------------------------------------------
ROOT_DIR <- here::here()
SO2_IN   <- file.path(ROOT_DIR, "data", "processed", "satellite", "so2_weekly.csv")
ERA5_IN  <- file.path(ROOT_DIR, "data", "processed", "satellite", "era5l_cleaned.csv")
OUTFILE  <- file.path(ROOT_DIR, "data", "processed", "satellite", "panel_so2.csv")

stopifnot(file.exists(SO2_IN), file.exists(ERA5_IN))

# ---- Constants -------------------------------------------------------------
POST_YEAR <- 2023
POST_WEEK <- 49

BLACKOUT_YEAR  <- 2024
BLACKOUT_WEEKS <- 16:18
WILDFIRE_YEAR  <- 2024
WILDFIRE_WEEK_MIN <- 39

MAX_GAP_LEN <- 2
WINSORIZE_PCTILE <- 0.99

CONTROLS_W <- c(
  "calm_pct_w", "evap_week_mm_w", "rain_freq_pct_w", "rh2m_mean_w",
  "soilT1_mean_w", "soilW1_mean_w", "solar_week_MJ_w", "sp_mean_w",
  "t2m_mean_w", "tp_week_mm_w", "wind10m_dir_w", "wind10m_max_w",
  "wind10m_speed_mean_w"
)

# ============================================================================
# Step 1: Load SO2 weekly and rename to short names
# ============================================================================
cat("Reading:", SO2_IN, "\n")
so2 <- read_csv(SO2_IN, show_col_types = FALSE) %>%
  rename(
    so2_mean = SO2_column_number_density_mean,
    so2_sum  = SO2_column_number_density_sum,
  ) %>%
  rename_with(~ tolower(.x),
              .cols = any_of(c("ID_UC_G0", "GC_CNT_GAD", "GC_UCN_MAI"))) %>%
  select(-any_of(c("system:index", ".geo", "source_file"))) %>%
  distinct(id_uc_g0, iso_year, iso_week, .keep_all = TRUE)

cat("  SO2 rows:", nrow(so2), "  cities:", length(unique(so2$id_uc_g0)), "\n")

# ============================================================================
# Step 2: Load cleaned ERA5 and merge
# ============================================================================
cat("\nReading:", ERA5_IN, "\n")
era5 <- read_csv(ERA5_IN, show_col_types = FALSE) %>%
  select(id_uc_g0, iso_year, iso_week, all_of(CONTROLS_W))

cat("  ERA5 rows:", nrow(era5), "  cities:", length(unique(era5$id_uc_g0)), "\n")

merged <- so2 %>% inner_join(era5, by = c("id_uc_g0", "iso_year", "iso_week"))
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
# Step 4: Winsorize SO2 at p99, then take log
# ============================================================================
p99 <- quantile(panel$so2_mean, probs = WINSORIZE_PCTILE, na.rm = TRUE)
panel <- panel %>%
  mutate(
    so2_w    = pmin(so2_mean, p99, na.rm = FALSE),
    ln_so2   = if_else(!is.na(so2_mean) & so2_mean > 0, log(so2_mean), NA_real_),
    ln_so2_w = if_else(!is.na(so2_w)    & so2_w    > 0, log(so2_w),    NA_real_),
  )

cat("\n  SO2 winsorized at p99 =", signif(p99, 4), "\n")
cat("  SO2 non-missing after merge:", sum(!is.na(panel$so2_mean)),
    "/", nrow(panel), "\n")
cat("  ln_so2 non-missing (after dropping <=0):", sum(!is.na(panel$ln_so2)),
    "/", nrow(panel), "\n")

# ============================================================================
# Step 5: Build wdate and lag/lead on ln_so2
# ============================================================================
panel <- panel %>%
  mutate(wdate = iso_year * 53L + iso_week) %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    L1_lnso2 = lag(ln_so2),
    F1_lnso2 = lead(ln_so2),
  ) %>%
  ungroup()

# ============================================================================
# Step 6: Identify gaps and flag short gaps (1-2 weeks)
# ============================================================================
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    is_na = is.na(ln_so2),
    grp = cumsum(is_na != lag(is_na, default = !first(is_na)))
  ) %>%
  group_by(id_uc_g0, grp) %>%
  mutate(gap_len = if (first(is_na)) n() else 0L) %>%
  group_by(id_uc_g0) %>%
  mutate(short_gap = is_na & gap_len >= 1L & gap_len <= MAX_GAP_LEN) %>%
  ungroup() %>%
  select(-is_na, -grp)

n_short <- sum(panel$short_gap, na.rm = TRUE)
n_long  <- sum(is.na(panel$ln_so2), na.rm = TRUE) - n_short
cat("  Short gaps (1-2 wk) eligible for imputation:", n_short, "\n")
cat("  Long  gaps (3+ wk) will remain NA:        ", n_long,  "\n")

# ============================================================================
# Step 7a: Regression-based imputation (fixed effects on city)
# ============================================================================
est_data <- panel %>%
  filter(!is.na(ln_so2), !is.na(L1_lnso2), !is.na(F1_lnso2),
         !if_any(all_of(CONTROLS_W), is.na))

if (nrow(est_data) > 0 && n_short > 0) {
  fml <- as.formula(
    paste0("ln_so2 ~ L1_lnso2 + F1_lnso2 + ",
           paste(CONTROLS_W, collapse = " + "),
           " | id_uc_g0")
  )
  cat("\n  Estimating imputation regression on", nrow(est_data), "obs ...\n")
  mod <- fixest::feols(fml, data = est_data, notes = FALSE)

  controls_have_na <- rowSums(is.na(panel[, CONTROLS_W, drop = FALSE])) > 0
  pred_mask <- panel$short_gap &
               is.na(panel$ln_so2) &
               !is.na(panel$L1_lnso2) &
               !is.na(panel$F1_lnso2) &
               !controls_have_na
  pred_mask[is.na(pred_mask)] <- FALSE

  panel$lnso2_hat <- NA_real_
  if (any(pred_mask)) {
    panel$lnso2_hat[pred_mask] <- predict(mod, newdata = panel[pred_mask, ])
  }
  n_reg_imp <- sum(!is.na(panel$lnso2_hat))
  cat("  Imputed via regression :", n_reg_imp, "\n")
} else {
  panel$lnso2_hat <- NA_real_
  cat("  No short gaps with sufficient covariate data; skipping regression imputation.\n")
}

# ============================================================================
# Step 7b: Linear interpolation fallback (short gaps only)
# ============================================================================
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    lnso2_ip = zoo::na.approx(ln_so2, x = wdate, na.rm = FALSE),
    lnso2_ip = if_else(short_gap, lnso2_ip, NA_real_),
  ) %>%
  ungroup()

# ============================================================================
# Step 7c: Combine ln_so2_imp = original / regression / interpolation
# ============================================================================
panel <- panel %>%
  mutate(
    ln_so2_imp = case_when(
      !is.na(ln_so2)                   ~ ln_so2,
      short_gap & !is.na(lnso2_hat)    ~ lnso2_hat,
      short_gap & !is.na(lnso2_ip)     ~ lnso2_ip,
      TRUE                              ~ NA_real_
    ),
    imputed = is.na(ln_so2) & !is.na(ln_so2_imp),
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
  select(-L1_lnso2, -F1_lnso2, -lnso2_hat, -lnso2_ip, -gap_len)

cat("\nFinal panel:\n")
cat("  Rows         :", nrow(out), "\n")
cat("  Columns      :", ncol(out), "\n")
cat("  Cities       :", length(unique(out$id_uc_g0)), "\n")
cat("  Year range   :", min(out$iso_year, na.rm = TRUE), "to",
    max(out$iso_year, na.rm = TRUE), "\n")
cat("  Non-missing ln_so2_imp :", sum(!is.na(out$ln_so2_imp)),
    sprintf(" (%.1f%%)\n", 100 * mean(!is.na(out$ln_so2_imp))))

write_csv(out, OUTFILE)
cat("\nWrote:", OUTFILE, "\n")
