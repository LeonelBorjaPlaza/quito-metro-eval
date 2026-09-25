# road_safety: 2026-09-23_amt_siniestros

- **Store folder:** `/home/leonelb/data/quito-metro-eval/road_safety/raw/2026-09-23_amt_siniestros/`
- **Received** on 2026-09-23 by email from Dennys Mosquera, Coordinador General de Ingeniería de Tránsito y Seguridad Vial, Agencia Metropolitana de Tránsito (AMT). The matrix was prepared by the AMT's statistics unit. See `docs/correspondence/2026-09-23_crash_data_delivery.md`.
- **Files:** `REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx` and the email as `.msg`.
- **Expected sha256 of the Excel file** (computed on the attachment as received): `1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18`
- **Terms of use:** only for this evaluation; results published in aggregate; main findings shared with the AMT.

## What it covers

- **Sheet SINIESTROS:** one row per crash, 20,095 rows and 23 columns, dated 2021-01-01 to 2026-08-31 (68 months). Columns: AÑO, MES, SINIESTRO (crash ID), DISTRITO, JEFATURA, FECHA, DIA, HORA, LATITUD, LONGITUD, PROVINCIA, CANTON, PARROQUIA, ADMINISTRACION, ZONA, PRINCIPAL, SECUNDARIA, FALLECIDOS, LESIONADOS, TIPOLOGÍA, CAUSA PROBABLE, SEVERIDAD, VEHICULOS REGISTRADOS.
- **Sheet VEHÍCULOS:** one row per vehicle, 33,685 rows and 10 columns, linked by SINIESTRO. Columns: AÑO, MES, SINIESTRO, MARCA, MODELO, AÑO2, CILINDRAJE, TIPO DE SERVICIO, TIPO DE VEHÍCULO, SUB CATEGORÍA. No license plates.

## First-look caveats (2026-09-24)

- Every crash has coordinates. In the Excel file they are stored partly as text and partly as numbers; all of them convert to numbers. Check every point against the district boundary.
- One record has "X (SICARIATO)" in FALLECIDOS instead of a number.
- ZONA is empty for 960 records.
- The typology ATIPICO (2,696 records) has no definition yet.
- No data for 2020 or earlier (see the correspondence note).

The `data-auditor` agent does the full audit in workstream C.

## Stored and checked, 2026-09-24

- Loaded into the store during the consolidation (Phase 3), locked, with `SHA256SUMS` in the folder. `road_safety/data/raw` is a committed symlink to `/home/leonelb/data/quito-metro-eval/road_safety/raw/`.
  - `REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx`, sha256 `1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18` (matches the expected value above).
  - `RE Solicitud de datos de siniestros de tránsito del DMQ para la evaluación de impacto del Metro de Quito.msg`, sha256 `d74f60dd8b836ca699623323399a65e6cd930f688e742a98c9dab02e78e8e664`.
  - `copy_found_in_AQ_SRC/`: an older copy of both files that sat, untracked and not ignored, in the air quality OneDrive folder under `data/traffic-accidents/`. `Copy of REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx` (sha256 `b03c7e77d43666aeea3a92adcb7a0064bc9280244c49745bbfde81940a476ecb`) has the same sheets, rows and columns as the delivered file and the same values in every cell except the day-of-week column `DIA`, which holds English labels (Monday, Tuesday...) where the delivered file has Spanish ones (lunes, martes...). It looks like a re-save by Excel in another locale. Use the delivered file, not this copy. The email copy (sha256 `9223216ae1586ab7b22b65dd594dd27d74b037788341c99272c51b7dd06eeffa`) is a different export of the same email.
- Facts above checked against the delivered file: sheets `SINIESTROS` and `VEHÍCULOS`; SINIESTROS has 20,095 data rows and the 23 listed columns, `FECHA` from 2021-01-01 to 2026-08-31 in 68 distinct months, 20,095 distinct `SINIESTRO` values; VEHÍCULOS has 33,685 rows and the 10 listed columns, and its `SINIESTRO` values cover all 20,095 crashes. `FALLECIDOS` has exactly one non-numeric value, "X (SICARIATO)". `ZONA` is empty in 960 rows. `TIPOLOGÍA` equals ATIPICO in 2,696 rows. `LATITUD` is text in 18,658 rows and a number in 1,437; `LONGITUD` is text in 19,271 and a number in 824; every value converts to a number. Everything matched; nothing was corrected.
