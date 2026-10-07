# Air quality revision plan (workstream A)

Written 2026-10-04, before any re-run on the 2026-10-04 REMMAQ delivery. It records decisions already taken, rules fixed before any estimate, and the options still open. Nothing here has been estimated. Evidence: `reports/air_quality/2026-10-05_vintage_comparison.md` and `air_quality/output/local/diagnostics/vintage_2026-10-04/`.

## 1. Decisions taken by Leonel (2026-10-04)

1. **One vintage.** The delivery `air_quality/raw/2026-10-04_remmaq_all_redownload/` replaces the earlier vintages (`air_quality/raw/data/raw/remmaq/`) as the source of every REMMAQ variable the paper uses. A series keeps the earlier vintage only where a defect in the new one is confirmed and recorded in `docs/data_provenance/air_quality__2026-10-04_remmaq_all_redownload.md`. As of this plan, no such defect is confirmed (see the provenance note, section "Defects checked").
2. **Official data are kept** unless a documented problem justifies dropping them. Extra decimals are not such a problem.
3. **PM2.5 after March 2025 is included**, as the gases already run past March.
4. **The Secretaría's gap-fill file is not used.** The new delivery contains the same Los Chillos values for 2025-01-13 to 2025-01-25 (311 of 311 hours equal), and more.
5. **Questions to the Secretaría** are not sent yet.
6. **Belisario distance** waits for the Secretaría's coordinates. No estimate uses distances.

## 2. Rules fixed before any re-run

### 2.1 Reading

- Every station column is read as numeric (`read_remmaq()` already does this with readxl `col_types`); time stamps are rounded to the hour, as now. The new files have rows up to 33 s off the hour (CO), all handled by the rounding.
- Station headers are matched by name. The new HUM header "Santonio" is mapped to San Antonio. Without the mapping, the pipeline drops San Antonio's humidity, a predictor of the San Antonio imputation.
- Negative pollutant values become missing, as now (29 in the new SO2 file).
- Duplicate hours are averaged, as now (one in the new PRE file).

### 2.2 Minimum-hours sensitivity (decided; to run beside the main specification)

A station-week with fewer than half of its weekday peak-hour slots observed is treated as missing. The slots are the weekday hours 07, 08, 09, 17, 18 and 19 present in the hourly spine that week (30 in a full week). The pipeline's short-gap interpolation (runs of up to two weeks), the San Antonio regression imputation and the all-stations rule then apply as written. The main specification keeps the current rule (any observed peak hour makes a weekly mean).

### 2.3 Not changed

The all-stations rule, the two-week interpolation, the San Antonio imputation, the treatment week, the windows (pre_blackout, donut, full), the donor pools, the estimators and the seeds. Any change goes through section 3.

## 3. Months after the current rule's last week (decided 2026-10-05: option B3 is the main specification; see 3A)

Under the current rule, the new delivery keeps every week for all four pollutants up to the week starting **2025-06-16**. From the next week, Guamaní's PM2.5 and gas monitors stop. The all-stations rule then drops every week until Guamaní returns in August 2026 (`weekly_summary.csv`, `weekly_kept_by_month.csv`).

**(a) Last month each pollutant can run under the current rule:** June 2025 (last week 2025-06-16) for PM2.5, CO, NO2 and SO2. Apart from a few weeks in August 2026, no later week survives.

**(b) Options for later months**, by weeks kept out of the 74 weeks from 2025-04-07 to 2026-08-31 (current rule; `weekly_donor_pool_options.csv`). Each option is a full rebuild of the weekly panel without the excluded stations, so the San Antonio regression is refitted on the stations that remain. The pre-period (52 weeks) and the post-period to March 2025 (71 weeks) are fully kept under every option. The blackout weeks are counted; the donut sample would drop 14 of them.

| Pollutant | Current pool | Without Guamaní | Without Guamaní and Los Chillos | Without Guamaní and San Antonio | Without Guamaní, San Antonio and Los Chillos |
|---|---|---|---|---|---|
| PM2.5 | 15 (4) | 69 (39) | 74 (43) | 69 | 74 |
| CO | 11 | 49 | 49 | (no San Antonio in CO) | |
| NO2 | 14 | 57 | 59 | (no San Antonio in NO2) | |
| SO2 | 14 | 73 | 73 | (no San Antonio in SO2) | |

