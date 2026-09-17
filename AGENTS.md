# Quito Metro congestion module

The following sections reproduce sections 0, 1 and 2 of the authors' Phase 1 instructions verbatim. The session amendments and status below supplement them.

## 0. Ground rules

1. Read before you act. This repository starts almost bare: the raw Waze delivery under Data/Waze/raw/, the provider's documentation docs/Documentacion_Indicadores_Waze.docx, the paper as docs/paper/Underground-relief.pdf, and the paper's result tables under docs/paper/results/. Read everything in docs/ first. Convert the .docx documentation to docs/waze_documentation.md with pandoc or python-docx so it is greppable, and keep the original. If any other context files exist in docs/ (a CLAUDE.md, a congestion_context.md, a data description brief), read them and treat them as binding. Then create AGENTS.md at the root carrying sections 0, 1 and 2 of this prompt verbatim, so the rules survive into later sessions.
2. HARD RULE. Do not estimate any post-opening treatment effect. No ATT, no event study coefficient dated after November 2023, no synthetic control or SDID fit that uses post-opening months, no regression of any outcome on a post indicator. Descriptive statistics, plots of raw series across the whole period, coverage diagnostics, and pre-period-only analyses are allowed and expected. If a step you are about to take would produce a post-opening estimate, stop and note it in the memo instead.
3. The air quality analysis is finished and frozen. Do not modify anything that belongs to it.
4. If anything in the data contradicts the facts below or the facts in the repository (dates, column definitions, coverage, hexagon counts), do not adapt silently. Record the contradiction in the memo and proceed with the version the data supports, labeled as such.
5. Language: R with arrow, data.table, sf, ggplot2 for the work; DuckDB is fine for heavy aggregation over the Parquet. Ask before installing anything outside arrow, duckdb, data.table, dplyr, sf, h3jsr, ggplot2, patchwork, fixest, synthdid, augsynth. Write all prose in plain English, active voice, no em dashes, no bullet lists inside the memo where a sentence will do.
6. Outputs go to Output/Waze/. Reports go to reports/. Scripts go to Scripts/Congestion/ and must run top to bottom from a clean session.

## 1. Facts to inherit from the paper (verify against docs/paper/, do not re-derive)

The paper is "Underground Relief: The Air Pollution Effects of Quito's First Metro Line" by Borja Plaza and Quintero. It is at docs/paper/Underground-relief.pdf. Extract its text with pdftotext -layout into docs/paper/Underground-relief.txt so you can grep it, and read the methods, results and mechanism sections in full before touching the data. The paper's own output tables are in docs/paper/results/: results_all_pollutants.csv and results_primary_specs.csv hold the headline estimates, descriptives_treatment_timeline.csv holds the calendar, and the trajectories_*.csv and donor_weights_*.csv files show how each synthetic control behaved. In your memo, report the exact numbers you find there for the headline PM2.5 effect at the Centro monitor, the Belisario contrast, and the null results for the other pollutants, and check that the PDF and the CSVs agree. Do not quote numbers from this prompt.

What the module inherits:

- Metro Line 1 opened on Friday, December 1, 2023. In the monthly Waze panel, treatment turns on in December 2023.
- Post-opening blocks: P1 runs from December 2023 through August 2024. The disruption block runs September through December 2024 (national electricity rationing, diesel generators, wildfires around Quito) and is excluded from effect estimation in the paper. P2 runs January through December 2025.
- The paper's finding is a localized PM2.5 reduction at the Centro monitor inside the historic center, with no comparable effect at the Belisario monitor, which is similarly close to the line but outside the center. The interpretation is destination-based mode substitution. The paper explicitly leaves the direct traffic channel untested. That is what this module tests.
- The confirmatory test therefore mirrors the paper: congestion at the hexagons around the Centro monitor versus congestion at the hexagons around the Belisario monitor, each against a donor pool of hexagons away from the line.
- Peak-hour windows used in the paper are weekday 7:00 to 9:00 and 17:00 to 19:00. Confirm this in the source.

## 2. Facts about the Waze delivery (verify against docs/waze_documentation.md and the data)

