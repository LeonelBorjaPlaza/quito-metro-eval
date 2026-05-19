# ============================================================================
#  04_co_panel.R
#  Stage 4 of the LAC city-wide satellite pipeline.
#
#  R port of the original Stata script 4_CO_panel.do.
#
#  Merges weekly Sentinel-5P CO with cleaned ERA5 covariates, winsorizes CO
#  at the 99th percentile, takes the log, performs short-gap imputation
#  (regression + linear interpolation fallback), and writes the panel.
#
#  Design choices, mirroring the AOD script and the master file methodology:
#    - No additional QA mask at panel level. Sentinel-5P L3 CO is
#      algorithm-filtered upstream; there is no client-side cloud mask
#      to apply (CO retrievals penetrate clouds).
#    - Winsorize CO at p99 before log (matches Stata 4_CO_panel.do).
#    - Short-gap imputation only (1-2 week gaps). The Stata script imputes
#      all gaps; we restrict to short gaps to (a) match the AOD treatment,
#      (b) align with the "minimal imputation" methodology in the master
#      file. CO has near-complete coverage, so this restriction is largely
#      academic in practice.
#    - Event flags (blackout, wildfires) tagged inline; balance and event
#      filtering happen in the Stage 5 analysis scripts.
#
#  Output: data/processed/satellite/panel_co.csv
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
CO_IN    <- file.path(ROOT_DIR, "data", "processed", "satellite", "co_weekly.csv")
ERA5_IN  <- file.path(ROOT_DIR, "data", "processed", "satellite", "era5l_cleaned.csv")
OUTFILE  <- file.path(ROOT_DIR, "data", "processed", "satellite", "panel_co.csv")

stopifnot(file.exists(CO_IN), file.exists(ERA5_IN))

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
# Step 1: Load CO weekly and rename to short names
# ============================================================================
cat("Reading:", CO_IN, "\n")
co <- read_csv(CO_IN, show_col_types = FALSE) %>%
  rename(
    co_mean  = CO_column_number_density_mean,
    co_sum   = CO_column_number_density_sum,
    h2o_mean = H2O_column_number_density_mean,
    h2o_sum  = H2O_column_number_density_sum,
  ) %>%
  rename_with(~ tolower(.x),
              .cols = any_of(c("ID_UC_G0", "GC_CNT_GAD", "GC_UCN_MAI"))) %>%
  select(-any_of(c("system:index", ".geo", "source_file"))) %>%
  distinct(id_uc_g0, iso_year, iso_week, .keep_all = TRUE)

cat("  CO rows:", nrow(co), "  cities:", length(unique(co$id_uc_g0)), "\n")

# ============================================================================
# Step 2: Load cleaned ERA5 and merge
# ============================================================================
cat("\nReading:", ERA5_IN, "\n")
era5 <- read_csv(ERA5_IN, show_col_types = FALSE) %>%
  select(id_uc_g0, iso_year, iso_week, all_of(CONTROLS_W))

cat("  ERA5 rows:", nrow(era5), "  cities:", length(unique(era5$id_uc_g0)), "\n")

merged <- co %>% inner_join(era5, by = c("id_uc_g0", "iso_year", "iso_week"))
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
# Step 4: Winsorize CO at p99, then take log
# ============================================================================
p99 <- quantile(panel$co_mean, probs = WINSORIZE_PCTILE, na.rm = TRUE)
panel <- panel %>%
  mutate(
    co_w   = pmin(co_mean, p99, na.rm = FALSE),
    ln_co   = if_else(!is.na(co_mean) & co_mean > 0, log(co_mean), NA_real_),
    ln_co_w = if_else(!is.na(co_w)    & co_w    > 0, log(co_w),    NA_real_),
  )

cat("\n  CO winsorized at p99 =", round(p99, 4), "\n")
cat("  CO non-missing after merge:", sum(!is.na(panel$co_mean)),
    "/", nrow(panel), "\n")

# ============================================================================
# Step 5: Build wdate and lag/lead on ln_co
# ============================================================================
panel <- panel %>%
  mutate(wdate = iso_year * 53L + iso_week) %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    L1_lnco = lag(ln_co),
    F1_lnco = lead(ln_co),
  ) %>%
  ungroup()