In brackets: of the kept weeks, those in which San Antonio's PM2.5 value comes only from the regression (no observed value that week). For comparison, the current pool already relies on the regression alone for San Antonio in 3 pre-period weeks and 12 post-period weeks to March 2025.

- **Option B1: drop a station from the donor pool for a whole window** when it is missing for most of that window. For a full window ending in August 2026, Guamaní's PM2.5 is missing in 59 of the 74 weeks after March 2025 (CO 63, NO2 60, SO2 59); San Antonio's PM2.5 has its last weekly value in November 2025 (`weekly_station_presence_by_month.csv`). Dropping Guamaní alone keeps 69 PM2.5 weeks, but San Antonio is then regression output only in 39 of them, which is a design question in itself. Dropping a station changes the donor pool in the pre-period too, so the full window becomes a new specification; the pre-disruption and donut windows would keep the current pool.
- **Option B2: extend the San Antonio imputation** (or impute Guamaní the same way). The current regression uses Guamaní (and Los Chillos) as predictors, so it cannot impute San Antonio in a week either is missing. The rebuilds above show what refitting without them does; imputing Guamaní itself would need a new rule.
- **Option B3: end every window at the current rule's last week** (2025-06-16): no change to the rule. The PM2.5 full window gains the seven restored January-February 2025 weeks and 11 weeks from April to mid-June 2025; the gas panels already end at 2025-06-16 in the frozen version, so their length does not change.
- Guamaní's TMP, HUM, PRE and RS do not return in August 2026 (its PM2.5, NO2 and SO2 do), so its weather covariates would be missing in the few August 2026 weeks the current rule keeps.
- Limits no donor rule can fix: in NO2, Centro (the treated station) has one weekly value in August 2025 (of 4 weeks) and one in December 2025 (of 5), and none in January and February 2026; in CO, Tumbaco has no value from April 2026 (2 of 5 weekly values in March 2026); Los Chillos PM2.5 is missing in November 2025.
- **Los Chillos timing and the San Antonio imputation.** The San Antonio PM2.5 regression (`02_build_weekly_panels.R:350-367`) uses the weekly peak-hour PM2.5 of Carapungo, Cotocollao, Guamaní, Los Chillos and Tumbaco, plus San Antonio's weather, as predictors. From late 2024, Los Chillos's hourly PM2.5 runs about two hours behind the other stations (`reports/air_quality/2026-10-05_vintage_comparison.md`, section 4), so its weekly peak-hour mean covers a different part of its daily cycle than before. That shift can carry into San Antonio's imputed values in two ways: directly, in the weeks imputed from late 2024 on, and through the regression coefficients, which are fitted on every week in which San Antonio and all predictors are observed (`lm(..., na.action = na.exclude)`) and then apply to every imputed week. It applies to the current pool and to every option above that keeps Los Chillos as a predictor. The check in 4.4 measures it before any estimate.

## 3A. Decisions of 2026-10-05 (Leonel) and pre-specification of step 2

Written before any step 2 code change or run. Step 2 is approved (Leonel, 2026-10-05).

### 3A.1 Main specification

- **Option B3.** Every window ends at the current rule's last week, the week starting **2025-06-16**, for all four pollutants. Donor pools, the all-stations rule, the two-week interpolation, the San Antonio imputation, estimators, windows and seeds are unchanged. The weekly panels are cut at that week (the few August 2026 weeks the rule would keep are dropped).
- **Data:** the 2026-10-04 delivery for every variable (section 1), read as in 2.1, with the HUM header mapped.
- **Los Chillos PM2.5:** the official data are kept as delivered.

### 3A.2 Pre-specified sensitivities (each reported in its own columns, never mixed into the main table)

