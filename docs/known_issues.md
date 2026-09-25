# Known issues

Items carried over from earlier work and from the first look at the new deliveries (2026-09-24). None has been fixed in this repository yet. Each needs checking against the code and data here. Add new items at the top of their module with the date, the evidence and a status: open, fixed in <commit>, or won't fix (and why).

## air_quality

Added 2026-09-24 during the consolidation (evidence checked in this repository):

- **Open, Leonel.** Two donut definitions. The cross-sample scripts, which feed the paper's tables, drop only the weeks flagged as Phase 3 blackout or wildfire weeks (`code/local/04_PM2_5_crosssample.R:64-73`, using `blackout_week_ids` from `03_analysis_setupPM2.5.R:111-115`, thresholds 0.3). In the frozen PM2.5 and CO panels those are the 14 weeks starting 2024-09-16 through 2024-12-16, matching paper Table 5 ("excluding Sept. 16 to Dec. 16, 2024"). The spatial placebo scripts drop every week between `BLACKOUT_START` and `BLACKOUT_END` (`04b_spatial_placebo_PM25_M8b_conformalp.R` and `04c`, `week_date < BLACKOUT_START | week_date > BLACKOUT_END`), 16 weeks through the week starting 2024-12-30. The paper's Table 6 reports the pre-disruption window, so its printed numbers do not depend on this. Any donut result from `04b` or `04c` does. Leonel's notes described the donut as "September 16 to December 30".
- **Open, Leonel.** Satellite inference uses Wald p-values. The OneDrive copy of `code/satellite/cloud_R/00_helpers.R` computes `p_2s` and `p_1s` from placebo standard errors with `pnorm` (lines 491-526, 591-592). The rank-based permutation p-value is only an extra column, `p_2s_perm` (lines 530-553, 593). The paper text reports the Wald p-value as primary (for example, lines 549-556 and 836-846 of `congestion/docs/paper/Underground-relief.txt`). Root rule 6 says never report Wald or pnorm p-values, and Leonel's notes say the satellite design uses rank-based two-sided permutation p-values. The authoritative VM copy of `00_helpers.R` differs and was not checked.
- **Open.** `02_build_weekly_panels.R` says in its header that step 2 drops event days (line 11), but the code only drops dates before 2022-12-01 (lines 92-98). Power-outage and wildfire days stay in the weekly means; blackout weeks are handled later by the 0.3 thresholds in the setup scripts. The comment and the code disagree; which one reflects the intent needs checking.
- **Open.** `master.R` does not run the cross-sample scripts, the spatial placebo scripts or `fig_pm25_eventstudy_pub.R`, which were never committed to the old repository (they came in as a snapshot, commit `033f40e`). The old `README.md` points to `code/master.R` and `output/tables/`, but the files are `code/local/master.R` and `output/local/tables/`. `RUNBOOK.md` now gives the full order.
- **Open.** Six frozen outputs have no producing script in the repository: `output/local/blackout_comparison/` (three files), `output/local/tables.zip`, `output/local/figures/descriptives_time_series_edit.png` and `output/local/spatial_placebo/spatial_placebo_PM25_M8b_noCentroDonor.pdf`.
- **Open.** `code/local/fig1_metro_airquality_map.R` loads sf, ggrepel, ggspatial, maptiles, rnaturalearth and tidyterra, none of which is in `renv.lock`, and it downloads basemap tiles at run time. They were installed here without a snapshot (`ENVIRONMENT.md`).
- **Open, satellite.** `code/satellite/laptop_R/01b_donor_pool_selection.py:32` reads `data/raw/ghs_ucdb/...`, but the folder is `data/raw/GHS_UCDB/`. This only works on a case-insensitive file system. Not changed, because the satellite pipeline does not run in WSL.
- **Correction to the item below on `ucdb_donor_distances_all.csv`.** A producing script exists: `code/satellite/laptop_R/01b_donor_pool_selection.py:329-330` writes `data/working/ucdb_donor_distances_all.csv`. The remaining problem is the path. The run scripts read it from `file.path(ROOT, "data", ...)` (for example `cloud_R/01_run_AOD.R:26`), which is the VM layout, while `05_descriptives.R:119` reads `data/working/`.
- **Status update on `read_remmaq()` and `df[-1,]`.** The imported function (`code/local/01_read_and_merge.R:55-121`) contains no `df[-1,]`. It reads the first column as a date and drops rows whose `fecha` is NA (line 80); the comments (lines 57-59) say that is how the units row goes. The check still stands: confirm that the units row is the only row dropped there.
- **Fixed in `a091013`.** `code/local/05_analysis_setupCO.R:33` read `co_completepanel_peakweekly.csv`, but `02_build_weekly_panels.R:473` writes `CO_completepanel_peakweekly.csv`. The mismatch only worked on Windows. Corrected as a path edit needed to run in WSL. Also in `a091013`: the absolute OneDrive path at `fig1_metro_airquality_map.R:40` became `here::here()`.

