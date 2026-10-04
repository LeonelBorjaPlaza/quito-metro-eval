# Congestion module: stop before any post-opening month

1 October 2026, workstream B, branch `worktree-congestion-step1`. Governing plan: `congestion/docs/analysis_plan.md`, Amendments 5 (approved as the record) and 6 (the stop). No month from December 2023 on was loaded at any point. Unless a path says otherwise, files are in `congestion/Output/restart_diagnostics/`, written by `Scripts/Congestion/45_restart_diagnostics.R` within the runner `39_run_redesign.R`.

## Decision

**The congestion analysis stops before any post-opening month.** Amendment 5, item 1 (1 October) reads: "If the pre-period work shows that monthly data cannot sign the effect, the report says so, and finer data are sought." Amendment 6 applies it as a stop. The referee's four further computations are not run.

**Reasons, as Leonel gave them:**

- **The measure.** The measure he named on 1 October, the nine-month placebo forecast errors on the 22 tiles, puts the smallest signable fall at 0.92 of CENTER's level (`Output/redesign/mde_empirical.csv`).
- **Plausible effects are far smaller.** Plausible effects of one metro line on central congestion are well under 20 percent; Gu, Jiang, Zhang and Zou (2021) find about 4 percent faster rush-hour speeds near new subway lines (Gu, Jiang, Zhang and Zou, "Subways and Road Congestion", American Economic Journal: Applied Economics, 2021; reference added by me from memory, to be checked).
- **The caveats do not close the gap.** The caveats below are right, but the corrections they imply are far smaller than the gap.
- **CENTER's own record agrees.** It fell 9.3 percent below its forecast in June to October 2023, before the opening, and 13 of 22 tiles missed by as much (`Output/redesign/check_center_vs_placebo_jun_oct_2023.csv`).
  - *Note for Leonel (claims audit):* the 9.3 percent is the shortfall as a share of CENTER's fit-window mean. Against the forecast itself it is 7.9 percent, because the forecast averages 1.18 times the fit mean (`Output/redesign/check_center_jun_oct_2023_paths.csv`, my arithmetic). The 13 of 22 counts misses in either direction; 7 of 22 fell at least as far. Amendment 6 keeps your wording.
- **The known biases point toward a fake fall,** which is the hoped-for direction: that drift, and the over-prediction of high-level units.
  - *Note for Leonel (claims audit):* the drift is measured. The over-prediction of high-level units is inferred from `Output/redesign/contest_overall.csv`; no file reports errors by level.
- **Timing.** Choosing a criterion after seeing 0.92 would weaken any result. Stopping now keeps a later analysis with finer data a clean test.

**My caveats on the 0.92 measure,** recorded with the decision:

- It is not the MDE of the confirmatory CWZ test, of the scaled placebo rank or of the direction rule.
- Its critical value sits between the third- and second-largest of 22 tile errors.
- The tiles have at most 7 cells and lower levels than CENTER (15 cells).
- It is one calendar draw: one 12-month fit and one 9-month forecast.

**The diagnostics below support the decision rather than weaken it.**

- **The errors persist.** Most of the tiles' nine-month error is a persistent offset or drift that does not average out over months.
- **Larger units may help, but the data cannot show it.** CORRIDOR's smallest signable fall ranges from 0.17 to 1.09 of its level, depending on how tile errors are scaled to its size: 0.50 at the fitted slope, 0.82 without the single tile with the largest RMSE.
- **The data do not pass the known-change test.** Reading the hour labels as the start of the hour, the zone moved as expected at 20:00 but not beyond the placebo dates, and the wrong way at 21:00. Reading them as the end of the hour, the hour that should not change moved most. Either way, both hours stepped up in March 2023, a month before the change.

## Your decisions, as recorded (Amendment 6)

1. **Zone, approved as a record.** The south-east gap is now closed by a straight segment of 1,207 m from the eastern end of Av. Morán Valverde to the nearest point of Av. Simón Bolívar, labeled as our assumption (`Output/redesign/zone_summary.csv`, `Output/redesign/map_pico_y_placa_zone.png`).
   - The zone covers 11,992 ha, against 12,125 ha with the connector roads, and contains 0.907 of CENTER's area, 14 of the 15 stations (Quitumbe is outside) and the Belisario point.
   - The 12,125 ha is from the zone summary committed at `32e339e`.
   - With the segment instead of the connector roads, the smallest buffer tried that closes the ring is 250 m, against 100 m before. At 25, 50, 100 and 150 m the ring stays open; 200 m was not tried (`Output/redesign/zone_buffer_trace.csv`). The wider buffer is part of the assumption.
   - The valley check was not run.
