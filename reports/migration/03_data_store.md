# Phase 3. Data store, links and the new deliveries, 2026-09-24

## Result

Raw inputs sit once in `/home/leonelb/data/quito-metro-eval/<module>/raw/`, and the derived data and outputs of both sources sit in `frozen_<date>/` reference folders. Everything is locked. All 1,078 copies from the data map, plus the four files from `NEW_DATA`, match their source by sha256, and `MANIFEST.sha256` (1,083 lines) agrees with the map for every row. Each module reaches its raw folders through five committed absolute symlinks. No link is broken, and git tracks no file under a `raw/` or `frozen_` path except those links.

## Classification

`reports/migration/03_classify_data.py` lists every ignored file, every untracked non-code file and every tracked data file in both sources, hashes it, and classes it. The result is `reports/migration/03_data_map.csv` (source path, git status, size, sha256, class, new location, evidence). Environment files (package libraries, IDE state, shell history) appear as one summary row per folder and are not copied.

| Module | Class | Files | Size | Destination |
|---|---|---|---|---|
| air_quality | raw | 117 | 2.284 GB | `air_quality/raw/<path>` |
| air_quality | derived | 38 | 3.225 GB | `air_quality/frozen_2026-05-29/<path>` |
| air_quality | output | 834 | 0.100 GB | `air_quality/frozen_2026-05-29/<path>` |
| air_quality | delivery copies | 4 | 0.010 GB | the two dated delivery folders |
| air_quality | environment | 10 summary rows | 0.385 GB | not copied (`.venv`, `renv/library/windows`, `.Rproj.user`, `.Rhistory`, `.claude/settings.local.json`) |
| congestion | raw | 37 | 6.561 GB | `congestion/raw/<path>` |
| congestion | derived | 4 | 0.193 GB | `congestion/frozen_2026-09-17/<path>` |
| congestion | output | 44 | 0.036 GB | `congestion/frozen_2026-09-17/<path>` |
| congestion | environment | 1 summary row | 0.256 GB | not copied to the store (`Output/Waze/_environment/`; see Phase 4) |

The frozen folders are named after each source's last commit: `64eb72a` on 2026-05-29 for air quality and `121a6a6` on 2026-09-17 for congestion.

Class decisions worth knowing:

- **Air quality raw**: `data/raw/remmaq/*` (the eleven REMMAQ files that `01_read_and_merge.R:129-141` reads, plus IUV, PM10, the QA/QC PDF and a provenance note), `data/raw/satellite/**` (Earth Engine exports read by `python/02b_merge.py`), `data/raw/GHS_UCDB/*`, the tracked `data/raw/README.md`, `CALENDARIO-FERIADOS.pdf` and `ecuador_blackouts_2024.xlsx`, and `data/for_maps/*` (read by `fig1_metro_airquality_map.R`). Also, by the when-in-doubt rule, the five Stata files in `data/processed/satellite/*.dta` (no script writes `.dta`) and the tracked `data/working/donor_list.csv` and `donor_pool_100_with_rationales.csv` (no script writes them).
- **Air quality derived**: `data/processed/*.csv` (written by `01` and `02`), `data/processed/satellite/*.csv` (written by `python/02b_merge.py` and the `laptop_R` scripts), the tracked `data/working/` donor tables and `ucdb_lac.*` (written by `laptop_R/01b_donor_pool_selection.py` and `python/01_geometries_ucdb.py`), and `.RData`, an interactive workspace from the 03/04 scripts.
- **Air quality output**: every file under `output/`, tracked or not (local tables, figures, cross-sample summaries, spatial placebo, maps, all satellite tables, figures and logs, and `output/local/tables.zip`).
- **Congestion raw**: `Data/Waze/raw/*` (the delivery: hourly CSV and Parquet, polygons, road lengths), `Data/spatial/*`, and the tracked copies of the paper and its tables in `docs/paper/`.
- **Congestion derived**: `Data/Waze/parquet/*` (written by `02_prepare_blocks.R:21`) and the tracked `reports/waze_sample.csv` (written by `01_inventory.R:173`).
- **Congestion output**: `Output/Waze/**` except `_environment/`, tracked or not.
- **Delivery copies inside AQ_SRC**: the Secretaría Excel file in `data/raw/remmaq/` is byte-identical to the one in `NEW_DATA`, so it is stored once. The other three (the Secretaría email, and the crash Excel file and email in `data/traffic-accidents/`) differ in bytes from the `NEW_DATA` files. They are kept in a `copy_found_in_AQ_SRC/` subfolder of the matching delivery. The crash Excel copy differs only in the `DIA` column, which holds English day names (see the provenance note).

