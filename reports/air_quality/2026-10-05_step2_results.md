# Step 2: re-estimation on the 2026-10-04 REMMAQ delivery, old against new

Workstream A. The main specification and every pre-specified sensitivity and diagnostic of `air_quality/docs/revision_plan.md` (section 3A) were run at commit `a172a9e`, with outputs committed in `606ea82`.

- **Sources.** Numbers below come from these folders under `air_quality/output/local/`, against the frozen reference `frozen_2026-05-29`:
  - `step2/`: the comparison tables and diagnostics;
  - `crosssample/`, `sensitivity/` and `spatial_placebo/`.
- **P-values.** All are two-sided. An iid conformal p-value uses 1,000 random permutations. Its smallest nonzero value is 0.001, and a printed 0 means no permutation was as extreme (p < 0.001).
- **Paper-number map:** `air_quality/output/local/step2/paper_number_map.csv`. Paper line numbers refer to `congestion/docs/paper/Underground-relief.txt`.

**Verification.** The verifier passed `606ea82` with notes (`reports/verification/2026-10-05_air_quality_606ea82.md`). A clean re-run from raw reproduced every step 2 output byte for byte, apart from PDF date stamps, with every p-value identical. Its notes are in section 9.

## Results in brief

**What the new data change**

- **San Antonio imputation check (plan 4.4): not material.** Run before any estimate. The check refits San Antonio's imputation with and without Los Chillos as a predictor.
  - Both fits impute the same 19 weeks. They are counted before the all-stations rule and the June 2025 cut, and 15 of them are in the main panel.
  - Imputed values with Los Chillos minus without differ by:
    - -0.60 µg/m3 on average in the pre-period (3 weeks);
    - +0.02 from December 2023 to September 2024 (3 weeks);
    - +0.20 from October 2024 (13 weeks).
  - None changes by more than 10 percent, and no week enters or leaves the panel.
- **The preferred PM2.5 estimate is unchanged in the pre-disruption window.** Centro, M8b: -0.131 log points, -12.2 percent, conformal p = 0.016 (smallest nonzero p 0.001). The paper prints -0.130, -12.2 percent and p = 0.011.
  - This is the only one of the 12 M8b pollutant-by-window tests in the main run with p at or below 0.05. One more, PM2.5 in the full window, is at or below 0.10.
- **In the donut and full windows the reduction holds, but the p-values rise.** Donut: -13.7 percent, p = 0.199 (paper: -12.4 percent, p = 0.041). Full: -15.6 percent, p = 0.097 (paper: -15.1 percent, p = 0.006).
  - The weekly gaps of the 18 weeks these windows now add are more negative than the pre-disruption average: the seven restored January-February 2025 weeks average -0.141, and the 11 weeks from April to June 2025 average -0.212. These are slices of the full-window gap series, not separate estimates.
  - So the point estimate does not fade, but why the p-values rose is not established (section 2).
  - The robustness estimator M5b (no station fixed effects) loses significance in the same windows: donut p = 0.191, full p = 0.057.
- **The Belisario placebo in Table 6 changes sign, because of the new donor rule.** Estimated without Centro in its donor pool, as now pre-specified, it is -6.1 percent, p = 0.740. Table 6 printed +8.5 percent, p = 0.452, from a synthetic Belisario that was 0.731 Centro.
  - Under M8b, Centro remains the only station with a significant negative placebo estimate (-12.2 percent, p = 0.013).
  - Under M5b, Tumbaco's placebo is -28.7 percent with p < 0.001, in both runs.
  - Cotocollao's positive M8b estimate moves from p = 0.061 to 0.047, a change of the size the new data and simulation noise can produce together.
- **Gases.**
  - NO2 barely changes: log effects move by about 0.0001 and p-values by at most 0.005, and M8b prints the same to three decimals.
  - CO M8b changes little, and every M8b conformal p stays at 1.000. The SDID CO estimates move more: M1 donut goes from -16.9 to -6.9 percent and M2 donut from -17.7 to -3.5.
  - The SO2 donut effect falls from 13.1 to 10.0 percent, with p from 0.055 to 0.120.
- **Sensitivities, PM2.5 M8b.**
  - Pre-disruption: the result holds under minimum hours (S3: -12.2 percent, p = 0.010) and without the 2023 rationing weeks (S4: -12.5 percent, p = 0.018).
  - Donut and full windows: every sensitivity keeps a reduction of 13.3 to 17.4 percent, with p-values from 0.058 (S4, full) to 0.658 (S1, donut).
  - M7 and M9 are less stable. Details are in section 4.

**What re-reading the paper's own estimates finds (true in the frozen outputs too)**

- **Most of the pre-disruption estimate comes from June to September 2024.** Its 42 post-opening weekly gaps average -0.131.
  - The last 12, from 2024-06-24 to 2024-09-09, average -0.385 and carry 84 percent of the total.
  - The first 30 average -0.029, and 7 of the first 8 are positive.
  - The frozen M8b weekly effects show the same pattern (-0.130, -0.384, 84 percent, -0.029, 7 of 8).
  - So the paper's description of an effect that appears "in the first months of operation" and deepens gradually never matched its own estimates (section 5).
