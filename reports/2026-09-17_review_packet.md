# Quito Metro congestion module: review packet

17 September 2026. Two-page reading summary. Review the proposed choices; do not authorize estimation implicitly. No new post-opening effect was estimated. The authors must write docs/analysis_plan.md after review.

## Page 1: state and evidence

The frozen paper, provider DOCX, text conversions and 22 paper CSVs are present under docs/. Spatial inputs include MetroStations.gpkg, MetroLine.gpkg and Distancia_REMMAQ_Metro.gpkg. R, DuckDB/H3, data.table, sf and ggplot2 work. Arrow has a shutdown problem; h3jsr, augsynth and synthdid remain unavailable. Data/ is ignored and uncommitted; reports/waze_sample.csv is committed. Reports, scripts and figures are under reports/, Scripts/Congestion/ and Output/Waze/. Both ten-number audits pass. The authoritative [May 31 PDF](../docs/paper/Underground-relief.pdf) reports Centro PM2.5 P1 -12.2%, p=0.011, versus Belisario -6.0%, p=0.729. These are inherited pollution results, not traffic estimates.

Five inventory facts from [waze_inventory.md](waze_inventory.md):

| Fact | Consequence |
| --- | --- |
| 15,080,765 rows collapse to 5,546,323 distinct keys. | Exact copies must not reweight space. Clean all-road/fast-road blocks contain 1,314,213/852,218 keys. |
| All 2,469 polygon IDs and boundaries validate as H3 resolution 8; only 1,729 cells appear. | Drop 740 never-observed cells. |
| Delivery is monthly with 24 hours and six stacked speed-class blocks, without weekdays, counts or flags. | No weekday-only outcome or direct penetration test is possible. |
| March 2025 is missing; February/April look incomplete. | Authors mask all three months, rather than zero-fill them. |
| S=100-T+TJ/100 fails by up to 4.170018 percentage points. | Keep speed_ratio dropped, but do not claim exact delivered redundancy. |

