# Code review: paper_number_map.py (step 2)

Report of the `code-reviewer` agent on the first version of `air_quality/code/local/step2/paper_number_map.py` and its 288-row output, 2026-10-05, saved word for word by the maker. Fixes applied in the version committed after `aad1942`: Table 3 period counts and stations, Table A.1 stations, notes (A.3 typo, Belisario donor rule, A.1 counting window, PM2.5 P2), sign checks on unrounded values, matching p_type on both sides, values written at printed precision, frozen-path check, RUNBOOK line, table line ranges. Not applied: Table 6 distances (they do not change).

---

## Review of air_quality/code/local/step2/paper_number_map.py and its output paper_number_map.csv (288 rows)

**Verdict.** You can trust every value the CSV contains, with one exception. It is not yet a complete map of the printed numbers.

- **Sourcing.** I found no sourcing errors. Each row reads the right file, specification, window and column.
- **Frozen values against the paper.** I checked every frozen value against the printed cells of Tables 5, 6, 7, A.1, A.3 and the window columns of Table 3 in congestion/docs/paper/Underground-relief.txt. All of them match except one: Table A.3, M8, Donut.
- **Coverage.** The map leaves out 32 printed numbers.
- **Table A.1.** The "change" values for the hourly counts mix a change in definition with a change in data, and nothing in the CSV says so.

No CRITICAL findings. I did not run the script or edit any file. I read the existing CSV and its source tables, and no raw hourly records.

## MAJOR

**1. One printed value is wrong in the map (paper_number_map.py:65; CSV row 216).**
- The map says Table A.3, M8, Donut was printed as -0.153. The paper prints -0.154 (paper line 1258).
- The frozen source value is -0.1534619 (frozen CrossSample_Summary_PM25.csv, row 18). It rounds to -0.153, which is what Table 5 prints at paper line 651.
- So the paper is internally inconsistent here. But the column `printed_frozen` is the rounded frozen value, not what the paper prints, so its name is wrong for this cell.
- Why it matters: anyone building the "what changed" table from this column will misstate what the paper printed.
- Fix: rename the column to `frozen_rounded`, or add a `paper_printed` column and a note on this cell saying the paper has a typo against Table 5.

**2. Table 3 coverage is wrong (paper_number_map.py:84-95).**
- The paper prints Stations, Pre, P1, Blackout, Trans., P2 and the three window totals (paper lines 293-299).
- The map has Pre and the window totals only, so it misses 20 printed numbers: Stations, P1, Blackout, Trans. and P2 for each of the four pollutants.
- PM2.5's P2 is one of the numbers that changes: 6 in the paper, 24 in the new run according to reports/air_quality/2026-10-05_step2_results.md:183. That figure is not in any mapped row.
- The map also lists "post weeks (full)" (64 frozen, 82 new), which the paper does not print.
- Fix: extend `window_weeks()` in code/local/step2/old_vs_new.R:64-77 to write p1, blackout, trans and p2 counts (Trans. = unflagged weeks between BLACKOUT_START and BLACKOUT_END). Map those columns plus `stations`, and drop the "post weeks (full)" row.

**3. The Table A.1 changes are not like for like (paper_number_map.py:97-104; CSV rows 266-286).**
- 11_descriptives.R:114-117 now counts only hours from 2022-12-01 to AQ_PANEL_END + 7.
- The gas panels are unchanged (938 station-weeks, 134 weeks), yet their counts fall:

| Gas | Raw hourly, frozen | Raw hourly, new |
|---|---|---|
| CO | 167,214 | 142,761 |
| NO2 | 176,580 | 145,306 |
| SO2 | 177,295 | 141,510 |

- So most of the change comes from the definition (and possibly the new raw vintage), not from the sample. The map shows it as a plain change.
- I could not confirm the frozen script's date filter without git history.
- Fix: add a note column on the raw hourly, peak-hour and weekday peak-hour rows saying the counting window changed. Also add Stations, which the map leaves out of Table A.1 (4 numbers).

## MINOR

**4. Sign-change logic (lines 32-33).**
- It runs on rounded values, and it returns False rather than missing when either side is zero. A flip such as +0.0004 to -0.03 would be reported as no change.
- No current row rounds to zero, so no output is affected today.
- It also departs from old_vs_new.R:53-54, which uses unrounded signs.
- Fix: compute `np.sign` on the unrounded values, and return missing when either one is 0.

