# Road safety analysis plan

**APPROVED FOR P1 on 2026-10-01 through amendment 1 (see below); P2 not approved.** Written 2026-09-25 in workstream C, Step 1, before any post-opening outcome by area was loaded, described or estimated. Revised the same day after the methods referee's report (`reports/road_safety/2026-09-25_methods_referee.md`), again after the GeoQuito parish polygons and the OSM BRT routes were added to the store (power study re-run on polygon-based donors), and on 2026-09-27 after Leonel corrected the comparison-pool rule (pool B: all parishes, urban and rural, entirely beyond 2 km) and made January 2022 the primary pre-period start (record of his decisions: `docs/correspondence/2026-09-27_road_safety_design_decisions.md`). The pool B version was then revised after the methods referee's and the claims auditor's reports (`reports/road_safety/2026-09-27_methods_referee.md`, `2026-09-27_claims_audit.md`). On 2026-09-28 three candidate designs (urban-street outcome, composite donors, gradient design) were added to the power table with 15 fake placements, after the choice rule of section 13 was written down (sections 4, 10 and 13). **APPROVED FOR P1 by Leonel Borja Plaza on 2026-10-01, through amendment 1 as finalized that day (`road_safety/docs/analysis_plan_amendment_1.md`, section 4.6 for the conditions; P2 is not covered).** Amendment 1, `road_safety/docs/analysis_plan_amendment_1.md`, changes the framing, the main specification and the full list of specifications, and withdraws the choice rule of section 13; where they differ, the amendment governs.** Label correction (Leonel, 2026-10-01): the amendment's main comparator is the 39 distant parishes **pooled** (crash-weighted), not "DID weights", which in this plan means equal weights over donor units. Until Leonel's written approval appears at the top of this file, root CLAUDE.md rule 5 applies: no post-opening outcome may be loaded by area, described by area or estimated.

This is a release-redacted copy of the historical plan. Crash counts, reconstructible means and linked count shares have been removed; approved rules, dates and model summaries remain. Historical output paths below refer to local archives excluded from this clean tree. Every retained number below comes from a file produced in Step 1 from pre-period data (January 2021 to November 2023) or from district-wide completeness tables; the path is given with each number. Choices marked **[decision]** are open for Leonel; the rest are proposals. Before this plan can be approved: Leonel's decisions in section 13, the AMT's answers on coverage and recording (section 8), a cited benchmark for plausible effect sizes (section 10), Leonel's reading of the choice rule for the candidate designs (section 13), the two pre-period checks of the gradient's ring (section 4), and, if route 2 is chosen, its runs (section 9).

## 1. Question

Did Quito Metro Line 1, in commercial service since December 1, 2023, change the number of recorded road crashes near its stations, compared with what would have happened without it?

The metro could lower crashes near stations by taking trips out of cars, buses and motorcycles, or raise them through more pedestrians around entrances, feeder buses and pick-ups, and traffic moved onto nearby streets. The test is two-sided. The design can show whether crashes changed; mechanisms are at most "consistent with" what it finds.

## 2. Data

- **Crashes.** AMT crash matrix received 2026-09-23, covering January 2021 to August 2026. Crash and vehicle totals are redacted in this release. Provenance: `docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`. The historical data audit is retained locally and excluded from this release.
- **Metro.** 15 stations and the alignment from `air_quality/data/for_maps/MetroStations.gpkg` and `MetroLine.gpkg`; line length 21.76 km (`road_safety/output/spatial/treated_area_geometry.csv`). Distances in UTM 17S (EPSG:32717).
- **Parishes.** GeoQuito `PARROQUIAS_REF` (65 parishes, 32 urban by INEC DPA code), in the store since 2026-09-25 (`docs/data_provenance/road_safety__2026-09-25_geoquito_parroquias.md`; licence not confirmed). Assign crashes by point in polygon; missing assignments and disagreements with recorded parish labels were audited. Crash counts for those diagnostics are redacted. All area units come from coordinates and polygons, never from the recorded label.
- **BRT corridors.** OpenStreetMap route relations (ODbL, "© OpenStreetMap contributors"), in the store since 2026-09-25 (`docs/data_provenance/road_safety__2026-09-25_osm_brt_routes.md`). The trunk corridors are the Trolebús (refs C1, C4, C6) and Ecovía (E1, E1R, E3, E4, E6), as Leonel asked, and, as an addition, the Central Norte MetroBus; the other 157 relations are feeder or local routes (`road_safety/output/spatial/brt_relations.csv`). The snapshot is of September 2026, after the opening.
- **Build.** `road_safety/code/01_build.R` and `02_spatial.R`; problems are flagged, never dropped. Entries flagged SICARIATO stay in the derived file and are excluded from outcome counts as homicide rather than road crashes, pending the AMT response. Their count is withheld.

## 3. The confirmatory test and the other outcomes

**One confirmatory test [decision on the window, the pool and the inference route].** The candidate designs of 2026-09-28 and the choice rule applied to them (sections 10 and 13) may replace the proposal below; until Leonel reads the rule, the proposal stands as written. Proposed: in **P1** (December 2023 to August 2024), the effect of the metro on **all recorded crashes** within **1 km of any station, pooled**, against the comparison pool Leonel approves (section 4). Two routes are on the table (section 9), and Leonel picks one before approval:
- **Route 1 (recommended): synthetic control with an intercept and conformal inference** with the level-shift statistic |mean residual| over P1. It does not depend on the number of donors, so it can reach the 5 percent level: the floor is 1/32 in the real P1 panel with the January 2022 start (1/44 with 2021), so a 5 percent rejection needs the treated statistic to rank first of 32. With pool B and the 2022 start, the pre-period runs for all crashes in the 1 km catchments detect at 5 percent a fall of 50 percent and a rise of 25 percent with synthetic-control weights (fake effect +4.5 percent), and no fall up to 50 percent and a rise of 30 percent with DID weights (fake effect +3.7) (section 10).
- **Route 2: SDID with the in-space rank test.** It can reach only p = 1/(J + 1): 1/10 = 0.10 with pool B (J = 9), exactly the 10 percent level and no lower, and 1/8 without the Central Norte-crossed donors (J = 7), above it. It has not been run for pool B, so there is no pool B evidence on its fake effects, size or power; with the earlier pools and the 2021 start its fake effects for all crashes were large (+14.4 percent with O1, +11.8 with O2) (section 10). If Leonel chooses route 2, the pool B in-space runs come before approval.
The route not chosen is reported as a secondary check. Under route 1 with pool B and the 2022 start, the 1 km catchments do not have the smallest fake effects of the three pooled units (all crashes, synthetic-control weights: 1 km +4.5 percent, 500 m catchments +0.3, corridor within 500 m -0.3), but they have the lowest MDEs at 5 percent: 50 / 25, against more than 50 / 40 for the 500 m catchments and more than 50 / 30 for the corridor (`road_safety/output/power/pool_b/comparison.csv`).

P1 is proposed over P2 because it follows the pre-period directly, avoids the 13-month hole left by P1 and the disruption, is less exposed to the post-opening recording changes found by the audit (the differently formatted blocks of October 2024 and August 2025, the vehicle misalignment of October 2025 and the change in time rounding from February 2025 fall outside it), and has a tested MDE. Leonel's reason for a long P2 (power) is real, but no MDE exists for P2 with the proposed estimator, and route 1 is not yet workable for P2 with the 2022 start (section 5). If Leonel prefers P2 as the confirmatory window, a P2 test must first be designed and checked for power; P1 would then be secondary.

**Everything else is secondary**, reported with rank p-values as diagnostics and no significance claim:

1. The other window (P2, January 2025 to August 2026, as persistence).
2. **Injury or fatal crashes** (SEVERIDAD = LESIONADOS or FALLECIDOS): least exposed to changes in the reporting of minor crashes, with volume redacted (`road_safety/output/spatial/pre_counts_by_treated_area.csv`). With O1 and O2 and the 2021 start this outcome showed almost no pre-period drift, but with pool B it drifts about as much as all crashes, and more with the 2021 start (section 8). It is the alternative confirmatory outcome (open question 3).
3. The 500 m catchments and the corridor within 500 m of the line (Leonel's primary corridor distance; see open question 3).
4. **Pedestrian crashes** (ATROPELLO), described only: no P1 design with SDID, the Poisson model or conformal inference with the level-shift statistic detects a change of less than 50 percent (section 10). With pool B and the 2022 start the 1 km catchments show fake effects of +31.2 (synthetic control) and +32.4 percent (DID) and no MDE up to 50 percent; with the 2021 start they fail the size check (`road_safety/output/power/pool_b_start2022/conformal_mde_table.csv`, `pool_b_start2021/conformal_mde_table.csv`).
5. Crashes involving motorcycles, buses or bicycles, described only; vehicle types are unreliable in October 2025.

All outcomes are counts of crashes (not victims or vehicles) per unit and month, by crash date. Fatal crashes alone are too few below the district level (audit section 6). CAUSA PROBABLE is not used (missing for December 2023 and January 2024).

## 4. Units, treated group and comparison pool

- **Treated unit (confirmatory):** crashes within 1 km of any Line 1 station, pooled (union of the 15 circles, 37.3 km², `treated_area_geometry.csv`); pre-period mean redacted (`road_safety/output/descriptives/zero_share_by_unit.csv`). It is the largest of the three pooled units. With the earlier pools it was the only one with SDID MDEs below 50 percent, and with pool B it has the lowest route 1 MDEs (section 3).
- **Treated units (secondary):** the 500 m catchments pooled (11.5 km²); the corridor within 500 m of the line (22.5 km²), with 1 km as its sensitivity (Leonel's decision 2). Associated crash counts are redacted (`pre_counts_by_treated_area.csv`, `treated_area_geometry.csv`).
- **Stations one by one** (disjoint nearest-station 1 km catchments): described only.
- **Spillover ring:** 1 to 2 km from the nearest station, estimated with the same estimator and donors as the treated unit, and never used as a control in the donor designs. The gradient candidate (below) is the one exception: it uses the ring as its control.
- **Comparison pool: pool B (Leonel, 2026-09-27).** All parishes, urban and rural alike, entirely beyond 2 km of the line (distance from the parish polygon to the line), with no urban or rural exclusion; the pre-period fit decides the donor weights. Filters, in order (`road_safety/output/power/pool_b/filters.csv`, `road_safety/code/06_pool_b.R`):

  | Step | Parishes removed | Parishes left |
  |---|---|---|
  | All parishes (GeoQuito polygons) | | 65 (32 urban) |
  | Not entirely beyond 2 km of the line | 26 | 39 (6 urban) |
  | Crossed by the Trolebús or Ecovía trunk (more than 100 m inside) | 0 | 39 |
  | Volume screen (below 3 crashes a month, or more than 20 percent of months without one) | 30 | **9 donors** (5 urban, 4 rural) |
  | Sensitivity: crossed by the Central Norte MetroBus | 2 | 7 |

  The 9 donors are Calderón, Carcelén, Comité del Pueblo, Conocoto, Cotocollao, Cumbayá, El Condado, Ponceano and Tumbaco; Ponceano and Cotocollao are the two crossed by the Central Norte MetroBus. Guamaní, counted as crossed by the Trolebús and Ecovía, is not entirely beyond 2 km, so it is not a candidate either way; the Trolebús and Ecovía step therefore removes no parish. The volume screen removes 29 of the 33 rural parishes and San Isidro del Inca; observed crash means around the threshold are redacted (`road_safety/output/power/pool_b/screen_detail.csv`). Six of the nine donors lie in the north of the city (Calderón, Carcelén, Comité del Pueblo, Cotocollao, El Condado, Ponceano), two in the eastern valley (Cumbayá, Tumbaco) and one in the Los Chillos valley to the southeast (Conocoto); none lies in the south of the city.
- **Fast-road diagnostic (no exclusion).** The historical diagnostic compared shares of pre-period crashes whose PRINCIPAL or SECUNDARIA names a fast road (Simón Bolívar, Interoceánica, Ruta Viva, Panamericana, Autopista General Rumiñahui, Manuel Córdova Galarza, E35, Intervalles; Av. Mariscal Sucre separately). All observed counts and shares are redacted to prevent linked reconstruction (`road_safety/output/power/pool_b/fast_road_shares.csv`). The flag is name-based: Interoceánica is also a main street, and Simón Bolívar and Mariscal Sucre also name local streets. It describes recorded locations, not road speed.
- **Candidate designs (Leonel, 2026-09-27; `docs/correspondence/2026-09-27_road_safety_design_decisions.md`).** Three candidates were added to shrink the MDE for injury or fatal crashes. The rules below were fixed before any run.
  - **Urban-street outcome.** Counts only crashes whose PRINCIPAL or SECUNDARIA does not name a fast road (the list of the fast-road diagnostic), in treated areas and donors alike, with the donor sets unchanged.
    - A sensitivity also drops crashes naming Av. Mariscal Sucre.
    - Observed removals in the treated area are redacted; the outcome rule above is unchanged.
    - Observed donor removals and their totals are redacted (`road_safety/output/power/candidates/urban_street_removed.csv`).
    - The Mariscal Sucre flag may also catch local streets of that name (`docs/known_issues.md`).
  - **Composite donors (pool C).** Contiguous parishes that fail the volume screen are merged into composites that pass it. The merging rule is in `road_safety/code/composites.R`:
    - candidates are parishes entirely beyond 2 km, not Trolebús- or Ecovía-crossed, sharing a boundary line;
    - each composite is seeded with the busiest parish and grown by the busiest neighbour until it passes the screen;
    - no parish that passes on its own is merged.

    It gives 5 composites: Nayón + Zámbiza (mean redacted), Alangasí + Píntag + Pifo (mean redacted), San Isidro del Inca + Llano Chico (mean redacted), Puembo + Tababela (mean redacted) and San Antonio + Pomasqui (mean redacted) (`road_safety/output/power/candidates/composites.csv`). Nineteen parishes in 5 groups could not reach the screen and were dropped: Amaguaña, La Merced and Guangopolo alone, a group of 4 in the northeast and a group of 12 in the northwest (`composites_dropped.csv`). Pool C = pool B + composites: 14 donors, 12 without the Central Norte-crossed donors (`donor_counts.csv`).
  - **Gradient design.** Compares crashes within 1 km of a station (inner) with crashes 1 to 2 km from the nearest station (outer), each as an index of its training mean, and tests the change in their gap. There are two inference routes:
    - **Conformal inference over time** on the metro's own gap series. It needs no placebo corridors. Its floor is 1/32 in the real P1 test (1/23 in the simulation).
    - **In-space rank inference against placebo corridors** along other major avenues. The selection rule below was approved on 2026-09-27 and is written out in full here on 2026-10-01, before any run on the 2022 layer (Leonel's request of 2026-10-01). It is implemented in `road_safety/code/08_gradient.R`.
      - **Road layer.** OpenStreetMap as of 1 January 2022 over the district's bounding box (delivery `osm_major_roads_20220101_dmq`, in the store since 2026-10-01; `docs/data_provenance/road_safety__2026-10-01_osm_major_roads_20220101_dmq.md`). It replaces a 2026 snapshot over a smaller box, which has been dropped.
      - **Road classes.** Named ways of class motorway, trunk or primary. Link roads and secondary roads are not used for placebos; secondary roads serve only the check of the fast-road name flag. Ways with the same normalized name (upper case, accents removed, spaces collapsed) are merged into one avenue.
      - **Distance from the line.** Every part of an avenue within 4 km of the metro line is removed, so a placebo's 0 to 2 km bands stay at least 2 km from the line, outside the metro's own 2 km zone.
      - **BRT.** Every part within 500 m of a Trolebús or Ecovía trunk is removed (the BRT rule of the donor pools). A corridor whose road comes within 500 m of the Central Norte MetroBus is kept and flagged for the sensitivity without it.
      - **Bands: the same as the treated unit's, not a 500 m strip.**
        - **Leonel's request and the deviation.** On 2026-10-01 Leonel asked for "the same 500 m corridor width as the Metro corridor". The lead kept the approved bands instead, because a placebo's statistic must be the same as the metro's, and the gradient candidate's metro statistic uses the 1 km station catchments.
        - **The bands.** Each placebo has 5 pseudo-stations spaced 1,554 m apart (the line's mean station spacing: 21.76 km over 14 gaps). Its inner band is everything within 1 km of its nearest pseudo-station; its outer band is 1 to 2 km. The metro has the same bands around its 15 stations.
        - **Limit.** This is the same definition, not a mirror: the placebos have 5 pseudo-stations against the metro's 15, and their bands hold far fewer crashes (`band_counts_pre2022.csv`). So their standardized statistics would not be exchangeable with the metro's even if enough of them were usable.
        - **The 500 m-strip option [decision].** Crashes within 500 m of the avenue against 500 m to 1 km. It tests a different metro statistic: the 500 m corridor against the next 500 m. If the exclusion and separation distances shrink with the bands (about 3 km from the line, 2 km between placebos), it is the only version that might admit urban avenues. Whether it would be testable is unknown. It has not been run.
      - **Minimum length.** A remaining piece of avenue must be at least 6,216 m long (4 gaps of 1,554 m) to hold one placebo.
      - **How corridors are cut.** Avenues are taken in alphabetical (byte) order, and each remaining piece is walked from its start vertex. A placebo is tried at every start that is a multiple of 1,554 m along the piece. It is kept only if:
        - all 5 pseudo-stations lie inside the district;
        - every pseudo-station is at least 4 km from every pseudo-station already kept, so their 2 km discs do not overlap and no crash belongs to two placebos.
      - **How they are counted.** P is the number of placebos kept. At each fake placement only placebos with crashes in the training months of both bands enter the rank, and the smallest attainable p-value, 1/(P + 1), is computed from that number. The table reports the minimum P over placements (the largest floor), and the route is "not testable" at any level below that floor.
      - **No crash data are read in choosing placebos.**
      - **What the rule selects on the 2022 layer (run 2026-10-01).** It keeps 10 placebos (`road_safety/output/power/gradient/placebo_corridors.csv`). Each placebo segment is 6.216 km between its first and last pseudo-station; none is flagged for the Central Norte.

        | Placebo | Avenue | Road piece, km | Nearest point to the line, km |
        |---|---|---|---|
        | P01 | Av. Manuel Córdova Galarza | 11.58 | 10.13 |
        | P02 | Av. Oswaldo Guayasamín | 8.72 | 9.62 |
        | P03 | Av. Panamericana Norte | 8.59 | 5.82 |
        | P04 | Corredor Alpachaca | 6.53 | 14.22 |
        | P05 | Vía Calacalí – La Independencia | 37.09 | 32.37 |
        | P06 | Vía Calacalí – La Independencia | 34.66 | 16.67 |
        | P07 | Vía Calacalí – La Independencia | 34.66 | 22.67 |
        | P08 | Vía Pifo – El Quinche | 11.65 | 19.08 |
        | P09 | Vía Pifo – Papallacta | 31.82 | 18.01 |
        | P10 | Vía Pifo – Papallacta | 31.82 | 26.54 |

        All lie on peri-urban or rural highways.
        - **Usable placebos.** Five have no pre-period crash in at least one band (`band_counts_pre2022.csv`). Some bands near the district edge (the Calacalí and Papallacta roads) may extend beyond the area the crash records cover, since only the pseudo-stations must lie inside the district.
        - **The floor.** The minimum number of usable placebos over the fake placements is 4, also in the forward subset (`gradient_rows.csv`). The floor is therefore 1/5; one placebo with very few crashes may be usable at some placements, which would give 1/6 there.
        - **Result.** **The placebo-corridor route is "not testable" at 5 or 10 percent** for every outcome.
        - **This is structural, not bad luck.** With at most 10 placebos the 5 percent level is out of reach (it needs P of at least 19), and the 10 percent level needs 9 usable placebos.
        - **Consequence.** The gradient candidate therefore rests on its conformal route alone: on the assumption that the 1 to 2 km ring is unaffected by the metro, and on its gap series being exchangeable over time. The two pre-period checks the methods referee asks for, both possible with data already in the store, are listed and not run: the ring's forward drift against pool B, and the BRT trunk length inside the ring. The order of pieces within one avenue follows the geometry library's output (GEOS; versions in `gradient_session_info.txt`); the verifier found the same 10 placebos with the pieces merged in the other order (`reports/verification/2026-10-01_road_safety_914c651.md`).
    - **What it estimates, and its main weakness** (methods referee, 2026-09-28).
      - It estimates the change in crashes within 1 km of stations relative to the ring 1 to 2 km away, not the effect near stations against an area without the metro.
      - It assumes the ring is unaffected, which section 7 doubts: traffic diverted from the corridor, feeder buses, and probably stretches of the Trolebús and Ecovía trunks (not measured; the donor rule excludes those corridors for this reason).
      - Any shock concentrated at station sites (street reopenings, AMT agents posted at stations) would be attributed to the metro, since there is no comparison area outside the metro's 2 km zone.
      - The power simulation injects effects into the inner band only, so power is overstated if the metro moves both bands.
      - For all crashes the gap already rejects at the placements of January and February 2023 and in 1 of the 3 forward openings (`road_safety/output/power/candidates/comparison.csv`).
      - Not yet checked, and suggested by the referee: the ring estimated against pool B for pre-period drift, and the BRT trunk length inside the ring.
- **Check of the fast-road name flag against road geometry (2026-10-01; `road_safety/code/09_fast_road_check.R`, pre-period crashes, January 2021 to November 2023).**
  - **Method.** A crash counts as on a fast road in the geometry when it lies within 50 m of an OSM way of the 2022 layer whose name matches the fast-road list or whose `ref` is E35 (25 m and 100 m are sensitivities). The Mariscal Sucre test uses the ways named Av. Mariscal Sucre.
  - **Totals, district-wide** (`road_safety/output/build/fast_road_geometry_summary.csv`):
    - Observed name-versus-geometry counts are redacted in this release.



  - **Tumbaco and Cumbayá:** observed crash counts for these comparisons are redacted (`fast_road_geometry_check.csv`).
    - Av. Oswaldo Guayasamín was the nearest major road for off-road matches. Nearest does not establish that the crash occurred on that road; the distance to it was not computed.
    - Several Guayasamín ways in the 2022 layer carry the Interoceánica's route number (`ref` E28C), and two carry the alternative name Interoceánica, but most carry neither.
    - These mismatches are therefore **not shown to be misclassification**, rather than shown to be correct.
  - **Elsewhere:** mismatches could reflect intersections, side streets, landmarks or local streets sharing a name. The observed counts by distance are redacted.
  - **Mariscal Sucre:** the diagnostic includes local streets of the same name (`docs/known_issues.md`). Crash counts and distances for sparse subgroups are withheld. The OSM ways named plain MARISCAL SUCRE are in San Juan (`mariscal_sucre_plain_ways.csv`).
  - **Treated 1 km catchments:** crash counts for name and geometry agreement are redacted.
  - **Proposed fix [decision; not applied].** Keep the name flag, but count a match only when the crash lies within 1 km of a way carrying a fast-road name, the E35 ref, or the OSM alias Av. Oswaldo Guayasamín for the Interoceánica. Count a Mariscal Sucre match only within 1 km of the avenue. Crashes merely near a fast road without the name are not added, because proximity alone is weak evidence. **Its limits:**
    - It only removes matches. Crashes the AMT records as Guayasamín in the valley would stay unflagged, and the check cannot see that miss, because Guayasamín is not in the fast-road list. That miss falls only on donors (Cumbayá, Tumbaco).
    - The alias and the 1 km tolerance were chosen after seeing where donor crashes lie (pre-period only). They should be fixed before approval.
    - Its exact pre-period effect had not been computed at this point in the historical plan. The original illustrative count calculation is redacted.
    - Unit-specific indexing absorbs misclassification that is stable over time. Bias would arise only if street fields were recorded differently after the opening (section 8), and that risk differs between treated areas and donors.

    The outcome definition is unchanged until Leonel approves.
- **Earlier pools, kept for comparison only:** A (urban parishes entirely beyond 2 km, J = 5), O1 (parts of urban parishes beyond 2 km, J = 13), O2 (O1 plus parts of rural parishes beyond 2 km, J = 17), O3 (urban resolution-7 cells, J = 4) (`road_safety/output/power/donor_pools.csv`). O1 and O2 cut parishes at the 2 km line; pool B does not.
- **Screening rules (fixed, `road_safety/code/power_units.R`):** a donor needs at least 3 crashes a month on average and at most 20 percent of months without a crash, over January 2021 to November 2023. The screen is applied once, on that full period, so the donor set is the same under the 2022 and 2021 starts and in every sensitivity.
- **BRT rule.** A donor is "crossed" when a trunk corridor runs more than 100 m inside its part beyond 2 km (`parishes.csv`). The Trolebús and Ecovía cross Turubamba (6,252.5 m) and Guamaní (100.8 m; counted as crossed, as Leonel decided); neither is a pool B candidate. The Central Norte MetroBus crosses Ponceano (3,449.5 m), La Concepción (1,834.2 m) and Cotocollao (132.3 m); dropping Ponceano and Cotocollao from pool B is a sensitivity (J = 7).
- **Terminal catchments [decision]:** the northern pool B donors (Carcelén, Comité del Pueblo, Ponceano, El Condado, Cotocollao, Calderón) lie beyond the northern end of the line, the natural catchment of the El Labrador terminal for feeders, park-and-ride and reorganized routes. With six of nine donors in the north, a sensitivity that drops every donor near a terminal station would leave three donors, so it is not defined for pool B as written. Options: drop only the donors served by feeder routes once Metro de Quito supplies them, or drop them one at a time (leave-one-out, section 11). The sign of any spillover bias is not assumed.

## 5. Windows and panels

- **Pre-period (primary, Leonel 2026-09-27, `docs/correspondence/2026-09-27_road_safety_design_decisions.md`):** January 2022 to November 2023 (23 months). It drops the COVID-19 recovery, the October to December 2021 recording block and the least reliable parish labels, and aligns with congestion v2. Sensitivity: January 2021 to November 2023 (35 months). The donor screen is applied on the full 35 months in both cases, so the donor set does not change.
- **P1:** December 2023 to August 2024 (9 months); panel = 23 pre months + 9 P1 months (T = 32) with the primary start, 35 + 9 (T = 44) with the 2021 start. P1 is not free of outages; any 2024 outage month Leonel can date is dropped in a sensitivity. December 2023 (opening month and a holiday month) is dropped in a sensitivity.
- **Disruption:** September to December 2024, dropped as whole months. The air quality paper drops the weeks starting 2024-09-16 through 2024-12-16 (through December 22); the day-exact window is a sensitivity (crashes from September 16 to December 22, 2024 dropped, the partial months scaled).
- **P2:** January 2025 to August 2026 (20 months; Leonel's primary P2 definition), calendar 2025 as its sensitivity. Panel = 23 pre months + 20 P2 months (T = 43) with the primary start, 35 + 20 (T = 55) with the 2021 start; P1 and the disruption months are left out, and SDID treats the pre months as training and the P2 months as evaluation.
- **P2 under route 1 is not workable as written [decision].** Two problems, both with the 2022 start. First, the conformal test fits the model on all months under the null, so the intercept absorbs part of a level shift over the 20 P2 months: in the simplest case the mean residual over P2 keeps 23/43 of the shift, against 20/43 (opposite sign) in any 20-month window inside the pre-period, so the two differ by only 3/43 of the effect. Second, if blocks may not straddle the 13-month hole (to keep calendar adjacency, as in congestion v2), only the 4 twenty-month windows inside the 23 pre months and P2 itself are available, so the floor is 1/5, not 1/43; allowing cyclic shifts across the hole restores 1/43 but breaks adjacency. No P2 conformal power was simulated. A P2 test under route 1 needs a new design and both a size and a power check before it can be approved (fitting the weights on the pre-period only, for example, would make the pre-period residuals in-sample and the P2 residuals out-of-sample, which breaks the exchangeability the permutation relies on and tends to over-reject); until then P2 has only the illustrative evidence of section 10.
- Each window is estimated separately (root rule 6); P1 and P2 are never read off a longer window's effect path. A full-window estimate (all months, disruption included) may be shown as robustness, labelled not clean.
- Quarterly versions use opening-aligned quarters (December to February, March to May, June to August, September to November); quarterly P2 starts March 2025. In P1, quarterly MDEs are never lower than monthly ones whenever both pass the size check (`output/power/mde_table.csv`); quarterly results are secondary.
- Post-period recording blocks (October 2024, August 2025; vehicle rows in October 2025) are kept; a sensitivity drops those months.

## 6. Anticipation

- Station works closed and diverted streets for years before the opening; whether trial runs or a partial service preceded December 1, 2023 is asked of Metro de Quito, with the dates of closures and reopenings by station. Both could move crashes near stations inside the pre-period.
- Sensitivity: drop September to November 2023 as an anticipation window.

## 7. Spillovers

- Traffic that leaves the corridor may move onto feeder roads, parallel avenues and comparison areas. Under pool B donors lie entirely beyond 2 km (the earlier O1 and O2 cut parishes at the 2 km line, next to the 1 to 2 km ring). The ring is reported as a spillover check.
- BRT corridors and terminal catchments: section 4.
- Feeder buses are not separately identified in the data.

## 8. Threats and the rules fixed now

**Pre-period drift (the main threat).** In the pre-period, all recorded crashes near the line rose relative to the peripheral donors. For the 1 km catchments in P1, the average SDID fake effect is +14.4 percent with O1 and +11.8 percent with O2 (Poisson +8.8 and +6.9; conformal, level-shift route, +5.6 to +8.8) (`road_safety/output/power/mde_table.csv`, `conformal_mde_table.csv`). SDID fake effects are larger at the fake openings of July to December 2022 (+13.7 to +23.0 percent with O1) than at those of January to March 2023 (+3.8 to +8.3) (`road_safety/output/power/placebo_in_time_null.csv`), which suggests the drift weakened before the opening. For injury or fatal crashes, with O1 and O2 and the 2021 start, the drift is small or absent: SDID -1.0 percent with O1 and +7.9 with O2; Poisson 0.0 and +5.2; conformal DID +0.3 and +2.3. With those pools the drift is therefore concentrated in damage-only crashes, which is consistent with, but does not show, a change in how minor crashes were recorded near the centre. With pool B it is not: injury or fatal crashes drift about as much as all crashes with the 2022 start (conformal, SC weights +3.7 against +4.5 percent; DID +3.6 against +3.7) and more with the 2021 start (DID +15.7 against +10.4) (`road_safety/output/power/pool_b/comparison.csv`).

The drift is largest with the 2021 start. At the same three fake openings (January, February and March 2023), pool B's conformal fake effects for all crashes in the 1 km catchments (DID weights) are +13.4, +11.8 and +9.1 percent with the 2021 start and +6.5, +3.9 and +0.6 with the 2022 start; for injury or fatal crashes +16.6, +14.0 and +11.4 against +6.6, +3.7 and +0.6 (`road_safety/output/power/pool_b_start2021/conformal_placebo_in_time_null.csv`, `pool_b_start2022/conformal_placebo_in_time_null.csv`). So dropping 2021 from training, not only moving the fake openings later, lowers the fake effects. Across the nine 2021-start openings the fake effects first rise (all crashes, DID: +6.1 percent at July 2022 to +13.4 at January 2023; injury or fatal crashes +4.4 to +22.0 at October 2022) and fall only over January to March 2023 (`pool_b_start2021/conformal_placebo_in_time_null.csv`). The fake windows of those last openings end in September to November 2023, so the fall is consistent with the drift easing before the opening but also with anticipation (street reopenings, trial runs); it does not settle which counterfactual is right. With O1 and O2 the 2022-start fake effects for all crashes are -2.5 to -0.4 percent. Neither SDID's nor synthetic control's weights can follow a trend that no donor combination shows, so the drift is handled by rule, fixed now:
1. Next to the confirmatory estimate, the plan reports the full distribution of in-time fake effects for the same design (recomputed on the final donor units), and, with the 2022 start, the 2021-start distribution next to it. These are the **forward** fake openings (training before the window only). The 15 placements of the candidate table are not a drift measure: windows with training after them cancel a linear trend, so their mean is close to zero for any trend. For pool B, injury or fatal crashes, synthetic-control weights, the 15 placements range from -16.2 to +11.6 percent, against +1.1 to +5.9 over the 3 forward openings (`candidates/comparison.csv`, `pool_b/comparison.csv`).
2. The estimate is described as **distinguishable from the pre-period drift** only if its absolute value exceeds the largest absolute fake effect (a two-sided rule: an estimate between zero and the fake effects, of either sign, does not pass); otherwise it is described as not distinguishable, whatever its p-value. With the 2022 start the fake effects come from only 3 overlapping fake openings (for all crashes in the 1 km catchments with pool B: +0.6 to +6.5 percent, DID), so the threshold is poorly estimated and the rule is a weak guard; the threshold from the 2021 start (13.4 percent) is reported next to it.
3. **[decision]** Which counterfactual is primary: that the drift ended by the opening (the estimator as is) or that it continues (series detrended with the pre-period trend of each unit's gap; so far defined for SDID only, and to be defined for route 1 if it is chosen). The fake effects fall at the last three openings, which is consistent with the first but also with anticipation (see above). The January 2021 start is a further sensitivity.

**Recording changes after the opening.** The audit found new recording units in 2024, differently formatted blocks in October 2024 and August 2025, a change in time rounding from February 2025, and unknown coverage (the observed ID-range shares are redacted). All recorded crashes is the outcome most exposed to reporting practice (the historical damage-only count and share are redacted; `road_safety/output/descriptives/severity_and_involvement_by_year.csv`), and AMT agents posted around stations after the opening would raise recorded crashes there mechanically. Rules fixed now:
1. The AMT's answers to the audit questions on coverage and recording (questions 3, 7, 8 and 15) are needed before approval.
2. If the AMT reports a change in which minor (damage-only) crashes are recorded, injury or fatal crashes become the confirmatory outcome, with the same test.
3. If the AMT says recent months are not closed, the months it names are dropped.
4. Step 2 checks the recording composition by area as a diagnostic: shares of records by JEFATURA type and by ID-format block, treated area against donors, before and after the opening. Differences are reported next to the estimate.

**Other shocks.** COVID-19 recovery in 2021 (left out by the 2022 primary start; in the 2021-start sensitivity); the 2024 power cuts (disruption dropped); other citywide events in 2024 that could move crashes differently in the centre and the periphery, such as curfews under the state of emergency or changes in fuel prices (suggested by the methods referee, not checked here; Leonel to date them, and the months affected are dropped in a sensitivity); repeated exact coordinates in 2021 and 2022: no pre-period crash at a point shared by 5 or more records lies inside the treated areas (`pre_counts_by_treated_area.csv`), but smaller exact-point clusters, below that threshold, do lie within 1 km of a station (audit table T25, distance bands); crashes at points shared by 3 or more records are dropped in a sensitivity.

## 9. Estimator and inference

- **Route 1 (recommended confirmatory): synthetic control with an intercept, conformal inference.** Weights on the donors are synthdid-style (simplex, intercept, ridge penalty; `synthdid:::sc.weight.fw`), on unit-month counts divided by each unit's pre-period mean. Following Chernozhukov, Wüthrich and Zhu, under the null of no effect the model is fitted on all months of the panel, the residuals are formed, and the statistic |mean residual| over the evaluation months is compared with its value under every cyclic shift of the residual sequence. For P1 the p-value's floor is 1/T: 1/32 with the January 2022 start (1/44 with 2021), whatever the number of donors, so the 5 percent level is reachable; in the power simulations the floor was 1/21 to 1/23 with the 2022 start and 1/27 to 1/35 with 2021. P2 is not yet workable under this route (section 5). It assumes the residuals are exchangeable over time, which the pre-period drift strains (section 8). The CWZ default statistic, mean |residual|, is shown as a secondary check: it has almost no power here (section 10).
- **Route 2: SDID with the in-space rank test.** SDID (`synthdid` 0.0.9) on the same scaled counts. Each donor in turn is the fake treated unit, fitted on the other donors; statistic |effect| divided by the unit's pre-period fit error; p = (1 + number of placebos at least as extreme) / (J + 1). No placebo is excluded for poor fit (the statistic is already scaled by fit error). The only reachable rejection is the treated unit ranking first: p = 1/10 = 0.10 with pool B (J = 9), so the 5 percent level is out of reach and the 10 percent level is reached only at rank one; without the Central Norte-crossed donors (J = 7) the floor is 1/8 = 0.125, and leaving one donor out (J = 8) gives 1/9 = 0.111, so neither sensitivity can reach 10 percent. (With the earlier pools the floors were 1/14 for O1 and 1/18 for O2.) Route 2 has not been run for pool B. Because the treated area was not assigned at random among the J + 1 units, the p-value reads as how unusual the treated unit is among the placebos (an observational diagnostic), not as an exact randomization test.
- **[decision]** Leonel picks the confirmatory route; the other is reported as a secondary check. Under either route the smallest attainable p-value is stated next to every p-value, the drift rule of section 8 applies, and there are no Wald, normal or fixest standard-error p-values.
- **Effect scale.** Effects on the scaled series (tau) are reported as a percentage of the counterfactual: 100 x tau / (mean treated index in the evaluation months - tau).
- **Secondary estimators:** SDID or synthetic control (whichever is not confirmatory); Poisson model with unit and month fixed effects (`fixest::fepois`), effect exp(b) - 1, point estimate only.
- **Estimators by outcome** (earlier pools, 2021 start; for pool B only route 1 was run). For all crashes, conformal inference with the level-shift statistic has the smallest fake effects and never rejected with no injected effect in the P1 in-time runs for the 1 km catchments with O1 or O2; SDID has larger fake effects and fails the size check for several pooled designs (for example the 500 m catchments with O1 and O2), and the Poisson model fails it for the 1 km catchments with O1 (`mde_table.csv`, `conformal_mde_table.csv`). For injury or fatal crashes all three estimators fit well with O1 (fake effects -1.0, 0.0 and +0.3 percent). For pedestrian crashes SDID's fake effects differ in sign from the others (for example corridor 500 m, O1: SDID -9.2 percent, Poisson +33.5, conformal DID +44.1); this is not yet understood and is checked before Step 2.
- **Confidence sets** by inverting the chosen test over constant proportional effects (in-space: coverage 1 - 1/(J + 1)); the set may be unbounded.
- Non-rejection does not show that the metro had no effect, and an MDE is not a bound on the true effect.

## 10. Minimum detectable effects (pre-period only)

### Candidate designs (2026-09-28): 15 fake placements, January 2022 start

**Result.** No candidate brings the MDE for a fall in injury or fatal crashes below 40 percent at the 5 percent level. The smallest value, 40 percent, is reached by two designs that also pass both size checks: the earlier pool O2 with DID weights, and the gradient design with conformal inference. On the grid, 40 means a fall of between 30 and 40 percent.
- **Composite donors (pool C)** do not pass the 10 percent size check for injury or fatal crashes: 2 or 3 of 15 placements reject with no effect. They reject at the windows starting in April and May 2022 (and July for DID at 10 percent), where their fake effects are -18 to -24 percent, which points to a 2022 dip in treated crashes relative to the composites (`candidates_2022/conformal_placebo_in_time_null.csv`). The composites' fast-road shares are not reported; Puembo + Tababela includes the airport zone.
- **The size check that filters this table is weak** (methods referee, 2026-09-28).
  - Under route 1 the model is fitted on all 23 months at every placement, so with no injected effect the 15 p-values are ranks of 15 of the 23 cyclic windows of nearly the same residual series, and rejections cluster at adjacent placements.
  - Even with independent windows, a correctly sized 10 percent test gives 2 or more rejections in 15 about 45 percent of the time.
  - A "fails" at 10 percent (2 of 15) is therefore partly chance, and so is the filter of the choice rule (section 13).
  - The referee suggests one of three changes: base the size check on forward openings, as the real test runs; allow a binomial tolerance; or simulate the gate under a null with the months permuted. None of these has been run.
- **The urban-street outcome** barely changes the treated series (observed removal counts redacted) and lowers no 5 percent MDE for injury or fatal crashes. At 10 percent it lowers one: O2 with DID weights, from 40 to 30.

**Method.**
- Conformal inference (route 1), level-shift statistic, 1 km station catchments, P1, monthly, 80 percent power, pre-period only (January 2022 to November 2023, T = 23).
- **Placements.** The 9-month fake window is placed at each of the 15 positions inside the panel. Training covers the other 14 months, before and after the window.
- **Size check.** A design fails when more than max(alpha, 1/15) of the 15 placements reject with no injected effect, that is, 2 or more.
- **Forward subset.** It comes from a separate run with the 3 forward openings (January to March 2023, training before the window only).
- **Runs.** 150 per power estimate. The smallest attainable p is 1/23 in the simulation and 1/32 in the real P1 test.
- **Caveat on the placements.** Windows in the middle of the panel check size under the test's own assumption (months exchangeable), but not the forward extrapolation that the real test makes. The 15 windows overlap heavily (about 2.5 independent windows), and the gate is close to mechanical (see the result above).
- **Sources.**
  - `road_safety/output/power/candidates/comparison.csv`, built by `road_safety/code/07_candidates.R` from `output/power/candidates_2022/` and `candidates_2022_forward/`;
  - method: `road_safety/code/04b_power_conformal.R` with `RS_OPENINGS=all`;
  - composites: `road_safety/code/composites.R`.
- **Changes against the 3-opening table below.** With 15 placements, pool B's injury MDE with SC weights is 50 / more than 50 at 5 percent; its DID version fails the 10 percent size check.

**Injury or fatal crashes and all crashes**

| Design | Outcome | Weights | Donors | Fake effect, mean (range), percent | No-effect rejections 5 / 10 percent (of 15) | Forward subset 5 / 10 (of 3) | MDE fall / rise at 5 percent | MDE fall / rise at 10 percent | Passes both size checks |
|---|---|---|---|---|---|---|---|---|---|
| Pool B | injury or fatal | SC | 9 | -0.6 (-16.2 to +11.6) | 0 / 1 | 0 / 0 | 50 / > 50 | 50 / > 50 | yes |
| Pool B | injury or fatal | DID | 9 | -1.5 (-19.5 to +13.6) | 0 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| Pool B without Central Norte | injury or fatal | SC | 7 | -1.9 (-19.9 to +15.5) | 1 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| Pool B without Central Norte | injury or fatal | DID | 7 | -2.0 (-23.4 to +19.6) | 1 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| C: pool B + composites | injury or fatal | SC | 14 | -7.8 (-24.1 to +2.5) | 1 / 2 | 0 / 0 | 50 / > 50 | size fails / size fails | no |
| C: pool B + composites | injury or fatal | DID | 14 | -8.4 (-23.4 to +4.0) | 1 / 3 | 0 / 0 | 50 / > 50 | size fails / size fails | no |
| C without Central Norte | injury or fatal | SC | 12 | -9.3 (-28.1 to +2.6) | 1 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| C without Central Norte | injury or fatal | DID | 12 | -9.8 (-28.6 to +3.6) | 1 / 3 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| Earlier O1 | injury or fatal | SC | 13 | -7.1 (-19.9 to +12.7) | 0 / 0 | 0 / 0 | 50 / > 50 | 40 / > 50 | yes |
| Earlier O1 | injury or fatal | DID | 13 | -7.1 (-16.0 to +9.9) | 0 / 0 | 0 / 0 | 50 / > 50 | 40 / > 50 | yes |
| Earlier O2 | injury or fatal | SC | 17 | -4.3 (-12.9 to +11.0) | 0 / 0 | 0 / 0 | 50 / > 50 | 40 / > 50 | yes |
| Earlier O2 | injury or fatal | DID | 17 | -4.8 (-11.2 to +7.9) | 0 / 0 | 0 / 0 | 40 / > 50 | 40 / > 50 | yes |
| Gradient, conformal (inner minus outer ring) | injury or fatal | DID | 1 | -0.7 (-7.9 to +10.4) | 0 / 0 | 0 / 0 | 40 / > 50 | 40 / 50 | yes |
| Pool B | all crashes | SC | 9 | -0.7 (-7.8 to +6.4) | 0 / 0 | 0 / 1 | 25 / 40 | 25 / 25 | yes |
| Pool B | all crashes | DID | 9 | -1.0 (-9.7 to +5.7) | 1 / 1 | 0 / 1 | 30 / 40 | 25 / 30 | yes |
| Pool B without Central Norte | all crashes | SC | 7 | -1.7 (-13.6 to +11.1) | 2 / 3 | 1 / 1 | size fails / size fails | size fails / size fails | no |
| Pool B without Central Norte | all crashes | DID | 7 | -1.6 (-15.6 to +11.7) | 1 / 2 | 1 / 1 | 30 / 50 | size fails / size fails | no |
| C: pool B + composites | all crashes | SC | 14 | -4.9 (-14.2 to +2.3) | 1 / 2 | 0 / 0 | 30 / 40 | size fails / size fails | no |
| C: pool B + composites | all crashes | DID | 14 | -4.8 (-14.0 to +2.3) | 2 / 2 | 0 / 0 | size fails / size fails | size fails / size fails | no |
| C without Central Norte | all crashes | SC | 12 | -5.9 (-17.3 to +4.0) | 1 / 2 | 0 / 0 | 30 / 40 | size fails / size fails | no |
| C without Central Norte | all crashes | DID | 12 | -5.8 (-18.2 to +5.5) | 2 / 2 | 0 / 0 | size fails / size fails | size fails / size fails | no |
| Earlier O1 | all crashes | SC | 13 | -2.3 (-5.6 to +2.0) | 0 / 0 | 0 / 0 | 25 / 40 | 20 / 30 | yes |
| Earlier O1 | all crashes | DID | 13 | -3.1 (-7.1 to +0.7) | 0 / 1 | 0 / 0 | 25 / 40 | 20 / 30 | yes |
| Earlier O2 | all crashes | SC | 17 | -2.3 (-6.6 to +2.4) | 0 / 0 | 0 / 0 | 20 / 30 | 20 / 25 | yes |
| Earlier O2 | all crashes | DID | 17 | -3.2 (-6.8 to +0.8) | 1 / 2 | 0 / 0 | 20 / 30 | size fails / size fails | no |
| Gradient, conformal (inner minus outer ring) | all crashes | DID | 1 | +2.1 (-10.2 to +14.7) | 1 / 2 | 1 / 1 | 40 / 40 | size fails / size fails | no |

**Urban-street outcome (candidate 1, and 1+2 with pool C)**

| Design | Outcome | Weights | Donors | Fake effect, mean (range), percent | No-effect rejections 5 / 10 percent (of 15) | Forward subset 5 / 10 (of 3) | MDE fall / rise at 5 percent | MDE fall / rise at 10 percent | Passes both size checks |
|---|---|---|---|---|---|---|---|---|---|
| Pool B | urban-street injury or fatal | SC | 9 | +0.6 (-17.7 to +18.1) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| Pool B | urban-street injury or fatal | DID | 9 | +0.1 (-23.1 to +21.4) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| Pool B without Central Norte | urban-street injury or fatal | SC | 7 | +0.1 (-25.3 to +24.6) | 0 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| Pool B without Central Norte | urban-street injury or fatal | DID | 7 | +0.4 (-30.3 to +26.5) | 1 / 2 | 0 / 0 | > 50 / > 50 | size fails / size fails | no |
| C: pool B + composites | urban-street injury or fatal | SC | 14 | -5.6 (-22.8 to +7.4) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| C: pool B + composites | urban-street injury or fatal | DID | 14 | -5.9 (-20.6 to +9.9) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| C without Central Norte | urban-street injury or fatal | SC | 12 | -6.5 (-27.4 to +10.8) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| C without Central Norte | urban-street injury or fatal | DID | 12 | -6.8 (-25.0 to +12.3) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| Earlier O1 | urban-street injury or fatal | SC | 13 | -16.2 (-33.8 to +12.8) | 0 / 0 | 0 / 0 | > 50 / > 50 | 50 / > 50 | yes |
| Earlier O1 | urban-street injury or fatal | DID | 13 | -17.2 (-34.5 to +12.0) | 0 / 0 | 0 / 1 | 50 / > 50 | 40 / > 50 | yes |
| Earlier O2 | urban-street injury or fatal | SC | 17 | -10.0 (-25.7 to +9.8) | 0 / 0 | 0 / 0 | 50 / > 50 | 40 / > 50 | yes |
| Earlier O2 | urban-street injury or fatal | DID | 17 | -11.4 (-24.7 to +6.2) | 0 / 0 | 0 / 0 | 40 / > 50 | 30 / > 50 | yes |
| Gradient, conformal (inner minus outer ring) | urban-street injury or fatal | DID | 1 | -1.4 (-9.1 to +12.7) | 0 / 0 | 0 / 0 | 50 / > 50 | 50 / 50 | yes |
| Pool B | urban-street all | SC | 9 | +0.6 (-9.1 to +10.8) | 1 / 1 | 0 / 0 | 40 / 50 | 30 / 40 | yes |
| Pool B | urban-street all | DID | 9 | +1.3 (-8.5 to +13.5) | 1 / 1 | 0 / 0 | 50 / > 50 | 40 / 40 | yes |
| Pool B without Central Norte | urban-street all | SC | 7 | +0.6 (-12.7 to +14.1) | 0 / 2 | 0 / 0 | 50 / > 50 | size fails / size fails | no |
| Pool B without Central Norte | urban-street all | DID | 7 | +1.6 (-11.7 to +15.8) | 1 / 1 | 0 / 0 | 50 / > 50 | 40 / 50 | yes |
| C: pool B + composites | urban-street all | SC | 14 | -4.5 (-14.2 to +5.4) | 0 / 1 | 0 / 0 | 50 / 50 | 30 / 40 | yes |
| C: pool B + composites | urban-street all | DID | 14 | -2.2 (-10.2 to +7.4) | 0 / 1 | 0 / 0 | > 50 / 50 | 40 / 40 | yes |
| C without Central Norte | urban-street all | SC | 12 | -5.1 (-17.5 to +7.8) | 0 / 1 | 0 / 0 | 50 / > 50 | 40 / 50 | yes |
| C without Central Norte | urban-street all | DID | 12 | -2.7 (-13.6 to +9.2) | 0 / 1 | 0 / 0 | > 50 / > 50 | 40 / 50 | yes |
| Earlier O1 | urban-street all | SC | 13 | -4.9 (-10.5 to +4.5) | 0 / 0 | 0 / 0 | 40 / 50 | 30 / 40 | yes |
| Earlier O1 | urban-street all | DID | 13 | -5.8 (-12.0 to +2.8) | 0 / 0 | 0 / 0 | 40 / 50 | 30 / 40 | yes |
| Earlier O2 | urban-street all | SC | 17 | -3.5 (-10.2 to +2.6) | 0 / 1 | 0 / 0 | 40 / 40 | 30 / 40 | yes |
| Earlier O2 | urban-street all | DID | 17 | -3.6 (-10.4 to +0.8) | 0 / 1 | 0 / 0 | 40 / 40 | 25 / 40 | yes |
| Gradient, conformal (inner minus outer ring) | urban-street all | DID | 1 | +1.1 (-8.0 to +12.6) | 1 / 2 | 0 / 0 | 40 / 40 | size fails / size fails | no |

**Sensitivity: urban-street outcome also without Av. Mariscal Sucre**

| Design | Outcome | Weights | Donors | Fake effect, mean (range), percent | No-effect rejections 5 / 10 percent (of 15) | Forward subset 5 / 10 (of 3) | MDE fall / rise at 5 percent | MDE fall / rise at 10 percent | Passes both size checks |
|---|---|---|---|---|---|---|---|---|---|
| Pool B | urban-street injury or fatal, also without Mariscal Sucre | SC | 9 | +1.6 (-17.9 to +16.9) | 0 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| Pool B | urban-street injury or fatal, also without Mariscal Sucre | DID | 9 | +0.7 (-22.6 to +18.8) | 0 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| C: pool B + composites | urban-street injury or fatal, also without Mariscal Sucre | SC | 14 | -5.0 (-21.4 to +7.9) | 1 / 1 | 0 / 0 | > 50 / > 50 | 50 / > 50 | yes |
| C: pool B + composites | urban-street injury or fatal, also without Mariscal Sucre | DID | 14 | -5.4 (-18.2 to +9.8) | 1 / 1 | 0 / 0 | > 50 / > 50 | > 50 / > 50 | yes |
| Gradient, conformal (inner minus outer ring) | urban-street injury or fatal, also without Mariscal Sucre | DID | 1 | +1.0 (-7.6 to +7.7) | 0 / 0 | 0 / 0 | 50 / > 50 | 40 / 50 | yes |
| Pool B | urban-street all, also without Mariscal Sucre | SC | 9 | +0.1 (-12.9 to +11.2) | 1 / 1 | 0 / 0 | 50 / 50 | 40 / 40 | yes |
| Pool B | urban-street all, also without Mariscal Sucre | DID | 9 | +0.6 (-12.0 to +12.8) | 1 / 2 | 0 / 0 | 50 / 50 | size fails / size fails | no |
| C: pool B + composites | urban-street all, also without Mariscal Sucre | SC | 14 | -4.7 (-15.5 to +7.2) | 0 / 2 | 0 / 0 | 50 / 50 | size fails / size fails | no |
| C: pool B + composites | urban-street all, also without Mariscal Sucre | DID | 14 | -2.4 (-11.2 to +9.3) | 0 / 1 | 0 / 0 | > 50 / 50 | 40 / 50 | yes |
| Gradient, conformal (inner minus outer ring) | urban-street all, also without Mariscal Sucre | DID | 1 | +2.1 (-6.2 to +14.3) | 1 / 2 | 1 / 2 | 40 / 40 | size fails / size fails | no |

**Gradient, placebo-corridor route (candidate 3 and 1+3).** Run on 2026-10-01 on the 2022 district-wide road layer. The rule keeps 10 placebos; the minimum number usable over placements is 4, so the floor is 1/5 and all 8 placebo rows in `comparison.csv` are "not testable" at 5 and 10 percent (`road_safety/output/power/gradient/gradient_rows.csv`; section 4).

**Donor weights and pre-period fit** (all 23 months, synthetic control with an intercept; `road_safety/output/power/candidates/weights.csv`, `fit_summary.csv`, `fit_monthly.csv`):
- **Weights.** They are close to equal. That may be because the ridge penalty of the weight rule dominates, or because no donor helps; a refit with a penalty near zero would tell, and has not been run.
  - Pool B: every donor has 7 to 15 percent. The largest weight goes to Conocoto: 13.7 percent for all crashes, 14.9 for injury or fatal crashes.
  - Pool C, injury or fatal crashes: every donor has 4.7 to 9.1 percent.
- **Fit.** It is weak: for injury or fatal crashes the correlation is near zero in pool B (-0.01) and low in pool C (0.191). These are in-sample figures, over the months used to fit the weights, and synthetic control barely beats equal weights (injury or fatal, pool B: 0.227 against 0.276 with DID weights).
  - Pool B, all crashes: root mean square error of the gap 0.136 (on the index scale, where 1 is the treated area's mean month); correlation between the treated and synthetic series 0.405.
  - Pool B, injury or fatal crashes: 0.227 and -0.01.
  - Pool C: 0.121 and 0.495 for all crashes, 0.194 and 0.191 for injury or fatal crashes.
  - The observed monthly injury-or-fatal count mean and its numerical Poisson-noise benchmark are redacted. Under a Poisson model, the index-scale noise benchmark is the inverse square root of the count mean. Count noise that no donor combination follows could contribute to weak fit and a large MDE; this is a possible explanation, not a demonstrated cause. Fit was computed only for pools B and C.
  - For the urban-street outcome the donor screen was not re-applied: Tumbaco falls below the fixed crash-volume screen (observed counts and mean redacted) (`urban_street_removed.csv`), and the fit worsens (injury or fatal, pool B, SC: 0.318 against 0.227). The name-based outcome is also exposed to post-opening changes in how street fields are recorded (section 8), and it changes the estimand to crashes off named fast roads.

### Pool B (2026-09-27): primary start January 2022, sensitivity 2021

Conformal inference (route 1), level-shift statistic, P1, monthly, 80 percent power, pre-period only. Each cell gives synthetic-control weights (SC, the recommended route 1 estimator) first, then DID weights. Fake openings: January to March 2023 (3) with the 2022 start, July 2022 to March 2023 (9) with the 2021 start; 10 draws per opening and effect size, so 30 or 90 runs per power estimate. "Rejections with no effect" counts the fake openings at which the design rejects with no injected effect; a design fails the size check when that share exceeds max(alpha, 1/n) of its n openings, so with 3 openings one rejection still passes. "> 50" means no effect up to 50 percent reaches 80 percent power. Source: `road_safety/output/power/pool_b/comparison.csv` (built by `road_safety/code/06_pool_b.R` from `output/power/pool_b_start2022/` and `pool_b_start2021/`; method `road_safety/code/04b_power_conformal.R`).

**1 km station catchments**

| Start | Outcome | Pool | Donors | Fake effect, percent: SC; DID (DID range) | Rejections with no effect, 5 / 10 percent: SC; DID | MDE fall / rise at 5 percent: SC; DID | MDE fall / rise at 10 percent: SC; DID |
|---|---|---|---|---|---|---|---|
| 2022 | injury or fatal | **B** | 9 | +3.7; +3.6 (+0.6 to +6.6) | 0 / 0 of 3; same | 50 / 40; > 50 / 40 | 40 / 25; 50 / 40 |
| 2022 | injury or fatal | B without Central Norte | 7 | +4.7; +7.3 | 0 / 0 of 3; same | 50 / 40; 50 / 50 | 40 / 30; 50 / 40 |
| 2022 | injury or fatal | O1 | 13 | -11.7; -10.7 | 0 / 0 of 3; same | 50 / > 50; same | 40 / > 50; same |
| 2022 | injury or fatal | O2 | 17 | -8.6; -8.2 | 0 / 0 of 3; same | 50 / 50; same | 40 / 40; same |
| 2022 | all crashes | **B** | 9 | +4.5; +3.7 (+0.6 to +6.5) | 0 / 1 of 3; same | 50 / 25; > 50 / 30 | 40 / 15; same |
| 2022 | all crashes | B without Central Norte | 7 | +9.1; +10.1 | 1 / 1 of 3; same | 50 / 25; 50 / 40 | 30 / 15; 30 / 20 |
| 2022 | all crashes | O1 | 13 | -1.7; -2.5 | 0 / 0 of 3; same | 30 / 30; 40 / 30 | 20 / 25; 20 / 20 |
| 2022 | all crashes | O2 | 17 | -0.4; -0.9 | 0 / 0 of 3; same | 40 / 15; 40 / 20 | 25 / 15; same |
| 2021 | injury or fatal | **B** | 9 | +16.0; +15.7 (+4.4 to +22.0) | 0 / 1 of 9; same | > 50 / 30; same | 50 / 25; same |
| 2021 | injury or fatal | B without Central Norte | 7 | +20.1; +22.6 | 0 / 2 of 9 (fails at 10); same | > 50 / 25; > 50 / 40 | size fails; same |
| 2021 | injury or fatal | O1 | 13 | +0.2; +0.3 | 0 / 0 of 9; same | 50 / 50; same | 50 / 50; 40 / 50 |
| 2021 | injury or fatal | O2 | 17 | +2.8; +2.3 | 0 / 0 of 9; same | 50 / 50; 50 / 40 | 40 / 40; same |
| 2021 | all crashes | **B** | 9 | +9.3; +10.4 (+6.1 to +13.4) | 0 / 1 of 9; same | > 50 / 20; same | 30 / 10; same |
| 2021 | all crashes | B without Central Norte | 7 | +11.7; +13.4 | 1 / 4 of 9 (fails at 10); 2 / 4 of 9 (fails at both) | > 50 / 15; size fails | size fails; same |
| 2021 | all crashes | O1 | 13 | +8.8; +7.8 | 0 / 0 of 9; same | 50 / 30; 40 / 25 | 40 / 30; 40 / 25 |
| 2021 | all crashes | O2 | 17 | +6.4; +5.6 | 0 / 0 of 9; same | 40 / 25; same | 40 / 25; 30 / 20 |

**Other treated units, pool B, 2022 start** (no rejection with no effect at either level in any of these designs)

| Treated unit | Outcome | Fake effect, percent: SC; DID | MDE fall / rise at 5 percent: SC; DID | MDE fall / rise at 10 percent: SC; DID |
|---|---|---|---|---|
| 500 m catchments | all crashes | +0.3; 0.0 | > 50 / 40; > 50 / 50 | 50 / 40; same |
| 500 m catchments | injury or fatal | +1.4; +2.5 | > 50 / > 50; > 50 / 50 | > 50 / 50; same |
| Corridor within 500 m | all crashes | -0.3; -0.6 | > 50 / 30; > 50 / 40 | 50 / 25; 50 / 30 |
| Corridor within 500 m | injury or fatal | +5.3; +5.9 | > 50 / 50; > 50 / > 50 | > 50 / 30; same |

Reading the pool B tables:
- With the primary 2022 start and SC weights, pool B detects at 5 percent a fall of 50 percent (that is, somewhere between 40 and 50, the grid step) and a rise of 25 percent in all crashes in the 1 km catchments, and a fall of 50 and a rise of 40 percent in injury or fatal crashes; with DID weights no fall up to 50 percent is detected in either outcome. At 10 percent it detects falls of 40 percent with SC weights. Its fake effects are small and positive (+3.6 to +4.5 percent).
- **The 2022 size checks cannot assess size.** They rest on 3 fake openings whose 9-month windows share 8 of 9 months (for adjacent openings), and a design passes with 1 rejection in 3; the all-crash pool B designs reject once in 3 at 10 percent. They show only that no design rejects at every opening.
- **The 2022 power figures may be pessimistic, for reasons that are not the floor.** The simulated panels have 21 to 23 months (floor 1/21 to 1/23) against 32 in the real P1 test (floor 1/32); a 5 percent rejection needs rank one in both, which is harder among 32. Against that, the real test trains on 23 months instead of 12 to 14, and its fit absorbs less of a level shift (by the logic of section 5, the 9 evaluation months are 9/32 of the panel instead of 9/21 to 9/23). Each power estimate rests on 30 runs, a Monte Carlo standard error of about 0.07 near 80 percent power, so MDEs can differ by a grid step by chance.
- The 2021 start adds drift to pool B (fake effects +9.3 to +16.0 percent), and its rise MDEs partly reflect that drift rather than power.
- Dropping the Central Norte-crossed donors (Ponceano, Cotocollao) raises the fake effects and, with the 2021 start, makes several designs fail the size check.
- O1 and O2, which cut parishes at the 2 km line, have fake effects closer to zero for all crashes from 2022 (-2.5 to -0.4 percent) and detect a 30 to 40 percent fall at 5 percent; for injury or fatal crashes their 2022 fake effects are negative (-8.2 to -11.7 percent). Whether they fit the treated series better in a formal sense (pre-period fit error) was not tested, and pool B follows Leonel's rule, not these numbers.
- Pedestrian crashes, pool B: no MDE up to 50 percent in the 1 km catchments with the 2022 start (fake effects +31.2 SC, +32.4 DID; one 500 m design reaches a 50 percent rise at 10 percent), size failures in the 1 km and 500 m catchments and the corridor with the 2021 start (`pool_b_start2022/conformal_mde_table.csv`, `pool_b_start2021/conformal_mde_table.csv`).
- Pool B's donor weights and pre-period fit are in the candidate-design subsection above.

### Earlier pools, 2021 start (2026-09-25; kept for comparison)

Re-run on 2026-09-25 with the GeoQuito parish polygons and the OSM BRT routes (`road_safety/code/04_power.R`, `04b_power_conformal.R`, `power_units.R`); the earlier label-based results are superseded.

P1 (9 fake openings, July 2022 to March 2023), monthly, 80 percent power; effects are changes in the treated area's crashes as a share of its training mean; "> 50" means no effect up to 50 percent reaches 80 percent power; "size fails" means the design rejected with no injected effect at more than max(alpha, 1/9) of the fake openings.

**Route 1: synthetic control (SC) or DID weights, conformal inference, level-shift statistic.** Floor of the p-value: 1/27 to 1/35 in the simulations, 1/44 in the real P1 panel with the 2021 start. Source: `road_safety/output/power/conformal_mde_table.csv`.

| Treated unit | Outcome | Pool | Fall / rise at 5 percent (DID; SC) | Fall / rise at 10 percent (DID; SC) | Fake effect (DID; SC) |
|---|---|---|---|---|---|
| 1 km catchments | all crashes | O1 (J = 13) | 40 / 25; 50 / 30 | 40 / 25; 40 / 30 | +7.8; +8.8 |
| 1 km catchments | all crashes | O2 (J = 17) | 40 / 25; 40 / 25 | 30 / 20; 40 / 25 | +5.6; +6.4 |
| 1 km catchments | all crashes | O1 without Trolebús/Ecovía (J = 11) | 40 / 25; 50 / 30 | 40 / 25; 40 / 30 | +7.8; +8.8 |
| 1 km catchments | all crashes | O2 without Trolebús/Ecovía (J = 15) | 40 / 25; 50 / 25 | 30 / 20; 30 / 20 | +5.3; +6.0 |
| 1 km catchments | injury or fatal | O1 | 50 / 50; 50 / 50 | 40 / 50; 50 / 50 | +0.3; +0.2 |
| 1 km catchments | injury or fatal | O2 | 50 / 40; 50 / 50 | 40 / 40; 40 / 40 | +2.3; +2.8 |
| Corridor 500 m | all crashes | O2 | 40 / 30; 50 / 30 | 40 / 20; 40 / 20 | +7.9; +9.9 |
| 500 m catchments | all crashes | O2 | 50 / 30; 50 / 40 | 40 / 20; 40 / 25 | +12.9; +13.4 |
| 1 km catchments | all crashes | A (J = 5) | > 50 / 30; > 50 / 25 | size fails | +20.1; +19.5 |

**Route 2: in-space rank test.** The level is the treated unit ranking first: p = 1/(J + 1). Source: `road_safety/output/power/mde_table.csv`.

| Treated unit | Outcome | Pool | SDID fall / rise | Poisson fall / rise | SDID fake effect, mean (range) |
|---|---|---|---|---|---|
| 1 km catchments | all crashes | O1 (J = 13) | 50 / 10 | size fails | +14.4 (+3.8 to +23.0) |
| 1 km catchments | all crashes | O2 (J = 17) | 40 / 10 | 25 / 20 | +11.8 (+7.3 to +15.5) |
| 1 km catchments | all crashes | O2 without Trolebús/Ecovía (J = 15) | 40 / 10 | 25 / 20 | +12.8 (+8.1 to +16.0) |
| 1 km catchments | injury or fatal | O1 | 40 / 40 | 20 / 25 | -1.0 (-10.3 to +11.0) |
| 1 km catchments | injury or fatal | O2 | 40 / 25 | 25 / 15 | +7.9 (-1.5 to +14.2) |
| 1 km catchments | pedestrian | O1, O2 | > 50 / > 50 | > 50 / > 50 | |
| 500 m catchments | all crashes | O1, O2 | size fails | 50 / 30 (O1); 50 / 40 (O2) | |
| Corridor 500 m | all crashes | O2 | > 50 / 15 | 40 / 40 | +18.9 (-1.0 to +28.8) |
| Each station (1 km) | all crashes | O1 | size fails for 3; see below | | |
| Any treated unit | any outcome | A (J = 5), O1 without both BRT sets (J = 8) | not attainable (smallest p 1/6 or 1/9) | | |

Reading the tables:
- The MDEs include the realised pre-period drift, which makes rises easier and falls harder to detect. The in-space rise MDEs of 10 percent for all crashes are drift, not power; route 1 carries less of it.
- Single stations (SDID, O1, all crashes): 3 of 15 fail the size check (Cardenal de la Torre, El Ejido, Universidad Central); no station detects a fall of less than 50 percent (Iñaquito, La Pradera and Solanda reach exactly 50), and one reaches a 30 percent rise (La Alameda) (`mde_table.csv`). Stations stay descriptive.
- Pedestrian crashes: no design detects a change of less than 50 percent; a few conformal designs reach exactly a 50 percent rise at 10 percent.
- In P1, whenever both the monthly and the quarterly design pass the size check, quarterly MDEs are never lower than monthly ones (`mde_table.csv`); in 7 comparisons the monthly design fails the check and the quarterly one, whose gate allows 1 rejection in 3, does not.
- The default conformal statistic, mean |residual|, detects no fall of less than 50 percent for the 1 km catchments and all crashes (`conformal_mde_table.csv`).
- **P2:** no MDE exists for SDID, synthetic control or the Poisson model. The single in-time placement (training January 2021 to March 2022) is illustrative; the monthly Poisson model fails its size check there with O1. The block bootstrap uses an equal-weight donor mean, not SDID, with one set of block starts per draw for all units; for the 1 km catchments with O2 it gives 15 / 15 for all crashes and 25 / 25 for injury or fatal crashes with stationary gaps; when each gap keeps its pre-period trend, the all-crash design fails its size check and injury or fatal crashes give 50 / 25 (`road_safety/output/power/p2_block_bootstrap_mde.csv`).
- **Monte Carlo variation.** In `04_power.R` the injected draws are seeded by a design's position in the run list, so changing the list changes the draws and MDEs can move by about one grid step (earlier runs are not kept). In `04b_power_conformal.R` each design is seeded by its position in a fixed grid, so it gets the same draws whichever pools are run: the 72 O1 and O2 rows of the 2021-start pool B run match `conformal_mde_table.csv` exactly.
- **Size gate.** With 9 fake openings the gate lets a design reject once with no injected effect; at 5 percent that is lenient.
- **Limits of the method.** The 9 fake windows overlap heavily (closer to one or two independent windows than nine); 10 draws per opening leave a few points of Monte Carlo error near 80 percent; the grid steps by 10 above 30 percent, so "40" means between 30 and 40; the P2 bootstrap adds no count noise to the injected effect and extends the trend right after November 2023 although P2 starts 13 months later.
- **Plausible effect sizes:** no literature benchmark is given in this draft; one, with citations, is to be added before approval so Leonel can judge whether MDEs of 25 to 50 percent are useful.

## 11. Sensitivity checks (all pre-specified)

1. Pre-period from January 2021 (the primary start is January 2022).
2. The other counterfactual for the drift (section 8, item 3).
3. Anticipation window: drop September to November 2023. Drop December 2023.
4. Day-exact disruption window; datable 2024 outage months dropped from P1; other datable 2024 citywide shocks dropped (section 8).
5. P2 as calendar 2025 (once a P2 test exists, section 5).
6. Corridor within 1 km instead of 500 m; 500 m catchments.
7. Donors crossed by the Central Norte MetroBus dropped (pool B without Ponceano and Cotocollao, J = 7; route 2 cannot reach 10 percent there). Donors crossed by the Trolebús or Ecovía are already out of the primary pool. The terminal-catchment sensitivity is not defined for pool B (section 4) and waits for Leonel's decision.
8. Crashes at exact points shared by 3 or more records dropped.
9. Months recorded in a different block (October to December 2021, October 2024, August 2025) dropped; October 2025 dropped for vehicle-type outcomes.
10. The other inference route (section 9), and the Poisson fixed-effects model.
11. The confirmatory estimator on levels and on log(count + 1) instead of the index.
12. Leave-one-donor-out (J = 8; route 2 cannot reach 10 percent there).
13. Quarterly instead of monthly.
14. Full window (disruption included), labelled not clean.
15. Volume screen at a different threshold, if Leonel changes it or asks for a sensitivity (section 13, question 1).

**Proposed, not adopted [decision]:** following the fast-road diagnostic (section 4), (a) pool B without Tumbaco and Cumbayá, and (b) all outcomes recounted without crashes whose street names a fast road, in both the treated areas and the donors. Leonel asked for the diagnostic only, with no exclusion; these are listed for his decision, and neither has been run.

## 12. What will be reported

- The confirmatory result (section 3): the effect as a percentage of the counterfactual, its p-value under the chosen route with the smallest attainable p-value, the other route as a check, the test-inversion confidence set, the in-time fake-effect distribution for the same design, and whether the estimate's absolute value exceeds the largest absolute fake effect (section 8).
- The pre-period fit (treated against synthetic), the donor weights and the full placebo distribution. For pools B and C they are computed on the pre-period (section 10, candidate designs): the weights are close to equal, so the four donors with many crashes on named fast roads carry about as much weight as the others.
- Secondary windows, outcomes and units, and the 1 to 2 km ring, with rank p-values as diagnostics and no significance claims.
- The sensitivity checks of section 11 and the recording-composition diagnostic of section 8.
- Station-by-station, pedestrian and vehicle-type results as descriptions only.
- Everything in aggregate; no crash-level data leave the machine; main findings shared with the AMT.

## 13. Open questions for Leonel

**Choice rule for the confirmatory design (Leonel, 2026-09-27; written into this plan before the candidate runs, as he asked; it was committed together with the tables in `0210ed2`, so git alone cannot show the order; record: `docs/correspondence/2026-09-27_road_safety_design_decisions.md`).** Among the designs in the candidate power table (pre-period only, January 2022 start, 1 km catchments, P1, 15 fake placements), the primary design is the one with the smallest 5 percent MDE for a fall in injury or fatal crashes, among designs that pass the 15-placement size check at both 5 and 10 percent. Ties, or MDEs within 5 percentage points of each other, go to the design with fewer untestable assumptions, in this order: donor designs first, then the gradient design.

**What the choice rule gives (applied 2026-09-28 to `road_safety/output/power/candidates/comparison.csv`; section 10).** Six designs for injury or fatal crashes pass the 15-placement size check at both levels:
- **40 percent fall at 5 percent:** the earlier pool O2 with DID weights, and the gradient design with conformal inference.
- **50 percent:** O1 (both weightings), O2 with synthetic-control weights, and pool B with synthetic-control weights.

Whether the urban-street injury or fatal outcome counts as "injury or fatal crashes" under the rule is not settled. If it does, O2 with DID weights on that outcome also passes both checks and reaches 40, a tie between two donor designs that the rule does not break; the gradient's urban-street row is at 50, so the gradient reading is unchanged.

The two designs at 40 tie. Read literally, the rule gives the tie to donor designs first, so it picks **O2 with DID weights**. But O2 is an earlier option pool (parish parts beyond 2 km) that you replaced with pool B on 2026-09-27. If the earlier pools do not count as candidates, the rule picks the **gradient design with conformal inference** (40, against 50 for pool B with synthetic-control weights, more than 5 points apart). The placebo-corridor route of the gradient design has not run yet (road layer not in the store).

**How firm this result is** (methods referee, 2026-09-28).
- **The ranking.** The MDE grid steps by 10 above 30 percent, so 40 against 50 is one grid step. With 150 runs the Monte Carlo standard error near 80 percent power is about 0.03, and O2's two weightings differ by the same step. At this resolution, O2 with DID weights, the gradient design and pool B with synthetic-control weights (40 to 50) cannot be ranked.
- **The filter.** The size check is close to mechanical (section 10).
- **A weakness O2 and the gradient share.** O2's donors are parish parts that border the 2 km line, next to the ring the gradient uses as its control.
- **The referee's verdict.** Neither O2 with DID weights nor the gradient design is yet a sound confirmatory choice.


**The choice rule on the complete table (2026-10-01).** The placebo-corridor rows are now in `comparison.csv`, all "not testable", so none is eligible. The result is unchanged: **O2 with DID weights** if the earlier pools count, otherwise **the gradient design with conformal inference**; both reach 40 at 5 percent.

**[decision]** Whether O2 counts under the rule, and whether the urban-street injury rows are eligible. Also: whether to adopt the proposed fix of the fast-road flag (section 4); whether the plan should fix the order of road pieces within an avenue for the placebo rule; and whether to run the 500 m-strip variant of the placebo design. Separately, no candidate detects a fall in injury or fatal crashes smaller than 30 to 40 percent at 5 percent, so the concern that led to this round is not resolved. You may also want to reconsider the confirmatory outcome or level before approval.

1. **Comparison pool.** Pool B follows the recorded beyond-2-km rule. Historical open questions concerned the fixed volume screen, Central Norte-crossed donors and fast-road contrast. Observed crash means/shares are redacted; no exclusion was made on that diagnostic.
2. **Confirmatory window:** P1 (proposed) or P2. P2 needs a new route 1 design and a power check first (section 5).
3. **Confirmatory unit and outcome** (route 1, pool B, 2022 start, MDE fall / rise at 5 percent, synthetic-control weights; DID weights): 1 km catchments and all crashes (proposed; 50 / 25; more than 50 / 30), or the corridor within 500 m (your primary corridor distance, decision 2; more than 50 / 30; more than 50 / 40), or injury or fatal crashes in the 1 km catchments (closer to harm and less exposed to the recording of minor crashes; 50 / 40; more than 50 / 40; with pool B it drifts about as much as all crashes from 2022, and more from 2021) (`road_safety/output/power/pool_b/comparison.csv`).
4. **Inference route and level:** route 1, synthetic control with conformal inference and the level-shift statistic (5 percent reachable; recommended), or route 2, SDID with the in-space rank test (only "treated ranks first" reachable: p = 1/10 with pool B, 1/8 without the Central Norte donors; not yet run for pool B); or report p-values without significance claims.
5. **Drift:** which counterfactual is primary (section 8, item 3). With the 2022 start the drift rule rests on 3 fake effects (section 8, item 2).
6. **Terminal catchments:** how to define the terminal-catchment sensitivity for a pool in which six of nine donors lie north of the line (section 4).
7. **Citywide shocks in 2024:** the dates of any curfews, fuel-price changes or other events you consider relevant (section 8).
8. **Licence.** Confirm the GeoQuito terms yourself (pages in the provenance note). The BRT rule is settled (Trolebús and Ecovía crossed excluded, Guamaní counted as crossed, Central Norte as a sensitivity).
9. **Post-opening rows in the derived file.** 01 and 02 assign every crash, including post-opening ones, to cells, bands and stations, as the Step 1 instruction asked ("assign each crash"), without summarising them. The referee considers this close to "loading by area" and recommends leaving those columns empty from December 1, 2023 until approval, or recording your permission in writing.
10. **Exposure.** Using Waze congestion from the congestion module as exposure would adjust for a likely mediator (traffic that the metro may have reduced) and change the estimand from crash counts to crash risk; Waze congestion also measures delay, not volume. Not used; for your decision.
11. **Provider answers before approval:** the AMT questions in the audit, and from Metro de Quito the construction, reopening and trial-run dates and the feeder routes.
12. **SICARIATO flag:** confirm exclusion of flagged entries from outcome counts; frequency withheld.
