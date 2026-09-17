# Run top to bottom from the repository root in a fresh R session.
# Rscript Scripts/Congestion/00_orient.R
# Reads frozen inputs; creates text conversions, reports, and readiness checks only.
# No model is fitted and no treatment effect is calculated.
stopifnot(file.exists("AGENTS.md"), dir.exists("docs/paper/results"))
Sys.setenv(TZ = "America/New_York")
local_library <- "Output/Waze/_environment/R-library"
if (dir.exists(local_library)) .libPaths(c(normalizePath(local_library), .libPaths()))
options(width = 160, digits = 15)
paths <- c("Data/Waze/raw", "Data/Waze/parquet", "Data/spatial", "docs",
           "reports", "Scripts/Congestion", "Output/Waze")
for (path in paths) dir.create(path, recursive = TRUE, showWarnings = FALSE)
stopifnot(nzchar(Sys.which("pandoc")), nzchar(Sys.which("pdftotext")))
stopifnot(system2("pandoc", c("docs/Documentacion_Indicadores_Waze.docx", "-t", "gfm",
  "--wrap=none", "-o", "docs/waze_documentation.md")) == 0L)
stopifnot(system2("pdftotext", c("-layout", "docs/paper/Underground-relief.pdf",
  "docs/paper/Underground-relief.txt")) == 0L)
doc_lines <- readLines("docs/waze_documentation.md", warn = FALSE)
paper_lines <- readLines("docs/paper/Underground-relief.txt", warn = FALSE)
result_paths <- sort(list.files("docs/paper/results", pattern = "[.]csv$", full.names = TRUE))
results <- setNames(lapply(result_paths, read.csv, check.names = FALSE), basename(result_paths))
result_inventory <- data.frame(file = names(results),
  rows = vapply(results, nrow, integer(1)), columns = vapply(results, ncol, integer(1)),
  bytes = file.info(result_paths)$size, row.names = NULL)
all_results <- results[["results_all_pollutants.csv"]]
primary <- results[["results_primary_specs.csv"]]
consistency <- vapply(c("PM25", "CO", "NO2", "SO2"), function(pollutant) {
  x <- results[[paste0("results_", pollutant, ".csv")]]
  y <- all_results[all_results$pollutant == x$pollutant[1], names(x)]
  isTRUE(all.equal(x, y, check.attributes = FALSE))
}, logical(1))
primary_consistency <- isTRUE(all.equal(primary,
  all_results[all_results$spec_short %in% c("M5b", "M8b", "M2b"), names(primary)],
  check.attributes = FALSE))
stopifnot(all(consistency), primary_consistency)
preferred <- primary[primary$spec_short == "M8b", ]
preferred <- preferred[match(c("pm25", "co", "no2", "so2"), preferred$pollutant), ]
belisario <- all_results[all_results$pollutant == "pm25" & all_results$spec_short == "M9", ]

stopifnot(requireNamespace("sf", quietly = TRUE))
stations_original <- sf::st_read("Data/spatial/MetroStations.gpkg", quiet = TRUE)
stations_shp <- sf::st_read("Data/spatial/MetroStations.shp", quiet = TRUE)
alignment <- sf::st_read("Data/spatial/MetroLine.gpkg", quiet = TRUE)
monitors <- sf::st_read("Data/spatial/Distancia_REMMAQ_Metro.gpkg", quiet = TRUE)
# Remove unused Z/M in memory before transformations and spatial operations.
stations <- sf::st_transform(sf::st_zm(stations_original), 4326)
station_coordinates <- cbind(sf::st_drop_geometry(stations), sf::st_coordinates(stations))
monitor_coordinates <- cbind(sf::st_drop_geometry(monitors), sf::st_coordinates(monitors))
san_francisco <- stations[stations$Name == "San Francisco", ]
stopifnot(nrow(san_francisco) == 1L,
          all(c("Centro", "Belisario") %in% monitors$Station))