Five descriptive findings from [waze_descriptives.md](waze_descriptives.md). Figure filenames below resolve under **Output/Waze/descriptives/**.

| Finding | Figure |
| --- | --- |
| Another 92 pre-empty REST cells are excluded. Retained groups: CENTER 7, BELISARIO 7, CORRIDOR 34, RING 56, REST 1,533. There are 271 saturated donors at threshold 20; 555 at 12. | map_saturated_donors.png |
| Broad REST peak presence is 0.4377 in 2022, 0.4529 in Jan-Nov 2023, 0.5222 in usable 2025. Saturated presence stays near 0.98; its trend mainly reflects conditional intensity. | rest_decomposition.png |
| Pre peak correlations with saturated REST are 0.9454 for CENTER and 0.9342 for BELISARIO, despite large level differences. The 2020 trough and recovery complicate a 2019 start. | pre_donor_comparison.png; series_tci_osm_ratio.png |
| All 2,272 negative-spread keys are in REST, including 294 in saturated donors. Flagged primary TCI exceeds adjacent-month levels unusually often; 86.4% of within-cell-hour comparisons exceed their reference deviation. | negative_spread_comparison.png |
| CENTER free flow is 41.1820/39.4011 km/h in Nov/Dec 2023 and 47.1863/43.0984 in Aug/Sep 2024. Fast roads have 8,290 keys absent from all-road support. | freeflow_diagnostic.png; fast_road_support.png |

Open figures first in this order: **series_tci_osm_ratio.png**, **rest_decomposition.png**, **map_saturated_donors.png**, **negative_spread_comparison.png**, **freeflow_diagnostic.png**, then **pre_donor_comparison.png**. Opening is dashed, disruption grey and the delivery gap amber on calendar plots. These figures contain no fitted post-opening effects.

## Page 2: recommendations, caveats and handoff

The [strategy memo](2026-09-17_strategy_memo.md) supplies options and reasons; the following are recommendations, not locked decisions.

**Units.** Start with the symmetric seven-cell neighborhoods around rounded published monitor points. A single-cell test needs precise coordinates; UNESCO geometry is absent. Prespecify a San Francisco station-buffer sensitivity and its Belisario analog.

**Donors.** Start with 271 saturated REST donors, retain threshold 12 and all eligible REST as sensitivities, and always exclude RING. Road-length/functional-class and altitude/density matching need unavailable inputs. Coverage alone does not cure contamination.

**Pre period.** Prefer January 2022-November 2023, with 2019 as a stability sensitivity. Request closure/reopening logs: the observed construction-era movements do not identify a local construction cause.

**Hours/outcomes.** Use one combined peak primary TCI outcome, bins 7,8,17,18, with separate morning/evening secondary descriptions. Keep severe TCI and conditional jam speed secondary; TCS metres is a proxy. Night 0-4 is diagnostic, not automatically unaffected. All days remain included.

**Estimator/inference.** Propose augmented synthetic control with pre-only blocked validation, regularization and dependence-aware conformal inference. Use SDID as robustness, not an automatic citywide transfer. Jointly compare Centro and Belisario; different significance levels do not prove different effects. Spatial placebos need comparable footprints and dependence safeguards. A fake 2022 opening would test earlier instability, not validate later identification.

**Calendar.** P1 is December 2023-August 2024; exclude all September-December 2024. Usable P2 is January and May-December 2025. Preserve P1, P1-plus-P2 and full-available-window estimands; P2 alone is secondary. Never fill the delivery gap. Waze P2 extends beyond the paper's.

**Threats.** Seek provider correction before causal interpretation. Freeze donor eligibility using pre coverage; do not zero-fill deleted flagged rows. Free flow affects jam detection, severity and speed classes, not primary TCI's direct denominator. Night-reference changes, construction, spillovers and lingering energy-crisis effects remain threats.

**Power.** [Pre-only calibration](waze_preperiod_power.md) gives rough detectable reductions of 1.681-1.852 percentage points under serial-noise resampling and 3.757 under historical donor-placebo scaling. These benchmark nine-month responses, not achieved estimator power; no December 2023-or-later outcomes enter.

**Tiers.** Confirmatory: Centro and Belisario against a shared distant pool, with joint inference. Citywide: drop the causal average without external-city donors; a global test of local patterns is a different claim. Exploratory: maps require fixed exposure rules, uncertainty, unsupported-cell labels and multiplicity control.

**Contradictions/artifacts to retain.** PDF/CSV p-value conflict P1 and SDID-label conflict P3 remain author items; monthly/weekly calendars and weekday coverage differ. Delivery problems include duplicates concentrated by cell, empty/pre-empty cells, the gap, missing diagnostics, failed speed identity, negative auxiliary ratios, severe persistence above 100, possible primary contamination, nonnested fast/all support, conflicting severe definitions, and the documented omission of exactly 40 km/h from the two-class split. Fast roads are speed classes, not arterials. Pandemic recovery, free-flow volatility and night/peak differences are visible; a construction signature remains unverified.

Spatial caveats are the empty shapefile versus 15 GPKG stations, San Francisco's 146.1 m coordinate discrepancy, rounded monitor points, nine spatial monitors versus eight in the paper, nearest-station rather than line HubDist, and 117 centroids outside the requested box although every polygon intersects it. CRS/Z/M handling is documented; upstream layer versions, UNESCO, cell altitude/density and road lengths are unavailable. Delivered aliases and integer month dates differ from the dictionary; the inventory maps them. The CSV index is merely serialization; CSV/Parquet verification passed. The paper's gas finding is not a universal null: later SO2 is positive. Package limitations remain as stated above. No frozen source was repaired.

**Questions for review.** Ask Víctor and Juan Camilo to repair the gap, explain duplication/nonnesting/flagged values, confirm missing-versus-zero, severe and free-flow definitions, and supply counts, flags, weekday profiles, timezone and denominators. Authors must choose geometry, donor threshold, estimator/inference and flagged-data sensitivity; supply precise coordinates and construction logs; retain P1/P3 conflicts; and decide whether external-city data merit a separate tier.

**Reproduce.** Run `Rscript Scripts/Congestion/02_run_phase_c.R`, then `Rscript Scripts/Congestion/03_preperiod_power.R`, from the repository root. The first command reuses existing deduplicated files and runs the fresh-session audit. No new installations are needed. AGENTS.md preserves the instructions and amendments.

**Commit record.** `eaf0adf`: Phase A orientation/tooling. `16fbfa9`: Phase B inventory/H3/audit. `84cf7e2`: Phase C descriptives/coverage/artifacts. `1602fb6`: Phase D options/pre-only power. The packet handoff commit is titled **Review packet: hand off Waze evidence, options, and session status** and contains this file; its hash is available with `git log -1 --format=%h -- reports/2026-09-17_review_packet.md`. The seed commit predates this work. No commit includes Data/.
