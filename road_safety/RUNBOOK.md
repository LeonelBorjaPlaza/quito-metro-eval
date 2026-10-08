# road_safety runbook

## Corrected Amendment 4 Stage B: January 2022 primary

Leonel directly authorized the correction on 2026-10-07 after seeing the full
2021-start table. The correction record is `docs/amendment4_start_correction.md`;
the prior amendment is preserved as `docs/analysis_plan_amendment_4_original.md`.
No new merge is required for this authorized execution.

From `road_safety/`, with the pinned library available:

```bash
Rscript code/39_amend4_stage_b_2022.R
```

In a fresh checkout, first run `Rscript code/00_setup.R`. Script 39 rebuilds from
raw, fits the January 2022 window separately and reuses the committed original
`output/amendment4_stage_b/estimates.csv` as the 2021-start sensitivity. Do not
rerun script 38 to produce the sensitivity. The historical script now reads the
preserved original amendment; its analysis is otherwise unchanged.

Only requested descriptive fits are added: pedestrian quarterly models in each
band and inner-band typology/severity models. The existing inner pedestrian fit
is reused for ATROPELLO. Release files in `output/amendment4_stage_b_2022/` are
`estimates.csv`, `quarterly_all_crashes.png`,
`quarterly_pedestrian_descriptive.png`, and `descriptive_types_severity.csv`.
The updated note is `../reports/road_safety/2026-10-07_amendment4_stage_b_2022.md`.
Exact outputs, release-support decisions and fit diagnostics remain ignored in
`data/derived/amendment4_stage_b_2022/`. The one-run marker is separate from the
original run. The independent verifier uses a fresh checkout and its own marker.

The maker's initial corrected run stopped before fitting VOLCAMIENTO, whose
common-post coefficient was unavailable. Leonel authorized retaining that row
as "Not estimable" and finishing only severity. The maker uses
`Rscript code/40_amend4_finish_severity.R` once against the existing saved fits;
it checks that all prior fit objects, the paired-start table and both event
figures remain unchanged. Script 39 now incorporates this authorized disposition
for a fresh independent reproduction. Never run 39 again in the maker's checkout.
The descriptive table also has a readable Markdown version with the requested
one-line explanation for VOLCAMIENTO.

## Approved Amendment 4 Stage B (2026-10-07)

Leonel confirmed the approved amendment is on main at `4abdbe8` and requested
execution once. Its content is identical to worktree commit `b0a6ea4`
(SHA-256 `fe1187f532aeb687c7933d0714899c7b7b4c6d3d58bc54845a54da4956daa0ee`).

Execution plan: validate the locked workbook and frozen geography registries;
check delivery completeness; construct full monthly panels; run only the approved
main models, primary checks and quarterly event studies; release the seven-row
table, quarterly figure and one-page note. Review code before execution, commit
locally, then independently verify the same specifications from raw on the
committed SHA. Methods and claims reviews precede reporting. No merge or push.

From `road_safety/` in a fresh checkout:

```bash
Rscript code/00_setup.R
Rscript code/38_amend4_stage_b.R
```

An existing checkout with the pinned library needs only the second command.
Stage B reads the crash workbook directly and the committed Stage A registries;
it does not need earlier crash-derived data or run earlier model scripts.
It checks input hashes and uses the approved frozen grid without repeating
selection. The `fit_started` marker in ignored `data/derived/amendment4_stage_b/`
prevents a second maker run. A fresh verification checkout has its own marker.

Release files are `output/amendment4_stage_b/estimates.csv`,
`output/amendment4_stage_b/quarterly_event_study.png`, and
`../reports/road_safety/2026-10-07_amendment4_stage_b.md`.
Exact panels, assigned records, model objects, event coefficients, input hashes,
delivery checks and omission diagnostics stay ignored under
`data/derived/amendment4_stage_b/`. A missing delivery month, failed input check,
unavailable coefficient or nonconverged fit stops execution for review.

The instructions below describe historical stages and are not the Stage B run order.