**5. The Table A.3 p-value check reads only the frozen p_type (line 66).** The p-value types in the frozen and new files are the same today, so nothing is affected. Fix: require `o["p_type"] == n["p_type"] == "conformal"`.

**6. Table 6 distances are not mapped (8 numbers, paper lines 690-697).**
- If you add them, do not take them from `dist_corridor_km`: that column swaps Tumbaco (9.558) and San Antonio (16.65) in both the frozen and new files. This is already logged in docs/known_issues.md:53. The paper has Tumbaco at 9.56 and San Antonio at 16.65.
- Also, the Belisario row's sign change (8.5 to -6.1) comes from the new donor rule, not from the data. Its new estimate is exactly M9 pre-disruption (att_log -0.06284704148405637 in both files). The label says so; the sign_changed column does not.

**7. Formatting and labels.**
- `change` is computed on rounded values and its direction (new minus old) is not documented in the header.
- Integers come out as floats (198778.0), and p-values lose their trailing zero (0.61 for the printed 0.610). This trips string matching by the claims-auditor. Fix: write strings at the printed precision.
- Pollutant keys mix PM25 and pm25.

**8. Printed date labels are not covered.** The window labels "Nov. 27, 2023–Mar. 2025" (paper line 657) and "through Mar. 2025 for PM2.5" (line 765) change under the new panel end (2025-06-16). The map does not cover them; the report should.

**9. Reproducibility.**
- The absolute FROZEN path (line 20) follows old_vs_new.R:22 and points at the data store. That is acceptable, but add an existence check with a clear error.
- `ROOT` comes from `__file__`, so the working directory does not matter. The output is deterministic: there is no randomness and the order is fixed.
- The script is not called from code/local/step2/run_step2.sh or RUNBOOK.md. It depends on step2/window_weeks.csv, which old_vs_new.R produces, and its Python dependencies (pandas, numpy) are not recorded in air_quality/ENVIRONMENT.md.

## Checks that passed

- **Tables 5 and 7.** They read CrossSample_Summary_{PM25,CO,NO2,SO2}.csv for M7/M9/M8/M8b and M8b, using the columns att_log, att_pct, p_2s, rmspe_pre, rmspe_post and ratio. Every one of these cells matches the paper. Table 5 does print post RMSPE (paper lines 648, 655, 662), so mapping it is right.
- **Table A.3.**
  - Every log effect and conformal p matches except M8 Donut (item 1).
  - Dropping the SDID permutation p-values is correct, because Panel A prints "n.a." (paper lines 1237-1243). M5b's conformal p-values are kept (CSV rows 191, 193, 195).
  - RMSPE pre and the post/pre ratio come from the pre-disruption window, as the table note says (paper lines 1268-1269). This choice matters, because SDID's RMSPE pre differs by window: M1 is 0.26103 pre-disruption and 0.26134 donut.
- **Legacy and Wald columns.** The script uses no sliced column (att_clean, att_p1, att_p2, att_blackout) and no Wald column (se, ci_lo, ci_hi).
- **Table 6.**
  - It uses only `sample == "pre_blackout"`, so the 16-week placebo donut against the 14-week cross-sample donut does not matter here.
  - The placebo Centro pre-disruption att_log equals M8b pre-disruption exactly in both the frozen and new files, so the windows are identical.
  - All 8 stations' effects and p-values match the paper.
- **Table 3 frozen values.** old_vs_new.R:64-88 rebuilds them from the frozen panels with the same blackout rule as 03_analysis_setupPM2.5.R:40-44,128-132 (po > 0.3 or wf > 0.3). They reproduce the printed totals: 94/102/116 for PM2.5 and 94/120/134 for the gases.
- **Window label.** pre_blackout is mapped to "Pre-disruption" (line 23).

## The three fixes I would make first

1. Table 3: add the Stations, P1, Blackout, Trans. and P2 counts, and drop the unprinted "post weeks (full)" row (item 2).
2. Rename `printed_frozen` or add a `paper_printed` column, and flag the Table A.3 M8 Donut typo (-0.154 printed, -0.153 at source) (item 1).
3. Add a definition-change note on the Table A.1 hourly count rows, and add Stations to Table A.1 and the distances to Table 6, taking the distances from the paper, not `dist_corridor_km` (items 3 and 6).
