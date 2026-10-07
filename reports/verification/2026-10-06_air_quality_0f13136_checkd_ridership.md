# Verification (light): check d and the ridership test, commit 0f13136

Report of the `verifier` agent, 2026-10-06, saved by the maker. The verdict, the numbers and the notes are kept; the paths to the verifier's own scripts are shortened.

## Verdict

**PASS WITH NOTES.** Every result recomputed matches the committed outputs. The differences are at floating-point precision (1e-16), and every p-value matches exactly. The notes cover one wording error in the mechanism note and two framing points. None of them changes a number.

## What was run

- **Checkout.** An isolated worktree at `0f13136`, with a clean tree.
- **Raw inputs.** The REMMAQ delivery (15 files) and the Metro de Quito delivery (3 files) match `SHA256SUMS` and the store's `MANIFEST.sha256`.
- **Setup.** `renv::restore` linked 63 packages from the cache.
- **Panels.** The PM2.5 main and S4 weekly panels were rebuilt from raw with `01` and `02`; both are byte-identical (sha256) to the maker's.
- **Check d.** The verifier's own script sourced `03_analysis_setupPM2.5.R`, took `fit()` by parse from `centro_diagnostics.R`, and re-ran four pseudo-openings: main weeks 20 and 44, S4 weeks 20 and 38. It then recomputed the summary rates from the committed per-date files.
- **Ridership.** The verifier's own Python, not importing the maker's script. Spearman uses average ranks, ties count against San Francisco, and cyclic shifts run on 16 levels and 14 differences. It also recomputed the totals check.

## The verifier's numbers

| Panel, week (date) | att_log | iid p | block p (T) |
|---|---|---|---|
| main 20 (2023-04-10) | 0.0135088469406873 | 0.057 | 3/52 = 0.0577 |
| main 44 (2023-09-25) | 0.159942837154357 | 0.033 | 6/52 = 0.1154 |
| S4 20 (2023-04-10) | -0.018388667357339 | 0.167 | 6/47 = 0.1277 |
| S4 38 (2023-08-14) | 0.0627586844105647 | 0.027 | 5/47 = 0.1064 |

Structure of the two panels:
- Main: t_int 53, 52 pre weeks, last pre week 2023-11-20.
- S4: 8 rationing weeks dropped, t_int 48, 47 pre weeks, last pre week 2023-10-16.

| Test | n | Spearman (SF) | SF rank by absolute value, station-placebo p | SF rank, most negative | Cyclic-shift p |
|---|---|---|---|---|---|
| Primary: share, levels | 16 | +0.255882 | 10, p = 0.6667 | 10 | 0.4375 |
| Secondary: log entries, levels | 16 | -0.302941 | 8, p = 0.5333 | 8 | 0.25 |
| Share, first differences (14) | 14 | +0.257143 | 4, p = 0.2667 | 14 | 0.3571 |
| Log entries, first differences | 14 | +0.239560 | 3, p = 0.2 | 14 | 0.2143 |
| Hourly file: share, levels | 16 | +0.411765 | 6, p = 0.4 | 13 | 0.1875 |
| Hourly file: log entries, levels | 16 | -0.088235 | 14, p = 0.9333 | 14 | 0.6875 |

Smallest attainable p-values: 1/15 for the station placebo, 1/16 for cyclic shifts in levels, and 1/14 in differences. The primary correlation is positive, so the decision rule is not met.

**Totals check.** 250 of 270 station-months are equal between the two files. Monthly system totals are equal in 16 of 18 months.

## Comparison

All of these are identical, at most 3e-16 apart:
- the check d per-date rows (4 of 23 re-run);
- both check d summary files (recomputed from the per-date rows);
- `ridership_test_series.csv` (16 rows), `ridership_station_placebo.csv` (90 rows), `ridership_test_results.csv` (6 rows) and `totals_check_station_month.csv` (270 rows).

Every block p is a multiple of 1/T. Check d's code and inputs are the same at `6b5a2c4` (where it ran) and at `0f13136`.

## Notes (unsupported or imprecise claims)

1. **"Monthly system totals unchanged"** (mechanism note, data check; provenance note, line 16) holds in 16 of 18 months. March 2025 differs by +25 and May 2025 by -41. Only December 2023, January 2024 and December 2024 are pure permutations.
2. **"The block test does not over-reject at 5 percent in either panel" is true but selective.** At 10 percent the main-panel block test rejects 6 of 13 (0.46), against an effective level of 0.096. Three main-panel block p-values sit at 3/52 = 0.058.
3. **"Most of the iid test's over-rejection comes from the late-2023 rationing weeks" is an interpretation.** S4's iid test still rejects 2 of 10 at 5 percent and 4 of 10 at 10 percent, with nested windows.

## Rule check

- No Wald or pnorm p-values.
- Each pseudo-opening is a separate fit.
- Check d (3B) and the ridership test (3C plus amendment) are approved.
- No writes into `raw/` or `frozen_*`.
- Minor: `ridership_test.py` reads the Metro delivery by an absolute store path, with no committed symlink under `air_quality/data/` (for `docs/known_issues.md`).

## Not checked

- The other 19 pseudo-openings: they come from the committed files and the maker's logs.
- The gap series itself (from the step 2 run verified on `606ea82`).
- Sections 3 and 4 of the rewordings report, and the non-ridership numbers in G1, G3 and G4.
- Which ridership file has the correct station labels.
