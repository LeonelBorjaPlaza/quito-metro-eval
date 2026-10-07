# PM2.5 gap of January and February 2025: diagnosis

Workstream A, step 1. Answers comment 1 of the Secretaría de Ambiente (`docs/correspondence/2026-09-07_secretaria_ambiente_comments.md`). No estimate was re-run, no table changed, and the gap-fill file was not merged into any panel.

## Result

The answer is (c), a mix, and the larger part is processing.

- **Seven of the eight stations report in every gap week.** The raw REMMAQ file we hold, `air_quality/data/raw/remmaq/PM2.5.xlsx`, has a row for every hour of the seven weeks, and Belisario, Carapungo, Centro, Cotocollao, Guamaní, San Antonio and Tumbaco have values in every one of those weeks (not in every hour; Guamaní, for example, has 117 of 168 hours in the week of January 13). They reach the hourly panel unchanged.
- **One station is missing in the file we hold: Los Chillos.** Its column is empty from 2025-01-06 08:00 to 2025-03-01 00:00: no value at all on 2025-01-07 to 2025-02-28, and 8 of 24 hours on 2025-01-06. Whether the portal lacked these values or the download lost them cannot be told from the file (section 3).
- **The pipeline then drops each whole week.** `02_build_weekly_panels.R` keeps a week only if all eight stations have a value (lines 392-399). It interpolates gaps of at most two weeks and imputes only San Antonio by regression, so a seven-week hole at Los Chillos removes those weeks for every station. This is a design rule working as written, not a bug, so there is no code fix to propose. The fix is data: Los Chillos for those days.
- **`read_remmaq()` loses nothing.** It contains no `df[-1,]`. `PM2.5.xlsx` has no units row, every first cell is a date, and the function returns all 189,243 data rows.
- **The Secretaría's file adds only Los Chillos.** For the other eight stations in it, every value equals `PM2.5.xlsx` exactly at the same hour, with the missing hours in the same places. Los Chillos is present for 311 of its 312 hours (2025-01-13 to 2025-01-25), which covers every weekday peak hour of the weeks starting January 13 and January 20.
- **What a new REMMAQ download must cover:** Los Chillos only. If the Secretaría's Los Chillos column were accepted, at the least the weekday peak hours of 2025-01-27 to 2025-02-28 (full days 2025-01-26 to 2025-02-28); it is not accepted so far (follow-up report, section 2), which extends the need to 2025-01-13 to 2025-01-25 as well. The list and a recommended wider request are in section 3.

One correction to the prompt: the gap-fill folder is in the data store, `/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/`, not under `air_quality/raw/` in the repository. On purpose, nothing in the repository links to it.

## 1. The gap-fill file (data-auditor)

The full audit is `reports/data_audits/2026-10-01_aq_secretaria_pm25_gapfill.md`. Its script and 17 summary tables sit next to it. Verdict: usable with caveats, and only for Los Chillos.

