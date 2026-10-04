# Congestion module, Step 1: pre-period panel, fit and provisional freeze

Work of 27 and 28 September 2026. Workstream B, branch `worktree-congestion-step1`. The file name keeps the start date because the freeze README links to it.

Governing plan: `congestion/docs/analysis_plan.md` (v2 of 2026-09-22 with Amendment 1 of 2026-09-27). Every number below uses **provisional zero coding**: absent records count as zero congestion until the provider confirms that reading. No outcome month from December 2023 on was loaded, and nothing was merged into main. Unless a path says otherwise, file names refer to `congestion/Output/step1_freeze/`.

## Result

**The pre-period fit for CENTER is good in-sample, but the freeze is not ready to confirm.** The holdout errors look persistent. If they are, the smallest P1 effect the design would detect with 80 percent power is 1.903 or 1.896 percentage points. If they cancel like independent monthly errors, it is 0.634 or 0.632 (`mde_center.csv`). The methods-referee advised against confirming the freeze until you take the decisions listed below.

- **CENTER fits the pre period closely** (amended flag rule).
  - Full pre-period RMSPE is 0.217 with the unscreened donor pool and 0.114 with the screened pool, against a pre-period mean of 10.42653 (percentage points of peak tci_osm_ratio).
  - On the June to November 2023 holdout, augsynth misses by an RMSE of 0.679 (unscreened) and 0.677 (screened). It beats the donor-mean DiD benchmark (1.220 and 1.200).
  - It is close to plain SCM: 0.679 against 0.689, and 0.677 against 0.642, where plain SCM does better.
- **The holdout shows a pre-opening divergence.**
  - Under the amended rule, every augsynth and plain SCM fit predicts more congestion at CENTER than Waze recorded in June to November 2023. The mean gap is -0.47 to -0.59, and all six monthly augsynth gaps are negative in both pools.
  - Under the original-rule sensitivity the mean gap is -0.96 to -1.25, over five holdout months.
  - After opening, the same pattern would read as a reduction.
  - It may reflect a pre-opening change along the line: BELISARIO drifts the same way with both pools. It may also be ordinary six-month forecast error: two of eight placebo neighbourhoods have a larger absolute mean gap (-0.747 and -0.595).
- **The MDE depends on whether the holdout errors persist** (figures above).
  - All six holdout gaps have the same sign, so the persistent case is the more realistic one.
  - The Phase D planning figures (`congestion/reports/waze_preperiod_power.md`) used different hours and a different comparison, so they are not comparable.
  - An MDE is never a bound on the true effect.
- **The planned inference is tight.**
  - With 32 periods, a 5 percent conformal test rejects only when the observed P1 statistic ranks first among the 32 block permutations (smallest p-value 0.03125).
  - The Holm-adjusted joint claim in plan section 5 can never reach 5 percent.
  - The placebo neighbourhoods are too few (8 and 3) and on a different scale.
- **BELISARIO fits poorly.**
  - With the unscreened pool it fails both benchmarks (holdout RMSE 2.433 against 1.990 and 2.060).
  - With the screened pool it scores 0.919 against 0.734 and 2.033.
  - Its full pre-period RMSPE is 0.829 and 1.002. BELISARIO and the contrast are weaker evidence than CENTER.
- **The ridge augmentation adds little in most fits.**
  - In the 5 fits whose tuned penalty sits at the top of augsynth's grid, augsynth is effectively SCM with an intercept.
  - It does move weights substantially in the amended-rule screened CENTER fit (negative weight -0.680) and in the two interpolating fits.
- **Checks.** The code-reviewer, verifier and methods-referee ran on the freeze, and the claims-auditor ran on this report. By the agents' reports:
  - the verifier reproduced the freeze from raw byte for byte;
  - no reviewer found an error in the primary numbers.

Sources: `fit_statistics.csv`, `contrast_statistics.csv`, `fit_paths_pre.csv`, `mde_center.csv`, `inference_dimensions.csv`, `pseudo_neighbourhood_fits.csv`, `weight_statistics.csv`, `donor_weights.csv`; full detail in `README.md` there.

## Holdout comparison

Primary rule (amended). Each fit trains on January 2022 to May 2023 and predicts June to November 2023. Values are RMSE, with bias (mean of actual minus prediction) in brackets, in percentage points.

