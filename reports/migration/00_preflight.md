# Phase 0. Preflight (read-only), 2026-09-24

## Result

Every path in `settings.env` exists except `NEW_REPO`, which this migration creates. `DATA_STORE` existed and was empty, so this is a fresh run and nothing had to be resumed. The ten largest OneDrive files read in full from disk, there is enough free space, both Excel deliveries match their expected sha256, and the network reaches CRAN, Posit Package Manager and GitHub. No hard stop applies.

## Settings and new data

| Setting | Path | State |
|---|---|---|
| NEW_REPO | `/home/leonelb/projects/quito-metro-eval` | absent before Phase 1 |
| DATA_STORE | `/home/leonelb/data/quito-metro-eval` | existed, empty |
| AQ_SRC | `/mnt/c/Users/LEONELB/OneDrive - Inter-American Development Bank Group/quito-metro-airquality-2026` | exists |
| WAZE_SRC | `/home/leonelb/projects/waze-metroq` | exists |
| NEW_DATA | `/mnt/c/Users/LEONELB/Downloads/quito-new-data` | exists, 4 files |
| KIT | `/home/leonelb/quito-metro-kit` | exists |
| GITHUB_REPO | `LeonelBorjaPlaza/quito-metro-eval` | owner matches `gh api user -q .login` |
| GCP_VM_SSH | empty | satellite VM snapshot skipped (pending for Leonel) |

`NEW_DATA` holds the four expected files:

| File | Bytes | sha256 | Expected (provenance note) |
|---|---|---|---|
| `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx` | 29,808 | `a1a08e5b99a64b93942950d6101d2ce8e91fb73d8362331b960eebdbe821eaa3` | match |
| `REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx` | 4,874,225 | `1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18` | match |
| `RE Solicitud de datos de siniestros de tránsito del DMQ para la evaluación de impacto del Metro de Quito.msg` | 5,145,600 | | |
| `Solicitud de revisión del paper de calidad del aire PLMQ.msg` | 165,376 | | |

## Free space and sizes

- `df -h $HOME`: 1007G, 930G available (WSL virtual disk).
- `df -h /mnt/c`: 475G, 241G available. This is the real limit, since the WSL disk file lives on C:.
- `du -sh`: AQ_SRC 5.7G (of which `.venv` about 0.37G and satellite data about 5.2G), WAZE_SRC 6.6G (of which the raw Waze CSV is 5.6G).
- Threshold: twice the data to copy plus 20 GB is at most 2 × 12.3G + 20G = 44.6G, well below 241G.

## AQ_SRC git state

Full output: `reports/migration/00_gitstate_aq_src.txt`, produced by `reports/migration/gitstate.sh aq` (read-only, `git --no-optional-locks -c core.autocrlf=true -c core.filemode=false`).

- Branch `main` at `64eb72a` (2026-05-29, "Add Figure 1: Metro Line 1 alignment and REMMAQ monitoring stations"). It is the only local branch and matches `origin/main`.
- Remote `origin` = `https://github.com/LeonelBorjaPlaza/quito-metro-airquality-2026.git`. No unpushed commits. No stashes.
- 131 tracked files.
- Modified tracked file: `output/local/figures/descriptives_time_series.pdf`.
- 793 untracked, non-ignored files. The ones that matter:
  - Seven code files, among them the **cross-sample scripts that produce the paper's three-sample tables**: `code/local/04_PM2_5_crosssample.R`, `06_CO_crosssample.R`, `08_NO2_crosssample.R`, `10_SO2_crosssample.R`, the spatial placebo scripts `04b_spatial_placebo_PM25_M8b_conformalp.R` and `04c_spatial_placebo_PM25_M5b_conformalp.R`, and `fig_pm25_eventstudy_pub.R`. None of them were ever committed.
  - Their outputs: `output/local/crosssample/CrossSample_Summary_{PM25,CO,NO2,SO2}.csv`, `output/local/spatial_placebo/*`, `output/local/figures/fig_pm25_eventstudy.{pdf,png}`, `output/maps/fig1_*`.
  - Satellite outputs: `output/satellite/tables/D2..D6, F1, F2, PreTreatmentFit_*`, `output/satellite/figures/F1, F2`, and about 750 files under `output/satellite/v4_city_level/` (AOD, CO, NO2 and SO2 by sample: graphs, tables and logs).
  - `data/traffic-accidents/Copy of REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx` and the AMT email `.msg`, a copy of the new crash delivery that is not ignored in this repository.
