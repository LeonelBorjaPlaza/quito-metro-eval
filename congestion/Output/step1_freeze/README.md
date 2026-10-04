# Step 1 provisional freeze, congestion module

The data files here were written on 2026-09-27 by `Scripts/Congestion/24_step1_freeze.R` at code commit `e173f6d` (recorded in `spec.json`). This README is written by hand and was revised on 2026-09-28 after the methods-referee's review. Governing plan: `docs/analysis_plan.md`, v2 of 2026-09-22 with Amendment 1 of 2026-09-27. Everything here uses **provisional zero coding**: absent records count as zero congestion until the provider confirms that reading. Only pre-opening months (January 2022 to November 2023) were read. `25_step1_check_no_post.R` scanned all 32 Step 1 output files, before and after writing this freeze, and found no value dated December 2023 or later.

This freeze is provisional. Under plan section 8, Leonel confirms it in Step 2, after deciding the items below and after the provider answers on zero coding. Step 3 then estimates on post-opening data. Point estimates will use the frozen full pre-period weights. Conformal inference refits the model on all periods with the frozen penalty, which the plan says is not an amendment. **The methods-referee advised against confirming the freeze as written until the decisions below are taken** (review of 2026-09-28, summarized in `reports/congestion/2026-09-27_step1_report.md`).

## What is frozen

- **Outcome.** tci_osm_ratio, all_roadtype, native 0 to 100 levels. It is averaged over weekday peak hours 7, 8, 9, 17, 18 and 19 with equal hour weights, then over cells with equal weights.
- **Units.** CENTER and BELISARIO are each the H3 resolution-8 cell holding the published monitor point plus its six neighbours. The seeds and cell lists, and the 34 CORRIDOR cells (centroid within 1 km of a station), are in `spec.json`.
- **Data rules.**
  - A unit-month exists only if every cell-hour in it is valid.
  - Amended flag rule (primary): a sentinel, or any of six auxiliary ratios below zero, makes a key missing. Severe persistence above 100 makes only the severe outcomes missing.
  - The plan's original rule (sensitivity): severe persistence above 100 makes every outcome missing.
  - A target's missing months are left out of its fits, never filled.
- **Donor pools.** REST cells with a mean of at least 20 valid delivered hour slots per month, complete in the peak block over the pre period. Two pools are frozen:
  - without the coverage screen: `primary_unscreened`;
  - with the 2022 "jam-derived coverage" screen: `primary_screened`. The target-cell range is 38.9702 to 70.3876.

  Donor counts are in `spec.json` (donor_counts). Memberships for every pool, including the sensitivity pools, are in `donor_pools.csv`.
- **Estimator.** augsynth 0.2.0 (GitHub 65c5a6f), ridge augmentation, SCM weights, unit intercept.
  - The ridge penalty is tuned by leave-one-block-out validation over six calendar blocks of January 2022 to May 2023, on augsynth's own grid.
  - The penalty for each rule, pool and target, with a grid-edge flag, is in `spec.json`.
  - Frozen weights are the `full_pre` rows of `donor_weights.csv`.
- **Benchmarks.** Plain SCM (augsynth without augmentation and *without an intercept*) and the donor-mean DiD. Because the plain SCM has no intercept, the gap between augsynth and plain SCM mixes the effect of the augmentation with the effect of the intercept.

## Not yet frozen

These parts of the plan have no frozen fit, penalty or cell list yet. They must be frozen on pre-period data before Step 3.

- Secondary outcomes: the log of the target aggregates (plan section 4, including the count of donors dropped for zeros), the morning and evening blocks, tci_severe_osm_ratio, conditional jam speed, the fast-road block, and the length-weighted aggregate.
- CORRIDOR and RING fits. The RING cell list is not in `spec.json`.
- The alternative exposure geography (plan section 2, "fixed now"). No cell lists are built yet.
- The threshold-12, all-REST and low-exposure pools. Their memberships are in `donor_pools.csv`, but they have no fits.
- The SDID robustness estimator (synthdid is not installed in the congestion library).
- Placebo-in-time (plan section 7).
- The contrast placebo pairs (plan section 7: pseudo-neighbourhood pairs 4 to 6 km apart, matched on pre-period mean and variance).

## Pre-period results (amended rule)

Values are in percentage points of peak tci_osm_ratio. The gap is actual minus prediction, and bias is the mean holdout gap. Sources: `fit_statistics.csv` and `contrast_statistics.csv`.