- **M8b is close to a comparison of Centro with Belisario.** Belisario's weight is 0.849. The paper already printed the three numbers that matter, and they barely move:
  - Belisario treated (M9): -6.0 percent, now -6.1;
  - Centro without Belisario (M8): -17.0 percent, now -17.2, p = 0.431;
  - Centro with Belisario (M8b): -12.2 percent.

  These fit a reading in which both stations near the line fell, Centro by more. Under that reading, M8b measures Centro's change net of Belisario's. The paper's step that Table 5 "establishes Belisario as a placebo-treated station with no comparable response" (line 611) does not follow from an imprecise -6 percent (section 5).
- **The pseudo-opening diagnostic is hard to read.** Placed inside the pre-period, where there is no treatment, pseudo-openings reject at 5 percent in 8 of 13 cases for PM2.5 M8b.
  - The 13 cases are nested: every pseudo-post window ends at the real opening and contains the late-2023 rationing weeks, when the M8b gap was large and positive.
  - The result fits two readings: the iid conformal test may be oversized, or Centro had a real Centro-specific shock before the opening.
  - The block conformal p for the pre-disruption window is 1/94 (0.011), the smallest value it can take, and the PM2.5 pre-period gaps are close to uncorrelated (lag 1: 0.076). The block test was not run on the pseudo-openings, so it does not settle the question.
- **The triple difference at Centro points the same way but cannot reject.** PM2.5, weekday peak against off-peak and weekends, controls without Belisario: -11.4 percent in the pre-disruption window and -11.7 percent in the full window.
  - Centro ranks second of seven in both windows (p = 0.286).
  - With six controls the smallest attainable p is 0.143, so this test cannot reject at 10 percent whatever the data.

## 1. What changed between the frozen run and this one

1. **Data.** Every REMMAQ variable comes from the 2026-10-04 delivery, with the HUM header "Santonio" mapped to San Antonio (`reports/air_quality/2026-10-05_vintage_comparison.md`).
2. **Windows.** Every window ends at the week starting 2025-06-16 (option B3).
   - For PM2.5 this adds the seven January-February 2025 weeks the old file lacked, plus 11 weeks from April to mid-June 2025.
   - The PM2.5 full window grows from 116 to 134 weeks (64 to 82 post-opening), and the donut from 102 to 120.
   - The gas windows keep their length of 134 weeks (`window_weeks.csv`).
3. **Belisario placebo.** Centro is removed from Belisario's donor pool in `04b` and `04c` (plan 3A.3 item 2).
4. **Nothing else.** Estimators, donor pools, window rules, the San Antonio imputation and seeds are unchanged.

## 2. Main results, old against new

**Table 5 (PM2.5).** Percent effect, with conformal p in brackets. "Old" is the paper's value.

| Window | M7 Centro + Belisario | M9 Belisario (Centro excluded) | M8 Centro (Belisario excluded) | M8b Centro (Belisario retained) |
|---|---|---|---|---|
| Pre-disruption, old | -11.7 (0.610) | -6.0 (0.729) | -17.0 (0.392) | -12.2 (0.011) |
| Pre-disruption, new | -11.8 (0.655) | -6.1 (0.737) | -17.2 (0.431) | -12.2 (0.016) |
| Donut, old | -8.5 (0.809) | -2.3 (0.849) | -14.2 (0.486) | -12.4 (0.041) |
| Donut, new | -6.2 (0.877) | +1.3 (0.863) | -13.0 (0.775) | -13.7 (0.199) |
| Full, old | +4.1 (0.807) | +15.1 (0.698) | -5.8 (0.506) | -15.1 (0.006) |
| Full, new | +2.9 (0.922) | +13.9 (0.863) | -7.1 (0.767) | -15.6 (0.097) |

- **Fit.** The M8b pre-period fit is unchanged: pre RMSPE 0.129, post-to-pre ratio 1.98 in the pre-disruption window.
- **Sign changes.** One sign changes in Table 5: M9 in the donut window, from -2.3 to +1.3 percent, both far from significance.