sf_xy <- sf::st_coordinates(san_francisco)[1, ]
prompt_point <- sf::st_sfc(sf::st_point(c(-78.5158, -0.2203)), crs = 4326)
sf_discrepancy_m <- as.numeric(sf::st_distance(san_francisco, prompt_point))
parquet_path <- "Data/Waze/raw/grids_quito_hourly_2019-2025.parquet"
raw_files <- list.files("Data/Waze/raw", full.names = TRUE)
raw_sizes <- setNames(file.info(raw_files)$size, basename(raw_files))
stopifnot(requireNamespace("duckdb", quietly = TRUE))
parquet_check <- local({
  connection <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE))
  list(metadata = DBI::dbGetQuery(connection,
      "SELECT num_rows, num_row_groups, file_size_bytes, created_by FROM parquet_file_metadata(?)",
      params = list(parquet_path)),
    schema = DBI::dbGetQuery(connection, "DESCRIBE SELECT * FROM read_parquet(?)", params = list(parquet_path)),
    sample = DBI::dbGetQuery(connection, "SELECT * FROM read_parquet(?) LIMIT 1", params = list(parquet_path)))
})
allowed <- c("arrow", "duckdb", "data.table", "dplyr", "sf", "h3jsr", "ggplot2",
             "patchwork", "fixest", "synthdid", "augsynth")
package_versions <- setNames(vapply(allowed, function(package) {
  if (requireNamespace(package, quietly = TRUE)) as.character(packageVersion(package)) else "unavailable"
}, character(1)), allowed)
package_status_path <- "Output/Waze/_environment/package_status.rds"
package_status <- if (file.exists(package_status_path)) readRDS(package_status_path) else list()
h3_check <- local({
  connection <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE))
  extension_dir <- normalizePath("Output/Waze/_environment/duckdb_extensions", mustWork = TRUE)
  DBI::dbExecute(connection, paste("SET extension_directory =", DBI::dbQuoteString(connection, extension_dir)))
  DBI::dbExecute(connection, "SET autoinstall_known_extensions = false")
  DBI::dbExecute(connection, "LOAD h3")
  result <- DBI::dbGetQuery(connection,
    "SELECT h3_is_valid_cell('8866d3ad07fffff') AS valid, h3_get_resolution('8866d3ad07fffff') AS resolution")
  stopifnot(isTRUE(result$valid), result$resolution == 8L)
  result
})
seed <- system2("git", c("rev-list", "--max-parents=0", "HEAD"), stdout = TRUE)
git_state <- system2("git", c("status", "--short", "--branch"), stdout = TRUE)
frozen_files <- c("docs/Documentacion_Indicadores_Waze.docx", "docs/paper/Underground-relief.pdf", result_paths)
checks <- list(date = as.character(Sys.Date()), R = R.version.string,
  distro = system2("lsb_release", "-cs", stdout = TRUE),
  packages = package_versions, package_installation = package_status, h3_fallback = h3_check,
  paper_files = result_inventory, frozen_input_md5 = tools::md5sum(frozen_files),
  result_table_consistency = consistency, primary_consistency = primary_consistency,
  raw_file_sizes = raw_sizes, parquet = parquet_check,
  stations = station_coordinates, monitors = monitor_coordinates,
  station_shapefile_rows = nrow(stations_shp), alignment_features = nrow(alignment),
  station_source_crs = sf::st_crs(stations_original)$wkt,
  station_original_empty = sum(sf::st_is_empty(stations_original)),
  station_2d_empty = sum(sf::st_is_empty(stations)),
  san_francisco_prompt_discrepancy_m = sf_discrepancy_m, git_state = git_state,
  session = sessionInfo())
saveRDS(checks, "Output/Waze/phase_a_checks.rds")
writeLines(capture.output(str(checks, max.level = 3)), "Output/Waze/phase_a_checks.txt")

markdown_table <- function(x) {
  x[] <- lapply(x, function(column) gsub("|", "/", as.character(column), fixed = TRUE))
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |")))
}
installed_sentence <- paste(paste(names(package_versions)[package_versions != "unavailable"],
  package_versions[package_versions != "unavailable"]), collapse = ", ")
