# Moving to the 2026-10-04 REMMAQ delivery: comparison and proposed rules (step 1 of 2)

Workstream A. No estimate was re-run, nothing was merged or pushed, and the pipeline was not changed. The new delivery is not yet wired into the pipeline.

## Results in brief

- **The new delivery can replace the earlier vintages.** No defect was found in any series the paper uses. The large RS difference in February 2026 is a defect of the *earlier* vintage, which was flat at about 1 to 2 W/m² day and night. It never reached a frozen panel.
- **History is almost untouched where the frozen panels use it.** From December 2022 to March 2025, no value of TMP, HUM, VEL, DIR, LLU, PRE, CO or NO2 changed. In PM2.5, only Los Chillos changed, in November 2024 and March 2025. SO2 has only newly filled hours. The big SO2 revisions (median new-to-old ratio 2.20 to 12.95 by station and year, `vintage_ratio_by_station_year.csv`) are all in 2004 to 2007, at five stations. Some hours present in the earlier vintage are now gone, mainly Guamaní PM2.5 (244 hours from December 2022 to March 2025).
- **The Los Chillos gap is filled.** The new file covers 1,296 of the 1,344 hours from 2025-01-06 to 2025-03-02, and it equals the Secretaría's file exactly in all 311 shared hours. The March 9 to 22 hole is still empty. It spans two weeks, which the pipeline's two-week interpolation fills.
- **The Los Chillos PM2.5 timing changed at the end of 2024.** From October 2024, its series lags the other stations by about two hours in most months (15 of 22); October and November 2024 have little data, and December 2024 and January 2025 are the first clear months. Before, the lag was 0 or 1 hour in every month (21 of 21). The station's CO still peaks at 7:00 every month, and its solar radiation timing did not move, so the clock looks right. No other station shows a lasting shift.
- **After March 2025, coverage limits every pollutant to June 2025 under the current rule.** All four pollutants keep every week up to the week starting 2025-06-16. Then Guamaní stops, and the all-stations rule drops nearly every later week. The options and their coverage are in `air_quality/docs/revision_plan.md`, section 3, for you to decide.
- **Plan, rules, questions.** The minimum-hours sensitivity and the step 2 plan are written in `air_quality/docs/revision_plan.md`. The questions are revised in `reports/air_quality/2026-10-05_questions_secretaria_draft.md`. The claims-auditor checked the questions and these documents, and its corrections are in. The verifier passed the comparison and coverage tables with notes on commit `5b19967` (`reports/verification/2026-10-05_air_quality_5b19967.md`).

## 1. Provenance

`docs/data_provenance/air_quality__2026-10-04_remmaq_all_redownload.md` is filled in. It gives the source, the file names, sheets, date ranges, row counts and sha256 of every workbook, the terms, the coverage and the caveats. It also names the files the paper uses that this delivery does not replace: the event dates hard-coded in `01`, the map layers and the satellite inputs. It records why PM10 stays out of the paper. In the new file, PM10 has five columns but only four header names. Which station the unnamed column holds is not established (the files cannot tell a discontinued Guamaní monitor from a lost header label); PM10 is not used, so it was not pursued. The file also repeats almost every hour (227,608 of its 228,438 rows fall in duplicated hours).

## 2. Comparison with the earlier vintages

Script: `air_quality/code/local/diagnostics/vintage_compare.py`. Tables: `air_quality/output/local/diagnostics/vintage_2026-10-04/`. By station and month: `vintage_compare_station_month.csv`. By period: `vintage_compare_station_period.csv`.

- **Columns read as numeric.** Every station column is read as numeric, whatever a reader would guess: numbers stay numbers, numeric text becomes a number, other text becomes missing. The earlier CO vintage stores missing values as the text "NA" in 366,037 cells; the new workbooks the paper uses have no text cells (`vintage_inventory.csv`).
- **Pipeline type guessing.** The pipeline itself reads with `col_types` set to numeric. Its `02` step re-reads the hourly CSV with `read_csv`, which guesses types. On the new delivery, that guess loses no value (`weekly_read_csv_type_check.csv`).