- 10,783 ignored files, 5.89 GB in total. Grouped: `data/processed/satellite` (21 files, 3.43 GB), `data/raw/satellite` (76 files, 1.82 GB), `data/raw/remmaq` (17 files, 113 MB), `data/processed/hourly_panel.csv` (83 MB), `data/raw/GHS_UCDB` (4 files, 57 MB), four weekly local panels in `data/processed/`, nine map layers in `data/for_maps/`, `output/local/tables.zip`, plus `.venv/` (Windows Python, 368 MB), `renv/library/windows` (15 MB), `.Rproj.user/`, `.RData` and `.Rhistory`.
- `data/raw/remmaq/` also holds `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx` and `Solicitud de revisión del paper de calidad del aire PLMQ .msg` (dated 2026-09-24), which are copies of the Secretaría delivery. The pipeline does not read them.

### Proof that the files are on disk

The ten largest files (all in `data/processed/satellite/`, 157 to 371 MB each) were read in full with `sha256sum` in 27 seconds. None failed. The only empty files are `.gitkeep` placeholders and a few zero-byte metadata files inside `.venv` and `.Rproj.user`.

| Bytes | sha256 | File |
|---|---|---|
| 370,862,903 | `26b328028064dd4a6b63a011187b5ccf43c48e9360579632c27a652da97bf874` | `data/processed/satellite/no2_weekly.csv` |
| 366,468,608 | `88d99ea966448ceee234efcb0c063e0fa103dddb169a8c4d0463980cc19b60ba` | `data/processed/satellite/aod_weekly.csv` |
| 357,143,336 | `165331cf78810cd97faa108fca0d73e8a52cd0740407a821fc7d04fd372a5b28` | `data/processed/satellite/so2_weekly.csv` |
| 342,637,193 | `428f7048370ed6d97ca56c4abc40984b6a5324a28d7021073659429316ec95a5` | `data/processed/satellite/co_weekly.csv` |
| 333,087,862 | `d569d0ea402a742bce1fa82394978a97c220df93079a9420409b3913e113244e` | `data/processed/satellite/era5l_weekly.csv` |
| 182,191,592 | `5d49c7289c2d9b54516f3cda3a345a2d321ea68ff6c81c9b60733e3e4c7f8c2f` | `data/processed/satellite/panel_no2.csv` |
| 170,489,592 | `4e0a6dfdcb46ace94b6156017bcf0a9019df39ef96d9ebcbb661642d15ce16ea` | `data/processed/satellite/panel_so2.csv` |
| 167,988,520 | `d98c0f9a1f11ee7599cd79aa4dbfcc274fdbe942920b4bc3c33db3460a34a7c4` | `data/processed/satellite/panel_aod.csv` |
| 160,159,014 | `8de71ae0403c107534132980f5f5a22ba49a31c12487f4a0bf3f0c9acd974562` | `data/processed/satellite/panel_no2_balanced.csv` |
| 157,304,909 | `ac919e16b748db63c6fcf315c28bd97bb0a47edb6382ead113fa79ef2dcd7cbb` | `data/processed/satellite/panel_co.csv` |

## WAZE_SRC git state

Full output: `reports/migration/00_gitstate_waze_src.txt`.

- Branch `main` at `121a6a6` (2026-09-17, "Review packet: hand off Waze evidence, options, and session status"). Six commits, no other branches, **no remote**, no stashes.
- 91 tracked files. Untracked, non-ignored: `docs/analysis_plan_v1_2026-09-17.md` and `docs/analysis_plan_v2.md`. **The Step 1 v2 prompt is not in the repository** (searched WAZE_SRC and Downloads).
- 1,549 ignored files, 7.02 GB: `Data/Waze/raw/` (the delivery: CSV 5.61 GB, Parquet 0.94 GB, `grids_polygons.csv`, `roadlengths_quito.csv`), `Data/Waze/parquet/` (two deduplicated blocks and a manifest, derived), `Data/spatial/` (nine map layers), `Output/Waze/inventory/*.csv` (derived), and `Output/Waze/_environment/` (a project-local R library, 179 MB, duckdb h3 extension, package archives).
- Data files that the history has committed (they would travel into the new repository):
  - `reports/waze_sample.csv`: 500 record-level rows of the Waze delivery (date, grid_id, hour, roadtype and every indicator), 196 KB. **This is raw provider data in history.**
  - 19 `.rds` files under `Output/Waze/` (inventory, descriptives, planning), aggregated outputs.
  - 22 CSVs under `docs/paper/results/`, copies of the air quality paper's output tables, and the paper PDF `docs/paper/Underground-relief.pdf`.

## Machine-specific paths and working-directory assumptions

AQ_SRC (code only, excluding `.venv`, `renv/`, `data/` and `output/`):

