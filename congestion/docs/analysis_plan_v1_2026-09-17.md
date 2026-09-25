# Analysis plan: Waze congestion module for Underground Relief

Draft of 17 September 2026 for author approval. Once approved and committed as docs/analysis_plan.md, this document governs every estimate. No post-opening effect is estimated before the commit. Any change after the pre-period fit is frozen is recorded as an amendment with its date and reason.

## What the module tests

The paper finds a localized PM2.5 reduction at the Centro monitor after Line 1 opened on December 1, 2023, and no comparable reduction at Belisario, a monitor equally close to the line but outside the historic center. The paper interprets this as destination-based mode substitution and leaves the traffic channel untested. This module asks whether Waze-recorded peak-hour congestion fell in the historic center after opening, whether it fell at Belisario, and whether the two responses differ.

## 1. Data and hygiene (fixed by the inventory)

The analysis uses the deduplicated all_roadtype block written in Phase B. The provider has confirmed that all hourly profiles are computed from Monday to Friday only, so every hour block in this plan is a weekday block, matching the paper's peak windows. The provider has also confirmed that severe congestion means Waze jam levels 3 and 4, which are exactly the segments below 40 percent of free-flow speed. Sentinels -998 and -999 are missing. An absent record within a delivered month is zero congestion. February, March and April 2025 are a delivery gap and every outcome is missing in those months for every cell. The 740 never-observed cells and the 92 cells without records in January 2022 to November 2023 are excluded from every group.

Flag rule. A cell-month-hour key is flagged if any auxiliary ratio is outside its range: tci_waze_ratio, tci_severe_waze_ratio, tc_spread_osm_ratio, tc_spread_waze_ratio, tc_severe_spread_osm_ratio or tc_severe_spread_waze_ratio below zero, or tc_severe_persistance_ratio above 100. For a flagged key, tci_osm_ratio, tci_severe_osm_ratio and avg_jam_speed_ratio are set to missing, not zero. A peak-block value for a cell-month is the mean over the unflagged hours in the block; it is missing only if all hours are flagged. A donor cell is excluded if more than 5 percent of its January 2022 to November 2023 keys are flagged. If the provider delivers a corrected panel, the whole plan is re-run on it and both sets of results are reported.

## 2. Units

CENTER is the H3 cell containing the published Centro monitor point (8866d33885fffff) plus its six neighbors. BELISARIO is the cell containing the published Belisario point (8866d33aa3fffff) plus its six neighbors. Each is aggregated to one unit as the equal-weight mean of its cells' peak-block outcomes. CORRIDOR is the 34 cells within 1 km of any other Line 1 station, aggregated the same way. RING is the cells between 1 and 2 km of any station and is never a donor.

Sensitivity, fixed now: CENTER defined as the cells within 1 km of San Francisco station, BELISARIO as the cells within 1 km of the published Belisario point. If precise monitor coordinates arrive before the pre-period fit is frozen, the seven-cell neighborhoods are re-centered on them and that is recorded as an amendment; the neighborhoods are not changed after the freeze.

## 3. Donor pool

The main donor pool is the saturated REST cells: cells in REST with a mean of at least 20 delivered hourly slots per month over January 2022 to November 2023, after the flag exclusion. Sensitivities: threshold 12, and all eligible REST cells.

Coverage file. The provider is delivering annual OSM road length, Waze road length and their ratio (Waze coverage) per cell. It is used three ways. First, as the penetration diagnostic: mean coverage by group and year, reported with the results, with any group whose coverage trend departs from CENTER's after 2023 flagged. Second, as a pre-period donor screen added to the saturated rule: donors must have 2022 and 2023 coverage within the range observed in the CENTER and BELISARIO cells; post-period coverage is never used to select donors. Third, OSM road length is available as a weight for a length-weighted version of each unit aggregate, reported as a sensitivity to the equal-weight primary. CENTER, BELISARIO, CORRIDOR and RING never enter a donor pool. The first execution report states how many donors have a pre-period mean peak outcome at or above CENTER's, and the same for BELISARIO and CORRIDOR.

## 4. Outcome

Primary: tci_osm_ratio averaged over hours 7, 8, 17 and 18, at the unit level, analyzed as log(outcome). Effects are reported in log points and as percent, as in the paper. Level (percent) version is a sensitivity.

