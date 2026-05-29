# Quito Metro Air Quality — City-Level Analysis v4 (2026-05)

R pipeline for the city-level (satellite) analysis of the Quito Metro Line
1 effect on air quality, using SDID + SC + AugSynth on Mahalanobis-trimmed
donor pools from the UCDB. Three pollutants in main paper (AOD, CO) +
appendix (NO2) + placebo (SO2).

## Methodology summary

- Treatment week: ISO 2023-W48 (consistent with local pipeline).
- Three samples: `pre_blackout` (drop from 2024-09-15), `full` (everything),
  `donut` (drop 2024-09-15 to 2024-12-31). Donut PRIMARY for SDID.
- Residualization (split FWL):
  - SDID: full residualization (13 ERA5 `_w` controls + city × month FE).
  - AugSynth: month-FE-only outcome + FWL-residualized covariates on RHS.
- Block aggregation B=4 (non-overlapping, aligned to t_int).
- Donor pool sizes per sample: 50, 100, 150, 200, all (Mahalanobis-ranked).
- Estimators: SDID (primary), SC (robustness), AugSynth no FE, AugSynth FE.
- Inference: one-sided p reported only when ATT < 0 (pollution-reduction
  prior); two-sided always reported.
- Sub-period decomposition (AugSynth): P1, P2, blackout, clean, overall
  from weekly ATT vector indexed by block period IDs.

## Folder layout on the VM (`~/v4_2026_05/`)

```
v4_2026_05/
├── code/
│   ├── 00_helpers.R
│   ├── 01_run_AOD.R
│   ├── 02_run_CO.R
│   ├── 03_run_NO2.R
│   ├── 04_run_SO2.R
│   ├── run_all.sh
│   ├── bundle_results.sh
│   └── README.md
├── data/
│   ├── panel_aod.csv
│   ├── panel_co.csv
│   ├── panel_no2.csv
│   ├── panel_so2.csv
│   └── ucdb_donor_distances_all.csv
├── output/         # created by scripts
└── logs/           # created by run_all.sh
```

## Setup (one-time)

1. **Confirm R packages installed** on the VM:
   ```bash
   Rscript -e "pkgs <- c('dplyr','readr','tibble','tidyr','stringr','lubridate','synthdid','augsynth','fixest','ggplot2','patchwork','scales'); installed <- pkgs %in% rownames(installed.packages()); print(data.frame(pkg=pkgs, installed=installed))"
   ```
   If any missing, install them. `synthdid` and `augsynth` may need GitHub
   installs (`remotes::install_github("synth-inference/synthdid")` and
   `remotes::install_github("ebenmichael/augsynth")`).

2. **Upload code and data** to the VM. From the SSH ⚙ menu → Upload file.
   Or use `gsutil cp` if you have a GCS bucket.

   Code goes in `~/v4_2026_05/code/`. Data goes in `~/v4_2026_05/data/`.

3. **Make scripts executable** (one-time):
   ```bash
   chmod +x ~/v4_2026_05/code/run_all.sh
   chmod +x ~/v4_2026_05/code/bundle_results.sh
   ```

## Run

From the SSH terminal:

```bash
cd ~/v4_2026_05/code/
bash run_all.sh
```

That launches 4 parallel `nohup` jobs. You can close the SSH window; jobs
continue. Each pollutant runs its 3 samples sequentially; total wall time
estimate: 2-4 hours depending on donor pool sizes and AugSynth convergence.

## Monitor

```bash
tail -f ~/v4_2026_05/logs/AOD_master.log     # live log
watch 'ps aux | grep Rscript | grep -v grep' # process status
ls -lh ~/v4_2026_05/output/*/CrossSample_Summary.csv  # appears when each pollutant done
```

## Single-pollutant rerun (debugging)

If one pollutant fails or you want to rerun:

```bash
cd ~/v4_2026_05/code/
nohup Rscript 02_run_CO.R > ../logs/CO_master.log 2>&1 &
```

## Download results

When all 4 pollutants complete:

```bash
cd ~/v4_2026_05/code/
bash bundle_results.sh
```

This creates `~/v4_2026_05/v4_results_<YYYYMMDD_HHMM>.tar.gz`. Download via
GCP SSH ⚙ → Download file → paste the full path.

## Output structure

```
output/
├── AOD/
│   ├── pre_blackout/
│   │   ├── tables/
│   │   │   ├── Summary_N50.csv
│   │   │   ├── Summary_N100.csv
│   │   │   ├── ...
│   │   │   ├── Summary_Nall.csv
│   │   │   ├── Weights_*.csv
│   │   │   ├── Trajectories_*.csv
│   │   │   ├── PreTreatmentFit_*.csv
│   │   │   ├── GrandSummary.csv
│   │   │   └── ResidualizationDiagnostics.csv
│   │   └── graphs/
│   │       ├── Trajectory_SDID_N100.png
│   │       ├── EventStudy_SDID_N100.png
│   │       └── ...
│   ├── full/
│   ├── donut/
│   └── CrossSample_Summary.csv
├── CO/
├── NO2/
└── SO2/
```

Key file for paper tables: `CrossSample_Summary.csv` per pollutant. Combines
all (sample × donor pool size × method) ATTs, p-values, CIs, fit
diagnostics in one tibble.

## Reproducibility

`set.seed(12345)` at top of helpers. Placebo SE for SDID uses 300
replications.

## Local laptop run (optional)

For a local test before cloud upload:

```bash
cd <repo-root>
V4_ROOT=. Rscript code/01_run_AOD.R
```

That overrides the default `~/v4_2026_05` and reads from the current
directory. Assumes panels are at `data/panel_*.csv` and
`data/ucdb_donor_distances_all.csv`.
