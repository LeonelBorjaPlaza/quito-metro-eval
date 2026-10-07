# Data audit: Secretaría de Ambiente PM2.5 gap-fill file

- **Source:** `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx`, sent by María Valeria Díaz (Secretaría de Ambiente) on 2026-09-04, forwarded by Metro de Quito on 2026-09-07.
- **Store path (read-only):** `/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/`
- **Reference file:** `air_quality/data/raw/remmaq/PM2.5.xlsx` (sheet LIMPIO), the file `code/local/01_read_and_merge.R` reads.
- **Workstream:** A (air quality revision). Audit date 2026-10-01. Script: `reports/data_audits/2026-10-01_aq_secretaria_pm25_gapfill_audit.py`. Every number below comes from a CSV in this folder whose file name starts with `2026-10-01_aq_secretaria_pm25_gapfill_` (short names given in brackets).

## Verdict: usable with caveats, and only for Los Chillos

1. **For eight of the nine stations, the file adds nothing new.** Belisario, Carapungo, Centro, Cotocollao, El Camal, Guamaní, San Antonio and Tumbaco are identical to `PM2.5.xlsx` for 2025-01-13 to 2025-01-25. Every paired hour is equal at lag 0 (share 1.000) and the missing hours are the same in both files. `PM2.5.xlsx` already holds these data [lag_alignment, coverage_joint].
2. **Los Chillos is the only new series, and it is the one the pipeline needs.** `PM2.5.xlsx` has no Los Chillos value from the week starting 2025-01-13 through the week starting 2025-02-17. The gap-fill file has Los Chillos for 311 of 312 hours, including all 30 weekday peak hours in each of the two weeks it covers [coverage_joint, weekday_peak_hour_coverage, pm25xlsx_weekly_coverage_gapweeks].
3. **The Los Chillos column looks like it went through a different processing step.** 309 of its 311 values carry 3 to 5 decimals. No value in `PM2.5.xlsx`, for any station or year from 2004 to 2026, has more than 2 decimals, and the other eight columns of the gap-fill file have at most 2 [decimals]. (The count is the fewest decimals that reproduce the stored value, so it is a lower bound: trailing zeros are not stored.) Its levels fit µg/m3, but its validation status is unknown.
4. **Time stamps:** both files store exact hours and agree with each other. Neither file, the email nor the QA/QC framework says whether a stamp marks the start or the end of the hour. The daily patterns show local clock time, even though `PM2.5.xlsx` formats its date column with a "UTC" label.
5. **It fills two of the seven gap weeks at most.** Those are the weeks starting January 13 and 20. The weeks starting 2025-01-27 to 2025-02-24 still need Los Chillos from REMMAQ.

Before Los Chillos enters any panel, the Secretaría should confirm its validation level and the time convention (questions 1, 2 and 4 below). Under the module's rules, adding a data source also needs Leonel's approval, with an old-versus-new table against `frozen_2026-05-29/`.

**Scope note.** This audit reports station-level coverage and value summaries for December 2024 to February 2025 because Leonel asked for a measurement check on January 2025. Root rule 5 of `CLAUDE.md` restricts post-opening outcome work in `congestion` and `road_safety`; in `air_quality`, the post-opening specifications are already approved and estimated. No before-and-after contrast around December 1, 2023 is computed. Only aggregates are saved. The one listing of hours is `gapfill_missing_runs.csv`, which gives the start and end of missing spells and no values. If Leonel prefers a structure-only audit for post-opening months, drop the value columns for those windows from `values_by_station.csv`, `diurnal_*.csv` and `timing_vs_other_stations.csv`. In `values_by_station.csv`, the min, max, p01 and p99 columns each amount to a single hourly value without its time stamp; REMMAQ data are public, so this was judged acceptable.

## 1. Inventory

| File | Bytes | sha256 (first 12) | Checked against | Match |
|---|---|---|---|---|
| `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx` | 29,808 | a1a08e5b99a6 | `SHA256SUMS` | yes |
| `Solicitud de revisión del paper de calidad del aire PLMQ.msg` | 165,376 | 662ed1ded267 | `SHA256SUMS` | yes |
| `copy_found_in_AQ_SRC/... PLMQ .msg` | 201,728 | b0791f2ca34a | `SHA256SUMS` | yes |
| `PM2.5.xlsx` (reference) | 9,929,306 | f68cf3bd028b | `MANIFEST.sha256` | yes |

