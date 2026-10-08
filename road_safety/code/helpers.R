# Shared setup for the road_safety scripts. Source from road_safety/: source("code/helpers.R")
# Crash records are confidential (root CLAUDE.md rule 4): scripts print and save aggregates only.
# Outcomes after the opening are not described by area (rule 5): read them only through load_pre().
stopifnot(file.exists("RUNBOOK.md"), basename(getwd()) == "road_safety")
stopifnot(dir.exists("_environment/R-library"))  # run code/00_setup.R first
.libPaths(c(normalizePath("_environment/R-library"), .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
})
options(width = 160)

RAW_XLSX <- "data/raw/2026-09-23_amt_siniestros/REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx"
RAW_SHA256 <- "1bfc56dd11a6c86a50715c536338e0cd62a80ba9d71fd5147636613f12f8ee18"
STATIONS_GPKG <- "../air_quality/data/for_maps/MetroStations.gpkg"
LINE_GPKG <- "../air_quality/data/for_maps/MetroLine.gpkg"
# Added to the store by Leonel on 2026-09-25 (docs/data_provenance/road_safety__2026-09-25_*.md).
PARISH_ZIP <- "data/raw/2026-09-25_geoquito_parroquias/PARROQUIAS_REF.zip"
PARISH_SHA256 <- "20012166d883a7de9800e117b159609e87bb21b29be35c341ba8bc7e782da96c"
BRT_OSM <- "data/raw/2026-09-25_osm_brt_routes/osm_quito_brt_routes_20260925.osm"
BRT_SHA256 <- "84f498abf2e60350d894ce498a69f7a028a142682d3f131067240ecda7dcc1fd"
# OSM motorway, trunk, primary and secondary ways as of 2022-01-01, whole district (placebo avenues for
# the gradient design and the check of the fast-road name flag; Leonel 2026-10-01, replacing a 2026 snapshot).
ROADS_OSM <- "data/raw/2026-10-01_osm_major_roads_20220101_dmq/osm_major_roads_20220101_dmq.osm"
ROADS_SHA256 <- "40c80333e13e39c7ad47f170eb4c4ff8e6e5268dd2630547435a83718ad1c72c"
# GeoQuito historic-area polygon (Area Historica), the congestion module's CENTER, read through the committed
# symlink data/congestion_centro_historico -> congestion/raw/2026-09-29_centro_historico_poligono (read-only).
CENTRO_GEOJSON <- "data/congestion_centro_historico/quito_historic_area.geojson"
CENTRO_SHA256 <- "9d9af32f74ffc832d060d38f5d0c6e638e496923edbea5d730dc9afcb52f4435"
PARISHES_TABLE <- "output/spatial/parishes.csv"  # parish geometry facts written by 02_spatial.R
DERIVED_DIR <- "data/derived"
CRASHES_BUILD <- file.path(DERIVED_DIR, "crashes.parquet")
CRASHES_SPATIAL <- file.path(DERIVED_DIR, "crashes_spatial.parquet")
CRS_UTM <- 32717L

PRE_START <- as.Date("2021-01-01")
OPENING <- as.Date("2023-12-01")  # commercial opening; the pre-period ends on 2023-11-30
PRE_END <- OPENING - 1L

# In-memory DuckDB with the h3 extension copied by 00_setup.R (the same function as congestion).
connect_duckdb <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  invisible(DBI::dbExecute(con, paste("SET extension_directory =",
    DBI::dbQuoteString(con, normalizePath("_environment/duckdb_extensions")))))
  invisible(DBI::dbExecute(con, "SET autoinstall_known_extensions = false"))
  invisible(DBI::dbExecute(con, "LOAD h3"))
  con
}

write_parquet <- function(x, path) {
  con <- connect_duckdb()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  duckdb::duckdb_register(con, "x", as.data.frame(x))
  invisible(DBI::dbExecute(con, paste("COPY x TO", DBI::dbQuoteString(con, path), "(FORMAT parquet)")))
}

read_parquet <- function(path, where = NULL) {
  con <- connect_duckdb()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  sql <- paste("SELECT * FROM read_parquet(", DBI::dbQuoteString(con, path), ")",
               if (!is.null(where)) paste("WHERE", where))
  as.data.table(DBI::dbGetQuery(con, sql))
}

# The only way descriptive and power scripts read crashes: pre-period rows only,
# filtered in the query, then checked. The SICARIATO record (a homicide, not a road crash, pending
# the AMT's answer) stays in the derived file with its flag and is excluded from every outcome count.
load_pre <- function(path = CRASHES_SPATIAL) {
  x <- read_parquet(path, where = "fecha < DATE '2023-12-01' AND NOT flag_sicariato")
  stopifnot(nrow(x) > 0L, max(x$fecha) <= PRE_END, min(x$fecha) >= PRE_START,
            !anyNA(x[, .(injury_or_fatal, pedestrian, any_motorcycle, any_bus, any_bicycle, severity)]))
  x
}

# P1 rows only (approved for P1 by Leonel on 2026-10-01; road_safety/docs/analysis_plan_amendment_1.md,
# frozen at branch commit f161d18): December 2023 to August 2024, filtered in the query, then checked.
# Nothing after August 2024 is read. The SICARIATO record is excluded as in load_pre().
P1_START <- as.Date("2023-12-01")
P1_END <- as.Date("2024-08-31")
load_p1 <- function(path = CRASHES_SPATIAL) {
  stopifnot(any(grepl("^\\*\\*APPROVED FOR P1", readLines("docs/analysis_plan.md", n = 5L))))
  x <- read_parquet(path, where = "fecha >= DATE '2023-12-01' AND fecha <= DATE '2024-08-31' AND NOT flag_sicariato")
  stopifnot(nrow(x) > 0L, min(x$fecha) >= P1_START, max(x$fecha) <= P1_END,
            !anyNA(x[, .(injury_or_fatal, pedestrian, any_motorcycle, any_bus, any_bicycle, severity)]))
  x
}

month_start <- function(d) as.Date(format(d, "%Y-%m-01"))

# Opening-aligned quarters: Dec-Feb, Mar-May, Jun-Aug, Sep-Nov, labelled by their first month.
quarter_start <- function(d) {
  m <- as.integer(format(d, "%m")); y <- as.integer(format(d, "%Y"))
  qm <- c(12L, 12L, 3L, 3L, 3L, 6L, 6L, 6L, 9L, 9L, 9L, 12L)[m]
  qy <- ifelse(m <= 2L, y - 1L, y)
  as.Date(sprintf("%d-%02d-01", qy, qm))
}

save_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  fwrite(x, path)
}

md_table <- function(x) {
  x <- as.data.frame(x)
  x[] <- lapply(x, function(v) gsub("|", "/", as.character(v), fixed = TRUE))
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(v) paste0("| ", paste(v, collapse = " | "), " |")))
}
