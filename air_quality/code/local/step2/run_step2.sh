#!/usr/bin/env bash
# Step 2 of the air quality revision: every run, in order, with its switches
# (air_quality/docs/revision_plan.md, 3A). Run from air_quality/ after the
# RUNBOOK setup step. Logs go to ../logs/. Stages can be run one at a time:
#   bash code/local/step2/run_step2.sh panels|check|main|sens|diag|compare|all
set -euo pipefail
cd "$(dirname "$0")/../../.."          # air_quality/
L=../logs
mkdir -p "$L" data/processed output/local/tables output/local/figures output/local/crosssample \
         output/local/spatial_placebo output/local/diagnostics output/local/step2
stage="${1:-all}"

r() { Rscript -e "$1"; }
# Background jobs: wait on each PID so a failed run stops the script (set -e)
pids=()
waitall() { local p; for p in "${pids[@]}"; do wait "$p"; done; pids=(); }
pm25_block='for (f in c("03_analysis_setupPM2.5.R","04_PM2.5.R","04_PM2_5_crosssample.R","04b_spatial_placebo_PM25_M8b_conformalp.R","04c_spatial_placebo_PM25_M5b_conformalp.R","fig_pm25_eventstudy_pub.R")) source(file.path("code/local", f))'

if [[ $stage == panels || $stage == all ]]; then
  # Main specification (B3: panels cut at the week starting 2025-06-16)
  r 'source("code/local/01_read_and_merge.R")'      > $L/aq_s2_01.log 2>&1
  r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_main.log 2>&1
  # Sensitivity panels (3A.2)
  AQ_SENS=S1 AQ_PANEL_END=none AQ_EXCLUDE=guamani,sanantonio \
    r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_S1.log 2>&1
  AQ_SENS=S2a AQ_EXCLUDE=loschillos \
    r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_S2a.log 2>&1
  AQ_SENS=S2b AQ_LC_SHIFT_FROM=2024-12-01 \
    r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_S2b.log 2>&1
  AQ_SENS=S3 AQ_MIN_HALF=1 \
    r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_S3.log 2>&1
  AQ_SENS=S4 \
    r 'source("code/local/02_build_weekly_panels.R")' > $L/aq_s2_02_S4.log 2>&1   # same as main; S4 acts in setup
fi

if [[ $stage == check || $stage == all ]]; then
  # Check 4.4, before any estimate
  Rscript code/local/step2/sa_imputation_check.R > $L/aq_s2_sa_check.log 2>&1
fi

if [[ $stage == main || $stage == all ]]; then
  # RUNBOOK steps 3 to 6, main specification; the four blocks run in parallel
  r "$pm25_block" > $L/aq_s2_pm25.log 2>&1 & pids+=($!)
  r 'for (f in c("05_analysis_setupCO.R","06_CO.R","06_CO_crosssample.R")) source(file.path("code/local", f))'    > $L/aq_s2_co.log 2>&1 & pids+=($!)
  r 'for (f in c("07_analysis_setupNO2.R","08_NO2.R","08_NO2_crosssample.R")) source(file.path("code/local", f))' > $L/aq_s2_no2.log 2>&1 & pids+=($!)
  r 'for (f in c("09_analysis_setupSO2.R","10_SO2.R","10_SO2_crosssample.R")) source(file.path("code/local", f))' > $L/aq_s2_so2.log 2>&1 & pids+=($!)
  waitall
  r 'source("code/local/99_missingness_diagnostic.R")'  > $L/aq_s2_99.log 2>&1
  r 'source("code/local/11_descriptives.R")'            > $L/aq_s2_11.log 2>&1
  r 'source("code/local/12_cross_pollutant_master.R")'  > $L/aq_s2_12.log 2>&1
fi

if [[ $stage == sens || $stage == all ]]; then
  pm='for (f in c("03_analysis_setupPM2.5.R","04_PM2_5_crosssample.R")) source(file.path("code/local", f))'
  co='for (f in c("05_analysis_setupCO.R","06_CO_crosssample.R")) source(file.path("code/local", f))'
  no='for (f in c("07_analysis_setupNO2.R","08_NO2_crosssample.R")) source(file.path("code/local", f))'
  so='for (f in c("09_analysis_setupSO2.R","10_SO2_crosssample.R")) source(file.path("code/local", f))'
  PM_SPECS="M7,M9,M8,M8b"; GAS_SPECS="M8b"
  for s in S1 S3 S4; do
    extra=""; [[ $s == S4 ]] && extra="AQ_DROP_RATIONING=1"
    env AQ_SENS=$s AQ_SPECS=$PM_SPECS  $extra Rscript -e "$pm" > $L/aq_s2_${s}_pm25.log 2>&1 & pids+=($!)
    env AQ_SENS=$s AQ_SPECS=$GAS_SPECS $extra Rscript -e "$co" > $L/aq_s2_${s}_co.log 2>&1 & pids+=($!)
    env AQ_SENS=$s AQ_SPECS=$GAS_SPECS $extra Rscript -e "$no" > $L/aq_s2_${s}_no2.log 2>&1 & pids+=($!)
    env AQ_SENS=$s AQ_SPECS=$GAS_SPECS $extra Rscript -e "$so" > $L/aq_s2_${s}_so2.log 2>&1 & pids+=($!)
    waitall
  done
  env AQ_SENS=S2a AQ_SPECS=$PM_SPECS Rscript -e "$pm" > $L/aq_s2_S2a_pm25.log 2>&1 & pids+=($!)
  env AQ_SENS=S2b AQ_SPECS=$PM_SPECS Rscript -e "$pm" > $L/aq_s2_S2b_pm25.log 2>&1 & pids+=($!)
  waitall
fi

if [[ $stage == diag || $stage == all ]]; then
  for p in "03_analysis_setupPM2.5.R:pm25" "05_analysis_setupCO.R:co" "07_analysis_setupNO2.R:no2" "09_analysis_setupSO2.R:so2"; do
    setup=${p%%:*}; tag=${p##*:}
    r "source('code/local/$setup'); source('code/local/step2/centro_diagnostics.R')" > $L/aq_s2_diag_$tag.log 2>&1 & pids+=($!)
  done
  Rscript code/local/step2/ddd_centro.R > $L/aq_s2_ddd.log 2>&1 & pids+=($!)
  waitall
fi

if [[ $stage == compare || $stage == all ]]; then
  Rscript code/local/step2/old_vs_new.R > $L/aq_s2_compare.log 2>&1
fi
echo "step 2 stage '$stage' finished"
