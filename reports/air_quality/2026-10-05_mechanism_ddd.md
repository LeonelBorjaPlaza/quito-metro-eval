# Mechanism: the triple difference at Centro, and a pre-specified ridership test

Workstream A, priority 3. The triple difference ran in the step 2 diag stage (`606ea82`; script `air_quality/code/local/step2/ddd_centro.R`, plan 3A.3 item 9). The verifier recomputed it with its own code and matched all 18 rows. The ridership test in the last section ran on 2026-10-06 (`0f13136`), and the verifier recomputed it with its own code (`reports/verification/2026-10-06_air_quality_0f13136_checkd_ridership.md`).

## Result

- **PM2.5.** In the pre-disruption window, the weekday-peak share of PM2.5 at Centro falls relative to the control stations: the triple difference is -11.4 percent. Centro ranks second of seven stations, so the placebo p-value is 0.286. With six controls, that test cannot go below 0.143.
- **NO2.** NO2, the clearest tracer of vehicle exhaust, shows no peak-hour decline at Centro in the same window (+0.1 percent, p 0.833, smallest attainable 0.167).
- **What it means for the car channel.** The data do not show a clear peak-hour drop in NO2. The test is weak and cannot tell the possible channels apart.
- **Ridership (added 2026-10-06).** The pre-specified ridership test, run on December 2023 to May 2025, does not support the mechanism. San Francisco's share of entries correlates positively with Centro's gap (Spearman +0.256), against the predicted negative. Station-placebo p is 0.667 (smallest 0.067) and cyclic-shift p 0.438 (smallest 0.0625). Details are in the last section.

## What the triple difference measures

- **D.** For each station and week, D is the log of the mean over weekday peak hours (07-09 and 17-19) minus the log of the mean over all other hours (weekday off-peak and weekends). A station-week counts only if at least half of its peak and half of its off-peak hours are observed.
- **DDD.** The triple difference is Centro's change in D (post-opening minus pre-opening) minus the average change across control stations.
  - Controls A exclude Centro and Belisario.
  - Controls B add Belisario.
- **Inference.** Each control is treated in turn as if it were Centro. The two-sided rank p-value is (1 + number of placebos at least as large in absolute value) / (1 + number of placebos). Its smallest attainable value is 1/7 (0.143) for PM2.5 with controls A, and 1/6 (0.167) for NO2 and CO with controls A.
- **Windows.** The same as the main specification: pre-disruption, donut and full.

## Estimates (`output/local/step2/ddd_centro.csv`)

| Pollutant, window | DDD, controls A (percent) | Placebo p (smallest attainable) | DDD, controls B (percent) | Placebo p (smallest attainable) |
|---|---|---|---|---|
| PM2.5, pre-disruption | -11.4 | 0.286 (0.143) | -10.6 | 0.500 (0.125) |
| PM2.5, donut | -8.8 | 0.429 (0.143) | -8.5 | 0.375 (0.125) |
| PM2.5, full | -11.7 | 0.286 (0.143) | -11.1 | 0.250 (0.125) |
| NO2, pre-disruption | +0.1 | 0.833 (0.167) | -0.7 | 0.857 (0.143) |
| NO2, donut | -3.1 | 0.167 (0.167) | -3.6 | 0.143 (0.143) |
| NO2, full | -4.5 | 0.167 (0.167) | -4.9 | 0.143 (0.143) |
| CO, pre-disruption | -6.6 | 0.500 (0.167) | -5.4 | 0.571 (0.143) |
| CO, donut | -7.1 | 0.500 (0.167) | -6.2 | 0.429 (0.143) |
| CO, full | -6.6 | 0.500 (0.167) | -5.8 | 0.571 (0.143) |

**Centro's rank.** With controls A, Centro's triple difference is the second largest in absolute value among seven stations for PM2.5 (pre-disruption and full). It is the largest of six for NO2 in the donut and full windows, where p equals its floor, and the third of six for CO.

**Where the PM2.5 number comes from** (`output/local/step2/ddd_station_d.csv`, pre-disruption window).
- Centro's D falls from 0.291 to 0.220 (change -0.071).
- The average change across controls A is therefore about +0.050, since -0.071 minus that average gives the -0.121 log points of the DDD. So roughly 60 percent of the PM2.5 DDD is Centro's own peak share falling, and the rest is the control stations' peak share rising.
- Belisario's D changes by -0.011.

**NO2 in the same window.** Centro's D changes by -0.021, about as much as the controls' average, so the DDD is close to zero.

### NO2 by window (added 2026-10-06)

The NO2 triple difference is near zero in the pre-disruption window and negative in the longer windows. Centro's rank counts stations by absolute value, Centro included, from `ddd_centro.csv` (rank = p x (1 + number of placebos)).

| Window | Controls A: DDD (percent), Centro's rank of 6, p (smallest) | Controls B: DDD (percent), Centro's rank of 7, p (smallest) |
|---|---|---|
| Pre-disruption | +0.1, 5th, 0.833 (0.167) | -0.7, 6th, 0.857 (0.143) |
| Donut | -3.1, 1st, 0.167 (0.167) | -3.6, 1st, 0.143 (0.143) |
| Full | -4.5, 1st, 0.167 (0.167) | -4.9, 1st, 0.143 (0.143) |

