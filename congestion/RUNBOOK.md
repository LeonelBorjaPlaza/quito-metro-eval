# congestion RUNBOOK

Run order from raw Waze data to the Step 1 outputs. Every command runs from `congestion/`, because every path in the scripts is relative to it.

## Setup in a fresh checkout

A new checkout or worktree has no package library and no derived folders, since git tracks neither. Run once:

```
bash Scripts/Congestion/19_step1_setup.sh
```

It does four things:

1. Copies the ignored project library `Output/Waze/_environment/` (R packages, DuckDB h3 extension) from the main checkout, `~/projects/quito-metro-eval/congestion/`, if it is absent.
2. Adds augsynth 0.2.0 (GitHub ebenmichael/augsynth at 65c5a6f) and three dependencies it lacks (osqp 1.0.0, FNN 1.1.4.1, LiblineaR 2.10-24). It copies them from the renv cache `~/.cache/R/renv/cache/` that the air quality restore filled, at the versions in `air_quality/renv.lock`. No network, no compiling. The other augsynth dependencies already resolve from the project or system libraries.
3. Checks every congestion raw file, read through the committed symlinks `Data/Waze/raw` and `Data/spatial`, against `/home/leonelb/data/quito-metro-eval/MANIFEST.sha256`. It stops on any mismatch. The result goes to `Output/Waze/step1/raw_checksum_result.txt`.
4. Loads augsynth, checks the pinned commit, fits augsynth's bundled example, and writes `sessionInfo()` to `Output/Waze/step1/setup_session.txt`.

If the renv cache lacks augsynth, restore the air quality library first (root `CLAUDE.md`, Environment).

## Step 1 of analysis plan v2 (pre-period only)

Step 1 reads no outcome dated December 2023 or later. One loader, `Scripts/Congestion/step1_loader.R`, is the only reader of outcomes, and it stops if a later month gets through. The last script scans every output for such months.

Run everything, each script in a clean R session, with:

```
Rscript Scripts/Congestion/20_run_step1.R
```

It takes about two minutes and runs, in order:

1. `20_step1_blocks_pre.R`: rebuilds the deduplicated all_roadtype block for January 2022 to November 2023 from the raw Parquet, with the date limit in the SQL, into `Data/Waze/parquet_step1/` (ignored).
2. `21_step1_panel.R`: the panel under the five data states, both flag rules (Amendment 1), fixed composition, units, donor pools and the 2022 jam-derived coverage screen. Writes `Data/Waze/step1/panel_pre.rds` (ignored), `Output/Waze/step1/panel_summary.md` and the map.
3. `22_step1_fit.R`: augsynth fits, holdout, benchmarks and full pre-period fits. Writes `Output/Waze/step1/holdout_comparison.md`.
4. `23_step1_diagnostics.R`: weights, top donors, influence, pseudo-neighbourhood placebos, MDE and inference dimensions. Writes `Output/Waze/step1/diagnostics.md` and `fit_paths_pre.png`.
5. `24_step1_freeze.R`: writes the provisional freeze to `Output/step1_freeze/`, with the code commit and the sha256 of every input.
6. `25_step1_check_no_post.R`: scans every Step 1 output and stops on any value dated December 2023 or later.

Shared code: `step1_helpers.R` (constants, geography), `step1_loader.R` (the only outcome and coverage readers) and `step1_fit_helpers.R` (augsynth wrappers, tuning, benchmarks).

## Amendments 2 to 4: the historic center as treated unit (pre period only)

Run after the setup step, with:

```
Rscript Scripts/Congestion/30_run_amend2.R
```

It takes about five minutes. It reruns 20 and 21 (the pre-only block and panel), then:

1. `31_amend2_geography.R`: checks the three geography deliveries against their `SHA256SUMS`, reached through the committed symlinks in `Data/geo/`. It then builds CENTER from GeoQuito feature 41, the descriptive core from the OSM World Heritage outline, and the road-length weights from OSM as of 2022-01-01 (drivable classes, at least 1 m of road per cell). It also produces the group changes, the buffer, the donor status changes, the coverage position of each CENTER cell (category only) and the zonal administration and line distance of every cell.
2. `32_amend2_panel.R`: the weighted unit-month series under both flag rules, with the fixed-composition rule, and the frozen donor pools minus the buffer.
3. `33_amend2_fit.R`: augsynth, plain SCM and DiD for CENTER, CORE, RING7, BELISARIO (road-weighted and equal), CORRIDOR and the low-exposure pools, plus the contrasts, MDE and inference dimensions.
4. `34_amend2_drift.R`: the drift checks (fake window June to November 2022, holdout gaps by month, observation density).
5. `35_amend2_placebos.R`: overlapping seven-cell placebo neighbourhoods, scaled with CENTER's RMSPE as floor (uses four cores).
6. `36_amend2_donor_geography.R`: donor weight by zonal administration and by distance from the line, and the donor map.
7. `25_step1_check_no_post.R`: scans every Step 1 and Amendment 2 output.

Outputs go to `Output/step1_amendment2/` (committed tables and maps) and `Data/Waze/amend2/` (ignored). Shared code is in `amend2_helpers.R`.

## Earlier phases (Codex, 2026-09-17)

These are the historical descriptive phases, kept for reference. They read the full delivery, including post-opening months, as descriptive work allowed at the time. Step 1 does not run them.

- `Rscript Scripts/Congestion/02_prepare_blocks.R` rebuilds the full deduplicated blocks in `Data/Waze/parquet/`.
- `Rscript Scripts/Congestion/02_run_phase_c.R`, then `Rscript Scripts/Congestion/03_preperiod_power.R`.
