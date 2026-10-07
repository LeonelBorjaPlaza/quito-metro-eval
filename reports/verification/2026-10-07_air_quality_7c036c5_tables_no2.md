# Verification (light, no reruns): Tables 5 and 7 relabel and the Centro NO2 arithmetic, commit 7c036c5

Report of the `verifier` agent, 2026-10-07, saved by the maker (summary; the numbers are kept).

## Verdict

**PASS WITH NOTES.** Every number matches its source file or the raw store. The notes concern wording and process, not numbers.

## A. Tables 5 and 7

- **What changed.** Only the iid row label, from "Conformal p" to "Conformal p (iid)": 3 rows in each `.csv` and `.tex`, and 6 rows in `tables_preview.md`.
- **Cells.** All 168 cells in `table5.csv` and `table7.csv` match `CrossSample_Summary_*.csv` and `block_conformal_*.csv`, rounded as printed. The `.tex` and preview versions match the `.csv` files.

## B. NO2 arithmetic

- **The week's gap.** Week of 2025-06-16: -0.8726 log points, the last of 134 weeks in `gaps_M8b_full_NO2.csv`.
- **Week counts.** The full window has 82 post-opening weeks; 14 blackout weeks (2024-09-16 to 2024-12-16) leave 68 in the donut.
- **Contributions.** -0.0128 (donut) and -0.0106 (full).
- **Means equal the estimates.** The mean post-opening gaps (-0.055035 and -0.059945) equal the M8b `att_log` (-5.35 and -5.82 percent).
- **Arithmetic without the week.** -0.0428 (-4.19 percent) and -0.0499 (-4.87 percent).
- **Raw store** (hashes match `SHA256SUMS` and `MANIFEST.sha256`), weekday peak-hour weekly means, Centro and Belisario:

| Week | NO2 slots at Centro | NO2 Centro mean | NO2 ratio | CO ratio | PM2.5 ratio |
|---|---|---|---|---|---|
| 2025-05-26 | 30 | 25.4 | 0.871 | 0.832 | 0.724 |
| 2025-06-02 | 30 | 26.4 | 0.878 | 0.933 | 0.928 |
| 2025-06-09 | 30 | 31.0 | 0.823 | 0.723 | 0.778 |
| 2025-06-16 | 18 | 12.1 | 0.423 | 0.799 | 0.796 |
| 2025-06-23 | 28 | 16.4 | 0.538 | 0.834 | 0.931 |
| 2025-06-30 | 30 | 13.9 | 0.465 | 0.855 | 0.671 |
| 2025-07-07 | 30 | 15.4 | 0.499 | 0.980 | 0.847 |
| 2025-07-14 | 30 | 12.5 | 0.521 | 0.905 | 0.629 |
| 2025-07-21 | 9 | 15.8 | 0.524 | 0.974 | 0.710 |
| 2025-07-28 | 0 | none | none | 0.511 | 0.714 |
| 2025-08-04 | 11 | 21.5 | 0.523 | 0.708 | 0.716 |

- **S1 NO2 donut** (`sensitivities_long.csv`): -12.11 percent, p_2s 0, smallest 0.001; "p < 0.001" is supported.

## Notes

1. **"Stops reporting" in `docs/known_issues.md`.** Centro NO2 returns in the week of 2025-08-04 with 11 slots, still at a ratio of 0.52. Fixed: the entry and the change list now describe a gap and partial reporting at the same low level.
2. **Fewer PM2.5 slots in two weeks.** Centro's PM2.5 has 19 and 21 of 30 slots in the weeks of 2025-07-07 and 2025-07-14. The CO ratio is 0.511 in the week of 2025-07-28, just outside the cited weeks.
3. **Raw path.** The evidence was read from the store by absolute path, since `air_quality/data/raw` points to the older raw folder. This is allowed.
4. **Not blind.** The brief included the expected numbers; the verifier computed each one before comparing.