In the donut and full windows, Centro's NO2 change is the most negative of all stations, and p equals its smallest attainable value; with six or seven stations the test cannot go lower. The donut window adds the 2025 weeks to the pre-disruption weeks, and the full window also keeps the disruption weeks. So the NO2 decline appears only once 2025 is included, not in the first nine months after the opening.

## What it says about the car channel

Fewer cars driving into the historic center at rush hour should first lower Centro's peak-hour pollution relative to its off-peak hours, and most clearly for the exhaust tracers NO2 and CO. In the pre-disruption window, where the main PM2.5 estimate is cleanest, the data show this:
- **PM2.5.** Centro's peak-hour share of PM2.5 falls relative to other stations, by 11.4 percent.
- **NO2.** Centro's peak-hour share of NO2 does not (+0.1 percent).
- **CO.** The CO estimate is negative (-6.6 percent) but no larger than the controls' spread (p 0.500, smallest attainable 0.167).
- **Later windows.** NO2 turns negative (-3.1 percent in the donut window, -4.5 percent in the full window) and is the most extreme of the six stations (p 0.167, its smallest attainable value). The donut window adds the 2025 weeks and the full window also keeps the disruption weeks, so the timing does not tie it to the opening.

A channel that moves particles more than exhaust gases (for example resuspended road dust, buses, or changes in activity around the center) would fit this pattern, but none of these was tested. The data do not show a clear peak-hour drop in NO2, and the test cannot tell these channels apart.

**Limits.**
- With six to eight stations (smallest attainable p from 0.125 to 0.167), the placebo test cannot reject at 10 percent.
- Off-peak hours include weekends, when the metro also runs, so a reduction spread over all hours would not show up in D.
- The PM2.5 controls include Los Chillos's official series, whose hourly timing shifts from late 2024 (`docs/known_issues.md`). This cannot affect the pre-disruption window, which ends in September 2024.
- Guamaní, also a PM2.5 control, had a similar timing episode from June to November 2023, a lag of 3 or 4 hours in five of six months (`docs/known_issues.md`). It falls inside the pre-period of every window, so it can move Guamaní's pre-period D and, through it, the controls' average. Its size was not measured.

## Pre-specified test: San Francisco ridership against Centro's gap path

Written on 2026-10-05, before any ridership data were requested or seen. Added to `air_quality/docs/revision_plan.md` as section 3C, approved by Leonel on 2026-10-06 to run on December 2023 to May 2025 (amendment in 3C). The text below is the pre-specification as written; the result is in the last section.

**Question.** Does Centro's PM2.5 gap fall more in months when more people use San Francisco, the metro station inside the historic center, relative to the rest of the line?

**Data requested from Metro de Quito.**
- Monthly entries (and exits, if available) by station for all 15 stations, from December 2023 to June 2025 at least.
- Hourly or peak/off-peak splits would allow a secondary test aligned with the triple difference, but they are not required.

**Outcome.** The monthly mean of the committed weekly M8b PM2.5 gaps, Centro minus synthetic Centro, from `output/local/step2/diagnostics/gaps_M8b_full_PM25.csv` (as committed in `606ea82`).
- No model is re-estimated.
- Each week is assigned to the month of its start date, except the opening week (starting 2023-11-27), which is assigned to December 2023 because it contains the December 1 opening.
- Blackout weeks (2024-09-16 to 2024-12-16) are excluded, as in the donut window. Months with no remaining week, October and November 2024, drop out.
- That leaves M = 17 months, from December 2023 to June 2025.
- Rule 6 forbids reading a slice of a longer window's effect vector as an effect. Here the monthly means are a description of the committed gaps, used only as the outcome of a correlation test. For the M8b fit the window effects equal the means of their weeks' gaps (the verified donut and pre-disruption estimates are reproduced exactly), so the slices carry no hidden re-estimation.

**Predictor.**
- Primary: San Francisco's share of monthly system entries. Using the share removes the common system-wide ramp-up, which also trends with time.
- Secondary: the log of San Francisco's monthly entries.

**Statistic and prediction.** The Spearman rank correlation between the monthly gap and the predictor, reported sign first. The destination-access mechanism predicts a negative correlation: more San Francisco use, more negative gap.

**Inference, rank-based, two-sided.**
1. **Station placebo.** Compute the same correlation using each of the other 14 stations' shares. The p-value is San Francisco's rank among the 15 by absolute correlation, divided by 15. The smallest attainable p is 1/15 (0.067).
2. **Cyclic shifts.** Recompute the correlation for every cyclic shift of the monthly ridership series against the gap series, M = 17 shifts including the original. The p-value is the share of shifts with an absolute correlation at least as large. The smallest attainable p is 1/17 (0.059).

Neither test can reach 0.05 with this many months and stations. That is stated now so that a large-but-insignificant result is read as such.

**Decision rule, fixed in advance.** The test supports the destination-access mechanism only if both hold:
- the primary correlation is negative;
- San Francisco ranks first or second most negative among the 15 stations.

