#!/bin/bash
# ============================================================================
#  run_all.sh - Launch all 4 pollutants in parallel via nohup
# ============================================================================
#  Run from ~/v4_2026_05/code/:
#    bash run_all.sh
#
#  Each pollutant runs its 3 samples (pre_blackout, full, donut) sequentially
#  in its own R session. 4 sessions run in parallel, sharing the 8 cores and
#  ~24 GB RAM on the VM.
#
#  After launching: you can close the SSH connection. Jobs continue.
#
#  Monitor progress:
#    tail -f ../logs/AOD_master.log
#    ps aux | grep Rscript
#
#  Check completion:
#    ls -lh ../output/*/CrossSample_Summary.csv
# ============================================================================

set -e
cd "$(dirname "$0")"

mkdir -p ../logs
mkdir -p ../output

echo "================================================================"
echo "Quito Metro Air Quality - City-Level Analysis v4 (2026-05)"
echo "Launching 4 pollutants in parallel"
echo "================================================================"
echo ""

# Optional sanity check: panels exist
for p in aod co no2 so2; do
  if [ ! -f "../data/panel_${p}_balanced.csv" ]; then
    echo "ERROR: ../data/panel_${p}_balanced.csv not found. Upload balanced panel CSVs first."
    exit 1
  fi
done
if [ ! -f "../data/ucdb_donor_distances_all.csv" ]; then
  echo "ERROR: ../data/ucdb_donor_distances_all.csv not found."
  exit 1
fi
echo "All required data files present."
echo ""

# Launch
echo "Launching AOD..."
nohup Rscript 01_run_AOD.R > ../logs/AOD_master.log 2>&1 &
AOD_PID=$!
echo "  AOD PID: $AOD_PID  -> ../logs/AOD_master.log"

echo "Launching CO..."
nohup Rscript 02_run_CO.R  > ../logs/CO_master.log  2>&1 &
CO_PID=$!
echo "  CO PID:  $CO_PID   -> ../logs/CO_master.log"

echo "Launching NO2..."
nohup Rscript 03_run_NO2.R > ../logs/NO2_master.log 2>&1 &
NO2_PID=$!
echo "  NO2 PID: $NO2_PID  -> ../logs/NO2_master.log"

echo "Launching SO2..."
nohup Rscript 04_run_SO2.R > ../logs/SO2_master.log 2>&1 &
SO2_PID=$!
echo "  SO2 PID: $SO2_PID  -> ../logs/SO2_master.log"

echo ""
echo "================================================================"
echo "All 4 jobs launched."
echo "PIDs: AOD=$AOD_PID  CO=$CO_PID  NO2=$NO2_PID  SO2=$SO2_PID"
echo ""
echo "PIDs saved to ../logs/pids.txt"
echo "$AOD_PID $CO_PID $NO2_PID $SO2_PID" > ../logs/pids.txt
echo ""
echo "Monitor with:"
echo "  tail -f ../logs/AOD_master.log"
echo "  watch 'ps aux | grep Rscript | grep -v grep'"
echo ""
echo "Check completion (file appears when each pollutant finishes):"
echo "  ls -lh ../output/*/CrossSample_Summary.csv"
echo ""
echo "When all done, bundle results:"
echo "  bash bundle_results.sh"
echo "================================================================"
