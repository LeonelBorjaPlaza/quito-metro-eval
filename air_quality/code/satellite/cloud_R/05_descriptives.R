#=========================================================
#  05_descriptives.R
#  City-level (satellite) descriptive outputs for the paper.
#  Mirror of code/local/11_descriptives.R, adapted to the
#  satellite panels.
#
#  Produces, as comprehensive CSVs (trimmed later for the paper):
#    D2  coverage and data quality   (Quito vs donor pool)
#    D3  sample construction funnel
#    D4  pre-treatment balance       (Quito vs donor pool, by donor-pool size)
#    F1  weekly outcome series       (data + 4-panel figure)
#    F2  coverage over time          (data + figure)
#
#  Treatment-timeline table is intentionally NOT here: it is a
#  paper-general object (shared with the local analysis), not a
#  satellite-specific descriptive.
#
#  Run after the Stage 4 panel scripts. Reads both the pre-balance
#  panels (panel_<pol>.csv) and the balanced panels
#  (panel_<pol>_balanced.csv).
#=========================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(lubridate)
  library(ggplot2)
  library(stringr)
  library(here)
})

# ---- Paths ----
root_dir <- here::here()
proc_dir <- file.path(root_dir, "data", "processed", "satellite")
out_tables_dir  <- file.path(root_dir, "output", "satellite", "tables")
out_figures_dir <- file.path(root_dir, "output", "satellite", "figures")
dir.create(out_tables_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(out_figures_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Constants ----
QUITO_ID  <- 2544L
EXCLUDE_ID <- 2610L          # Cumbaya, excluded from donor pool in the analysis

# Treatment week: ISO 2023-W48 (contains Dec 1, 2023). Matches Stage 5.
TREAT_ISO_YEAR <- 2023L
TREAT_ISO_WEEK <- 48L

# Donor-pool sizes for the pre-treatment balance table (comprehensive;
# the paper will show one, probably 100).
DONOR_POOL_SIZES <- c(50L, 100L, 150L, 200L)

# 13 winsorized ERA5 covariates (identical set used in estimation).
CONTROLS_W <- c("calm_pct_w", "evap_week_mm_w", "rain_freq_pct_w", "rh2m_mean_w",
                "soilT1_mean_w", "soilW1_mean_w", "solar_week_MJ_w", "sp_mean_w",
                "t2m_mean_w", "tp_week_mm_w", "wind10m_dir_w", "wind10m_max_w",
                "wind10m_speed_mean_w")

# Per-pollutant column mapping. SO2 uses asinh (as_so2), the rest use log.
POLLUTANTS <- list(
  aod = list(
    label        = "AOD",
    panel_raw    = "panel_aod.csv",
    panel_bal    = "panel_aod_balanced.csv",
    raw_outcome  = "ln_aod",         # logged outcome, NA where unobserved
    imp_outcome  = "ln_aod_imp",     # logged outcome, short gaps imputed
    level_var    = "aod_mean",       # raw level, for the levels table
    instrument   = "MODIS MAIAC",
    transform    = "log"
  ),
  co = list(
    label        = "CO",
    panel_raw    = "panel_co.csv",
    panel_bal    = "panel_co_balanced.csv",
    raw_outcome  = "ln_co",
    imp_outcome  = "ln_co_imp",
    level_var    = "co_mean",
    instrument   = "Sentinel-5P TROPOMI",
    transform    = "log"
  ),
  no2 = list(
    label        = "NO2",
    panel_raw    = "panel_no2.csv",
    panel_bal    = "panel_no2_balanced.csv",
    raw_outcome  = "ln_no2",
    imp_outcome  = "ln_no2_imp",
    level_var    = "no2_mean",
    instrument   = "Sentinel-5P TROPOMI",
    transform    = "log"
  ),
  so2 = list(
    label        = "SO2",
    panel_raw    = "panel_so2.csv",
    panel_bal    = "panel_so2_balanced.csv",
    raw_outcome  = "as_so2",
    imp_outcome  = "as_so2_imp",
    level_var    = "so2_mean",
    instrument   = "Sentinel-5P TROPOMI",
    transform    = "asinh"
  )
)

# ---- Helper: classify a panel into pre / post relative to treatment week ----
add_period <- function(df) {
  df %>%
    mutate(
      period = if_else(
        iso_year < TREAT_ISO_YEAR |
          (iso_year == TREAT_ISO_YEAR & iso_week < TREAT_ISO_WEEK),
        "pre", "post"
      )
    )
}

# ---- Load donor ranking once (Mahalanobis distances) ----
# The donor file carries three rankings (primary, extended, minimal).
# The v4 analysis used the EXTENDED ranking, so we use rank_extended here
# for consistency with what actually entered estimation.
donor_file <- file.path(root_dir, "data", "working", "ucdb_donor_distances_all.csv")
if (file.exists(donor_file)) {
  donor_ranks <- read_csv(donor_file, show_col_types = FALSE) %>%
    rename(id_uc_g0   = ID_UC_G0,
           donor_rank = rank_extended) %>%
    select(id_uc_g0, donor_rank) %>%
    arrange(donor_rank)
  cat(sprintf("Donor ranking loaded: %d cities (rank_extended)\n",
              nrow(donor_ranks)))
} else {
  donor_ranks <- NULL
  cat("WARNING: donor ranking file not found; D4 balance table will be skipped.\n")
}


#=========================================================
# D2. Coverage and data quality  (Quito vs donor pool)
#=========================================================
cat("\n[D2] Coverage and data quality...\n")

coverage_rows <- lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  panel <- read_csv(file.path(proc_dir, cfg$panel_raw), show_col_types = FALSE)
  panel <- panel %>% filter(id_uc_g0 != EXCLUDE_ID) %>% add_period()

  raw <- cfg$raw_outcome

  # A city-week is "valid" if the raw (un-imputed) outcome is present.
  per_unit <- panel %>%
    mutate(is_quito = id_uc_g0 == QUITO_ID,
           valid    = !is.na(.data[[raw]])) %>%
    group_by(group = if_else(is_quito, "Quito", "Donor pool"), period) %>%
    summarise(
      n_cityweeks   = n(),
      n_valid       = sum(valid),
      pct_valid     = round(100 * n_valid / n_cityweeks, 1),
      mean_cov_ratio = round(mean(coverage_ratio, na.rm = TRUE), 3),
      .groups = "drop"
    ) %>%
    mutate(pollutant = cfg$label)

  # AOD-only pixel detail (other pollutants do not carry valid_pixels the same way).
  if (pol == "aod") {
    px <- panel %>%
      mutate(is_quito = id_uc_g0 == QUITO_ID) %>%
      group_by(group = if_else(is_quito, "Quito", "Donor pool"), period) %>%
      summarise(mean_valid_px = round(mean(valid_pixels, na.rm = TRUE), 0),
                .groups = "drop")
    per_unit <- per_unit %>% left_join(px, by = c("group", "period"))
  } else {
    per_unit$mean_valid_px <- NA_real_
  }

  # Gap structure: of all missing spells, share that are short (imputable).
  gap <- panel %>%
    group_by(group = if_else(id_uc_g0 == QUITO_ID, "Quito", "Donor pool")) %>%
    summarise(
      n_missing_raw = sum(is.na(.data[[raw]])),
      n_short_gap   = sum(short_gap, na.rm = TRUE),
      pct_short_of_missing = round(
        100 * sum(short_gap, na.rm = TRUE) / pmax(sum(is.na(.data[[raw]])), 1), 1),
      .groups = "drop"
    ) %>%
    mutate(pollutant = cfg$label)

  per_unit %>% left_join(gap, by = c("group", "pollutant"))
})