2. **The valley check, when it runs:** the 10 district tiles outside the valleys, reported as a weak check, with no neighbouring-municipality tiles.
3. **The CWZ size check failed narrowly.**
   - 3 of 22 placebo tiles rejected at the T = 21 opening (13.6 percent; smallest attainable p 0.048).
   - 1 of 22 at T = 20 (smallest attainable p 0.05).
   - The pooled 4 of 44 does not count (`Output/redesign/check_cwz_size.csv`, relabeled).
4. **The confirmatory test** is deferred to a restart.
5. **The direction rule** is deferred, with one principle fixed: signed, and binding against every pre-period fake effect.
6. **Scale:** proportions stay.
7. **Amendment 5** is approved as the record.

The BELISARIO ring stays rebuilt around 8866d338c9fffff.

## Diagnostics for a restart

All four use pre-period data only. Diagnostics 1, 2 and 4 use the default synthetic control with the 22 district tiles as donors, in proportions. Diagnostic 3 compares road-weighted cell averages inside and outside the zone and uses no model. None reopens the stop.

### 1. Noise over time: the errors persist

| Errors | Units | Lag-1 autocorrelation | Variance ratio | Ceiling | Position between 1 and the ceiling |
|---|---|---|---|---|---|
| Placebo tiles, nine-month forecasts (fit on usable months 1 to 12) | 22 | 0.77 | 7.1 | 9 | 0.77 |
| Placebo tiles, one-month-ahead rolling-origin errors | 22 | 0.34 | not defined | | |
| CENTER, June to October 2023 holdout | 1 | 0.35 (4 pairs) | 2.9 (5 months) | 5 | 0.48 |

Source: `d1_noise_over_time.csv`.

- **The ratio.** It is the variance of the mean error over the monthly variance divided by the number of months.
  - A value near 1 means the errors are month-to-month noise.
  - The ceiling is reached when the error is the same in every month: about 9 for the tiles' nine-month forecasts, 5 for CENTER's five months.
  - With the sample-variance denominators the script uses (22 tile means, 198 monthly errors), the tiles' exact ceiling is 197/21 = 9.4, which puts their position at 0.73 rather than 0.77 (my arithmetic; the script divides by 9).
  - The last column places each ratio between those two ends.
- **The two ratios are computed differently.** The tile ratio compares tiles with each other. CENTER's is a single unit, uncentred. Compare them only through the last column.
- **The lag-1 correlation of 0.77** pools tiles, so it mixes lasting differences between tiles with month-to-month dependence.
- **Implication:** most of the tiles' nine-month error is persistent (a tile-specific offset or drift; this ratio cannot tell the two apart), not noise that averages out. CENTER's five months sit about halfway, on very little data.
- **Weekly or daily values** would shrink the month-to-month part, but for the tiles that part is the smaller one. They would help mainly by giving more pre-period points, which allow drift to be modeled and checked.

### 2. Noise over space and observation: weak signs that size and observation matter

| Regression across the 22 tiles | Slope | 95 percent interval |
|---|---|---|
| log RMSE on log road length | -0.33 | -0.76 to 0.10 |
| log RMSE on log number of cells | -0.95 | -4.21 to 2.32 |
| log RMSE on the 2022 share of cell-hours with a record | -2.28 | -4.43 to -0.12 |

Sources: `d2_noise_fits.csv`, `d2_noise_by_unit.csv`.

- **Definitions.**
  - The RMSE is the rolling-origin forecast error in proportions at horizons of one to three months, cut-offs 12 to 20 (24 forecasts per unit).
  - Road length is the provider's 2022 OSM length summed over each unit's whole cells, the same basis for every unit.
  - The intervals are classical OLS intervals, descriptive only.
- **Size.** The slope on road length is compatible with the square-root law (-0.5) and with no effect of size (0). Twenty of the 22 tiles have 7 cells, so the cell regression says nothing.
- **Observation.** Tiles with more complete records tended to forecast better (slope -2.28), but this rests on one tile. Without the tile with the largest RMSE the slope is -1.09 and its interval, -3.17 to 1.00, includes zero (my computation from `d2_noise_by_unit.csv`). In 2022 the tiles had a record in 62 to 98 percent of cell-hours.
- **CENTER and CORRIDOR beat the tile fit** (`d2_center_corridor_vs_tile_fit.csv`).
  - CENTER: RMSE 0.105, against 0.123 predicted for its 225 km of road; 90 percent of cell-hours observed.
  - CORRIDOR: RMSE 0.072, against 0.098 predicted for 455 km; 98 percent observed.

