# Known issues

Items carried over from earlier work and from the first look at the new deliveries (2026-09-24). None has been fixed in this repository yet. Each needs checking against the code and data here. Add new items at the top of their module with the date, the evidence and a status: open, fixed in <commit>, or won't fix (and why).

## air_quality

- **Open.** PM2.5 gap for all stations in the frozen weekly panel: seven weeks, from the week starting 2025-01-13 to the week starting 2025-02-24. The Secretaría de Ambiente says REMMAQ holds these data (email of 2026-09-04). Its file covers only 2025-01-13 00:00 to 2025-01-25 23:00, about two of the seven weeks, so the rest still needs a REMMAQ download. Workstream A must first establish whether the data were lost at download or in processing.
- **Open.** `read_remmaq()` drops the first row with `df[-1,]`. Check that it never drops a real observation.
- **Open.** `descriptives_summary_stats.csv` swaps the distances of Tumbaco and San Antonio. Table 2 of the paper is correct.
- **Open.** CO_4 contains CONDADO instead of TUMBACO.
- **Open.** PM2.5 starts about eight months later than the gases.
- **Open.** The CO, NO2 and SO2 cross-sample scripts were made by text substitution from the PM2.5 template and have not had the verification pass that PM2.5 had.
- **Open.** HUM has near-zero readings that may be sensor artifacts. Wind direction (DIR) needs a circular mean.
- **Open.** Satellite pipeline: no script produces `ucdb_donor_distances_all.csv`, yet the run scripts need it; the run scripts read it from `data/` while `05_descriptives.R` reads `data/working/`. The VM copy of `00_helpers.R` is the authoritative one.
- **Open.** The May 31, 2026 paper PDF postdates the May 28 CSV export. Where the two differ, the PDF governs cited numbers until the tables are regenerated.

## congestion

- **Open, provider.** Waze February to April 2025: March is missing and February and April are thin. Treated as missing.
- **Open, provider.** Records arrive once or three times with identical values. The derived panel deduplicates them.
- **Open, provider.** The Waze-network ratio, the spread ratio and severe persistence are contaminated and not used.
- **Open, provider.** 8,290 fast-road keys have no all-road match.
- **Open, Leonel.** Question to Juan Camilo on absent records (true zero or no data). Step 1 runs under provisional zero coding; final numbers wait for the answer.
- **Note.** REMMAQ monitor coordinates in the spatial layer are rounded to 0.01 degrees. `MetroStations.shp` is empty; use the `.gpkg`.

## road_safety

- **Open, provider.** No records for 2020 or earlier with coordinates and the same variables, so the series starts in January 2021.
- **Open.** One record has the text "X (SICARIATO)" in the deaths field instead of a number, which suggests a homicide rather than a road crash. Decide how to treat it and document the rule.
- **Open.** The urban or rural field (ZONA) is empty for 960 records.
- **Open, provider.** The typology "ATIPICO" (about 2,700 records) has no definition yet.
- **Open.** Coordinates are stored partly as text and partly as numbers in the Excel file. All convert to numbers, but no point has yet been checked against the district boundary.
