# Air quality: how to run the local pipeline

This is the run order from raw REMMAQ data to every local output table, for the frozen May 31, 2026 draft. The satellite design runs on the Google Cloud VM and is not covered here (see `code/satellite/README.md`). Run every command from `air_quality/` in the checkout you are working in. Never point it at another worktree.

## 0. Setup in a fresh checkout

A new worktree has no package library and no derived folders, because git tracks neither. Raw inputs arrive through the committed symlinks `data/raw` and `data/for_maps`, which point into the locked store `/home/leonelb/data/quito-metro-eval/air_quality/raw/`.

```bash
cd air_quality

# Packages: links the 67 lockfile packages from the shared renv cache (seconds once the cache is warm).
# INSTALL_REMOTES=FALSE stops renv from pulling MCPanel, which is outside the lockfile and fails under GCC 15.
RENV_CONFIG_INSTALL_REMOTES=FALSE \
RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/resolute/latest" \
Rscript -e 'renv::restore(prompt = FALSE)'

# Folders the scripts write to
mkdir -p data/processed output/local/tables output/local/figures output/local/crosssample \
         output/local/spatial_placebo output/local/diagnostics output/maps ../logs

# Check that the raw inputs resolve
ls data/raw/remmaq/PM2.5.xlsx data/for_maps/MetroLine.gpkg
```

Only for Figure 1 (step 7), add the map packages, which the lockfile does not record:

```bash
RENV_CONFIG_INSTALL_REMOTES=FALSE \
RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/resolute/latest" \
Rscript -e 'renv::install(c("sf","ggrepel","ggspatial","maptiles","rnaturalearth","tidyterra"), prompt = FALSE)'
```

`here::here()` resolves to `air_quality/` through the empty `.here` file, so the working directory only needs to be inside `air_quality/`.

## How the scripts depend on each other

- `01` and `02` are standalone and write files.
- Each pollutant block is one R session. The setup script (`03`, `05`, `07`, `09`) leaves `df`, `t_int`, `blackout_week_ids` and other objects in memory. The model script (`04`, `06`, `08`, `10`) and the cross-sample script read those objects, not files. The PM2.5 spatial placebo `04b` also needs `m8b` and `run_augsynth` from `04_PM2.5.R`. Running a later script without its setup in the same session stops with "Missing required objects".
- Every setup, cross-sample and placebo script calls `set.seed(12345)` at its top, so each block gives the same numbers whether it runs alone or after other blocks.
- `master.R` runs `01`, `02`, the four setup and model pairs, `99`, `11` and `12`. It does **not** run the cross-sample scripts, the spatial placebos or the publication figure, which were never committed to the old repository. The steps below cover all of them.

## 1. Hourly panel

```bash
Rscript -e 'source("code/local/01_read_and_merge.R")' > ../logs/aq_01.log 2>&1
```

- Reads `data/raw/remmaq/{PM2.5,CO,NO2,SO2,TMP,HUM,VEL,DIR,LLU,RS,PRE}.xlsx`.
- Writes `data/processed/hourly_panel.csv`.

## 2. Weekly panels

```bash
Rscript -e 'source("code/local/02_build_weekly_panels.R")' > ../logs/aq_02.log 2>&1
```

- Reads `data/processed/hourly_panel.csv`.
- Writes `data/processed/pm25_completepanel_peakweekly.csv`, `CO_completepanel_peakweekly.csv`, `NO2_completepanel_peakweekly.csv` and `SO2_completepanel_peakweekly.csv`.

## 3. PM2.5 (the headline; run first)

```bash
Rscript -e 'for (f in c("03_analysis_setupPM2.5.R", "04_PM2.5.R", "04_PM2_5_crosssample.R",
                        "04b_spatial_placebo_PM25_M8b_conformalp.R", "04c_spatial_placebo_PM25_M5b_conformalp.R",
                        "fig_pm25_eventstudy_pub.R")) source(file.path("code/local", f))' > ../logs/aq_pm25.log 2>&1
```

