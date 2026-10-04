# Governing plan, v2 of 2026-09-22

Copied unchanged from `analysis_plan_v2.md` on 2026-09-27 (workstream B, Step 1). The v1 and v2 files stay as they are. Leonel's written approval, which root rule 5 requires before any post-opening estimate, is not yet recorded here.

Amendments are listed with date and reason at the end. From Amendment 2 (2026-09-29) on, the sections they change carry a bracketed note at the point of change, and superseded text is kept and marked, so the v2 wording stays readable.

# Analysis plan v2: Waze congestion module for Underground Relief

Revised 22 September 2026 after the authors' review of the 17 September draft. Once approved and committed as docs/analysis_plan.md, this document governs every estimate. No post-opening effect is estimated before the commit. Amendments after the pre-period freeze are recorded with date and reason. Items marked [author decision pending] are settled by the authors before the freeze and never from results.

## What the module tests

The paper finds a localized PM2.5 reduction at the Centro monitor after Line 1 opened on December 1, 2023, and no comparable reduction at Belisario. This module asks whether Waze-recorded peak-hour congestion in the historic center changed after opening, relative to selected comparison roads elsewhere in Quito, and whether Belisario shows the same. A congestion response is evidence on the traffic channel the paper leaves untested. It does not identify travelers' previous modes, the number of vehicles removed, emissions avoided, or the share of the PM2.5 effect mediated by traffic, and the paper will not claim any of those from it. The outcome is Waze-recorded congestion: what Waze's users and detection rules registered, not traffic itself.

## 1. Data states and hygiene

Base table: the deduplicated all_roadtype block from Phase B (every repeated key had identical values; multiplicity one or three; source unknown). The provider has confirmed that hourly profiles use Monday to Friday only and that severe congestion means Waze jam levels 3 and 4, equivalent to speed below 40 percent of free flow. Provenance for both is the provider's email of 17 September 2026, saved in docs/.

Five states are kept distinct: (a) a delivered record with valid values; (b) an absent record in a delivered month; (c) a sentinel (-998, -999) or an out-of-range auxiliary value that marks a contaminated key; (d) the February to April 2025 delivery gap, missing for every cell; (e) a cell that never appears or has no record in the pre period, excluded.

Zero coding. [Amendment 3, 2026-09-29: the paragraph below replaces the v2 paragraph, kept struck at the end of this section.] State (b) is coded as zero recorded congestion. This is the provider's own method: the provider's answer of 2026-09-29 (`docs/2026-09-29_provider_answers.md`, answer 1) says that a missing cell-hour means Waze reported no congestion there, and that its methodology treats the cell as free flow. The same answer states the caveat that this plan carries into every result: **a missing record means either no congestion or congestion with no Waze user to report it.** A zero is therefore "no Waze-recorded congestion", not "no congestion". A fall in Waze users in an area lowers its recorded congestion even if traffic does not change (section 9, measurement). Answer 2 adds that the delivered monthly values already average over all business days of the month with zeros for days without a jam, so zero coding applies to absent monthly cell-hour records in a delivered month. States (c) and (d) are always missing. Conditional jam speed is undefined when there is no recorded jam and is never coded as zero.

~~v2 text: "State (b) is coded as zero recorded congestion only after the provider confirms in writing that an absent all_roadtype key means no recorded jam rather than insufficient coverage, suppression or processing failure (question in section 11). Until then, provisional zero coding is used for diagnostics and pre-period fits, labeled as provisional, and no final estimate is produced. If the answer mixes the two cases, a flag or corrected extract is requested and estimation waits."~~

Flag rule. A key is contaminated if tci_waze_ratio, tci_severe_waze_ratio, tc_spread_osm_ratio, tc_spread_waze_ratio, tc_severe_spread_osm_ratio or tc_severe_spread_waze_ratio is below zero, or tc_severe_persistance_ratio exceeds 100. Bounds come from the provider's definitions, not from variable names. Contaminated keys are missing for every outcome.

Fixed composition. Each unit is a fixed set of cells and hours with fixed weights, declared before fitting. A unit-month value exists only when every cell-hour component is valid, where a documented structural zero counts as valid. Otherwise the unit-month is missing. No na.rm, no renormalized weights, no substitution. The report states, for every target and every donor, the number of missing unit-months by period and reason. If CENTER has more than two missing months in P1 under this rule, estimation stops and the authors decide on an explicit missing-data treatment.

The dictionary in reports/waze_inventory.md is extended before the freeze with, for tci_osm_ratio: numerator, denominator, units (native scale 0 to 100), averaging over eligible weekdays (all weekdays or only days with a recorded jam), road-network vintage, and treatment of overlapping jam segments. The unmatched fast-road keys are traced before any fast-road analysis.

## 2. Units and geography

