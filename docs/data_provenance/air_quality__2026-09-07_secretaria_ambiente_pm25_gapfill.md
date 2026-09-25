# air_quality: 2026-09-07_secretaria_ambiente_pm25_gapfill

- **Store folder:** `/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/`
- **Received** on 2026-09-07, attached to the Secretaría de Ambiente comments forwarded by Vanessa Rodríguez (Metro de Quito). See `docs/correspondence/2026-09-07_secretaria_ambiente_comments.md`.
- **Files:** `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx` and the email as `.msg`.
- **Expected sha256 of the Excel file** (computed on the attachment as received): `a1a08e5b99a64b93942950d6101d2ce8e91fb73d8362331b960eebdbe821eaa3`

## What it covers

- One sheet (Hoja1), hourly PM2.5 from 2025-01-13 00:00 to 2025-01-25 23:00: 312 hours, 13 days.
- Ten columns: FECHA and nine stations (BELISARIO, CARAPUNGO, CENTRO, COTOCOLLAO, EL CAMAL, GUAMANI, LOS CHILLOS, SAN ANTONIO, TUMBACO). An empty eleventh column in the header row.
- Share of hours with a value: about 99 percent for most stations, 93 percent for San Antonio, 84 percent for Guamaní and 81 percent for El Camal.

## Caveats

- It fills only the first 13 days of the gap in the frozen weekly panel, which runs from the week starting 2025-01-13 to the week starting 2025-02-24 (seven weeks). It covers the whole week starting January 13 and six of the seven days of the week starting January 20; Sunday, January 26 is missing. The rest must come from REMMAQ.
- Units, validation level and time stamp convention (hour beginning or hour ending) must be checked against the REMMAQ files the pipeline already reads before these values enter any panel.
- Do not merge it into any panel during the consolidation. Workstream A decides how to use it.