## Amendment 2 pre-period-only branch

Do not run the old all-date build for this task. From `road_safety/`, run:

```bash
Rscript code/00_setup.R
python3 code/13_amend2_extract.py
Rscript code/19_amend2_geography.R
Rscript code/14_amend2_build.R
Rscript code/20_amend2_predictors.R
Rscript code/23_amend2_parish_roads.R
Rscript code/15_amend2_forecasts.R
Rscript code/18_amend2_share_event.R
A2_CALIBRATION_MODE=pilot Rscript code/21_amend2_count_calibration.R
A2_CALIBRATION_MODE=null A2_REPS=200 A2_CORES=6 Rscript code/21_amend2_count_calibration.R
A2_CALIBRATION_MODE=power A2_REPS=200 A2_CORES=6 Rscript code/21_amend2_count_calibration.R
Rscript code/22_amend2_calibration_summary.R
Rscript code/17_amend2_packet.R
```

Run long calibration stages with shell redirection to `../logs/` in a background
job. The runner checkpoints each complete replication in ignored derived storage.
A fingerprint covers code, input objects, package versions and the rank grid;
resuming a changed experiment cannot silently reuse old results. Pilot and
production checkpoints are separate. Stage wall times and summed replication
worker times are recorded separately. See `docs/amendment2_continuation_execution.md`
for the prespecified simulation, conditional trend-proposal evaluation and
exact decision/grid early stopping rules.

These steps rebuild from the committed raw symlinks, offline. The extractor
materializes only January 2021–November 2023 crash, linked-vehicle and rainfall
records, routing by date/identifier before decoding outcome fields. Scanning ZIP
bytes and routing metadata is necessary to select these records; excluded outcome
records are not constructed. Do not call the old all-date builders. Current OSM
entrances are user-authorized treatment geometry, while the street PBF is historical.
Public census population is a predictor; non-parish allocation is approximate.

Exact records and panels stay in ignored `data/derived/amendment2/`. Protected
aggregate releases go to `output/amendment2/`. Step 17 reads the published P1 tables
only to inventory seen specification labels and withholding statuses. It does not
re-estimate P1. The registered P1 record stays unchanged.

The old step 16 residual-prototype outputs (`conditional_mde.csv`,
`simulation_curves.csv`, `simulation_parameters.csv`, `placebo_composites.csv`)
remain the historical cc471a4 record. Do not regenerate them under the new entrance
geometry and mislabel them as the old experiment. New full-count results use the
`full_calibration_` prefix. Verification distinguishes these unchanged historical
outputs from the current continuation outputs. `build_session.txt` is environment
metadata. Missing enforcement/works and unresolved policy dates remain explicit.
The amendment remains unapproved; no actual post-opening estimate is authorized.

Every command runs from `road_safety/` (the scripts stop otherwise). R 4.5.2 under WSL. Crash records never leave the machine: scripts print and save aggregates only.

## Setup in a fresh checkout

A new worktree has no package library and no derived folders, since git does not track them.

1. Check that the raw symlink resolves and the delivered file is intact:
   ```
   readlink -f data/raw
   sha256sum "data/raw/2026-09-23_amt_siniestros/REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx"
   ```
   Expected: `/home/leonelb/data/quito-metro-eval/road_safety/raw` and `1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18`.
2. Build the project library:
   ```
   Rscript code/00_setup.R
   ```
   It copies the pinned versions in `code/packages.csv` into the ignored folder `_environment/R-library`, offline: 47 packages from the shared renv cache (`~/.cache/R/renv/cache/`) and duckdb 1.5.5 from the congestion project library of the main checkout (`~/projects/quito-metro-eval/congestion/Output/Waze/_environment/`), together with the DuckDB h3 extension. sf comes from the system library. It then loads every package, checks its version, tests h3, and writes `output/_environment/package_versions.csv` and `session_info.txt`. Override the two source folders with the environment variables `RENV_CACHE_PKGS` and `CONGESTION_ENV` if they live elsewhere.

## Why these tools