- Two deliveries from the IDB Geo Indicators Hub: grids_polygons.csv (H3 resolution-8 cell ids and geometries, expected 2,469 cells) and grids_quito_hourly_2019-2025, a monthly panel with an hour-of-day dimension covering January 2019 to December 2025, delivered as both CSV (about 5 GB) and Parquet (under 1 GB). Use the Parquet. Check once that the CSV and Parquet agree on row count and a sample of values, then ignore the CSV.
- What the authors requested in July 2026, for the delivery-versus-request comparison: all H3 resolution-8 cells inside the bounding box latitude -0.45 to 0.05, longitude -78.62 to -78.30; weekly frequency; two aggregations, one for weekday peak hours (Monday to Friday, 7:00 to 9:00 and 17:00 to 19:00) and one for all hours and all days; January 2019 start; the full indicator suite (TCI, TCI ratio, TCS, TCS ratio, TCP, their severe versions, free-flow speed, speed measures) plus diagnostic fields (observation counts per cell, free-flow series).
- The delivery is monthly with hour of day, not weekly. Confirm whether any day-of-week dimension exists. If it does not, the peak-hour block will average over all days of the week including weekends, and the memo must say what that implies.
- Roadtype is a stacked row dimension with six values. Every analysis filters exactly one block. Default is all_roadtype. The block for large roads is the candidate for an arterial-only test.
- Outcome hierarchy already decided by the authors: tci_osm_ratio is primary, tci_severe_osm_ratio and jam_speed_ratio secondary. speed_ratio is dropped because it is a deterministic function of the other two; verify that identity in the data and report it.
- Hygiene: recode sentinel values -998 and -999 to NA. Keep only rows with flag_corr_type == 0 if that column exists. Determine whether the panel is dense (every cell by month by hour present) or sparse (rows only where a jam was observed). If sparse, an absent record means zero congestion, not missing, and every aggregation must be built on the completed panel.
- Free-flow speed is re-estimated monthly per segment from 1:00 to 2:00 a.m. observations. This is a known threat: if the road network or the night traffic environment changed at opening, the denominator of every ratio moves with it.
- The severe congestion indicators use a speed threshold of 40 percent of free flow according to the provider's email. The provider has not confirmed the exact definition. Check whether the data documentation settles it and flag if not.

Provisional spatial groups, to be replaced by the formal definition in the analysis plan:

- CENTER: cells within 1 km of San Francisco station (lat -0.2203, lon -78.5158). Also identify the single cell that contains the Centro air quality monitor, using the coordinates in Data/spatial/.
- BELISARIO: cells within 1 km of the Belisario monitor coordinates in Data/spatial/. Also identify the single cell containing the monitor.
- CORRIDOR: cells within 1 km of any other Line 1 station.
- RING: cells between 1 and 2 km of any station, held out of the donor pool as a spillover buffer.
- REST: everything else inside the delivered grid.

Data/spatial/ holds three layers copied from the air quality repository: MetroStations (shapefile and gpkg, the Line 1 stations), MetroLine.gpkg (the alignment) and Distancia_REMMAQ_Metro.gpkg (the REMMAQ air quality monitors, with their distance to the line). Use these for every station and monitor coordinate and record their provenance. Confirm that the San Francisco station coordinates above match the layer and that the Centro and Belisario monitors are present in it. Only if a monitor is missing from the layer, list its coordinates as an open question for the authors.

## Session amendments

The authors approved the five-phase implementation plan on 2026-09-17 and directed this turn to complete Phase A. Commit at the end of each phase with a descriptive message. Never commit anything under `Data/`. Do not create `docs/analysis_plan.md`; the authors will write it after review.

Install missing allowed packages using Posit Package Manager Linux binaries at `https://packagemanager.posit.co/cran/__linux__/<lsb_release -cs>/latest`, with no source compilation. Record failures in `reports/00_repo_state.md` and use substitutes from the allowed list where possible. Ask before installing packages outside the allowed list, including missing dependencies unless separately approved.

