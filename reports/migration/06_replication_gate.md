# Phase 6. Replication gate, 2026-09-24

## Verdict: PASS WITH NOTES

The new home reproduces the frozen air quality tables. The whole local pipeline ran in WSL from the raw REMMAQ files in a clean checkout of commit `281d0e0`: PM2.5, CO, NO2 and SO2, the cross-sample tables, the spatial placebos, the diagnostics, the descriptives and the cross-pollutant master. Of the 39 tables compared with `frozen_2026-05-29`, 25 are identical and 14 differ only by floating-point noise, with the largest absolute difference 2.8e-14. None differs at the small (above 1e-6) or material (above 1e-3) level. Every p-value, conformal and permutation alike, matches exactly. No expected table was missing or older than the run start.

The notes: the noise-level differences in the last one or two digits, and six frozen files that no script produces and so could not be regenerated.

## Independent verifier: PASS WITH NOTES

A separate agent ran the RUNBOOK setup and steps 1 to 3 (PM2.5) from raw data in its own checkout of commit `ddf1322`, without seeing these results. It recorded its own numbers first and then compared them with `frozen_2026-05-29`. All 11 PM2.5 files it produced match. By its comparison table, 4 are byte-identical, 2 logs are identical apart from line endings, and 5 differ by at most 2.8e-14. (The summary sentence of its verdict says seven noise and two identical, which does not match its own table; the table is the detailed record.) Every p-value matches exactly, and every value it wrote down before opening the reference equals the reference. Its run took 55 minutes 19 seconds for the PM2.5 block. Report: `reports/verification/2026-09-24_air_quality_ddf1322.md`.

Its notes, all about existing code rather than the move, are now in `docs/known_issues.md`:

- The legacy `results_PM25.csv` slices sub-period effects from the full-panel weekly vector and carries an unlabeled SDID Wald interval.
- The legacy table does not state the smallest attainable permutation p-value.
- augsynth's conformal p-values use 1,000 random permutations by default, so they depend on the seed and on the call order. `04_PM2.5.R` inherits its seed from `03`, and the same test gives different conformal p-values in different scripts.
- 9 AugSynth rows (7 in the cross-sample table, 2 in the legacy table) have a one-sided conformal p-value of exactly 0.

## How the gate ran

1. Commit `281d0e0` on `main` (Phase 5, part 1: RUNBOOK and air quality CLAUDE.md). Clean checkout: `git worktree add .claude/worktrees/gate-aq HEAD` (detached). The later commit `ddf1322` changed only documentation and agents, not pipeline code.
2. Setup step from `air_quality/RUNBOOK.md`: `renv::restore()` linked 63 packages from the cache in 40 ms; `mkdir -p` for every output folder.
3. Deleted, inside the gate checkout, every derived and output file listed in `03_data_map.csv` that git had put there: 111 files, tracked outputs included (the local tables, figures, diagnostics, spatial placebo logs, the satellite diagnostics and donor tables, and the congestion outputs). The other 809 rows were untracked in the source, so they never existed in the checkout. Only the two raw CSVs in `air_quality/data/working/` remained.
4. **Run start: 2026-09-24 22:42:46 EDT.** Steps 1 and 2, then the PM2.5 block (step 3) from 22:43:42. The CO, NO2 and SO2 blocks (step 4) ran in parallel from 22:45:35, followed by steps 5, 6 and 7. The PM2.5 block ended at 23:39:40. Every script exited with status 0. The per-script times are in the RUNBOOK. The whole run took 57 minutes, well under the four-hour limit, so the gases were not deferred.
5. Timing of the first specification: M1 (SDID) about 1 s; the first augmented synthetic control fit (M4) 26 s. Extrapolated, `04_PM2.5.R` would take about 5 minutes. It took 8.6 minutes under the load of five parallel R processes.
6. Warnings: only ggplot's "Removed ... rows containing missing values (`geom_ribbon()`)" in `fig_pm25_eventstudy_pub.R` and `12_cross_pollutant_master.R`. These come from confidence bounds that conformal inference leaves as NA in the pre-period (root rule 6: correct, not a bug). The Figure 1 map also warned "Ignoring unknown parameters: `label.size`" (a ggplot2 version change). None of these warnings touches a table.
7. The cross-sample scripts' built-in checks passed in all four blocks. Check (a): the pre_blackout AugSynth ATT equals the full-sample weekly ATT averaged over P1 (maximum difference 0.00e+00). Check (b): the pre-period RMSPE does not change across samples (0.00e+00). Check (c) tied the full-sample M5b and M8b to the legacy battery (difference 0.00e+00). Source: `logs/gate-aq/aq_{pm25,co,no2,so2}.log`.

## Comparison