Source: [inventory].

| Property | Gap-fill file | PM2.5.xlsx |
|---|---|---|
| Sheets | Hoja1 | LIMPIO |
| Used range | A1:K313 | A1:J189244 |
| Data rows | 312 | 189,243 |
| Header | FECHA + 9 stations + 1 empty cell (K1, bold, no values below) | fecha + the same 9 stations |
| Units row | none | none |
| First and last hour | 2025-01-13 00:00 to 2025-01-25 23:00 | 2004-08-26 15:00 to 2026-03-31 23:00 |
| Distinct hours, duplicates | 312, 0 | 189,243, 0 |
| Station cells | all numeric (type n, General format); missing hours are absent cells | same |
| Date column format | built-in format 22 (`m/d/yyyy h:mm`) | custom `yyyy-mm-dd hh:mm:ss UTC` |
| Comments, conditional formats, data validation, colour fills | none | none |
| Document properties | created and saved 2026-09-04 by María Valeria Díaz Suárez, in `C:\Users\vdiaz\Downloads\` | created 2025-11-18 by the same author; last saved 2026-05-26 by Leonel Borja Plaza |

Source: [inventory], plus `docProps/core.xml` and `xl/workbook.xml` read in this session.

Numeric cells per station in the gap-fill file: Belisario 311, Carapungo 312, Centro 310, Cotocollao 311, El Camal 254, Guamaní 261, Los Chillos 311, San Antonio 291, Tumbaco 311.

**Email.** I read both `.msg` exports for text with `strings`. They hold the same thread (Díaz to Rodríguez, 2026-09-04, with Leonel's 2026-08-20 message below). The attachment is named `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx`, and the body says only that these data are available in REMMAQ. **The email states no units, no validation level and no time convention.** I did not extract the attachment bytes from the `.msg` to re-hash them, because Python here has no OLE reader. The provenance note records that the expected hash was computed on the attachment as received.

**Provenance inconsistency (minor).** `air_quality/data/raw/README.md` says the REMMAQ files were downloaded on March 25, 2026, and `remmaq/data_provenance_note.txt` says May 26, 2026. `PM2.5.xlsx` was last saved on 2026-05-26 by Leonel's account. The same "UTC" date format (`yyyy-mm-dd hh:mm:ss UTC`) appears in `PM10.xlsx` and `VEL.xlsx`, which Leonel's account never saved, so it was not set on May 26; whether it is the portal's label or a template of the Secretaría cannot be told. (The download date is settled in `docs/data_provenance/air_quality__2026-05-26_remmaq_download.md`: May 26, 2026; March 25 belongs to an earlier, replaced download.) The README also says each file has a units row; `PM2.5.xlsx` does not (already noted in `docs/known_issues.md`).

## 2. Coverage

### Time span and gaps

The gap-fill file is complete and hourly, with 312 consecutive hours and no missing time stamp. `PM2.5.xlsx` has 23 gaps in its row sequence totalling 54 hours. Sixteen of them are the first hours of January 1 in various years. One is near the gap: the hour 2024-12-21 02:00 has no row. None falls between 2024-12-30 and 2025-03-31 [pm25xlsx_timeline_gaps]. From 2025-01-06 to 2025-03-09, `PM2.5.xlsx` has all 1,512 hourly rows and no row where all nine stations are empty (printed by the script; the trace in `air_quality/output/local/diagnostics/pm25_gap/pm25_gap_trace_facts.csv` confirms no missing row from 2024-12-30 to 2025-03-16).

### By station, 2025-01-13 to 2025-01-25 (312 hours)

| Station | In pipeline | Gap-fill hours (share) | PM2.5.xlsx hours (share) | Both | Gap-fill only | PM2.5.xlsx only | Neither |
|---|---|---|---|---|---|---|---|
| Belisario | yes | 311 (0.997) | 311 (0.997) | 311 | 0 | 0 | 1 |
| Carapungo | yes | 312 (1.000) | 312 (1.000) | 312 | 0 | 0 | 0 |
| Centro | yes | 310 (0.994) | 310 (0.994) | 310 | 0 | 0 | 2 |
| Cotocollao | yes | 311 (0.997) | 311 (0.997) | 311 | 0 | 0 | 1 |
| El Camal | no | 254 (0.814) | 254 (0.814) | 254 | 0 | 0 | 58 |
| Guamaní | yes | 261 (0.837) | 261 (0.837) | 261 | 0 | 0 | 51 |
| **Los Chillos** | yes | **311 (0.997)** | **0 (0.000)** | 0 | **311** | 0 | 1 |
| San Antonio | yes | 291 (0.933) | 291 (0.933) | 291 | 0 | 0 | 21 |
| Tumbaco | yes | 311 (0.997) | 311 (0.997) | 311 | 0 | 0 | 1 |

Source: [coverage_joint]. "In pipeline" follows `stations_keep` in `01_read_and_merge.R`, which leaves out El Camal. No station appears in `PM2.5.xlsx` and not in the gap-fill file.

### Missing hours in the gap-fill file

| Station | Missing spells | Hours | Where |
|---|---|---|---|
| El Camal | 2 | 58 | 2025-01-13 00:00 to 2025-01-15 08:00 (57 h), and 2025-01-23 16:00 |
| Guamaní | 2 | 51 | 2025-01-14 14:00 to 2025-01-16 15:00 (50 h), and 2025-01-18 17:00 |
| San Antonio | 17 | 21 | scattered single hours or pairs, mostly at night (20:00 to 05:00); longest 3 h (2025-01-16 00:00 to 02:00) |
| Centro | 2 | 2 | 2025-01-17 19:00, 2025-01-18 17:00 |
| Belisario | 1 | 1 | 2025-01-22 10:00 |
| Cotocollao | 1 | 1 | 2025-01-16 15:00 |
| Los Chillos | 1 | 1 | 2025-01-21 14:00 |
| Tumbaco | 1 | 1 | 2025-01-25 16:00 |
| Carapungo | 0 | 0 | |

Source: [gapfill_missing_runs]. Coverage by station and day is in [coverage_station_day], and by station and hour of day in [coverage_station_hour]. San Antonio's 21 missing hours fall at hours 0 (3), 1 (3), 2 (2), 4 (2), 5 (1), 14 (1), 15 (1), 20 (3), 21 (1), 22 (3) and 23 (1). El Camal and Guamaní miss 2 or 3 days at every hour of day, which fits the multi-day spells. By day, El Camal has 0 hours on January 13 and 14 and 15 on January 15. Guamaní has 14 on January 14, 0 on January 15 and 8 on January 16. Both files show the same pattern.

### Weekday peak hours (the hours in the weekly outcome)

Weekday peak hours are 7, 8, 9, 17, 18 and 19 (`02_build_weekly_panels.R:59-61`), giving 30 per full week.

| Station | Gap-fill, week of Jan 13 | Gap-fill, week of Jan 20 | PM2.5.xlsx, week of Jan 13 | PM2.5.xlsx, week of Jan 20 |
|---|---|---|---|---|
| Los Chillos | 30 | 30 | 0 | 0 |
| El Camal | 16 | 30 | 16 | 30 |
| Guamaní | 18 | 30 | 18 | 30 |
| Centro | 29 | 30 | 29 | 30 |
| Other five | 30 | 30 | 30 | 30 |

Source: [weekday_peak_hour_coverage].

### PM2.5.xlsx around the seven-week gap (hours with a value out of 168 per week)

| Station | Jan 6 | Jan 13 | Jan 20 | Jan 27 | Feb 3 | Feb 10 | Feb 17 | Feb 24 | Mar 3 |
|---|---|---|---|---|---|---|---|---|---|
| Los Chillos | 8 | 0 | 0 | 0 | 0 | 0 | 0 | 47 | 129 |
| El Camal | 104 | 111 | 167 | 168 | 168 | 168 | 168 | 167 | 168 |
| Guamaní | 167 | 117 | 168 | 168 | 160 | 166 | 164 | 135 | 103 |
| San Antonio | 116 | 150 | 165 | 161 | 149 | 139 | 148 | 150 | 133 |
| Belisario | 164 | 168 | 167 | 162 | 168 | 168 | 168 | 168 | 107 |
| Carapungo, Centro, Cotocollao, Tumbaco | 137 to 168 in every week | | | | | | | | |

Source: [pm25xlsx_weekly_coverage_gapweeks]. This confirms the diagnosis in `docs/known_issues.md` (entry dated 2026-10-01). The reference file has every hour of the gap and the other seven pipeline stations, but no Los Chillos value from the week of January 13 to the week of February 17. The balance rule then drops those weeks for every station. That entry places the end of the Los Chillos outage at 2025-02-28 23:00, which would put all 47 hours of the week of February 24 on the weekend.

### Spatial extent

Neither file has coordinates. The units are nine named stations, with the same names and order in both files.

## 3. Keys, duplicates and links between the two files

### Duplicates

- No duplicate time stamps in either file [inventory].
- No copied columns. Across all 36 pairs of gap-fill stations, the largest share of hours with identical values is 0.004 [gapfill_column_pairs].
- No flat runs. No station in the gap-fill file repeats the same value for 3 or more consecutive hours; the longest run is 2 [values_by_station].

### How time stamps are stored

Both files store Excel date serials at exact hours: 312 of 312 in the gap-fill file and 189,243 of 189,243 in `PM2.5.xlsx`. No `XX:59:59.999` and no text dates [inventory]. The rounding step in `read_remmaq()` (`round_date(..., "hour")`) therefore changes nothing for either file. Both use the 1900 date system.

### Alignment at lags (gap-fill at hour t against PM2.5.xlsx at hour t + L)

If the gap-fill file stamped the end of the hour and `PM2.5.xlsx` the start, the best match would be at L = -1. Values were compared at each file's precision: 2 decimals, or 1 for San Antonio.

| Station | Paired hours (L=0) | Share equal, L=0 | Share within 0.5, L=0 | Mean signed diff, L=0 | Corr L=-2 | Corr L=-1 | Corr L=0 | Corr L=+1 | Corr L=+2 | Largest share equal at any L≠0 (-6 to +6) |
|---|---|---|---|---|---|---|---|---|---|---|
| Belisario | 311 | 1.000 | 1.000 | 0.000 | 0.550 | 0.676 | 1.000 | 0.677 | 0.552 | 0.003 |
| Carapungo | 312 | 1.000 | 1.000 | 0.000 | 0.556 | 0.700 | 1.000 | 0.700 | 0.554 | 0.006 |
| Centro | 310 | 1.000 | 1.000 | 0.000 | 0.535 | 0.620 | 1.000 | 0.619 | 0.530 | 0.000 |
| Cotocollao | 311 | 1.000 | 1.000 | 0.000 | 0.468 | 0.601 | 1.000 | 0.596 | 0.467 | 0.000 |
| El Camal | 254 | 1.000 | 1.000 | 0.000 | 0.470 | 0.651 | 1.000 | 0.651 | 0.471 | 0.004 |
| Guamaní | 261 | 1.000 | 1.000 | 0.000 | 0.396 | 0.573 | 1.000 | 0.572 | 0.399 | 0.004 |
| San Antonio | 291 | 1.000 | 1.000 | 0.000 | 0.553 | 0.651 | 1.000 | 0.652 | 0.553 | 0.007 |
| Tumbaco | 311 | 1.000 | 1.000 | 0.000 | 0.474 | 0.561 | 1.000 | 0.558 | 0.468 | 0.003 |
| Los Chillos | 0 | | | | | | | | | |

Source: [lag_alignment], which also gives, for every station and lag, the paired hours, the share within 0.5, the mean signed and mean absolute differences and the ratio of means. At L = ±1, the share within 0.5 µg/m3 is between 0.039 and 0.097 and the mean absolute difference between 4.2 and 6.8. I widened the window to -6 to +6 hours to catch a possible 5-hour UTC offset. Lag 0 is the best lag for all eight stations with an overlap.

**Reading.** For eight stations the two files are the same extract, on the same clock. So the gap-fill file uses whatever convention `PM2.5.xlsx` uses, and merging on the stamps as given introduces no shift for those stations. The overlap cannot test Los Chillos.

### Daily profiles (mean by hour of day, all days)

| Station | Gap-fill, Jan 13 to 25: morning peak / afternoon-evening peak / daily low | PM2.5.xlsx, Dec 30 to Jan 12 | PM2.5.xlsx, Jan 26 to Feb 8 |
|---|---|---|---|
| Belisario | 9 / 15 / 3 | 11 / 15 | 10 / 14 |
| Carapungo | 7 / 19 / 0 | 7 / 20 | 7 / 19 |
| Centro | 7 / 14 / 23 | 11 / 15 | 7 / 14 |
| Cotocollao | 7 / 17 / 20 | 11 / 15 | 10 / 14 |
| El Camal | 7 / 15 / 17 | 7 / 14 | 7 / 14 |
| Guamaní | 7 / 19 / 2 | 11 / 16 | 7 / 14 |
| Los Chillos | 10 / 23 / 16 | 4 / 20 (only 7 or 8 days per hour) | no data |
| San Antonio | 8 / 15 / 3 | 11 / 14 | 11 / 14 |
| Tumbaco | 7 / 18 / 0 | 6 / 15 | 7 / 18 |

Source: [diurnal_peaks] (morning window 04:00 to 11:00, afternoon-evening window 14:00 to 23:00), with full profiles in [diurnal_profiles], including weekday-only profiles. The PM2.5.xlsx profile for January 13 to 25 is identical to the gap-fill profile for the eight shared stations.

- **Morning peak.** In the 13 gap-fill days and in the two weeks after, the morning maximum falls at 07:00 for most stations. In the two weeks before, which include the year-end holidays, it falls later (11:00) at five stations. A 07:00 morning maximum, with the daily low between 20:00 and 03:00 at seven of nine stations in the gap-fill window, matches local Quito time (UTC-5). If the stamps were truly UTC, the morning traffic peak would show near 12:00. The "UTC" in `PM2.5.xlsx`'s date format therefore looks like a display label, not the real time zone. Confidence: high.
- **Afternoon maximum.** In the two neighbouring windows it falls at 14:00 or 15:00 at most stations (6 of 9 and 6 of 8), not at the 17:00 to 19:00 evening rush; in the gap-fill window at 4 of 9. It says little about timing.
- **Shift test on profiles.** I compared the gap-fill daily profile with the PM2.5.xlsx profiles of the neighbouring weeks at circular shifts of -6 to +6 hours. The best shift is 0 for all eight shared stations against the week after. Against the week before, it is 0 for six, +1 for Centro (0.844 against 0.832 at 0) and -1 for Guamaní (0.660 against 0.626) [diurnal_shift].
- **Hour beginning or hour ending cannot be settled from these data.** Both conventions put the Quito morning rush in the 07:00 stamp, and the two files agree with each other. The Marco QA/QC REMMAQ (dated 18/11/2025) and the email do not say. The convention matters only for reading the peak-hour window: stamps 7 to 9 cover 06:00 to 09:00 if hour-ending, or 07:00 to 10:00 if hour-beginning. It does not affect merging the two files.

### Los Chillos timing against the other stations

Since there is no overlap, I correlated each station's hourly series with the mean of the other stations at lags -6 to +6, within the same file [timing_vs_other_stations].

| Station | Gap-fill, Jan 13 to 25 | PM2.5.xlsx, Dec 30 to Jan 12 | PM2.5.xlsx, Jan 2023 (pre-period) |
|---|---|---|---|
| Los Chillos best lag (corr at best; at 0) | -2 (0.472; 0.314) | -2 (0.486; 0.309) | -1 (0.571; 0.570) |
| Other stations best lag | 0 for six; -1 Belisario; +1 Tumbaco | 0 for six; +1 Carapungo and San Antonio | 0 for six; +1 San Antonio |

*Superseded on 2026-10-01 by a dedicated test against Los Chillos's own record; see `reports/air_quality/2026-10-01_pm25_followup.md` and `air_quality/output/local/diagnostics/pm25_gap/loschillos_timing_*.csv`.* Against the other stations, the gap-fill Los Chillos correlates best two to three hours earlier (0.4721 at t-2 against 0.4703 at t-3 and 0.3137 at t, over the other eight columns), and its weekday morning peak is at 10:00. REMMAQ's own Los Chillos record also lags the other stations in the two weeks before the outage, by one to two hours (best -2 at 0.4859, nearly tied with -1 at 0.4847; 0.3085 at lag 0), but not in January 2023 (lags -1 and 0 tied, 0.5712 and 0.5701). The dedicated test is inconclusive. Within ±3 hours, the gap-fill's weekday profile matches the station's own March 2025 and January to March 2024 profiles best at the same shift (-3 hours, on the edge of the range), but the lag test against March 2025 does not confirm a shift, and the unshifted profiles do not match. Whether the gap-fill column keeps REMMAQ's timing for this station is therefore not established (question 7).

## 4. Values

### Summary by station, gap-fill file, 2025-01-13 to 2025-01-25 (µg/m3 assumed)

| Station | n | Min | Median | Mean | p99 | Max | Zeros | Negatives | ≥500 | Sentinels | Decimals (modal / max) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Belisario | 311 | 0.14 | 13.97 | 16.16 | 48.88 | 57.40 | 0 | 0 | 0 | 0 | 2 / 2 |
| Carapungo | 312 | 0.00 | 11.00 | 12.53 | 41.59 | 82.98 | 2 | 0 | 0 | 0 | 2 / 2 |
| Centro | 310 | 0.07 | 12.94 | 14.37 | 41.92 | 49.75 | 0 | 0 | 0 | 0 | 2 / 2 |
| Cotocollao | 311 | 0.00 | 11.11 | 13.20 | 49.40 | 61.33 | 2 | 0 | 0 | 0 | 2 / 2 |
| El Camal | 254 | 0.30 | 15.36 | 16.95 | 58.07 | 74.97 | 0 | 0 | 0 | 0 | 2 / 2 |
| Guamaní | 261 | 0.82 | 18.00 | 18.74 | 46.18 | 54.21 | 0 | 0 | 0 | 0 | 2 / 2 |
| **Los Chillos** | 311 | 1.60 | 12.15 | 13.60 | 34.87 | 48.98 | 0 | 0 | 0 | 0 | **4 / 5** |
| San Antonio | 291 | 0.00 | 10.30 | 12.01 | 36.82 | 65.30 | 3 | 0 | 0 | 0 | 1 / 1 |
| Tumbaco | 311 | 0.02 | 8.85 | 9.24 | 25.58 | 27.69 | 0 | 0 | 0 | 0 | 2 / 2 |

Source: [values_by_station]. "Sentinels" counts -9999, -999, -99, -9, 999, 9999 and 99999. The same CSV gives the same summary for `PM2.5.xlsx` over January 13 to 25 (identical for the eight shared stations), the two weeks before, the two weeks after, and January 2023.

### Flags and status codes

None found. There are no text cells, negative values, sentinel codes or values of 200 or more, and no comments, colour fills, conditional formats or data validation in either workbook. Missing hours are empty cells, so the file carries no "invalid" marker, and nothing distinguishes a value removed by QA/QC from one never recorded. The QA/QC framework (section 7) mentions a dataset "separada en datos válidos, outliers y flags de auditoría", but no flag layer came with either file (question 5).

### Units

- **Eight shared stations: µg/m3, as in `PM2.5.xlsx`.** They are identical to `PM2.5.xlsx`, which `air_quality/data/raw/README.md` documents as µg/m3. Confidence: very high.
- **Los Chillos: almost certainly µg/m3 by level.** Confidence: high for the unit, not established for calibration or validation stage.
  - Its gap-fill median is 12.15 and mean 13.60, with a maximum of 48.98.
  - In `PM2.5.xlsx`, Los Chillos averaged 16.66 in January 2023 (median 15.20, maximum 66.67) and 9.46 over the 176 hours it has in December 30 to January 12.
  - Its ratio to neighbouring Tumbaco is about 1.47 in the gap-fill window. In `PM2.5.xlsx` the ratio is 1.25 in January 2023 and 1.33 in the two weeks before (means from [values_by_station]).
  - A unit error (mg/m3, or a factor of 10) would be obvious, and there is none.
- Neither file says whether concentrations are at local or standard conditions, which matters at 2,800 m (question 3).

### Decimal precision, a sign of a different processing step

| | 0 decimals | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Gap-fill Los Chillos | 0 | 0 | 2 | 19 | 189 | 101 |
| Gap-fill San Antonio | 34 | 257 | 0 | 0 | 0 | 0 |
| Gap-fill other seven stations (each) | 0 to 6 | 20 to 34 | 230 to 286 | 0 | 0 | 0 |
| PM2.5.xlsx, every year 2004 to 2026, all stations | yes | yes | yes | **0** | **0** | **0** |

Source: [decimals]. The other eight gap-fill columns match the REMMAQ download exactly, at 2 decimals (1 for San Antonio). Los Chillos alone carries 3 to 5. It probably comes from a different table or processing stage than the "LIMPIO" series, for example values before validation or before rounding, or hourly means computed from shorter readings. Los Chillos also has no zeros and a minimum of 1.60, while validated columns occasionally show 0.00; that is a weak hint in the same direction. Only the Secretaría can confirm (question 1).

### Consistency across fields

There are no internal contradictions to test beyond the above. The eight shared columns are mutually distinct and consistent with the neighbouring weeks.

## 5. Stability over time

- **Gap-fill file:** at 13 days, it is too short for a time-stability test. Its one break is across stations: Los Chillos has a different precision from the rest, as shown above.
- **PM2.5.xlsx (district-wide structure):**
  - No value has more than 2 decimals in any year from 2004 to 2026 [decimals].
  - Time stamps are exact hours throughout.
  - Row-sequence gaps are short and mostly at New Year [pm25xlsx_timeline_gaps].
  - The counts of values with 0 or 1 decimals more than double from 2016 to 2017. San Antonio is stored at 1 decimal, so this may reflect stations joining the file, but I did not test that by station.

## 6. Fit for purpose

**What it can support:**

- Filling Los Chillos for 2025-01-13 to 2025-01-25. That gives full weekday peak-hour coverage for the weeks starting January 13 and 20, so those two of the seven gap weeks could pass the balance rule.
- For the other eight stations, it confirms that the reference file is correct for these 13 days: same values, same holes, same clock.

**What it cannot support:**

- The other five gap weeks (starting 2025-01-27 to 2025-02-24), for which Los Chillos is still missing.
- The later 2025 and 2026 losses from the balance rule (Los Chillos from April to November 2025, Guamaní from July 2025; see `docs/known_issues.md`).
- Any claim that the Los Chillos values were validated to the same standard as the rest. Mixing them into the Centro synthetic control without that confirmation would put unvalidated donor data into a preferred specification.
- A firm statement on hour beginning versus hour ending.

**Practical consequence for comment 1 of the Secretaría.** The data for January and February 2025 are indeed in REMMAQ for most stations, and they are already in our download. The gap came from one missing station (Los Chillos) combined with the panel's balance rule, not from a failed download of all stations. A REMMAQ extract of validated Los Chillos for 2025-01-06 to 2025-03-02 would close the whole gap in a single, consistently processed series. That is preferable to splicing a differently processed 13-day column.

## Questions for the Secretaría de Ambiente (en español, listas para el correo)

1. **Origen de la columna LOS CHILLOS.** En el archivo DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx, las ocho columnas de Belisario, Carapungo, Centro, Cotocollao, El Camal, Guamaní, San Antonio y Tumbaco coinciden exactamente con el archivo PM2.5.xlsx que descargamos del portal datosambiente.quito.gob.ec el 26 de mayo de 2026. En cambio, 309 de los 311 valores de Los Chillos tienen entre 3 y 5 decimales, mientras que todos los valores de PM2.5 del archivo que descargamos, de 2004 a 2026 y en todas las estaciones, tienen como máximo 2 decimales (San Antonio, como máximo 1). ¿De qué base o etapa de procesamiento proviene la columna de Los Chillos? ¿Son datos validados con el mismo protocolo del Marco QA/QC de la REMMAQ, o datos crudos o preliminares? ¿Son promedios horarios calculados a partir de registros de mayor resolución temporal (por ejemplo, a intervalos de minutos)?
2. **Los Chillos en enero, febrero y marzo de 2025.** En el archivo PM2.5.xlsx que descargamos del portal datosambiente.quito.gob.ec el 26 de mayo de 2026, Los Chillos no tiene datos entre el 7 de enero y el 28 de febrero de 2025 (y solo 8 de 24 horas el 6 de enero), aunque su archivo sí los tiene del 13 al 25 de enero. Tampoco tiene datos entre el 9 y el 22 de marzo de 2025. ¿Podrían enviarnos la serie horaria validada de PM2.5 de Los Chillos del 6 de enero al 2 de marzo de 2025 y del 8 al 23 de marzo de 2025, en el mismo formato y con el mismo nivel de validación que el portal? Si no existe validada para todo ese período, ¿qué días están disponibles y con qué nivel de validación?
3. **Unidades y condiciones de referencia.** ¿Confirman que el PM2.5 está en µg/m3? ¿Las concentraciones se reportan a condiciones locales (presión y temperatura de Quito) o corregidas a condiciones estándar (25 °C, 1 atm)? ¿Es igual para todas las estaciones y para todo el período 2022 a 2026?
4. **Convención horaria.** ¿La hora registrada (por ejemplo, 07:00) corresponde al inicio del promedio (07:00 a 08:00) o al final (06:00 a 07:00)? ¿Es hora local de Ecuador (UTC-5)? En el archivo PM2.5.xlsx que descargamos del portal datosambiente.quito.gob.ec el 26 de mayo de 2026, la columna de fecha tiene el formato "UTC", pero el comportamiento diario de los datos sugiere hora local.
5. **Datos faltantes y banderas.** En ambos archivos las horas sin dato aparecen como celdas vacías. ¿Una celda vacía significa dato invalidado por el control de calidad, o dato no registrado (falla de equipo o de energía)? El Marco QA/QC menciona una serie "separada en datos válidos, outliers y flags de auditoría". ¿Sería posible recibir esas banderas para PM2.5 en las estaciones Belisario, Carapungo, Centro, Cotocollao, Guamaní, Los Chillos, San Antonio y Tumbaco desde diciembre de 2022?
6. **Interrupciones del 13 al 16 de enero de 2025.** El Camal no tiene datos del 13 de enero a las 00:00 al 15 de enero a las 08:00, y Guamaní del 14 de enero a las 14:00 al 16 de enero a las 15:00. ¿Corresponden a fallas de equipo o de energía, o a datos invalidados? ¿Existen datos de esas horas en alguna otra base?
7. **Referencia horaria de Los Chillos.** En su archivo, el perfil horario de Los Chillos en días laborables tiene su pico de la mañana a las 10:00. En el archivo PM2.5.xlsx que descargamos del portal datosambiente.quito.gob.ec el 26 de mayo de 2026, para la misma estación, ese pico cae a las 09:00 en marzo de 2025 y a las 08:00 entre enero y marzo de 2024, y el perfil diario de su archivo, comparado hora por hora, no coincide con el de esos períodos. ¿La columna de Los Chillos de su archivo usa la misma referencia horaria que los datos publicados en el portal para esa estación? ¿Hubo algún cambio de reloj o de configuración del equipo en enero de 2025?
8. **Resto de 2025 y 2026.** En el archivo PM2.5.xlsx que descargamos del portal datosambiente.quito.gob.ec el 26 de mayo de 2026 (que llega hasta el 31 de marzo de 2026), Los Chillos no tiene datos de PM2.5 entre la tarde del 31 de marzo y la mañana del 10 de diciembre de 2025, Guamaní no tiene datos desde el 18 de junio de 2025 hasta el final del archivo, y San Antonio tiene solo 102 horas en noviembre de 2025 y 1 hora entre diciembre de 2025 y marzo de 2026. ¿Se trata de períodos en que las estaciones no midieron, o existen datos que no se publicaron en el portal? Si existen, ¿podrían compartirlos?

## Files

All in `reports/data_audits/`, prefix `2026-10-01_aq_secretaria_pm25_gapfill_`:

- `audit.py` (the script; reads raw files read-only, writes only the CSVs below)
- `inventory.csv`, `pm25xlsx_timeline_gaps.csv`
- `coverage_joint.csv`, `coverage_station_day.csv`, `coverage_station_hour.csv`, `gapfill_missing_runs.csv`, `weekday_peak_hour_coverage.csv`, `pm25xlsx_weekly_coverage_gapweeks.csv`
- `values_by_station.csv`, `decimals.csv`, `gapfill_column_pairs.csv`
- `lag_alignment.csv`, `diurnal_profiles.csv`, `diurnal_profiles_jan2023.csv`, `diurnal_peaks.csv`, `diurnal_shift.csv`, `timing_vs_other_stations.csv`