# ============================================================================
# Step 6: Identify gaps and flag short gaps (1-2 weeks)
# ============================================================================
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    is_na = is.na(ln_co),
    grp = cumsum(is_na != lag(is_na, default = !first(is_na)))
  ) %>%
  group_by(id_uc_g0, grp) %>%
  mutate(gap_len = if (first(is_na)) n() else 0L) %>%
  group_by(id_uc_g0) %>%
  mutate(short_gap = is_na & gap_len >= 1L & gap_len <= MAX_GAP_LEN) %>%
  ungroup() %>%
  select(-is_na, -grp)

n_short <- sum(panel$short_gap, na.rm = TRUE)
n_long  <- sum(is.na(panel$ln_co), na.rm = TRUE) - n_short
cat("  Short gaps (1-2 wk) eligible for imputation:", n_short, "\n")
cat("  Long  gaps (3+ wk) will remain NA:        ", n_long,  "\n")

# ============================================================================
# Step 7a: Regression-based imputation (fixed effects on city)
# ============================================================================
est_data <- panel %>%
  filter(!is.na(ln_co), !is.na(L1_lnco), !is.na(F1_lnco),
         !if_any(all_of(CONTROLS_W), is.na))

if (nrow(est_data) > 0 && n_short > 0) {
  fml <- as.formula(
    paste0("ln_co ~ L1_lnco + F1_lnco + ",
           paste(CONTROLS_W, collapse = " + "),
           " | id_uc_g0")
  )
  cat("\n  Estimating imputation regression on", nrow(est_data), "obs ...\n")
  mod <- fixest::feols(fml, data = est_data, notes = FALSE)

  controls_have_na <- rowSums(is.na(panel[, CONTROLS_W, drop = FALSE])) > 0
  pred_mask <- panel$short_gap &
               is.na(panel$ln_co) &
               !is.na(panel$L1_lnco) &
               !is.na(panel$F1_lnco) &
               !controls_have_na
  pred_mask[is.na(pred_mask)] <- FALSE

  panel$lnco_hat <- NA_real_
  if (any(pred_mask)) {
    panel$lnco_hat[pred_mask] <- predict(mod, newdata = panel[pred_mask, ])
  }
  n_reg_imp <- sum(!is.na(panel$lnco_hat))
  cat("  Imputed via regression :", n_reg_imp, "\n")
} else {
  panel$lnco_hat <- NA_real_
  cat("  No short gaps with sufficient covariate data; skipping regression imputation.\n")
}

# ============================================================================
# Step 7b: Linear interpolation fallback (short gaps only)
# ============================================================================
panel <- panel %>%
  arrange(id_uc_g0, wdate) %>%
  group_by(id_uc_g0) %>%
  mutate(
    lnco_ip = zoo::na.approx(ln_co, x = wdate, na.rm = FALSE),
    lnco_ip = if_else(short_gap, lnco_ip, NA_real_),
  ) %>%
  ungroup()

# ============================================================================
# Step 7c: Combine ln_co_imp = original / regression / interpolation
# ============================================================================
panel <- panel %>%
  mutate(
    ln_co_imp = case_when(
      !is.na(ln_co)                  ~ ln_co,
      short_gap & !is.na(lnco_hat)   ~ lnco_hat,
      short_gap & !is.na(lnco_ip)    ~ lnco_ip,
      TRUE                            ~ NA_real_
    ),
    imputed = is.na(ln_co) & !is.na(ln_co_imp),
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
  select(-L1_lnco, -F1_lnco, -lnco_hat, -lnco_ip, -gap_len)

cat("\nFinal panel:\n")
cat("  Rows         :", nrow(out), "\n")
cat("  Columns      :", ncol(out), "\n")
cat("  Cities       :", length(unique(out$id_uc_g0)), "\n")
cat("  Year range   :", min(out$iso_year, na.rm = TRUE), "to",
    max(out$iso_year, na.rm = TRUE), "\n")
cat("  Non-missing ln_co_imp :", sum(!is.na(out$ln_co_imp)),
    sprintf(" (%.1f%%)\n", 100 * mean(!is.na(out$ln_co_imp))))

write_csv(out, OUTFILE)
cat("\nWrote:", OUTFILE, "\n")
