# Road safety module

This module will estimate the effect of Quito Metro Line 1 (opened December 1, 2023) on road crashes near its stations and along the corridor. It uses the municipal crash records that the Agencia Metropolitana de Tránsito (AMT) delivered on September 23, 2026, covering January 2021 to August 2026.

## Where the data are

The raw crash matrix is not in git. It lives once, locked, in the data store:

- `/home/leonelb/data/quito-metro-eval/road_safety/raw/2026-09-23_amt_siniestros/`

The module reaches it through the committed symlink `road_safety/data/raw`, which points to `/home/leonelb/data/quito-metro-eval/road_safety/raw/`. Provenance, sheets, row counts and caveats are in `docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`. The data were shared for this evaluation only and may be published only in aggregate.

## First tasks, in order

1. Data audit with the `data-auditor` agent, including questions for the provider.
2. A spatial frame: crashes on the same H3 grid as the Waze data, and on station catchments and the corridor.
3. Pre-period descriptives only (January 2021 to November 2023).
4. A draft analysis plan for Leonel's approval.

No estimation, and no post-opening outcomes by area, until the analysis plan is approved. See `road_safety/CLAUDE.md`.
