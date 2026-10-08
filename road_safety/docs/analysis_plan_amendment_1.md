# Road safety analysis plan, amendment 1 (2026-10-01)

**APPROVED FOR P1 by Leonel Borja Plaza on 2026-10-01, with the final definitions of the drift rule and the direction rule and the conditions in section 4.6** (his written approval is recorded in `docs/correspondence/2026-09-27_road_safety_design_decisions.md`).
- **What it covers.** The approval covers P1 (December 2023 to August 2024) only; P2 needs its own proposal.
- **Frozen.** The plan is frozen as of this version; any later change is an amendment.

This amendment follows Leonel's change of course of 2026-10-01 (`docs/correspondence/2026-09-27_road_safety_design_decisions.md`). It replaces the choice rule in section 13 of `road_safety/docs/analysis_plan.md` and open decisions 16 to 18 of the Step 1 report. Where it differs from the plan, the amendment governs; the plan's other sections stand unless changed here. Every number below comes from pre-period data, January 2021 to November 2023: the approval was given before any post-opening outcome was loaded.

It was revised after code review pass 7 and the methods referee (`reports/road_safety/2026-10-01_code_review_pass7.md`, `2026-10-01_methods_referee_amendment1.md`), and again after Leonel's decisions on section 12 (2026-10-01), which settle the comparator, the counterfactual, the specification list and its headline set, the confirmatory test, a direction rule and the calendar of national shocks.

## 1. What changes, in brief

- **Framing.** The road safety analysis is supporting evidence for the air quality paper, and it says from the start that it has little power. Leonel judges effects of the size it can detect unlikely; no literature benchmark is cited yet (plan section 10).
  - **The main specification's own power** (section 4), with June 2022 and November 2023 left out: it detects a fall in injury or fatal crashes of 40 percent at the 5 percent level, both with the 13 fake placements and with the single forward opening. On the grid, 40 means a fall of between 30 and 40 percent.
  - **Two caveats.** With the 13 placements the 10 percent size check counts as failed (2 of 13 reject with no effect). The forward figure rests on one placement and 10 draws per effect size.
  - **The best designs for all crashes** reach 20 to 25 percent (`road_safety/output/power/candidates/comparison.csv`).
- **Designs are no longer chosen by power.**
  - **What is fixed.** One main specification is fixed now (section 4). Every other specification is listed now and approved as pre-registered (section 5). All are reported in an appendix, each with its estimate, its interval, and the largest fall and rise it rules out.
  - **The paper.** Its table shows a headline set of eight (section 4.5).
  - **Confirmatory and descriptive.** **Only the main specification is confirmatory** (section 4.1). The others are descriptive: with 53 of them (counting H1 once), two or three 95 percent intervals would exclude zero by chance even with no effect.
  - **Describing a direction.** A fall or a rise is described only under the direction rule (section 4.3).
  - **The choice rule** of section 13 is withdrawn.
- **Comparators are judged by their trends and their exposure to the metro, not by their levels** (section 2). No crash type is dropped for its level, road type or recording; every crash has a role (section 3).
- **Spillover zones get their own estimates** (section 5, group C): the ring 1 to 2 km from stations, the rest of the district near the line, and fast roads near the line. They are no longer clean comparators or data to drop.

## 2. Comparators: trends and exposure, not levels

In a difference-in-differences design, a comparison area can have far more or fewer crashes than the treated area, other road types, or more unrecorded crashes. None of that matters as long as the differences are stable over time, because area fixed effects absorb them. Only two things disqualify a comparator or a crash type:
- a different trend before the opening;
- exposure to the metro.

**Scale, fixed now.** Crash counts differ widely across areas. Parallel trends cannot then hold both in levels and in proportions (Roth and Sant'Anna, 2023, "When Is Parallel Trends Sensitive to Functional Form?", *Econometrica* 91(2)). The main specification is therefore proportional:
- **The scale.** Each monthly series is divided by its own mean over the training months, so the gap is a difference in percent of each area's own level. To first order this is the log scale.
- **What it absorbs.** A stable share of unrecorded crashes cancels, and so does a recording change that removes the same share everywhere.
- **It keeps conformal inference.** This is the scale of all the power work (`road_safety/code/04b_power_conformal.R`).
- **The test is not exact.** Conformal inference (Chernozhukov, Wüthrich and Zhu) is valid when the residuals are exchangeable over time, which the pre-trends of section 6 strain. Its p-values are approximate, like those of every alternative here.

**The log scale and a Poisson model** are sensitivities (F1, F2), and raw counts are a check (F3). For the Poisson model the conformal method is adapted as follows:
- fit a model with area and month fixed effects and no treatment term, on all months, to two series: the treated area and the pooled comparator (or, in a variant, the treated area and the 39 distant parishes);
- take the treated area's residuals on the log scale (log observed minus log fitted);
- permute them cyclically as in the main specification.

The treated area never has a zero month in the pre-period (observed minimum redacted; `road_safety/output/descriptives/monthly_by_treated_area.csv`), so its log residual is always defined.

## 3. Every crash and its role

Crashes are grouped by distance from the nearest station and by parish (GeoQuito polygons). Severity is injury or fatal, or damage only. Road type uses the approved, geometry-confirmed fast-road flag (section 9); Mariscal Sucre counts as a fast road for the split.

| Group | Definition | Role |
|---|---|---|
| Treated | within 1 km of a station (pooled catchments) | outcome |
| Ring | 1 to 2 km from the nearest station | spillover zone, own estimate |
| Intermediate | more than 2 km from a station, in parishes that reach within 2 km of the line | spillover zone, own estimate |
| Comparator | all 39 parishes entirely beyond 2 km of the line, valleys included, with no volume screen (the 30 set aside earlier for lack of power are back) | comparator (main) |
| Historic center | inside GeoQuito's Área Histórica (the congestion module's CENTER), 5.14 km², with San Francisco station inside and 79 percent of its area within 1 km of a station | treated sub-unit, own estimate (overlaps treated and ring) |
| Placebo highways | within 2 km of a pseudo-station of the 10 placebo corridors; fast-road crashes only when used as a comparator | comparator for fast roads near the line (overlaps comparator and intermediate) |
| Outside every parish polygon | no parish | dropped: no area to assign; counts withheld |
Sources: historical `road_safety/output/preperiod/zone_counts.csv` and `historic_center.csv`, retained locally. The crash-count column and severity counts are redacted from this release.
- **SICARIATO flag:** flagged entries remain excluded as homicide rather than road crashes; frequency withheld.
- **Secondary outcomes.** Pedestrian, motorcycle, bus and bicycle crashes remain secondary, described outcomes.