Script: `reports/migration/compare_outputs.py`. It compares every CSV and text log in the frozen `output/local/` and `data/processed/` (satellite panels excluded) with the regenerated file: rows and columns, cell by cell, with integers exact, other numbers classed as identical, noise (≤ 1e-6), small (≤ 1e-3) or material (> 1e-3), p-value columns exact, a missing or stale file a failure, and figures checked only for existence and freshness. Full results: `reports/migration/06_compare_files.csv` (one row per file) and `06_compare_columns.csv` (every differing column, with the count of differing cells and the largest difference).

| Group | Files | Result |
|---|---|---|
| Hourly panel `data/processed/hourly_panel.csv` | 1 | identical, byte for byte (195,024 rows) |
| Weekly panels `data/processed/*_completepanel_peakweekly.csv` | 4 | noise: 2 or 3 cells per file in `dir_imp` (and `ln_co`), max 2.8e-14 |
| `results_{PM25,CO,NO2,SO2}.csv` | 4 | NO2, SO2 identical; PM25 noise 3.5e-18 (`se`, `ci_lo`, `ci_hi`); CO noise 8.7e-19 |
| `att_weekly_*.csv`, `trajectories_*.csv`, `donor_weights_*.csv` | 12 | 9 identical; `att_weekly_CO` 5.6e-17, `trajectories_CO` 5.6e-17, `trajectories_SO2` 2.2e-16 |
| `CrossSample_Summary_{PM25,CO,NO2,SO2}.csv` | 4 | NO2, SO2 identical; PM25 noise 1.4e-17 (only the unused SDID Wald `ci_lo`/`ci_hi`); CO noise 8.7e-19 |
| `spatial_placebo_PM25_{M8b,M5b}_conformalp.csv` and their `_log.txt` | 4 | CSVs noise, max 1.2e-14 (in `att_pct`); logs identical |
| `results_all_pollutants.csv`, `results_primary_specs.csv` | 2 | noise 1.0e-17 / identical |
| `missingness_*.csv` | 4 | identical |
| `descriptives_*.csv` | 4 | identical |
| Figures (20 PNG and PDF files, Figure 1 included) | 20 | all produced by this run; content not compared |
| No producing script | 6 | `blackout_comparison/` (3 files), `tables.zip`, `descriptives_time_series_edit.png`, `spatial_placebo_PM25_M8b_noCentroDonor.pdf` |

The largest differences are 2.8e-14 in the imputed wind direction of the weekly panels (rounding in the last printed digit, which propagates into a handful of trajectory and effect cells at 1e-16 or less) and 1.2e-14 in the spatial placebo percent effects. Every such difference is in the 15th to 17th significant digit.

## Orphan inputs

None. No run stopped for a missing input, and nothing was added to the raw store.

## Randomness

The random steps are seeded, so placebo-based and conformal numbers reproduce exactly when the scripts run in the RUNBOOK order. augsynth's conformal inference draws 1,000 random permutations by default, and the SDID placebo standard errors use 300 replications. `set.seed(12345)` is called in every setup script (`03`, `05`, `07`, `09`), in the cross-sample scripts and in the spatial placebo scripts. The model scripts `04`, `06`, `08` and `10` have no seed of their own and rely on the one their setup script sets in the same session. As a result, p-values depend on the call order, and the same test can give different p-values in different scripts. The verifier found this; it is logged in `docs/known_issues.md`. No step was found to be unseeded within a RUNBOOK session.

## Congestion smoke test

`Rscript Scripts/Congestion/02_prepare_blocks.R`, run in the gate checkout's `congestion/` (after copying the ignored `Output/Waze/_environment/` into it), rebuilt the deduplicated panel from the raw Parquet file in 12 seconds. Totals and hashes only:

- `Data/Waze/parquet/all_roadtype.parquet` and `large.parquet`: sha256 identical to `/home/leonelb/data/quito-metro-eval/congestion/frozen_2026-09-17/Data/Waze/parquet/` (`6050031f…adeb0` and `3417a98c…5b35`), and no row in either new block is absent from the frozen one.
- Row totals (the script's own proof table): all_roadtype 1,314,213 distinct rows from 3,571,869 raw rows; large 852,218 from 2,315,636. Both equal the frozen manifest.
- `deduplication_manifest.rds` differs in bytes only: its `created` timestamp, and the row order of the two-row proof table (the grouped query has no ORDER BY). The source md5, the source size, the rule and the counts are equal.

No outcome value was read or reported by period.

## Figures and not-regenerable files

Figures are not compared by content (PNG and PDF bytes depend on fonts and devices). The Figure 1 map also downloads basemap tiles at run time. The six not-regenerable files are listed in `RUNBOOK.md` and `docs/known_issues.md`.