- **Absolute Windows path**: `code/local/fig1_metro_airquality_map.R:40` sets `PROJECT_ROOT <- "C:/Users/LEONELB/OneDrive - Inter-American Development Bank Group/quito-metro-airquality-2026"`.
- **Case-only filename mismatch that works only on Windows**: `code/local/05_analysis_setupCO.R:33` reads `co_completepanel_peakweekly.csv`, while `02_build_weekly_panels.R:473` writes `CO_completepanel_peakweekly.csv`. Linux file names are case-sensitive, so this fails in WSL.
- `here::here()` sets the root in `01`, `02`, `03`, `05`, `07`, `09`, `11`, `12`, `99` and `fig_pm25_eventstudy_pub.R` (local), and in `cloud_R/05_descriptives.R`, `cloud_R/consolidate_pretreatment_fit.R` and six `laptop_R` scripts (satellite). The root is found through `quito-metro-airquality-2026.Rproj`.
- `master.R:14` requires the working directory to be the project root (`code/local` must exist) and sources `code/local/...` paths.
- `.Rprofile:1` sources `renv/activate.R`, and `code/00_setup.R` initializes renv.
- Python scripts find the root with `Path(__file__).resolve().parents[3]`, which is relative.
- Windows line endings (CRLF) in the working copy: `00_setup.R`, `01`, `03`, `04`, `05`, `06`, `07`, `08`, `09`, `10`, `master.R`. Git stores them with LF (`.gitattributes` sets `eol=lf`), so the imported history is clean. The untracked scripts are already LF.

WAZE_SRC: no hits. Scripts use paths relative to the repository root (`Data/...`, `Output/Waze/...`) and prepend the project-local library `Output/Waze/_environment/R-library` to `.libPaths()`.

## Environment

| Item | Finding |
|---|---|
| OS | Ubuntu 26.04 LTS (resolute), WSL2, 15 GB RAM, 8 cores |
| R | 4.5.2 (2025-10-31), `/usr/bin/R` |
| R packages, system library | sf 1.0-24, ggplot2 4.0.2, DBI 1.2.3. **Missing**: augsynth, synthdid, fixest, duckdb, data.table, tidyverse (dplyr, readr, tidyr, stringr, lubridate), readxl, patchwork, here, renv, arrow, remotes |
| R packages, congestion project library | `WAZE_SRC/Output/Waze/_environment/R-library`: duckdb 1.5.5, arrow 25.0.1, data.table 1.18.6.1, dplyr 1.2.1, fixest 0.14.2, patchwork and others (Posit binaries). V8 fails to load (libnode.so.127 missing), so h3jsr is unavailable. The congestion session's `package_status.txt` says augsynth and synthdid were "Unavailable in the requested Posit CRAN repository". |
| Python | 3.14.6. pandas 3.0.6 and openpyxl 3.1.5 installed; duckdb, geopandas and h3 not installed |
| duckdb CLI | not installed |
| rsync | `/usr/bin/rsync` |
| Stata | `stata-mp` and `stata` binaries in `/home/leonelb/` (not used by the pipelines here) |
| gh | 2.46.0, logged in as `LeonelBorjaPlaza` (scopes gist, read:org, repo, workflow) |
| gcloud | not installed |
| git | 2.53.0, `git subtree` available |
| Network | HTTP 200 from packagemanager.posit.co (resolute binaries), cloud.r-project.org, api.github.com, codeload.github.com |

## Satellite code

In `AQ_SRC/code/satellite/`: `cloud_R/` (the SDID and augsynth runs `01_run_AOD.R` to `04_run_SO2.R`, `00_helpers.R`, `05_descriptives.R`, `consolidate_pretreatment_fit.R`, `run_all.sh`, `bundle_results.sh`, `balance_panels_archive.R`), `laptop_R/` (ERA5 cleaning, panel construction, balancing, donor pool selection in Python) and `python/` (Earth Engine exports and merge). The run scripts read `data/panel_*_balanced.csv` and `data/ucdb_donor_distances_all.csv` relative to a VM root, not this repository's layout. The authoritative copy is on the VM (`~/v4_2026_05/code/`), which this session cannot reach (`GCP_VM_SSH` is empty and gcloud is not installed).

## Notes carried forward

1. The four cross-sample scripts and the two spatial placebo scripts exist only as uncommitted files. They enter the new repository in Phase 2's snapshot commit.
2. `reports/waze_sample.csv` in the congestion history holds raw Waze records. Phase 7 has to stop the push unless Leonel decides to strip it from the history.
3. The CO case mismatch and the Windows path in the map script must be fixed for the pipeline to run in WSL. Both fall under the allowed path edits.