Otherwise it does not support it, whatever the size.

**Robustness, reported beside the primary result.** The same statistic on month-to-month first differences of both series, which removes slow trends in both.

**Not done.** No pooling with outcomes from the congestion or road-safety modules. No new specification of the air-quality model.

## Ridership test: result (run 2026-10-06)

**Result: the test does not support the destination-access mechanism.** San Francisco's share of monthly metro entries is positively correlated with Centro's monthly PM2.5 gap: Spearman +0.256 over 16 months, against the predicted negative sign. San Francisco ranks 10th most negative of the 15 stations.
- Station-placebo p: 0.667 (smallest attainable 0.067).
- Cyclic-shift p: 0.438 (smallest attainable 0.0625).

Under the pre-specified decision rule, the test does not support the mechanism.

**Caveats, reported with the result.**
1. **Little variation in the predictor.** San Francisco's share of monthly entries stays between 7.8 and 10.2 percent over the 16 months.
2. **The test could not reach 5 percent.** With 16 months and 15 stations, the smallest attainable p-values are 0.0625 (cyclic shifts) and 0.067 (station placebo).
3. **The two delivered files swap some station labels**, including San Francisco in December 2023 (below). The conclusion is the same with either file.

No alternative ridership test was run.

**How it was run.** Approved by Leonel on 2026-10-06 and run as written, with one change: Metro de Quito delivered validations from December 2023 to May 2025, so the window ends in May 2025 instead of June 2025. That gives M = 16 months instead of 17, and smallest cyclic-shift p 1/16 = 0.0625.
- **Two choices fixed before computing.** The predictor comes from the monthly station sheet, and first differences are taken only between calendar-adjacent months.
- **One check added after the totals check (post hoc).** The tests are repeated on the hourly-file totals.
- **Where it is recorded.** All three are in the plan's 3C amendment. The script is `air_quality/code/local/step2/ridership_test.py`. Its outputs are in `air_quality/output/local/step2/ridership/`: `ridership_test_results.csv`, `ridership_test_series.csv`, `ridership_station_placebo.csv` and `totals_check_station_month.csv`.

| Test | Months | Spearman (San Francisco) | Station-placebo p (smallest) | San Francisco's rank, most negative of 15 | Cyclic-shift p (smallest) | Meets the decision rule |
|---|---|---|---|---|---|---|
| Primary: share, levels | 16 | +0.256 | 0.667 (0.067) | 10th | 0.438 (0.0625) | no |
| Secondary: log entries, levels | 16 | -0.303 | 0.533 (0.067) | 8th | 0.250 (0.0625) | no |
| Robustness: share, first differences | 14 | +0.257 | 0.267 (0.067) | 14th | 0.357 (0.071) | no |
| Robustness: log entries, first differences | 14 | +0.240 | 0.200 (0.067) | 14th | 0.214 (0.071) | no |

**Reading the rows.**
- **Secondary.** The only negative correlation is in levels of log entries (-0.303). In levels, a Spearman correlation is the same for log entries and raw entries, because the log does not change the ranks. That series rises with the system's overall growth, while the gap also falls over time, so the two share a time trend. Seven other stations' entries correlate more negatively with the gap than San Francisco's do.
- **First differences.** The robustness rows (calendar-adjacent months only, so 14 differences) are positive.
- **Two different ranks.** The station-placebo p ranks San Francisco by absolute correlation (4th and 3rd in the difference rows). The rank column counts from the most negative, and the decision rule uses that one.

**Data check: the two files Metro de Quito sent disagree on some station totals.** The monthly station sheet and the hourly file summed by station and month agree in 250 of 270 station-months.
- **Labels.** Most differences are station labels swapped between the files. In December 2023, January 2024 and December 2024 the values are permuted and the monthly system total is unchanged. Monthly system totals agree in 16 of 18 months; March and May 2025 differ by 25 and 41 validations. In December 2023 this includes San Francisco: 389,085 in the monthly sheet, 513,260 in the hourly file. Details are in `docs/data_provenance/air_quality__2026-10-05_metro_validaciones_dic2023_may2025.md`.
- **Which source the test uses.** The monthly sheet, chosen before any result was seen.
- **Check with the other file.** Repeated with the hourly-file totals as a check, the primary correlation is +0.412 (station-placebo p 0.400, smallest 0.067; cyclic-shift p 0.188, smallest 0.0625) and the conclusion is the same. The secondary correlation (log entries) is -0.088 (station-placebo p 0.933, San Francisco 14th most negative; cyclic-shift p 0.688).
- **Open question.** Which file is right is a question for Metro de Quito.

**What it means.** Over these 16 months, Centro's gap does not move with San Francisco's share of ridership. The share stays between 7.8 and 10.2 percent, while the gap falls from mid-2024. So the ramp-up of San Francisco use relative to the rest of the line shows no sign of explaining the timing of the gap. The test is weak, though: 16 months, with smallest attainable p-values of 0.06 to 0.07. It does not rule out other ridership channels, for example total system growth, which a share removes by design.