missing_sentence <- paste(names(package_versions)[package_versions == "unavailable"], collapse = ", ")
state <- c(
  "# Repository state: Phase A", "", paste("Checked", Sys.Date(), "from a fresh R session. No treatment effect was estimated."), "",
  sprintf("The repository began clean on `main` at `%s`. It contains three Waze delivery files, the provider DOCX, the 33-page paper, %d paper CSVs, and the copied spatial layers. No additional context brief or CLAUDE.md was present in docs/. The frozen inputs remain unchanged; the two text conversions are new.", substr(seed, 1, 7), length(results)), "",
  "The paper is `docs/paper/Underground-relief.pdf`. Its CSVs are `results_all_pollutants.csv`, `results_primary_specs.csv`, `results_{PM25,CO,NO2,SO2}.csv`, `trajectories_{PM25,CO,NO2,SO2}.csv`, `donor_weights_{PM25,CO,NO2,SO2}.csv`, `att_weekly_{PM25,CO,NO2,SO2}.csv`, and `descriptives_{sample_construction,summary_stats,time_series_data,treatment_timeline}.csv`, all under `docs/paper/results/`. Every CSV opens. Detailed file counts and source conflicts are in [00_source_checks.md](00_source_checks.md).", "",
  sprintf("`Data/Waze/raw/` contains `grids_polygons.csv` (%s bytes), `grids_quito_hourly_2019-2025.csv` (%s bytes), and `grids_quito_hourly_2019-2025.parquet` (%s bytes). DuckDB opens the Parquet and reads a row; its footer reports %s rows in %d row groups and its schema has %d columns. CSV/Parquet equivalence, coverage and H3 validity remain Phase B checks.",
    format(raw_sizes[["grids_polygons.csv"]], scientific = FALSE, big.mark = ","),
    format(raw_sizes[["grids_quito_hourly_2019-2025.csv"]], scientific = FALSE, big.mark = ","),
    format(raw_sizes[["grids_quito_hourly_2019-2025.parquet"]], scientific = FALSE, big.mark = ","),
    format(parquet_check$metadata$num_rows, scientific = FALSE, big.mark = ","),
    parquet_check$metadata$num_row_groups, nrow(parquet_check$schema)), "",
  sprintf("`Data/spatial/` contains MetroStations as GPKG (%d stations) and SHP/SHX/DBF/PRJ/CPG plus QGIS metadata (the shapefile has %d records), MetroLine.gpkg (%d alignment feature), and Distancia_REMMAQ_Metro.gpkg (%d monitors). Centro and Belisario are present. Use the GPKG stations, remove unused Z/M in memory, and transform their declared CRS. San Francisco differs from the prompt coordinate by %.1f metres. Provenance is the authors' copy from the air-quality repository; the QGIS metadata does not identify an upstream author or date.", nrow(stations), nrow(stations_shp), nrow(alignment), nrow(monitors), sf_discrepancy_m), "",
  paste0("R ", getRversion(), " runs on Ubuntu ", checks$distro, ". Available: ", installed_sentence, ". An Arrow read succeeded but one mixed-package session crashed at shutdown; a separate Arrow session with explicit cleanup exited normally. Use DuckDB for the workflow."), "",
  paste0("Unavailable: ", missing_sentence, ". `h3jsr` is blocked by V8's missing system library `libnode.so.127`; DuckDB's prebuilt h3 extension substitutes and loads in a fresh session. `synthdid` and `augsynth` are absent from the requested Posit CRAN index; no estimator is needed in Phase A. Packages use the ignored local library `Output/Waze/_environment/R-library`; scripts add it explicitly. Posit downloads are checked for prebuilt contents before installation. No package was compiled."), "",
  "The approved layout keeps deliveries in `Data/Waze/raw/`, reserves `Data/Waze/parquet/` for later derived data, and uses `Data/spatial/` for frozen spatial inputs, `docs/` for references, `reports/` for prose and the review sample, `Scripts/Congestion/` for executable R scripts, and `Output/Waze/` for generated checks and figures. The original Parquet stays in raw/ without duplication. `.gitignore` excludes Data/, environment files, and CSVs except `docs/paper/results/*.csv` and `reports/waze_sample.csv`. The sample will be generated and committed in Phase B.", "",
  "Reproduce with `Rscript Scripts/Congestion/00_orient.R`. Initial setup uses `00_install_packages.R --allow-dependencies` and `00_check_h3.R` in the same script folder. This phase stops at orientation; inventory, descriptives, strategy memo and review packet remain pending."
)
writeLines(state, "reports/00_repo_state.md")

effect_table <- data.frame(Pollutant = preferred$pollutant_label,
  `P1 log (CSV)` = sprintf("%.15f", preferred$att_p1_log),
  `P1 percent (CSV)` = sprintf("%.14f", preferred$att_p1_pct),
  `P1 log / percent (PDF Table 7)` = c("-0.130 / -12.2", "-0.056 / -5.4", "-0.064 / -6.2", "-0.025 / -2.5"),
  `P1 p (PDF)` = c("0.011", "1.000", "0.967", "0.187"), check.names = FALSE)