Secondary: morning block (7, 8) and evening block (17, 18) separately; tci_severe_osm_ratio in the same peak block; avg_jam_speed_ratio in the peak block, labeled as conditional on recorded jams. The fast-road block (roadtype = large) repeats the primary outcome as a secondary result. Night hours 0 to 4 repeat the primary outcome as a diagnostic that carries little signal and is not a validation of the design.

## 5. Calendar and estimands

Pre period: January 2022 to November 2023 (23 months). Sensitivity: January 2019 start, with March to December 2020 excluded.

P1: December 2023 to August 2024. Disruption: September to December 2024, excluded from all clean-window estimates. Usable P2: January 2025 and May to December 2025.

Confirmatory estimand: the P1 average effect for CENTER. Persistence: the clean-window average (P1 plus usable P2). Secondary: P2 alone, and the full available window including the disruption. Months are equally weighted.

## 6. Estimator

Primary: augmented synthetic control with a unit intercept (demeaned) and ridge augmentation, one exposed unit against the donor cells, fit on the pre period only. The ridge penalty is chosen by blocked leave-one-block-out validation on the pre period with three-month blocks. The fit is frozen before any post-opening month enters. Reported for every fit: pre-period RMSPE, the share of the pre-period RMSPE relative to the unit's pre-period standard deviation, the donor weights, the share of weight on the five largest donors, and the intercept.

Robustness: synthetic difference-in-differences with the same exposed unit and donor pool, months excluded consistently. The paper's citywide SDID with external cities has no analog in this delivery and is not attempted.

Implementation: augsynth and synthdid from GitHub if installable; otherwise a direct implementation of ridge-augmented SCM in R, checked against the package on a public example before use. The implementation choice is recorded in the execution report.

## 7. Inference

Conformal inference on the post-period residuals with moving-block permutations of length three, reported with its finite support. Placebo-in-space: each saturated donor cell, in turn, is treated as the exposed unit with the same estimator, pre period and rules; the rank of CENTER's effect among the placebo effects is reported, with placebos whose pre-period RMSPE exceeds three times CENTER's excluded and the exclusion count stated. Placebo-in-time: a fake opening in January 2023 with a 2022 baseline, reported as a diagnostic.

Joint test. The Centro-minus-Belisario contrast is tested against the distribution of contrasts between pairs of placebo cells drawn at distances comparable to the Centro-Belisario distance. A significant CENTER effect and a non-significant BELISARIO effect are not by themselves evidence of a difference; only the contrast is.

Minimum detectable effect. Every null is reported with the pre-only detectable effect for that unit and window, so a null is read as "no effect larger than X" rather than "no effect."

## 8. Tiers and order of operations

Tier 1, confirmatory: CENTER and BELISARIO, primary outcome, P1, with the joint contrast. Tier 2, corridor: CORRIDOR against the same donors, primary outcome, P1 and clean window; RING reported as the spillover check. Tier 3, exploratory: cellwise estimates for all saturated-coverage cells within 3 km of the line, mapped with placebo-rank p-values under Benjamini-Hochberg control, with unsupported cells shown as such.

Order. Step 1: Astra fits the pre-period models for CENTER, BELISARIO and CORRIDOR, reports the diagnostics in section 6 and the donor level counts in section 3, and commits with no post-opening month loaded. Step 2: the authors review the fit and either freeze it or amend this plan. Step 3: Astra runs Tier 1 and Tier 2 on the frozen fits, then inference, then sensitivities, then Tier 3, in that order, committing after each. Step 4: the authors read the results before any interpretation is written.

## 9. Threats, stated once

Waze penetration grows in the periphery over the sample; the saturated-donor screen and the fixed pre-period eligibility rule address the extensive margin but not intensity growth, and observation counts have been requested from the provider. Free flow does not enter the primary outcome's denominator but affects jam detection and severity classification; the free-flow series by group is reported alongside results. Station construction may have raised congestion in the center in 2022 and 2023, which would bias the P1 effect toward a reduction; the 2019-start sensitivity and the placebo-in-time speak to this, and a closure log has been requested. The 2024 energy crisis is excluded by the disruption window and its persistence into 2025 is visible in the P2-alone estimate. Spillovers into RING are reported, not assumed away. The peak block is weekday-only, as confirmed by the provider.

## 10. Open items that do not block execution

Provider: corrected February to April 2025, the source of the triplication and the flagged values, the 8,290 fast-road keys without an all-road match, and confirmation that an absent all-road record never means suppressed data. Observation counts cannot be produced from the provider's pipeline. Authors: precise monitor coordinates, construction dates. Paper: conflicts P1 and P3 on exported p-values and SDID labels are carried unchanged.
