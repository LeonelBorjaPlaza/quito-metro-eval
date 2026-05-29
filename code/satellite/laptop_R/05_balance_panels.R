# ============================================================================
#  05_balance_panels.R
#  Stage 5 of the LAC city-wide satellite pipeline.
#
#  Filter each pollutant panel to cities with a perfectly balanced outcome
#  series across the full 2021-2026 period, and write a `_balanced.csv`
#  version of each.
#
#  Rationale: balancing here (rather than per-sample at the estimation step) guarantees
#  the same donor pool across all three samples (pre-blackout / full / donut).
#  Cross-sample comparisons become apples-to-apples and the cloud-side
#  Stage 5 code receives analysis-ready data.
#
#  Rule (uniform across pollutants): keep cities whose outcome `*_imp` column
#  has zero NAs across all 227 weeks of the panel. Any city with even one
#  missing week is dropped.
#
#  Outputs:
#    data/processed/satellite/panel_aod_balanced.csv
#    data/processed/satellite/panel_co_balanced.csv
#    data/processed/satellite/panel_no2_balanced.csv
#    data/processed/satellite/panel_so2_balanced.csv
#
#  CANONICAL Stage-5 balancer. Supersedes the ad-hoc, VM-side balancer
#  `balance_panels.R` (now archived), which was run by hand on the cloud and
#  produced the live `panel_*_balanced.csv`. That script uses an equivalent
#  keep rule (<=5% missing rather than ==0); on the current data both rules
#  keep identical cities, so the two are interchangeable here. This script
#  force-keeps the treated unit (Quito, id_uc_g0 = 2544) so the equivalence
#  also holds under any future data refresh in which Quito gains a gap.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

ROOT_DIR <- here::here()
DATA_DIR <- file.path(ROOT_DIR, "data", "processed", "satellite")

# Pollutant -> outcome column to balance on
POLLUTANTS <- list(
  aod = "ln_aod_imp",
  co  = "ln_co_imp",
  no2 = "ln_no2_imp",
  so2 = "as_so2_imp"
)

balance_panel <- function(pol, outcome_col) {
  in_path  <- file.path(DATA_DIR, sprintf("panel_%s.csv", pol))
  out_path <- file.path(DATA_DIR, sprintf("panel_%s_balanced.csv", pol))

  if (!file.exists(in_path)) {
    cat(sprintf("\n%s: input not found at %s; skipping.\n", toupper(pol), in_path))
    return(invisible(NULL))
  }

  cat(sprintf("\n=== %s ===\n", toupper(pol)))
  panel <- read_csv(in_path, show_col_types = FALSE)

  n_rows_in    <- nrow(panel)
  n_cities_in  <- n_distinct(panel$id_uc_g0)
  n_weeks      <- n_distinct(paste(panel$iso_year, panel$iso_week))

  # Identify cities with zero NA in the outcome column across the full period
  if (!(outcome_col %in% names(panel))) {
    cat(sprintf("  ERROR: outcome column %s not in panel; columns are:\n", outcome_col))
    print(names(panel))
    return(invisible(NULL))
  }

  city_missing <- panel %>%
    group_by(id_uc_g0) %>%
    summarise(n_miss = sum(is.na(.data[[outcome_col]])), .groups = "drop")

  balanced_cities <- city_missing %>%
    filter(n_miss == 0 | id_uc_g0 == 2544) %>%   # force-keep treated unit (Quito); see header note
    pull(id_uc_g0)

  panel_bal <- panel %>% filter(id_uc_g0 %in% balanced_cities)

  cat(sprintf("  Input:      %d rows, %d cities, %d weeks\n",
              n_rows_in, n_cities_in, n_weeks))
  cat(sprintf("  Balanced:   %d rows, %d cities (%.1f%% of input)\n",
              nrow(panel_bal), length(balanced_cities),
              100 * length(balanced_cities) / n_cities_in))

  # Sanity: balanced panel must be exactly cities x weeks
  if (length(balanced_cities) > 0) {
    expected <- length(balanced_cities) * n_weeks
    if (nrow(panel_bal) != expected) {
      cat(sprintf("  WARNING: balanced panel has %d rows; expected %d\n",
                  nrow(panel_bal), expected))
    }
  }

  # Confirm Quito is in the balanced set (id_uc_g0 = 2544)
  quito_in <- 2544 %in% balanced_cities
  cat(sprintf("  Quito (id_uc_g0 = 2544) in balanced set: %s\n",
              if (quito_in) "YES" else "NO -- check before analysis!"))

  write_csv(panel_bal, out_path)
  cat(sprintf("  Wrote:      %s\n", basename(out_path)))

  invisible(panel_bal)
}

# Run for all four pollutants
for (pol in names(POLLUTANTS)) {
  balance_panel(pol, POLLUTANTS[[pol]])
}

cat("\nDone. The balanced panels are ready for cloud upload.\n")
