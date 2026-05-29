# ============================================================================
#  02_run_CO.R - CO city-level analysis (v4, 2026-05)
# ============================================================================
#  Outcome: ln_co_imp (imputed log of TROPOMI CO weekly mean, from raw).
#  CO is winsorized in panel (co_w) but the imputed outcome uses raw log.
#  Methods handoff: outcome winsorization not applied at analysis stage.
# ============================================================================

source("00_helpers.R")

POLLUTANT   <- "co"
OUTCOME_VAR <- "ln_co_imp"

ROOT       <- Sys.getenv("V4_ROOT", unset = "~/v4_2026_05")
PANEL_CSV  <- file.path(ROOT, "data", "panel_co_balanced.csv")
DONOR_CSV  <- file.path(ROOT, "data", "ucdb_donor_distances_all.csv")
OUT_ROOT   <- file.path(ROOT, "output")

SAMPLES       <- c("pre_blackout", "full", "donut")
N_DONORS_LIST <- c(50, 100, 150, 200, Inf)
B             <- 4

for (f in c(PANEL_CSV, DONOR_CSV)) {
  if (!file.exists(f)) stop(sprintf("Required file missing: %s", f))
}

cat(sprintf("\n=== CO analysis started: %s ===\n", Sys.time()))
cat(sprintf("ROOT: %s\n", ROOT))

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

cross_summary <- bind_rows(all_grand)
cs_path <- file.path(OUT_ROOT, toupper(POLLUTANT), "CrossSample_Summary.csv")
write_csv(cross_summary, cs_path)
cat(sprintf("\nCross-sample summary saved: %s\n", cs_path))

cat(sprintf("\n=== CO analysis complete: %s ===\n", Sys.time()))
