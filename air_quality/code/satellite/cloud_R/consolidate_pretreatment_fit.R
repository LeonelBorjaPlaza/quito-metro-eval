#=========================================================
#  consolidate_pretreatment_fit.R
#  Post-processing of v4 analysis results (NOT a pipeline stage).
#
#  Reads the 60 PreTreatmentFit_*.csv files produced by the v4
#  city-level analysis (4 pollutants x 3 samples x 5 donor pools)
#  and consolidates them into:
#    - PreTreatmentFit_All.csv      comprehensive, every row
#    - PreTreatmentFit_Paper.csv    paper-ready: donut + full,
#                                   top-100, main estimators
#
#  Recalculates nothing. Pure assembly of existing outputs, so the
#  paper's pre-treatment fit table is reproducible and versioned.
#
#  RMSPE_pre  : pre-treatment fit error (lower = better counterfactual)
#  RMSPE_post : post-treatment error
#  Ratio      : RMSPE_post / RMSPE_pre (Abadie post/pre ratio;
#               higher = stronger evidence of an effect)
#  MAE_pre    : pre-treatment mean absolute error
#
#  NOTE on AugSynth_FE: with fixed effects, AugSynth can fit the
#  pre-treatment period almost perfectly (RMSPE_pre near zero,
#  Ratio in the hundreds). That is overfitting, not good fit; its
#  RMSPE_pre is not comparable to the other estimators. It is kept
#  in the comprehensive table but flagged, and excluded from the
#  paper-ready slice.
#=========================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(here)
})

# ---- Paths ----
root_dir     <- here::here()
results_root <- file.path(root_dir, "output", "satellite",
                          "v4_city_level", "output")
out_dir      <- file.path(root_dir, "output", "satellite", "tables")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

if (!dir.exists(results_root)) {
  stop(sprintf("Results folder not found: %s", results_root))
}

# ---- Find every PreTreatmentFit file ----
fit_files <- list.files(results_root, pattern = "^PreTreatmentFit_.*\\.csv$",
                        recursive = TRUE, full.names = TRUE)
cat(sprintf("Found %d PreTreatmentFit files.\n", length(fit_files)))
if (length(fit_files) == 0) stop("No PreTreatmentFit files found.")

# ---- Parse pollutant / sample / donor pool from each path ----
# Path shape: .../output/<POL>/<sample>/tables/PreTreatmentFit_<tag>.csv
parse_meta <- function(path) {
  parts <- str_split(path, "[/\\\\]")[[1]]
  n     <- length(parts)
  pollutant <- parts[n - 3]                       # <POL>
  sample    <- parts[n - 2]                       # <sample>
  tag       <- str_match(parts[n], "PreTreatmentFit_(.*)\\.csv")[, 2]
  # tag is N50 / N100 / N150 / N200 / Nall
  donor_pool <- if (tag == "Nall") Inf else as.numeric(str_remove(tag, "^N"))
  tibble(pollutant = pollutant, sample = sample,
         donor_tag = tag, donor_pool = donor_pool)
}

# ---- Read and stack ----
fit_all <- bind_rows(lapply(fit_files, function(f) {
  meta <- parse_meta(f)
  dat  <- read_csv(f, show_col_types = FALSE)
  bind_cols(meta[rep(1, nrow(dat)), ], dat)
}))

# Tidy: column order, factor levels, AugSynth_FE flag.
pol_levels    <- c("AOD", "CO", "NO2", "SO2")
sample_levels <- c("pre_blackout", "full", "donut")

fit_all <- fit_all %>%
  mutate(
    pollutant   = factor(pollutant, levels = pol_levels),
    sample      = factor(sample, levels = sample_levels),
    fe_overfit_flag = Model == "AugSynth_FE"   # RMSPE_pre not comparable
  ) %>%
  arrange(pollutant, sample, donor_pool, Model) %>%
  select(pollutant, sample, donor_pool, donor_tag, Model,
         RMSPE_pre, RMSPE_post, Ratio, MAE_pre, T_pre, T_post,
         fe_overfit_flag)

write_csv(fit_all, file.path(out_dir, "PreTreatmentFit_All.csv"))
cat(sprintf("Wrote: PreTreatmentFit_All.csv (%d rows)\n", nrow(fit_all)))

# ---- Paper-ready slice ----
# donut + full, top-100, main estimators (AugSynth_FE excluded
# because its RMSPE_pre reflects overfitting, see header note).
fit_paper <- fit_all %>%
  filter(sample %in% c("donut", "full"),
         donor_pool == 100,
         Model %in% c("SDID", "SC", "AugSynth_noFE")) %>%
  select(pollutant, sample, Model, RMSPE_pre, RMSPE_post, Ratio, MAE_pre) %>%
  arrange(pollutant, sample, Model)

write_csv(fit_paper, file.path(out_dir, "PreTreatmentFit_Paper.csv"))
cat(sprintf("Wrote: PreTreatmentFit_Paper.csv (%d rows)\n", nrow(fit_paper)))

cat("\n=== Paper-ready pre-treatment fit ===\n")
print(as.data.frame(fit_paper), digits = 4)

cat("\n=== Consolidation complete ===\n")
cat(sprintf("Tables in: %s\n", out_dir))
