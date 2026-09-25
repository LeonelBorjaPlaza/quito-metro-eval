#=========================================================
# master.R
# Full local pipeline. Run from project root.
#
# Workflow:
#   00:    shared setup (libraries, constants, paths)
#   01-02: data ingestion + panel construction (deterministic)
#   03-10: per-pollutant analysis + exports
#   99:    missingness diagnostic
#   11:    descriptives
#   12:    cross-pollutant master + headline figure
#=========================================================

if (!dir.exists("code/local")) {
  stop("Cannot find code/local. Open the .Rproj so the working ",
       "directory is the project root, then re-run.")
}

rm(list = ls())  # clean environment to avoid contamination
t0 <- Sys.time()

# ---- Shared setup ----
#source("code/00_setup.R")

# ---- Data pipeline (deterministic) ----
source("code/local/01_read_and_merge.R")
source("code/local/02_build_weekly_panels.R")

# ---- Per-pollutant analysis (each setup resets seed) ----
source("code/local/03_analysis_setupPM2.5.R");  source("code/local/04_PM2.5.R")
source("code/local/05_analysis_setupCO.R");     source("code/local/06_CO.R")
source("code/local/07_analysis_setupNO2.R");    source("code/local/08_NO2.R")
source("code/local/09_analysis_setupSO2.R");    source("code/local/10_SO2.R")

# ---- Diagnostics + descriptives + cross-pollutant ----
source("code/local/99_missingness_diagnostic.R")
source("code/local/11_descriptives.R")
source("code/local/12_cross_pollutant_master.R")

cat(sprintf("\n=== Full pipeline complete (%.1f min) ===\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))