| Target, pool | augsynth | Plain SCM | Donor-mean DiD |
|---|---|---|---|
| CENTER, unscreened (270 donors) | 0.679 (-0.562) | 0.689 (-0.571) | 1.220 (0.772) |
| CENTER, screened (166 donors) | 0.677 (-0.591) | 0.642 (-0.470) | 1.200 (0.771) |
| BELISARIO, unscreened | 2.433 (-2.269) | 1.990 (-1.868) | 2.060 (1.553) |
| BELISARIO, screened | 0.919 (-0.642) | 0.734 (-0.363) | 2.033 (1.552) |
| Contrast, unscreened | 2.027 (1.707) | 1.609 (1.297) | 1.026 (-0.781) |
| Contrast, screened | 0.622 (0.051) | 0.714 (-0.107) | 1.026 (-0.781) |

- **Plain SCM has no intercept.** That is how it is frozen in `spec.json`; the plan says only "unaugmented SCM". So the gap between augsynth and plain SCM mixes the effect of the augmentation with the effect of the intercept.
- **The DiD misses in the opposite direction.** So the divergence is relative to the weighted donors.
- **Original-rule sensitivity.** CENTER has 20 pre months and 5 holdout months under this rule. Its augsynth holdout RMSE is 1.297 (unscreened) and 1.487 (screened). Both screened-pool augsynth fits under this rule interpolate their training months, with sums of absolute weights of 3.363 and 7.869, and lose to plain SCM. They are not usable as they stand.
- **December 2022 start.** CENTER's holdout RMSE is 0.671 and 0.632. The model is trained on six months, which CENTER's fits reproduce almost exactly.

## Fit diagnostics

- **Penalty grid** (`weight_statistics.csv`, `lambda_at_grid_edge`). Seven of the eight chosen penalties sit at an edge of augsynth's grid.
  - Five sit at the largest penalty. In their frozen full pre-period weights the augmentation changes no donor's weight by more than 0.0075 (`donor_weights.csv`).
  - Two sit at the smallest penalty and interpolate.
  - Only CENTER with the screened pool under the amended rule chose an interior value.
- **Concentration and extrapolation.**
  - CENTER, unscreened: dropping its largest training-fit donor (weight 0.317) raises the holdout RMSE from 0.679 to 1.322 (`influence_drop_one.csv`).
  - CENTER, screened: total negative weight -0.680 and sum of absolute weights 2.360, so the fit extrapolates.
  - Several top donors lie 2 to 4 km from a station, inside the low-exposure cutoff (`congestion/Output/Waze/step1/diagnostics.md`).
- **Pseudo-neighbourhoods.** The outcome-blind greedy rule yields 8 (unscreened) and 3 (screened), so the smallest placebo-rank p-values would be 1/9 and 1/4.
  - Their pre-period means are 2.25 to 6.14, against CENTER's 10.43. In levels, CENTER's holdout RMSE is larger than 7 of the 8 unscreened ones. As a share of each unit's mean it is smaller than all but one.
  - 5 of the 11 have a full pre-period RMSPE below 0.001.
  - The fit filter removes none of them, and BELISARIO itself would fail it.

## Minimum detectable effect for CENTER

This is the smallest constant effect over the nine P1 months that a two-sided 5 percent test would detect with 80 percent power, using a normal approximation scaled by the holdout RMSE (`mde_center.csv`).

| Assumption about holdout errors | Unscreened | Screened |
|---|---|---|
| They cancel like independent monthly errors | 0.634 | 0.632 |
| They persist through P1 (three times the row above) | 1.903 | 1.896 |

- **The holdout errors look persistent.** All six holdout gaps have the same sign, and the squared bias makes up 68 to 76 percent of the holdout mean squared error.
- **The AR(1)-adjusted column should not be used.** That column in `mde_center.csv` (0.556 and 0.433) takes its autocorrelation from in-sample residuals, which plan section 7 rules out. An earlier README draft called the independent-months figure "the more cautious planning figure"; that framing was wrong and has been removed.
- **Pooled leave-one-block-out errors for CENTER are larger** (0.994 and 1.231, from `lobo_folds.csv`).
- **None of these figures describes the planned conformal test.** A power simulation of that test on pre-period data is still to be done.
- **An MDE describes the design and is never a bound on the true effect.** A non-significant result later will not show that the effect is smaller than these amounts.