- **Open (from the verifier, 2026-09-24).** Conformal p-values depend on the seed and the call order. augsynth's `conformal_inf` defaults to `type = "iid"` with `ns = 1000` random permutations. `04_PM2.5.R`, `06_CO.R`, `08_NO2.R` and `10_SO2.R` set no seed of their own; they inherit `set.seed(12345)` from their setup script in the same session. The same test therefore gives different p-values in different scripts. Centro M5b pre_blackout has an identical ATT in `CrossSample_Summary_PM25.csv` and `spatial_placebo_PM25_M5b_conformalp.csv`, but conformal p 0.011 in the first and 0.003 in the second (verifier's run, which matched the frozen files exactly). Reported p-values are reproducible only in the RUNBOOK order.
- **Open (from the verifier, 2026-09-24).** One-sided conformal p-values of exactly 0: 7 of 24 AugSynth rows in `output/local/crosssample/CrossSample_Summary_PM25.csv` and 2 of 8 in `output/local/tables/results_PM25.csv` (checked in `frozen_2026-05-29`). A permutation p-value cannot be 0; the smallest attainable value should be reported instead.
- **Open (from the verifier, 2026-09-24).** The legacy `results_<POL>.csv` tables written by `04_PM2.5.R` and its gas twins slice the sub-period effects (`att_clean_*`, `att_p1_*`, `att_p2_*`, `att_blackout_*`) from the full-panel weekly vector (`04_PM2.5.R:57-61`), against root rule 6. They carry an SDID Wald interval (`se`, `ci_lo`, `ci_hi`) with no "not used" label, and they do not state the smallest attainable permutation p-value. The cross-sample tables have none of these problems. `12_cross_pollutant_master.R` builds `results_primary_specs.csv` from the legacy tables.

Carried over from earlier work:

- **Open.** PM2.5 gap for all stations in the frozen weekly panel: seven weeks, from the week starting 2025-01-13 to the week starting 2025-02-24. The Secretaría de Ambiente says REMMAQ holds these data (email of 2026-09-04). Its file covers only 2025-01-13 00:00 to 2025-01-25 23:00, about two of the seven weeks, so the rest still needs a REMMAQ download. Workstream A must first establish whether the data were lost at download or in processing.
- **Open.** `read_remmaq()` drops the first row with `df[-1,]`. Check that it never drops a real observation.
- **Open.** `descriptives_summary_stats.csv` swaps the distances of Tumbaco and San Antonio. Table 2 of the paper is correct.
- **Open.** CO_4 contains CONDADO instead of TUMBACO.
- **Open.** PM2.5 starts about eight months later than the gases.
- **Open.** The CO, NO2 and SO2 cross-sample scripts were made by text substitution from the PM2.5 template and have not had the verification pass that PM2.5 had.
- **Open.** HUM has near-zero readings that may be sensor artifacts. Wind direction (DIR) needs a circular mean.
- **Open.** Satellite pipeline: no script produces `ucdb_donor_distances_all.csv`, yet the run scripts need it; the run scripts read it from `data/` while `05_descriptives.R` reads `data/working/`. The VM copy of `00_helpers.R` is the authoritative one.
- **Open.** The May 31, 2026 paper PDF postdates the May 28 CSV export. Where the two differ, the PDF governs cited numbers until the tables are regenerated.

## congestion

Added 2026-09-24 during the consolidation:

- **Open, Leonel (blocks the GitHub push).** `congestion/reports/waze_sample.csv` holds 500 record-level rows of the raw Waze delivery (date, grid_id, hour, roadtype and every indicator). It was committed in `16fbfa9` (Phase B, 2026-09-17) and is in the imported history. Pushing the history to GitHub would publish provider records. Removing it from the history before the first push is Leonel's decision.
- **Open, Leonel.** `congestion/AGENTS.md` and analysis plan v2 disagree on several points (hour bins, zero coding, provider answers, the flag rule, whether `docs/analysis_plan.md` may be created). The list is in `reports/migration/05_claude_setup.md`. The plan wins (`congestion/CLAUDE.md`); none has been resolved.
- **Open, Leonel.** The Step 1 v2 prompt is not in the repository or the old one. Workstream B needs it.
- **Open.** The project library `congestion/Output/Waze/_environment/R-library` has no augsynth or synthdid, which Step 1 needs. They install from GitHub; see `air_quality/ENVIRONMENT.md`.

Carried over from earlier work:

- **Open, provider.** Waze February to April 2025: March is missing and February and April are thin. Treated as missing.
- **Open, provider.** Records arrive once or three times with identical values. The derived panel deduplicates them.
- **Open, provider.** The Waze-network ratio, the spread ratio and severe persistence are contaminated and not used.
- **Open, provider.** 8,290 fast-road keys have no all-road match.
- **Open, Leonel.** Question to Juan Camilo on absent records (true zero or no data). Step 1 runs under provisional zero coding; final numbers wait for the answer.
- **Note.** REMMAQ monitor coordinates in the spatial layer are rounded to 0.01 degrees. `MetroStations.shp` is empty; use the `.gpkg`.

## road_safety

Added 2026-09-24:

- **Note.** An older copy of the crash matrix sat in the air quality OneDrive folder (`data/traffic-accidents/`). It matches the delivered file cell for cell, except that its `DIA` column holds English day names, apparently from a re-save by Excel. It is kept in the store under `copy_found_in_AQ_SRC/`. Use the delivered file.

Carried over from the first look:

- **Open, provider.** No records for 2020 or earlier with coordinates and the same variables, so the series starts in January 2021.
- **Open.** One record has the text "X (SICARIATO)" in the deaths field instead of a number, which suggests a homicide rather than a road crash. Decide how to treat it and document the rule.
- **Open.** The urban or rural field (ZONA) is empty for 960 records.
- **Open, provider.** The typology "ATIPICO" (about 2,700 records) has no definition yet.
- **Open.** Coordinates are stored partly as text and partly as numbers in the Excel file. All convert to numbers, but no point has yet been checked against the district boundary.
