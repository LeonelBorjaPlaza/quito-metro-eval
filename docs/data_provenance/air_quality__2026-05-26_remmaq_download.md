# air_quality: REMMAQ hourly files, download of 2026-05-26

Written 2026-10-01 (workstream A) to settle the download date. The store folder predates the dated-delivery convention, so it has no date in its name.

- **Store folder:** `/home/leonelb/data/quito-metro-eval/air_quality/raw/data/raw/remmaq/` (reached through the committed symlink `air_quality/data/raw`). Fingerprints in the store's `MANIFEST.sha256`; for example, `PM2.5.xlsx` is `f68cf3bd…0f58f`.
- **Download date: 2026-05-26 for `PM2.5.xlsx` and the ten other workbooks last saved that day** (CO, DIR, HUM, IUV, LLU, NO2, PRE, RS, SO2, TMP). `PM10.xlsx` (file time and last save, by the Secretaría's account, on 2026-05-06; not used in the analysis) and `VEL.xlsx` (last saved by the Secretaría's account on 2026-04-07, file time 2026-05-26) were not part of that download. The date March 25, 2026 in the store's `air_quality/data/raw/README.md` belongs to an earlier download whose files were replaced. The README is in the locked raw store, so it was not edited; this note supersedes its date.

## Evidence

1. **The provenance note next to the files** (`remmaq/data_provenance_note.txt`, file time 2026-05-26 17:20 EDT) says the files were downloaded on May 26, 2026, from datosambiente.quito.gob.ec over a VPN. It also says that PM2.5, CO, NO2, SO2, TMP, DIR and HUM arrived as `.rar` archives with loose workbook parts, which were repackaged into `.xlsx` by uploading them to an outside AI chat tool (Claude Opus 4.7); the note states that only the container was repaired and no cell value changed.
2. **File times.** Twelve of the thirteen workbooks were last written on 2026-05-26 (between 16:15 and 19:27 EDT); `PM10.xlsx` on 2026-05-06. The README's file time is 2026-03-25.
3. **Workbook metadata** (`docProps/core.xml`). Eleven workbooks were last saved in Excel on 2026-05-26 by "Borja Plaza Leonel Alejandro"; `PM2.5.xlsx` at 20:22:58 UTC, which matches its file time of 16:22:59 EDT. `VEL.xlsx` (2026-04-07) and `PM10.xlsx` (2026-05-06) were last saved by "Maria Valeria Diaz Suarez". The pollutant workbooks (PM2.5, CO, NO2, SO2, PM10) were created on 2025-11-17 or 2025-11-18 by "Diaz Suarez Maria Valeria"; the weather and UV workbooks on 2026-04-06, by Leonel's account except `VEL.xlsx`, which records no creator. Creation dates record where a workbook started, not when the data were downloaded; `PM2.5.xlsx` holds data through 2026-03-31.
4. **Git history** (the imported old repository, under `air_quality/`):
   - `062346d`, 2026-03-25 15:58 EDT, "Document REMMAQ data download: source, variables, QA/QC", added `data/raw/README.md` with the March 25 date. The README has not changed since.
   - `7b725e4`, 2026-05-27 10:28 EDT, "Fix LOCAL pipeline: REMMAQ data format, ...", rewrote `read_remmaq()` for a new file layout. The code before that commit read each file with `sheet = sheet_name` and dropped its first data row with `df[-1, ]` as "the units row", which implies the March files had one sheet per variable and a units row (the files themselves are not in the store). The May files have one sheet named `LIMPIO` and no units row (read with `sheet = 1`, no row dropped).
5. **The current files have the May layout.** `PM2.5.xlsx` has the single sheet `LIMPIO` and no units row (`air_quality/output/local/diagnostics/pm25_gap/pm25_gap_trace_facts.csv`); all thirteen workbooks have one sheet, `LIMPIO` (twelve) or `Sheet1` (`PM10.xlsx`).
6. **No other source gives a date.** `MANIFEST.sha256` records fingerprints, not dates, and the store folder name has no date.

## What stays open

- The March 25 files are not in the store, so the two downloads cannot be compared.
- **Source confirmed (Leonel, 2026-10-05):** all the May 2026 files came from the REMMAQ portal. Why `VEL.xlsx` and `PM10.xlsx` carry saves by the Secretaría's account (April 7 and May 6) is not established; it does not change their source.