coverage_tbl <- bind_rows(coverage_rows) %>%
  select(pollutant, group, period, n_cityweeks, n_valid, pct_valid,
         mean_cov_ratio, mean_valid_px,
         n_missing_raw, n_short_gap, pct_short_of_missing) %>%
  arrange(pollutant, group, desc(period))

write_csv(coverage_tbl, file.path(out_tables_dir, "D2_coverage_quality.csv"))
cat(sprintf("  Wrote: D2_coverage_quality.csv (%d rows)\n", nrow(coverage_tbl)))
print(coverage_tbl)


#=========================================================
# D3. Sample construction funnel
#=========================================================
cat("\n[D3] Sample construction funnel...\n")

funnel_rows <- lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  raw_panel <- read_csv(file.path(proc_dir, cfg$panel_raw),
                        show_col_types = FALSE)
  bal_panel <- read_csv(file.path(proc_dir, cfg$panel_bal),
                        show_col_types = FALSE)

  raw  <- cfg$raw_outcome
  impv <- cfg$imp_outcome

  tibble(
    pollutant = cfg$label,
    # Step 1: every city-week in the merged Stage 4 panel.
    s1_cities          = n_distinct(raw_panel$id_uc_g0),
    s1_cityweeks       = nrow(raw_panel),
    # Step 2: city-weeks with a valid raw outcome (passed QA + positivity).
    s2_valid_raw       = sum(!is.na(raw_panel[[raw]])),
    # Step 3: city-weeks present after short-gap imputation.
    s3_after_impute    = sum(!is.na(raw_panel[[impv]])),
    s3_imputed         = sum(raw_panel$imputed, na.rm = TRUE),
    # Step 4: final balanced analysis panel.
    s4_cities          = n_distinct(bal_panel$id_uc_g0),
    s4_cityweeks       = nrow(bal_panel),
    s4_weeks_per_city  = round(nrow(bal_panel) / n_distinct(bal_panel$id_uc_g0), 1)
  )
})