- **Integrity.** The Excel file and both email exports match the folder's `SHA256SUMS`.
- **Coverage.** 312 consecutive hours, 2025-01-13 00:00 to 2025-01-25 23:00, with no missing time stamps. Hours with a value: Carapungo 312, Belisario, Cotocollao, Los Chillos and Tumbaco 311 each, Centro 310, San Antonio 291, Guamaní 261, El Camal 254 (`..._coverage_joint.csv`). Los Chillos lacks only 2025-01-21 14:00, which is not a peak hour (`..._gapfill_missing_runs.csv`). Guamaní's main hole runs from Jan 14 14:00 to Jan 16 15:00, and El Camal's from Jan 13 00:00 to Jan 15 08:00. `PM2.5.xlsx` has exactly the same holes.
- **Units.** The eight shared stations are µg/m3, since they equal `PM2.5.xlsx`. Los Chillos is very likely µg/m3 too: its 13-day mean is 13.60, against 16.66 in its own January 2023 data (`..._values_by_station.csv`).
- **Validation flags.** There are none in either file: no text cells, negatives, sentinel codes, comments or colour fills. A missing hour is an empty cell.
- **Different processing for Los Chillos.** 309 of its 311 values carry 3 to 5 decimals. No value in `PM2.5.xlsx`, for any station from 2004 to 2026, has more than 2, and the other columns of the gap-fill file have at most 2 (`..._decimals.csv`). Los Chillos may come from a different stage of processing (raw or preliminary rather than validated). This is not established; it is the Secretaría's question 1.
- **Time stamps.** Both files store exact hours, with no `XX:59:59.999` entries. They agree with each other at lag 0, and lag 0 is the best match over lags of -6 to +6 hours for every shared station (`..._lag_alignment.csv`). The daily cycle shows local clock time even though `PM2.5.xlsx` labels its date column "UTC": most stations peak at 07:00. Whether a stamp marks the start or the end of the hour cannot be settled from the files, the email or `Marco_QAQC_REMMAQ.pdf`. Since the files agree with each other, this matters for how the peak-hour window is read, not for merging. The question is in the audit as question 4.
- **Los Chillos timing, a second caveat** (revised after two claims audits; the dedicated test is in `reports/air_quality/2026-10-01_pm25_followup.md`, section 2). The test is inconclusive. Within ±3 hours, the gap-fill's weekday profile matches the station's own March 2025 and January to March 2024 profiles best at the same shift, -3 hours, on the edge of the range; the lag test against March 2025, a month in which Los Chillos barely tracks the other stations, does not confirm it, and the unshifted profiles do not match. Against the other stations, the gap-fill lags by two to three hours; REMMAQ's own Los Chillos lagged by one to two hours in the two weeks before the outage (best -2, nearly tied with -1, `..._timing_vs_other_stations.csv`), and by about one hour in January to March 2024. This matters because the weekly panel uses fixed clock hours. It is question 7 in the audit.

## 2. The seven weeks through the pipeline

Script: `air_quality/code/local/diagnostics/pm25_gap_trace.R`. Log: `logs/aq_pm25_gap_trace.log` (not tracked). Tables: `air_quality/output/local/diagnostics/pm25_gap/`. The script runs the pipeline's own code, unchanged: it evaluates `read_remmaq()` from `01_read_and_merge.R`, steps 1 to 7 of `02_build_weekly_panels.R`, and a copy of `build_weekly_panel()` with capture points added between its steps. To show that it changes nothing, it checks that the traced run reproduces the weekly panel the pipeline wrote (largest difference 0). The written panel matches the frozen panel up to 2.84e-14, the floating-point noise the replication gate already recorded. The hourly panel rebuilt here is byte-identical to the frozen one (`pm25_gap_trace_facts.csv`).

Stations with a value in each week, from `pm25_gap_trace_week.csv` (the seven gap weeks in bold):

| Week starting | A. Raw file, weekday peak hours | C. Hourly panel | D. Weekly mean | E. After short-gap interpolation | F. After San Antonio imputation | Missing at F | G. In panel (frozen too) |
|---|---|---|---|---|---|---|---|
| 2024-12-30 | 8 | 8 | 8 | 8 | 8 | | yes |
| 2025-01-06 | 8 | 8 | 8 | 8 | 8 | | yes |
| **2025-01-13** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-01-20** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-01-27** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-02-03** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-02-10** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-02-17** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| **2025-02-24** | 7 | 7 | 7 | 7 | 7 | Los Chillos | no |
| 2025-03-03 | 8 | 8 | 8 | 8 | 8 | | yes |
| 2025-03-10 | 6 | 6 | 6 | 8 | 8 | | yes |

Step by step:

- **A. Raw file.** One sheet, `LIMPIO`, with 189,243 data rows below the header. In the trace window (2024-12-30 to 2025-03-16), no hour lacks a row, no time stamp is off the hour, and no cell holds text. Los Chillos has 0 values from 2025-01-07 to 2025-02-28. Every other station has values in every gap week (`pm25_raw_station_day_window.csv`, `pm25_gap_trace_station_week.csv`).
- **B. `read_remmaq()`.** It returns 189,243 rows, so it drops none. Its NA-date filter (line 80) is there for a units row, which this file does not have.
- **C. Hourly panel (`01` output).** Over the window, the PM2.5 columns equal the `read_remmaq()` output exactly, after `01` sets negatives to missing. Hour counts per station-week are the same at A, B and C.
- **D to F. Weekly means, interpolation, imputation.** Los Chillos has no weekly mean in the seven weeks. Short-gap interpolation fills runs of at most two weeks, so it leaves a seven-week run alone. The regression imputation covers San Antonio only.
- **G. Balance rule.** Seven stations report in each gap week, so the rule drops all seven weeks. The rebuilt panel and the frozen panel both have 116 weeks and both lack these seven.

