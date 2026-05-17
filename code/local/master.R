#=========================================================
# master.R
# Full pipeline. Run from project root.
#
# Workflow:
#   01-02: data ingestion + panel construction (deterministic)
#   03-10: per-pollutant analysis + exports
#   99:    missingness diagnostic
#   11:    descriptives
#   12:    cross-pollutant master + headline figure
#=========================================================

rm(list = ls())  # clean environment to avoid contamination

t0 <- Sys.time()

# ---- Data pipeline (deterministic) ----
source("code/01_read_and_merge.R")
source("code/02_build_weekly_panels.R")

# ---- Per-pollutant analysis (each setup resets seed) ----
source("code/03_analysis_setupPM2.5.R");  source("code/04_PM2.5.R")
source("code/05_analysis_setupCO.R");      source("code/06_CO.R")
source("code/07_analysis_setupNO2.R");     source("code/08_NO2.R")
source("code/09_analysis_setupSO2.R");     source("code/10_SO2.R")

# ---- Diagnostics + descriptives + cross-pollutant ----
source("code/99_missingness_diagnostic.R")
source("code/11_descriptives.R")
source("code/12_cross_pollutant_master.R")

cat(sprintf("\n=== Full pipeline complete (%.1f min) ===\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))