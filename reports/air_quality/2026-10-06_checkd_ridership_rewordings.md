# Check d, the ridership test, the donut and full estimates, and the 11 rewordings

Workstream A, 2026-10-06.
- **Sources.** All numbers come from committed outputs under `air_quality/output/local/`. Check d ran in Leonel's terminal on `6b5a2c4`, and its outputs are in `c5755ff`.
- **P-values.** All are two-sided. Iid conformal: 1,000 random permutations; smallest nonzero 0.001, and 0 is attainable. Block conformal: smallest 1/T.
- **Not edited.** Nothing in the paper has been changed.

## 1. Check d: pseudo-openings with block p-values

**The iid test's over-rejection is concentrated in pseudo-windows that contain the late-2023 rationing weeks. Without them it falls, but it does not disappear. The block test does not over-reject at 5 percent in either panel, but on the main panel it over-rejects at 10 percent.**

- **Iid without the rationing weeks (S4).** It still rejects 2 of 10 at 5 percent and 4 of 10 at 10 percent, about four times the nominal rate.
- **Block on the main panel.** It rejects 6 of 13 at 10 percent, against an effective level of 0.096. Three of its block p-values sit at 3/52 = 0.058, just above the effective 5 percent level.
- **The panels differ in more than the rationing weeks.** S4's pseudo-post windows are also five weeks shorter than the main panel's.

| Panel | Pseudo-openings | Iid: rejected at 5% / 10% | Block: rejected at 5% / 10% (effective levels) | Negative pseudo-effects |
|---|---|---|---|---|
| Main pre-period (52 weeks) | 13 (weeks 20-44) | 8 / 10 | 0 / 6 (0.038 / 0.096) | 1 of 13 |
| S4, rationing weeks dropped (47 weeks) | 10 (weeks 20-38) | 2 / 4 | 0 / 1 (0.043 / 0.085) | 4 of 10 |

Sources: `step2/diagnostics/pseudo_openings_block_summary_{main,S4}_PM25.csv` and the per-date files beside them.
- **Smallest attainable block p.** 1/52 = 0.019 on the main pre-period and 1/47 = 0.021 on S4. The block p can only take multiples of 1/T, so "p at or below 0.05" is in effect a test at 2/52 = 0.038 or 2/47 = 0.043.
- **Same dates, like for like** (a comparison added after the results; plan 3B listed only the rates above). On the same 10 calendar dates (weeks 20-38), the main panel's iid test rejects at 5 percent in 6 of 10, against 2 of 10 once the rationing weeks are dropped.
- **Sign of the pseudo-effects.** With the rationing weeks, 12 of 13 pseudo-effects are positive. Without them, 6 of 10 are.
- **Reproduction.** The main run reproduced the committed iid pseudo-openings exactly (log `aq_s2_pseudo_block_main.log`).
- **Caveat.** The pseudo-post windows are nested in both panels (all end at the last pre-period week), so these are not independent draws.

## 2. Ridership test (plan 3C)

**The test does not support the destination-access mechanism.**
- **Correlation.** San Francisco's share of monthly entries correlates positively with Centro's monthly PM2.5 gap: Spearman +0.256, against the predicted negative.
- **Rank.** San Francisco ranks 10th most negative of 15 stations.
- **P-values.** Station-placebo p is 0.667 (smallest attainable 0.067); cyclic-shift p is 0.438 (smallest 0.0625).
- **Window.** The test ran as written on December 2023 to May 2025, the last month Metro de Quito delivered: 16 months instead of the 17 planned through June 2025.
- **Data.** The two delivered files swap some station labels, including San Francisco in December 2023. Repeating the test with the other file's totals gives the same conclusion (Spearman +0.412).

Details: `reports/air_quality/2026-10-05_mechanism_ddd.md`, last section; `step2/ridership/`.

## 3. M8b PM2.5 in the donut and full windows: estimates and p-values

