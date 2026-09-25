# ============================================================================
#  01_run_AOD.R - AOD city-level analysis (v4, 2026-05)
# ============================================================================
#  Runs three sample variants (pre_blackout, full, donut). Each variant loops
#  over donor pool sizes {50, 100, 150, 200, all}.
#
#  Outcome: ln_aod_imp (imputed log of MAIAC AOD weekly mean).
#  AOD is NOT winsorized.
#
#  Run:
#    cd ~/v4_2026_05/code/
#    Rscript 01_run_AOD.R
#
#  Or in parallel with the rest via run_all.sh.
# ============================================================================

# --- Source helpers (must be in same directory) ---
source("00_helpers.R")

# --- PARAMS ---
POLLUTANT   <- "aod"
OUTCOME_VAR <- "ln_aod_imp"

ROOT       <- Sys.getenv("V4_ROOT", unset = "~/v4_2026_05")
PANEL_CSV  <- file.path(ROOT, "data", "panel_aod_balanced.csv")
DONOR_CSV  <- file.path(ROOT, "data", "ucdb_donor_distances_all.csv")
OUT_ROOT   <- file.path(ROOT, "output")

SAMPLES       <- c("pre_blackout", "full", "donut")
N_DONORS_LIST <- c(50, 100, 150, 200, Inf)   # Inf = all available donors
B             <- 4

# --- Guard: data files exist ---
for (f in c(PANEL_CSV, DONOR_CSV)) {
  if (!file.exists(f)) {
    stop(sprintf("Required file missing: %s", f))
  }
}

cat(sprintf("\n=== AOD analysis started: %s ===\n", Sys.time()))
cat(sprintf("ROOT: %s\n", ROOT))

# --- Run all three samples ---
all_grand <- list()
for (smp in SAMPLES) {
  res <- run_pollutant_sample(
    POLLUTANT     = POLLUTANT,
    OUTCOME_VAR   = OUTCOME_VAR,
    SAMPLE        = smp,
    N_DONORS_LIST = N_DONORS_LIST,
    B             = B,
    PANEL_CSV     = PANEL_CSV,
    DONOR_CSV     = DONOR_CSV,
    OUT_ROOT      = OUT_ROOT
  )
  all_grand[[smp]] <- res %>% mutate(sample = smp)
}

# --- Cross-sample summary ---
cross_summary <- bind_rows(all_grand)
cs_path <- file.path(OUT_ROOT, toupper(POLLUTANT), "CrossSample_Summary.csv")
write_csv(cross_summary, cs_path)
cat(sprintf("\nCross-sample summary saved: %s\n", cs_path))

cat(sprintf("\n=== AOD analysis complete: %s ===\n", Sys.time()))
