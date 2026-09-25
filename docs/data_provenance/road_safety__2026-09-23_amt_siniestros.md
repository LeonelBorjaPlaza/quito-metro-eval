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