**The estimates did not shrink; the p-values rose.**
- **Main run.** On the new data the reduction is slightly larger than in the paper in both windows: donut 13.7 against 12.4 percent, full 15.6 against 15.1.
- **Sensitivities.** Under the Los Chillos and minimum-hours sensitivities, it ranges from 13.3 to 13.9 percent in the donut window and from 14.6 to 15.8 percent in the full window. Among these, only S3's full-window estimate (14.6) is below the paper's 15.1.
- **P-values.** Every new-data p-value is above 0.05.
- **The other sensitivities**, shown in the table for completeness:
  - S4 (no rationing weeks): donut -13.3 percent, full -14.9 percent; its full-window estimate is also below the paper's 15.1.
  - S1 (Guamaní and San Antonio out, data to August 2026): -16.8 and -17.4 percent.

| Run | Donut: log effect (percent) | Donut p | Full: log effect (percent) | Full p |
|---|---|---|---|---|
| Paper (frozen data) | -0.132 (-12.4) | 0.041 | -0.164 (-15.1) | 0.006 |
| New data, main | -0.147 (-13.7) | 0.199 | -0.170 (-15.6) | 0.097 |
| S2a: Los Chillos out | -0.143 (-13.3) | 0.094 | -0.172 (-15.8) | 0.088 |
| S2b: Los Chillos shifted two hours | -0.149 (-13.9) | 0.167 | -0.172 (-15.8) | 0.107 |
| S3: minimum hours | -0.144 (-13.4) | 0.177 | -0.157 (-14.6) | 0.120 |
| S4: no rationing weeks (treatment week 2023-12-18) | -0.143 (-13.3) | 0.146 | -0.162 (-14.9) | 0.058 |
| S1: no Guamaní or San Antonio, to August 2026 | -0.184 (-16.8) | 0.658 | -0.191 (-17.4) | 0.556 |

Sources: `step2/main_old_vs_new.csv` and `step2/sensitivities_long.csv`. Iid conformal p-values; smallest nonzero 0.001.

## 4. The 11 flagged passages: minimal rewording

Each passage is matched to the new p-values and the new Belisario placebo, without changing the argument. New numbers are those of the rebuilt tables (`air_quality/output/local/paper/`). Line numbers refer to `congestion/docs/paper/Underground-relief.txt`.

1. **Abstract, lines 21-24.**
   - Now: "falls by 0.130 log points, equivalent to 12.2 percent, in the first months of operation, before the late-2024 energy crisis. The estimate is nearly unchanged when later post-opening weeks are added but blackout and wildfire weeks are excluded."
   - Proposed: "falls by 0.131 log points, equivalent to 12.2 percent, in the first months of operation, before the late-2024 energy crisis. The point estimate is similar when later post-opening weeks are added but blackout and wildfire weeks are excluded, although it is not statistically significant in that longer window."
2. **Introduction, lines 90-92.**
   - Now: "The estimate is nearly unchanged when later post-opening weeks are added, as long as the blackout and wildfire weeks are excluded."
   - Proposed: "The point estimate is similar when later post-opening weeks are added, as long as the blackout and wildfire weeks are excluded, but it is not statistically significant in that longer window."
3. **Section 5.1, lines 595-597.**
   - Now: "the average effect is -0.130 log points. The estimate is nearly identical, -0.132 log points, when later post-opening weeks are added but the disruption weeks are excluded."
   - Proposed: "the average effect is -0.131 log points. The estimate is similar, -0.147 log points, when later post-opening weeks are added but the disruption weeks are excluded."
4. **Section 5.1, lines 620-623.**
   - Now: "with a two-sided conformal p-value of 0.011. The estimate is nearly unchanged in the donut window, at 12.4 percent. The full post-opening window gives a larger reduction of 15.1 percent, but because it includes the late-2024 disruption, we interpret the pre-disruption estimate as the cleanest local effect."
   - Proposed: "with a two-sided conformal p-value of 0.016. The point estimate is similar in the donut window, at 13.7 percent, and the full post-opening window gives a reduction of 15.6 percent, but neither is statistically significant at the 5 percent level (p = 0.199 and 0.097). Because the full window includes the late-2024 disruption, we interpret the pre-disruption estimate as the cleanest local effect."