## Panel and donor pool

- **Pre-period records.** The pre-only block has 376,495 distinct all_roadtype keys from 1,023,905 raw rows (`congestion/Data/Waze/parquet_step1/manifest.rds`, ignored). An ad hoc comparison found it identical to the frozen Codex block for the same months. That comparison is recorded only in the message of commit `2a9ac76`; no script repeats it.
- **Record status** (`congestion/Output/Waze/step1/panel_summary.md`):
  - 373,774 clean;
  - 1,313 with a negative auxiliary ratio;
  - 1,408 flagged only by severe persistence above 100;
  - none with a sentinel.
- **Geography.** It matches Phase B cell for cell: CENTER 7, BELISARIO 7, CORRIDOR 34, RING 56, and REST 2,365, of which 1,533 have a pre-period record.
- **Valid peak unit-months, of 23.**
  - Amended rule: 23 for CENTER, BELISARIO and CORRIDOR.
  - Original rule: CENTER has 20.
- **Donor counts, amended rule** (without / with the 2022 jam-derived coverage screen):
  - threshold 20: 270 / 166;
  - threshold 12: 553 / 306;
  - all REST: 1,482 / 552;
  - low exposure beyond 4 km: 214 / 126.
- **Donor counts, original rule** (same order): 197 / 136, 404 / 236, 1,290 / 467, and 152 / 99.

## Not yet frozen

These parts of the plan have no frozen fit, penalty or cell list yet. They must be frozen on pre-period data before Step 3.

- The secondary outcomes (log, morning, evening, severe, jam speed, fast roads, length-weighted).
- CORRIDOR and RING fits.
- The RING and alternative-geography cell lists.
- The threshold-12, all-REST and low-exposure fits.
- SDID (synthdid is not installed in the congestion library).
- Placebo-in-time.
- The contrast placebo pairs.

## Disagreements between the prompt and the plan, and how I resolved them

1. **Freeze timing.** The plan (section 8) confirms the freeze in its Step 2 and estimates in Step 3. The freeze here is labeled provisional, and the README uses the plan's step numbers.
2. **The plan's Step 1 asks for more than the prompt listed.** Done:
   - the tci_osm_ratio dictionary (`congestion/reports/2026-09-27_dictionary_tci_osm_ratio.md`);
   - geography reconciliation and map;
   - leave-one-block-out tuning;
   - the full weight diagnostics;
   - the inference-dimension check.
3. **"Fit augsynth for the contrast."** The contrast is CENTER's gap minus BELISARIO's gap from two separate fits (plan sections 5 and 7).
4. **Coverage screen.** It uses `roadlengths_quito.csv`, whose Waze length is jam-based. The screen is labeled "jam-derived coverage", which plan section 3 says is not an independent coverage measure.
5. **Rebuilding from raw vs the no-post rule.** Blocks were rebuilt from raw with the date limit in the SQL.
6. **augsynth was not in the congestion library.** It was copied from the renv cache at the pinned version.
7. **Output path.** `congestion/Output/step1_freeze/` replaces the prompt's `congestion/output/step1_freeze/`, which would collide on case-insensitive systems.
8. **Flag rule.** You amended it (Amendment 1); the original rule is a sensitivity.
9. **`AGENTS.md` peak bins (7, 8, 17, 18) are superseded** by the plan's 7, 8, 9, 17, 18, 19, which match `air_quality/code/local/02_build_weekly_panels.R` lines 59-61.

## Decisions for you

1. **Primary donor pool.** The holdout cannot separate the pools for CENTER (0.679 against 0.677). Choosing on BELISARIO or the contrast would use the holdout a second time, which counts as model selection. The referee recommends deciding on what the screen measures (2022 jam extent), recording the reason as an amendment, and keeping the other pool as a fixed sensitivity.
2. **The pre-opening divergence.** Options:
   - pre-state an interpretive threshold;
   - obtain construction and trial-run dates around San Francisco and La Alameda;
   - run the pre-period CORRIDOR holdout and placebo-in-time checks;
   - consider a backdated-treatment sensitivity (an amendment).