## 4. The main specification

| Element | Choice |
|---|---|
| Outcome | all injury or fatal crashes, city streets and fast roads together |
| Treated area | within 1 km of any Line 1 station, pooled |
| Comparator | the 39 distant parishes, **pooled**: their crashes summed into one comparison series |
| Weighting | **Pooled (crash-weighted)**, decided by Leonel on 2026-10-01. Each parish counts by its crashes, so parishes with a few crashes a year add little noise. This is not "DID weights" in the plan's sense (equal weights over parishes), and the plan's label is corrected here. The observed comparator shares are redacted to prevent linked reconstruction. The version without Calderón is reported explicitly (E6). Equal weights (E2) and leave-one-parish-out (I4) are sensitivities. |
| Scale | proportional (section 2) |
| Window | P1, December 2023 to August 2024, monthly |
| Pre-period | January 2022 to November 2023, with June 2022 (strike) and November 2023 (start of power rationing) left out of the panel (section 4.4) |
| Counterfactual | the pre-period drift is assumed to have ended (Leonel, 2026-10-01). As the estimator is built, this means **no drift**: P1 is compared with the gap's average level over the pre-period, not with its level in late 2023. See "Direction of the bias" below. |
| Confirmatory test | section 4.1; floor 1/30 |
| Drift rule | **signed** (Leonel, 2026-10-01). **A fall passes only if the estimate lies below zero and below every forward fake effect. A rise passes only if it lies above zero and above every forward fake effect.** With the one forward opening left at +9.6 percent, any fall passes and a rise must exceed +9.6 percent. Why signed: the pre-period evidence points to upward drift in the central areas, and upward drift can hide a fall but cannot create one. Why "below zero": "below the smallest fake effect" alone would let +5 count as a fall. **The report says that this rule rests on a single forward opening.** Beside the estimate it also shows the range of the 13 inside placements (-13.5 to +13.0), the 2021-start forward fake effects, and the continued-drift estimate (section 4.2). The rule applies to every specification, **each with its own forward fake effects** (built with its own window and months); where a specification has none (for example G5, which keeps 19 pre-period months, fewer than one forward opening needs), the report says "drift rule not assessable". **Scale:** the estimate and the fake effects are compared on the same scale, the effect on the index in percentage points of the training mean (100 × tau); the percent of the counterfactual is reported separately. |

**Direction of the bias.**
- **The evidence of drift.** In the pre-period, crashes in the central areas drift upward against the distant parishes (section 6). The main pair's own linear trend is small and within noise (+1.4 percent a year with the 2022 start; +7.1, at the edge of its band, with 2021). Its single forward fake effect is positive (+9.6) but lies within the range of the inside placements (-13.5 to +13.0). So the evidence of an upward drift comes mostly from the other central pairs.
- **If the drift continues into P1,** comparing P1 with the pre-period average sets the counterfactual too low, and **the estimate is biased toward an increase**, against the fall the metro is expected to cause.
- **If the drift ran until November 2023 and then stopped,** the estimate is biased the same way. Its late-2023 level lies above its pre-period average by roughly the trend times 11 months, from the middle of the pre-period to its end: about 1.3 points for the main pair, about 11 for the ring (+12.0 a year).
- **The continued-drift sensitivity** (section 4.2) shows how large the first bias could be.

**Its own power, pre-period**, with June 2022 and November 2023 left out (`road_safety/output/power/amendment1_main_2022_drop/` and `amendment1_main_2022_drop_forward/`; method `04b_power_conformal.R`, pool `D_distant_pooled`, option `RS_DROP_MONTHS`):
- **Fake openings.** The 21 remaining pre-period months allow 13 placements of the 9-month fake window inside the panel. They allow only one forward opening (February 2023) with the 12 training months the forward rule requires, so the forward fake effect is a single value.
- **Floors.** The simulated panels have 21 months (floor 1/21); the real P1 test has 30 (floor 1/30).

| Placements | Outcome | Fake effect, mean (range), percent | Rejections with no effect, 5 / 10 percent | MDE fall / rise at 5 percent | at 10 percent |
|---|---|---|---|---|---|
| 13, inside the panel | injury or fatal | +0.7 (-13.5 to +13.0) | 1 / 2 of 13 | 40 / > 50 | size fails |
| 1, forward (February 2023) | injury or fatal | +9.6 | 0 / 0 of 1 | 40 / 25 | 25 / 15 |
| 13, inside the panel | all crashes | -1.3 (-9.3 to +9.6) | 1 / 2 of 13 | 30 / 30 | size fails |
| 1, forward (February 2023) | all crashes | +8.8 | 0 / 0 of 1 | 40 / 10 | 20 / 5 |

