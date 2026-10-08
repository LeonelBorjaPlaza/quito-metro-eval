# Setup in a fresh checkout. Run from road_safety/: Rscript code/00_setup.R
# Builds the ignored project library _environment/R-library offline, by copying pinned
# package versions (code/packages.csv) from the shared renv cache and from the congestion
# project library of the main checkout, plus the DuckDB h3 extension. Nothing is compiled
# and nothing is downloaded. Then loads every package, checks its version and tests h3.
stopifnot(file.exists("RUNBOOK.md"), basename(getwd()) == "road_safety")

renv_cache <- Sys.getenv("RENV_CACHE_PKGS",
  path.expand("~/.cache/R/renv/cache/v5/linux-ubuntu-resolute/R-4.5/x86_64-pc-linux-gnu"))
congestion_env <- Sys.getenv("CONGESTION_ENV",
  path.expand("~/projects/quito-metro-eval/congestion/Output/Waze/_environment"))
lib <- "_environment/R-library"
ext <- "_environment/duckdb_extensions"
dir.create(lib, recursive = TRUE, showWarnings = FALSE)

pins <- read.csv("code/packages.csv", stringsAsFactors = FALSE)
source_dir <- function(p, v, src) {
  if (src == "congestion") return(file.path(congestion_env, "R-library", p))
  hits <- Sys.glob(file.path(renv_cache, p, v, "*", p))
  if (length(hits) == 0L) stop("Not in renv cache: ", p, " ", v)
  hits[1]
}
for (i in seq_len(nrow(pins))) {
  p <- pins$package[i]; v <- pins$version[i]
  have <- file.path(lib, p, "DESCRIPTION")
  if (file.exists(have) && read.dcf(have, fields = "Version")[1, 1] == v) next
  unlink(file.path(lib, p), recursive = TRUE)
  from <- source_dir(p, v, pins$source[i])
  got <- read.dcf(file.path(from, "DESCRIPTION"), fields = "Version")[1, 1]
  if (got != v) stop(p, ": source has ", got, ", pinned ", v)
  stopifnot(file.copy(from, lib, recursive = TRUE))
}
if (!dir.exists(file.path(ext, "v1.5.5"))) {
  dir.create(ext, recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy(file.path(congestion_env, "duckdb_extensions", "v1.5.5"), ext, recursive = TRUE))
}

# Check: the GitHub packages are the pinned commits (the same as the air quality lockfile).
remote_pins <- c(augsynth = "65c5a6f34f4e4a8b1011182fe12309ef022d992f", synthdid = "70c1ce3eac58e28c30b67435ca377bb48baa9b8a")
for (p in names(remote_pins))
  stopifnot(read.dcf(file.path(lib, p, "DESCRIPTION"), fields = "RemoteSha")[1, 1] == remote_pins[[p]])

# Check: every pinned package loads from the project library at the pinned version.
.libPaths(c(normalizePath(lib), .libPaths()))
for (i in seq_len(nrow(pins))) {
  p <- pins$package[i]
  suppressPackageStartupMessages(requireNamespace(p, quietly = TRUE)) || stop("Cannot load ", p)
  stopifnot(packageVersion(p) == package_version(pins$version[i]),
            startsWith(normalizePath(system.file(package = p)), normalizePath(lib)))
}
suppressPackageStartupMessages(library(sf))

# Check: the h3 extension loads offline and returns resolution-8 cells.
con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
invisible(DBI::dbExecute(con, paste("SET extension_directory =", DBI::dbQuoteString(con, normalizePath(ext)))))
invisible(DBI::dbExecute(con, "SET autoinstall_known_extensions = false"))
invisible(DBI::dbExecute(con, "LOAD h3"))
h3 <- DBI::dbGetQuery(con, paste("SELECT h3_is_valid_cell('8866d3ad07fffff') AS is_valid,",
  "h3_get_resolution(h3_latlng_to_cell_string(-0.2, -78.5, 8)) AS res"))
DBI::dbDisconnect(con, shutdown = TRUE)
stopifnot(isTRUE(h3$is_valid), h3$res == 8L)

dir.create("output/_environment", recursive = TRUE, showWarnings = FALSE)
versions <- data.frame(package = c(pins$package, "sf"),
  version = c(pins$version, as.character(packageVersion("sf"))),
  source = c(pins$source, "system site library"))
write.csv(versions, "output/_environment/package_versions.csv", row.names = FALSE)
writeLines(c(capture.output(sessionInfo()), "", capture.output(sf::sf_extSoftVersion())),
  "output/_environment/session_info.txt")
cat("Setup complete:", nrow(pins), "pinned packages, sf", as.character(packageVersion("sf")), "and h3 checked.\n")
