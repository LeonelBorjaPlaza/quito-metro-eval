# Road safety design decisions from Leonel (workstream C)

Record of Leonel's instructions in the Claude Code session of workstream C, so that the plan and report can cite them. Paraphrased; the wording of the instructions is kept where it matters.

## 2026-09-25 (approval of the Step 1 plan, with changes)

- **Boundary:** official INEC or CONALI parish boundaries first, the Quito municipal geoportal second, GADM only if neither works; fetched to scratch, added to the store by Leonel. `flag_outside_district` stays NA until then.
- **Corridor:** 500 m of the line primary, 1 km sensitivity.
- **Windows:** P1 December 2023 to August 2024; P2 January 2025 to August 2026 primary (power is the binding constraint for crashes), calendar 2025 as a sensitivity aligned with congestion.
- **Comparison pool (later corrected, see below):** urban parishes only, excluding the rural valleys unless the pre-period screen shows they match; donors crossed by the Trolebús or Ecovía corridors flagged, MDE with and without them.
- **Exposure:** list as an open question whether Waze congestion could measure traffic volume; do not use it yet.

Later on 2026-09-25: the GeoQuito parish layer and the OSM BRT routes were added to the store; licence of GeoQuito "not confirmed" (Leonel checks the terms himself); OSM under ODbL with the credit "© OpenStreetMap contributors"; the polygon-based power study to be re-run.

## 2026-09-27 (correction of the comparison pool)

- The exclusion of the valley parishes (Cumbayá, Tumbaco, Los Chillos parishes such as Conocoto and Alangasí, Calderón and similar) "was wrong. They are the intended comparison areas, as my original data request to the AMT said."
- **Rules for the comparison pool (pool B):**
  1. Units: parishes, urban and rural alike, entirely beyond 2 km of the line; keep the volume screen and the BRT rules: Trolebús- and Ecovía-crossed parishes excluded in the primary pool, Guamaní counted as crossed, Central Norte flagged for a sensitivity.
  2. No urban or rural exclusion; the pre-period fit decides the weights.
  3. Report how many parishes each filter removes and the resulting donor count.
  4. Diagnostic only: the share of each donor's pre-period crashes on fast roads (Interoceánica, Simón Bolívar, Ruta Viva, Panamericana and similar, from PRINCIPAL/SECUNDARIA), compared with the treated catchments; no exclusion on it.
- **Power table:** pre-period only, **January 2022 start primary, 2021 sensitivity**, for injury or fatal crashes and all crashes: donors available, pre-period fake effect, conformal size check at 5 and 10 percent, and MDE, next to the previous O1 and O2.
- Update plan sections 10 and 13 and the report, run the methods-referee and claims-auditor on the updated versions, commit and stop. No post-opening outcomes.

## 2026-09-27, later (pool B not approved; three candidate designs)

- Not approving yet: with pool B the MDE for injury or fatal crashes (about a 50 percent fall) "is too large to be informative".
- Add three candidates to the same power table (pre-period only, January 2022 start, 1 km catchments, P1; injury or fatal and all crashes; fake effect, size check, MDE): (1) an urban-street outcome, counting only crashes that do not name a fast road (same list as the diagnostic), in treated areas and donors alike, with the crashes removed reported for each; (2) composite donors, merging contiguous parishes that fail the volume screen into composites that pass it, with the merging rule written before running (contiguity, beyond 2 km, BRT rules, no look at outcomes); (3) a gradient design, crash counts by distance band around stations, with inference from placebo corridors along other major avenues (rule written before running), reporting the placebos available and the MDE. Also the combinations 1+2 and 1+3.
- Add pool B's donor weights and pre-period fit. Use every feasible fake opening in the pre-period for the size check, not three.
- Then the verifier on the final commit, and the methods-referee and claims-auditor on the updated plan and report; commit and stop. No post-opening outcomes.
- Approval of the plan for this round, with additions: (a) the choice rule written into plan section 13 before any table is read; (b) for the gradient design, conformal inference over time on the metro's own gradient series (inner 0 to 1 km minus outer 1 to 2 km), reported next to the placebo-corridor rank route with P and the floor 1/(P + 1); (c) an urban-street variant that also removes Av. Mariscal Sucre, as a sensitivity row. Fifteen fake placements, the composite rule and the placebo-avenue rule as proposed.