p_table <- data.frame(Pollutant = preferred$pollutant_label,
  `Full p (PDF Table 7)` = c("0.006", "1.000", "0.716", "0.124"),
  `Single p_2s (CSV)` = sprintf("%.3f", preferred$p_2s), check.names = FALSE)
notes <- c(
  "# Phase A source checks and handoff", "", paste("Date:", Sys.Date()), "",
  "These notes record existing paper outputs and source definitions. They do not re-estimate air-quality results or estimate a Waze effect. Carry every unresolved conflict into the strategy memo. The metadata and copied numeric fields can be regenerated by `Scripts/Congestion/00_orient.R`; PDF comparisons below are transcriptions from identified tables.", "",
  "## Paper and results", "",
  "The title page identifies Leonel Borja Plaza and Luis Quintero, *Underground Relief: The Air Pollution Effects of Quito's First Metro Line*, May 31, 2026. The PDF metadata uses the shorter title 'The Quito Metro and Urban Air Quality'; the visible title page supplies the citation. Sections 3 through 6 confirm the local augmented synthetic-control design with station fixed effects and conformal inference, the separate citywide satellite SDID design, and the untested direct traffic channel. Section 3.2 and Table 3 confirm weekday 07:00–09:00 and 17:00–19:00. The exact inclusion of endpoint hourly bins is not recoverable from prose alone; retain this as an implementation question.", "",
  "The preferred local specification is M8b, AugSynth with station fixed effects, Centro treated and Belisario retained in the donor pool. Do not confuse it with M5b, which omits station fixed effects. The exported primary table contains both, plus M2b SDID. The four pollutant-specific results tables agree with their rows in results_all_pollutants.csv, and results_primary_specs.csv agrees with the corresponding subset.", "",
  markdown_table(effect_table), "",
  sprintf("For preferred Centro PM2.5, the CSV gives the clean-window effect as %.16f log points (%.14f percent), the full-window effect as %.16f (%.14f percent), and P2 as %.16f (%.14f percent). PDF Tables 5 and 7 agree with these point estimates where reported, to displayed precision. They label the clean window 'donut'. The PDF reports p = 0.041 for the donut and p = 0.006 for the full window.", preferred$att_clean_log[1], preferred$att_clean_pct[1], preferred$att_overall_log[1], preferred$att_overall_pct[1], preferred$att_p2_log[1], preferred$att_p2_pct[1]), "",
  markdown_table(p_table), "",
  "Conflict P1: the CSVs have one p_2s per model, without a window label. Their PM2.5, NO2 and SO2 values differ from the PDF's full-window p-values and cannot stand in for the window-specific tests. No supplied CSV exports the complete set of window-specific conformal p-values. Preserve both sources; ask the authors which result export matches the PDF. Do not repair the frozen outputs.", "",
  sprintf("For Belisario treated with Centro excluded (M9), the CSV gives P1 %.16f log points (%.14f percent), clean %.16f (%.14f percent), and full %.16f (%.14f percent). PDF Table 5 rounds these to -0.062/-6.0 percent, -0.024/-2.3 percent, and 0.140/15.1 percent, with p-values 0.729, 0.849 and 0.698. Its full-window p-value differs from the CSV's p_2s = %.3f. PDF Table 6 reports a different leave-one-station-out exercise: Belisario +8.5 percent, p = 0.452, and Centro -12.2 percent, p = 0.012. The supplied files do not contain that complete spatial-placebo table; do not equate it with M9.", belisario$att_p1_log, belisario$att_p1_pct, belisario$att_clean_log, belisario$att_clean_pct, belisario$att_overall_log, belisario$att_overall_pct, belisario$p_2s), "",
  "The gas results support a narrower statement than 'all other pollutants are null in every period'. The PDF calls NO2 a well-fit null and CO uninformative. SO2 is insignificant before the disruption but positive in the donut window (13.1 percent, p = 0.055). The CSV clean-window SO2 estimate is 13.05990720576356 percent. The full-window p-value discrepancy matters for any stronger significance claim.", "",
  "Conflict P2: the weekly calendar differs from the proposed Waze monthly blocks. The paper's P1 ends with the week beginning 2024-09-09; the disruption spans week starts 2024-09-16 through 2024-12-16, followed by two transition weeks, 2024-12-23 and 2024-12-30. The paper reports pre-disruption, donut and full-window estimands, not simply separate P1 and P2 estimands. The Waze proposal of excluding all September–December 2024 is a monthly adaptation to evaluate, not an exact inherited calendar. PDF Table 3 and the supplied timeline agree on 52 pre weeks, 42 P1 weeks, 14 disruption weeks and 2 transition weeks. P2 contains only 6 PM2.5 weeks through March 2025 and 24 gas weeks through June 2025. It does not cover all of calendar 2025.", "",
  sprintf("Conflict P3: SDID window labels cannot be read literally from the exported overall column. For example, M2b PM2.5 att_overall_log is %.16f in the CSV, matching the PDF's rounded donut value -0.154, whereas PDF Table A.3 reports full -0.232 and pre-disruption -0.157. The CSV has NA in its SDID clean/P1/P2 fields. Exported SDID standard errors and p-values also exist, while the PDF explicitly declines to report valid local SDID inference. These are source-version or labeling questions for the authors, not a reason to fit anything again.", primary$att_overall_log[primary$pollutant == "pm25" & primary$spec_short == "M2b"]), "",
  "Conflict P4: descriptives_summary_stats.csv assigns distance 9.558 km to sanantonio and 16.650 km to tumbaco. PDF Table 2 and the spatial layer instead assign about 9.558 km to Tumbaco and 16.650 km to San Antonio de Pichincha. The monitor names and coordinates in the supplied spatial layer govern this module. Frozen CSVs stay unchanged.", "",
  "## Provider definitions and the initial schema", "",
  "Conflict W1: provider section 6 defines severe events as jam_level in {3,4}, while its section 9 dictionary defines severe_tci by speed below 40 percent of free flow. The document does not establish equivalence. Keep this unresolved for Víctor and Juan Camilo.", "",
  "Provider section 5.1 describes monthly segment free flow inferred from jam speed, delay and segment length and aggregated with length weights. Its section 9 explicitly lists the 1–2 a.m. reference. Ask how that night restriction enters the formula and whether network coverage or the eligible segment set changes monthly.", "",
  "Conflict W2: free flow is the direct denominator of speed ratios, but section 4.2 defines tci_osm_ratio with OSM road length and the nominal observation count in its denominator. The claim that every ratio directly divides by free flow is too broad. Free flow can still affect severity classification, roadtype membership and speed outcomes. Distinguish these channels in the memo.", "",
  "Provider section 7.1 averages hourly profiles over all days. Weekday-specific variants exist in the pipeline, but the delivered schema has no day-of-week field. It also has no flag_corr_type, observation-count field, jam-count field, or road-length field. Section 8.2 says summarized tables filter flags by default; that claim cannot be audited from this delivery. Phase B must distinguish record counts from actual observation counts and avoid presenting the former as direct Waze penetration measures.", "",
  "Conflict W3: delivered names include avg_jam_speed_ratio and t_speed_ratio rather than jam_speed_ratio and speed_ratio, and tci_severe rather than severe_tci. Both avg_freeflow and freeflow_speed are present. The date field is an integer, not the dictionary's timestamp. These are candidate mappings to verify numerically in Phase B. No identity, density, coverage, or absent-row interpretation has yet been verified.", "",
  "Provider section 3.1 confirms six stacked roadtype labels, based on free-flow speed rather than OSM functional road classes. 'large' means free flow above 50 km/h, so an arterial interpretation is provisional. The two-level split excludes exactly 40 km/h because both comparisons are strict. Every later aggregation must select one roadtype block. These statements come from the documentation; observed category values are a Phase B check.", "",
  "## Spatial provenance and readiness", "",
  sprintf("Conflict S1: MetroStations.shp opens with %d features; MetroStations.gpkg contains %d. The shapefile sidecars and QGIS metadata are present, but the QGIS metadata has an empty abstract, no contact/date provenance, and invalid placeholder bounds. Use the GPKG, whose layer is insumos_pmm_dmq__estaciones_metro. Its declared CRS is WGS_1984_SIRES_TMQ (ESRI:65162), not an EPSG-coded UTM CRS. Transform using the embedded definition. Drop unused Z/M dimensions in memory: the M values are NaN and printing shows misleading POINT ZM EMPTY labels, although st_is_empty is false for all points and XY coordinates are finite. No source layer was edited.", nrow(stations_shp), nrow(stations)), "",
  sprintf("Conflict S2: GPKG San Francisco transforms to latitude %.10f, longitude %.10f. The supplied approximate coordinate (-0.2203, -78.5158) is %.1f metres away using sf's s2 distance. The layer coordinate governs future groups. The monitor layer has %d features, including Centro at (-0.2200, -78.5100) and Belisario at (-0.1800, -78.4900), in latitude/longitude order. It also contains El Camal, which is not one of the paper's eight study monitors; the spatial layer and the estimation sample therefore have different counts. No monitor coordinate is missing.", sf_xy["Y"], sf_xy["X"], sf_discrepancy_m, nrow(monitors)), "",
  "The monitor file's HubName and HubDist refer to nearest stations: Centro is tied to San Francisco and Belisario to Iñaquito. Do not silently describe these values as shortest distance to the continuous rail alignment. The source layer records elevations for monitors only, not for H3 cells. No UNESCO boundary, cell elevation layer or population-density layer was supplied. The authors identify all three spatial datasets as copies from the air-quality repository; upstream acquisition dates and versions are absent from the supplied metadata.", "",
  "## Package installation", "",
  paste0("System: ", R.version.string, "; Ubuntu ", checks$distro, ". Available versions: ", installed_sentence, ". Unavailable: ", missing_sentence, "."), "",
  "The requested Posit resolute endpoint initially served source archives because R's default libcurl user agent did not transmit its version correctly. The installer refused those archives. Setting the explicit R user agent documented in [Posit's binary configuration guide](https://docs.posit.co/rspm/admin/serving-binaries/) selected prebuilt packages. The installer checks the Built field, R minor version, platform, prebuilt package metadata and absence of a source-code directory. It accepts platform-independent prebuilt R packages. The tidyselect archive has NeedsCompilation=yes despite no shared library and an empty built-platform field; its prebuilt contents and namespace load govern acceptance. No native compilation was allowed. The authors explicitly approved the 27 additional dependencies listed in AGENTS.md.", "",
  "The h3jsr dependency V8 installs as a binary but cannot load because libnode.so.127 is missing. No system package was installed. The approved substitute is the [DuckDB h3 extension](https://duckdb.org/community_extensions/extensions/h3), installed as a prebuilt community extension into Output/Waze/_environment/duckdb_extensions. A fresh offline session loads it and checks a resolution-8 index. This is a readiness test, not full validation of the delivery's H3 cells. The setup script is 00_check_h3.R.", "",
  "Runtime issue E1: Arrow 25.0.1 loaded and read the Parquet schema and one row, but R exited with code 139 and a segmentation fault during shutdown in a session that had loaded all eight available analysis packages. A separate Arrow-only session that removed its dataset and result and called gc() exited with code 0. A separate DuckDB read and explicit disconnect also exited with code 0. The interaction causing the first shutdown failure has not been isolated. Use DuckDB for data access in this module; do not claim an Arrow namespace check alone establishes full runtime stability. The orientation script uses DuckDB and completes in a fresh session.", "",
  "`synthdid` and `augsynth` are unavailable in the requested CRAN index. Phase A needs no estimator substitute, and Phases B/C can use descriptive R and SQL operations. Pre-period power calculations can use base R resampling without either estimator. Any later estimator-specific fit must wait for the authors' analysis plan and a compatible installation route.", "",
  vapply(names(package_status), function(package) paste0("`", package, "`: ", package_status[[package]], "\n"), character(1)), "",
  "## Complete paper CSV inventory", "",
  markdown_table(result_inventory), "",
  "The trajectory files contain 12 model configurations, the weekly estimate files contain 8 augmented synthetic-control configurations, and donor weights are keyed by model and donor station. These files have been read as frozen outputs only. The Parquet footer, schema, station/monitor coordinates, package versions, input checksums and session information are saved in `Output/Waze/phase_a_checks.rds` and the readable `Output/Waze/phase_a_checks.txt`."
)
writeLines(notes, "reports/00_source_checks.md")
message("Phase A reports regenerated. No treatment effects estimated.")
