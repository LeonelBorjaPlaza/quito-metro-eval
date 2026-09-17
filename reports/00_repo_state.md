# Repository state: Phase A

Checked 2026-09-17 from a fresh R session. No treatment effect was estimated.

The repository began clean on `main` at `eed6566`. It contains three Waze delivery files, the provider DOCX, the 33-page paper, 22 paper CSVs, and the copied spatial layers. No additional context brief or CLAUDE.md was present in docs/. The frozen inputs remain unchanged; the two text conversions are new.

The paper is `docs/paper/Underground-relief.pdf`. Its CSVs are `results_all_pollutants.csv`, `results_primary_specs.csv`, `results_{PM25,CO,NO2,SO2}.csv`, `trajectories_{PM25,CO,NO2,SO2}.csv`, `donor_weights_{PM25,CO,NO2,SO2}.csv`, `att_weekly_{PM25,CO,NO2,SO2}.csv`, and `descriptives_{sample_construction,summary_stats,time_series_data,treatment_timeline}.csv`, all under `docs/paper/results/`. Every CSV opens. Detailed file counts and source conflicts are in [00_source_checks.md](00_source_checks.md).

`Data/Waze/raw/` contains `grids_polygons.csv` (761,250 bytes), `grids_quito_hourly_2019-2025.csv` (5,612,810,893 bytes), and `grids_quito_hourly_2019-2025.parquet` (939,414,511 bytes). DuckDB opens the Parquet and reads a row; its footer reports 15,080,765 rows in 15 row groups and its schema has 24 columns. CSV/Parquet equivalence, coverage and H3 validity remain Phase B checks.

`Data/spatial/` contains MetroStations as GPKG (15 stations) and SHP/SHX/DBF/PRJ/CPG plus QGIS metadata (the shapefile has 0 records), MetroLine.gpkg (1 alignment feature), and Distancia_REMMAQ_Metro.gpkg (9 monitors). Centro and Belisario are present. Use the GPKG stations, remove unused Z/M in memory, and transform their declared CRS. San Francisco differs from the prompt coordinate by 146.1 metres. Provenance is the authors' copy from the air-quality repository; the QGIS metadata does not identify an upstream author or date.

R 4.5.2 runs on Ubuntu resolute. Available: arrow 25.0.1, duckdb 1.5.5, data.table 1.18.6.1, dplyr 1.2.1, sf 1.0.24, ggplot2 4.0.2, patchwork 1.3.2, fixest 0.14.2. An Arrow read succeeded but one mixed-package session crashed at shutdown; a separate Arrow session with explicit cleanup exited normally. Use DuckDB for the workflow.

Unavailable: h3jsr, synthdid, augsynth. `h3jsr` is blocked by V8's missing system library `libnode.so.127`; DuckDB's prebuilt h3 extension substitutes and loads in a fresh session. `synthdid` and `augsynth` are absent from the requested Posit CRAN index; no estimator is needed in Phase A. Packages use the ignored local library `Output/Waze/_environment/R-library`; scripts add it explicitly. Posit downloads are checked for prebuilt contents before installation. No package was compiled.

The approved layout keeps deliveries in `Data/Waze/raw/`, reserves `Data/Waze/parquet/` for later derived data, and uses `Data/spatial/` for frozen spatial inputs, `docs/` for references, `reports/` for prose and the review sample, `Scripts/Congestion/` for executable R scripts, and `Output/Waze/` for generated checks and figures. The original Parquet stays in raw/ without duplication. `.gitignore` excludes Data/, environment files, and CSVs except `docs/paper/results/*.csv` and `reports/waze_sample.csv`. The sample will be generated and committed in Phase B.

Reproduce with `Rscript Scripts/Congestion/00_orient.R`. Initial setup uses `00_install_packages.R --allow-dependencies` and `00_check_h3.R` in the same script folder. This phase stops at orientation; inventory, descriptives, strategy memo and review packet remain pending.