The tracked diagnostic `air_quality/output/local/diagnostics/missingness_PM25.csv`, written by `99_missingness_diagnostic.R` for the May draft, already showed the same pattern: Los Chillos has 0 of 30 peak hours in the gap weeks, while the other stations report.

## 3. Conclusion and the download list

**Which case holds.** (c), a mix. The pipeline drops data that the raw files contain, for seven stations, because one station, Los Chillos, is missing from the raw file. Whether REMMAQ's portal lacked Los Chillos for those days or the download lost it cannot be told from the file. The column is empty within a sheet whose other columns are full. The sheet is named `LIMPIO` ("clean"), so the portal's validated product may simply not include Los Chillos for that period. The Secretaría's Los Chillos values, with their extra decimals, fit that reading. The audit's questions 1 and 2 ask exactly this.

**No pipeline fix is proposed.** No step loses data by mistake. The weeks drop because of the balance rule, a design choice, and root rule 7 says not to change a design choice to make a problem go away.

**Station-days a new REMMAQ download must cover.** Los Chillos is the only station needed. Every other station already has these days in `PM2.5.xlsx`.

1. **Required, if the Secretaría's Los Chillos column is accepted as is:** Los Chillos, 2025-01-26 to 2025-02-28, 34 station-days. For the weekly panel, only the weekday peak hours (07, 08, 09, 17, 18 and 19) of 2025-01-27 to 2025-02-28 count: 25 weekdays, 150 station-hours. With these, the weeks starting January 27 to February 24 can pass the balance rule. The gap-fill file already covers every weekday peak hour of the weeks starting January 13 and 20; its one missing Los Chillos hour (January 21, 14:00) is not a peak hour.
2. **Also required, if the gap-fill Los Chillos column is not accepted** (for example, if it turns out to be unvalidated, or shifted in time; see section 1): Los Chillos, 2025-01-13 to 2025-01-25, 13 station-days.
3. **Recommended:** Los Chillos, 2025-01-06 to 2025-01-12, 7 station-days. These days are outside the seven weeks, but 16 of the 24 hours of January 6 are missing. The week starting January 6 enters the frozen panel on a single Los Chillos peak hour, on Monday, January 6 (`pm25_gap_trace_station_week.csv`).

4. **Also worth requesting (found by the claims-auditor):** Los Chillos, 2025-03-08 to 2025-03-23. The raw column is also empty from 2025-03-09 to 2025-03-22, with 9 hours on March 8 and 9 on March 23 (`pm25_raw_day_mar2025.csv`). The weeks starting March 10 and March 17 have 0 of 30 Los Chillos peak hours (`air_quality/output/local/diagnostics/missingness_PM25.csv`) but stay in the panel, because the two-week interpolation fills them.

The simplest request, and the one the audit's question 2 makes, is one validated series for Los Chillos from 2025-01-06 to 2025-03-02. It covers items 1 to 3 in a single, consistently processed series and avoids splicing in a column processed differently.

## 4. Where the two files overlap

The gap-fill file overlaps the pipeline's data for seven of the eight analysis stations, plus El Camal, which the pipeline drops. Los Chillos does not overlap at all: the gap-fill has 311 hours and `PM2.5.xlsx` none. In every overlap the values are identical:

| Station | Hours in both files | Exactly equal | Hours in only one file |
|---|---|---|---|
| Belisario | 311 | 311 | 0 |
| Carapungo | 312 | 312 | 0 |
| Centro | 310 | 310 | 0 |
| Cotocollao | 311 | 311 | 0 |
| Guamaní | 261 | 261 | 0 |
| San Antonio | 291 | 291 | 0 |
| Tumbaco | 311 | 311 | 0 |
| El Camal (not used) | 254 | 254 | 0 |