## 2026-10-01 (road layer)

- The congestion module's 2022 OSM layer (`congestion/raw/2026-09-29_osm_roads_20220101/`) covers only a central box (41 km², 7 of 15 stations, no pool B donor, 0.13 km² beyond 4 km of the line), so it serves neither the placebo corridors nor a check of the fast-road name flag.
- Leonel agreed to a district-wide layer instead: OpenStreetMap as of 2022-01-01, motorway, trunk, primary and secondary roads with their links, over the district's bounding box. It is to be named `osm_major_roads_20220101_dmq`, so it cannot be confused with the congestion layer, and is to be used for the placebo corridors and for checking the name flag, including the Conocoto "MARISCAL SUCRE" issue.
- It replaces the 2026 snapshot fetched on 2026-09-27, which is dropped. If Overpass timed out on the full box, the box was to be split into tiles and the provenance note was to say so; it did not need to be.

## 2026-10-01 (placebo corridors and the fast-road flag)

- Leonel asked, in this order:
  - write the placebo-corridor selection rule into the plan before any run (road classes, 4 km from the line, "the same 500 m corridor width as the Metro corridor", minimum length, how corridors are cut and counted), commit it, and list the corridors with names and lengths but no crash counts;
  - run 08 and 07 for the placebo rows, pre-period only;
  - check the fast-road name flag against the road geometry, parish by parish, including Conocoto, and propose a fix without changing the outcome definition until he approves;
  - apply the fixed choice rule to the complete table;
  - then code review, verifier, commit, methods referee, and stop.