| Target, pool | augsynth holdout RMSE (bias) | Plain SCM | Donor-mean DiD | Full pre-period RMSPE |
|---|---|---|---|---|
| CENTER, unscreened (270 donors) | 0.679 (-0.562) | 0.689 (-0.571) | 1.220 (0.772) | 0.217 |
| CENTER, screened (166 donors) | 0.677 (-0.591) | 0.642 (-0.470) | 1.200 (0.771) | 0.114 |
| BELISARIO, unscreened | 2.433 (-2.269) | 1.990 (-1.868) | 2.060 (1.553) | 0.829 |
| BELISARIO, screened | 0.919 (-0.642) | 0.734 (-0.363) | 2.033 (1.552) | 1.002 |
| Contrast, unscreened | 2.027 (1.707) | 1.609 (1.297) | 1.026 (-0.781) | 0.718 |
| Contrast, screened | 0.622 (0.051) | 0.714 (-0.107) | 1.026 (-0.781) | 0.941 |

CENTER's pre-period mean is 10.42653 (`mde_center.csv`). Its augsynth holdout RMSE is about 0.68, or 6.5 percent of that mean.

## Warnings for the reader

1. **Pre-opening divergence at CENTER.**
   - Under the amended rule, every augsynth and SCM holdout for CENTER trained on January 2022 to May 2023 predicts more congestion than was recorded from June to November 2023, by 0.47 to 0.59 on average. Under the original-rule sensitivity the gap is 0.96 to 1.25, over five holdout months.
   - All six monthly augsynth gaps are negative in both pools (`fit_paths_pre.csv`).
   - In a post-opening estimate this pattern would read as a reduction.
   - The donor-mean DiD misses in the opposite direction (bias +0.772 and +0.771), so the drift is relative to the weighted donors.
   - With the screened pool, BELISARIO drifts the same way (-0.642), and the screened contrast's bias is only 0.051. That fits a change along the whole line before opening, or among the weighted donors.
   - The drift may also be the estimator's ordinary six-month forecast error. Two of the eight unscreened pseudo-neighbourhoods have a larger absolute bias (-0.747 and -0.595; `pseudo_neighbourhood_fits.csv`).
   - Either way, a P1 effect below about 0.6 cannot be told apart from pre-opening forecast error.
2. **BELISARIO with the unscreened pool fails its benchmarks.** Its augsynth holdout RMSE (2.433) is worse than plain SCM (1.990) and DiD (2.060). BELISARIO's pre-period fit (full RMSPE 0.829 and 1.002) makes it, and the contrast, weaker evidence than CENTER.
3. **Some fits interpolate their training months and are not usable as they stand.**
   - Training RMSPE is near zero, with a chosen penalty of about 1e-5, in both original-rule, screened-pool augsynth fits. Their weights also explode (sum of absolute weights 3.363 and 7.869; `weight_statistics.csv`), and they lose to plain SCM on the holdout.
   - Training RMSPE is also near zero in every CENTER fit trained from December 2022 to May 2023 (six months, or five under the original rule), and in 5 of the 11 pseudo-neighbourhoods (full pre-period RMSPE 0.000 at three decimals).
   - A near-zero training error here means overfitting, not good fit.
4. **Extrapolation and concentration** (full fits, `weight_statistics.csv`, `influence_drop_one.csv`, `Output/Waze/step1/diagnostics.md`).
   - CENTER, screened pool: total negative weight -0.680 and sum of absolute weights 2.360.
   - CENTER, unscreened pool: dropping its largest training-fit donor (weight 0.317) raises the holdout RMSE from 0.679 to 1.322.
   - Several top donors lie 2 to 4 km from a station, inside the plan's low-exposure cutoff.
5. **Penalty tuning is limited by augsynth's grid.** Seven of the eight chosen penalties sit at an edge of the grid (`lambda_at_grid_edge` in `weight_statistics.csv` and `spec.json`).
   - Five sit at the largest penalty. There the augmentation changes no donor's weight by more than 0.0075, and the sum of the absolute changes is 0.038 to 0.297 (`donor_weights.csv`). So augsynth is effectively SCM with an intercept, and widening the grid upward would change little.
   - Two sit at the smallest penalty: the interpolating fits in warning 3.
   - Only the amended-rule, screened-pool CENTER fit chose an interior value.
   - Leave-one-block-out validation also predicts middle blocks from later months, whereas the holdout and the design forecast forward.