On 2026-09-17 the authors also approved binary installation of these dependencies: assertthat, bit, bit64, curl, dreamerr, Formula, generics, geojsonsf, geometries, jsonify, jsonlite, numDeriv, pillar, pkgconfig, purrr, rapidjsonr, sandwich, sfheaders, stringi, stringmagic, stringr, tibble, tidyr, tidyselect, utf8, V8, and zoo.

`reports/waze_sample.csv` is a review artifact. The `.gitignore` exception `!reports/waze_sample.csv` must allow it to be committed when Phase B generates it. All other CSV files outside `docs/paper/results/` stay ignored.

## Status

### Author decisions accepted before Phase B, 2026-09-17

These decisions supersede conflicting statements in the verbatim sections above and in the historical Phase A reports. The approved Phase B work includes inventory, review sample, independent ten-number audit and a phase-end commit. Do not begin Phase C in this turn.

The May 31 PDF postdates the CSV export. Cite paper numbers only from the PDF. Use the paper CSVs only for trajectories and donor weights from this point forward. Conflicts P1 and P3 remain author items; do not resolve them or rerun the historical Phase A CSV reconciliation.

The monthly calendar is fixed: P1 is December 2023 through August 2024; disruption is September through December 2024, including all of September deliberately; P2 is January through December 2025. The three paper estimands map to P1 only, P1 plus P2, and the full window. The memo must note that Waze P2 is longer than the paper's P2.

Use hour bins 7 and 8 for morning peak, and 17 and 18 for evening peak, pending author confirmation. The night block is 22 through 5. Explicitly record the included bins in every output.

Centro and Belisario coordinates are rounded to 0.01 degrees, coarser than a cell. Do not identify a verified single monitor cell. For Phase C CENTER and BELISARIO, use the cell containing each published point plus its six H3 neighbors, k-ring 1, and report their IDs. Phase B inventory and review sampling use these same neighborhoods for continuity. Preserve the original station/monitor buffer candidates separately. A single-cell analysis remains conditional on precise monitor coordinates in the memo.

Free flow does not divide tci_osm_ratio. It enters through jam detection, the severe threshold, speed ratios, and the delivered free-flow roadtype classification. Treat the threat through those channels.

With no counts or flags supplied, use the share of cell-hours with any congestion and TCS spread as indirect penetration proxies. Counts have been requested from the provider. Do not call delivered row counts observations of vehicles, users, or underlying jam events.

Call roadtype=large 'fast roads', not an arterial or functional road class. Use MetroStations.gpkg and DuckDB throughout. Keep source layers unchanged.

2026-09-17: Phase A is complete. Read the provider documentation, complete paper text and all 22 paper CSVs; created both requested text conversions; installed the available approved Posit Linux binaries; verified Parquet access and the DuckDB H3 fallback; wrote `reports/00_repo_state.md` and `reports/00_source_checks.md` with reproducible scripts. No new treatment effect was estimated. The paper and its results remain frozen, and Data/ is excluded from commits.

The Phase A handoff is `reports/00_source_checks.md`; its historical CSV comparisons remain evidence of conflicts, not authoritative paper estimates. Use the station GPKG and DuckDB. h3jsr is unavailable because V8 lacks libnode.so.127; use the verified DuckDB h3 extension. synthdid and augsynth are unavailable from the requested repository.

2026-09-17: Phase B is complete. `reports/waze_inventory.md` and `reports/waze_sample.csv` are regenerated by `Scripts/Congestion/01_inventory.R`, which runs a separate ten-number raw-data audit. All ten audited numbers match. The CSV/Parquet one-time count and 256-row comparison passes. There are 15,080,765 raw rows but only 5,546,323 distinct keys; repeated keys are exact copies. All 2,469 polygon IDs are valid resolution-8 cells and boundaries match H3. Only 1,729 cells and 83 months appear in the panel. March 2025 is wholly missing, and February/April 2025 show suspicious proxy declines. Preserve March as a delivery gap, not zero congestion; complete other absent cell-hours as zero congestion under the authors' sparse-panel convention. Jam speed and free flow remain undefined for absent records. No analysis plan or post-opening effect has been produced.