**Why the donut and full p-values rose is not established.** Two changes are mixed together: the new data vintage and the 18 added weeks.
- **The vintage.** The pre-disruption window cannot isolate it, because that window ends in September 2024 and most vintage differences are in the 2025 weeks (for example Los Chillos's refilled series). S2a, which drops Los Chillos, moves the donut p from 0.199 to 0.094.
- **Power.** As the post-opening window grows relative to the whole sample (68 of 120 weeks in the donut, 82 of 134 in the full window), a random permutation fills the "post" slot mostly with true post-opening weeks. A sustained shift then loses power.
- **Separating the two** would need a new run, listed under "Suggestions".

**Table 7 (M8b, four pollutants).** Percent effect (conformal p).

| Window | PM2.5 | CO | NO2 | SO2 |
|---|---|---|---|---|
| Pre-disruption, old | -12.2 (0.011) | -5.4 (1.000) | -6.2 (0.967) | -2.5 (0.187) |
| Pre-disruption, new | -12.2 (0.016) | -5.5 (1.000) | -6.2 (0.967) | -5.1 (0.248) |
| Donut, old | -12.4 (0.041) | -7.9 (1.000) | -5.4 (0.610) | +13.1 (0.055) |
| Donut, new | -13.7 (0.199) | -7.4 (1.000) | -5.4 (0.610) | +10.0 (0.120) |
| Full, old | -15.1 (0.006) | -10.2 (1.000) | -5.8 (0.716) | +10.0 (0.124) |
| Full, new | -15.6 (0.097) | -9.8 (1.000) | -5.8 (0.716) | +7.3 (0.249) |

**Robustness estimators for PM2.5** (`main_old_vs_new.csv`), as the paper quotes them in section 5.3:
- **M5b** (augmented synthetic control without fixed effects, Centro treated, Belisario retained):
  - pre-disruption: -9.5 percent, p 0.011 to 0.019;
  - donut: -10.1 to -11.6 percent, p 0.020 to 0.191;
  - full: -13.3 to -13.8 percent, p 0.003 to 0.057.
- **M2b** (SDID): -14.5 to -14.9 percent pre-disruption, and 13.9 to 19.8 percent across windows (old 14.3 to 20.7).

**Across the full battery** (12 specifications, 3 windows, 4 pollutants; `main_old_vs_new.csv`), 5 of 144 estimates change sign, all within 2.5 percent of zero in both runs:

- PM2.5:
  - M9 donut: -2.3 to +1.3 percent; p 0.849 to 0.863.
  - M1 (SDID) full: +0.5 to -0.8 percent; this specification has no p-value in either run.
- CO, M5b donut: -0.2 to +0.3 percent; p 1.000 in both.
- SO2, M5:
  - donut: +0.2 to -2.4 percent; p 0.413 to 0.672;
  - full: +0.2 to -2.1 percent; p 0.495 to 0.740.

## 3. Spatial placebo (Table 6)

Pre-disruption window, M8b estimator, each station treated in turn (`placebo_old_vs_new.csv`). Percent effect (conformal p).

| Station | Paper | New |
|---|---|---|
| Centro | -12.2 (0.012) | -12.2 (0.013) |
| Belisario | +8.5 (0.452) | -6.1 (0.740), without Centro in its donor pool |
| Guamaní | -7.8 (0.523) | -9.0 (0.585) |
| Cotocollao | +4.5 (0.061) | +5.2 (0.047) |
| Carapungo | -8.9 (1.000) | -9.2 (1.000) |
| Los Chillos | +21.8 (0.135) | +21.7 (0.136) |
| Tumbaco | -17.7 (0.785) | -17.8 (0.768) |
| San Antonio | +9.2 (0.574) | +10.0 (0.565) |

- **Belisario.** The new row has the same estimate as M9 in Table 5 (-6.1 percent), since both now estimate Belisario without Centro. The p-values differ (0.740 against 0.737) because of the random stream.
  - The old +8.5 percent rested on a synthetic Belisario that was 0.731 Centro.
  - The paper printed both -6.0 (Table 5) and +8.5 (Table 6) for Belisario.
- **Two cautions on "only Centro":**
  - It holds under M8b only. Under M5b, Tumbaco is -28.7 percent with p < 0.001 (0 of 1,000 permutations as extreme), in both runs.
  - The placebos have no rule for poorly fitted stations. Carapungo's synthetic puts a weight of 1.12 on Cotocollao, which is extrapolation.
- **Distances.** A redrawn Table 6 must take its distances from the paper. The placebo files still swap Tumbaco's and San Antonio's distance to the corridor (known issue).

## 4. Sensitivities (`sensitivities_long.csv`)

Percent effect (conformal p). As pre-specified, S1, S2a and S2b are reported for the donut and full windows only.

| Spec, window | Main | S1 no Guamaní/S. Antonio, to Aug 2026 | S2a Los Chillos out | S2b Los Chillos shifted | S3 minimum hours | S4 no rationing weeks (treatment week 2023-12-18) |
|---|---|---|---|---|---|---|
| PM2.5 M8b, pre-disruption | -12.2 (0.016) | | | | -12.2 (0.010) | -12.5 (0.018) |
| PM2.5 M8b, donut | -13.7 (0.199) | -16.8 (0.658) | -13.3 (0.094) | -13.9 (0.167) | -13.4 (0.177) | -13.3 (0.146) |
| PM2.5 M8b, full | -15.6 (0.097) | -17.4 (0.556) | -15.8 (0.088) | -15.8 (0.107) | -14.6 (0.120) | -14.9 (0.058) |
| PM2.5 M8, pre-disruption | -17.2 (0.431) | | | | -17.2 (0.363) | -16.1 (0.270) |
| PM2.5 M8, donut | -13.0 (0.775) | -21.2 (0.362) | -7.7 (0.873) | -15.2 (0.828) | -12.7 (0.767) | -11.3 (0.574) |
| PM2.5 M8, full | -7.1 (0.767) | -18.3 (0.364) | -8.5 (0.781) | -9.2 (0.775) | -12.2 (0.709) | -3.8 (0.523) |
| PM2.5 M9, pre-disruption | -6.1 (0.737) | | | | -5.9 (0.832) | -3.7 (0.468) |
| PM2.5 M9, donut | +1.3 (0.863) | -6.0 (0.270) | +8.8 (0.990) | -1.5 (0.888) | +1.5 (0.910) | +3.3 (0.700) |
| PM2.5 M9, full | +13.9 (0.863) | -1.1 (0.590) | +12.9 (0.789) | +11.0 (0.841) | +4.4 (0.841) | +17.7 (0.759) |
| PM2.5 M7, pre-disruption | -11.8 (0.655) | | | | -11.7 (0.685) | -10.1 (0.394) |
| PM2.5 M7, donut | -6.2 (0.877) | -13.9 (0.228) | +0.2 (0.977) | -8.6 (0.899) | -5.9 (0.911) | -4.3 (0.715) |
| PM2.5 M7, full | +2.9 (0.922) | -10.1 (0.393) | +1.6 (0.869) | +0.4 (0.898) | -4.2 (0.835) | +6.4 (0.796) |
| CO M8b, pre-disruption | -5.5 (1.000) | | | | -6.7 (1.000) | -7.8 (1.000) |
| CO M8b, donut | -7.4 (1.000) | +10.8 (0.990) | | | -7.6 (1.000) | -9.4 (1.000) |
| CO M8b, full | -9.8 (1.000) | +8.3 (0.982) | | | -8.9 (1.000) | -11.4 (1.000) |
| NO2 M8b, pre-disruption | -6.2 (0.967) | | | | -6.2 (0.968) | -7.1 (0.960) |
| NO2 M8b, donut | -5.4 (0.610) | -12.1 (< 0.001) | | | -5.0 (0.932) | -6.5 (0.628) |
| NO2 M8b, full | -5.8 (0.716) | -11.6 (0.001) | | | -5.2 (0.935) | -6.8 (0.749) |
| SO2 M8b, pre-disruption | -5.1 (0.248) | | | | -5.1 (0.235) | -4.4 (0.210) |
| SO2 M8b, donut | +10.0 (0.120) | +1.6 (0.034) | | | +6.6 (0.139) | +11.9 (0.137) |
| SO2 M8b, full | +7.3 (0.249) | +1.0 (0.035) | | | +5.1 (0.144) | +8.8 (0.231) |

**S1** extends the windows to the end of the data, with 140 PM2.5 post-opening weeks against 82. It also drops Guamaní (and San Antonio for PM2.5) from every donor pool.
- **Two changes at once.** S1 changes the window and the donor pool together, so a difference from the main result cannot be attributed to either one alone. For CO, leave-one-donor-out shows that dropping Guamaní alone turns the estimate positive (section 5), so CO's positive S1 estimate is plausibly the donor change.
- **Pre-specified limits:**
  - NO2 Centro has one weekly value in August 2025 and one in December 2025, and none in January and February 2026.
  - CO Tumbaco has no value from April 2026, so the CO S1 panel ends with the week starting 2026-03-09.
  - The last PM2.5 week, starting 2026-08-31, holds one day.
- **Small S1 p-values for the gases.** S1 NO2 donut has p < 0.001 (0 of 1,000 permutations as extreme). S1 NO2 full has p = 0.001; S1 SO2 has p = 0.034 (donut) and 0.035 (full).
  - The conformal test rejects zero effect in every week jointly; it does not test the average. A small average effect can therefore carry a small p when weeks deviate in both directions, as SO2 shows (+1.6 and +1.0 percent).
  - What drives the NO2 rejection is not known. Centro's NO2 series has long gaps in 2025-2026, but weeks with Centro missing are dropped by the all-stations rule. The S1 NO2 gap path should be examined before this p is given weight.
  - **Update 2026-10-07: do not cite the S1 NO2 result.** S1 includes the two periods in which Centro's NO2 analyzer is suspected faulty: mid-June to July 2025, and March to mid-May 2026. In both, Centro's NO2 falls to about 0.4 to 0.6 of Belisario's while its CO and PM2.5 do not fall relative to Belisario's. Details are in `docs/known_issues.md`.

**S3** masks station-weeks with too few weekday peak hours. As a result its donut drops 10 PM2.5 weeks and 8 CO weeks, not 14 (verification report, section 2a).

**S4** removes the eight weeks from 2023-10-23 to 2023-12-11: five before the opening and three after. The treatment week moves to 2023-12-18, and the pre-disruption window becomes 47 pre and 39 post weeks.
- It also removes the positive late-2023 gaps, so the M8b pre RMSPE falls from 0.129 to 0.113.
- The M8b result is unchanged without those weeks: -12.5 percent, p = 0.018. That is evidence against the rationing weeks driving the result, and it bears on the pseudo-openings (section 5).

**Simulation noise.** Part of each main-versus-sensitivity difference in p is noise, because a sensitivity runs fewer specifications and so draws a different random stream (plan 3A.3a).
- **Size.** One p-value has a standard error of about sqrt(p(1-p)/1000): 0.004 at p = 0.016. A difference between two independent runs has a standard error about 1.4 times larger.
- **The headline.** On the new data the headline estimate appears with p = 0.016 (Table 5), 0.013 (placebo run) and 0.021 (reseeded run). These are consistent with simulation noise. The paper's 0.011 comes from the old data.
- **Not noise.** The S2a donut p (0.094 against 0.199) is a real difference.

## 5. Diagnostics

### Where the pre-disruption estimate comes from

Source: `diagnostics/gaps_M8b_full_PM25.csv` and the gap plot `step2/figures/gap_M8b_PM25.png`. The M8b fit uses only the pre-period. So the pre-disruption estimate is the mean of the 42 weekly gaps from 2023-11-27 to 2024-09-09, which is -0.131.
- **Early weeks.** The first 30 post-opening weeks, to 2024-06-17, average -0.029. Seven of the first eight are positive.
- **Late weeks.** The 12 weeks from 2024-06-24 to 2024-09-09 average -0.385 and carry 84 percent of the sum. The three largest gaps fall in this stretch: -0.642 (2024-09-09), -0.622 (2024-07-15) and -0.519 (2024-08-19).
- **April 2024.** Two weeks have large negative gaps: -0.309 (2024-04-15) and -0.268 (2024-04-29).
- **The 2023 dry season** (2023-06-26 to 2023-09-18, 13 weeks) has a mean gap of -0.041.
- **Not new.** The frozen M8b weekly effects (`frozen_2026-05-29/output/local/tables.zip`, `att_weekly_PM25.csv`) give the same pattern: mean -0.130, last 12 weeks -0.384 and 84 percent of the total, first 30 weeks -0.029, 7 of the first 8 positive. This is a finding about the paper's own estimates, not a change caused by the new data.

These readings describe the plot; they are not estimates. A claim about a sub-period effect would need its own approved window, estimated separately.

What they imply for the paper:
- **The event-study narrative in section 5.1 does not describe the estimates.** It says the estimates "move below zero during the first months of operation and deepen through 2024" (lines 593-594) and reports a "gradual deepening" (line 601). The phrase "not driven by a single post-opening week" (lines 600-601) is still literally true, since the late effect spans 12 weeks.
- **"In the first months of operation" is repeated** in the abstract (line 22), the introduction (line 89) and the conclusion (line 861).
- **The divergence opens in the 2024 dry season.** The paper itself describes the drought in lines 157-162. A shock that hits Belisario's area differently from Centro's would move the gap with no Metro effect. With one dry season in the pre-period, such a seasonal divergence cannot be fully told apart from a delayed effect. The calm 2023 dry season helps, but it is one year.
- **The triple difference partly addresses this.** It nets out shocks that hit all hours alike, and in the pre-disruption window it is -11.4 percent.
- **April 2024 needs checking.** The two large April 2024 gaps may coincide with rolling power cuts in Ecuador that month, which the paper does not mention. This is to be confirmed with a source.

### Donor weights and leave-one-donor-out

**Donor weights** (`donor_weights_main.csv`).
- **PM2.5 M8b.** Belisario carries 0.849. The other positive weights are Cotocollao 0.070, Carapungo 0.067 and Los Chillos 0.049, with small negative weights on Guamaní, San Antonio and Tumbaco.
- **Across windows.** The weights are identical, because the pre-period fit is shared.
- **Gases.** The SO2 M8b synthetic Centro is also mostly Belisario (0.823); CO and NO2 spread their weight more widely.

**Leave-one-donor-out for Centro** (`diagnostics/loo_centro_M8b_PM25.csv`). Percent effect, with the reseeded iid p in brackets. Dropping Belisario is M8 by construction; its p here comes from a reseeded run, and the main run gives 0.431.

| Dropped | Pre-disruption | Donut | Full |
|---|---|---|---|
| none | -12.2 (0.021) | -13.7 (0.208) | -15.6 (0.085) |
| Belisario | -17.2 (0.406) | -13.0 (0.790) | -7.1 (0.776) |
| each of the other six | -11.6 to -12.5 (0.005 to 0.029) | -13.3 to -13.9 (0.126 to 0.239) | -15.4 to -15.9 (0.069 to 0.108) |

For the gases (`loo_centro_M8b_{CO,NO2,SO2}.csv`, highlights):
- **CO:** the estimate turns positive when Guamaní is dropped (+5.4 percent pre-disruption).
- **SO2:** the donut effect turns negative when Belisario is dropped (-4.1 percent).
- **NO2:** dropping Belisario moves the full-window estimate from -5.8 to -0.5 percent.

**What follows for the estimand.** This is a re-reading of numbers the paper already printed, not a change in the data. M8b is close to a comparison of Centro with Belisario. In the pre-disruption window:
- Centro against the other stations (M8): -17.0 percent in the paper, -17.2 now;
- Belisario against the others (M9): -6.0 percent, -6.1 now;
- Centro with Belisario in the pool (M8b): -12.2 percent.

These fit a reading in which both stations near the line fell, Centro by more. Under that reading, M8b measures Centro's change net of Belisario's, and its significance rests on that comparison: M8, which drops Belisario, has p = 0.431.
- **M9 cannot settle it.** It is imprecise (pre RMSPE 0.190), so it cannot rule out a Belisario effect of about 6 percent either.
- **The paper's argument.** It reads M9 as showing "no comparable response" (line 611) and builds on it: "after showing no comparable effect at Belisario" (line 668), and Belisario "does not show the same pattern" or "comparable evidence" (lines 92, 582, 848, 862). That argument needs qualifying.
- **Belisario's distance** to the line is also uncertain: the paper's figure may be off by 0.27 to 0.67 km (`docs/known_issues.md`).

### Residual autocorrelation

M8b weekly gaps (`diagnostics/acf_gaps_M8b_*.csv`), lags 1 to 4:

| Pollutant | Pre-period, lags 1-4 | Post-period, lags 1-4 |
|---|---|---|
| PM2.5 | 0.076, 0.059, 0.015, -0.007 | 0.458, 0.352, 0.380, 0.319 |
| CO | 0.455, 0.187, 0.089, -0.050 | 0.227, 0.161, 0.086, 0.116 |
| NO2 | 0.329, 0.127, 0.184, 0.119 | 0.258, 0.208, 0.194, 0.174 |
| SO2 | 0.425, 0.222, 0.184, 0.108 | 0.713, 0.523, 0.348, 0.275 |

- **PM2.5.** The pre-period gaps are close to uncorrelated. The post-period gaps decay slowly, which is what a level shift produces. That shift could be a lasting effect, an effect that begins in mid-2024, or a lasting misfit.
- **Gases.** The pre-period lag-1 values of 0.33 to 0.46 make the iid test questionable for them too. No conclusion changes, since no gas result in the main run is significant.

### Pseudo-openings in the pre-period

M8b, 13 fake opening weeks from week 20 to week 44 (`pseudo_openings_M8b_summary_*.csv` and `pseudo_openings_M8b_*.csv`):

| Pollutant | Rejection rate at 5% | Rejection rate at 10% | Share of negative pseudo-effects |
|---|---|---|---|
| PM2.5 | 0.615 | 0.769 | 0.077 |
| CO | 0.154 | 0.231 | 0.692 |
| NO2 | 0.308 | 0.462 | 0.769 |
| SO2 | 0.000 | 0.000 | 0.846 |

With no treatment in the pre-period, a correctly sized test would reject about 5 and 10 percent of the time. For PM2.5 the conformal test rejects far more often, and almost always with a positive pseudo-effect. The diagnostic cannot say whether this is a problem of inference or of identification:
- **The 13 cases are nested, not independent.**
  - Every pseudo-post window ends at week 52, so all of them contain the weeks from 2023-09-25 to 2023-11-20.
  - Those weeks include the 2023 rationing period, when the M8b gaps were +0.263 (2023-10-23), +0.336 (2023-10-30) and +0.223 (2023-11-13).
  - The largest pseudo-effect is at week 44, the closest to those weeks: +0.160 log points, p = 0.033. The rise is not steady: week 38 gives +0.107 and week 40 +0.059.
  - The 8 rejections may be closer to one episode counted several times than to an estimate of test size. Suggestion 1 would test this.
- **A correctly sized test should reject a real shock.** If Centro had a large Centro-specific shock in late 2023, a correct test would reject it. That would be a problem of identification (shocks of this size happen at Centro without the Metro), not of test size.
- **The test also reacts to volatility, not only to level.** At week 30 the pseudo-effect is +1.4 percent with p = 0.025. Read the headline the same way: p = 0.016 rejects "no effect in any week", not "average effect is zero".
- **The pseudo-periods are shorter.** The pseudo-openings use pre-periods of 19 to 43 weeks, against 52 in the real test, which may make them harsher.
- **S4 agrees with the main result.** Without the rationing weeks, the real estimate is unchanged (section 4).

### Block conformal p-values

Moving-block permutations (`diagnostics/block_conformal_*.csv`). The iid p comes from a reseeded run. The smallest attainable block p is 1/T, where T is the number of weeks; the smallest nonzero iid p is 0.001.

| Spec, window | Iid p (reseeded) | Block p | Smallest block p |
|---|---|---|---|
| PM2.5 M8b, pre-disruption | 0.021 | 1/94 (0.011) | 0.011 (T = 94) |
| PM2.5 M8b, donut | 0.208 | 0.242 | 0.008 (T = 120) |
| PM2.5 M8b, full | 0.085 | 0.291 | 0.007 (T = 134) |
| CO, NO2, SO2 M8b, pre-disruption | 0.224 to 1.000 | 0.340 to 1.000 | 0.011 (T = 94) |
| CO, NO2, SO2 M8b, donut | 0.145 to 1.000 | 0.333 to 1.000 | 0.008 (T = 120) |
| CO, NO2, SO2 M8b, full | 0.227 to 1.000 | 0.410 to 1.000 | 0.007 (T = 134) |

- **PM2.5 M8b, pre-disruption.** The block test allows for serial dependence and still gives this window the smallest p it can reach. It was not run on the pseudo-openings (suggestion 2).
- **Other PM2.5 specifications.** For M7, M8 and M9, every block p is between 0.394 and 0.784.

## 6. Triple difference at Centro (`ddd_centro.csv`)

- **D** is the log weekday-peak mean minus the log off-peak-and-weekend mean, per station and week.
- **DDD** is Centro's change in D (post minus pre) minus the controls' average change.
- **Controls.** Controls A exclude Centro and Belisario; controls B add Belisario.
- **P-value.** A two-sided placebo permutation over the controls.
- **Weeks.** Centro has 41 and 81 PM2.5 post-opening weeks here, against 42 and 82 in the main panel, because of the half-slots rule for D.

| Pollutant, window | DDD (percent), controls A | p (smallest) | DDD (percent), controls B | p (smallest) |
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

- **PM2.5.** With controls A, Centro ranks second of seven in the pre-disruption and full windows. One control has a larger negative value: the smallest placebo is -0.131 log points against Centro's -0.121 in the pre-disruption window. `ddd_centro.csv` does not name that station. Since the floor is 0.143, "not distinguishable from its placebos" is not evidence against an effect.
- **NO2.** It is close to zero, and slightly positive with controls A, in the pre-disruption window. It is negative in the donut and full windows, where its p-values equal their smallest attainable values.
- **Los Chillos.** The PM2.5 DDD uses Los Chillos's official series as a control. Its late-2024 timing change (`docs/known_issues.md`) cannot affect the pre-disruption window, which ends in September 2024.

## 7. What the paper says that the new numbers change (paper-number map)

### The map

The map holds 308 printed numbers from Tables 3, 5, 6, 7, A.1 and A.3, each with its frozen source value and its new value at the paper's precision. 212 of them change.

- **Sign changes.** Five rows change sign, and they cover three estimates:
  - PM2.5 M9 donut, printed in both Table 5 and Table A.3;
  - PM2.5 M1 (SDID) full, in Table A.3;
  - the Belisario placebo in Table 6, which changes because of the new donor rule, not only the data.
- **Notes.** 16 rows carry one of four notes:
  - the Table A.3 typo (1 row): the paper prints -0.154 for M8 in the donut window (line 1258), while Table 5 prints -0.153 for the same estimate (line 651), and the frozen source rounds to -0.153;
  - the Belisario donor rule (2 rows);
  - the frozen PM2.5 P2 count that excludes the January-February 2025 gap (1 row);
  - the Table A.1 counting window (12 rows): the hourly counts now stop at the June 2025 cut.

**Departure from plan 4.3.** The plan asks for page and line for every number. The map gives each table's line range in the text copy (column `paper_lines`), not a line per cell, and no page numbers. Text numbers are listed below with their lines.

**Not in the map, with the reason:**

- **Table 2** (lines 252-268): station distances, pollutant check marks and the stations-in-panel row (line 262: 8, 7, 7, 7). None of them changes; the stations row equals the Table 3 stations column, which is mapped. The uncertainty about Belisario's distance stays logged in `docs/known_issues.md`.
- **Table 6 monitor distances:** they do not change.
- **Figures 2 and 5:** the figures themselves must be redrawn from the new outputs. Their text is listed below.

### Statements the new numbers change

- **Abstract** (lines 21-25).
  - The pre-disruption figure changes at printed precision from 0.130 to 0.131 log points; 12.2 percent holds.
  - "Nearly unchanged when later post-opening weeks are added" holds for the point estimate (-13.7 percent). But the donut estimate is no longer statistically significant (p = 0.199).
  - "Centro is the only station with a statistically significant negative PM2.5 estimate in a spatial placebo exercise" holds under M8b only (Tumbaco has p < 0.001 under M5b).
- **Table 1** (line 210). "PM2.5: 8 stations × 116 weeks" becomes 134 weeks.
- **Data section** (lines 273-275). "The PM2.5 panel ... runs through March 2025, yielding 116 balanced station-weeks per station" becomes June 2025 and 134, the same as the gases.
- **Table 3 and its footnote a** (lines 292-312; footnote at 309-312). The PM2.5 7-week gap is gone. PM2.5's donut and full windows have 120 and 134 weeks, and its P2 has 24 weeks like the gases.
- **Figure 2 text** (lines 315-319). It describes the figure, which will be redrawn. "Centro and Belisario ... do not move together uniformly after the opening" must be re-read against the redrawn figure.
- **Section 5.1** (lines 592-631).
  - "-0.132 log points" in the donut window (line 596) is now -0.147.
  - The conservative specification's "17.0 ... and 14.2 percent" are now 17.2 and 13.0 percent.
  - "P-value of 0.011" is now 0.016.
  - The donut "12.4 percent" is now 13.7 percent, with p 0.199 against 0.041.
  - The full "15.1 percent" is now 15.6 percent, with p 0.097 against 0.006.
  - "0.185 to 0.205 in the other specifications" (line 625) is now 0.188 to 0.207.
- **Date label of Table 5** (line 657). "Full post-opening window: Nov. 27, 2023–Mar. 2025" becomes June 2025.
- **Section 5.2** (lines 674-711).
  - "Conformal p-value of 0.012" (line 678) is now 0.013.
  - Belisario's "positive and statistically insignificant estimate of 8.5 percent" is now negative: -6.1 percent, p = 0.740.
  - Cotocollao's positive estimate now has p = 0.047, against 0.061.
  - "Tumbaco ... 0.785" is now 0.768.
- **Section 5.3** (lines 716-786).
  - "PM2.5 falls significantly in every window" (line 720): only the pre-disruption window now has p at or below 0.05 (donut 0.199, full 0.097).
  - "SO2 ... donut estimate is 13.1 percent, with a two-sided conformal p-value of 0.055, and the full-window estimate is 10.0 percent" is now 10.0 percent (p = 0.120) and 7.3 percent.
  - The NO2 figures (pre-RMSPE 0.089, ratio 1.02) hold.
  - The M5b reductions of "9.5 ... 10.1 ... 13.3 percent, all significant" (lines 778-781) become 9.5 (p = 0.019), 11.6 (p = 0.191) and 13.8 (p = 0.057).
  - The SDID range "14.3 to 20.7 percent ... pre-disruption estimate of 14.5 percent" (line 785) becomes 13.9 to 19.8 percent, with 14.9 percent pre-disruption.
- **Table 7 notes** (line 764). "Through Mar. 2025 for PM2.5" becomes June 2025.
- **Figure 5 note** (lines 1046-1050).
  - The window averages become -0.131 (p = 0.016), -0.147 (p = 0.199) and -0.170 (p = 0.097).
  - The sentences on Period 2 containing "only 6 PM2.5 weeks" and on the January-February 2025 gap are obsolete.
- **Table A.1** (lines 1173-1182). The raw, peak-hour and weekday counts fall because they now stop at the June 2025 cut. That is a change of definition: the frozen counts ran to the end of the earlier file. The PM2.5 balanced panel rises from 928 to 1,072 station-weeks, and its weeks from 116 to 134.
- **Appendix A.2 text** (lines 1218-1220). "The Centro-treated, Belisario-retained configuration is the only one that combines a tight pre-treatment fit with statistically significant negative estimates":
  - still holds in the pre-disruption window for M8b (p = 0.016) and M5b (p = 0.019);
  - holds for neither in the donut window (M8b p = 0.199, M5b p = 0.191);
  - holds for neither in the full window (M8b p = 0.097, M5b p = 0.057).
- **Significance claims elsewhere.** "PM2.5 at Centro falls significantly" in the introduction (line 89) and the conclusion (line 860) refers to the pre-disruption window and still holds there.

### Statements that the paper's own estimates never supported (same in the frozen outputs)

- **"In the first months of operation"** (abstract line 22, introduction line 89, conclusion line 861), and the section 5.1 event-study narrative (lines 593-594, 601). See section 5.
- **"No comparable response" at Belisario** (lines 92, 582, 587, 611, 668, 848, 862). See section 5.

## 8. Suggestions (not run; each needs Leonel's approval)

1. **Pseudo-openings on the S4 panel** (rationing weeks dropped). If the iid rejection rate falls to near 5 percent, the late-2023 shock explains the diagnostic.
2. **Pseudo-openings with block conformal p-values.** If these also reject often, the block floor in the real test is less reassuring.
3. **The weekly Centro and Belisario PM2.5 series in levels, mid-2023 to September 2024.** It would show whether the 2024 divergence is Centro falling or Belisario rising.
4. **The new-vintage donut and full windows cut at the old end date** (week of 2025-03-31), or a small simulation of conformal power as the post-opening window grows. Either would separate the vintage from the added weeks in the rise of the donut and full p-values.
5. **More permutations (for example 10,000) for the headline p-values in the revised paper,** so that three-decimal values are stable.
6. **The S1 NO2 gap path,** before any weight is put on its p-value.
7. **A source for the April 2024 power cuts** in Ecuador, if the paper is to mention them.

## 9. Checks

**Verifier.** It re-ran step 2 from raw on a clean checkout of `606ea82` and passed it with notes. It reproduced all 103 CSV, PNG and text outputs byte for byte, and the 7 PDFs apart from their date stamps. It also recomputed the weekly panel counts and the triple difference with its own code; both match. Its notes:

- **Step 1 diagnostics not re-run.**
  - 37 committed files in `output/local/diagnostics/` (`vintage_2026-10-04/`, `pm25_gap/`, `monitor_distances/`) come from the step 1 scripts, which `run_step2.sh` does not run. No step 2 commit changed them.
  - They remain unverified, as the step 1 commit already said.
  - A strict reading of the verification rule would count them as a failure; the verifier treated them as out of scope. **This is Leonel's call.**
- **Legacy tables.** `tables/results_*.csv` still carry the SDID Wald columns (`se`, `ci_lo`, `ci_hi`) and the sliced columns (`att_clean`, `att_p1`, `att_p2`, `att_blackout`), as in the frozen version. This report and the paper-number map use neither: the map reads only the cross-sample tables, which estimate each window separately.
- **Two donut definitions.** The spatial placebo scripts drop 16 blackout weeks and the cross-sample scripts drop 14 (known issue). This report quotes the placebo only in the pre-disruption window.
- **Stray `air_quality/Rplots.pdf`.** Some script draws to R's default graphics device. The file is not committed.

**Reviews.** Each review is saved word for word:
- **Code-reviewer** on the map script: `reports/air_quality/2026-10-05_step2_review_code_map.md`. It found no sourcing errors, and its fixes are applied.
- **Methods-referee** on the memo: `reports/air_quality/2026-10-05_step2_review_methods_referee.md`. Its findings on interpretation are worked into sections 2 to 7, and the further analyses it proposed are in section 8.
- **Claims-auditor** on the memo and the map at `aad1942`: `reports/air_quality/2026-10-05_step2_claims_audit.md`. It traced every number to a committed file and found no wrong rounding or percent conversion. It also checked every frozen value in the map against the printed paper: all match except the Table A.3 typo.
  - Its corrections are applied in this version: misattributions to the new data, missing statements in section 7, line references, overstated wording and the "p = 0" notation.
  - It counted 18 rows with notes; the map has 16.

**Out of scope.** Paper Table 9 prints satellite Wald p-values (lines 874-883). This is already logged in `docs/known_issues.md` and belongs to the satellite part of the revision.

## What ran

- **Code and checks.**
  - Plan 3A was committed before any code change (`00a9147`).
  - The code-reviewer reviewed the code, and its fixes were applied (`dc7c7f9`).
  - Check 4.4 ran before any estimate (`9455bc7`).
  - A pipe bug in `11_descriptives.R` was fixed (`a172a9e`).
- **Runs.** Leonel ran the main specification, the sensitivities, the diagnostics and the comparison tables in his own terminal; the outputs are committed in `606ea82`. Two background runs of mine were stopped at the two-hour limit under heavy machine load and produced nothing that was kept.
- **Map script.** `code/local/step2/paper_number_map.py` builds the map from aggregated tables only, in a few seconds.
- **Not done:** no paper text was changed, no question was sent, and none of the suggestions in section 8 was run.