6. **The pseudo-neighbourhoods cannot serve plan section 7 as built.**
   - The outcome-blind greedy rule yields 8 in the unscreened pool and 3 in the screened pool (`pseudo_neighbourhoods.csv`), so the smallest placebo-rank p-values would be 1/9 and 1/4.
   - Their pre-period means are 2.25 to 6.14, against CENTER's 10.43. In levels, CENTER's holdout RMSE exceeds 7 of the 8 unscreened ones. As a share of each unit's mean it is 6.5 percent, lower than all but one of them (5.0 to 24.0 percent).
   - The fit filter (full pre-period RMSPE at most three times CENTER's) removes none of them, and BELISARIO itself would fail it.
   - Greedy selection by H3 id is outcome-blind but not a maximal packing.
7. **Minimum detectable effect (MDE) for CENTER in levels** (`mde_center.csv`; two-sided 5 percent, 80 percent power, constant effect over nine months, scaled by the holdout RMSE).
   - If monthly errors cancel as independent errors would, it is 0.634 (unscreened) or 0.632 (screened).
   - The holdout errors do not look independent: all six have the same sign, and the squared bias makes up 68 to 76 percent of CENTER's holdout mean squared error. If the error persists over P1, the MDE is three times larger: 1.903 and 1.896.
   - The CENTER holdout errors are also smaller than its pooled leave-one-block-out errors (0.994 unscreened and 1.231 screened, from `lobo_folds.csv`).
   - The AR(1)-adjusted column (0.556 and 0.433) takes its autocorrelation from in-sample residuals. Plan section 7 calibrates power on holdout errors, not training residuals, so that column does not follow the plan and should not be used.
   - Under the original rule the independent-months MDE is 1.211 and 1.388.
   - The Phase D figures (1.681 to 3.757, `reports/waze_preperiod_power.md`) used different hours, a different comparison and a bootstrap, so they are not directly comparable.
   - None of these figures describes the planned conformal test itself. A power simulation of that test on pre-period data is still to be done.
   - An MDE describes the design and is never a bound on the true effect.
8. **Inference support** (`inference_dimensions.csv`).
   - With 23 pre months and 9 P1 months, moving-block permutations give 32 permutations and a smallest attainable p-value of 0.03125. A 5 percent test rejects only when the observed statistic ranks first.
   - A Holm adjustment of the two or three hypotheses in plan section 5 needs 0.025 or 0.0167 at its first step. Under this design the Holm-adjusted joint claim can never reach 5 percent.
   - Under the original rule CENTER has 20 pre months with 3 calendar gaps, which gives 29 and 0.03448 if the gaps are ignored.
   - The clean and full windows have calendar gaps (September to December 2024 excluded, February to April 2025 missing), and no rule yet says how moving blocks handle them.
   - The December 2022 sensitivity has 12 pre months plus 9 P1 months, so its smallest p-value is 1/21, about 0.048.
   - Near-interpolating fits could also leave the conformal refits with residuals near zero.

## Decisions pending for Leonel

1. **Primary donor pool.** For CENTER the holdout cannot separate the two pools (0.679 against 0.677). Choosing on BELISARIO or the contrast would use the holdout a second time, which the plan counts as model selection. The referee recommends deciding on what the screen measures (2022 jam extent, not independent coverage), recording the reason as an amendment, and reporting the other pool as a fixed sensitivity.
2. **The pre-opening divergence (warning 1).** Options:
   - pre-state an interpretive threshold;
   - obtain construction and trial-run dates;
   - run the pre-period CORRIDOR holdout and placebo-in-time checks;
   - consider a backdated-treatment sensitivity (an amendment).
3. **Inference.**
   - Amend plan section 5 so that the confirmatory claim is feasible, for example CENTER P1 alone as confirmatory.
   - Adopt a gap rule for the clean and full windows, or declare p-values infeasible there, as plan section 7 allows.
4. **Interpolating fits (warning 3).** Declare them uninformative, or pre-specify a fallback (an amendment).
5. **Penalty grid (warning 5).** The referee advises keeping augsynth's grid.
6. **December 2022 sensitivity.** It reuses the main penalty (approved) and interpolates CENTER. Keep it, or re-tune on that window.
7. **Placebo design (warning 6).** Settle it by an outcome-blind amendment before Step 3. The pre-period placebo fits have already been seen.
8. **Confirm Amendment 1** and the original-rule sensitivity.
9. **Zero coding.** The provider's answer still gates final estimates.

## Files

| File | Contents |
|---|---|
| `spec.json` | Frozen specification, penalties with grid-edge flags, donor counts, code commit |
| `donor_weights.csv` | SCM and effective weights for the full pre-period and training fits |
| `donor_pools.csv` | Pool membership and missing-month counts for every REST cell, both rules |
| `fit_statistics.csv`, `contrast_statistics.csv` | Training and holdout errors for every fit and for the contrast |
| `fit_paths_pre.csv` | Monthly actual, synthetic and gap values, pre period only |
| `weight_statistics.csv`, `influence_drop_one.csv`, `lobo_folds.csv` | Weight diagnostics, drop-one influence, fold errors |
| `pseudo_neighbourhoods.csv`, `pseudo_neighbourhood_fits.csv` | Placebo units and their pre-period fits |
| `mde_center.csv`, `inference_dimensions.csv` | MDE and permutation support |
| `input_checksums.csv` | sha256 of every raw input, derived file and script |
