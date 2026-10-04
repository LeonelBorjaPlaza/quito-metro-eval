# Congestion module: the historic center as treated unit, pre-period fits and drift checks

Work of 1 October 2026, workstream B, branch `worktree-congestion-step1`. Governing plan: `congestion/docs/analysis_plan.md` with Amendments 1 to 4. Pre period only (January 2022 to November 2023). No month from December 2023 on was loaded, and nothing was merged into main. Unless a path says otherwise, file names refer to `congestion/Output/step1_amendment2/`, written by `Scripts/Congestion/30_run_amend2.R`. Values are peak-hour tci_osm_ratio in percentage points; a gap is actual minus synthetic, and a bias is the mean gap.

## Result

**The primary specification, as now defined, produces an interpolating fit, so the freeze is not ready to confirm.**

- **The primary fit interpolates.** CENTER (GeoQuito's Área Histórica, road-weighted) with the screened pool chooses the smallest ridge penalty on augsynth's grid (2.07e-5). It then reproduces its training months almost exactly: training RMSPE 2.5e-7 (`fit_statistics.csv`), full pre-period RMSPE 3.0e-7. Its weights extrapolate: total negative weight -1.48, sum of absolute weights 3.96 (`weight_statistics.csv`). Amendment 3 declared two named sets of Step 1 interpolating fits uninformative. It has no general criterion, so whether this fit counts is your decision.
- **The penalty choice is close to arbitrary.** 16 of the 21 penalties on the grid come within 5 percent of the minimum leave-one-block-out error, and the largest penalty is only 12 percent worse (`lobo_grid.csv`). The seven-cell ring with the screened pool chose an interior penalty in Step 1 (20.88). With one buffer donor removed, it now chooses the grid minimum too.
- **On the holdout, plain synthetic control does better than augsynth with the screened pool.** Augsynth misses by 0.827 (bias -0.42). Plain synthetic control (non-negative weights, no augmentation, no intercept) misses by 0.749 (bias -0.29). The donor-mean DiD misses by 1.451.
- **With the unscreened pool, the fit does not interpolate.** The penalty is interior (213), the full pre-period RMSPE is 0.227, and the holdout RMSE is 0.994 (bias -0.69), against 0.978 for plain synthetic control.
- **The synthetic fits over-predict the whole line in the holdout, not only CENTER.**
  - In the June to November 2023 holdout, CORRIDOR's augsynth gaps are negative in all six months in both pools (bias -0.80 screened, -1.05 unscreened).
  - The donor-mean DiD shows the opposite sign (CORRIDOR bias +0.19, CENTER +0.87), and CORRIDOR's synthetic fits nearly interpolate their training months (training RMSPE 0.0028 screened, 1.3e-9 unscreened; `fit_statistics.csv`).
  - CENTER's gaps are negative in 5 of 6 months (screened) and 4 of 6 (unscreened) (`drift_bc_holdout_gaps.csv`).
  - Fitted around a fake window of June to November 2022, CENTER is also over-predicted on average: bias -0.67 (screened) and -0.29 (unscreened), or -0.45 and -0.25 without June 2022, the strike month (`drift_a_fake_window_stats.csv`). Unlike in 2023, its 2022 gaps change sign: three months are negative and three positive.
- **CENTER is not fully saturated in observation.** Its road-weighted delivered slots rise from 22.0 to 23.0 per cell-month (of 24) between the first and last six pre-period months. The ten heaviest donors rise from 22.4 to 22.7 (screened) and stay at 22.3 (unscreened) (`drift_d_density_summary.csv`).
- **The panel's dimensions allow a 5 percent test, but the primary fit does not.** All 15 CENTER cells are valid in all 23 pre months under the amended flag rule, so the confirmatory test has 32 periods and a smallest attainable p-value of 1/32 = 0.03125 (`inference_dimensions.csv`). With the primary fit interpolating, the methods-referee judges the conformal test not well defined: its p-value would either not depend on the data or reject almost automatically (see "Methods-referee" below).
- **The MDE for CENTER depends on whether holdout errors persist** (`mde.csv`; constant effect over nine P1 months, two-sided 5 percent, 80 percent power, scaled by the holdout RMSE; never a bound on the true effect; a normal-approximation MDE, not the MDE of the planned conformal test).

  | Holdout errors | Screened | Unscreened |
  |---|---|---|
  | Cancel like independent months | 0.773 | 0.928 |
  | Persist through P1 | 2.318 | 2.785 |

  CENTER's pre-period mean is 11.557.

## Geography (Amendment 4, items 1 to 3)

- **Polygon** (`polygon_areas.csv`). CENTER is GeoQuito feature 41.
  - Its area is 513.634 ha in SIRES-DMQ, equal to GeoQuito's `STArea` field, and 513.164 ha on the WGS 84 ellipsoid (Lambert azimuthal equal-area).
  - The two downloads of the feature (yours and mine) are byte-identical, and the script checks this on every run.
  - The descriptive core (OSM World Heritage outline, volunteer-traced) measures 71.99 ha in SIRES-DMQ and 71.93 ha on the ellipsoid.
- **Cells** (`unit_cells_weights.csv`, `group_changes.csv`, `ring_cells_in_new_center.csv`). CENTER has 15 cells with at least 1 m of drivable road inside the polygon:
  - all seven cells of Step 1's CENTER, the ring now called RING7 (confirmed);
  - five former CORRIDOR cells;
  - three former RING cells.

  No cell fell between zero and 1 m. The largest road-length weight is 0.179, and five cells weigh less than 0.01. They still count under the rule that every positive-weight cell must be valid. CORRIDOR keeps 29 cells.
- **Buffer.** 19 cells border CENTER. Four were REST, and one of those (8866d338b1fffff) was a donor in every threshold-20 and threshold-12 pool under both flag rules. Two more were in the all-REST pools only (`donor_status_changes.csv`). The threshold-20 pools drop from 166 to 165 donors (screened) and from 270 to 269 (unscreened) (`donor_pool_sizes.csv`).
- **Coverage screen.** The frozen reference set and range are kept. 14 CENTER cells fall inside the range and one, a former CORRIDOR cell, falls above it (`center_cells_coverage_position.csv`, categories only).
- **BELISARIO with road weights.** The OSM snapshot stops at latitude -0.190 (`31_amend2_geography.R`). BELISARIO's cells lie north of it, except the southern tip of one cell (to -0.1909; one-off check, not saved to a file). Its weights therefore come from the provider's 2022 OSM length per cell, the denominator of each cell's own tci_osm_ratio. That makes the unit summed congested metres over summed road metres, as you specified. CENTER's weights come from the OSM snapshot clipped to the polygon, so the two units use different road sources. On 33 cells the two sources agreed to a median ratio of 1.005 and a total ratio of 1.026 (29 September memo).
- **Map.** `map_center_units.png` shows the polygon, the cells with their weights, the buffer and the core.

## Fits, holdout and benchmarks (item D.1)

Holdout errors, June to November 2023, from fits trained on January 2022 to May 2023 (`fit_statistics.csv`). The full pre-period RMSPE is the augsynth fit on all 23 months.

| Target, pool | augsynth RMSE (bias) | Plain SCM | Donor-mean DiD | Full pre RMSPE |
|---|---|---|---|---|
| CENTER, screened (165) | 0.827 (-0.42) | 0.749 (-0.29) | 1.451 (0.87) | 3.0e-7 |
| CENTER, unscreened (269) | 0.994 (-0.69) | 0.978 (-0.66) | 1.456 (0.87) | 0.227 |
| CORE, screened | 0.769 (0.02) | 1.184 (-0.48) | 2.453 (1.45) | 3.7e-7 |
| CORE, unscreened | 1.148 (-0.25) | 1.206 (-0.05) | 2.473 (1.45) | 0.464 |
| RING7, screened | 0.703 (-0.62) | 0.642 (-0.47) | 1.204 (0.77) | 2.1e-7 |
| RING7, unscreened | 0.679 (-0.56) | 0.689 (-0.57) | 1.223 (0.77) | 0.225 |
| BELISARIO road-weighted, screened | 0.782 (-0.48) | 0.628 (-0.14) | 2.166 (1.70) | 1.044 |
| BELISARIO road-weighted, unscreened | 2.326 (-2.16) | 1.707 (-1.57) | 2.192 (1.70) | 0.864 |
| CORRIDOR, screened | 0.897 (-0.80) | 0.882 (-0.75) | 0.454 (0.19) | 0.109 |
| CORRIDOR, unscreened | 1.122 (-1.05) | 1.123 (-1.04) | 0.467 (0.19) | 1.7e-7 |

- **The holdout doubles as the backdated fit.** Using pre-period data only, a fit with June 2023 as the treatment date is this holdout (Amendment 4, item 7).
- **The ring reproduces Step 1.** RING7 with the unscreened pool matches Step 1's CENTER (0.679, bias -0.56), and RING7 and BELISARIO_EQ reproduce Step 1's CENTER and BELISARIO series exactly (checked in `32_amend2_panel.R`).
- **BELISARIO, unscreened, still fails both benchmarks,** as in Step 1.
- **CORRIDOR is beaten by the DiD** in both pools.
- **Original flag rule (sensitivity).** CENTER loses three months (202201, 202304, 202307; `unit_month_validity.csv`), as the ring did in Step 1. Holdout RMSE 1.999 screened and 1.263 unscreened.
- **Contrast** (`contrast_statistics.csv`), CENTER minus road-weighted BELISARIO:
  - augsynth holdout RMSE 0.635 (bias 0.05) with the screened pool and 2.022 (bias 1.47) with the unscreened pool;
  - with equal-weight BELISARIO: 0.659 and 2.102.

### Weights and plain synthetic control (Amendment 4, item 6)

Full pre-period fits (`weight_statistics.csv`). Plain SCM is the frozen benchmark, with non-negative weights, no augmentation and no intercept; its weights sum to one with negatives below 1e-6 in every pool.

| CENTER, pool | Ridge penalty (grid edge) | Most negative weight | Sum of negative weights | Sum of absolute weights | Plain SCM: largest weight, donors above 1e-6 |
|---|---|---|---|---|---|
| Screened | 2.07e-5 (yes, minimum) | -0.072 | -1.479 | 3.957 | 0.313, 8 |
| Unscreened | 213 (no) | -0.013 | -0.272 | 1.543 | 0.207, 15 |
| Low exposure, screened | 18.0 (no) | -0.068 | -1.074 | 3.148 | 0.340, 8 |
| Low exposure, unscreened | 2,419 (yes, maximum) | -0.003 | -0.055 | 1.109 | 0.338, 10 |

## Drift checks (item D.2)

No drift rule is chosen. The evidence comes first, then the options.

- **(a) Fake window, June to November 2022** (`drift_a_fake_window_stats.csv`). The model trains on the other 17 pre months with the frozen penalty, so this check fills in a window from months on both sides; it does not forecast forward like the holdout. The frozen penalty was tuned on January 2022 to May 2023, which contains the window, so the check is not out of sample for tuning.

  | Target, pool | augsynth RMSE (bias) | Plain SCM | Bias without June 2022 | June 2022 gap |
  |---|---|---|---|---|
  | CENTER, screened | 1.345 (-0.67) | 1.273 (-0.62) | -0.45 | -1.81 |
  | CENTER, unscreened | 0.953 (-0.29) | 0.942 (-0.10) | -0.25 | -0.49 |
  | BELISARIO road-weighted, screened | 1.819 (0.85) | 1.582 (0.73) | 1.32 | -1.53 |
  | CORRIDOR, screened | 0.679 (-0.18) | 0.455 (-0.19) | -0.13 | -0.45 |

  - June 2022 is not CENTER's largest miss in this window. September 2022 is larger in both pools (augsynth -2.20 screened, -1.36 unscreened), and October 2022 (-1.49) is the largest unscreened miss (`drift_a_fake_window_paths.csv`).
  - CENTER's 2022 gaps change sign: three months are negative and three positive in each pool. In the 2023 holdout, by contrast, 5 of 6 months are negative with the screened pool.
- **(b) Holdout gaps by month** (`drift_bc_holdout_gaps.csv`).
  - CORRIDOR: augsynth gaps negative in all six months in both pools; DiD gaps positive in four of six.
  - BELISARIO road-weighted: negative in all six months with the unscreened pool and in four with the screened pool.
  - CENTER: negative in five months (screened) and four (unscreened).
- **(c) The backdated fit** is the holdout in the table above.
- **(d) Observation density** (`drift_d_density_summary.csv`, `drift_d_density_monthly.csv`, `drift_d_density.png`; per-donor counts stay in the ignored `Data/Waze/amend2/`). Delivered slots per cell-month, of 24, averaged over the first and last six pre months, with a descriptive linear slope (no test).

  | Series | First six months | Last six months | Slope per year |
  |---|---|---|---|
  | CENTER cells, road-weighted | 22.02 | 22.97 | +0.67 |
  | Ten heaviest donors, screened (mean weighted by absolute weight) | 22.39 | 22.72 | +0.34 |
  | Ten heaviest donors, unscreened (same) | 22.25 | 22.26 | +0.12 |

  - CENTER is not saturated: one CENTER cell had 4 slots in its lowest month.
  - Among the ten heaviest donors, slopes run from -0.69 to +1.96 per year (screened) and from -1.58 to +0.82 (unscreened).
  - A slot is delivered only when a jam was recorded, so density mixes congestion with observation.

**Options for a drift rule, with the evidence for each.** Your decision.

1. **No adjustment; report the holdout bias next to the P1 estimate as an interpretive threshold.**
   - For: CENTER's biases are of similar size in the two windows: -0.29 to -0.67 in 2022 against -0.42 to -0.69 in 2023, though the larger miss falls in opposite pools. So the miss may be an ordinary error of the method rather than a pre-opening change.
   - Against: the 2022 gaps change sign month to month, while the 2023 gaps are mostly negative. And the 2022 check fills in between months rather than forecasting, so it is not the same test.
2. **Backdated treatment (June 2023) as a Step 3 sensitivity.**
   - For: CORRIDOR's augsynth and plain SCM holdout gaps are negative in all six months in both pools, which fits a change along the line before opening.
   - But: CORRIDOR's DiD gaps are positive in four of six months.
   - Against: CENTER's gaps are not all negative.
3. **Exclude June to November 2023 from the fit as an anticipation window, training on January 2022 to May 2023.**
   - For: it removes the months where the line-wide drift shows.
   - Against: it costs six pre months, so the smallest p-value rises to 1/26.
4. **Read CENTER against CORRIDOR (difference in gaps) as a check on line-wide change.**
   - For: CORRIDOR drifts with CENTER.
   - Against: CORRIDOR is treated too, so this mixes two effects.
5. **Drop or down-weight donors whose observation density rises.**
   - For: CENTER's density rose more than the donors' (+0.67 against +0.34 and +0.12 per year).
   - Against: the rise is small (CENTER gained 0.94 slots of 24, against 0.33 and 0.01 for the donors), and density mixes congestion with observation.

## Low-exposure sensitivity (item D.3)

Donors more than 4 km from every station (`fit_statistics.csv`, `weight_statistics.csv`).

- **Screened (126 donors):** holdout RMSE 1.481 (bias -1.28); plain SCM 1.498; interior penalty 18.0; total negative weight -1.07.
- **Unscreened (214 donors):** 0.764 (bias -0.36); plain SCM 0.914; penalty at the top of the grid.

So the low-exposure donors fit CENTER's holdout less well with the screened pool (1.481 against 0.827) and better with the unscreened pool (0.764 against 0.994). Plan section 3: the tradeoff is reported, not resolved.

## Donor geography (item D.4)

Full pre-period augsynth fit for CENTER (`donor_geography_by_distance_band.csv`, `donor_geography_by_zonal_administration.csv`, `donor_geography_mean_distance.csv`, `map_donors.png`). Distance is from the line's alignment, not from stations. Every donor is more than 2 km from every station, but a few lie within 2 km of the track between stations.

| Distance from the line | Screened: donors, synthetic weight (share of absolute weight) | Unscreened |
|---|---|---|
| Under 2 km | 3, -0.011 (1.7%) | 4, 0.003 (0.4%) |
| 2 to 4 km | 38, 0.671 (32.3%) | 54, 0.337 (29.0%) |
| Over 4 km | 124, 0.341 (66.1%) | 211, 0.659 (70.7%) |

- **Weighted mean distance from the line:**
  - screened: 11.46 km weighted by synthetic weight, 8.84 km weighted by absolute weight;
  - unscreened: 12.10 km and 11.11 km;
  - plain SCM, screened: 0.436 of its weight sits on 2 donors at 2 to 4 km.
- **Zonal administration:**
  - 21 screened donors, and 44 unscreened, lie outside the DMQ's parish layers (GeoQuito, urban and rural). The 21 screened cells lie in neighbouring cantons, 0.03 to 6.2 km beyond the district boundary; the 23 unscreened-only cells were not checked (one-off check, not saved to a file).
  - They carry 0.560 (screened) and 0.575 (unscreened) of the signed synthetic weight, or 0.227 and 0.437 of the absolute weight.
  - That includes the heaviest screened donor (8866d3a891fffff, weight 0.36), north-east of the district (same one-off check).
  - Within the district, Eugenio Espejo carries 0.423 (screened) and 0.303 (unscreened).
  - One donor in each pool falls where urban and rural parishes overlap with different zonal administrations (Calderón and Eugenio Espejo), and is labeled "ambiguous". There are three such cells in the whole grid, from the run log, not saved to a file.

## Placebos (your item 5, Amendment 4)

- **Why five Step 1 placebos had a pre-period RMSPE below 0.001.** Neither of your two causes applies: none had its own cells in its donor pool (the Step 1 code removed them), and no outcome is near zero (pre-period means 2.2 to 4.7, no zero cell-month). They interpolate:
  - four through the ridge step at the grid-minimum penalty (plain SCM with an intercept fits them at an RMSPE of 0.067 to 0.244);
  - one (8866d33121fffff) through plain SCM itself, whose fit is exact (9.6e-13) with all 263 donors weighted, because its path lies inside the cloud of donor paths.

  This diagnosis was run as a one-off check in this session and is not saved to a file. The floor was therefore applied as you specified.
- **New placebo run** (`placebo_placement.csv`, `placebo_fits.csv`, `placebo_holdout_bias.png`). Overlapping seven-cell neighbourhoods on every pool cell whose whole ring is in the pool; buffer cells are excluded, and each placebo's own cells are removed from its donors.
  - **Screened pool: only 4 pseudo-neighbourhoods qualify.**
    - CENTER's own RMSPE is 3.0e-7, so the floor adds nothing. The scaled statistics are withheld in the file (NA, with a note) until you decide.
    - Unscaled, one of the four has a mean holdout gap at least as large in absolute value as CENTER's.
    - The plan's fit filter (RMSPE at most three times CENTER's) excludes three of the four.
  - **Unscreened pool: 28 qualify.**
    - The floor (CENTER's 0.227) binds for all 28, so the scaled and unscaled rankings coincide.
    - Eleven have their own RMSPE below 0.001, and 23 chose a penalty at a grid edge.
    - Two of the 28 have a mean holdout gap at least as large in absolute value as CENTER's (-0.69).
    - The fit filter excludes none.
    - Their pre-period means run from 2.2 to 6.6, against CENTER's 11.6.
  - **Two caveats.** The scale is the full pre-period RMSPE, as you specified; the training RMSPE would be the matching scale for a holdout gap. And the pseudo-targets are seven equal-weight cells while CENTER is 15 road-weighted cells, so their noise levels differ.
  - These are descriptive; no p-value is computed. The counts are given as counts, not shares, because a share would read as a rank p-value, which the plan says placebos do not carry.

## Changes to Step 1 code

- **Panel script:** `21_step1_panel.R` now keeps every cell's block values and monthly slot counts in the ignored panel file.
- **No-post check:** `25_step1_check_no_post.R` also scans the new output folders.
- **Step 1 outputs unchanged:** a rerun of 20 and 21 left every tracked Step 1 output unchanged (`git status`). The Step 1 freeze was not rewritten.
- **The "provisional zero coding" label stays in the Step 1 scripts.** Since 21 reruns, changing it would rewrite the tracked Step 1 summary. The new scripts use the provider's-method label.
- **Two check deviations:**
  - The new fit and drift scripts (33 and 34) check order invariance at an absolute tolerance of 1e-6 instead of the Step 1 helper's relative tolerance of 1e-8 (`amend2_helpers.R`). At the grid-minimum penalty, reordering the months moves the intercept by about 1e-8 (predictions by about 6e-9). That is numerical noise of the near-interpolating solve, compared with about 1e-13 at ordinary penalties.
  - Ellipsoidal areas use an equal-area projection, because `lwgeom` is not installed.
- **Fixes after the code review:**
  - Road pieces that an intersection returns inside a geometry collection are now extracted instead of dropped, and total road length is checked for conservation. The fix changed only the core's weights (top weight 0.534 to 0.529; `reports/congestion/2026-09-29_historic_center_candidates/road_length_weights_summary.csv` and `unit_cells_weights.csv`) and therefore the CORE rows. CENTER's weights did not change.
  - New assertions check that:
    - both polygons lie inside the OSM box;
    - all seven ring cells are in CENTER;
    - the rebuilt donor pools equal `Output/step1_freeze/donor_pools.csv` before the buffer is removed.
  - BELISARIO's per-cell provider road lengths are no longer written to the committed weights file; only its weights are.
  - The no-post check now also reads month-like names and column names.

## Decisions for you

1. **The interpolating primary fit.** Options:
   - keep it and treat CENTER's ridge fit as uninformative, so plain SCM carries the weight;
   - take the unscreened pool as primary, where the fit does not interpolate;
   - put a floor on the penalty grid (the Step 1 referee advised keeping augsynth's grid; `reports/congestion/2026-09-27_step1_report.md`, decision 5);
   - use plain SCM with an intercept as the primary estimator.

   Each is an amendment.
2. **A drift rule**, from the options above, or none.
3. **The placebo scale for the screened pool,** where CENTER's own RMSPE gives no floor.
4. **Donors outside the district.** About 0.56 of the signed synthetic weight sits on cells outside the DMQ's parish layers. The plan's donor rule does not restrict donors to the DMQ.
5. **The BELISARIO road source.** Provider lengths, not the OSM snapshot; confirm, or I can propose an OSM delivery covering BELISARIO.
6. **The referee's list** (below): the confirmatory null and statistic, a general interpolation criterion and whether the penalty is frozen in conformal refits, the holdout uses as model selection, one line per amendment item naming the results seen, the section 9 and 9a wording, the estimand restatement (including the share of weight outside the DMQ), the contrast p-value procedure, a complete dropped-month rule, and the placebo filter and scale.
7. **Register the parish delivery.** The parish delivery used for the zonal administrations (`road_safety/raw/2026-09-25_geoquito_parroquias/`) is not in the store's `MANIFEST.sha256`. The scripts check it only against its own `SHA256SUMS`. Registering it is your step.

## What ran, and status of every check

- **Pipeline:** `Rscript Scripts/Congestion/30_run_amend2.R` from raw, each script in a clean session, at `f6b783d`. The no-post check found no value dated December 2023 or later. It scans 71 files in this worktree (run log `logs/amend2_run_full4.log`, ignored by git) and, by the second verifier's report, 59 in a clean checkout at `f6b783d`, which lacks Step 1 derived files that only `22` and `23` write (71 once those are run).
- **Code-reviewer: done.**
  - By its report, it found no code error that changes a reported number.
  - Its critical point is the interpolating primary fit and the degenerate placebo floor, reported above.
  - It raised six major points, all fixed except the parish manifest (decision 7):
    - the geometry collections;
    - the uncommitted symlinks;
    - the parish manifest;
    - the pool assertion;
    - the missing fit filter;
    - BELISARIO's provider values.
  - Its minor points are fixed, except the label (kept, see above).
  - It could not run R. The full pipeline was rerun after the fixes and passed.
- **Verifier, first run at `ae1d50c`: failed on setup only.** Statements here are from its report.
  - `19_step1_setup.sh` stopped because you had added the three 2026-09-29 deliveries to `MANIFEST.sha256`, and the script did not map their paths.
  - The verifier checked the raw files itself and ran `30_run_amend2.R` unmodified. All 33 outputs came out byte-identical to the committed copies, and the tracked Step 1 outputs were unchanged.
  - Its own code matched the CENTER cells, areas, unit series, pools, holdout statistics, penalties and MDE. The only differences came from its own H3 hexagons, at most 3e-6.
  - It contradicted no number in this report.
  - It found that `st_make_valid` had moved the valid GeoQuito polygon by about 1 m² (513.634014 against STArea 513.634123 ha).
  - My own follow-up, not the verifier's: I fixed both problems in `f6b783d`.
    - The setup now checks 71 raw files, and polygons are repaired only if invalid.
    - The regenerated statistics differ from `ae1d50c` by at most 2.7e-5 in absolute terms (second verifier's comparison). Relative changes reach about 1e-4 to 2e-4 for some biases and fold errors, and up to 4.3e-3 for donor weights near 1e-5. No penalty choice changed, and no number shown in this report changes.
    - `setup_session.txt` now records rlang 1.3.0 where Step 1 had 1.1.7, a change in the shared library, not in the code.
- **Verifier, second run at `f6b783d`: passed with notes.** Statements here are from its report.
  - The setup passed and checked 71 raw files. `30_run_amend2.R` ran in a clean checkout.
  - All 33 Amendment 2 outputs and the 7 tracked Step 1 files are byte-identical to the committed copies. It also reran 22 and 23 for the three Step 1 files that 30 does not write.
  - The no-post check passed. The store was untouched.
  - Its own code reproduced, to about 1e-10:
    - CENTER's SIRES-DMQ area, against GeoQuito's STArea;
    - the CENTER weights;
    - the pre-period mean (11.5566 amended, 11.8397 original rule);
    - the augsynth, plain SCM and DiD holdout RMSEs in both primary pools;
    - every tuned penalty.
  - Its notes:
    - two inaccuracies in this report (change sizes and file count), now corrected;
    - the unregistered parish delivery (decision 7);
    - the STArea assertion in the code allows 0.01 ha, so on its own it would not have caught the old 1 m² shift.
  - It did not check the statements labeled as one-off checks.
- **Methods-referee (plan): done.** It judges the plan not ready to freeze. Statements below are from its report; it ran no code. I changed nothing in the plan in response, because every point is a decision for you.
  - **Critical: the confirmatory test is not well defined with the primary fit as it stands.**
    - A penalty near zero can match all 32 periods in the conformal refits, so the p-value would not depend on the data.
    - If P1 is not matched, the near-zero pre-period residuals make almost any P1 deviation rank first.
    - The penalty choice rests on the sixth to eighth significant digit of the leave-one-block-out error (`lobo_grid.csv`).
    - The plan does not say whether the penalty is frozen or re-tuned in the conformal refits.
    - Amendment 3 lists uninformative fits by name rather than by criterion.

    It asks for a general interpolation criterion, a choice of estimator, pool and penalty for the confirmatory test, and a record that the choice was made with the item D results in view. The candidates differ in holdout bias (augsynth screened -0.42, plain SCM screened -0.29, augsynth unscreened -0.69).
  - **Major:**
    1. The test statistic (mean absolute residual, sharp null) tests "no effect in any month", not the P1 average, and is unsigned. The plan does not name which null gives the confirmatory p-value. The smallest attainable p-value is 1/32 = 0.03125, so a 5 percent test rejects only at rank one.
    2. The holdout drift runs in the hypothesis direction, and no drift rule exists. The holdout has been used many times without being recorded as model selection, as section 6 requires.
    3. Amendments 2 to 4 do not record which results had been seen when each was decided. Amendment 3, item 1 (screened pool) gives a reason from the old ring unit. Amendment 4 entered in the same commit as the item D outputs.
    4. Section 1's safeguard on mixed zeros was replaced once it was triggered. Section 9's statement that the screen guards road coverage no longer holds after provider answer 3. Measurement change works in the hypothesis direction.
    5. Section 9a's bias signs assume non-negative weights, and they contradict section 9 ("the sign of the bias is not assumed"). Guard 3 must say whether weights are signed or absolute. Guard 1 uses stations, not the alignment.
    6. The estimand no longer matches "Quito" or the "historic center's roads":
       - 0.56 of the weight lies outside the DMQ;
       - section 4 still gives equal cell weights;
       - CENTER mixes in-polygon weights with whole-cell values;
       - CENTER now contains station-access cells.
    7. The contrast compares units built on different principles. Because CENTER interpolates, the contrast's pre-period residuals equal BELISARIO's. It has no defined p-value procedure, and localization is not tested.
    8. The dropped-month rule leaves the disruption months, donor gaps, unit-specific gaps and P1 gaps open. The superseded "not adjacent" sentence is not struck.
    9. The placebos collapse in the primary pool: the fit filter keeps only an interpolating placebo, and the floor is degenerate. The v2 placebo text still says "non-overlapping".
  - **Minor:**
    - superseded text not struck in sections 2, 5 and 11;
    - the December 2022 sensitivity has no replacement;
    - the adopted area (513.634 ha) is not in the plan;
    - the MDE is not the MDE of the planned test;
    - a placebo-in-time with 12 training months will probably interpolate;
    - the coverage screen's reference cells no longer match its stated purpose;
    - this report's headline on the 5 percent test was too strong (now conditional).
- **Claims-auditor (this report): done.**
  - By its report, almost every number traces to a committed file at `f6b783d`.
  - It found no post-opening estimate, no Wald or pnorm p-value, and no MDE read as a bound.
  - It asked for 18 corrections, all applied in this version. The main ones:
    - the drift headline now says that only the synthetic fits over-predict the whole line;
    - Amendment 3 has no general interpolation criterion;
    - the out-of-district shares are now given in signed and absolute weights;
    - two rounding slips, one cross-reference and the verifier attributions are fixed.
