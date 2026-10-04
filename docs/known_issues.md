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

Added 2026-10-01 by workstream B (Amendment 5 redesign):

- **Open, Leonel (from the verifier of 231a113, before any push).** Three committed files hold values that equal single cells' provider values:
  - The coverage-range endpoints, 38.9701741964233 and 70.387631986531, are each one cell's 2022 `perc_waze_coverage` value (unnamed). They appear in `congestion/Output/step1_freeze/spec.json`, the freeze README, and `congestion/Output/Waze/step1/panel_summary.md` (4 decimals). Amendment 3, item 7 already discloses them.
  - `congestion/reports/waze_inventory.md` (Phase B, 2026-09-17) holds 100.00000000000004, which equals one cell's value.
  - `congestion/Output/step1_amendment2/unit_cells_weights.csv` gives the BELISARIO_RW weights as shares of the provider's per-cell 2022 OSM lengths. The lengths themselves are not written, but their ratios can be recovered.

- **Closed (Leonel, 2026-10-01).** Monthly tile data give an empirical minimum detectable effect of 0.92 of CENTER's pre-period mean for a reduction (`congestion/Output/redesign/mde_empirical.csv`). Leonel stopped the analysis before any post-opening month (Amendment 6; `reports/congestion/2026-10-01_stop_report.md`).
- **Closed (Leonel, 2026-10-01).** The pico y placa zone is approved as a record for a restart, with the 1.2 km south-east gap closed by a straight segment that is our assumption. With the segment the ring closes only at a 250 m buffer (`congestion/Output/redesign/zone_buffer_trace.csv`, `congestion/Output/redesign/map_pico_y_placa_zone.png`).

Added 2026-10-01 by workstream B (restart diagnostics, Amendment 6):

- **Open, restart.** The in-zone minus out-of-zone gap at hours 20 and 21 steps up from February to March 2023, a month before the pico y placa change of 10 April 2023, and no listed event explains it (`congestion/Output/restart_diagnostics/d3_event_time_gap.csv`, `congestion/docs/calendar_shocks.csv`).
- **Note (rule 5).** While verifying `b31cc94`, the verifier ran `head` on `Data/Waze/raw/roadlengths_quito.csv` and saw the header and six cell rows dated 2024 (OSM and Waze road lengths, not congestion outcomes) in its own tool output. Nothing was used, stored or copied; every computation filters road lengths to 2022 or earlier. The file is not sorted by year, as noted on 2026-09-29.
- **Open, provider.** The weekday profile's peaks (7:00 and 18:00) fit local time but cannot tell whether an hour label marks the start or the end of its hour (`congestion/docs/provider_questions.md`, item 11).
- **Note.** The BELISARIO monitor cell from the Colegio San Gabriel campus (8866d338c9fffff) differs from the seed built from the published coordinates (8866d33aa3fffff), which look truncated rather than rounded to 0.01 degree; the redesign rebuilds the ring (`congestion/docs/belisario_address_check.csv`). Step 1 and Amendment 2 outputs keep the old ring.

Added 2026-10-01 by workstream B (Amendments 2 to 4, item D):

