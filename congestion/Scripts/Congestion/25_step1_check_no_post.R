# Step 1 guardrail. Scans every Step 1 output and stops on any value dated December 2023 or later.
# Tables and R objects: every column or element named like a month or date, and every Date.
# Text files: every YYYYMM or YYYY-MM token between 2023-12 and 2025-12 (the delivery ends in 2025).
# The spec names post-opening periods in words only, so no exemption is needed.
source("Scripts/Congestion/step1_helpers.R")
LIMIT <- PRE_LAST
month_names <- "^(date|month|months|pre|train|holdout|training|range)$"
bad <- character()

as_yyyymm <- function(v) {
  if (inherits(v, "Date")) return(as.integer(format(v, "%Y%m")))
  if (is.numeric(v)) return(ifelse(v >= 190001 & v <= 210012, as.integer(v), NA_integer_))
  if (is.character(v)) {
    # Ranges such as "202201-202203" are split so that both ends are checked.
    parts <- unlist(strsplit(v, "[^0-9-]+|(?<=[0-9]{6})-", perl = TRUE))
    return(suppressWarnings(as.integer(sub("^(\\d{4})-?(\\d{2}).*$", "\\1\\2", parts))))
  }
  NA_integer_
}
walk <- function(x, path, name = "") {
  # Names and matrix column names that are months (for example a donor matrix with one column per month).
  for (nm in list(names(x), colnames(x))) {
    m <- suppressWarnings(as.integer(nm[grepl("^\\d{6}$", nm)]))
    if (any(m > LIMIT & m <= 210012, na.rm = TRUE)) bad <<- c(bad, sprintf("%s: month-like name(s) after %d", path, LIMIT))
  }
  if (is.data.frame(x)) {
    for (n in names(x)) walk(x[[n]], paste0(path, "$", n), n)
  } else if (is.list(x) && !inherits(x, "sf")) {
    for (i in seq_along(x)) walk(x[[i]], paste0(path, "[[", i, "]]"), if (is.null(names(x))) "" else names(x)[i])
  } else if (inherits(x, "Date") || (grepl(month_names, name) && (is.numeric(x) || is.character(x)))) {
    m <- as_yyyymm(x)
    if (any(m > LIMIT, na.rm = TRUE)) bad <<- c(bad, sprintf("%s: %d value(s) after %d", path, sum(m > LIMIT, na.rm = TRUE), LIMIT))
  }
}
scan_text <- function(f, txt) {
  tok <- c(regmatches(txt, gregexpr("\\b20(2[3-5])(0[1-9]|1[0-2])\\b", txt))[[1]],
           gsub("-", "", regmatches(txt, gregexpr("\\b20(2[3-5])-(0[1-9]|1[0-2])\\b", txt))[[1]]))
  tok <- as.integer(tok)
  if (any(tok > LIMIT & tok <= 202512)) bad <<- c(bad, sprintf("%s: text token(s) %s", f, paste(unique(tok[tok > LIMIT]), collapse = ", ")))
}

# Amendment 2 to 4 outputs (31 to 36) are scanned too: Output/step1_amendment2 and Data/Waze/amend2.
files <- list.files(c(STEP1_OUT, FREEZE_DIR, STEP1_DATA, dirname(pre_block), "Output/step1_amendment2", "Data/Waze/amend2",
                      "Output/redesign", "Data/Waze/redesign", "Output/restart_diagnostics"),   # Amendment 5 and 6 outputs (39 to 45)
                    full.names = TRUE, recursive = TRUE)
files <- files[!grepl("raw_manifest_check|raw_checksum_result|setup_session", files)]
for (f in files) {
  ext <- tolower(tools::file_ext(f))
  if (ext == "rds") walk(readRDS(f), f)
  else if (ext == "parquet") {
    con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
    mx <- DBI::dbGetQuery(con, sprintf("SELECT max(date) AS m, count(*) AS n FROM read_parquet(%s)", DBI::dbQuoteString(con, f)))
    DBI::dbDisconnect(con, shutdown = TRUE)
    if (mx$m > LIMIT) bad <- c(bad, sprintf("%s: max(date) %d", f, mx$m))
  } else if (ext == "csv") {
    x <- fread(f, colClasses = "character")
    walk(x, f)
    scan_text(f, paste(unlist(x), collapse = " "))
  } else if (ext == "json") {
    walk(jsonlite::read_json(f), f)
    scan_text(f, paste(readLines(f, warn = FALSE), collapse = " "))
  } else if (ext %in% c("md", "txt")) scan_text(f, paste(readLines(f, warn = FALSE), collapse = " "))
  else if (ext == "png") next  # figures: drawn from pre-only data and checked tables (23 and 34 assert their plot data end before 2023-12); not scanned
  else bad <- c(bad, sprintf("%s: file type not handled by this check", f))
}
cat("Scanned", length(files), "files.\n")
if (length(bad)) stop("Post-opening values found:\n", paste(bad, collapse = "\n"))
cat("No value dated December 2023 or later in any Step 1 output.\n")
