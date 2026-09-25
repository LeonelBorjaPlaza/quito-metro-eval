# Air quality: computing environment in WSL

Recorded on 2026-09-24 during the consolidation (Phase 4). If a re-run does not reproduce the frozen tables, check this file first: package versions and platform numerics are the first suspects.

## Platform

- Ubuntu 26.04 LTS (resolute) under WSL2, x86_64, 15 GB RAM, 8 cores.
- R 4.5.2 (2025-10-31), `x86_64-pc-linux-gnu`, from Ubuntu's `r-base`. The lockfile records R 4.5.2, the same version.
- BLAS and LAPACK: the reference libraries `/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.1` and `lapack/liblapack.so.3.12.1`.
- Compilers: gcc and g++ 15.2.0 (Ubuntu 15.2.0-16ubuntu1).
- The frozen outputs of 2026-05-26 to 2026-05-31 were produced on Windows (R 4.5.2, CRAN Windows binaries). Here every package was compiled from source: for these pinned versions Posit served source tarballs, not binaries (69 source builds in `logs/phase4_renv_restore.log`). The first restore compiled them into the shared cache; the second linked them from it. Tiny floating-point differences between the two platforms are possible.

## Package library (renv)

- `renv.lock` (67 packages) is unchanged from the source repository. `.Rprofile` activates renv 1.2.2 when R starts in `air_quality/`.
- Project library: `air_quality/renv/library/linux-ubuntu-resolute/R-4.5/x86_64-pc-linux-gnu/` (ignored by git). Packages are linked from the shared renv cache `~/.cache/R/renv/cache/v5/`, so a new worktree restores in seconds.
- Restore command, run from `air_quality/`:

  ```bash
  RENV_CONFIG_INSTALL_REMOTES=FALSE \
  RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/resolute/latest" \
  Rscript -e 'renv::restore(prompt = FALSE)'
  ```

- **Why `RENV_CONFIG_INSTALL_REMOTES=FALSE`.** augsynth's DESCRIPTION has `Remotes: susanathey/MCPanel`. By default renv follows that field and installs MCPanel from GitHub, even though MCPanel is only a suggested package of augsynth and is not in the lockfile. MCPanel bundles an old copy of the Eigen headers that GCC 15 rejects. The first error line was `Eigen/src/Core/Transpositions.h:387:87: error: 'const class Eigen::Transpose<Eigen::TranspositionsBase<Derived> >' has no member named 'derived' [-Wtemplate-body]`. That one failure rolled back the whole restore. With the setting off, renv installs exactly the lockfile and everything succeeds (log: `logs/phase4_renv_restore_2.log`, not committed). No package was patched, and no estimator was replaced.
- **Why augsynth and synthdid failed on 2026-09-17.** The congestion session looked for them only in the Posit CRAN repository (`congestion/Output/Waze/_environment/package_status.txt`: "Unavailable in the requested Posit CRAN repository"). Neither package is on CRAN; both install from GitHub at the commits the lockfile pins. GitHub is reachable from this machine.

## Key package versions

Every package in the lockfile is installed at its locked version. MASS 7.3-65, Matrix 1.7-4 and nlme 3.1-168 come from R's own library at the locked versions. There are no version differences from the lockfile.

| Package | Lockfile | Installed | Source |
|---|---|---|---|
| augsynth | 0.2.0 | 0.2.0 | GitHub ebenmichael/augsynth @ 65c5a6f34f4e4a8b1011182fe12309ef022d992f |
| synthdid | 0.0.9 | 0.0.9 | GitHub synth-inference/synthdid @ 70c1ce3eac58e28c30b67435ca377bb48baa9b8a |
| fixest | 0.14.1 | 0.14.1 | CRAN source from Posit, compiled here |
| osqp | 1.0.0 | 1.0.0 | CRAN source from Posit, compiled here |
| LiblineaR | 2.10-24 | 2.10-24 | CRAN source from Posit, compiled here |
| FNN | 1.1.4.1 | 1.1.4.1 | CRAN source from Posit, compiled here |
| mvtnorm | 1.3-7 | 1.3-7 | CRAN source from Posit, compiled here |
| dplyr | 1.2.1 | 1.2.1 | CRAN source from Posit, compiled here |
| readr | 2.2.0 | 2.2.0 | CRAN source from Posit, compiled here |
| tidyr | 1.3.2 | 1.3.2 | CRAN source from Posit, compiled here |
| readxl | 1.5.0 | 1.5.0 | CRAN source from Posit, compiled here |
| lubridate | 1.9.5 | 1.9.5 | CRAN source from Posit, compiled here |
| stringr | 1.6.0 | 1.6.0 | CRAN source from Posit, compiled here |
| ggplot2 | 4.0.3 | 4.0.3 | CRAN source from Posit, compiled here |
| patchwork | 1.3.2 | 1.3.2 | CRAN source from Posit, compiled here |
| here | 1.0.2 | 1.0.2 | CRAN source from Posit, compiled here |
| lattice | 0.22-7 | 0.22-7 | CRAN source from Posit, compiled here (R's own library has 0.22-9; the project library masks it) |

## Installed outside the lockfile

`code/local/fig1_metro_airquality_map.R` loads six packages that the lockfile does not record: sf 1.1-3 (GEOS 3.14.1, GDAL 3.12.2, PROJ 9.7.1), ggrepel 0.9.8, ggspatial 1.1.11, maptiles 0.12.0, rnaturalearth 1.2.0 and tidyterra 1.3.0. They and their 21 dependencies were installed into the project library with `renv::install()` and **not** snapshotted, so `renv::status()` reports the project as out of sync. That report is expected. A fresh worktree does not get them from `renv::restore()`; the RUNBOOK says how to add them. The map downloads basemap tiles at run time, so the figure is not bit-for-bit reproducible.

## Not used here

The satellite design runs on the Google Cloud VM, whose copy of the code is authoritative. Nothing on the satellite side runs in WSL. Python 3.14.6 has pandas and openpyxl but no geopandas or Earth Engine client. Stata binaries exist in the home folder but no local script needs them.