- **Open, Leonel.** The primary fit interpolates. CENTER (historic-center polygon) with the screened pool tunes the ridge penalty to the smallest value on augsynth's grid (2.07e-5). Its training RMSPE is 2.5e-7, its full pre-period RMSPE 3.0e-7, and its total negative weight -1.48 (`congestion/Output/step1_amendment2/fit_statistics.csv`, `weight_statistics.csv`).
  - The leave-one-block-out curve is flat: 16 of 21 penalties come within 5 percent of the minimum (`lobo_grid.csv`).
  - The same happens for CORE and RING7 with the screened pool and for CORRIDOR with the unscreened pool.
  - Under conformal inference, such a fit leaves pre-period residuals near zero.
  - The placebo floor (CENTER's own RMSPE) is degenerate in that pool; the scaled placebo statistics are withheld there.
  - Not fixed: the tuning rule is the plan's. Options are listed in `reports/congestion/2026-10-01_historic_center_preperiod_report.md`.
- **Fixed (by Leonel, 2026-10-01).** The parish delivery `road_safety/raw/2026-09-25_geoquito_parroquias/`, used by the congestion module for zonal administrations, is now in the store's `MANIFEST.sha256` (seven files; all hashes verify).
- **Open, Leonel.** About 0.56 of the synthetic CENTER's weight sits on donor cells outside the DMQ's parish layers, in neighbouring cantons (`donor_geography_by_zonal_administration.csv`). The plan's donor rule does not restrict donors to the district.
- **Open, Leonel (before any figure leaves the repository).** The UNESCO map image (document 173425) is embedded in `reports/congestion/2026-09-29_historic_center_candidates/map_candidates_over_unesco.png`. UNESCO's terms of use have not been checked.

Added 2026-09-29 by workstream B (Amendments 2 and 3):

- **Note (corrected 2026-10-01).** While preparing the historic-center weights, a `head -3` of `Data/Waze/raw/roadlengths_quito.csv` printed the header and two 2024 rows (the file is not sorted by year), against the structure-only rule for post-2023 rows.
  - The rows hold OSM length, Waze length and their ratio. The Waze-length column is a running maximum of the jam segments Waze observed (provider answer 3), so it is derived from the outcome.
  - The exposure is negligible: two rows of one cell-year each. They were not used or repeated.
  - Every later read filtered to `year == 2022` before printing, and printed aggregates only.
- **Open, Leonel.** The UNESCO map of the inscribed property (document 173425, 2019) carries a printed 1 km grid that is offset from SIRES-DMQ. Placed by that grid, its core sits 246 m east and 366 m north of the OSM trace, while the trace matches the official corner streets (`reports/congestion/2026-09-29_historic_center_candidates/unesco_map_shares.csv` and `core_corners_vs_osm_trace.csv`). The old PSAD56 datum shifts the other way, so the cause is unknown. Any use of that map's coordinates needs this correction.
- **Open, Leonel.** No official polygon of the World Heritage core (70.43 ha) was found on GeoQuito. The proposed core is an OpenStreetMap volunteer trace (way 1077782502, ODbL). An official file from the municipality would replace it by amendment.
- **Status update on the zero-coding question** (the item "Question to Juan Camilo on absent records" below). The provider answered on 2026-09-29 (`congestion/docs/2026-09-29_provider_answers.md`, saved in `1b3b1e0`). Zero coding is now the plan's rule (Amendment 3). The answer on severe persistence above 100 is still missing.
- **Status update on the branch history item** (commits `2a9ac76`, `ab00117`, `2a3c931`, below). Leonel decided on 2026-09-29 not to rewrite them: the branch will be squash-merged and never pushed (Amendment 3, item 7).

Added 2026-09-27 by workstream B (Step 1):

- **Open, Leonel.** In Step 1, the ridge-penalty tuning (plan v2 section 6: leave-one-block-out, augsynth's own grid) lands on an edge of augsynth's lambda grid in 7 of the 8 fits (`congestion/Output/step1_freeze/weight_statistics.csv`, column `lambda_at_grid_edge`, and `spec.json`).
  - Five fits take the largest penalty, where the ridge augmentation does least. These are all four unscreened-pool fits and BELISARIO's screened fit under the amended rule. It explains why augsynth and plain SCM score almost the same on the holdout.
  - The two original-rule, screened-pool fits take the smallest penalty and interpolate their training months.
  - Only CENTER with the screened pool under the amended rule chose an interior value.
  - Widening the grid would change the specification, so it is Leonel's decision before the freeze becomes final.

- **Open, Leonel.** The severe-persistence part of the flag rule (`tc_severe_persistance_ratio` above 100; plan v2 section 1) drives almost all pre-period missingness. It flags 1,408 of the 2,721 contaminated all_roadtype pre-period keys; the negative-ratio conditions flag the other 1,313 (one key trips both). All three missing CENTER peak unit-months (202201, 202304, 202307) come from this condition alone, in cell 8866d338e3fffff at one morning hour each (evidence: `congestion/Output/Waze/step1/panel_summary.md`, and the Step 1 report). It also accounts for every threshold-20 donor that is incomplete in the pre period. On persistence-flagged rows, primary TCI sits above the same cell-hour's unflagged median more often than on unflagged rows. That is consistent with contamination, and also with heavier congestion when jams persist.
- **Open, provider.** In `Data/Waze/raw/roadlengths_quito.csv` (data-auditor, 2026-09-27), Waze length is not capped at OSM length, although the documentation says it is (`docs/waze_documentation.md:69`). In 2022, 163 all_roadtype cells have `perc_waze_coverage` above 100. When OSM length is 0, `perc_waze_coverage` is coded 100. The roadtype lengths do not add up to all_roadtype, against line 127. 86 cells have 2022 jam records but no 2022 Waze length. Waze length is jam-based (line 67), so it is not an independent coverage measure. The Step 1 screen is labeled "jam-derived coverage". None of these cells can pass the current screen range.
- **Open, Leonel.** The provider email of 2026-09-17 that confirms Monday-to-Friday hourly profiles and the severe definition (plan v2 section 1, "saved in docs/") is not in the repository yet. Leonel will save it in `congestion/docs/`.
- **Open, Leonel (before any push of `worktree-congestion-step1`).** Commits `2a9ac76`, `ab00117` and `2a3c931` of this branch print the 2022 `perc_waze_coverage` value of each of the 14 CENTER and BELISARIO cells in `congestion/Output/Waze/step1/panel_summary.md`, and `2a3c931` prints it for 10 top donors per fit in `diagnostics.md`. These are cell-level provider values. From `798fcff` on, committed outputs carry only the target range and in-range flags. The branch has not been pushed, so whether to rewrite those commits before a merge is Leonel's decision.
- **Note.** The data-auditor's first read of `roadlengths_quito.csv` printed the file's first two rows, which are 2024 records (the file is not sorted by year). Their values were not used or repeated. All later checks of years after 2023 were structural only, as Leonel instructed.

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