[Amendment 2, 2026-09-29: CENTER is now the historic center defined by an official polygon, with road-length weights; the seven-cell ring below becomes a sensitivity. See Amendment 2 for the definition. BELISARIO is unchanged.] CENTER: the cell containing the published Centro monitor point (8866d33885fffff) plus its six H3 neighbors, equal weights. BELISARIO: the same around the published Belisario point (8866d33aa3fffff). CORRIDOR: cells whose centroid lies within 1 km of any other Line 1 station. RING: cells with centroid between 1 and 2 km of any station, never a donor. Membership uses cell centroids throughout; the four sets are disjoint. ~~The counts (7, 7, 34, 56)~~ [Amendment 5, proposed: superseded; under Amendment 4, CENTER has 15 cells and CORRIDOR 29, and Amendment 5 replaces cell donors with tiles] The geography is reconciled and mapped with the monitors, the historic-center boundary if available, the line, the stations and major roads before the freeze. Precise monitor coordinates, if obtained before the freeze, re-center the neighborhoods by amendment.

Alternative exposure geography, fixed now: CENTER as the cells within 1 km of San Francisco station and BELISARIO as the cells within 1 km of its nearest station. This changes the center and the area, and is reported as an alternative geography, not a radius check.

## 3. Donor pool

Eligibility (a pre-period comparability rule, not a penetration measure): REST cells with a mean of at least 20 delivered hourly slots per month over January 2022 to November 2023, after the flag rule. Because a delivered slot exists only when a jam was recorded, this selects on pre-period congestion frequency; the plan says so. Sensitivities: threshold 12, and all REST cells with any pre-period record.

[Amendment 3, 2026-09-29: the primary donor pool is the threshold-20 pool with the coverage screen ("screened"); the same pool without the screen ("unscreened") is a fixed sensitivity. Provider answer 3 settles what the screen measures: the cumulative jam extent Waze had observed in each cell by 2022, a running maximum since 2019, not mapped road coverage. Amendment 4 (2026-10-01) keeps the frozen reference set (the fourteen Step 1 ring cells) and the frozen range, so the donor pools stay as frozen.] Coverage screen: donors must have 2022 Waze/OSM coverage within the range observed across the fourteen CENTER and BELISARIO cells in 2022. Calendar 2023 coverage includes December 2023 and is not used for screening unless the provider documents that the annual measure is fixed before December. The provider is asked whether Waze road length means mapped roads or roads with at least one recorded jam; only the former is an independent coverage measure. Post-opening coverage is checked for integrity only and never used to select donors. Road-length weights, where used, are frozen at the 2022 vintage.

Low-exposure sensitivity: donors whose centroid is more than 4 km from any Line 1 station. If these cannot fit the target, the tradeoff is reported, not resolved by widening the pool.

Observation and jam counts cannot be produced from the provider's pipeline; their absence is a stated limitation.

## 4. Outcome and units

[Amendment 5, proposed: the primary outcome is labeled a road-weighted index of the hexagons covering the district, and described as Waze-reported congestion; fewer drivers also means fewer Waze observers. Its scale (levels or proportions) is set by the test in Amendment 5, item 3. Units are built as in Amendments 2 and 4 (CENTER) and Amendment 5, item 4 (donor tiles).] Primary: tci_osm_ratio in its native 0 to 100 scale, averaged over the peak hour bins 7, 8, 9, 17, 18 and 19, aggregated to the unit with equal cell weights, analyzed in levels. These are the paper's bins: its panel script (02_build_weekly_panels.R, line 60) keeps hour_of_day in {7, 8, 9, 17, 18, 19} on weekdays. The morning block is bins 7 to 9 and the evening block 17 to 19. Effects are reported in percentage points and, for interpretation, as the level effect divided by the synthetic counterfactual's post-period mean. Secondary transformation: log of the unit aggregate for CENTER, BELISARIO and CORRIDOR, whose pre-period aggregates are bounded away from zero; a donor cell with any zero unit-month is dropped from the log specification and the count is reported. Inverse hyperbolic sine is not used: with zeros present its effects depend on the outcome's units and carry no percent interpretation.

Secondary outcomes: morning and evening blocks separately; tci_severe_osm_ratio; avg_jam_speed_ratio, conditional on recorded jams and subject to selection into recorded jams; the fast-road block; the OSM-length-weighted aggregate as an alternative estimand. Night hours 0 to 4 are a diagnostic with little signal.

## 5. Calendar and hypotheses

Pre period: January 2022 to November 2023 (23 months). The paper's local pre period starts December 2022 (52 weeks); the module uses the longer window because a synthetic control with 23 fitting periods is better constrained than one with 12, and the December 2022 start is reported as a sensitivity so the two modules can be read on the same footing. Further sensitivity: January 2019 start with March to December 2020 excluded, used only after measurement consistency across years is checked.

P1: December 2023 to August 2024, described as preceding the major late-2024 disruption, not as free of outages. Disruption: September to December 2024, excluded from clean estimates. Usable P2: January 2025 and May to December 2025. ~~Calendar time is preserved in every dependence calculation; January and May 2025 are not adjacent.~~ [Struck by Amendment 5, proposed; the dropped-month rule is in Amendment 5, item 6.]