5. **Section 5.2, lines 678-681.**
   - Now: "Belisario, despite being almost equidistant from the metro corridor, has a positive and statistically insignificant estimate of 8.5 percent. This connects directly to the identification sequence in Table 5: the same station that anchors Centro’s preferred counterfactual does not show a comparable response when treated as the exposed station."
   - Proposed: "Belisario, despite being almost equidistant from the metro corridor, has a negative but imprecise and statistically insignificant estimate of -6.1 percent (p = 0.740), estimated, as in Table 5, without Centro in its donor pool. This connects directly to the identification sequence in Table 5: the same station that anchors Centro's preferred counterfactual does not show a comparable, statistically detectable response when treated as the exposed station."
   - Also, the Table 6 note gains: "for Belisario, Centro is also excluded from the donor pool".
   - The sign change comes from both the new data and the new donor rule (`step2/placebo_old_vs_new.csv`).
   - Table 5 gives the same estimate with p = 0.737 (M9). The two p-values differ only by simulation noise, because the placebo run draws its own permutations.
6. **Section 5.2, lines 683-684.**
   - Now: "The only other estimate approaching conventional significance is Cotocollao, but its point estimate is positive, so it is not a competing pollution-reduction result."
   - Proposed: "The only other estimate at conventional significance is Cotocollao (p = 0.047), but its point estimate is positive, so it is not a competing pollution-reduction result."
7. **Section 5.3, lines 720-721.**
   - Now: "PM2.5 falls significantly in every window, with the cleanest estimate in the pre-disruption period."
   - Proposed: "PM2.5 falls significantly in the pre-disruption period, the cleanest estimate; the point estimates in the donut and full windows are similar but not statistically significant at the 5 percent level."
8. **Section 5.3, lines 728-730.**
   - Now: "The donut estimate is 13.1 percent, with a two-sided conformal p-value of 0.055, and the full-window estimate is 10.0 percent."
   - Proposed: "The donut estimate is 10.0 percent, with a two-sided conformal p-value of 0.120, and the full-window estimate is 7.3 percent."
   - The generator interpretation that follows is left as is here. Refine's comment D3 proposes changing it (`reports/air_quality/refine_response_draft.md`).