The auditor's `..._lag_alignment.csv` gives share equal 1.000, mean signed difference 0 and mean absolute difference 0 at lag 0 (compared at file precision: two decimals, one for San Antonio). At lags of ±1 hour, no station has more than 0.73 percent of hours equal, and correlations fall to 0.56 to 0.70 (at ±2 hours, 0.40 to 0.56). I repeated the lag-0 comparison independently, on unrounded cell values, and got the counts in the table, with largest absolute difference 0. Because the hourly panel equals `PM2.5.xlsx` over this window (section 2, step C), the same holds against what the pipeline uses.

## Other findings

These are logged in `docs/known_issues.md`, and nothing was changed.

- **The balance rule removes much more than the seven weeks.** It drops 59 of 175 weeks of the PM2.5 panel, all in 2025 and 2026 (`pm25_balance_dropped_weeks.csv`). After the gap, it drops every week from 2025-04-07 to 2026-03-30. Los Chillos has no raw values from April to November 2025, Guamaní none from July 2025 to March 2026, and San Antonio has 102 hours in November 2025 and 1 hour in total from December 2025 to March 2026 (`air_quality/output/local/diagnostics/pm25_gap/pm25_raw_month.csv`). The PM2.5 sample therefore ends with the week starting 2025-03-31. Recovering January and February does not change that end date. The audit's question 8 asks the Secretaría about these later periods for all three stations.
- **No completeness rule for a station-week** (from the code-reviewer). A single weekday peak hour makes a weekly mean.
- **Provenance dates** (from the auditor). `air_quality/data/raw/README.md` gives the REMMAQ download as March 25, 2026; `data_provenance_note.txt` says May 26, 2026. Resolved on 2026-10-01 in `docs/data_provenance/air_quality__2026-05-26_remmaq_download.md`: May 26 for `PM2.5.xlsx` and the other workbooks last saved that day; March 25 belongs to an earlier, replaced download.

## What ran, what was skipped

- **Ran.** The RUNBOOK setup (renv restore) and steps 1 and 2 (`01_read_and_merge.R`, `02_build_weekly_panels.R`) in this worktree, to rebuild the derived panels. Then the new trace script, the data-auditor's audit and its script, and my independent lag-0 check.
- **Reviewed.** The code-reviewer reviewed the trace script and found nothing that misstated presence or absence. I applied its fixes: every sheet is listed, a check that missing cells sit in the same places, station names cleaned with the pipeline's own function, a check linking `read_remmaq()` to the hourly panel, no temporary copy of values left behind, and clearer labels. I then re-ran the script, and the results did not change. A second code-reviewer pass reviewed the auditor's script. It confirmed the three headline claims: identical at lag 0, Los Chillos the only new series, and the decimals. It found that the audit report had the direction of the Los Chillos timing backwards. That is now corrected in the audit, in Spanish question 7 and here. I also made the script stop when a station column is missing, where before it fell back silently. The re-run gave byte-identical tables.
- **Not done, as asked.** No estimate was re-run, no table or panel changed, and the gap-fill file was not merged. The verifier and the claims-auditor have not run; this is a diagnosis for Leonel, not a result leaving the repository.
- **Note.** The renv startup message says the project is "out of sync" (the map packages are installed outside the lockfile, as `ENVIRONMENT.md` records). The rebuilt hourly panel still matches the frozen one byte for byte.

## Suggestions (not done)

1. Send the audit's eight questions to the Secretaría, with question 2 (validated Los Chillos from 2025-01-06 to 2025-03-02) as the main request.
2. Leonel could check the datosambiente portal over the VPN, to see whether Los Chillos for January and February 2025 is now published. That would tell missing at download from never published.
3. Once Los Chillos arrives and Leonel approves it as a source, rebuild the panels and write the old-versus-new table against `frozen_2026-05-29/` for every specification and sample, as `air_quality/CLAUDE.md` requires.
