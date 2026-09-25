# Analysis plan v2: Waze congestion module for Underground Relief

Revised 22 September 2026 after the authors' review of the 17 September draft. Once approved and committed as docs/analysis_plan.md, this document governs every estimate. No post-opening effect is estimated before the commit. Amendments after the pre-period freeze are recorded with date and reason. Items marked [author decision pending] are settled by the authors before the freeze and never from results.

## What the module tests

The paper finds a localized PM2.5 reduction at the Centro monitor after Line 1 opened on December 1, 2023, and no comparable reduction at Belisario. This module asks whether Waze-recorded peak-hour congestion in the historic center changed after opening, relative to selected comparison roads elsewhere in Quito, and whether Belisario shows the same. A congestion response is evidence on the traffic channel the paper leaves untested. It does not identify travelers' previous modes, the number of vehicles removed, emissions avoided, or the share of the PM2.5 effect mediated by traffic, and the paper will not claim any of those from it. The outcome is Waze-recorded congestion: what Waze's users and detection rules registered, not traffic itself.

## 1. Data states and hygiene

Base table: the deduplicated all_roadtype block from Phase B (every repeated key had identical values; multiplicity one or three; source unknown). The provider has confirmed that hourly profiles use Monday to Friday only and that severe congestion means Waze jam levels 3 and 4, equivalent to speed below 40 percent of free flow. Provenance for both is the provider's email of 17 September 2026, saved in docs/.

Five states are kept distinct: (a) a delivered record with valid values; (b) an absent record in a delivered month; (c) a sentinel (-998, -999) or an out-of-range auxiliary value that marks a contaminated key; (d) the February to April 2025 delivery gap, missing for every cell; (e) a cell that never appears or has no record in the pre period, excluded.

Zero coding. State (b) is coded as zero recorded congestion only after the provider confirms in writing that an absent all_roadtype key means no recorded jam rather than insufficient coverage, suppression or processing failure (question in section 11). Until then, provisional zero coding is used for diagnostics and pre-period fits, labeled as provisional, and no final estimate is produced. If the answer mixes the two cases, a flag or corrected extract is requested and estimation waits. States (c) and (d) are always missing. Conditional jam speed is undefined when there is no recorded jam and is never coded as zero.

Flag rule. A key is contaminated if tci_waze_ratio, tci_severe_waze_ratio, tc_spread_osm_ratio, tc_spread_waze_ratio, tc_severe_spread_osm_ratio or tc_severe_spread_waze_ratio is below zero, or tc_severe_persistance_ratio exceeds 100. Bounds come from the provider's definitions, not from variable names. Contaminated keys are missing for every outcome.

Fixed composition. Each unit is a fixed set of cells and hours with fixed weights, declared before fitting. A unit-month value exists only when every cell-hour component is valid, where a documented structural zero counts as valid. Otherwise the unit-month is missing. No na.rm, no renormalized weights, no substitution. The report states, for every target and every donor, the number of missing unit-months by period and reason. If CENTER has more than two missing months in P1 under this rule, estimation stops and the authors decide on an explicit missing-data treatment.

The dictionary in reports/waze_inventory.md is extended before the freeze with, for tci_osm_ratio: numerator, denominator, units (native scale 0 to 100), averaging over eligible weekdays (all weekdays or only days with a recorded jam), road-network vintage, and treatment of overlapping jam segments. The unmatched fast-road keys are traced before any fast-road analysis.

## 2. Units and geography

CENTER: the cell containing the published Centro monitor point (8866d33885fffff) plus its six H3 neighbors, equal weights. BELISARIO: the same around the published Belisario point (8866d33aa3fffff). CORRIDOR: cells whose centroid lies within 1 km of any other Line 1 station. RING: cells with centroid between 1 and 2 km of any station, never a donor. Membership uses cell centroids throughout; the four sets are disjoint. The counts (7, 7, 34, 56) are reconciled and mapped with the monitors, the historic-center boundary if available, the line, the stations and major roads before the freeze. Precise monitor coordinates, if obtained before the freeze, re-center the neighborhoods by amendment.

Alternative exposure geography, fixed now: CENTER as the cells within 1 km of San Francisco station and BELISARIO as the cells within 1 km of its nearest station. This changes the center and the area, and is reported as an alternative geography, not a radius check.

## 3. Donor pool

