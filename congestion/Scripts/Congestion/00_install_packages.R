# Run from the repository root: Rscript Scripts/Congestion/00_install_packages.R
# Add --allow-dependencies only after the authors approve the dependency list.
# This script accepts prebuilt Linux archives only. It never installs from source.
stopifnot(file.exists("AGENTS.md"))
allowed <- c("arrow", "duckdb", "data.table", "dplyr", "sf", "h3jsr",
             "ggplot2", "patchwork", "fixest", "synthdid", "augsynth")
approved_dependencies <- c(
  "assertthat", "bit", "bit64", "curl", "dreamerr", "Formula", "generics",
  "geojsonsf", "geometries", "jsonify", "jsonlite", "numDeriv", "pillar",
  "pkgconfig", "purrr", "rapidjsonr", "sandwich", "sfheaders", "stringi",
  "stringmagic", "stringr", "tibble", "tidyr", "tidyselect", "utf8", "V8", "zoo"
)
allow_dependencies <- "--allow-dependencies" %in% commandArgs(trailingOnly = TRUE)
authorized <- c(allowed, if (allow_dependencies) approved_dependencies)
distro <- trimws(system2("lsb_release", "-cs", stdout = TRUE))
stopifnot(length(distro) == 1L, grepl("^[a-z]+$", distro))
repo <- sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", distro)
options(repos = c(CRAN = repo), timeout = 180,
        HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
          paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
environment_dir <- "Output/Waze/_environment"
library_dir <- file.path(environment_dir, "R-library")
archive_dir <- file.path(environment_dir, "archives")
dir.create(library_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
library_dir <- normalizePath(library_dir)
.libPaths(c(library_dir, .libPaths()))
available <- available.packages(type = "source")
if (!nrow(available)) stop("Posit package index unavailable; no installation attempted.")
status_file <- file.path(environment_dir, "package_status.rds")
status <- if (file.exists(status_file)) readRDS(status_file) else list()
dependencies <- tools::package_dependencies(
  intersect(authorized, rownames(available)), db = available,
  which = c("Depends", "Imports", "LinkingTo"), recursive = FALSE
)
install_one <- function(package, stack = character()) {
  if (requireNamespace(package, quietly = TRUE)) return(TRUE)
  if (!package %in% authorized) {
    status[[package]] <<- "Not installed: dependency outside approved list."
    return(FALSE)
  }
  if (!package %in% rownames(available)) {
    status[[package]] <<- "Unavailable in the requested Posit CRAN repository."
    return(FALSE)
  }
  if (package %in% stack) stop("Circular dependency: ", package)
  deps <- setdiff(dependencies[[package]], "R")
  deps_ok <- vapply(deps, install_one, logical(1), stack = c(stack, package))
  if (!all(deps_ok)) {
    status[[package]] <<- paste("Not installed; unavailable or unapproved dependencies:",
                              paste(deps[!deps_ok], collapse = ", "))
    return(FALSE)
  }
  tryCatch({
    download <- download.packages(package, destdir = archive_dir, available = available,
                                  repos = repo, type = "source", quiet = FALSE)
    if (!nrow(download)) stop("Download failed.")
    archive <- normalizePath(download[1, 2])
    entries <- utils::untar(archive, list = TRUE)
    if (any(grepl("(^/|(^|/)\\.\\.(/|$))", entries))) stop("Unsafe archive path.")
    description_path <- paste0(package, "/DESCRIPTION")
    if (!description_path %in% entries) stop("Missing package DESCRIPTION.")
    scratch <- tempfile(pattern = "waze_binary_check_")
    dir.create(scratch)
    utils::untar(archive, files = description_path, exdir = scratch)
    description <- read.dcf(file.path(scratch, description_path))
    if (!"Built" %in% colnames(description)) {
      stop("Source archive refused: no Built field; compilation is prohibited.")
    }
    built <- description[1, "Built"]
    r_minor <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = ".")
    built_platform <- trimws(strsplit(built, ";", fixed = TRUE)[[1]][2])
    has_native <- any(grepl("/libs/.*[.]so$", entries))
    platform_ok <- identical(built_platform, R.version$platform) ||
      (!has_native && identical(built_platform, ""))
    if (!startsWith(built, paste0("R ", r_minor, ".")) || !platform_ok) {
      stop("Binary does not match R version/platform: ", built)
    }
    if (!paste0(package, "/Meta/package.rds") %in% entries ||
        any(startsWith(entries, paste0(package, "/src/")))) {
      stop("Archive is not an installed binary package; refused.")
    }
    message("Verified binary: ", package, "; ", built)
    exit_status <- system2(file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", paste0("--library=", shQuote(library_dir)), shQuote(archive)))
    if (exit_status != 0L) stop("Binary installation failed with exit status ", exit_status)
    loadNamespace(package)
    status[[package]] <<- paste("Installed Posit Linux binary", as.character(packageVersion(package)),
                              "Built:", built, "archive MD5:", unname(tools::md5sum(archive)))
    TRUE
  }, error = function(error) {
    status[[package]] <<- conditionMessage(error)
    message(package, ": ", status[[package]])
    FALSE
  })
}
for (package in allowed) {
  present <- requireNamespace(package, quietly = TRUE)
  if (present && is.null(status[[package]])) {
    status[[package]] <- paste("Already installed", as.character(packageVersion(package)))
  }
  if (!present) install_one(package)
  saveRDS(status, status_file)
}
writeLines(c(paste("Repository:", repo), unlist(Map(function(package, detail)
  paste(package, detail, sep = ": "), names(status), status))),
  file.path(environment_dir, "package_status.txt"))
print(data.frame(package = allowed,
                 installed = vapply(allowed, requireNamespace, logical(1), quietly = TRUE)),
      row.names = FALSE)
