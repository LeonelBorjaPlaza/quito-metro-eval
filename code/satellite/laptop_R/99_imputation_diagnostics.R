# ============================================================================
#  99_imputation_diagnostics.R
#
#  Diagnostics on the satellite AOD panel.
#  Purpose: support methodology defense in the paper.
#
#  Question 1: How many cities does minimal short-gap imputation save vs
#              strict listwise deletion on the reference 2022-2024 window?
#  Question 2: How is the treated unit (Quito, id_uc_g0 = 2544) affected
#              by imputation?
#
#  Run after `04_aod_panel.R` produces panel_aod.csv.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

ROOT_DIR <- here::here()
PANEL_IN <- file.path(ROOT_DIR, "data", "processed", "satellite", "panel_aod.csv")
OUT_DIR  <- file.path(ROOT_DIR, "output", "satellite", "diagnostics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

QUITO_ID <- 2544L

panel <- read_csv(PANEL_IN, show_col_types = FALSE)

# ============================================================================
# Question 1: Sample-size effect of imputation
# ============================================================================
# Apply Stata-equivalent exclusions: drop blackout & wildfire weeks, keep 2022-2024.
panel_ref <- panel %>%
  filter(iso_year >= 2022, iso_year <= 2024,
         !event_blackout, !event_wildfires)

cities_listwise <- panel_ref %>%
  group_by(id_uc_g0) %>% summarise(n_miss = sum(is.na(ln_aod))) %>%
  filter(n_miss == 0) %>% pull(id_uc_g0)

cities_with_imp <- panel_ref %>%
  group_by(id_uc_g0) %>% summarise(n_miss = sum(is.na(ln_aod_imp))) %>%
  filter(n_miss == 0) %>% pull(id_uc_g0)

# Extended window (full new pipeline, donut applied)
panel_ext <- panel %>% filter(!event_blackout, !event_wildfires)

cities_listwise_ext <- panel_ext %>%
  group_by(id_uc_g0) %>% summarise(n_miss = sum(is.na(ln_aod))) %>%
  filter(n_miss == 0) %>% pull(id_uc_g0)

cities_with_imp_ext <- panel_ext %>%
  group_by(id_uc_g0) %>% summarise(n_miss = sum(is.na(ln_aod_imp))) %>%
  filter(n_miss == 0) %>% pull(id_uc_g0)

q1 <- tibble(
  window     = c("2022-2024 (Stata reference)", "2021-2026 (extended)"),
  listwise   = c(length(cities_listwise),  length(cities_listwise_ext)),
  with_imp   = c(length(cities_with_imp),  length(cities_with_imp_ext)),
  gain_from_imp = c(length(cities_with_imp) - length(cities_listwise),
                    length(cities_with_imp_ext) - length(cities_listwise_ext))
)

cat("\n=== Question 1: Sample-size effect of minimal short-gap imputation ===\n")
print(q1)

write_csv(q1, file.path(OUT_DIR, "imputation_sample_size_effect.csv"))

# ============================================================================
# Question 2: Imputation in the treated unit (Quito)
# ============================================================================
quito <- panel %>% filter(id_uc_g0 == QUITO_ID) %>%
  arrange(iso_year, iso_week)

q2_summary <- tibble(
  metric = c("Total weeks",
             "Raw ln_aod present",
             "Raw ln_aod missing",
             "Imputed (short-gap filled)",
             "Still missing post-imputation"),
  value  = c(nrow(quito),
             sum(!is.na(quito$ln_aod)),
             sum(is.na(quito$ln_aod)),
             sum(quito$imputed, na.rm = TRUE),
             sum(is.na(quito$ln_aod_imp)))
)

cat("\n=== Question 2: Imputation status of treated unit (Quito, id_uc_g0 = 2544) ===\n")
print(q2_summary)

# Detailed list of imputed weeks in Quito
quito_imputed <- quito %>%
  filter(imputed) %>%
  select(iso_year, iso_week, week_start, aod_mean, ln_aod, ln_aod_imp, post)

cat("\nWeeks imputed in Quito:\n")
if (nrow(quito_imputed) == 0) {
  cat("  None — Quito's series has no short gaps imputed.\n")
} else {
  print(quito_imputed, n = Inf)
}

# Pre vs post split for Quito
quito_split <- quito %>%
  group_by(post) %>%
  summarise(
    n = n(),
    n_imputed = sum(imputed, na.rm = TRUE),
    pct_imputed = round(100 * n_imputed / n, 2),
    .groups = "drop"
  )

cat("\nQuito imputation by treatment period:\n")
print(quito_split)

write_csv(q2_summary,   file.path(OUT_DIR, "quito_imputation_summary.csv"))
write_csv(quito_imputed, file.path(OUT_DIR, "quito_imputed_weeks.csv"))
write_csv(quito_split,   file.path(OUT_DIR, "quito_imputation_by_period.csv"))

cat("\nDiagnostic CSVs written to:", OUT_DIR, "\n")