[Amendment 3, 2026-09-29, replaces the hierarchy below for inference: **the CENTER P1 average effect is the single confirmatory test, at the 5 percent level**, with CENTER as defined in Amendment 2 (the wider historic center). Its smallest attainable p-value is reported next to it: 1/32 with 23 pre months and 9 P1 months, or 1/T when T periods are used. The BELISARIO P1 effect, the CENTER-minus-BELISARIO contrast and the P2 and clean-window estimates are secondary, reported with their own p-values and smallest attainable p-values, and **no joint or Holm-adjusted claim is made**. Missing months in the clean and full windows (February to April 2025, and any month a unit loses under the composition rule) are dropped; the remaining months keep their time order, and each result states the number of periods used. For permutation inference this supersedes the sentence above that January and May 2025 are not adjacent: after the drop, the moving-block permutations treat them as consecutive.] Primary hypothesis: the CENTER P1 average effect. The clean window (P1 plus usable P2) is the persistence estimate. The full available window, including September to December 2024, is a robustness estimate only: the national electricity rationing lowered activity everywhere, and a common shock is differenced out by the synthetic control, but any differential response between the center and the comparison roads is not, and its sign cannot be established. The authors confirmed this hierarchy on 22 September 2026. Pre-specified secondary hypotheses: the BELISARIO P1 effect and the CENTER-minus-BELISARIO contrast~~, Holm-adjusted if used jointly for the central claim~~ [struck by Amendment 5, proposed: no joint claim (Amendment 3); the contrast is descriptive unless both units are built the same way]. CORRIDOR and RING are Tier 2, with the spillover limitation stated. Cellwise significance maps are deferred.

## 6. Estimator and validation

[Amendment 5, proposed: the estimator is chosen by the contest in Amendment 5, item 5, with synthetic control with an intercept and non-negative weights as the default; the ridge with a cross-validated penalty is no longer the primary estimator.] Augmented synthetic control with unit intercept and ridge augmentation (augsynth, pinned version), one target against donor cells, fit on the pre period. Ridge penalty by leave-one-block-out validation with three-month blocks on the training sample. Terminal holdout: June to November 2023 is held out, tuning uses January 2022 to May 2023 only, and holdout prediction error is compared with two benchmarks fixed now: the donor-mean difference-in-differences and unaugmented SCM. Reported per fit: training and holdout RMSPE, fold-level errors, the pre-period residual path, initial SCM weights and effective augmented weights, total negative weight, sum of absolute weights, absolute-weight concentration, the intercept, and sensitivity to removing each of the five most influential donors. The holdout is used once; any second use is recorded as model selection. Synthetic difference-in-differences (synthdid, pinned) is the robustness estimator.

[Amendment 3, 2026-09-29: two sets of Step 1 fits interpolate their training months and are declared uninformative: the December 2022 start fits (in Step 1, every CENTER fit trained on December 2022 to May 2023 reproduced its training months almost exactly), and the two original-rule, screened-pool augsynth fits. They are kept in a labeled appendix table ("uninformative: interpolating fits") and are not read as evidence on fit or on effects.]

A validated package is required. If augsynth cannot be installed, the authors install the compiler toolchain; a custom estimator is not substituted.

## 7. Inference

Conformal inference follows Chernozhukov, Wüthrich and Zhu. For a hypothesized effect path, the post-period outcomes are adjusted by that path, the model is refit on all periods, the full residual sequence over pre and post periods is formed, and the test statistic is the mean absolute post-period residual. The permutation set is all moving-block permutations of the full residual sequence, with the number of permutations and the attainable p-value support reported. Two nulls are tested and named: the sharp null of zero effect in every P1 month, and constant-effect nulls inverted to a confidence interval for the P1 average. Design and tuning choices are frozen; refits required by the procedure are not amendments. If dependence or gaps make average-effect inference infeasible, the point estimate and diagnostics are reported without a manufactured p-value.

[Amendment 3, 2026-09-29: spatial placebos are descriptive and carry no p-value; conformal inference remains the test. Pseudo-neighborhoods may overlap. Each placebo gap is scaled by that pseudo-target's own pre-period RMSPE, and the report shows the distribution of scaled gaps with CENTER's scaled gap placed in it. The scale has a floor (Amendment 4, 2026-10-01): each pseudo-target's gap is divided by the larger of its own pre-period RMSPE and CENTER's. A pseudo-target's own cells are never in its donor pool. The pre-period placebo fits of Step 1 have already been seen.] [Amendment 5, proposed: the placebos below are replaced by every donor tile run through the identical pipeline (Amendment 5, item 9).] Spatial placebos: pseudo-targets are seven-cell neighborhoods centered on eligible REST cells whose full ring is eligible, ~~non-overlapping,~~ built with the same aggregation and composition rules, each with its own cells removed from its donor pool. Results are reported before and after a pre-specified fit filter (pseudo-target pre-period RMSPE within three times CENTER's), with the number excluded. These are observational diagnostics; overlapping neighborhoods are not counted as independent.

Contrast: the CENTER-minus-BELISARIO difference is compared with differences between pairs of pseudo-neighborhoods separated by 4 to 6 km and matched on pre-period mean and variance, with both members removed from each other's donor pools. The joint null is that neither has an effect; rejection is not evidence of unequal effects, and the equality of two nonzero effects is not tested.

Placebo-in-time: fake opening January 2023, training calendar 2022, evaluation to November 2023, labeled as a shorter-training diagnostic that cannot rule out a December 2023 confounder.

Power is reported separately from results, with alpha, power target, assumed effect path and dependence assumptions, calibrated on holdout errors rather than training residuals. A nonsignificant estimate is reported with its interval and a discussion of which reductions remain compatible with the data; it is not read as an exclusion bound.

## 8. Order of operations