The earlier runs on all 23 months (`amendment1_main_2022/`, `amendment1_main_2022_forward/`) are superseded and kept for comparison: 15 placements, 3 forward openings, forward fake effects +6.9 to +10.9 for injury or fatal crashes. With the 2021 start and all months, the main pair's 9 forward fake effects are +1.1 to +17.2, mean +12.5 (`road_safety/output/preperiod/ring_checks.csv`, treated against the distant parishes).

**Reported for every specification:**
- **Estimate:** the effect as a percentage of the counterfactual: 100 × tau / (mean treated index in P1 − tau), where tau is the effect on the index scale (plan section 9).
- **Interval:** the 90 and 95 percent sets of constant proportional effects that the test of section 4.1 (same statistic, same reference distribution) does not reject (test inversion). A set may be unbounded.
- **What it rules out:** "rules out falls larger than X percent and rises larger than Y percent". Where a set has no lower or upper bound, the report says "rules out no fall" or "rules out no rise"; a missing bound is correct, not an error (root rule 6).
- **p-value:** its floor stated beside it, and the size check reported next to every p-value: the specification's own where one was run, otherwise "size not checked" (condition 4, section 4.6).
- **Context:** the forward fake effect and the continued-drift estimate shown beside it.

### 4.1 The confirmatory test