**Time stamps.** The reader rounds every time stamp to the nearest hour, as `01` does (`round_date(fecha, "hour")`). In the new delivery, every row 1 s or more off the hour dates from 2025-12-04 or later (the first sub-second offset is at 2025-11-30 23:59:59.995, which rounds into 2025-12-01 00:00). Counts below are rows more than 1 s off; the verifier's report gives the counts at 1 s or more, which differ by at most 201 rows (`vintage_inventory.csv`, `rows_off_ge_1s` against `rows_off_gt_1s`):

- **PM2.5:** 1,291 rows more than 1 s off (1,292 at 1 s or more), up to 7.455 s, from July 2026.
- **CO:** 6,387 rows, up to 32.9 s.
- **DIR, LLU, RS:** about 5,540 rows each, up to 29 s.
- **NO2:** 1,294 rows, up to 7.465 s. **SO2:** 555. **TMP and HUM:** about 450, up to 4 s.

All fall after the hour, except TMP's, which fall before it (`vintage_inventory.csv`).

In the earlier vintages, PM2.5, CO and the weather files had none. NO2, SO2 and PM10 had about 450 rows more than 1 s off, up to 4 s, from March 2026. All offsets are far below half an hour, so rounding assigns every row to its own hour, and no duplicate hours result. The one exception is PRE, where a single hour appears twice in the file itself; the pipeline averages it.

**Revisions by period**, summed over the eight analysis stations (El Camal left out). Each cell gives hours whose value changed / hours newly filled / hours that were in the earlier vintage and are gone:

| Variable | Before 2022-12 | 2022-12 to 2023-11 (pre-period) | 2023-12 to 2025-03 | 2025-04 on |
|---|---|---|---|---|
| PM2.5 | 0 / 18 / 116 | 0 / 1 / 134 | 334 / 1,313 / 124 | 379 / 26,410 / 37 |
| CO | 0 / 27 / 115 | 0 / 6 / 0 | 0 / 24 / 55 | 3,644 / 28,726 / 467 |
| NO2 | 0 / 0 / 0 | 0 / 1 / 0 | 0 / 0 / 0 | 0 / 20,525 / 0 |
| SO2 | 104,246 / 4,761 / 8,519 | 0 / 110 / 9 | 0 / 253 / 9 | 2,017 / 20,581 / 12 |
| TMP | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,443 / 0 |
| HUM | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,440 / 0 |
| VEL | 0 / 3 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,766 / 0 |
| DIR | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,767 / 0 |
| LLU | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,916 / 0 |
| PRE | 0 / 1 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 25,440 / 0 |
| RS | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 4,642 / 25,441 / 0 |

El Camal, which the pipeline drops, adds 32,548 changed SO2 hours in 2004 to 2007, and 669 changed RS hours in February 2026.

The period table, by station, is `vintage_compare_station_period.csv`.

Your points, checked:

- **a. Most changes are new hours from April 2025 to August 2026.** Confirmed (last column of the table). Every workbook the paper uses now runs to 2026-08-31 23:00 (earlier: 2026-03-31, CO 2025-12-31). New hours after March 2025 are at most about 3,700 per station for each variable that ran to March 2026. CO, whose earlier vintage ended in December 2025, has up to 5,482. Los Chillos PM2.5 has 8,193, because the earlier vintage also lacked April to November 2025.
- **b. PM2.5: history nearly unchanged; Los Chillos 158 revised hours in 2024 and 203 in 2025.** Confirmed.
  - The 158 hours of 2024 are all in November 2024 (median absolute difference 0.0067, maximum 49.9).
  - Of the 203 hours of 2025, 176 are in March 2025 (median 1.61, maximum 10.6) and 27 are in December 2025 (0.01, a rounding change). 350 hours of January 2026 also differ by 0.01.
  - **Not in your list:** Guamaní PM2.5 *loses* hours that the earlier vintage had. That is 132 hours from December 2022 to November 2023 and 112 from December 2023 to March 2025, up to 47 in a month (October 2024). These fall in the analysis period. The panel will lose those values.