Step 1: data audit, dictionary completion, geography reconciliation, hour-bin verification, provisional pre-period fits with holdout and benchmarks, inference specification check against the actual panel dimensions, revised plan and unresolved-decisions list. No post-opening target outcome enters an estimator. Step 2: authors confirm the pending decisions, the zero-coding answer and the freeze. Step 3: Tier 1 on the frozen fits, then inference, then sensitivities, then Tier 2, committing after each. Step 4: authors read results before interpretation is written. A descriptive extension is the fallback if identification or inference cannot be supported.

## 9. Threats, stated once

Measurement: Waze penetration and detection may change with the metro itself; ~~the coverage screen and frozen weights address road coverage, not the composition of Waze users~~ [struck by Amendment 5, proposed: the coverage screen measures cumulative jam extent (provider answer 3) and is replaced; no guard against a change in the number of Waze observers exists, so results are described as Waze-reported congestion, and a jam-speed outcome and a yearly adoption check (Amendment 5, item 2) are reported beside them]. Donor contamination: within-Quito donors may carry metro effects; the estimated gap is the target effect net of weighted donor effects, and the sign of the bias is not assumed. Construction: street reopenings around San Francisco and La Alameda in 2022 and 2023 may raise the pre-period baseline; available records are used and the limitation stated if channels cannot be separated. Outages before September 2024 are a contextual limitation. Free flow affects jam detection and severity, not the primary denominator; the free-flow series by group is reported. Spillovers into RING are reported.

## 9a. Spillovers onto the comparison roads (SUTVA)

[Added by Amendment 3, 2026-09-29.] The synthetic control assumes that the Metro changed congestion only in the treated unit. Within one city, it may also change congestion in the donor cells. Three channels, with the direction each would bias the CENTER estimate:

| Channel | What happens in donor cells | Bias of the estimate |
|---|---|---|
| Citywide mode shift | Trips move from cars and buses to the Metro across the city, so donor congestion falls too | Toward zero |
| Diversion onto parallel roads | Traffic displaced from the corridor moves onto parallel roads, some of them donors, so donor congestion rises | Away from zero (a larger apparent reduction) |
| Feeder routes around stations | Buses and drop-offs concentrate near stations, raising congestion there, while some trips to stations end sooner | Either direction |

Guards, each reported with the results:

1. Corridor cells (within 1 km of a station) and RING cells (1 to 2 km) are never donors (section 2).
2. The low-exposure sensitivity uses only donors more than 4 km from any station (section 3).
3. The mean distance from the line of the synthetic control's donors, weighted by their synthetic weights, with the share of synthetic weight under 2 km, 2 to 4 km and over 4 km.
4. The drop-one refits that remove each of the five most influential donors (section 6).
5. The CORRIDOR estimate, as a check on how far any change spreads along the line.

**A citywide effect cannot be separated.** If the Metro lowered congestion everywhere, the donors carry that change and the design cannot see it. The estimate is therefore the historic center's change relative to the rest of the city, not its change relative to a Quito without the Metro.

## 10. Manuscript integration

Held until measurement and inference are settled and the exported p-value and SDID-label discrepancies in the paper's results files are reconciled. The congestion and pollution windows are aligned in presentation; May to December 2025 congestion lies beyond the paper's local PM2.5 endpoint and speaks to persistence only. Contemporaneous congestion is not added as a pollution control. Pages 11 and 15 of the manuscript, which use Belisario's nonsignificant pollution response to justify it as a donor, are revised: a nonsignificant estimate does not establish zero exposure.

## 11. Open items

