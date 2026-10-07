# air_quality: 2026-10-04_remmaq_all_redownload

- **Store folder:** `/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-10-04_remmaq_all_redownload`
- **Received** on 2026-10-04; added to the store on 2026-10-04 by leonelb with `scripts/add_raw_delivery.sh`. All 16 files (15 data and document files plus `SHA256SUMS`) are in the store's `MANIFEST.sha256`.
- **Copied from:** `/home/leonelb/staging/remmaq_2026-10-04/` (CO, DIR, HUM, IUV, LLU, NO2, O3, PM10, PM2.5, PRE, RS, SO2, TMP, VEL `.xlsx`, and `Marco_QAQC_REMMAQ.pdf`).
- **Sent by or obtained from:** the public REMMAQ portal of the Secretaría de Ambiente del DMQ (datosambiente.quito.gob.ec), downloaded by Leonel on 2026-10-04 as one `.rar` archive per variable and extracted with `unar` into the staging folder. Leonel reports that REMMAQ last updated the workbooks on 2026-09-07 (IUV on 2026-08-07).
- **Terms of use:** public data from the REMMAQ portal.
- **Role:** replaces the earlier vintages under `air_quality/raw/data/raw/remmaq/` (downloaded 2026-05-26; see `air_quality__2026-05-26_remmaq_download.md`) as the paper's source, so every variable comes from one vintage (`air_quality/docs/revision_plan.md`, section 1). Not yet wired into the pipeline: `code/local/01_read_and_merge.R` still reads the earlier vintages until step 2.

Facts below come from `air_quality/code/local/diagnostics/vintage_compare.py` and `vintage_weekly_coverage.R`, outputs in `air_quality/output/local/diagnostics/vintage_2026-10-04/` (`vintage_inventory.csv` and the comparison tables), final runs 2026-10-05.

## Files

Every workbook has one sheet, `LIMPIO`, with the date in column 1 and one column per station; there is no units row. Rows are data rows below the header. Time stamps are rounded to the hour when read.

| File | Used by the paper | Rows | First hour | Last hour | Stations | sha256 |
|---|---|---|---|---|---|---|
| PM2.5.xlsx | yes (outcome) | 192,969 | 2004-08-26 15:00 | 2026-08-31 23:00 | 9 | `63d65569…c595d66f` |
| CO.xlsx | yes (outcome) | 198,340 | 2004-01-01 00:00 | 2026-08-31 23:00 | 8 (no San Antonio) | `6e48a9d6…62f2ebea` |
| NO2.xlsx | yes (outcome) | 198,505 | 2004-01-01 00:00 | 2026-08-31 23:00 | 8 | `f9e1bef8…71331cf6` |
| SO2.xlsx | yes (outcome) | 198,391 | 2004-01-01 03:00 | 2026-08-31 23:00 | 8 | `9444fb4b…a2f58600` |
| TMP.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `358d565c…29cbdb9e` |
| HUM.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `cd7acd80…b3cca137` |
| VEL.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `d0c4fbb8…63f46dc4` |
| DIR.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `12db8343…5b94ed71` |
| LLU.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `7514d53c…dc191b03` |
| RS.xlsx | yes (covariate) | 171,143 | 2007-02-22 01:00 | 2026-08-31 23:00 | 9 | `b9d42eb0…833da671` |
| PRE.xlsx | yes (covariate) | 198,696 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `8b008ccb…282964d1` |
| O3.xlsx | no | 198,509 | 2004-01-01 00:00 | 2026-08-31 23:00 | 9 | `04a51ccd…66fa5a35` |
| PM10.xlsx | no | 228,438 | 2013-08-01 00:00 | 2026-08-31 23:00 | 3 named, 1 unnamed | `019aef61…9b6f7fdb` |
| IUV.xlsx | no | 78,888 | 2017-08-01 00:00 | 2026-07-31 23:00 | Jipijapa | `6decaa9a…927c7053` |
| Marco_QAQC_REMMAQ.pdf | documentation | | | | | `fae0d450…9120704f` |

Full sha256 values are in the store's `SHA256SUMS` and `MANIFEST.sha256`. The QA/QC PDF differs from the copy in the earlier vintage (sha256 `800c876c…f1c2`).

**Files the paper uses that this delivery does not replace:** the event dates hard-coded in `01_read_and_merge.R` (power cuts from `air_quality/raw/data/raw/ecuador_blackouts_2024.xlsx` and news sources; holidays from `CALENDARIO-FERIADOS.pdf`), the map layers in `air_quality/raw/data/for_maps/` (Figure 1 and the distances), and everything on the satellite side (`satellite/`, `GHS_UCDB/`).

## Coverage

All workbooks the paper uses run to 2026-08-31 23:00 (earlier vintages: 2026-03-31, CO 2025-12-31). Hours with a value by station and month, from 2024-10, are in `coverage_new_by_month.csv`. Gaps that matter for the panels after March 2025 (`weekly_station_presence_by_month.csv`, `revision_plan.md` section 3):