3. **Inference.**
   - Amend plan section 5 so the confirmatory claim is feasible, for example CENTER P1 alone as confirmatory.
   - Choose a rule for calendar gaps in the clean and full windows, or declare p-values infeasible there (plan section 7 allows this).
   - Under the original rule, CENTER has 29 periods and a smallest p-value of 0.0345 if its gaps are ignored.
4. **Interpolating fits.** Declare the original-rule screened fits and the December 2022 CENTER fits uninformative, or pre-specify a fallback. Re-tuning the December 2022 penalty on its own window is one option. The reuse was in the Step 1 plan you approved in session, and it is recorded in `spec.json`; the Step 1 plan itself is not in the repository.
5. **Penalty grid.** The referee advises keeping augsynth's grid, since widening it upward changes little and downward makes interpolation worse.
6. **Placebo redesign before Step 3,** outcome-blind:
   - plan section 3 eligibility;
   - a maximal tiling;
   - a scale-free statistic;
   - a filter on relative holdout error;
   - the contrast pairs.

   Record that the pre-period placebo fits have been seen.
7. **Confirm Amendment 1** and the original-rule sensitivity.
8. **Branch history.** Three early commits print cell-level 2022 coverage values (`docs/known_issues.md`). Rewrite them before a merge or not.
9. **Still pending from outside:**
   - the provider's answers on zero coding, severe persistence above 100 and the road-length file;
   - the provider email of 2026-09-17, to be saved in `congestion/docs/`.

## What ran, and status of every check

Statements about what an agent found come from that agent's report to me and have no file of their own, unless a file or commit is cited.

- **Items 1 to 6.** The full pipeline (`Rscript Scripts/Congestion/20_run_step1.R`) ran from raw in clean R sessions at `798fcff` and again, after the code review, at `e173f6d`. The freeze data are committed in `4908962`. The README was revised in `7aa5c19`, after the verifier, and in `1a07727`, after the referee. Neither of those two agents reviewed the final README text.
- **No-post check.** It passes on 32 output files, before and after the freeze is written (run log in the ignored `logs/`). It also stopped, as it should, on a planted post-opening test row (commit `798fcff`).
- **Data-auditor on `roadlengths_quito.csv`: done.** It checked years after 2023 for structure only, except that its first read printed two rows of 2024 values, which were not used (`docs/known_issues.md`).
- **Code-reviewer: done.**
  - By its report, it found no error in any primary number.
  - It found two issues in sensitivity rows. The MDE autocorrelation paired non-adjacent months: fixed. The December 2022 penalty reuse: kept, recorded, and listed as decision 4.
  - The minor issues it raised are fixed in `e173f6d` (the commit message lists them).
  - Every amended-rule number was unchanged (`git diff 1acb0da 4908962`).
- **Verifier: passed with notes,** on `4908962`. The first attempt was cut off by a lost connection and does not count; its worktree was removed and the check was rerun from scratch.
  - By its report, the rerun from raw reproduced all 13 freeze tables and the Step 1 outputs byte for byte.
  - Its own code matched the CENTER series, donor counts and lists, the CENTER holdout fit and the MDE to within about 1e-13.
  - It found no path to post-opening outcomes.
  - Its three notes on README wording are fixed in `7aa5c19`.
- **Methods-referee: done.** By its report, nothing was critical and every number in the README it reviewed matched its file. It raised eight major points: MDE framing, the divergence, Holm feasibility, inference windows, placebos, unfrozen parts, pool choice and fragile fits. These are disclosed in the README (`1a07727`) and listed as decisions above. It advised not confirming the freeze until those decisions are taken.
- **Claims-auditor: done on this report.**
  - Every number sourced from a file matched, exactly or after rounding.
  - It found no post-opening estimate and no Wald or pnorm p-value.
  - It found no MDE wording that reads as a bound.
  - Its 16 wording corrections are applied in this version. The main one replaced an unsourced headline figure with the MDE figures from `mde_center.csv`.

## Suggestions (not done)

- Freeze the remaining fits (the "Not yet frozen" list) on pre-period data.
- Simulate the power of the actual conformal procedure on pre-period data.
- Run the CORRIDOR holdout and placebo-in-time checks.
- Save the leave-one-block-out error for each penalty value in the freeze, to show how flat the curve is.
- Add the frozen-block comparison to a script, so it is reproducible.
