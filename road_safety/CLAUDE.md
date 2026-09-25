# road_safety module

Effect of Quito Metro Line 1 (opened December 1, 2023) on road crashes near its stations and along the corridor. New module, no code yet.

## The data

- Crash matrix from the Agencia Metropolitana de Tránsito (AMT), received 2026-09-23: `REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx`, January 2021 to August 2026. Sheet SINIESTROS has one row per crash (20,095 rows, 23 columns, with coordinates, date and time, parish, typology, probable cause, severity, deaths and injuries). Sheet VEHÍCULOS has one row per vehicle (33,685 rows, 10 columns, no license plates), linked by `SINIESTRO`.
- Location: `data/raw/2026-09-23_amt_siniestros/` inside this module, through the committed symlink `data/raw` → `/home/leonelb/data/quito-metro-eval/road_safety/raw/`. Locked; never edit or re-save it. Use the delivered file, not the copy in `copy_found_in_AQ_SRC/`, whose day-of-week column was translated to English by a re-save.
- Provenance, sha256, checked facts and first-look caveats (the SICARIATO record, 960 empty ZONA values, the undefined ATIPICO typology, coordinates stored as text): `docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`. Correspondence: `docs/correspondence/2026-09-23_crash_data_delivery.md`.

## Rules 4 and 5 of the root CLAUDE.md, in full

4. **Confidential data.** The crash records in `road_safety` were shared by the Agencia Metropolitana de Tránsito (AMT) for this evaluation only, to be published only in aggregate. REMMAQ and Waze data follow their providers' terms. Never paste raw records into web tools, emails or chat, and never send data over the network.
5. **No post-opening estimates without an approved plan.** In `congestion` and `road_safety`, do not load, describe by area, or estimate outcomes after December 1, 2023 until the module's analysis plan (`congestion/docs/analysis_plan.md` once v2 is committed, `road_safety/docs/analysis_plan.md`) carries Leonel's written approval. In `air_quality`, re-running approved specifications is allowed; a new specification, window or donor rule needs his approval first.

## First tasks, in order (workstream C)

1. **Data audit** with the `data-auditor` agent: coverage, keys, values, stability over time, and questions for the AMT in Spanish (the ATIPICO typology, the SICARIATO record, changes in recording practice between 2021 and 2026). For months from December 2023 on, district-wide completeness only.
2. **Spatial frame**: crashes on the same H3 resolution-8 grid as the Waze data, and on station catchments and the corridor, with every point checked against the district boundary.
3. **Pre-period descriptives** only, January 2021 to November 2023.
4. **Analysis plan draft** for Leonel's approval, with units large enough to detect a plausible effect and a power calculation (crashes are sparse district-wide).

No estimation of any kind in this module until step 4 is approved.
