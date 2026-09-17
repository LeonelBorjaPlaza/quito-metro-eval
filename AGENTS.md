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

2026-09-17: Phase A is complete. Read the provider documentation, complete paper text and all 22 paper CSVs; created both requested text conversions; installed the available approved Posit Linux binaries; verified Parquet access and the DuckDB H3 fallback; wrote `reports/00_repo_state.md` and `reports/00_source_checks.md` with reproducible scripts. No new treatment effect was estimated. The paper and its results remain frozen, and Data/ is excluded from commits.

Read `reports/00_source_checks.md` before starting Phase B and carry its unresolved conflicts into the strategy memo. Important findings include mismatched paper/CSV p-values and SDID window labels, swapped monitor distances in a frozen descriptive CSV, an empty station shapefile, a 146.1 m San Francisco coordinate discrepancy, conflicting severe-event definitions, and missing observation/quality fields in the Waze schema. Use the station GPKG and the supplied monitor coordinates. Use DuckDB for data access; Arrow had a shutdown fault in one mixed-package session. h3jsr is unavailable because V8 lacks libnode.so.127; use the verified DuckDB h3 extension. synthdid and augsynth are unavailable from the requested repository. Phases B, C, D and the review packet are pending; no sample or analysis plan has been created.