- Guamaní: every variable stops in mid-June 2025. PM2.5, NO2, SO2, DIR, LLU and VEL return in August 2026; CO, TMP, HUM, PRE and RS do not (`coverage_new_by_month.csv`).
- San Antonio PM2.5: last weekly value in November 2025.
- Los Chillos PM2.5: no weekly value in November 2025.
- Centro NO2: one weekly value in August 2025 (of 4 weeks) and one in December 2025 (of 5), none in January and February 2026.
- Tumbaco CO: no value from April 2026 (2 of 5 weekly values in March 2026).
- El Camal: every variable stops in mid-June 2026 (no value in July and August 2026). El Camal is not one of the eight analysis stations.

## Caveats

1. **Time stamps off the hour.** Rows up to 33 s off the hour; every row 1 s or more off dates from 2025-12-04 or later, and all fall after the hour except TMP's, which fall before it (`vintage_inventory.csv`). Counts are rows more than 1 s off: PM2.5 1,291 rows more than 1 s off (1,292 at 1 s or more), up to 7.455 s, from July 2026; CO 6,387, up to 32.9 s, from December 2025; DIR, LLU and RS about 5,540, up to 29 s; NO2 1,294; SO2 555; TMP and HUM about 450, up to 4 s. The pipeline rounds to the nearest hour, which handles all of them. Earlier vintages: PM2.5, CO and the weather files had none; NO2, SO2 and PM10 had about 450 rows more than 1 s off, up to 4 s, from March 2026.
2. **HUM header.** San Antonio is headed "Santonio". The pipeline's `standardize_name()` turns it into "santonio" and drops it, which would leave San Antonio without humidity, a predictor of the San Antonio imputation. Step 2 maps it to San Antonio (`revision_plan.md`, 2.1).
3. **Column order.** The weather workbooks list stations in a different order from the earlier vintages. The pipeline matches by name, so this is harmless.
4. **SO2 negatives.** 29 negative values; the pipeline sets negative pollutant values to missing.
5. **PRE duplicate hour.** One hour appears twice (2 rows); the pipeline averages duplicates.
6. **No text cells** in the workbooks the paper uses (the earlier CO vintage stored missing values as the text "NA" in 366,037 cells). IUV has 13,974 text cells; it is not used.
7. **Revisions to history** (details in `reports/air_quality/2026-10-05_vintage_comparison.md`):
   - SO2 at Belisario, Carapungo, Centro, Cotocollao and El Camal: values changed in 2004 to 2007 (median new-to-old ratio 2.20 to 12.95 by station and year, `vintage_ratio_by_station_year.csv`), outside the analysis period, which starts 2022-12-01. Centro SO2 also changed in January to March 2026 (2,017 hours, median ratio 0.93 to 0.96). Median ratios by station and year: `vintage_ratio_by_station_year.csv` (2.20 to 12.95 in 2004 to 2007). In the analysis period (December 2022 to March 2025), no value changed; the revisions are newly filled hours (up to 28 a month per station, Los Chillos in January 2025) and 18 hours removed in total.
   - PM2.5: Los Chillos filled from 2025-01-06 to 2025-03-02 (1,296 of 1,344 hours) and revised in November 2024 (158 hours) and March 2025 (176 hours); Guamaní loses hours present in the earlier vintage (132 in December 2022 to November 2023, 112 in December 2023 to March 2025, up to 47 in a month).
   - CO: changed values only in December 2025 (all stations) and November 2025 (Cotocollao), after the frozen CO panel ends; Cotocollao's median ratio is 0.75 to 0.81, the others 0.99 to 1.05. A few hours present in the earlier vintage are gone (up to 19 a month at Tumbaco in January to June 2025).
   - RS: every hour of February 2026 differs, at every station. The earlier vintage is defective that month (flat at about 1 to 2 W/m² day and night); the new vintage shows a normal daily curve with zero at night. The new vintage is kept.
   - TMP, HUM, VEL, DIR, LLU, PRE: no changed value; only new hours.
8. **Los Chillos PM2.5 timing.** From late 2024 (first clear in December 2024 and January 2025), its hourly series lags the other stations by about two hours, while its CO morning peak (7:00 in every month with enough data, except 6:00 in October 2024) and its solar radiation timing did not move. See the comparison report, section 4.

## Defects checked

No defect in a series the paper uses was confirmed in the new vintage, so no series keeps the earlier vintage. The RS difference in February 2026 is a defect of the earlier vintage.

## Not in the paper

- **PM10** is not used: its monitors do not cover the areas the paper needs, and there are too few of them. In this delivery, the file has five columns but only four header names (FECHA, CARAPUNGO, SAN ANTONIO, TUMBACO, and an unnamed fifth column holding 16,517 non-empty cells); the earlier vintage named four stations (CARAPUNGO, GUAMANI, SAN ANTONIO, TUMBACO). Leonel's reading is that the Guamaní PM10 monitor appears discontinued; the comparison scripts have not tested it, and the files alone cannot tell a dropped Guamaní column from a header that lost the GUAMANI label with the data shifted by one column. Not pursued, since PM10 is not used. The file also repeats almost every hour: 227,608 of its 228,438 rows fall in duplicated hours.
- **O3** is new to the store (nine stations, 2004 to 2026-08). The paper does not use O3, from REMMAQ or any other source: the local outcomes are PM2.5, CO, NO2 and SO2, and ozone appears in the paper text only in the titles of two cited references.
- **IUV** (UV index at Jipijapa) is not used.