**CORRIDOR's smallest signable fall, by the 0.92 measure** (`d2_corridor_mde.csv`, CORRIDOR's pre-period mean 9.50 index points):

| How tile errors are scaled to CORRIDOR's road length | Slope used | Smallest signable fall, share of level | Index points |
|---|---|---|---|
| Fitted slope | -0.33 | 0.50 | 4.7 |
| No scaling (slope 0) | 0 | 0.92 | 8.7 |
| Lower end of the slope's interval | -0.76 | 0.17 | 1.6 |
| Upper end of the slope's interval | 0.10 | 1.09 | 10.3 |
| Slope refitted without the tile with the largest RMSE | -0.06 | 0.82 | 7.8 |

- **Every row is an extrapolation.** No placebo unit is as large as CORRIDOR, so the tiles' errors must be rescaled, and CORRIDOR lies beyond the tiles' size range.
- **The answer hangs on one tile.** Without the tile with the largest RMSE, the slope nearly vanishes and the smallest signable fall goes from 0.50 to 0.82.
- **CORRIDOR's own nine-month mean error** is -0.018.
- **Implication:** sparse reporting matters, so a measure of Waze observation (users or reports by cell and month) would help a restart model it or screen on it. Larger units may help. At the most favourable end of the slope's interval, CORRIDOR's figure (0.17) falls just under 20 percent, still about four times the 4 percent in Gu and others (my arithmetic; theirs is a speed effect, not the same measure). Every other row is far above it.

### 3. A known change: the data do not pass the test

- **The hour labels fit local time, but not which end of the hour.** The average weekday profile peaks at 7:00 in the morning and 18:00 in the evening, with its minimum at 3:00 (`d3_hour_label_check.csv`, `d3_weekday_profile_by_hour.csv`).
  - Peaks at those hours fit local time whether a label marks the start or the end of its hour.
  - The test below reads the labels as the start of the hour, so hour 20 is 20:00 to 21:00. If they mark the end, the predictions shift by one hour. The provider question (item 11) asks this.
- **The test.** On 10 April 2023 the evening restriction inside the zone was cut to end at 20:00 instead of 21:00.
  - **Units:** in-zone and out-of-zone road-weighted indexes over the 1,484 population cells that are valid at both hours in every month and have a positive provider road length (`d3_cells.csv`: 1,618 valid, 1,484 of them weighted). 142 cells are inside the zone, 1,342 outside.
  - **Windows:** before is January 2022 to March 2023; after is May to November 2023; April 2023 is out.
  - **Noise:** the same contrast at 11 placebo split dates inside the before window, from after the fourth month to after the fourteenth. A rank among 11 placebos has a smallest attainable p-value of 1/12 = 0.083.

| Hour | Expected | Change in the in-zone minus out-of-zone gap | As a share of the in-zone level before | Largest placebo change (absolute) | Placebos at least as large | Rank p (smallest attainable 0.083) |
|---|---|---|---|---|---|---|
| 20:00 | rise | +0.81 | 34 percent | 1.07 | 1 of 11 | 0.17 |
| 21:00 | fall | +0.27 | 25 percent | 0.49 | 5 of 11 | 0.50 |

Source: `d3_pico_y_placa_hours_20_21.csv`; monthly series in `d3_monthly_zone_series.csv`; the gap by month in `d3_event_time_gap.csv`.

- **At 20:00 the gap rose as expected, but not beyond the placebos.** One placebo split is larger. It is the split that puts March 2023 alone in the "after" window, which shows how much of the change is already present in March.
- **At 21:00 the gap rose, the wrong sign** (if labels mark the start of the hour). If they mark the end, label 21 is the hour that should rise, and it did (+0.27), though 5 of the 11 placebos were at least as large; label 20 would then be an hour with no expected change, yet it rose most.
- **The step comes a month early.** From February to March 2023 the gap rose from 1.87 to 2.69 at 20:00, and from 0.80 to 1.22 at 21:00, before the change of 10 April. The calendar lists no event in March 2023 (`congestion/docs/calendar_shocks.csv`).
- **Other windows agree.** Without June 2022 and November 2023, the changes are +0.75 at 20:00 and +0.22 at 21:00. Comparing the same calendar months (May and July to October) of 2022 and 2023, they are +0.73 and +0.22. Every window shows a rise at both hours.
- **A common upward trend sits under all of it.** All 11 placebo splits at both hours are positive, so the in-zone gap was already growing before the change. These per-split values are my computation from `d3_event_time_gap.csv`; the script writes only their maximum and count.
- **Implication:** these monthly data cannot cleanly show a change of known date and sign. That supports the stop. A restart with daily data and confirmed hour labels could run this test sharply, using the days on either side of 10 April 2023. It should also find out what changed in March 2023.