funnel_tbl <- bind_rows(funnel_rows)
write_csv(funnel_tbl, file.path(out_tables_dir, "D3_sample_construction.csv"))
cat("  Wrote: D3_sample_construction.csv\n")
print(funnel_tbl)


#=========================================================
# D4. Pre-treatment balance: Quito vs donor pool
#     Comprehensive: computed for each donor-pool size.
#=========================================================
cat("\n[D4] Pre-treatment balance...\n")

if (is.null(donor_ranks)) {
  cat("  Skipped (no donor ranking file).\n")
} else {
  balance_rows <- list()

  for (pol in names(POLLUTANTS)) {
    cfg <- POLLUTANTS[[pol]]
    bal_panel <- read_csv(file.path(proc_dir, cfg$panel_bal),
                          show_col_types = FALSE) %>%
      filter(id_uc_g0 != EXCLUDE_ID) %>%
      add_period() %>%
      filter(period == "pre")

    impv <- cfg$imp_outcome
    vars <- c(impv, CONTROLS_W)

    # Quito pre-treatment moments.
    quito_df <- bal_panel %>% filter(id_uc_g0 == QUITO_ID)

    # Donor ranking restricted to cities that actually survive THIS
    # pollutant's balanced panel, then re-ranked. This matches the v4
    # analysis "top-N intersected with panel" logic: the effective
    # top-K is the K best-ranked cities AMONG those in the panel, not
    # the K best in the global ranking.
    cities_in_panel <- unique(bal_panel$id_uc_g0)
    ranked_in_panel <- donor_ranks %>%
      filter(id_uc_g0 != QUITO_ID, id_uc_g0 != EXCLUDE_ID,
             id_uc_g0 %in% cities_in_panel) %>%
      arrange(donor_rank) %>%
      mutate(effective_rank = row_number())

    n_available <- nrow(ranked_in_panel)

    for (K in DONOR_POOL_SIZES) {
      K_eff <- min(K, n_available)
      top_ids <- ranked_in_panel %>%
        filter(effective_rank <= K_eff) %>%
        pull(id_uc_g0)

      donors_df <- bal_panel %>% filter(id_uc_g0 %in% top_ids)

      for (v in vars) {
        q_mean <- mean(quito_df[[v]],  na.rm = TRUE)
        q_sd   <- sd(quito_df[[v]],    na.rm = TRUE)
        d_mean <- mean(donors_df[[v]], na.rm = TRUE)
        d_sd   <- sd(donors_df[[v]],   na.rm = TRUE)
        # Normalized difference (Imbens-Rubin): diff over pooled SD.
        norm_diff <- (q_mean - d_mean) / sqrt((q_sd^2 + d_sd^2) / 2)

        balance_rows[[length(balance_rows) + 1]] <- tibble(
          pollutant     = cfg$label,
          donor_pool    = K,
          n_donors_used = K_eff,
          variable      = if_else(v == impv, "outcome", v),
          quito_mean    = round(q_mean, 4),
          quito_sd      = round(q_sd, 4),
          donor_mean    = round(d_mean, 4),
          donor_sd      = round(d_sd, 4),
          norm_diff     = round(norm_diff, 3)
        )
      }
    }
  }

  balance_tbl <- bind_rows(balance_rows)
  write_csv(balance_tbl, file.path(out_tables_dir, "D4_pretreatment_balance.csv"))
  cat(sprintf("  Wrote: D4_pretreatment_balance.csv (%d rows)\n",
              nrow(balance_tbl)))


  #=========================================================
  # D5. Pre-treatment outcome comparison  (paper-ready)
  #     The slice of D4 most likely to enter the paper: outcome
  #     only (no climate covariates), at the top-100 donor pool.
  #     Climate covariates are intentionally excluded because
  #     Quito's altitude makes them structurally incomparable in
  #     levels, and the analysis residualizes them out anyway.
  #     The variable to validate the counterfactual is the outcome.
  #=========================================================
  cat("\n[D5] Pre-treatment outcome comparison (paper-ready)...\n")

  d5_tbl <- balance_tbl %>%
    filter(variable == "outcome", donor_pool == 100) %>%
    select(pollutant, n_donors_used,
           quito_mean, quito_sd, donor_mean, donor_sd, norm_diff)

  write_csv(d5_tbl, file.path(out_tables_dir, "D5_pretreatment_outcome.csv"))
  cat(sprintf("  Wrote: D5_pretreatment_outcome.csv (%d rows)\n", nrow(d5_tbl)))
  print(d5_tbl)
}