The delivered speed-ratio identity fails by up to 4.170018 percentage points, despite near-identical free-flow aliases. Keep the author-approved outcome hierarchy and record this failure in the memo. Some auxiliary spread/Waze ratios are negative after exact sentinel recoding, and severe persistence exceeds 100; no silent trimming rule has been chosen. Direct penetration counts remain unavailable. The indirect proxies use positive TCI cell-hour coverage and nonnegative TCS metres.

Read the inventory before Phase C. Spatial metadata are in `Output/Waze/inventory/cell_groups.rds`: CENTER and BELISARIO each have seven cells around their published-point seeds, with no verified physical monitor-cell claim. Remaining station buffers define CORRIDOR (34 cells), RING (56), and REST (2,365). Every cell is assigned once.

### Author decisions accepted before Phase C, 2026-09-17

Phase B is accepted. Proceed through Phase C, Phase D and the review packet without stopping, committing each phase. This supersedes the earlier stop after Phase B. Deduplicate once into distinct all_roadtype and large Parquet blocks under Data/Waze/parquet/ and read only those blocks thereafter. Retain original key multiplicity for a singleton concentration table.

Drop all 740 never-observed cells from every analytic group and aggregate. Flag cells with no record during January 2022 through November 2023, and exclude them from every REST series. Report both exclusions by group. Saturated REST donors have at least 20 delivered hour slots per month on average over those 23 pre months. Show all eligible REST and saturated REST in every REST series; also report the count at threshold 12.

Treat February, March and April 2025 as a delivery gap, with every cell's outcomes NA and shaded on time-series figures. Usable P2 is January 2025 and May through December 2025. Keep the author-approved P1 and disruption calendar unchanged. Morning bins are 7 and 8, evening bins 17 and 18, and night bins now 0 through 4, superseding the earlier night block. Give cells equal weight.

Use tci_osm_ratio, tci_severe_osm_ratio, avg_jam_speed_ratio and tc_spread in metres. Free flow remains a diagnostic, not an outcome. Compare primary TCI for the 2,272 all_roadtype negative auxiliary spread-ratio rows with adjacent months at the same cell-hour. Decompose REST peak TCI into record presence and intensity conditional on presence. Do not interpret either proxy as direct user or jam counts. Preserve the frozen Phase B report and its historical definitions.

2026-09-17: Phase C is complete. The two deduplicated blocks are stored locally under Data/Waze/parquet/ and remain untracked. The fixed population has 1,637 cells: CENTER 7, BELISARIO 7, CORRIDOR 34, RING 56 and REST 1,533. REST loses 740 never-observed cells and 92 additional cells without pre-period records. There are 271 saturated donors at threshold 20 and 555 at threshold 12. The descriptive report, figures, fixed eligibility flags, completed cell-month summaries and independent ten-number audit are under reports/ and Output/Waze/descriptives/. All ten audited numbers match. The February-April 2025 mask, equal-cell aggregation and presence-intensity identity were verified.

New Phase C cautions: all 2,272 negative auxiliary spread-ratio keys are in REST, including 294 in saturated donors. Primary TCI is unusually elevated on flagged rows relative to adjacent months; this is consistent with contamination, not proof of its cause. Also, 8,290 fast-road keys across 280 cells have no corresponding all-road key. The author-approved all-road zero-completion rule is retained for description, but this nesting failure requires provider clarification before causal use. No post-opening treatment effect has been estimated.

2026-09-17: Phase D is complete. `reports/2026-09-17_strategy_memo.md` lays out options, evidence and recommendations, with unresolved provider and author questions. It cites paper estimates only from the May 31 PDF and preserves P1/P3 conflicts. `Scripts/Congestion/03_preperiod_power.R` reads only January 2022-November 2023 outcomes and generates `reports/waze_preperiod_power.md` plus a planning RDS. The rough nine-month detectable-reduction calibrations are 1.681 percentage points with length-3 circular blocks, 1.852 with length-6 blocks, and 3.757 in the donor-cell historical stress calibration. These are not achieved estimator power or treatment effects. No docs/analysis_plan.md has been written. The review packet is next.