- **c. CO: only 2025 revisions, about 600 to 700 hours per station, small differences (median ratio near 1).** Mostly confirmed, with one exception.
  - The changed values are all in December 2025 (619 to 726 hours per station; Los Chillos 216) and November 2025 (98 hours at Cotocollao). These months fall after the frozen CO panel ends (2025-06-16).
  - The median new-to-old ratio is 0.99 to 1.05, except Cotocollao, at 0.75 in November and 0.81 in December.
  - A few hours present in the earlier vintage are gone in January to June 2025, which the frozen panel covers: up to 19 a month at Tumbaco and 10 at Guamaní.
- **d. SO2: large revisions at Belisario and Centro in 2004 to 2007, new values 2 to 10 times the old, plus about 2,000 hours at Centro in 2026.** Confirmed, and the pattern holds for the other three stations:
  - Belisario, Centro and El Camal are revised in 2004 to 2007; Carapungo and Cotocollao in 2005 to 2007.
  - The median ratio by station and year runs from 2.20 (Centro, 2004) to 12.95 (El Camal, 2006) (`vintage_ratio_by_station_year.csv`).
  - Centro also has 2,017 revised hours in January to March 2026 (median ratio 0.93 to 0.96).
  - **The study windows:** no SO2 value changed anywhere from December 2022 to March 2025. The only revisions there are newly filled hours (up to 28 a month at a station, Los Chillos in January 2025) and 18 removed hours. The Centro 2026 revisions fall after the frozen SO2 panel ends (2025-06-16). They would fall inside a full window that runs into 2026, if you choose one (section 5).
- **e. RS: about 650 hours per station from April 2025 differ by up to about 1,250 W/m², which looks like day and night swapped for about four weeks.** The block is exactly February 2026, every hour at every station (648 to 669 hours each; maximum difference 1,149 to 1,260 W/m²). It is not a swap.
  - The earlier vintage averages about 1.5 to 2.4 W/m² at midday and under 1 W/m² at night that month, at every station with data. The new vintage has a normal daily curve with zero at night (`rs_night_check.csv`).
  - RS enters the paper as a weather covariate (`rs_imp`), so the new vintage is the right one.
  - The defect never reached a paper number: no frozen panel reaches 2026. PM2.5 ends at 2025-03-31, and CO, NO2 and SO2 at 2025-06-16.
  - Small night values appear in *both* vintages at some stations: Centro averages 6.8 to 9.6 W/m² at night from October 2024 to February 2025, and Carapungo 1.6 to 7.7 W/m² from January 2024 to January 2025. They look like zero offsets, not clock shifts, and are not a difference between vintages.
- **f. HUM: San Antonio headed "Santonio".** Confirmed. The pipeline's `standardize_name()` would turn it into "santonio" and drop San Antonio's humidity, a predictor of the San Antonio imputation. The diagnostics map it to San Antonio; step 2 adds the mapping to `01` (`revision_plan.md`, 2.1).
- **g. O3 is new to the store.** The paper does not use O3, from REMMAQ or any other source. Ozone appears in the paper text only in the titles of two cited references.

**Defects in series the paper uses:** none confirmed in the new vintage, so every series comes from the new vintage. No series keeps the earlier one.

## 3. Los Chillos PM2.5

`loschillos_new_vs_gapfill.csv`, `loschillos_new_coverage.csv`, `loschillos_weeks_feb_apr_2025.csv`:

- **Coverage.** The new file has 1,296 of the 1,344 hours from 2025-01-06 to 2025-03-02, confirming your count. The earlier vintage had 55.
- **Against the Secretaría's gap-fill (2025-01-13 to 2025-01-25):** all 311 shared hours are exactly equal at lag 0. They are also equal after rounding, and the median and maximum difference are 0. At lags of ±1 hour, 22 or 23 hours match; at ±2 and ±3, none do. There is no shift.
- **The March 9 to 22 hole is still empty** (0 hours). The weeks starting March 10 and 17 have 0 Los Chillos weekday peak hours, and the weeks on either side have all 30. So the gap is two weeks, within the pipeline's two-week interpolation. In the weekly diagnostic on the new delivery, Los Chillos has a value in both weeks after interpolation, and both weeks are kept.

## 4. Los Chillos timing

Tables: `timing_by_month.csv` (weekday morning peak hour, RS centroid, TMP maximum hour), `loschillos_pm25_lag_by_month.csv`, `pm25_lag_by_station_month.csv`.

**The lag measure.** Each station's hourly PM2.5 is correlated, month by month, with the mean of five stations present in every month from 2023 (Belisario, Carapungo, Centro, Cotocollao and Tumbaco, leaving out the station itself). The lags run from -4 to +4 hours, and a negative best lag means the station's pattern comes later.

- **When the change began: the end of 2024.** From January 2023 to September 2024, Los Chillos's best lag is 0 or -1 in all 21 months. Where -1 wins, it beats lag 0 by at most 0.043 in correlation. From October 2024 to August 2026, the best lag is -2 or later in 15 of 22 months, often by a wide margin: in January 2025, 0.51 at -2 against 0.36 at lag 0. October 2024 is a weak month (301 hours; 0.18 at -2 against 0.15 at lag 0, during the power cuts, and Tumbaco is also at -3 that month), and November 2024 is at 0. December 2024 and January 2025 are the first clear months. Of the rest, 3 months are at -1, 2 at 0, and 2 at a positive lag (August 2025 and May 2026, both with weak correlations).
- **The morning peak.** Los Chillos's weekday morning PM2.5 peak (hours 4 to 12, months with every hour seen on at least 10 weekdays) is too noisy to date the change on its own. It falls at 7:00 in some months of 2023 and early 2024 and at 10:00 to 12:00 in others. From April 2024 it is never earlier than 8:00. In your periods: January and February 2025 at 10:00, March 2025 at 9:00, and January to March 2024 at 8:00, 8:00 and 7:00. Centro and Tumbaco mostly peak at 6:00 to 9:00, with Centro at 11:00 or 12:00 in some months (June to October 2024, several months of 2025 and 2026).
- **Other variables at Los Chillos do not show it.**
  - Its CO morning peak is at 7:00 in every month with data from 2023 to 2026, except 6:00 in October 2024.
  - Its RS centroid (the radiation-weighted mean hour) runs 10.9 to 11.8 h, tracking the other stations month by month. It sits between 0.06 h earlier and 0.29 h later than Centro, in 2023 as much as in 2025 and 2026, with no jump in late 2024 (no value in October and November 2024).
  - Its TMP maximum stays at 12:00 to 14:00.
  - So the station's clock looks right, and the change is specific to the PM2.5 series.
- **Other stations.** No other station shows a lasting shift. Guamaní has an earlier episode, a lag of -3 or -4 in five of the six months from June to November 2023 (in the pre-period). It is mostly between -1 and +1 after that, with -3 in August 2024 and -2 in October 2024. Belisario is at -1 or -2 in scattered months, mostly October 2023 to August 2024. Carapungo is at +1 to +3 in many months. Centro, Cotocollao and Tumbaco are at 0 almost every month (Tumbaco -3 in October 2024 and -1 in March and August 2026).
- Nothing was shifted. The timing question to the Secretaría is question 4 of the revised list.

## 5. Coverage after March 2025

Script: `air_quality/code/local/diagnostics/vintage_weekly_coverage.R`. It runs the pipeline's own `01` and `02` code on the new delivery in a temporary folder, with the HUM header mapped, and changes no pipeline file. Tables: `weekly_summary.csv`, `weekly_kept_by_month.csv`, `weekly_stage_F_by_week.csv`, `weekly_station_presence_by_month.csv`, `weekly_donor_pool_options.csv`. Hours by variable, station and month from 2024-10 are in `coverage_new_by_month.csv`.