Tracked files keep their tracking, with one exception. The four tracked files under `air_quality/data/raw/` (`README.md`, `CALENDARIO-FERIADOS.pdf`, `ecuador_blackouts_2024.xlsx`, `GHS_UCDB/readme_V1_1.txt`) were removed from the tracked tree so that the folder could become one link into the store and the "no tracked file under `raw/`" check could hold. They stay in the history and can still be read through the link. The store holds the OneDrive bytes; `readme_V1_1.txt` differs from the git copy only by CRLF line endings.

## Store layout

```
/home/leonelb/data/quito-metro-eval/
├── MANIFEST.sha256                                     1,083 files, paths relative to the store
├── air_quality/
│   ├── raw/data/raw/{remmaq,satellite,GHS_UCDB}/ ...   plus README.md, CALENDARIO-FERIADOS.pdf, ecuador_blackouts_2024.xlsx
│   ├── raw/data/for_maps/                              nine map layers
│   ├── raw/data/processed/satellite/*.dta              five Stata files (raw by default)
│   ├── raw/data/working/{donor_list,donor_pool_100_with_rationales}.csv
│   ├── raw/2026-09-07_secretaria_ambiente_pm25_gapfill/   Excel file, email, SHA256SUMS, copy_found_in_AQ_SRC/
│   └── frozen_2026-05-29/{data,output}/ ... and .RData    872 files, 3.1 GB
├── congestion/
│   ├── raw/Data/Waze/raw/                              the Waze delivery, 6.2 GB
│   ├── raw/Data/spatial/                               nine map layers
│   ├── raw/docs/paper/                                 paper PDF, text and 22 result tables
│   └── frozen_2026-09-17/{Data/Waze/parquet,Output/Waze,reports}/   48 files, 219 MB
└── road_safety/
    └── raw/2026-09-23_amt_siniestros/                  Excel file, email, SHA256SUMS, copy_found_in_AQ_SRC/
```

Locking: `find */raw */frozen_* -mindepth 1 -exec chmod a-w {} +` and `chmod a-w */frozen_*`. The top `raw/` folders stay writable for new dated deliveries; a test file could be created and removed there, while writing inside `air_quality/raw/data/raw/remmaq/` failed with "Permission denied". `MANIFEST.sha256` stays writable so Phase 6 can append orphan inputs.

## Links committed in git (mode 120000)

| Link | Target |
|---|---|
| `air_quality/data/raw` | `/home/leonelb/data/quito-metro-eval/air_quality/raw/data/raw` |
| `air_quality/data/for_maps` | `/home/leonelb/data/quito-metro-eval/air_quality/raw/data/for_maps` |
| `congestion/Data/Waze/raw` | `/home/leonelb/data/quito-metro-eval/congestion/raw/Data/Waze/raw` |
| `congestion/Data/spatial` | `/home/leonelb/data/quito-metro-eval/congestion/raw/Data/spatial` |
| `road_safety/data/raw` | `/home/leonelb/data/quito-metro-eval/road_safety/raw` |

- Only folders that hold nothing but raw inputs got a link. The raw `.dta` files in `data/processed/satellite/` got no link, because no script reads them. The two raw CSVs in `data/working/` and the paper copies in `congestion/docs/paper/` stay tracked where the code expects them.
- `air_quality/.here` (empty) was added, so `here::here()` resolves to `air_quality/` in every checkout. The module already had `quito-metro-airquality-2026.Rproj`, which would also work; `.here` makes the choice explicit. Congestion does not use `here`.
- Derived folders (`air_quality/data/processed/`, `congestion/Data/Waze/parquet/`) are not linked. Each checkout rebuilds them.

## New deliveries

- `road_safety/raw/2026-09-23_amt_siniestros/`: the crash Excel file, its email, `SHA256SUMS`, and `copy_found_in_AQ_SRC/`.
- `air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/`: the PM2.5 Excel file, its email, `SHA256SUMS`, and `copy_found_in_AQ_SRC/`. Not linked into `air_quality/` and not merged into any panel.
- Both provenance notes were checked against the files (sheets, row counts, dates, columns, missing shares, the SICARIATO, ZONA and ATIPICO counts). Every fact matched and nothing was corrected. A "Stored and checked, 2026-09-24" section was added to each note, with the hashes and the extra copies.

## Checks

- Tracked files under a `raw/` or `frozen_` path that are not symlinks: none.
- Broken links (`find . -xtype l`): none.
- Tracked files above 5 MB: `congestion/Output/Waze/descriptives/cell_month_blocks.rds` (14,768,340 bytes), an aggregated Phase C output tracked by the congestion history.