- **Null.** The null of interest is **no average change in P1**. Strictly, the conformal test's null is the sharp null of no effect in any P1 month, under which the residuals are exchangeable over time. The statistic below aims the test's power at a change in the average, which is the question.
- **Statistic.** The absolute value of the mean of the nine P1 monthly gaps on the proportional scale. Each gap is the treated index minus the comparator index, with residuals taken from the model fitted under the null on all months (the intercept absorbs the gap's overall level).
- **Reference distribution.** The same statistic under every circular shift of the 30-month residual sequence: 21 pre-period months (June 2022 and November 2023 left out) plus 9 P1 months. The p-value is the share of shifts at least as extreme, and the smallest attainable p-value is **1/30**.
- **Level.** The test rejects at the **5 percent** level, the level of the power work and of the MDEs quoted in section 1; with the floor of 1/30 that needs the P1 statistic to rank first among the 30 circular shifts.
- **Not the default.** The default statistic of Chernozhukov, Wüthrich and Zhu, the mean absolute residual, tests whether P1 residuals are unusually large in either direction month by month, a different question. It stays a sensitivity (I6).

### 4.2 The continued-drift estimate (in the spirit of Rambachan and Roth, 2023)

- **The idea.** The main estimate assumes the drift ended. This sensitivity assumes instead that the gap keeps the linear trend it had in the pre-period, and it carries that trend's own uncertainty.
- **Algorithm**, step by step:
  1. **Time.** Months are numbered by calendar position. The two left-out months keep their places, so the trend's extrapolation to P1 is not shortened. (The power code renumbers kept months; the estimation code for this sensitivity must not.)
  2. **Slope estimate.** b̂ is the least-squares slope of the gap over the 21 kept pre-period months.
  3. **Slope set.** The 95 percent interval of b comes from a moving-block bootstrap of the residuals around that trend (blocks of 3 months, 2,000 draws), as in section 6.
  4. **Testing an effect.** For a slope b and a proportional effect δ: subtract b × (t minus the pre-period's mean month) from the gap in all 30 months. The slope is held fixed, not refitted. Impose δ on P1, fit the null model (an intercept) on all 30 months, and compute the conformal p-value of section 4.1.
  5. **Point estimate.** The effect at b̂.
  6. **Interval.** The union, over every b in the 95 percent slope set, of the 95 percent conformal sets for δ. By the Bonferroni inequality its coverage is **at least 90 percent**, and it is labelled so.
- **Why not 95 percent.** A combination with at least 95 percent coverage would need 97.5 percent conformal sets, which the floor of 1/30 cannot give (it exceeds 0.025).
- **The link to Rambachan and Roth.** Linear extrapolation is their smoothness class with M = 0 (no change in the slope after the opening). Taking the union over the slope's own uncertainty is in their spirit. This is not their relative-magnitudes approach.
- **Scale of the effect.** With all 23 months, the main pair's trend is +1.4 percent of the mean a year, with a noise band of -12.8 to +12.9 (`road_safety/output/preperiod/pretrend_summary.csv`). The trend's 90 percent interval is therefore roughly -11.5 to +14.2 percent a year. Carried about 16 months to the middle of P1, that shifts the counterfactual by up to about 15 to 19 percent either way, so the continued-drift interval will be wide.
- **Where it is shown.** It is reported next to the main estimate and its forward fake effect, as J1.

### 4.3 The direction rule

Every estimate is reported with its interval and the largest fall and rise it rules out. **The direction rule and the wording table below govern the main specification (A1) only.** Every other specification is reported with its estimate, its interval, what it rules out and the drift rule, without directional wording.

**For A1, a direction (a fall or a rise) is described only if all of these hold:**
1. the main estimate and the continued-drift estimate (section 4.2) have the same sign;
2. the treated area's estimate **exceeds** the ring's (C1) and the in-between zone's (C6);
3. the sign holds also without night crashes (J2, crashes between 23:00 and 05:00 left out) and without April and May 2024 (J3). The curfew and the April power cuts reduced trips, probably most in busy central areas, so they could fake a fall (Leonel, 2026-10-01).

**What "exceeds" means** (Leonel, 2026-10-01):
- **The definition.** "Exceeds" means further in the direction of the claimed change than the ring's estimate: below it for a fall, above it for a rise.
- **Signs and absolute values.** The two signs may differ, and absolute values are not compared across signs.
- **What stops the reading.** A shock to all of central Quito, or to the distant parishes, moves the treated area and the ring the same way, so only a ring change in the same direction and at least as large stops it.
- **The in-between zone** is read the same way.
- **When the ring moves the other way,** meaning its estimate has the opposite sign to the treated area's (an estimate of exactly zero does not count), it is described as a spillover in its own right. The combined estimate for the treated area and the ring together (C12) is reported, so a reader can see whether crashes fell or moved.

**When no direction is described,** the report names **every** check that failed:
- condition 1: the continued-drift estimate has the other sign;
- condition 2: the ring's or the in-between zone's estimate, named, is as far or further in the same direction;
- condition 3: J2 or J3, named, has the other sign;
- the drift rule: the estimate does not lie beyond zero and beyond every forward fake effect in its direction.

It then gives the estimate with its interval.

Caveats:
- **Spillover pre-trends.** The ring and the in-between zone have their own upward pre-trends against the distant parishes (+12.0 and +18.6 percent a year for injury or fatal crashes, section 6). Those tilt their estimates upward, which makes the condition easier to meet for a fall in the treated area and harder for a rise.
- **Condition 1 has little bite for the main pair**, whose own trend is +1.4 percent a year: the continued-drift estimate will differ from the main estimate by about 2 points.
- **It is not a test.** The rule describes a direction.

**How the paper words the result:**

| Confirmatory test (4.1), 5 percent level | Drift rule | Direction rule (4.3) | Wording |
|---|---|---|---|
| rejects | passes | met (all three conditions) | "a fall (or rise) of X percent, interval [a, b]" |
| rejects | passes | not met | "a change of X percent, interval [a, b], with no clear direction: [the check that stopped it]" |
| rejects | does not pass | either | "a change of X percent that cannot be told apart from the pre-period drift (a rule resting on one forward opening)" |
| does not reject | either | either | "no detectable change; the interval rules out falls larger than a and rises larger than b" (or "rules out no fall" / "rules out no rise" where the set is unbounded) |

Every line also reports the size check next to the p-value (section 4.6, condition 4). The ring's own estimate and, when it moves the other way, the combined treated-and-ring estimate (C12) are reported beside it.

### 4.4 The calendar of national shocks

As given by Leonel on 2026-10-01 (`docs/correspondence/2026-09-27_road_safety_design_decisions.md`):

| Shock | Dates | Months touched | Treatment |
|---|---|---|---|
| Strike | 13 to 30 June 2022 | June 2022 (pre-period) | left out of the panel, the permutation set and the fake openings |
| Power rationing, about four hours a day between 07:00 and 18:00, suspended at times | 27 October 2023 to 23 February 2024 | late October and November 2023 (pre); December 2023 to February 2024 (P1) | November 2023 left out like June 2022; P1 reported with and without December 2023 (G4) |
| State of exception with a night curfew (23:00 to 05:00 at first, later varying by risk level) | 8 January to 6 April 2024 | January to April 2024 (P1) | sensitivity without crashes between 23:00 and 05:00 in every month (J2) |
| Power cuts, work suspended, pico y placa lifted on 18 and 19 April | 16 April to about 1 May 2024 | April and May 2024 (P1) | sensitivity without April and May 2024 (J3) |
| Gasoline subsidy cut, price bands from 12 July | from 28 June 2024 | July and August 2024 (P1) | marked |
| Power cuts | September to December 2024 | between P1 and P2 | dropped, as planned |

- **Marking.** Every series figure marks these dates.
- **Common shocks.** Because the shocks are national, the comparison removes their common part; what remains is any difference in how they hit the centre and the periphery.
- **An asymmetry.** The two shock months are left out of the pre-period, but P1 keeps its rationing, curfew and power-cut months. The reference distribution is therefore cleaner than the window it is compared with. If those shocks hit the centre and the periphery differently, the test may reject too often. K1 (the confirmatory test with both months kept, floor 1/32) checks this, together with J2 and J3.
- **The pre-trend checks** of section 6 use all 23 months, and their quarterly leads include the two left-out months. The quarter June to August 2022 contains the strike, and the reference quarter September to November 2023 contains the start of rationing; the leads are read with that in mind.

### 4.5 The headline set for the paper (eight specifications)

All specifications of section 5 are pre-registered and reported in full in an appendix (Leonel, 2026-10-01). The paper's table shows these eight:

| # | Specification | Why it is in the table |
|---|---|---|
| 1 | Main specification (A1) | the confirmatory test |
| 2 | Treated area against the 1 to 2 km ring (E5) | a nearby comparator that shares the central drift, but carries spillover and BRT risk (section 7). Pre-trend: injury or fatal -10.6 percent a year (inside its band); damage only +16.7 (outside) |
| 3 | The ring's own effect against the distant parishes (C1) | measures spillovers, and is part of the direction rule. Pre-trend +12.0 percent a year, just outside its band |
| 4 | Fast roads near the line against the distant placebo highways (C11; injury or fatal fast-road crashes, all crashes in the appendix) | the fast-road comparison; those roads may lose traffic to the metro too. Pre-trend +31.6 percent a year, outside its band |
| 5 | All crashes, damage-only included (A2) | the broadest outcome; with the 2021 start, damage-only crashes have a drift partly specific to the treated area (section 10) |
| 6 | Historic center (B4, all crashes; B5 and B6 by severity in the appendix) | the low-speed core, where the congestion module also measures CENTER |
| 7 | Pooled comparator without Calderón (E6) | Observed comparator share redacted (`road_safety/output/preperiod/comparator_composition.csv`). Pre-trends without it: all inside their bands |
| 8 | Poisson version (F2) | a count model in place of the index scale |

The direction rule's in-between zone estimate (C6) and the continued-drift estimate (J1) are reported next to the table.

### 4.6 Conditions of the approval (Leonel, 2026-10-01)

1. **Direction and the 2024 shocks.** A direction is described only if its sign also holds without night crashes (J2) and without April and May 2024 (J3). This is condition 3 of the direction rule (section 4.3).
2. **Naming the check.** When no direction is described, the report names the check that stopped it (section 4.3).
3. **Calderón.** A specification without Calderón is already in the list and the headline set (E6), because of its contribution to the comparator (share redacted).
4. **The size check is not changed to make it pass.** With the 13 inside placements the main specification's 10 percent size check fails: 2 of 13 placements reject with no effect, and one rejection fewer (1 of 13) would have passed. Its failure changes nothing in the framing, because road safety makes no confirmatory claim of its own. It is reported next to every p-value: the specification's own size check where one was run, otherwise "size not checked".
5. **Small counts.** The count of crashes outside every parish polygon was closed by merging those crashes into the grouped row of `road_safety/output/spatial/pre_counts_by_parish_polygon.csv` and by rounding the totals of `road_safety/output/preperiod/fast_fix_changes.csv` to 5. The pre-merge scan (`reports/verification/2026-10-01_road_safety_premerge_scan.md`) found other counts of 1 to 4, published directly in Step 1 and audit tables by area, and a few district-wide data-quality counts. Those predate amendment 1, and how to treat them before the merge is Leonel's decision.
6. **The methods referee** reviews the final definitions once more; a gap is fixed unless the fix would change one of these decisions.
7. **Small counts in P1 outputs** (Leonel, 2026-10-04). Every new P1 output follows the small-count rule from the start: no count of 1 to 4 is published, or can be derived by subtraction from any other published table, with secondary suppression or rounding to 5 where needed. Nothing from P1 should need cleaning later. Cleaning the older Step 1 and audit tables is a separate task, after P1 and before any full merge of the branch.

## 5. Every specification, listed in advance

Each specification is reported like the main one, on P1 unless stated. Unless a line says otherwise, a specification changes one element of the main specification and keeps the rest.
- **Smallest attainable p-value:** 1/30 unless stated, with June 2022 and November 2023 left out (section 4.4). A 95 percent interval needs a floor below 0.05, and a 90 percent interval a floor below 0.10.
- **Approval and reporting.** The list is approved as pre-registered (Leonel, 2026-10-01). Every specification is reported in full in an appendix; the paper's table shows the eight of section 4.5.
- **Counts:** specifications that depend on sparse series (fast-road splits, the historic center) run only where every pre-period quarter has at least 5 crashes in both series; otherwise they are reported as "counts too small".
- **Pre-trend evidence:** section 6 shows it for the pairs listed there.

**A. Outcomes (treated area against the distant parishes)**
- A1. Injury or fatal, all roads (the main specification).
- A2. All crashes.
- A3. Damage-only crashes (secondary: part of their pre-period drift is specific to the treated area with the 2021 start, section 10; the AMT is being asked about recording practice).
- A4. Injury or fatal on city streets.
- A5. All crashes on city streets.
- A6. Damage only on city streets.
- A7. Injury or fatal on fast roads in the treated area.
- A8. All crashes on fast roads in the treated area.

**B. Treated-area variants**
- B1. 500 m catchments.
- B2. Corridor within 500 m of the line.
- B3. Corridor within 1 km of the line.
- B4. Historic center, all crashes.
- B5. Historic center, injury or fatal.
- B6. Historic center, damage only.

**C. Spillover zones, each against the distant parishes** (their own effects)
- C1 to C3. Ring 1 to 2 km: injury or fatal; all; damage only.
- C4 and C5. Ring, city streets and fast roads separately (injury or fatal).
- C6 and C7. Intermediate zone: injury or fatal; all.
- C8 and C9. Fast roads near the line (treated area and ring, fast-road crashes, Mariscal Sucre included): injury or fatal; all.
- C10. Fast roads near the line against fast-road crashes in the distant parishes.
- C11. Fast roads near the line against fast-road crashes on the placebo highways.
- C12. The treated area and the ring together (within 2 km of a station) against the distant parishes, injury or fatal. It is reported whenever the ring moves opposite to the treated area (section 4.3).

**D. Within the treated area**
- D1. Fast roads against city streets in the treated area: a relative effect on the two road types. Both are exposed (section 7).

**E. Comparator and weighting variants, for the main specification**
- E1. Pool B (the 9 screened distant parishes), pooled.
- E2. Equal weights over the distant parishes with crashes in the training months.
- E3. Synthetic-control weights over the distant parishes.
- E4. Distant parishes without those crossed by the Central Norte MetroBus (Ponceano, Cotocollao).
- E5. The gradient: treated area against the ring (inner minus outer). The ring is a spillover zone, so this is a relative estimate. The label E5 belonged to a different specification in the first draft, since dropped.
- E6. The pooled comparator without Calderón (headline 7).
- **Dropped:** comparing against all crashes more than 2 km from the line (the earlier O2), because it uses the intermediate zone, a spillover zone, as a comparator.

**F. Scale**
- F1. Log scale.
- F2. Poisson model with area and month fixed effects, with the conformal adaptation of section 2. Its interval comes from test inversion: for each proportional effect δ, the treated P1 counts are divided by (1 + δ) before the null fit. The interval is the set of δ that are not rejected.
- F3. Raw counts (level difference-in-differences), as a check.

**G. Windows and timing**
- G1. P2, January 2025 to August 2026. Conformal inference is not workable for P2 as written (plan section 5). P2 gets the point estimate and a 90 percent percentile interval from a moving-block bootstrap of pre-period gap blocks: no p-value, not size-checked, exploratory.
- G2. P2 as calendar 2025, same treatment.
- G3. Pre-period from January 2021 (floor 1/42, with the two months left out). With this start the main pair's pre-trend is at the edge of its band (+7.1 against +7.1, `pretrend_summary.csv`).
- G4. December 2023 dropped (floor 1/29): P1 with and without December 2023, both reported.
- G5. September and October 2023 also dropped, for anticipation (November 2023 is already out; floor 1/28).
- G6. Day-exact disruption window.
- G7. Months recorded in a different block dropped.
- G8. Quarterly instead of monthly (floor about 1/10, so the 95 percent interval is unbounded). Quarters are opening-aligned. A quarter containing a left-out month averages its two kept months. The power code builds no quarterly design when months are left out, so this has to be added before estimation.

**H. Flags**
- H1. The name-only fast-road flag instead of the confirmed one, for A4 to A8, C4, C5 and C8 to C11.

**I. Sensitivities carried over from plan section 11, and new ones**
- I1. Merged into J1 (the continued-drift estimate).
- I2. Replaced by the calendar of section 4.4 (J2, J3, G4).
- I3. Crashes at exact points shared by 3 or more records dropped.
- I4. Leave one distant parish out, each in turn; the range is reported.
- I5. Full window (disruption included), labelled not clean.
- I6. The default conformal statistic, mean |residual|.
- I7. Seasonality: the gap adjusted by its pre-period month-of-year means. The March to May leads of section 6 suggest a seasonal pattern.

**J. The counterfactual and the calendar (Leonel, 2026-10-01)**
- J1. Continued drift, with the drift's own uncertainty (section 4.2).
- J2. Crashes between 23:00 and 05:00 left out in every month (the 2024 night curfew). Times are recorded to the minute but heaped on 5-minute marks (audit), which does not matter at this resolution.
- J3. April and May 2024 left out (the April 2024 power cuts; floor 1/28).
- K1. The confirmatory test with June 2022 and November 2023 kept (floor 1/32), for the asymmetry of section 4.4.

## 6. Pre-period evidence: trends against the treated area

Method (`road_safety/code/10_preperiod_checks.R`):
- **Gap.** The monthly gap is the target index minus the comparator index.
- **Leads.** Event-study leads are its quarterly means relative to September to November 2023.
- **Noise bands.** They come from a moving-block bootstrap of the gap's residuals around its linear trend (blocks of 3 months, 2,000 draws). The first draft resampled the demeaned gap, which counts any real trend as noise; those bands are reported beside them.
- **Trend and detectability.** The pre-period linear trend of the gap is given in percent of the area's mean per year, with its noise band. The smallest detectable trend is the smallest trend found with 80 percent power by a two-sided 10 percent test.

**How little these checks can detect.**
- **Size of the noise.** A lead for the main pair has a 90 percent noise band of about ±25 percent (`pretrend_leads.csv`).
- **Smallest detectable trend.** For the main pair it is 20 percent of the mean per year (`pretrend_summary.csv`).
- **What an invisible trend could do.** A trend that size, carried about 16 months from the middle of the pre-period (December 2022) to the middle of P1 (April 2024), would shift the estimate by about 27 percent. That is close to the main specification's MDE, a fall of 30 to 40 percent.
- **What follows.** A pre-trend of that size is invisible here. These checks are evidence to show, not a pass or fail test.

**All 51 pairs** (the 45 of the first draft plus the 6 added for the headline set: treated area against the ring and against the comparator without Calderón). 18 lie outside their noise band (`pretrend_summary.csv`). If the pairs were independent about 5 would by chance, but they are correlated, sharing targets and comparators. Every pair outside its band:

| Pair | Trend of the gap, percent of mean per year | 90 percent noise band |
|---|---|---|
| Treated vs pool B, all crashes | +5.9 | -5.6 to +5.6 |
| Treated vs distant parishes, all crashes, 2021 start | +6.3 | -3.6 to +3.6 |
| Treated vs distant parishes, damage only, 2021 start | +5.4 | -4.2 to +4.4 |
| Treated city streets vs distant parishes, all crashes | +6.8 | -5.7 to +5.9 |
| Treated city streets vs distant parishes, damage only | +9.0 | -6.8 to +7.2 |
| Treated city streets vs pool B, all crashes | +8.4 | -4.9 to +5.0 |
| Treated city streets vs pool B, damage only | +8.8 | -8.3 to +8.6 |
| Treated city streets vs distant city streets, damage only | +14.0 | -9.9 to +10.6 |
| Ring vs distant parishes, injury or fatal | +12.0 | -11.3 to +11.2 |
| Ring vs pool B, injury or fatal | +15.8 | -12.6 to +12.3 |
| Intermediate vs distant parishes, injury or fatal | +18.6 | -14.5 to +13.3 |
| Intermediate vs distant parishes, all crashes | +12.7 | -5.2 to +5.1 |
| Intermediate vs pool B, injury or fatal | +22.4 | -15.2 to +14.3 |
| Intermediate vs pool B, all crashes | +14.3 | -5.9 to +6.4 |
| Fast roads near the line vs distant parishes, all crashes | -12.9 | -10.3 to +10.5 |
| Fast roads near the line vs distant fast roads, damage only | -29.1 | -26.6 to +25.5 |
| Fast roads near the line vs placebo-highway fast roads, injury or fatal | +31.6 | -29.3 to +29.3 |
| Treated vs ring, damage only | +16.7 | -13.5 to +12.8 |

**Reading:**
- **Upward drift in the centre.** The central areas (treated city streets, ring, intermediate zone) rise against the distant areas, mostly for all crashes and damage-only crashes, and for injury or fatal crashes in the ring and intermediate zone. The drift plan section 8 described for the earlier pools persists in this comparison, though weaker with the 2022 start.
- **The main pair** (treated area, injury or fatal, against the distant parishes) shows a small trend: +1.4 percent a year, band -12.8 to +12.9. But its forward fake effect is +9.6 percent (the single forward opening, section 4), and its leads for March to May are +20.2 in 2022 and +24.3 in 2023 (`pretrend_leads.csv`). That points to a seasonal pattern or level shifts that a linear trend misses, hence I7.
- **Fast roads near the line** fall against the distant parishes for all crashes, and rise against the placebo-highway fast roads for injury or fatal crashes (+31.6, outside its band). That pair is headline 4.
- **The headline pairs added here.** Treated against the ring: damage-only crashes outside their band (+16.7). Treated against the comparator without Calderón: all three outcomes inside their bands.
- **The spillover zones' pre-trends** will be shown next to their estimates, and they weaken E5 (the gradient against the ring).

## 7. Spillover risk of each comparator, and the direction of bias

If a comparator's crashes rise because of the metro, the estimated effect is pushed toward a fall; if they drop, toward a rise.

| Comparator | Exposure to the metro | Likely change | Bias of the estimate |
|---|---|---|---|
| Distant parishes (main) | low overall, but mixed. The northern parishes lie beyond the northern end of the line, where the El Labrador terminal draws feeders and park and ride, and could gain traffic. A third of the comparator's injury or fatal crashes are on fast roads (about 320 of 910, rounded, `zone_counts.csv`), whose commuters could switch to feeder plus metro and lose traffic | either | **ambiguous**: toward a larger fall if the terminal effect dominates, toward a smaller fall or a rise if commuter switching does |
| Pool B (E1) | as above, more weight on the northern parishes | as above | ambiguous, more likely toward a larger fall |
| Distant fast roads (C10) | commuters who could switch to the metro | a fall | toward a smaller fall or a rise |
| Placebo-highway fast roads (C11) | as distant fast roads; some lead to the city (Panamericana Norte, Guayasamín) | a fall | toward a smaller fall or a rise |
| City streets in the treated area (D1) | high: same area | same direction as fast roads, unknown size | D1 is a relative effect, not a total |
| Ring (E5) | high: feeder buses, diverted traffic, 22.4 km of Trolebús and Ecovía trunk (section 8) | with the treated area if the metro reduces traffic in both; against it if traffic diverts into the ring | **ambiguous**: toward zero in the first case, toward a larger fall in the second |

## 8. The two ring checks

**BRT trunk inside the ring** (`road_safety/output/preperiod/brt_in_ring.csv`):

| Area | Area, km² | Trolebús and Ecovía trunk, km | Central Norte, km | Trolebús and Ecovía, km per km² |
|---|---|---|---|---|
| 1 km catchments | 37.3 | 44.5 | 15.6 | 1.19 |
| Ring 1 to 2 km | 51.0 | 22.4 | 4.9 | 0.44 |

The ring has less trunk per km² than the catchments, but not little: 22.4 km of the corridors the donor rule excludes for their exposure.

**The ring's forward drift.** Forward fake effects, mean (range), percent (`road_safety/output/preperiod/ring_checks.csv`; proportional scale, 9-month fake windows; 3 openings with the 2022 start, 9 with 2021). "Pool B" uses equal weights over its 9 parishes, as in the power work; "distant parishes" is the pooled main comparator.

| Target | Outcome | Pool B (equal weights), 2022 | Pool B (equal weights), 2021 | Distant parishes (pooled), 2022 | Distant parishes (pooled), 2021 |
|---|---|---|---|---|---|
| Ring | injury or fatal | +6.7 (+5.2 to +7.5) | +16.5 (+8.3 to +24.9) | +11.4 (+9.5 to +13.6) | +13.3 (+5.1 to +20.1) |
| Ring | all crashes | -7.0 (-7.7 to -5.9) | -0.6 (-3.4 to +3.6) | -2.4 (-3.6 to -0.7) | -2.1 (-4.9 to +2.0) |
| Treated | injury or fatal | +3.6 (+0.6 to +6.6) | +15.7 (+4.4 to +22.0) | +8.3 (+6.9 to +10.9) | +12.5 (+1.1 to +17.2) |
| Treated | all crashes | +3.7 (+0.6 to +6.5) | +10.4 (+6.1 to +13.4) | +8.2 (+5.8 to +10.6) | +8.9 (+2.7 to +14.2) |

**Reading:**
- **Injury or fatal drift.** The ring is not flat: it drifts upward against both comparators, by about as much as the treated area.
- **All crashes.** It is flat or slightly falling.
- **Two comparisons mixed together.** Pool B with equal weights and the pooled distant parishes differ both in composition and in weighting, so their difference cannot be read as one or the other.

## 9. The approved fast-road fix

Applied to all areas and months in `road_safety/code/02_spatial.R`:
- **The rule.** A fast-road name match counts only when the crash lies within 1 km of an OSM way (2022 layer) carrying a fast-road name, the E35 ref, or the name Av. Oswaldo Guayasamín. A Mariscal Sucre match counts only within 1 km of a way named Av. Mariscal Sucre.
- **The flags.** The name flags are kept unchanged beside the confirmed ones, and `road_type` (city or fast) uses the confirmed flags.
- **Effect.** The historical observed flag-change table, its totals and linked margins are redacted. Source: `road_safety/output/preperiod/fast_fix_changes.csv`, held locally. The original review found a reconstruction route through the pool B row and removed that row. These disclosure edits do not change the approved geometry-confirmation rule.

## 10. Damage-only drift

Is the pre-period rise in damage-only crashes shared by treated and comparison areas, or specific to the treated area? Each area's own trend is in percent of its mean per year, with the noise band of its residuals around the trend (`road_safety/output/preperiod/damage_drift.csv`):

| Start | Area | Damage only (band) | Injury or fatal (band) | All crashes (band) |
|---|---|---|---|---|
| 2022 | Treated | +17.4 (-6.6 to +6.5) | +6.0 (-9.2 to +9.6) | +11.7 (-6.3 to +6.2) |
| 2022 | Distant parishes | +10.0 (-8.4 to +8.5) | +4.7 (-8.9 to +8.9) | +7.4 (-5.2 to +5.2) |
| 2022 | Pool B | +10.1 (-8.8 to +9.0) | +0.9 (-13.0 to +12.9) | +5.8 (-6.4 to +6.7) |
| 2021 | Treated | +8.6 (-6.3 to +6.2) | +13.4 (-5.7 to +6.0) | +10.9 (-5.3 to +5.0) |
| 2021 | Distant parishes | +3.2 (-6.6 to +6.3) | +6.3 (-7.6 to +7.7) | +4.6 (-5.8 to +5.9) |
| 2021 | Pool B | +4.9 (-7.2 to +6.7) | +5.2 (-9.7 to +10.1) | +5.0 (-7.5 to +7.4) |

**Reading:**
- **2022 start.** Damage-only crashes rise in the treated area and in both comparison areas, beyond noise in each. The comparison removes about 10 of the treated area's 17.4 points: the gap's trend is +7.4 percent a year, inside its band of -7.5 to +8.0 (`pretrend_summary.csv`).
- **2021 start.** The comparison areas' damage-only trends are within noise and the treated area's is not. The gap's trend, +5.4 against a band of -4.2 to +4.4, is beyond noise.
- **Conclusion.** Part of the damage-only drift is shared and part is specific to the treated area, mostly in 2021. The AMT's answer on recording practice is awaited.

## 11. Decisions recorded

- **The 500 m strips are dropped** (Leonel, 2026-10-01). They would test a different statistic from the main specification's: the 500 m corridor against the next 500 m. The placebo-corridor route they belong to kept at most 4 usable placebos at every placement with the 1 km bands (plan section 4). Whether strips would admit more placebos is unknown, and with designs no longer chosen by power it was not pursued.
- **The size check.** Leonel's instruction of 2026-10-01 asked to "state plainly that the size check can hardly fail with only 15 fake openings". The accurate statement is that it can hardly discriminate: with so few overlapping fake openings, it can hardly tell a correctly sized design from a mis-sized one. As a rough guide, assuming independent openings, with the main specification's 13 placements:
  - a correctly sized design shows 2 or more rejections at 10 percent, and so "fails", about 38 percent of the time;
  - a design whose true size is 15 percent passes about 40 percent of the time.

  With the 15 placements of the candidate tables the figures are about 45 percent and a third. The openings overlap, so these figures are only indicative. Passing is weak evidence and failing is not decisive, so the check is reported, never used to choose a design.
- **The choice rule** of plan section 13 is withdrawn; the candidate tables stay as descriptions of power.
- **Leonel's decisions of 2026-10-01 on section 12:**
  - the pooled comparator (section 4);
  - drift assumed to have ended, with a continued-drift sensitivity (sections 4 and 4.2);
  - the full list approved and a headline set of eight (sections 5 and 4.5);
  - the confirmatory test (section 4.1) and the direction rule (section 4.3);
  - the calendar (section 4.4);
  - damage-only crashes secondary (A3);
  - the effect-size benchmark to come separately, without changing the design.

## 12. Open points

1. **The AMT's answer** on recording practice (section 10, A3). It does not block P1; it is needed before the results are written up.
2. **The effect-size benchmark**, from Leonel. It only feeds the paper's paragraph on power.
3. **A P2 design**, to be proposed separately; this approval does not cover P2.

Release note (2026-10-07): observed crash counts, reconstructible means and linked count shares are redacted; historical model summaries and approved choices are preserved. Referenced historical outputs remain local.