#=========================================================
# D6. Quito imputation count, by pollutant and period
#     Reproducible source for the imputation-coverage numbers
#     reported in the paper text and in the F2 figure note.
#     A city-week is "missing_raw" if the un-imputed outcome is
#     NA; "imputed" if the flag is set; "still_na" if it stayed
#     NA after imputation (long gap, not imputable).
#=========================================================
cat("\n[D6] Quito imputation count...\n")

d6_tbl <- bind_rows(lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  raw  <- cfg$raw_outcome
  impv <- cfg$imp_outcome
  read_csv(file.path(proc_dir, cfg$panel_raw), show_col_types = FALSE) %>%
    filter(id_uc_g0 == QUITO_ID) %>%
    add_period() %>%
    group_by(period) %>%
    summarise(
      n_weeks       = n(),
      n_missing_raw = sum(is.na(.data[[raw]])),
      n_imputed     = sum(imputed, na.rm = TRUE),
      n_still_na    = sum(is.na(.data[[impv]])),
      pct_imputed   = round(100 * sum(imputed, na.rm = TRUE) / n(), 2),
      .groups = "drop"
    ) %>%
    mutate(pollutant = cfg$label)
})) %>%
  select(pollutant, period, n_weeks, n_missing_raw, n_imputed,
         n_still_na, pct_imputed) %>%
  arrange(pollutant, desc(period))

write_csv(d6_tbl, file.path(out_tables_dir, "D6_quito_imputation.csv"))
cat(sprintf("  Wrote: D6_quito_imputation.csv (%d rows)\n", nrow(d6_tbl)))
print(d6_tbl)

