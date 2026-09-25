# Phase 4. Environment in WSL, 2026-09-24

## Result

WSL R 4.5.2 now runs the air quality local pipeline. The renv lockfile restores in full, augsynth 0.2.0 and synthdid 0.0.9 included, with every package at its locked version. DuckDB 1.5.5 and its h3 extension work for congestion from the new location. Nothing needed `sudo`.

## Air quality

- `air_quality/renv.lock` records R 4.5.2 and 67 packages; WSL has R 4.5.2.
- The first `renv::restore()` (log `logs/phase4_renv_restore.log`, not committed) failed and rolled back. **First error line:** `Eigen/src/Core/Transpositions.h:387:87: error: 'const class Eigen::Transpose<Eigen::TranspositionsBase<Derived> >' has no member named 'derived' [-Wtemplate-body]`, while compiling `mcnnm_R.cpp` in **MCPanel** (GitHub susanathey/MCPanel).
- **Diagnosis.** This is not a missing system library, an archived CRAN dependency, or blocked GitHub access. MCPanel is not in the lockfile and augsynth does not need it: it is only in augsynth's Suggests. renv installed it because augsynth's DESCRIPTION has `Remotes: susanathey/MCPanel`, and renv follows `Remotes` by default. MCPanel bundles an old copy of the Eigen headers that GCC 15.2 (Ubuntu 26.04) rejects.
- **Fix, without patching any package.** `RENV_CONFIG_INSTALL_REMOTES=FALSE` makes renv install exactly the lockfile. The second restore succeeded (`logs/phase4_renv_restore_2.log`). Posit Package Manager served source tarballs for these pinned versions, so all 69 packages compiled locally into the shared cache `~/.cache/R/renv/cache/v5/`. A later restore in a new worktree links 63 packages from the cache in well under a second (Phase 6 gate setup).
- **Why it failed on 2026-09-17.** The congestion session asked only the Posit CRAN repository for augsynth and synthdid, and neither package is on CRAN (`congestion/Output/Waze/_environment/package_status.txt`). Both install from GitHub at the commits the lockfile pins (augsynth `65c5a6f`, synthdid `70c1ce3`), and GitHub is reachable.
- augsynth, synthdid and fixest load. `renv::status()` lists the six map packages (below) as used but not recorded, and nothing else.
- The map script's packages, which the lockfile does not record, were installed with `renv::install()` without a snapshot: sf 1.1-3, ggrepel 0.9.8, ggspatial 1.1.11, maptiles 0.12.0, rnaturalearth 1.2.0 and tidyterra 1.3.0.
- `air_quality/ENVIRONMENT.md` records the platform, BLAS and LAPACK, compilers, the restore command and the key versions. There are no version differences from the lockfile. The frozen outputs came from Windows builds, and here every package was compiled from source.

## Congestion

- The scripts load packages from the project library `congestion/Output/Waze/_environment/R-library` and the h3 extension from `Output/Waze/_environment/duckdb_extensions`. Both are ignored by git and were copied (`cp -a`, 256 MB) from `WAZE_SRC` into the main checkout.
- Test from `congestion/`: the library loads (duckdb 1.5.5, arrow 25.0.1, data.table 1.18.6.1, fixest 0.14.2), `LOAD h3` works, `h3_latlng_to_cell_string(-0.2203, -78.5158, 8)` returns a cell, and `read_parquet('Data/Waze/raw/grids_quito_hourly_2019-2025.parquet')` reads 15,080,765 rows through the store symlink. That is the raw row count the Phase B inventory reports.
- The congestion library has no augsynth or synthdid. Workstream B must add them for Step 1.

## Code edits needed to run in WSL (commit `a091013`)

| File:line | Before | After | Why |
|---|---|---|---|
| `air_quality/code/local/05_analysis_setupCO.R:33` | `"co_completepanel_peakweekly.csv"` | `"CO_completepanel_peakweekly.csv"` | `02_build_weekly_panels.R:473` writes the upper-case name; the lower-case read only worked on Windows' case-insensitive file system |
| `air_quality/code/local/fig1_metro_airquality_map.R:40` | `PROJECT_ROOT <- "C:/Users/LEONELB/OneDrive - .../quito-metro-airquality-2026"` | `PROJECT_ROOT <- here::here()` | absolute Windows path |

No line-ending edits to scripts were needed: git stores every tracked script with LF (`.gitattributes` sets `eol=lf`), and the untracked scripts copied in Phase 2 were already LF. CRLF was stripped from the two spatial placebo `_log.txt` output files in Phase 2.