R, because sf and the GDAL, GEOS and PROJ libraries are installed system-wide, and because the H3 cells must match the congestion module exactly: congestion builds them with the DuckDB h3 extension (`h3_latlng_to_cell_string(lat, lng, 8)`, `congestion/Scripts/Congestion/inventory_helpers.R`). Python here has pandas and openpyxl but no duckdb, geopandas or h3. Distances are computed in UTM zone 17S (EPSG:32717).

## Run order

| Step | Command | Reads | Writes |
|---|---|---|---|
| Build | `Rscript code/01_build.R` | the raw Excel file (both sheets), all dates | `data/derived/crashes.parquet` (ignored), `output/build/` (district-wide counts, no dates) |
| Spatial frame | `Rscript code/02_spatial.R` | derived crashes (all dates, assignment only), metro layers, GeoQuito parish polygons, OSM BRT routes and the 2022 OSM road layer for the confirmed fast-road flags (checksums checked) | `data/derived/crashes_spatial.parquet` (ignored), `output/spatial/` (pre-period summaries; `parishes.csv` with parish geometry facts, read by the power scripts) |
| Completeness | `Rscript code/05_completeness.R` | `crashes.parquet`, all dates | `output/completeness/` (district-wide, per year only) |
| Descriptives | `Rscript code/03_descriptives.R` | pre-period only, through `load_pre()` | `output/descriptives/` (tables and PNG figures) |
| Power | `Rscript code/04_power.R` | pre-period only, through `load_pre()` | `output/power/` (5 to 10 minutes on 8 cores; `RS_CORES` sets the cores) |
| Power, conformal | `Rscript code/04b_power_conformal.R` | pre-period only, through `load_pre()` | `output/power/conformal_*` (about 8 minutes on 8 cores) |
| Pool B, conformal power (2022 start; in an existing checkout rerun 01 and 02 first, for the fast-road flags) | `RS_POOLS=B_parishes_beyond_2km,B_no_central_norte,O1_urban_parish_parts_beyond_2km,O2_O1_plus_rural_parish_parts RS_PRE_START=2022-01-01 RS_TAG=pool_b_start2022 Rscript code/04b_power_conformal.R` | pre-period only, from January 2022 | `output/power/pool_b_start2022/` (about 1 minute) |
| Pool B, conformal power (2021 start) | the same with `RS_TAG=pool_b_start2021` and no `RS_PRE_START` | pre-period only | `output/power/pool_b_start2021/` (about 3 minutes) |
| Pool B diagnostics | `Rscript code/06_pool_b.R` | pre-period only; the two pool B runs | `output/power/pool_b/` (filters, screen, fast-road shares, comparison) |
| Candidate designs, conformal power (Leonel 2026-09-27; 15 fake placements, 2022 start, 1 km catchments) | `RS_POOLS=B_parishes_beyond_2km,B_no_central_norte,O1_urban_parish_parts_beyond_2km,O2_O1_plus_rural_parish_parts,C_pool_b_plus_composites,C_no_central_norte,G_outer_ring_1_2km RS_OUTCOMES=all_crashes,injury_or_fatal,urban_street_all,urban_street_injury,urban_street_nms_all,urban_street_nms_injury RS_TREATED=pooled_1km RS_OPENINGS=all RS_PRE_START=2022-01-01 RS_TAG=candidates_2022 Rscript code/04b_power_conformal.R` | pre-period only, from January 2022; composites from `code/composites.R` (parish polygons) | `output/power/candidates_2022/` (about 10 minutes) |
| Candidate designs, forward subset (the 3 openings with training before the window) | the same command with `RS_OPENINGS` unset and `RS_TAG=candidates_2022_forward` | pre-period only | `output/power/candidates_2022_forward/` (read by 07 for the forward rejection counts) |
| Gradient design, placebo corridors | `Rscript code/08_gradient.R` | pre-period only; OSM major roads (`ROADS_OSM`, checksum checked), BRT routes, parish polygons | `output/power/gradient/` (placebo avenues and corridors, band counts, rows for 07) |
| Fast-road flag against road geometry (diagnostic) | `Rscript code/09_fast_road_check.R` | pre-period only; OSM major roads (`ROADS_OSM`) | `output/build/fast_road_geometry_check.csv` (by parish and treated area, small counts withheld), `fast_road_geometry_summary.csv`, `fast_road_geometry_ways.csv` (OSM ways used), `mariscal_sucre_plain_ways.csv` |
| Amendment 1, main specification's power (pooled comparator; June 2022 and November 2023 left out) | `RS_DROP_MONTHS=2022-06-01,2023-11-01 RS_POOLS=D_distant_pooled RS_OUTCOMES=all_crashes,injury_or_fatal RS_TREATED=pooled_1km RS_OPENINGS=all RS_PRE_START=2022-01-01 RS_TAG=amendment1_main_2022_drop Rscript code/04b_power_conformal.R`, and the same with `RS_OPENINGS` unset and `RS_TAG=amendment1_main_2022_drop_forward` | pre-period only | `output/power/amendment1_main_2022_drop/`, `..._drop_forward/` (the runs on all 23 months, tags `amendment1_main_2022` and `..._forward`, are kept for comparison) |
| Pre-period checks for amendment 1 | `Rscript code/10_preperiod_checks.R` (after 02 and 08) | pre-period only; historic-center polygon (`CENTRO_GEOJSON`, through the committed symlink `data/congestion_centro_historico`), BRT routes, placebo stations | `output/preperiod/` (counts by role, fast-road fix changes, pre-trend leads and summaries, damage-only drift, ring checks, BRT in the ring) |
| Candidate tables | `Rscript code/07_candidates.R` (after the two rows above) | pre-period only; the candidates and gradient runs | `output/power/candidates/` (composites, removed crashes, weights and fit, comparison) |
| **P1 estimates** (approved 2026-10-01; amendment 1, frozen at f161d18) | `Rscript code/11_p1_estimates.R` (after 02 and 08) | pre-period through `load_pre()` and December 2023 to August 2024 through `load_p1()` (nothing later) | `output/p1/` (estimates, direction rule, leave-one-out, specifications not run, P1 counts rounded to 5, main series figure; about 10 minutes) |
| Model inventory (Leonel, 2026-10-04; descriptive, no P1 estimate re-run) | `Rscript code/12_model_inventory.R` (after 11; 11 must be committed unchanged) | the specifications of 11 (pre-period and December 2023 to August 2024) | `output/p1/inventory/` (moments, E3 weights, pre-period fit, fake openings, A1 shifts, monthly gaps, pre-period event study, zone map) |
| Data audit tables (item 2) | `Rscript code/audit_2026-09-25_tables.R` | the raw Excel file | `../reports/road_safety/2026-09-25_data_audit_tables/` |
| Output check (last) | `Rscript code/99_check_outputs.R` | `output/`, `../reports/road_safety/` | nothing; fails on record-level columns, post-opening rows by area, post-opening presence of geographic or outcome-valued fields, or small-group statistics |

01 and 02 read every date because the build and the spatial assignment cover the whole file; they write only all-date district-wide totals (for example `output/spatial/assignment_rates.csv`) and pre-period tables (01: `output/build/fast_road_names_pre.csv`), nothing after the opening by period. Two scripts summarise records from December 2023 on, district-wide only: 05 (per year) and the audit script (per year, plus monthly shares of records with a given recording signature; counts for single post-opening months are withheld). Every descriptive and power script reads crashes through `load_pre()` (`code/helpers.R`), which keeps January 2021 to November 2023, drops the SICARIATO record from outcome counts, and fails if a later date gets through.

The power scripts are seeded (`SEED`, one seed per design; in `04b` a design is seeded by its position in a fixed canonical grid, so it gets the same draws whichever pools are run), so their outputs do not depend on the number of cores. Setting `RS_MAX_DESIGNS` (timing tests) writes to a temporary folder, never over `output/power/`.