# Per-pollutant totals (pre + post), used for the F2 figure note.
d6_totals <- d6_tbl %>%
  group_by(pollutant) %>%
  summarise(n_weeks   = sum(n_weeks),
            n_imputed = sum(n_imputed),
            n_still_na = sum(n_still_na),
            .groups = "drop")


#=========================================================
# F1. Weekly outcome series  (data + 4-panel figure)
#=========================================================
cat("\n[F1] Weekly outcome series...\n")

ts_data <- bind_rows(lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  bal_panel <- read_csv(file.path(proc_dir, cfg$panel_bal),
                        show_col_types = FALSE) %>%
    filter(id_uc_g0 != EXCLUDE_ID)
  impv <- cfg$imp_outcome
  bal_panel %>%
    select(id_uc_g0, week_start, value = all_of(impv)) %>%
    mutate(week_start = as.Date(week_start),
           pollutant  = cfg$label)
}))

write_csv(ts_data, file.path(out_tables_dir, "F1_time_series_data.csv"))
cat(sprintf("  Wrote: F1_time_series_data.csv (%d rows)\n", nrow(ts_data)))

# Treatment date for the vertical line: Monday of ISO 2023-W48.
treat_date <- as.Date("2023-11-27")
# Blackout band (donut definition used in the satellite analysis).
blackout_start <- as.Date("2024-09-15")
blackout_end   <- as.Date("2024-12-31")

pol_levels <- c("AOD", "CO", "NO2", "SO2")

# Donor pool summarized as a 10-90 percentile band + median per week.
# Plotting all ~570 donor lines produces an unreadable smear; the band
# conveys the same information cleanly.
donor_band <- ts_data %>%
  filter(id_uc_g0 != QUITO_ID) %>%
  group_by(pollutant, week_start) %>%
  summarise(p10 = quantile(value, 0.10, na.rm = TRUE),
            p50 = quantile(value, 0.50, na.rm = TRUE),
            p90 = quantile(value, 0.90, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(pollutant = factor(pollutant, levels = pol_levels))

quito_line <- ts_data %>%
  filter(id_uc_g0 == QUITO_ID) %>%
  mutate(pollutant = factor(pollutant, levels = pol_levels))

p_ts <- ggplot() +
  annotate("rect", xmin = blackout_start, xmax = blackout_end,
           ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "gray60") +
  geom_vline(xintercept = treat_date, linetype = "dashed",
             color = "gray30", linewidth = 0.5) +
  # Donor pool: 10-90 percentile band + median line.
  geom_ribbon(data = donor_band,
              aes(x = week_start, ymin = p10, ymax = p90),
              fill = "#377EB8", alpha = 0.25) +
  geom_line(data = donor_band,
            aes(x = week_start, y = p50),
            color = "#377EB8", linewidth = 0.5) +
  # Quito: highlighted on top.
  geom_line(data = quito_line,
            aes(x = week_start, y = value),
            color = "#E41A1C", linewidth = 0.8) +
  facet_wrap(~ pollutant, scales = "free_y", ncol = 2) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL,
       y = "Weekly outcome (logged; SO2 asinh-transformed)",
       caption = paste("Red: Quito. Blue line: donor-pool median;",
                        "band: donor-pool 10-90 percentiles.",
                        "Dashed line: Metro opening (ISO 2023-W48).",
                        "Shaded: 2024 blackout.")) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1),
        strip.text  = element_text(size = 12, face = "bold"),
        plot.caption = element_text(hjust = 0, size = 9, color = "gray30"))

ggsave(file.path(out_figures_dir, "F1_time_series.png"),
       plot = p_ts, width = 11, height = 7.5, dpi = 200)
ggsave(file.path(out_figures_dir, "F1_time_series.pdf"),
       plot = p_ts, width = 11, height = 7.5)
cat("  Wrote: F1_time_series.png and .pdf\n")


#=========================================================
# F2. Coverage over time  (data + figure)
#     The "% valid" line is meaningful only for the donor pool
#     (570 cities, varies smoothly). For Quito, a single city,
#     weekly coverage is binary (0 or 100), so it is shown as
#     discrete rug marks at the weeks with a missing observation,
#     not as a line. The per-panel note carries the D6 count so
#     the figure does not overstate Quito's gaps.
#=========================================================
cat("\n[F2] Coverage over time...\n")