All sensitivities run the cross-sample script (the source of the paper's tables) for the specifications the paper reports in the main text: M7, M9, M8 and M8b for PM2.5, and M8b (Table 7) for CO, NO2 and SO2. The main specification runs the full battery, as now.

| ID | Sensitivity | Pollutants | Windows reported | Definition |
|---|---|---|---|---|
| S1 | Extended windows without Guamaní (new specification) | PM2.5, CO, NO2, SO2 | donut, full | Panel not cut at 2025-06-16; it runs to the end of the data. Guamaní is removed from every donor pool, and, for PM2.5, San Antonio too. All other rules as written. Reported with its donor pool and its limits: NO2 Centro has one weekly value in August 2025 and in December 2025, none in January and February 2026; CO Tumbaco has no value from April 2026. Weeks the all-stations rule drops stay dropped. |
| S2a | Los Chillos out of the PM2.5 donor pool | PM2.5 | donut, full | Los Chillos removed from the panel before the San Antonio imputation, so the imputation is refitted without it. Panel cut at 2025-06-16. |
| S2b | Los Chillos PM2.5 shifted two hours earlier | PM2.5 | donut, full | From 2024-12-01 00:00 on, Los Chillos's hourly PM2.5 at hour t takes the value stamped t + 2 h (the value stamped 09:00 is treated as 07:00), before the weekly peak-hour means; the San Antonio imputation is refitted on the shifted series. Panel cut at 2025-06-16. |
| S3 | Minimum hours (section 2.2) | PM2.5, CO, NO2, SO2 | pre_blackout, donut, full | As in 2.2. Panel cut at 2025-06-16. |
| S4 | 2023 rationing weeks dropped | PM2.5, CO, NO2, SO2 | pre_blackout, donut, full | Drop every Monday week containing a day from 2023-10-27 to 2023-12-15: the weeks starting 2023-10-23 to 2023-12-11 (5 pre-period weeks and 3 post-period weeks, including the treatment week). The treatment week becomes the first kept post week, 2023-12-18. Decided by Leonel on 2026-10-05. |

S2a and S2b are sensitivities, not corrections: the cause of the Los Chillos timing change is unknown and has been asked of the Secretaría. The pre-disruption window is not reported for them, because the change begins in late 2024.

### 3A.3 Diagnostics written before the run

1. **Section 4.4 check** (San Antonio imputation with and without Los Chillos) runs after the panels are built and before any estimation script.
2. **Belisario placebo without Centro.** In the spatial placebo (Table 6, scripts `04b` and `04c`), the Belisario row is always estimated with Centro removed from its donor pool. The earlier version kept Centro, which, if Centro's PM2.5 fell after the opening and Centro carries weight, pushes Belisario's estimate up. Other rows are unchanged.
3. **Donor weights** for every main specification (from the `donor_weights` column of the cross-sample tables), tabulated by pollutant, specification and window.
4. **Leave-one-donor-out for Centro.** M8b, all four pollutants, all three windows: drop each donor in turn and re-estimate; report the range of ATTs and their conformal p-values against the full-pool estimate.
5. **Gap plots** (Centro actual minus synthetic, log points, by week) for M8b, all four pollutants, full window, with the treatment week and the blackout weeks marked.
6. **Residual autocorrelation.** For M8b, all four pollutants: autocorrelations of the weekly gaps at lags 1 to 4, pre-period and post-period separately. Descriptive only, with no p-values.
7. **Pseudo-openings inside the pre-period.** For M8b, all four pollutants: the panel is cut at the real treatment week; fake treatment weeks are placed at pre-period weeks 20, 22, ..., 44 (13 dates, at least 19 pre weeks and 9 pseudo-post weeks each); each gets the two-sided conformal p-value. Report the rejection rate at 0.05 and 0.10 and the share of negative pseudo-effects.
8. **Block conformal p-value** (`type = "block"` in augsynth's conformal inference, moving-block permutations, so the smallest attainable p-value is 1 over the number of weeks in the sample) beside the current iid conformal p-value, for M7, M8, M8b and M9 (PM2.5) and M8b (gases), all three windows. Each p-value is shown with its smallest attainable value.
9. **Triple difference at Centro** for PM2.5, NO2 and CO, from the hourly data (new delivery, from 2022-12-01 to the week starting 2025-06-16):
   - for each station and Monday week, D = log(mean of weekday peak hours 07-09 and 17-19) minus log(mean of all other hours, weekday off-peak and weekends), using station-weeks with at least half of the peak slots and half of the off-peak hours observed;
   - DDD = (mean D at Centro, post minus pre) minus (mean over control stations of the same difference), with controls = every analysis station with the pollutant except Centro and Belisario (Belisario may be treated); a second version adds Belisario to the controls;
   - windows: pre_blackout, donut and full, with the same week sets as the cross-sample script;
   - inference: placebo permutation over the control stations (each in turn treated as Centro, the rest as controls), two-sided rank p-value (1 + number of placebo DDDs at least as large in absolute value) / (1 + number of placebos), reported with its smallest attainable value. No Wald or normal p-values.

### 3A.3a Clarifications after code review (2026-10-05, before any run)

- **Where the B3 cut applies.** After the short-gap interpolation, the San Antonio imputation and the all-stations rule, on the finished weekly panel, so those steps see the data as in step 1's coverage counts. `11_descriptives.R` and `99_missingness_diagnostic.R` apply the same end date to their hourly counts.
- **S3 slots.** The slots are the weekday peak hours in the panel data from 2022-12-01 on, so the first week (starting 2022-11-28) has 12 slots, consistent with how its weekly mean is built.
- **S1 end.** With no cut, the last week of the delivery (starting 2026-08-31, one day) is kept if every station reports; the report states it.
- **S2a and S2b** also write gas panels that nothing reads.
- **Conformal p-values and simulation noise.** The iid conformal p-value uses 1,000 random permutations. A sensitivity that runs fewer specifications, or a diagnostic that reseeds before each call, draws a different random stream, so part of a main-versus-sensitivity difference in p is simulation noise (standard error about sqrt(p(1-p)/1000), for example about 0.007 at p = 0.05). The report states it; the paper's p-values stay those of the main cross-sample tables.
- **Check 4.4.** Period "December 2023 to September 2024" includes the week starting 2024-09-30; relative changes use the value without Los Chillos as the base.
- **Triple difference and Los Chillos.** Los Chillos's official PM2.5 enters the PM2.5 triple difference as a control. Its late-2024 timing change affects the control mean and one placebo in the donut and full windows. Logged in `docs/known_issues.md`; no variant without Los Chillos is run unless Leonel asks for it.

### 3A.4 Order

Code changes, code-reviewer, commit, then: panels; the 4.4 check; the main specification (RUNBOOK steps 3 to 6); the sensitivities; the diagnostics. Then the verifier on a clean checkout, the old-versus-new report with the paper-number map (main results first, every sensitivity in its own columns), the methods-referee and the claims-auditor. If the spend limit stops an agent, work stops and Leonel is told.

## 3B. Check d: pseudo-openings with block p-values (decided by Leonel, 2026-10-05; written before any run)

Purpose: Refine's general comment on conformal calibration. A diagnostic of the existing M8b specification for PM2.5; no new specification, window or donor rule.

- **Estimator.** The `fit()` call of `code/local/step2/centro_diagnostics.R` (M8b: Centro treated, all other stations as donors, `augsynth` with ridge, `scm = TRUE`, `fixedeff = TRUE`, weather covariates), with `set.seed(12345)` before each conformal call.
- **Main pre-period.** The 52 pre-treatment weeks of the main PM2.5 panel. Pseudo-openings at weeks 20, 22, ..., 44 (13 dates), each with the iid and the block conformal p-value. The iid results must reproduce `output/local/step2/diagnostics/pseudo_openings_M8b_PM25.csv`.
- **S4 pre-period.** The PM2.5 panel with the 2023 rationing weeks dropped (`AQ_SENS=S4 AQ_DROP_RATIONING=1`), whose pre-period is 47 weeks ending with the week starting 2023-10-16. Pseudo-openings at weeks 20, 22, ..., 38 (10 dates; the same calendar dates as in the main panel; later dates would leave fewer than 9 pseudo-post weeks, the existing guard). Iid and block p-values.
- **Floors.** Iid: smallest nonzero 0.001 (0 attainable). Block: 1/T with T the number of weeks in the pseudo sample, 52 (0.019) on the main pre-period and 47 (0.021) on S4.
- **Reported.** For each panel and p type: the rejection rate at 5 and 10 percent, the share of negative pseudo-effects, and every pseudo-opening's effect and p-values. No other summary is computed.
- **Caveat stated with the results.** The pseudo-post windows are nested (all end at the last pre week), so the rejection rates are not independent draws.
- **Run.** In Leonel's terminal (two commands in `RUNBOOK.md`). Code-reviewer before the run; verifier on the output commit.

## 3C. San Francisco ridership against Centro's gap path (proposed 2026-10-05; approved 2026-10-06, see the amendment below)

Written 2026-10-05, before any ridership data were requested or seen. Full text: `reports/air_quality/2026-10-05_mechanism_ddd.md`, last section.

- **Outcome.** Monthly mean of the committed M8b PM2.5 weekly gaps (`output/local/step2/diagnostics/gaps_M8b_full_PM25.csv` at `606ea82`), weeks assigned to the month of their start date (the opening week, starting 2023-11-27, to December 2023), blackout weeks excluded. These monthly means describe the committed gaps and are not read as effects; for the M8b fit the window effects equal the means of their weeks' gaps. Months December 2023 to June 2025 with at least one non-blackout week (M = 17). No model is re-estimated.
- **Predictor.** San Francisco's share of monthly system entries (primary); log San Francisco entries (secondary).
- **Statistic.** Spearman correlation, two-sided, sign first. The prediction is negative.
- **Inference.** (1) Station placebo: San Francisco's rank among the 15 stations' share correlations by absolute value, p = rank/15 (smallest 0.067). (2) Cyclic shifts of the monthly ridership series (M = 17 shifts including the original; smallest p 0.059).
- **Decision rule.** Support only if the primary correlation is negative and San Francisco ranks first or second most negative among the 15 stations.
- **Robustness.** The same on month-to-month first differences.

**Amendment, 2026-10-06 (Leonel).**
- **Approval.** 3C is approved as written, to run on December 2023 to May 2025, the last month Metro de Quito delivered (`air_quality/raw/2026-10-05_metro_validaciones_dic2023_may2025`). So M = 16 and the smallest cyclic-shift p is 1/16 = 0.0625. The June 2025 weeks drop out.
- **Two choices fixed by the maker before computing.**
  - Source: the predictor comes from the monthly station sheet.
  - First differences are taken only between calendar-adjacent months, so September to December 2024 is not differenced, which gives 14 differences.
- **Added after the totals check (post hoc).** The totals check found that the monthly sheet and the hourly file swap some station labels (San Francisco in December 2023 among them). The primary and secondary tests are therefore also reported on the hourly-file totals, as a data-source check. The monthly-sheet result is the result of record.
- **Code and outputs.** `code/local/step2/ridership_test.py` (code-reviewed); outputs in `output/local/step2/ridership/`.

## 3D. Correction to the inference (decided by Leonel, 2026-10-06)

**What had been seen.** Iid conformal p-values were seen for every estimate; block p-values only in the step 2 diagnostics. Sources are in `output/local/step2/diagnostics/`.
- **Iid on the main pre-period.** Pseudo-openings inside the pre-period, where there is no treatment, rejected at 5 percent in 8 of 13 cases and at 10 percent in 10 of 13 (`pseudo_openings_block_summary_main_PM25.csv`).
- **Iid without the 2023 rationing weeks (S4).** It still rejected 2 of 10 at 5 percent and 4 of 10 at 10 percent (`pseudo_openings_block_summary_S4_PM25.csv`).
- **Block, cyclic shifts.** In the same pseudo-openings it rejected 0 of 13 and 0 of 10 at 5 percent. At 10 percent it rejected 6 of 13 on the main panel, against an effective level of 0.096, and 1 of 10 on S4.

So in these pseudo-windows the iid test rejects far more often than its nominal rate. The block test does not at its effective 5 percent level, but it does at 10 percent on the main panel. The windows are nested, so this cannot separate test size from a Centro-specific shock in late 2023.

**Decision.**
- **Tables.** Wherever a block p-value was computed (Tables 5 and 7, and Table A.3 Panel C), the table reports it beside the iid p-value for the same estimate, with its smallest attainable value 1/T. These are 1/94 pre-disruption, 1/120 donut and 1/134 full.
- **Paper text.** Section 4 explains why, and states that iid p-values use 1,000 random permutations with smallest nonzero value 0.001.
- **No new estimation.** The block p-values come from the step 2 diagnostics (`block_conformal_*.csv`). They belong to the same fits as the tables, and `code/local/step2/paper_tables.py` checks that the effects match.

**Block p-values available.**
- PM2.5: M7, M8, M8b and M9 in all three windows, so Table 5 and Panel C of Table A.3.
- The gases: M8b in all three windows, so Table 7.

**Not computed, so not reported.** No new run without Leonel's approval.
- PM2.5 M4, M5, M5b and M6 (Table A.3, Panel B).
- The spatial placebos (Table 6).
- SDID, which has no conformal inference (Table A.3, Panel A).

## 4. Step 2: the full re-run

### 4.1 Code changes (minimal, each in its own commit, reviewed before the run)

1. `code/local/01_read_and_merge.R`: `raw_dir` points to the new delivery; `standardize_name()` maps "santonio" to "sanantonio". Nothing else.
2. The minimum-hours sensitivity as a switch in `02_build_weekly_panels.R` (default off), writing separate panel files (for example `*_completepanel_peakweekly_minhalf.csv`), and a matching switch in the setup scripts to read them.
3. Whatever Leonel decides in section 3, as its own change: the panel cut at 2025-06-16 (B3) and the switches for the sensitivities of 3A.2 (station exclusion, Los Chillos shift, minimum hours, rationing weeks), each off by default; outputs of a sensitivity go to their own folder.

### 4.2 Scripts and outputs the re-run touches (RUNBOOK order)

| Step | Scripts | Outputs |
|---|---|---|
| 1 | `01_read_and_merge.R` | `data/processed/hourly_panel.csv` |
| 2 | `02_build_weekly_panels.R` | `data/processed/{pm25,CO,NO2,SO2}_completepanel_peakweekly.csv` (and the minimum-hours versions) |
| 3 | `03_analysis_setupPM2.5.R`, `04_PM2.5.R`, `04_PM2_5_crosssample.R`, `04b_spatial_placebo_PM25_M8b_conformalp.R`, `04c_spatial_placebo_PM25_M5b_conformalp.R`, `fig_pm25_eventstudy_pub.R` | `output/local/tables/{results,donor_weights,trajectories,att_weekly}_PM25.csv`, `output/local/crosssample/CrossSample_Summary_PM25.csv`, `output/local/spatial_placebo/spatial_placebo_PM25_{M8b,M5b}_conformalp.{csv,_log.txt}`, `output/local/figures/event_study_PM25_*.png`, `fig_pm25_eventstudy.{png,pdf}` |
| 4 | `05`-`06` CO, `07`-`08` NO2, `09`-`10` SO2, each with its cross-sample script | the same tables and figures per gas |
| 5 | `99_missingness_diagnostic.R`, `11_descriptives.R` | `output/local/diagnostics/missingness_*.csv`, `output/local/tables/descriptives_*.csv`, `output/local/figures/descriptives_time_series.{png,pdf}` |
| 6 | `12_cross_pollutant_master.R` | `results_all_pollutants.csv`, `results_primary_specs.csv`, `headline_event_study_M5b.{png,pdf}` |

Figure 1 (map) does not change. The satellite design (Tables 1, 4, 8, 9, A.2; Figures 3, 4) does not use REMMAQ data and is not re-run.

### 4.3 How each paper number will be reported

- An old-versus-new table for every specification and sample, against `frozen_2026-05-29/` (as `air_quality/CLAUDE.md` requires): for each pollutant, specification (M1 to M12 where reported, with M7, M9, M8, M8b and M5b first) and window (pre_blackout, donut, full), the frozen and new ATT (log points and percent), conformal p-value with its smallest attainable value, pre-period RMSPE, weeks pre and post, and donor weights. The sign of each effect is reported first, with whether it changed.
- A paper-number map: every number printed in the local results (Tables 2, 3, 5, 6, 7, A.1, A.3; Figures 2 and 5; the text of sections 5.1 to 5.3 and the abstract) listed with its page and line in `congestion/docs/paper/Underground-relief.txt`, its frozen source cell, its new value and the change. The claims-auditor checks the map before it goes to Leonel.
- The minimum-hours sensitivity is reported in its own columns, never mixed into the main table.
- Order: code change, code-reviewer, commit, run, verifier on a clean checkout, the report, methods-referee, claims-auditor, Leonel.

### 4.4 Check before any estimate: San Antonio imputation without Los Chillos

Run after the weekly panels are built and before any estimation script. It is a diagnostic; it changes no panel and no specification unless Leonel decides so afterwards.

1. Build the PM2.5 weekly panel as specified, and again with the San Antonio regression refitted without Los Chillos as a predictor (all other predictors and steps unchanged). Do this for the current pool and for whichever option of section 3 Leonel chooses.
2. Compare the two fits:
   - the regression coefficients and the number of weeks used to fit them;
   - San Antonio's imputed weekly values, week by week: mean signed difference (with Los Chillos minus without), mean absolute difference and the largest absolute difference, overall and separately for the pre-period, December 2023 to September 2024, and October 2024 on;
   - the affected weeks: weeks imputed in one fit but not the other, and weeks whose imputed value changes by more than 10 percent;
   - whether any week enters or leaves the panel under the all-stations rule.
3. Report the comparison in the step 2 report before any estimate is shown, with the sign of the differences first. If the imputed values differ materially, Leonel decides which fit the main specification uses; the other becomes a sensitivity.