Eligibility (a pre-period comparability rule, not a penetration measure): REST cells with a mean of at least 20 delivered hourly slots per month over January 2022 to November 2023, after the flag rule. Because a delivered slot exists only when a jam was recorded, this selects on pre-period congestion frequency; the plan says so. Sensitivities: threshold 12, and all REST cells with any pre-period record.

Coverage screen: donors must have 2022 Waze/OSM coverage within the range observed across the fourteen CENTER and BELISARIO cells in 2022. Calendar 2023 coverage includes December 2023 and is not used for screening unless the provider documents that the annual measure is fixed before December. The provider is asked whether Waze road length means mapped roads or roads with at least one recorded jam; only the former is an independent coverage measure. Post-opening coverage is checked for integrity only and never used to select donors. Road-length weights, where used, are frozen at the 2022 vintage.

Low-exposure sensitivity: donors whose centroid is more than 4 km from any Line 1 station. If these cannot fit the target, the tradeoff is reported, not resolved by widening the pool.

Observation and jam counts cannot be produced from the provider's pipeline; their absence is a stated limitation.

## 4. Outcome and units

Primary: tci_osm_ratio in its native 0 to 100 scale, averaged over the peak hour bins 7, 8, 9, 17, 18 and 19, aggregated to the unit with equal cell weights, analyzed in levels. These are the paper's bins: its panel script (02_build_weekly_panels.R, line 60) keeps hour_of_day in {7, 8, 9, 17, 18, 19} on weekdays. The morning block is bins 7 to 9 and the evening block 17 to 19. Effects are reported in percentage points and, for interpretation, as the level effect divided by the synthetic counterfactual's post-period mean. Secondary transformation: log of the unit aggregate for CENTER, BELISARIO and CORRIDOR, whose pre-period aggregates are bounded away from zero; a donor cell with any zero unit-month is dropped from the log specification and the count is reported. Inverse hyperbolic sine is not used: with zeros present its effects depend on the outcome's units and carry no percent interpretation.

Secondary outcomes: morning and evening blocks separately; tci_severe_osm_ratio; avg_jam_speed_ratio, conditional on recorded jams and subject to selection into recorded jams; the fast-road block; the OSM-length-weighted aggregate as an alternative estimand. Night hours 0 to 4 are a diagnostic with little signal.

## 5. Calendar and hypotheses

Pre period: January 2022 to November 2023 (23 months). The paper's local pre period starts December 2022 (52 weeks); the module uses the longer window because a synthetic control with 23 fitting periods is better constrained than one with 12, and the December 2022 start is reported as a sensitivity so the two modules can be read on the same footing. Further sensitivity: January 2019 start with March to December 2020 excluded, used only after measurement consistency across years is checked.

P1: December 2023 to August 2024, described as preceding the major late-2024 disruption, not as free of outages. Disruption: September to December 2024, excluded from clean estimates. Usable P2: January 2025 and May to December 2025. Calendar time is preserved in every dependence calculation; January and May 2025 are not adjacent.

Primary hypothesis: the CENTER P1 average effect. The clean window (P1 plus usable P2) is the persistence estimate. The full available window, including September to December 2024, is a robustness estimate only: the national electricity rationing lowered activity everywhere, and a common shock is differenced out by the synthetic control, but any differential response between the center and the comparison roads is not, and its sign cannot be established. The authors confirmed this hierarchy on 22 September 2026. Pre-specified secondary hypotheses: the BELISARIO P1 effect and the CENTER-minus-BELISARIO contrast, Holm-adjusted if used jointly for the central claim. CORRIDOR and RING are Tier 2, with the spillover limitation stated. Cellwise significance maps are deferred.

## 6. Estimator and validation

Augmented synthetic control with unit intercept and ridge augmentation (augsynth, pinned version), one target against donor cells, fit on the pre period. Ridge penalty by leave-one-block-out validation with three-month blocks on the training sample. Terminal holdout: June to November 2023 is held out, tuning uses January 2022 to May 2023 only, and holdout prediction error is compared with two benchmarks fixed now: the donor-mean difference-in-differences and unaugmented SCM. Reported per fit: training and holdout RMSPE, fold-level errors, the pre-period residual path, initial SCM weights and effective augmented weights, total negative weight, sum of absolute weights, absolute-weight concentration, the intercept, and sensitivity to removing each of the five most influential donors. The holdout is used once; any second use is recorded as model selection. Synthetic difference-in-differences (synthdid, pinned) is the robustness estimator.

A validated package is required. If augsynth cannot be installed, the authors install the compiler toolchain; a custom estimator is not substituted.