[Update 2026-09-29: the provider answered the questions on absent records, monthly averaging and Waze road length (`docs/2026-09-29_provider_answers.md`; see section 1 and Amendment 3). Still open with the provider: why tc_severe_persistance_ratio exceeds 100 (Amendment 1), whether the annual coverage measure for 2023 is fixed before December, which OSM version each year's road length uses, whether "días hábiles" excludes public holidays, and the older items below.] Provider (one message): in a delivered month, does an absent all_roadtype cell-month-hour record always mean zero recorded congestion, or can it reflect insufficient coverage, suppression or a processing failure, excluding the known February to April 2025 gap and the sentinel codes; can zero be assigned to tci_osm_ratio and tci_severe_osm_ratio for absent records; if the cases are mixed, can a flag or corrected extract distinguish them; do the monthly hourly indexes average over all eligible weekdays including days with no recorded jam; does Waze road length mean mapped roads or roads with at least one recorded jam; is the annual coverage measure for 2023 fixed before December. Still pending from earlier: the February to April 2025 re-run, the triplication, the contaminated keys, the unmatched fast-road keys. Authors: precise monitor coordinates, construction records. Hour bins and the primary window are settled. Paper: conflicts P1 and P3 carried unchanged.

## Amendments

### Amendment 1, 2026-09-27 (Leonel Borja Plaza, during Step 1, before any model was fit)

Flag rule (section 1). A key whose only flag is tc_severe_persistance_ratio above 100 is missing for the severe outcomes (tci_severe_osm_ratio and the other severe measures), not for every outcome. A key with a sentinel, or with any of the six auxiliary ratios below zero, stays missing for every outcome.

Reason: severe persistence is a field already classed as contaminated, so its out-of-range values make only the severe outcomes missing. Under the original rule this condition alone removed three CENTER pre-period peak months (one cell, one morning hour each) and made every incomplete threshold-20 donor incomplete. The decision followed those missingness counts, not any fitted result.

The original rule is kept as a sensitivity and reported next to the primary. Under it, CENTER is fit on the pre-period months that remain; nothing is filled in.

Addition to the provider questions in section 11: why does tc_severe_persistance_ratio exceed 100, which its definition, (TCI / TCS) / N_obs × 100, should not allow?

Confirmed by Leonel on 2026-09-29, with the original rule kept as a sensitivity. The provider has not yet answered the question on severe persistence above 100.

### Amendment 2, 2026-09-29 (Leonel Borja Plaza, after Step 1, before any post-opening month was loaded)

Treated unit (section 2). CENTER is the historic center as delimited by an official polygon, not the seven-cell ring around the Centro monitor.

Reason: the mechanism under test runs through the historic center's urban form (narrow streets, scarce parking), so the treated unit should be the area that has that form, not a ring drawn around a monitor whose published coordinates are rounded to 0.01 degrees.

Definition:

1. **Primary unit: the wider historic center.** Sensitivities: the core (the World Heritage property, about 70 ha) and the seven-cell ring of section 2 with its Step 1 definition (equal weights).
2. **Congestion value of a polygon unit.** It is the average of the H3 cells the polygon touches, each weighted by its OSM road length inside the polygon. The weights are fixed before any fit. The fixed-composition rule of section 1 applies to every cell with positive weight.
3. **The polygons are pending Leonel's confirmation.** Candidates and a proposal are in `reports/congestion/2026-09-29_historic_center_candidates.md`. The proposal is GeoQuito's "Área Histórica Centro Histórico de Quito" for the wider area and the OpenStreetMap trace of the World Heritage property (way 1077782502) for the core. The official area figures are 70.43 ha for the core and 375.25 ha for core plus buffer zone.
4. **Road network for the weights, pending confirmation.** OSM as of 2022-01-01, drivable classes (motorway to residential, living streets and links). This follows the 2022 vintage rule of section 3; the evidence is in the same report.
5. **BELISARIO keeps its seven-cell ring for now.**

Points this creates, all pending Leonel's decision before item D runs:

- **Group precedence.** The polygon units touch cells now labeled CORRIDOR and RING. Those cells need a rule, for example that they join CENTER and leave CORRIDOR and RING.
- **Coverage screen reference cells.** The screen's range comes from the fourteen ring cells (section 3), so it must be redefined.
- **Tolerance for touching cells.** Cells whose road length inside the polygon is only a clipping artifact on a shared edge need a tolerance (proposed: at least 1 m of road inside the polygon).
- **The contrast mixes construction differences.** CENTER-minus-BELISARIO now compares a road-weighted polygon with an equal-weight seven-cell ring. The two units differ in area, weighting and number of cells, so the contrast mixes any difference in effects with differences in how the two units are built.

### Amendment 3, 2026-09-29 (Leonel Borja Plaza, after Step 1 and the provider's answers, before any post-opening month was loaded)

Decisions on the Step 1 review. Each is written into the section it changes, where it is marked.

1. **Primary donor pool: the screened pool** (section 3). The unscreened pool is a sensitivity.
   - Reason: the screen keeps donors that Waze observes the way it observes the historic center. The provider confirms that a missing record can mean no Waze users (answer 1). The screened pool also fitted the pre period better, and the holdout could not separate the two pools for CENTER.
   - Recorded with the decision (workstream B): by provider answer 3, the screen measures cumulative jam extent, so it selects on pre-period congestion extent as well as on Waze observation. Part of the screened pool's lower pre-period error in Step 1 comes with extrapolation: its CENTER fit had total negative weight -0.680 (`Output/step1_freeze/weight_statistics.csv`).
2. **Zero coding is the provider's method** (section 1). "Provisional" is dropped, and the caveat is recorded in section 1.
   - The v2 rule said that if the answer mixed true zeros with missing coverage, estimation would wait for a flag or a corrected extract. The provider's answer does mix them (no congestion, or congestion with no Waze user), so this amendment replaces that rule.
   - The data dictionary (`reports/2026-09-27_dictionary_tci_osm_ratio.md`) now records answers 2 and 3.
3. **Inference** (section 5).
   - CENTER P1 is the single confirmatory test at 5 percent, with the smallest attainable p-value (1/32) stated.
   - BELISARIO, the contrast and P2 are secondary, with no joint Holm claim.
   - Missing months in later windows are dropped, time order is kept, and the number of periods used is stated.
4. **Uninformative fits** (section 6). The December 2022 fits and the original-rule screened fits interpolate and are kept only in a labeled appendix table.
5. **Placebos are descriptive** (section 7). Pseudo-neighborhoods may overlap, each gap is scaled by its own pre-period RMSPE, and the distribution is reported. Conformal inference remains the test. Near-zero RMSPE needs a rule (pending).
6. **Amendment 1 (flag rule) is confirmed.** The provider's answer on severe persistence above 100 is still missing.
7. **Branch history is not rewritten.** The workstream branch will be squash-merged into main and never pushed.
   - Condition: the final tree holds no cell-level coverage values. The tree checked on 2026-09-29 names no cell with its coverage value.
   - It does keep the screen's range endpoints (38.9702 and 70.3876; `Output/step1_freeze/spec.json`, the freeze README and `Output/Waze/step1/panel_summary.md`). Each endpoint is the 2022 value of one target cell, left unnamed.
8. **Spillovers** get their own section (9a), with channels, bias directions, guards, and the statement that a citywide effect cannot be separated.

### Amendment 4, 2026-10-01 (Leonel Borja Plaza, on the pending points of Amendments 2 and 3, before any post-opening month was loaded)

1. **Polygons and roads.**
   - **CENTER** is GeoQuito's "Área Histórica Centro Histórico de Quito" (heritage layer `patrimonio`, layer 6, feature 41; store deliveries `2026-09-29_centro_historico_poligono` and `2026-09-29_historic_center_geography`, byte-identical copies).
   - **Road weights** come from the OSM network as of 2022-01-01, drivable classes (store delivery `2026-09-29_osm_roads_20220101`).
   - **The OSM outline of the World Heritage property** (way 1077782502) is a secondary, descriptive unit, labeled as volunteer-traced.
   - **The seven-cell monitor ring** stays as a sensitivity, with equal weights.
   - **The parish is not used.** It leaves out about a quarter of the UNESCO core and buffer (`reports/congestion/2026-09-29_historic_center_candidates.md`).
2. **Group precedence.** Every cell with at least 1 m of drivable road inside the CENTER polygon belongs to CENTER and leaves CORRIDOR and RING. The 1 m tolerance excludes edge artifacts of the clipping. A buffer is recomputed around the new CENTER: every cell that shares an edge with a CENTER cell (an H3 neighbor, grid distance 1) and is not itself in CENTER is excluded from donor pools and from placebo neighborhoods. Any donor whose status changes is listed. All seven Step 1 ring cells must be in the new CENTER.
3. **Coverage screen.** The reference set (the fourteen Step 1 ring cells) and the frozen range are kept, so the screened and unscreened pools stay as frozen, apart from any buffer exclusion under item 2. For each new CENTER cell, the report states only whether its 2022 jam-derived coverage falls below, inside or above that range.
4. **Placebo scale.** The Step 1 pseudo-neighborhoods with a full pre-period RMSPE below 0.001 did not have their own cells in their donor pool, and their outcomes are not near zero. Their fits interpolate: four through the ridge step at the smallest penalty, one through plain SCM because its path lies inside the cloud of donor paths. A floor is therefore needed. The scale is the larger of the pseudo-target's own pre-period RMSPE and CENTER's (section 7 note).
5. **Contrast.** BELISARIO is built with road weights too: summed congested metres over summed road metres across its seven cells, which is a weighted mean of the cell values with each cell's road length as weight. The OSM snapshot does not cover BELISARIO, so its weights are the provider's 2022 all_roadtype OSM length per cell (`roadlengths_quito.csv`), the denominator of its own tci_osm_ratio. The equal-weight BELISARIO is a sensitivity.
6. **Weights reporting (Amendment 3, item 1).** For each donor pool, the report gives the most negative weight, the sum of negative weights, and a plain synthetic control (non-negative weights, no ridge augmentation) next to the ridge fit. The plain synthetic control is the frozen benchmark: augsynth without augmentation and without an intercept.
7. **Backdated fit.** Using pre-period data only, a fit with June 2023 as the treatment date is the existing June to November 2023 holdout. It is reported under that heading and not fitted twice.

### Amendment 5, 2026-10-01, APPROVED as the record of what was done and when (Leonel Borja Plaza, after an outside review; approved on 2026-10-01 with Amendment 6; no post-opening month loaded)

Redesign of item D. It supersedes the estimator, donor pool, placebos and inference details of sections 3, 6 and 7 and of Amendments 3 and 4 wherever they differ. CENTER stays the GeoQuito historic-district polygon (Amendments 2 and 4).

**What had been seen when each part was decided** (referee point 3):

- Every part below was decided on 2026-10-01 after these had been seen:
  - all Step 1 pre-period results (`Output/step1_freeze/`, report of 2026-09-27);
  - all item D pre-period results at `f6b783d` (`Output/step1_amendment2/`, report of 2026-10-01): CENTER's interpolating ridge fit, the holdout gaps and their signs, the drift checks, the placebos, the donor geography and the MDEs;
  - the internal methods review of item D;
  - the three outside reviews and Leonel's assessment (`docs/external_review/`), which quote those results.
- Items 6 (the corrected rationing dates), 3 (the interval rule) and 4 (Calderón among the valleys; the low-exposure tiles), and the decision to drop the holiday check, were settled in the planning round of the same day, with the same results in view.
- No tile-level series, scale test, contest score or post-opening value had been computed or seen when any part was decided.

1. **One attempt with the data as delivered.** No new provider request for now. If the pre-period work shows that monthly data cannot sign the effect, the report says so, and finer data are sought (questions in `docs/provider_questions.md`).
2. **Outcome.**
   - The primary outcome is labeled a road-weighted index of the H3 hexagons covering the district, and described as Waze-reported congestion; fewer drivers also means fewer Waze observers.
   - Secondary outcome: a jam-speed index (avg_jam_speed_ratio, weighted by congested length), since the delivered pre-period fields are clean.
   - Adoption check: yearly increments of cumulative jam length (`waze_sum_length` in `roadlengths_quito.csv`) for 2019 to 2022 only, for CENTER and the donor tiles.
3. **Scale, decided first.**
   - Across donor tiles, regress the log of the standard deviation of calendar-adjacent monthly changes (peak index) on the log of the pre-period mean, and report the slope with its 95 percent interval.
   - Fit in proportions if the slope exceeds 0.5 or its interval includes 0.5: each unit is divided by its pre-period mean, and CENTER's counterfactual is rebuilt in index points. This rests on the measurement reason (lower Waze detection scales jams down by a share) and on consistency with the crash analysis.
   - Fit in levels only if the whole interval lies below 0.5.
   - The result is recorded and committed before any other choice is computed.
4. **Donor units.** The single cells and the coverage-range screen are replaced by tiles.
   - **Tile:** an H3 resolution-7 tile of its seven resolution-8 cells.
   - **Quality:** a tile is kept when at least four of its cells meet the saturation rule (mean of at least 20 valid delivered hour slots per cell-month over January 2022 to November 2023, amended flag rule; Phase C rule in `AGENTS.md`).
   - **Exclusion:** a tile is excluded if any of its cells belongs to CENTER, CENTER's buffer, CORRIDOR, RING (within 2 km of a station) or BELISARIO.
   - **Index:** total jam length over total road length, which is the mean of the cell indices weighted by the provider's 2022 OSM length. The fixed-composition rule applies.
   - **Main pool:** tiles in the DMQ (most cell centroids inside the GeoQuito parish layers), outside the buffer, valleys included.
   - **Neighbouring municipalities:** their tiles are a check, and join the main pool only if fewer than 20 DMQ tiles qualify.
   - **Valleys:** the zonal administrations of Tumbaco, Los Chillos and Calderón.
   - **Low-exposure sensitivity:** donor tiles whose cells all lie more than 4 km from any station.
   - **Pico y placa:** the report counts qualifying tiles inside and outside the zone, built from its official boundary streets.
5. **Estimator contest, menu fixed now.**
   - The menu:
     - (a) the default: synthetic control with an intercept, weights zero or positive and summing to one, fitted on the morning and evening peaks together;
     - (b) synthetic difference-in-differences;
     - (c) ridge-augmented synthetic control with the largest penalty within 5 percent of the best tuning error;
     - (d) difference-in-differences against the tile mean.
   - Scoring is by rolling-origin forecasts:
     - each fit is refit at cut-offs from about month 12 to month 20 of the usable months;
     - it forecasts the next three usable months;
     - squared errors are averaged over all placebo tiles, not over CENTER.
   - The default stands unless another estimator lowers that error by at least 10 percent. Ties go to the simpler estimator, in the order (d), (a), (b), (c).
   - The contest is reported in full, with each estimator's mean signed error beside its mean squared error, by horizon.
6. **Calendar and dropped months.**
   - Marked events:
     - the national strike, June 13 to 30, 2022;
     - power rationing from October 27 to about December 19, 2023, suspended then and not resumed (the crisis was declared over on February 23, 2024);
     - the state of exception with a night curfew, January 8 to April 6, 2024;
     - the power cuts of April 16 to about May 1, 2024, with work suspended and pico y placa lifted on April 18 and 19;
     - the gasoline subsidy cut of June 28, 2024, with price bands from July 12;
     - the September to December 2024 power cuts.

     Sources are in `docs/calendar_shocks.csv`.
   - June 2022 and November 2023 leave the weight fit and the permutation set. October 2023 stays (three affected days).
   - In P1, December 2023 is the only rationing month. P1 is reported with and without it.
   - In later windows, months missing for delivery reasons (February to April 2025) or under the composition rule are dropped, time order is kept, and each result states its number of periods.
   - Weekday holidays are not tested: monthly data cannot isolate them.
7. **Pre-period checks.**
   - **Pico y placa positive control:** after April 10, 2023, congestion at 20:00 should rise and at 21:00 fall inside the zone relative to outside.
   - **Valley checks:** rolling forecasts from in-zone to valley tiles and back, and no response at 20:00 after April 2023. The valleys stay if their forecast errors fall within the in-zone range.
   - **CENTER's errors:** whether CENTER's holdout errors lie within the placebo tiles' errors for the same months.
   - **Drift on the new scale:** whether the drift survives the change of scale.
8. **Inference and decision rules.**
   - **CWZ test:** Chernozhukov, Wüthrich and Zhu, with the absolute value of the average P1 residual as the statistic and circular shifts. The floor is 1/30, with 21 pre-period months and 9 P1 months.
   - **Rank and intervals:** CENTER's rank among all placebo tiles, each gap scaled by that tile's out-of-sample forecast error, and the Cattaneo, Feng and Titiunik prediction intervals. If the scpi package cannot be installed before the freeze, the fallback is conformal intervals from test inversion with augsynth.
   - **Size condition:** the CWZ p-value counts only if placebo tiles reject at 5 percent in no more than 10 percent of pseudo-openings.
   - **Anchored estimate:** reported beside the main estimate. Weights are fitted on January 2022 to May 2023, and the mean June to October 2023 gap is subtracted. The report also gives the multiple of the pre-opening drift needed to flip the sign.
   - **Direction rule, word for word:** "A direction is claimed only if the main and anchored estimates share a sign, the multiple of the pre-opening drift needed to flip that sign exceeds one, and the ring estimates shrink with distance from the center."
9. **Placebos.** Every donor tile runs through the identical pipeline, with its own area kept out of its donors.
10. **Rings.** Mutually exclusive rings by distance to the nearest station:
    - CENTER and BELISARIO;
    - the corridor tier (within 1 km);
    - 1 to 2 km, the buffer's edge;
    - the donors beyond.

    Each ring is tiled and split into north, centre and south, and estimated against the same donors with the same estimator.
11. **BELISARIO** keeps the provider's 2022 road lengths. A check confirms whether the monitor's street address falls in the stored seed cell. If not, the ring is rebuilt and the change is reported.
12. **Contrast.** CENTER minus BELISARIO is descriptive unless both units are built the same way.

### Amendment 6, 2026-10-01: STOP before any post-opening month (Leonel Borja Plaza)

**Decision.** The congestion analysis stops here, applying the stop rule set on 2026-10-01 (Amendment 5, item 1). No month from December 2023 on is loaded, and the referee's four further computations are not run.

**Reasons** (Leonel's, recorded at the time):

- **The measure.** The measure named on 1 October, nine-month placebo forecast errors on the 22 tiles, puts the smallest signable fall at 0.92 of CENTER's level (`Output/redesign/mde_empirical.csv`).
- **The plausible range is far below it.** Plausible effects of one metro line on central congestion are well under 20 percent: Gu, Jiang, Zhang and Zou (2021) find about 4 percent faster rush-hour speeds near new subway lines. The caveats on the 0.92 measure are right, but the corrections they imply are far smaller than the gap.
- **CENTER's own record agrees.** It fell 9.3 percent below its forecast in June to October 2023, before the opening, and 13 of 22 tiles missed by as much.
- **Both known biases point toward a fake fall,** the direction the hypothesis hopes for: that drift, and the over-prediction of high-level units.
- *Analyst's notes (claims audit, 2026-10-01), left to Leonel:* the 9.3 percent is a share of CENTER's fit-window mean; against the forecast itself it is 7.9 percent. The 13 of 22 counts misses in either direction; 7 of 22 fell at least as far. The over-prediction of high-level units is inferred, not measured (stop report).
- **Why stop now.** Choosing a criterion after seeing 0.92 would weaken any result. Stopping before any post-opening month keeps a later analysis with finer data a clean test.

**The analyst's caveats on the 0.92 measure,** recorded with the decision:

- It is not the MDE of the confirmatory CWZ test, of the scaled placebo rank or of the direction rule.
- Its critical value sits between the third- and second-largest tile errors.
- It comes from tiles of at most 7 cells and lower levels than CENTER's 15 cells.
- It is one calendar draw.

**Decisions of 2026-10-01 on the open points:**

1. **The pico y placa zone** is approved as a record for a restart. Its south-east gap is closed by a straight segment from the eastern end of Av. Morán Valverde to the nearest point of Av. Simón Bolívar. That segment is **our assumption**, not part of the official text. With it, the smallest buffer tried that closes the traced ring is 250 m (25 to 150 m stay open; 200 m was not tried; `Output/redesign/zone_summary.csv`, `Output/redesign/zone_buffer_trace.csv`). The valley check is not run.
2. **The valley check, when it runs,** uses the 10 district tiles outside the valleys and is reported as a weak check. The floor of 20 tiles applies to the main pool only. Neighbouring-municipality tiles are not added, since the check exists to remove donors outside the zone.
3. **The CWZ size check failed narrowly:** 3 of 22 placebo tiles rejected at the T = 21 opening (13.6 percent), and 1 of 22 at T = 20. The pooled 4 of 44 does not count, because pooling was chosen after the results.
4. **The confirmatory test** is deferred to a restart, since finer data would change its form.
5. **The direction rule** is deferred too. One principle is fixed for a restart: the rule is signed, as in the road safety module. A fall is described only if it lies below zero and below every fake effect from the pre-period. A rise is described only if it lies above zero and above every one. Here the known biases point down, so they bind on a fall.
6. **Scale:** proportions stay, by the rule fixed before the test.
7. **Amendment 5** is approved as the record of what was done and when.

**Kept as is:** the BELISARIO ring rebuilt around the Colegio San Gabriel cell (8866d338c9fffff).

**Diagnostics for a restart.** Four diagnostics were run on pre-period data only (`Scripts/Congestion/45_restart_diagnostics.R`, `Output/restart_diagnostics/`), with the default synthetic control and the 22 tiles (diagnostics 1, 2 and 4) and the approved zone (diagnostic 3, which compares cell averages and uses no model). Their only purpose is to say what a restart needs; they reopen nothing. Results and implications are in `reports/congestion/2026-10-01_stop_report.md`.

**Left open for a restart:**

- the confirmatory test (decision 4);
- the direction rule (decision 5);
- the referee's four computations: CWZ power at CENTER, the scaled-rank MDE, the false-direction rate, and the MDE without the two largest tiles;
- the valley check.

Provider requests are listed in `docs/provider_questions.md`.
