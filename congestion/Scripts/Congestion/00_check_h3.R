# Allowed fallback for h3jsr: install/check the prebuilt DuckDB h3 extension.
# Rscript Scripts/Congestion/00_check_h3.R
stopifnot(file.exists("AGENTS.md"))
environment_dir <- "Output/Waze/_environment"
.libPaths(c(normalizePath(file.path(environment_dir, "R-library")), .libPaths()))
extension_dir <- file.path(environment_dir, "duckdb_extensions")
dir.create(extension_dir, recursive = TRUE, showWarnings = FALSE)
local({
  connection <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:",
    config = list(extension_directory = normalizePath(extension_dir)))
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE))
  DBI::dbExecute(connection, paste("SET extension_directory =",
    DBI::dbQuoteString(connection, normalizePath(extension_dir))))
  # Community extensions are signed, prebuilt artifacts. No compilation occurs.
  DBI::dbExecute(connection, "INSTALL h3 FROM community")
  DBI::dbExecute(connection, "LOAD h3")
  result <- DBI::dbGetQuery(connection,
    "SELECT h3_is_valid_cell('8866d3ad07fffff') AS valid, h3_get_resolution('8866d3ad07fffff') AS resolution")
  stopifnot(isTRUE(result$valid), result$resolution == 8L)
  status <- DBI::dbGetQuery(connection,
    "SELECT extension_name, loaded, installed, extension_version, install_path FROM duckdb_extensions() WHERE extension_name = 'h3'")
  saveRDS(list(test = result, status = status), file.path(environment_dir, "h3_status.rds"))
  print(status)
})