# Donor-pool weekly coverage (the line).
donor_cov <- bind_rows(lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  raw <- cfg$raw_outcome
  read_csv(file.path(proc_dir, cfg$panel_raw), show_col_types = FALSE) %>%
    filter(id_uc_g0 != EXCLUDE_ID, id_uc_g0 != QUITO_ID) %>%
    mutate(valid = !is.na(.data[[raw]]),
           week_start = as.Date(week_start)) %>%
    group_by(week_start) %>%
    summarise(pct_valid = 100 * mean(valid), .groups = "drop") %>%
    mutate(pollutant = cfg$label)
}))

# Quito's missing weeks (the rug marks).
quito_missing <- bind_rows(lapply(names(POLLUTANTS), function(pol) {
  cfg <- POLLUTANTS[[pol]]
  raw <- cfg$raw_outcome
  read_csv(file.path(proc_dir, cfg$panel_raw), show_col_types = FALSE) %>%
    filter(id_uc_g0 == QUITO_ID) %>%
    mutate(week_start = as.Date(week_start)) %>%
    filter(is.na(.data[[raw]])) %>%
    select(week_start) %>%
    mutate(pollutant = cfg$label)
}))

write_csv(donor_cov, file.path(out_tables_dir, "F2_coverage_over_time.csv"))
cat(sprintf("  Wrote: F2_coverage_over_time.csv (%d rows)\n",
            nrow(donor_cov)))

donor_cov     <- donor_cov     %>% mutate(pollutant = factor(pollutant, levels = pol_levels))
quito_missing <- quito_missing %>% mutate(pollutant = factor(pollutant, levels = pol_levels))

# Per-panel note: Quito imputation count from D6.
note_df <- d6_totals %>%
  mutate(pollutant = factor(pollutant, levels = pol_levels),
         label = sprintf("Quito: %d of %d weeks imputed",
                          n_imputed, n_weeks))

p_cov <- ggplot() +
  geom_vline(xintercept = treat_date, linetype = "dashed",
             color = "gray30", linewidth = 0.5) +
  # Donor pool: smooth coverage line.
  geom_line(data = donor_cov,
            aes(x = week_start, y = pct_valid),
            color = "#377EB8", linewidth = 0.5) +
  # Quito: discrete marks at missing weeks (no misleading line).
  geom_rug(data = quito_missing,
           aes(x = week_start), color = "#E41A1C",
           sides = "b", linewidth = 0.7, length = unit(0.06, "npc")) +
  # Per-panel count note.
  geom_text(data = note_df,
            aes(x = as.Date("2022-02-01"), y = 12, label = label),
            hjust = 0, size = 3.2, color = "#E41A1C") +
  facet_wrap(~ pollutant, ncol = 2) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  scale_y_continuous(limits = c(0, 100)) +
  labs(x = NULL,
       y = "Donor-pool % of cities with a valid observation",
       caption = paste("Blue line: donor-pool coverage. Red ticks:",
                        "weeks with no valid observation in Quito.",
                        "Dashed line: Metro opening (ISO 2023-W48).")) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1),
        strip.text  = element_text(size = 12, face = "bold"),
        plot.caption = element_text(hjust = 0, size = 9, color = "gray30"))

ggsave(file.path(out_figures_dir, "F2_coverage_over_time.png"),
       plot = p_cov, width = 11, height = 7.5, dpi = 200)
ggsave(file.path(out_figures_dir, "F2_coverage_over_time.pdf"),
       plot = p_cov, width = 11, height = 7.5)
cat("  Wrote: F2_coverage_over_time.png and .pdf\n")


cat("\n=== Satellite descriptives complete ===\n")
cat(sprintf("Tables in:  %s\n", out_tables_dir))
cat(sprintf("Figures in: %s\n", out_figures_dir))