## 7. Inference

Conformal inference follows Chernozhukov, Wüthrich and Zhu. For a hypothesized effect path, the post-period outcomes are adjusted by that path, the model is refit on all periods, the full residual sequence over pre and post periods is formed, and the test statistic is the mean absolute post-period residual. The permutation set is all moving-block permutations of the full residual sequence, with the number of permutations and the attainable p-value support reported. Two nulls are tested and named: the sharp null of zero effect in every P1 month, and constant-effect nulls inverted to a confidence interval for the P1 average. Design and tuning choices are frozen; refits required by the procedure are not amendments. If dependence or gaps make average-effect inference infeasible, the point estimate and diagnostics are reported without a manufactured p-value.

Spatial placebos: pseudo-targets are seven-cell neighborhoods centered on eligible REST cells whose full ring is eligible, non-overlapping, built with the same aggregation and composition rules, each with its own cells removed from its donor pool. Results are reported before and after a pre-specified fit filter (pseudo-target pre-period RMSPE within three times CENTER's), with the number excluded. These are observational diagnostics; overlapping neighborhoods are not counted as independent.

Contrast: the CENTER-minus-BELISARIO difference is compared with differences between pairs of pseudo-neighborhoods separated by 4 to 6 km and matched on pre-period mean and variance, with both members removed from each other's donor pools. The joint null is that neither has an effect; rejection is not evidence of unequal effects, and the equality of two nonzero effects is not tested.

Placebo-in-time: fake opening January 2023, training calendar 2022, evaluation to November 2023, labeled as a shorter-training diagnostic that cannot rule out a December 2023 confounder.

Power is reported separately from results, with alpha, power target, assumed effect path and dependence assumptions, calibrated on holdout errors rather than training residuals. A nonsignificant estimate is reported with its interval and a discussion of which reductions remain compatible with the data; it is not read as an exclusion bound.

## 8. Order of operations

Step 1: data audit, dictionary completion, geography reconciliation, hour-bin verification, provisional pre-period fits with holdout and benchmarks, inference specification check against the actual panel dimensions, revised plan and unresolved-decisions list. No post-opening target outcome enters an estimator. Step 2: authors confirm the pending decisions, the zero-coding answer and the freeze. Step 3: Tier 1 on the frozen fits, then inference, then sensitivities, then Tier 2, committing after each. Step 4: authors read results before interpretation is written. A descriptive extension is the fallback if identification or inference cannot be supported.

## 9. Threats, stated once

Measurement: Waze penetration and detection may change with the metro itself; the coverage screen and frozen weights address road coverage, not the composition of Waze users. Donor contamination: within-Quito donors may carry metro effects; the estimated gap is the target effect net of weighted donor effects, and the sign of the bias is not assumed. Construction: street reopenings around San Francisco and La Alameda in 2022 and 2023 may raise the pre-period baseline; available records are used and the limitation stated if channels cannot be separated. Outages before September 2024 are a contextual limitation. Free flow affects jam detection and severity, not the primary denominator; the free-flow series by group is reported. Spillovers into RING are reported.

## 10. Manuscript integration

Held until measurement and inference are settled and the exported p-value and SDID-label discrepancies in the paper's results files are reconciled. The congestion and pollution windows are aligned in presentation; May to December 2025 congestion lies beyond the paper's local PM2.5 endpoint and speaks to persistence only. Contemporaneous congestion is not added as a pollution control. Pages 11 and 15 of the manuscript, which use Belisario's nonsignificant pollution response to justify it as a donor, are revised: a nonsignificant estimate does not establish zero exposure.

## 11. Open items

Provider (one message): in a delivered month, does an absent all_roadtype cell-month-hour record always mean zero recorded congestion, or can it reflect insufficient coverage, suppression or a processing failure, excluding the known February to April 2025 gap and the sentinel codes; can zero be assigned to tci_osm_ratio and tci_severe_osm_ratio for absent records; if the cases are mixed, can a flag or corrected extract distinguish them; do the monthly hourly indexes average over all eligible weekdays including days with no recorded jam; does Waze road length mean mapped roads or roads with at least one recorded jam; is the annual coverage measure for 2023 fixed before December. Still pending from earlier: the February to April 2025 re-run, the triplication, the contaminated keys, the unmatched fast-road keys. Authors: precise monitor coordinates, construction records. Hour bins and the primary window are settled. Paper: conflicts P1 and P3 carried unchanged.