- The lead kept the approved bands (within 1 km and 1 to 2 km of each pseudo-station, the same definition as the metro's 1 km catchments) instead of a 500 m strip, flagged this before implementing, and listed the strip version as an option (plan section 4).

## 2026-10-01, later (change of course: plan amendment 1)

Leonel's change of course, before any estimate. It replaces his earlier reply on report items 16 to 18; pre-period data only until he approves the amendment.

1. **Framing.** The analysis goes into the air quality paper as supporting evidence, with little power stated from the start. Designs are no longer chosen by power: one main specification is fixed now, every other specification is listed in advance, and all are reported, each with its estimate, its interval, and the largest fall and rise it rules out.
2. **Every crash has a role.** Every crash is kept, with a stated role: outcome, comparator or spillover zone. Dropping anything needs a stated reason. The distant parishes set aside for lack of power come back as comparators.
3. **Spillovers.** Nearby areas get their own effects against the distant parishes, including the valleys: the treated area, the 1 to 2 km ring, and fast roads near the line, split by city streets and fast roads where counts allow. Each comparator's spillover risk and bias direction is to be stated.
4. **Fast roads as comparators.** Fast-road crashes near the line are compared with those on the distant placebo highways, and city streets with fast roads within the same area, with the caveat that fast roads near the line (such as Av. Mariscal Sucre) may lose traffic to the metro too.
5. **Main specification.** All injury or fatal crashes in the treated area against the distant parishes, with DID weights and conformal inference.
6. **Historic center.** A unit for GeoQuito's Área Histórica (`congestion/raw/2026-09-29_centro_historico_poligono/`); all crashes, split by severity.
7. **Damage-only drift.** Whether it is shared by treated and comparison areas or specific to the treated areas. Leonel is asking the AMT about recording practice.
8. **Earlier items.**
   - The fast-road fix is approved, applied to all areas and months, and used for the split between city streets and fast roads; the pre-period flag changes are to be reported in treated and comparison areas.
   - The two ring checks are to be run.
   - The 500 m strips are dropped, with the reason recorded.
   - Leonel's wording on the size check: "State plainly that the size check can hardly fail with only 15 fake openings."
9. **Principle.** Comparators are judged by their trends and exposure, not by their levels. The scale is fixed in advance and proportional (Roth and Sant'Anna 2023), keeping conformal inference or the closest alternative, with raw counts as a check. Pre-period trends against the treated area are shown with event-study leads and bands for every comparator group and the historic center, stating how little 23 months can detect.

The amendment is to be written up, reviewed by the code reviewer and the methods referee, committed, and then work stops for Leonel's approval before any estimate.

## 2026-10-01, later still (decisions on amendment 1, section 12)

Pre-period data only until Leonel approves the final version.
1. **Comparator: pooled, as proposed.** Correct the "DID weights" label. Equal weights and leave-one-parish-out stay as sensitivities, and the version without Calderón is reported explicitly.
2. **Counterfactual: the pre-period drift is assumed to have ended.** The plan states the bias direction: the central drift runs upward, so if it continues, the estimate is biased toward an increase. A sensitivity with the drift continuing, carrying the drift's own uncertainty, follows the spirit of Rambachan and Roth (2023) and is shown next to the forward fake effects.
3. **The full specification list is approved as pre-registered and reported in an appendix.** A headline set of eight for the paper's table, each with its reason:
   - the main specification;
   - the treated area against the 1 to 2 km ring;
   - the ring's own effect against the distant parishes;
   - fast roads near the line against the distant placebo highways;
   - all crashes;
   - the historic center;
   - the pooled comparator without Calderón;
   - the Poisson version.
4. **Confirmatory test.** The null is no average change in P1. The statistic is the absolute value of the mean of the nine monthly gaps on the proportional scale, with circular shifts and the floor stated. The default mean absolute residual tests a different question.
5. **Direction rule.**
   - Every estimate is reported with its interval and the largest fall and rise it rules out.
   - A direction is described only if the main estimate and the continued-drift estimate share a sign, and the treated area's estimate exceeds the ring's and the in-between zone's (fading with distance).
6. **Calendar of national shocks, as given by Leonel:**
   - strike, 13 to 30 June 2022;
   - power rationing from 27 October 2023 (about four hours a day between 07:00 and 18:00, suspended at times), declared over on 23 February 2024;
   - state of exception with a night curfew, 8 January to 6 April 2024 (23:00 to 05:00 at first, later varying by risk level);
   - power cuts from 16 April to about 1 May 2024, with work suspended and pico y placa lifted on 18 and 19 April;
   - gasoline subsidy cut on 28 June 2024, with price bands from 12 July.

   How they are handled:
   - they are marked in the series;
   - June 2022 and November 2023 are left out of the permutation set and the fake openings (floor 1/30);
   - P1 is reported with and without December 2023;
   - one sensitivity leaves out crashes between 23:00 and 05:00 in every month, and one leaves out April and May 2024;
   - the September to December 2024 power cuts stay dropped.
7. **Damage-only crashes stay a secondary outcome,** with the caveat that part of their drift is specific to the treated area with the 2021 start. Leonel is asking the AMT about recording practice.
8. **The effect-size benchmark** will come from Leonel separately; it does not change the design.

Then: methods referee on the revised amendment, verifier, claims auditor, commit, and stop for final approval. Nothing after November 2023 until then.

## 2026-10-01, approval for P1

Leonel approved amendment 1 for P1, with these decisions and conditions:
- **Drift rule, signed:** "A fall passes only if the estimate lies below zero and below every forward fake effect. A rise passes only if it lies above zero and above every forward fake effect." With the one forward opening at +9.6 percent, any fall passes and a rise must exceed +9.6 percent; the report says the rule rests on a single forward opening.
- **Direction rule:** "exceeds" means further in the direction of the claimed change than the ring's estimate (below it for a fall, above it for a rise). The signs may differ, and absolute values are not compared across signs. When the ring moves the other way, it is described as a spillover, and the combined treated-and-ring estimate is reported.
- **Conditions before any estimate:**
  1. A direction is described only if its sign also holds without night crashes and without April and May 2024.
  2. When no direction is described, the report names the check that stopped it.
  3. A specification without Calderón (E6, already present).
  4. The size check is not changed to make it pass; it is reported next to every p-value, saying that one rejection fewer (1 of 13) would have passed.
  5. The last derivable small count is closed by rounding or merging.
  6. One more methods-referee pass on the final definitions; gaps are fixed unless a fix would change a decision.
- **Freeze and record:**
  - commit the frozen plan;
  - squash-merge the branch into main and push main (never the branch), after checking main for derivable small counts;
  - if main's working tree is not clean or the merge conflicts, give Leonel the exact commands;
  - afterwards, merge main back into the branch.
- **Estimation:** load December 2023 to August 2024 only, run the pre-registered P1 specifications, then the code review, verifier, methods referee and claims auditor, and stop with the report. P2 is not covered.
- **Not blocking P1:** the AMT answer (needed before writing up) and the literature benchmark (only for the power paragraph).

## 2026-10-04 (recording the freeze)

- **Merge scope (Leonel).** The pre-merge scan (`reports/verification/2026-10-01_road_safety_premerge_scan.md`) found counts of 1 to 4 in older Step 1 and audit tables, so only the frozen plan goes to main now: `road_safety/docs/analysis_plan.md`, `road_safety/docs/analysis_plan_amendment_1.md` and this record, on top of main at `5f136ec`.
  - Those three files were scanned for counts of 1 to 4 and for numbers that would let one be derived. Two passages were fixed: the number of crashes outside every parish polygon (now "fewer than 5, withheld") and the size of small exact-point clusters.
  - Cleaning the Step 1 and audit tables is a separate task, after P1 and before any full merge of the branch.
  - No tag or other ref pointing into the branch is pushed, and the branch itself is never pushed.
- **New P1 outputs** follow the small-count rule from the start (amendment section 4.6, condition 7).
- **What had been seen when the plan was frozen.**
  - **Outcomes.** No crash outcome after November 2023 had been loaded, described by area or estimated.
  - **Post-opening crash data seen at all:** the district-wide completeness tables allowed for December 2023 onward (records per year, missing fields, category lists, and recording-format flags by month as shares; Step 1 report and data audit), and nothing by area.
  - **Two post-opening counts derivable by subtraction.** The pre-merge scan found that the committed audit tables allow two district-wide counts for December 2023, the first month after the opening, to be worked out by subtraction. Their values are withheld:
    1. **Records timed exactly 00:00 in December 2023**: the 2023 yearly count of `hora_0000` in audit table T05 minus the January to November 2023 monthly counts in T03. This is a time-recording artefact (midnight, or a missing time entered as 00:00), counted district-wide.
    2. **Records with coordinates more than 40 km from the centre of Quito in December 2023**: the 2021 to 2023 counts of `farther_than_40km_from_centre` in T23 minus the pre-period total in T26. This is a coordinate-quality check. Such points lie in the outermost rural parishes or are coordinate errors, far from the metro line, the 1 km catchments and the ring.
  - **What they reveal.** Neither is an outcome by area for any unit of the design. Neither says anything about crashes near the metro, and neither separates injury from damage-only crashes. The second concerns a protected December 2023 subset somewhere in the far periphery, without parish or severity. The lead had not computed either difference before the scan; the verifier computed them as flags only and printed no value.
- **Code at the freeze.** The commit on branch `worktree-road-safety-plan` that holds the frozen plan and its code is given in the main commit message and in the line below. That commit is not pushed; it identifies the code state locally.
- **Freeze commit:** `f161d185859d8dcc611efab276edfefe970c1794` on branch `worktree-road-safety-plan` (frozen plan, amendment and code; local only, not pushed).