### 4. Where the drift sits: mostly on the line

Mean forecast error in June to October 2023, fit to May 2023, as a share of each unit's fit mean (`d4_drift_by_group.csv`; by month in `d4_drift_by_group_month.csv`):

| Group | Units | Mean error | Share of unit-months negative |
|---|---|---|---|
| CENTER | 1 | -0.093 | 0.80 |
| BELISARIO | 1 | -0.053 | 0.80 |
| Corridor (up to 1 km), north | 5 | -0.076 | 0.80 |
| Corridor, centre | 3 | -0.111 | 0.80 |
| Corridor, south | 6 | -0.107 | 0.77 |
| 1 to 2 km, north | 6 | -0.008 | 0.50 |
| 1 to 2 km, centre | 8 | -0.107 | 0.65 |
| 1 to 2 km, south | 10 | +0.089 | 0.38 |
| Tiles under 5 km from the line | 7 | -0.013 | 0.66 |
| Tiles 5 to 10 km | 9 | -0.040 | 0.49 |
| Tiles over 10 km | 6 | +0.197 | 0.33 |

- **Pattern.** The over-prediction is on the line (every corridor group, CENTER and BELISARIO) and in the central 1 to 2 km ring. The south 1 to 2 km ring goes the other way (+0.089), and among tiles it does not shrink steadily with distance.
- **It reverses far away.** Tiles more than 10 km from the line are under-predicted (+0.197).
- **Timing.** For CENTER and most corridor groups it is strongest in August to October 2023.
- **The calendar explains none of it.** The only listed shock in the window is the power rationing from 27 October 2023, three weekdays of October (`congestion/docs/calendar_shocks.csv`).
- **Implication:** the drift looks like a change around the line before the opening, or a core-against-periphery divergence. Candidates are works ending, trial runs and feeder changes, none of which is documented in the calendar.
  - **The pre-period.** A restart should consider ending the pre-period earlier (for example in May 2023) and get dates for works and trial operations. The pre-period is not changed here.

## What a restart would need from the provider

Also in `congestion/docs/provider_questions.md`.

| Request | Problem it fixes | How much it would help |
|---|---|---|
| Weekly or daily values | Few pre-period points; known changes blur inside months; holidays cannot be isolated | Diagnostic 1: monthly noise is a small part of the nine-month error (variance ratio 7.1), so finer time alone helps less than it seems. Its main value is more points to model drift, and sharp tests at known dates (diagnostic 3) |
| A measure of Waze users or reports by cell and month | Fewer drivers also means fewer observers; sparse observation adds noise | Diagnostic 2: tiles with more complete records tended to forecast better, but the sign rests on one tile. It is the most direct way to tell fewer jams from fewer reporters |
| Jam speeds | Speeds depend less on how many users report | Already delivered monthly and clean in the pre period. CENTER's speed index correlates -0.31 with its main index (`Output/redesign/check_speed.csv`). Daily speeds would make it a usable outcome |
| Jam lengths clipped to the historic area | CENTER mixes in-polygon road weights with whole-cell indices | Removes the hybrid definition; most useful together with daily values |
| Data for hours 20 and 21, and confirmation of the hour labels | The pico y placa test depends on them | Diagnostic 3: hours 20 and 21 are delivered, and the peaks at 7:00 and 18:00 fit local time, but they cannot tell whether a label marks the start or the end of its hour. That shifts which hour the April 2023 change should move. With daily data and confirmed labels, this becomes the restart's check that the data can see a real change |
| Why severe persistence exceeds 100 | Its definition caps it at 100; the flag rule depends on it | Settles Amendment 1 |
| Whether monthly averages include weekday holidays | The business-day averages may or may not include decreed days off | Needed to interpret any monthly or daily comparison around holidays |

## Left open for a restart

- **The confirmatory test** (decision 4) and **the direction rule** (decision 5, with its signed principle fixed).
- **The referee's four computations:**
  - the power of the actual CWZ test at CENTER;
  - the scaled-rank MDE;
  - the false-direction rate of the main-plus-anchored rule;
  - the MDE without the two largest tiles.
