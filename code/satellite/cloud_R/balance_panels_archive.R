# ============================================================================
#  balance_panels.R - Drop cities with high outcome missingness
# ============================================================================
#  Reads each panel_<pol>.csv, drops cities where the outcome has more than
#  THRESHOLD missing observations over the full panel window, writes a new
#  panel_<pol>_balanced.csv. Quito (2544) is always kept regardless.
#
#  Usage (defaults: DATA_DIR=~/v4_2026_05/data, THRESHOLD=0.05):
#    Rscript balance_panels.R
#
#  With custom params:
#    DATA_DIR=/path/to/data MISS_THRESHOLD=0.10 Rscript balance_panels.R
#
#  Outputs reproduce the original file structure (same columns) but with
#  fewer cities. Number of weeks per remaining city is unchanged.
# ============================================================================

suppressMessages({
  library(dplyr)
  library(readr)
})

DATA_DIR  <- Sys.getenv("DATA_DIR",       unset = "~/v4_2026_05/data")
THRESHOLD <- as.numeric(Sys.getenv("MISS_THRESHOLD", unset = "0.05"))

TREATED_ID <- 2544L

OUTCOMES <- list(
  aod = "ln_aod_imp",
  co  = "ln_co_imp",
  no2 = "ln_no2_imp",
  so2 = "as_so2_imp"
)

cat("\n", strrep("=", 60), "\n", sep = "")
cat(sprintf(" PANEL BALANCING\n"))
cat(sprintf(" DATA_DIR: %s\n", normalizePath(DATA_DIR, mustWork = FALSE)))
cat(sprintf(" Threshold: drop city if outcome missing > %.1f%%\n",
            THRESHOLD * 100))
cat(strrep("=", 60), "\n\n", sep = "")

for (pol in names(OUTCOMES)) {
  outcome  <- OUTCOMES[[pol]]
  in_file  <- file.path(DATA_DIR, sprintf("panel_%s.csv", pol))
  out_file <- file.path(DATA_DIR, sprintf("panel_%s_balanced.csv", pol))

  if (!file.exists(in_file)) {
    cat(sprintf("[%s] SKIP: %s not found\n\n", toupper(pol), in_file))
    next
  }

  cat(sprintf("[%s] Reading: %s\n", toupper(pol), basename(in_file)))
  df <- read_csv(in_file, show_col_types = FALSE)

  if (!outcome %in% names(df)) {
    cat(sprintf("  ERROR: outcome column '%s' not found. Skipping.\n\n", outcome))
    next
  }

  # Per-city missing rate
  city_miss <- df %>%
    group_by(id_uc_g0) %>%
    summarise(
      n_total  = n(),
      n_miss   = sum(is.na(.data[[outcome]])),
      miss_pct = n_miss / n_total,
      .groups  = "drop"
    )

  n_total <- nrow(city_miss)
  donor_miss <- city_miss$miss_pct[city_miss$id_uc_g0 != TREATED_ID]
  quito_row  <- city_miss[city_miss$id_uc_g0 == TREATED_ID, ]
  quito_miss <- if (nrow(quito_row) > 0) quito_row$miss_pct else NA_real_

  cat(sprintf("  Total cities: %d (incl. Quito)\n", n_total))
  cat(sprintf("  Quito missing: %.2f%%\n", 100 * quito_miss))
  cat(sprintf("  Donor missing distribution:\n"))
  cat(sprintf("    min=%.2f%%  p25=%.2f%%  median=%.2f%%  p75=%.2f%%  p90=%.2f%%  max=%.2f%%\n",
              100 * min(donor_miss,    na.rm = TRUE),
              100 * quantile(donor_miss, 0.25, na.rm = TRUE),
              100 * median(donor_miss, na.rm = TRUE),
              100 * quantile(donor_miss, 0.75, na.rm = TRUE),
              100 * quantile(donor_miss, 0.90, na.rm = TRUE),
              100 * max(donor_miss,    na.rm = TRUE)))
  cat(sprintf("  Cities at thresholds (donors only):\n"))
  for (t in c(0, 0.01, 0.02, 0.05, 0.10, 0.20)) {
    cat(sprintf("    <= %.0f%% missing: %d donors\n",
                100 * t, sum(donor_miss <= t, na.rm = TRUE)))
  }

  # Keep: Quito + donors with miss_pct <= THRESHOLD
  keep <- city_miss %>%
    filter(miss_pct <= THRESHOLD | id_uc_g0 == TREATED_ID) %>%
    pull(id_uc_g0)

  n_donors_kept <- sum(keep != TREATED_ID)
  cat(sprintf("\n  KEEPING %d cities (%d donors + Quito) at threshold %.1f%%\n",
              length(keep), n_donors_kept, 100 * THRESHOLD))

  if (quito_miss > THRESHOLD) {
    cat(sprintf("  WARNING: Quito missing (%.2f%%) exceeds threshold (%.1f%%)\n",
                100 * quito_miss, 100 * THRESHOLD))
    cat(sprintf("  Quito is kept regardless (it's the treated unit).\n"))
  }

  df_out <- df %>% filter(id_uc_g0 %in% keep)
  write_csv(df_out, out_file)

  cat(sprintf("  Wrote: %s\n", basename(out_file)))
  cat(sprintf("    %d rows, %d cities, %d weeks per city\n\n",
              nrow(df_out),
              n_distinct(df_out$id_uc_g0),
              nrow(df_out) / n_distinct(df_out$id_uc_g0)))
}

cat(strrep("=", 60), "\n", sep = "")
cat(" Done.\n")
cat(strrep("=", 60), "\n\n", sep = "")