**Your PM2.5 points,** checked in `coverage_new_by_month.csv`:

- **Guamaní** has no PM2.5 from July 2025 to July 2026. Confirmed. In fact every Guamaní variable stops in mid-June 2025. PM2.5, NO2, SO2, DIR, LLU and VEL return in August 2026; CO, TMP, HUM, PRE and RS do not.
- **San Antonio** fades from October 2025 (353 hours) and is empty from December 2025. Confirmed: 103 hours in November 2025, then 2 hours in total from December 2025 to August 2026.
- **Los Chillos** is empty in November 2025. Confirmed.
- **El Camal** is empty in July and August 2026. Confirmed, for every variable, from mid-June 2026.

**(a) The last month each pollutant can run under the current rule:** June 2025, for all four pollutants. Every week is kept up to the week starting 2025-06-16; the next week is the first dropped. Like for like, a PM2.5 panel ending in March 2025 would have 123 weeks against 116 now (the seven restored weeks), and one ending at 2025-06-16 would have 134. Counted to the end of the file, it has 138, including 4 weeks in August 2026. Apart from a few weeks in August 2026, when Guamaní returns, no later week survives. Under the minimum-hours rule, the unbroken run ends a week earlier for PM2.5 and CO (2025-06-09). For NO2 and SO2 it breaks at 2025-03-03, because short weeks in March 2025 now count as missing.

**(b) Options for later months.** The table counts weeks kept out of the 74 weeks from 2025-04-07 to 2026-08-31, current rule. Each option rebuilds the panel without the excluded stations, so the San Antonio regression is refitted on the stations that remain. The number in brackets is the kept weeks in which San Antonio's value comes only from the regression.

| Pollutant | Current pool | Without Guamaní | Without Guamaní and Los Chillos | Without Guamaní and San Antonio | Without Guamaní, San Antonio and Los Chillos |
|---|---|---|---|---|---|
| PM2.5 | 15 (4) | 69 (39) | 74 (43) | 69 | 74 |
| CO | 11 | 49 | 49 | | |
| NO2 | 14 | 57 | 59 | | |
| SO2 | 14 | 73 | 73 | | |

- **What limits each option:**
  - Dropping Guamaní works for SO2 almost fully.
  - For CO, Tumbaco stops from March 2026.
  - For NO2, Centro, the treated station, has one weekly value in August 2025 (of 4 weeks) and one in December 2025 (of 5), and none in January and February 2026. No donor rule can fix that.
  - For PM2.5, dropping Guamaní leaves San Antonio as pure regression output in 39 of 69 weeks, unless San Antonio is dropped too.
- **The options themselves** are in `revision_plan.md`, section 3:
  - B1: drop a station from the donor pool for a whole window.
  - B2: extend or re-specify the imputation.
  - B3: end every window at the current rule's last week.
- **Every option leaves the pre-period and the post-period to March 2025 fully covered.**

## 6 and 7. Plan

`air_quality/docs/revision_plan.md` is new. Before any re-run, it records:

- the decisions of October 4;
- the reading rules, including the HUM header mapping;
- the minimum-hours sensitivity as decided: a station-week with fewer than half of its weekday peak-hour slots observed is treated as missing, and the interpolation and all-stations rule then apply as written;
- the coverage options for you to choose from;
- step 2: the two code changes, every script and output the full re-run touches, and how each paper number will be reported against its new value. That means an old-versus-new table for every specification and window, sign first, plus a paper-number map checked by the claims-auditor.

## 8. Questions for the Secretaría

`reports/air_quality/2026-10-05_questions_secretaria_draft.md` replaces the earlier eight questions:

- **Dropped:** the Los Chillos gap and the decimals, which the new data answer, and the minor January 13 to 16 interruptions.
- **Kept:** units, hour convention (now also asking about the time stamps with seconds), empty cells and flags.
- **Rewritten:** the Los Chillos timing question, now about a change in the PM2.5 equipment at the end of 2024, without claiming the cause.
- **Updated:** the later gaps.
- **Added:** the differences between the May and October files (including the Los Chillos PM2.5 revisions of November 2024 and March 2025), and the exact current coordinates of every monitor with any relocation dates from 2022 to 2026. Leonel confirmed on 2026-10-05 that the May files all came from the portal, and question 6 now says so.

### Checks

- **Claims-auditor** (on commit `4b15ca5`), with the questions as its main target. It found:
  - Question 4 said the Los Chillos CO peaks at 7:00 "every month", but it is 6:00 in October 2024. The question also claimed the logger clock was fine, which no file shows.
  - Question 7 stated where the Belisario monitor is today, from an undated CORPAIRE document, and called the coordinates truncated.
  - Question 6 quoted an SO2 range that no file held.
  - Question 5 contradicted itself on San Antonio.
  - In the report and the provenance note: three sha256 typos, a stale timing sentence, the Centro NO2 weeks, a night-radiation claim, the scope of "no change in the analysis period", and a week count that compared unlike horizons.

  All are corrected, and the counts that had no file are now saved: SO2 ratios by station and year, the direction of the time-stamp offsets, and the PM10 fifth column (`vintage_ratio_by_station_year.csv`, `vintage_inventory.csv`). Question 6 first spoke of "los archivos que obtuvimos en mayo de 2026", because the May note left open whether every earlier file came from the portal; Leonel confirmed on 2026-10-05 that they did.
- **Verifier: PASS WITH NOTES on commit `5b19967`** (`reports/verification/2026-10-05_air_quality_5b19967.md`). A first attempt on `4b15ca5` stopped on the account's spend limit. The verifier worked in its own checkout and computed every requested count with its own code before opening the references. It also re-ran both scripts, which reproduced all 18 committed tables byte for byte. It found no unsupported count. Its notes are about definitions: time-stamp counts are rows more than 1 s off, now said explicitly, and the first offsets date from 2025-12-04, now stated exactly. It also notes that the weekly figures were checked against the reproduced pipeline tables, not an independent reimplementation, and that the weekly script writes a temporary hourly CSV that R deletes at exit.

## Other findings (logged in `docs/known_issues.md`)

- `standardize_name()` in `01` maps "ú" to "n" (a typo in its `chartr` call). No current station name has "ú", so nothing is affected yet. Found by the code-reviewer.
- The PM10 file repeats almost every hour and has an unnamed column. PM10 is not used.

## What ran

- **Two new diagnostic scripts:**
  - `vintage_compare.py`, which reads every workbook of both vintages and the gap-fill file, about 10 minutes per run.
  - `vintage_weekly_coverage.R`, which runs the pipeline's own code on the new delivery in a temporary folder, with one panel rebuild per pollutant, rule and donor set.
- **Code review.** The code-reviewer reviewed both scripts. It found a critical error in my first donor-pool counts: they read the exclusion sets off a single build, so San Antonio's regression could not be refitted, and dropping Guamaní looked like it kept 34 PM2.5 weeks instead of 69. It also found completeness rules too loose for the morning peak and the RS centroid, a wrong denominator in the RS night share, and a Los Chillos lag measure whose comparison stations changed over time. All are fixed and the scripts re-run. The numbers above are from the final runs.
- **Pipeline untouched.** No pipeline script, panel or table changed. The new delivery is read only by the diagnostics.
- **Not done, as asked.** No estimate, no merge, no push, no question sent.
- **Code review of the `97dd1de` additions** (SO2 ratios, offset direction, PM10 column). Its fixes were applied in `5b19967`: cells past the header are read; the ratio medians carry their sample, with 99.9 percent of differing SO2 hours behind the quoted medians; offsets are rounded to milliseconds; and the PM10 claim is softened. Every previously committed value was unchanged on re-run.
