# Phase 2. Code with its history, 2026-09-24

## Result

Both repositories now sit under their module folders with their full history, through a non-squashed `git subtree add`. The uncommitted work of both sources is in one snapshot commit. The satellite VM snapshot was skipped because `GCP_VM_SSH` is empty.

## What was done

1. Air quality: `git remote add aq-src "$AQ_SRC"`, `git fetch --no-tags aq-src`, `git subtree add --prefix=air_quality aq-src/main` (merge commit `a1cb963`), then `git remote remove aq-src`. Imported branch `main` at `64eb72a`.
2. Congestion: the same with `WAZE_SRC` and the prefix `congestion` (merge commit `dcea3c0`). Imported branch `main` at `121a6a6`.
3. Other branches: none. AQ_SRC has only `main` (and `origin/main` at the same commit). WAZE_SRC has only `main`. Nothing was left behind.
4. Uncommitted work (commit `033f40e`, "Snapshot of uncommitted work in both sources on 2026-09-24"):
   - `air_quality/code/local/04_PM2_5_crosssample.R`, `06_CO_crosssample.R`, `08_NO2_crosssample.R`, `10_SO2_crosssample.R`, `04b_spatial_placebo_PM25_M8b_conformalp.R`, `04c_spatial_placebo_PM25_M5b_conformalp.R`, `fig_pm25_eventstudy_pub.R` (untracked in the source; already LF).
   - `air_quality/output/local/spatial_placebo/spatial_placebo_PM25_{M5b,M8b}_conformalp_log.txt` (untracked `.txt`; CRLF removed).
   - `air_quality/output/local/figures/descriptives_time_series.pdf` (modified tracked file in the source).
   - `congestion/docs/analysis_plan_v1_2026-09-17.md` and `congestion/docs/analysis_plan_v2.md` (untracked in the source).
   - Every other untracked file (CSV, PNG, PDF, logs, the crash-data copy and its email) goes through the Phase 3 classification, not into git.
5. Satellite VM snapshot: skipped, `GCP_VM_SSH` is empty and `gcloud` is not installed. Added to the pending list.
6. Not found: the congestion Step 1 v2 prompt. It is not in WAZE_SRC; Leonel needs to supply it for workstream B.

## History

The repository has 50 commits and 249 tracked files after this phase.

```
* 033f40e Snapshot of uncommitted work in both sources on 2026-09-24
*   dcea3c0 Import congestion repository (waze-metroq, main at 121a6a6) under congestion/ with full history
|\  
| * 121a6a6 Review packet: hand off Waze evidence, options, and session status
| * 1602fb6 Phase D: propose congestion design options and pre-only power scenarios
| * 84cf7e2 Phase C: describe fixed Waze panels, donor coverage, and data artifacts
| * 16fbfa9 Phase B: inventory Waze delivery, validate H3 groups, and audit coverage
| * eaf0adf Phase A: document Waze repository, reconcile sources, and verify binary tooling
| * eed6566 Seed congestion module: Waze delivery, documentation, paper PDF, air quality results
*   a1cb963 Import air quality repository (quito-metro-airquality-2026, main at 64eb72a) under air_quality/ with full history
|\  
| * 64eb72a Add Figure 1: Metro Line 1 alignment and REMMAQ monitoring stations
| * 3970477 Fix LOCAL San Antonio imputation: use San Antonio's own weather
| * 0d44305 Archive VM-side balance_panels.R as balance_panels_archive.R
| * f65d6b2 Add SATELLITE code: estimation + data construction layers
| * b016b64 Regenerate LOCAL outputs from corrected W48 pipeline
| * 7b725e4 Fix LOCAL pipeline: REMMAQ data format, treatment week W49->W48, rank-based placebo inference, descriptives timeline
| * 1e5c9d8 Add satellite descriptives: D2-D6 tables and F1-F2 figures for data section
| * 4c2a88d Patch save_iteration_outputs: explicit if-else, type coercion, tryCatch wrappers
| * 35d183b Stage 4 SO2 panel: use asinh transform to handle negative TROPOMI retrievals
| * 3f93087 Add Stage 4 SO2 panel (R port, placebo outcome for falsification test)
| * 95498a4 Add Stage 4 NO2 panel (R port of 4_NO2_panel.do; validated)
| * ff2127c Add Stage 4 CO panel (R port of 4_CO_panel.do; validated)
| * de70561 Add AOD imputation diagnostic outputs
| * c264f39 Add Stage 4 AOD panel (R port) and imputation diagnostics; trust GEE QA at panel level
| * ee85bdc Add Stage 3: clean ERA5 covariates (R port of 3_cleanERAS.do)
| * ad1e2a6 Auto-deduplicate AOD month-boundary duplicates in merge
| * fca8c41 Add Stage 2b unified merge script for per-pollutant CSV consolidation
| * 0c26cbb Add Stage 2 SO2 weekly downloader (placebo outcome, annual chunking)
| * 93a7a6c Add Stage 2 ERA5-Land covariates weekly downloader (annual chunking)
| * 4b7de58 Add Stage 2 CO weekly downloader (annual chunking, no QA mask by design)
| * e22be7b Add Stage 2 NO2 weekly downloader (annual chunking, end 2026-04-30)
| * c063fec Add Stage 2 AOD weekly downloader; end date 2026-04-30
| * ed3a927 Regenerate UCDB shapefiles from script (matches GEE asset, 1089 features)
| * 1ac158d Patch Stage 1 to use pyogrio (geopandas 1.x default); pin Python deps
| * e65e8ff Refine .gitignore; add UCDB docs and Stage 1 geometries script
| * cc3c8cc Migrate donor pool selection files
| * 03012bc Migrate UCDB LAC urban centers shapefile (matches GEE asset)
| * db4ca45 Extend .gitignore for satellite data migration
| * c780e75 Reorganize repo: code/local/ and output/local/ with path updates
| * 1933db8 Add .gitattributes for consistent line endings
| * ca62e3b Reorganize output/ to mirror code/ (local/, satellite/)
```