- `04_PM2.5.R`, the twelve-specification battery on the full panel, writes `output/local/tables/{results,donor_weights,trajectories,att_weekly}_PM25.csv` and `output/local/figures/event_study_PM25_{M5b,M8b,M2b}.png`.
- `04_PM2_5_crosssample.R` re-estimates each specification separately on the three samples (pre_blackout, donut, full) and writes `output/local/crosssample/CrossSample_Summary_PM25.csv`. This is the source of the paper's three-sample tables.
- `04b` and `04c` write `output/local/spatial_placebo/spatial_placebo_PM25_{M8b,M5b}_conformalp.csv` and `_log.txt`.
- `fig_pm25_eventstudy_pub.R` reads `att_weekly_PM25.csv` and `CrossSample_Summary_PM25.csv` and writes `output/local/figures/fig_pm25_eventstudy.{png,pdf}`.

## 4. Gases (CO, NO2, SO2)

```bash
Rscript -e 'for (f in c("05_analysis_setupCO.R","06_CO.R","06_CO_crosssample.R")) source(file.path("code/local", f))'   > ../logs/aq_co.log 2>&1
Rscript -e 'for (f in c("07_analysis_setupNO2.R","08_NO2.R","08_NO2_crosssample.R")) source(file.path("code/local", f))' > ../logs/aq_no2.log 2>&1
Rscript -e 'for (f in c("09_analysis_setupSO2.R","10_SO2.R","10_SO2_crosssample.R")) source(file.path("code/local", f))' > ../logs/aq_so2.log 2>&1
```

- Each writes `output/local/tables/{results,donor_weights,trajectories,att_weekly}_<POL>.csv`, `output/local/figures/event_study_<POL>_{M5b,M8b,M2b}.png` and `output/local/crosssample/CrossSample_Summary_<POL>.csv`.
- The three blocks are independent of each other and of PM2.5, so they can run in parallel.

## 5. Diagnostics and descriptives

```bash
Rscript -e 'source("code/local/99_missingness_diagnostic.R")' > ../logs/aq_99.log 2>&1
Rscript -e 'source("code/local/11_descriptives.R")'           > ../logs/aq_11.log 2>&1
```

- `99` reads the hourly and weekly panels and writes `output/local/diagnostics/missingness_{PM25,CO,NO2,SO2}.csv`.
- `11` reads the same panels and writes `output/local/tables/descriptives_{summary_stats,sample_construction,treatment_timeline,time_series_data}.csv` and `output/local/figures/descriptives_time_series.{png,pdf}`.

## 6. Cross-pollutant master (after steps 3 and 4)

```bash
Rscript -e 'source("code/local/12_cross_pollutant_master.R")' > ../logs/aq_12.log 2>&1
```

- Reads `results_*.csv` and `att_weekly_*.csv` for all four pollutants.
- Writes `output/local/tables/results_all_pollutants.csv`, `results_primary_specs.csv` and `output/local/figures/headline_event_study_M5b.{png,pdf}`.

## 7. Figure 1 map (optional, needs the map packages and network access)

```bash
Rscript -e 'source("code/local/fig1_metro_airquality_map.R")' > ../logs/aq_fig1.log 2>&1
```

- Reads `data/for_maps/*.gpkg` and downloads basemap tiles, so the image is not bit-for-bit reproducible.
- Writes `output/maps/fig1_metro_airquality_map.{png,pdf}`.

## Outputs that no script produces

These files sit in the frozen reference (`/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29/output/local/`), but no script in this repository writes them: `blackout_comparison/{augsynth_vs_sdid_comparison.csv, sdid_blackout_comparison.pdf, sdid_blackout_comparison.png}` (the README calls them pre-pipeline diagnostics), `tables.zip`, `figures/descriptives_time_series_edit.png` and `spatial_placebo/spatial_placebo_PM25_M8b_noCentroDonor.pdf`.

## Run times

Measured in the Phase 6 replication gate (`reports/migration/06_replication_gate.md`) on the WSL machine described in `ENVIRONMENT.md`:

<!-- RUNTIMES -->