- **The valley check,** with the rule fixed in decision 2.
- **A possible earlier end of the pre-period** (diagnostic 4), and dates of works, trial runs and feeder changes.

## Record and merge

- **What is committed.** The stop, Amendment 6, the diagnostics and this report are committed on branch `worktree-congestion-step1`. The branch is never pushed.
- **Who merges.** Leonel squash-merges the branch into `main` and pushes `main` from his own checkout, since this session works only in its worktree. On 1 October at 17:40, after a fetch, `main` and `origin/main` both stood at `13fe4f1`, the branch's merge base, so no conflict was expected.
- **Left out of main.** The UNESCO overlay map, `reports/congestion/2026-09-29_historic_center_candidates/map_candidates_over_unesco.png`, is removed in the merge commit.
- **Checked before the push.** The squash brings no raw records and no data files; the five entries under `congestion/Data/geo/` are symlinks into the data store. Committed tables that list cells by H3 identifier hold geography, eligibility flags, estimator weights and distances, not provider outcome values. The three items with values tied to single cells, listed under congestion in `docs/known_issues.md` since the verifier of `231a113`, are Leonel's decision before the push.

## What ran, and status of every check

- **Pipeline.** The full runner (`Rscript Scripts/Congestion/39_run_redesign.R`) ran from raw earlier on 1 October, including the corrected zone (44) and a first version of the diagnostics (45). After the code review, scripts 43, 44 and 45 were changed and rerun, then 45 again to write the placebo rank p-values. The no-post check (25), rerun on the committed outputs at 17:40, scanned 113 files and found no value dated December 2023 or later (`logs/stop_report_no_post_check.log`, not committed).
- **Code-reviewer, on 43, 44 and 45.** Its findings were applied before commit:
  - Critical: the first version claimed the 20:00 change exceeded every placebo, from 8 splits that missed March 2023. The script now uses 11 splits, two more windows, an event-time table, sign agreement and rank p-values.
  - Road lengths are now on the provider's basis for every unit, which lowered CENTER's predicted RMSE from 0.168 to 0.123 (the 0.168 and the first version's 8 splits are in the run logs `logs/restart_45.log` and `logs/restart_run_full.log`, which are not committed).
  - The variance ratios now carry their ceilings, and the CORRIDOR figure carries the full range of slopes.
  - The zone script logs why each buffer failed, and the size-check rows are built per opening.
- **Verifier, at `b31cc94`: PASS WITH NOTES.** It ran the runner from raw in a clean worktree (about 9.5 minutes), after the setup step; the 71 raw files matched the store's manifest.
  - All 14 files in `Output/restart_diagnostics/` and `zone_summary.csv`, `zone_buffer_trace.csv` and `check_cwz_size.csv` came out byte-identical, as did the rest of `Output/redesign/`.
  - Its own code reproduced D1 to D4 to within 1e-7, including its own synthetic control fit, the CORRIDOR figures and the hour 20 and 21 contrasts read from raw. The rank counts and p-values match exactly.
  - Its no-post check scanned 96 files, against 113 here: this worktree also holds ignored outputs of scripts 22 to 24 and 32 to 36, which the runner does not make. It confirmed that every outcome read stops at November 2023.
  - Its wording notes (the 13 of 22, the three days, the OLS interval used as evidence) were already among the claims audit's findings. It also notes that the MDE grid gives 0.9162 and 0.49951, against exact values of 0.9155 and 0.49946; both round to the reported 0.92 and 0.50.
  - It disclosed that a `head` of the raw road-length file showed six cell rows dated 2024 (road lengths, not congestion) in its own tool output, unused and unstored. This is recorded in `docs/known_issues.md`.
- **Claims-auditor, on this report at `b31cc94`.** No stale numbers, no em dashes, no Wald or pnorm p-values, and every rank p-value has its smallest attainable value. Its 15 findings were applied:
  - Two method statements were wrong: the RMSE horizons (one to three months, not one) and "all four use the synthetic control" (diagnostic 3 uses no model).
  - Several sentences said more than the evidence: the observation slope (rests on one tile), the 21:00 "wrong sign" (depends on the hour labels), the CORRIDOR range, where the drift sits, and the 250 m buffer (200 m was not tried).
  - The variance-ratio ceiling is 9.4 with the script's denominators.
  - The no-post check was rerun and logged.
  - Three points concern Leonel's own reasons (the 9.3 percent, the 13 of 22, the over-prediction of high-level units). They are noted in the Decision section and in Amendment 6, and his wording is kept.