9. **Section 5.3, lines 779-781.**
   - Now: "gives reductions of 9.5 percent in the pre-disruption window, 10.1 percent in the donut window, and 13.3 percent in the full window, all significant under two-sided conformal inference."
   - Proposed: "gives reductions of 9.5 percent in the pre-disruption window, 11.6 percent in the donut window, and 13.8 percent in the full window; the pre-disruption estimate is significant under two-sided conformal inference (p = 0.019), while the donut and full estimates are not significant at the 5 percent level (p = 0.191 and 0.057)." ("at the 5 percent level" added on Leonel's decision of 2026-10-07)
10. **Figure 5 note, lines 1046-1050.**
    - Now: "pre-disruption, P1, -0.130 log points (p = 0.011); donut, P1 + P2, -0.132 log points (p = 0.041); and full post-opening, -0.164 log points (p = 0.006)."
    - Proposed: "pre-disruption, P1, -0.131 log points (p = 0.016); donut, P1 + P2, -0.147 log points (p = 0.199); and full post-opening, -0.170 log points (p = 0.097)."
    - Add the floor after "All p-values are two-sided conformal p-values": "(1,000 permutations; smallest nonzero value 0.001)".
    - Also delete the sentences on the 6-week Period 2 and the early-2025 gap, from "Period 2 (post-disruption) contains only 6 PM2.5 weeks" (line 1047) to the end of the note (line 1050), which no longer apply. Keep "All p-values are two-sided conformal p-values."
11. **Appendix A.2, lines 1218-1220.**
    - Now: "the Centro-treated, Belisario-retained configuration is the only one that combines a tight pre-treatment fit with statistically significant negative estimates across the augmented synthetic control specifications."
    - Proposed: "the Centro-treated, Belisario-retained configuration is the only one that combines a tight pre-treatment fit with statistically significant negative estimates in the pre-disruption window across the augmented synthetic control specifications; its donut and full-window estimates are also negative but not significant at the 5 percent level."

**Rule 6.** Add once to Section 4 and to the notes of Tables 5, 6, 7 and A.3: "Conformal p-values use 1,000 random permutations; the smallest nonzero p-value is 0.001." That puts the smallest attainable value beside every conformal p-value in the rewordings above.

**Also worth reviewing with these rewordings, though not flagged by the rule:** lines 92-93 and 608-612 (Belisario shows "no comparable response", which "supports using it as a valid donor") and line 778 ("qualitatively robust to alternative estimators"). They depend on Belisario's estimate and on significance across windows (see the Refine draft, D4 and G2).

The other numbers that change, without a sign change or a p crossing, are listed in `reports/air_quality/2026-10-05_paper_numbers_new_data.md` and `air_quality/output/local/paper/text_numbers.csv`.

## 5. Decisions of 2026-10-06 and the text they need

**Approved by Leonel:** rewordings 1 to 9 and 11, as in section 4. Item 10 (below) and the Section 4 paragraph (below) were approved on 2026-10-06. All are collected in `reports/air_quality/2026-10-06_paper_change_list.md`.

### Item 10, Figure 5 note: the exact sentences to delete

The note runs from line 1042 to line 1050 of the text copy. With the new numbers from rewording 10, delete exactly these two sentences (lines 1047-1050):

> "Period 2 (post-disruption) contains only 6 PM2.5 weeks: data are absent for all stations from the week of 13 Jan to the week of 24 Feb 2025, so the panel jumps from the week of 6 Jan 2025 to the week of 3 Mar 2025."
>
> "The break in the series in early 2025 marks this gap."

Everything else in the note stays, including "All p-values are two-sided conformal p-values." and the window averages, which are updated by rewording 10. The note does not describe the effect deepening over time. That description is in section 5.1 (lines 593-594 and 601), which no deletion here touches.

### Section 4: proposed sentences on the inference

To add after the paragraph on conformal inference (after line 515):

> "Random-permutation conformal tests assume that prediction errors are exchangeable across weeks, which serial correlation or a shock in the pre-treatment period can violate. We placed pseudo-openings inside the pre-treatment period, where there is no treatment. The random-permutation test rejected at the 5 percent level in 8 of 13 cases. A block version, which compares the post-opening errors with all cyclic shifts of the weekly sequence, rejected in none of them at its effective 5 percent level (2/52 = 0.038), but in 6 of 13 at the 10 percent level. These pseudo-openings overlap, and all of them include the late-2023 rationing weeks, so they cannot separate test size from a shock at Centro before the opening. We therefore report both p-values wherever both were computed (Tables 5, 7 and A.3). The random-permutation p-values use 1,000 permutations, so their smallest nonzero value is 0.001; the smallest value of a block p-value is one over the number of weeks in the estimation sample."

Revised after the claims audit:
- **10 percent and the effective level.** The paragraph now gives the 10 percent result and the block test's effective 5 percent level.
- **Nesting.** It now mentions the nesting.
- **Cause.** It no longer attributes the iid over-rejection to serial correlation; pre-period autocorrelation is small (0.076 at lag 1). The full pseudo-opening results belong in the appendix (Refine draft, G3).

### Tables

`air_quality/output/local/paper/` now shows the block p-value beside the iid p-value:
- **Table 5:** a "Block conformal p" row in each panel.
- **Table 7:** a "Block conformal p" row for all four pollutants, M8b.
- **Table A.3:** in brackets beneath the iid p-value, for Panel C (M7, M9, M8, M8b).

The table notes state both smallest attainable values. Not computed, so not shown: Table A.3 Panel B (M4, M6, M5, M5b), the Table 6 placebos, and SDID, which has no conformal inference. The record is `air_quality/docs/revision_plan.md`, section 3D.

M8b PM2.5, iid and block p-values side by side (block smallest value in parentheses):

| Window | Iid p | Block p |
|---|---|---|
| Pre-disruption | 0.016 | 0.011 (1/94, its smallest attainable value) |
| Donut | 0.199 | 0.242 (smallest 0.008) |
| Full | 0.097 | 0.291 (smallest 0.007) |
