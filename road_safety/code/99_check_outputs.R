# Guard for root CLAUDE.md rules 4 and 5. Run from road_safety/ before every commit:
#   Rscript code/99_check_outputs.R
# Scans every CSV in output/ and in ../reports/road_safety/ and fails if a table
# (a) has a column that identifies records (crash ID, street names, crash coordinates);
# (b) has a date on or after 2023-12-01, in full (YYYY-MM-DD) or month (YYYY-MM) form, with an area
#     column, or any such date outside the completeness tables;
# (c) has a year from 2023 on, as a `year`/`yr` column or as a year-named column (for example
#     present_2024), together with an area column, outside the completeness tables;
# (d) reports a min, max, median or numeric distance for a group of fewer than 5 crashes;
# (e) shows presence after 2023 (present_2024 and later) for a geographic or outcome-valued field
#     (parish, administration, recording unit, district; deaths, injured, vehicles) unless withheld;
# (f) has a year column from 2024 on outside the district-wide completeness tables.
# Figures (PNG) are allowed only in output/descriptives/, which holds pre-period figures only.
source("code/helpers.R")
files <- c(list.files("output", pattern = "\\.csv$", recursive = TRUE, full.names = TRUE),
           list.files("../reports/road_safety", pattern = "\\.csv$", recursive = TRUE, full.names = TRUE))
record_cols <- "^(crash_id|siniestro|principal|secundaria|lat|lon|latitud|longitud|minute_of_day)$"
area_cols <- c("band", "parroquia", "station", "nearest_station", "unit", "donor", "h3_r8", "h3_r7",
               "administracion", "distrito", "jefatura", "area", "treated", "pool", "cluster",
               "parish", "parish_code", "parroquia_polygon", "corridor", "composite", "avenue")
completeness <- function(f) grepl(paste0("^output/completeness/|_districtwide\\.csv$|/0[1-9]_inventory|by_year\\.csv$|",
                                          "/07_numeric_id_ranges|/08_near_duplicates|/09_vehreg|/23_coordinate_quality"), f)
withheld_fields <- c("PARROQUIA", "ADMINISTRACION", "JEFATURA", "DISTRITO", "FALLECIDOS", "LESIONADOS", "VEHICULOS REGISTRADOS")
problems <- character()
for (f in files) {
  x <- fread(f, colClasses = "character")
  nm <- tolower(names(x))
  has_area <- any(nm %in% area_cols) || (any(nm == "field") && any(toupper(x[[which(nm == "field")[1]]]) %in%
                                         c("PARROQUIA", "ADMINISTRACION", "DISTRITO")))
  bad <- grep(record_cols, nm, value = TRUE)
  # Street names are allowed only in the pre-period fast-road table, and only with at least 5 mentions.
  # brt_relations.csv names OSM bus routes (from the public OSM layer), not crash locations.
  if ("name" %in% nm && !grepl("output/spatial/brt_relations\\.csv$", f)) {
    if (!grepl("fast_road_names_pre\\.csv$", f)) bad <- c(bad, "name")
    else if (any(suppressWarnings(as.integer(x$mentions_pre)) < 5L, na.rm = TRUE))
      problems <- c(problems, sprintf("%s: street-name row with fewer than 5 mentions", f))
  }
  # Avenue names (public OSM data) are allowed only in the placebo-avenue table of the gradient design.
  if ("avenue" %in% nm && !grepl("output/power/gradient/placebo_(avenues|corridors)\\.csv$", f)) bad <- c(bad, "avenue")
  if (length(bad)) problems <- c(problems, sprintf("%s: record-level column %s", f, paste(bad, collapse = ", ")))
  for (col in names(x)) {
    v <- x[[col]]
    ym <- substr(v[grepl("^\\d{4}-\\d{2}(-\\d{2})?$", v)], 1, 7)
    # P1 outputs (approved 2026-10-01) may carry December 2023 to August 2024; nothing after August 2024 anywhere.
    p1_file <- grepl("^output/p1/", f)
    if (length(ym) && any(ym > "2024-08") && (p1_file || has_area || !completeness(f)))
      problems <- c(problems, sprintf("%s: column %s has a date after August 2024 outside the district-wide completeness tables", f, col))
    else if (length(ym) && any(ym >= "2023-12") && !p1_file && (has_area || !completeness(f)))
      problems <- c(problems, sprintf("%s: column %s has a date from 2023-12 on", f, col))
  }
  year_cols <- c(names(x)[nm %in% c("year", "yr")])
  late_year <- any(vapply(year_cols, function(y) any(suppressWarnings(as.integer(x[[y]])) >= 2023L, na.rm = TRUE), TRUE)) ||
    any(grepl("(^|_)20(2[3-9])$", nm))
  if (late_year && has_area && !grepl("12_area_categories", f)) {  # file 12 is checked field by field below
    problems <- c(problems, sprintf("%s: year 2023 or later together with an area column", f))
  }
  late <- grep("present_202[4-9]", names(x), value = TRUE)
  if (length(late) && "field" %in% nm) {
    sensitive <- toupper(x[[which(nm == "field")[1]]]) %in% withheld_fields
    if (any(unlist(x[sensitive, ..late]) != "withheld"))
      problems <- c(problems, sprintf("%s: presence after 2023 of a geographic or outcome-valued field", f))
  }
  if (length(year_cols) && !completeness(f) &&
      any(vapply(year_cols, function(y) any(suppressWarnings(as.integer(x[[y]])) >= 2024L, na.rm = TRUE), TRUE)))
    problems <- c(problems, sprintf("%s: a year from 2024 on outside the completeness tables", f))
  stat_cols <- grep("^(min|max|median)_(?!decimals)", nm, perl = TRUE)  # decimal counts are precision, not location
  dist_num <- grep("distance", nm)
  dist_num <- dist_num[vapply(dist_num, function(i) any(!is.na(suppressWarnings(as.numeric(x[[i]])))), TRUE)]
  stat_cols <- union(stat_cols, dist_num)
  if (length(stat_cols) && "crashes" %in% nm) {
    n <- suppressWarnings(as.integer(x[[which(nm == "crashes")[1]]]))
    if (any(n < 5L & rowSums(!is.na(x[, ..stat_cols]) & x[, ..stat_cols] != "") > 0, na.rm = TRUE))
      problems <- c(problems, sprintf("%s: min/max/median reported for a group of fewer than 5 crashes", f))
  }
}
pngs <- list.files("output", pattern = "\\.png$", recursive = TRUE, full.names = TRUE)
if (any(!startsWith(pngs, "output/descriptives/") & !startsWith(pngs, "output/p1/")))
  problems <- c(problems, "PNG figures outside output/descriptives/ (pre-period) and output/p1/ (P1, approved)")
# P1 tables: no published count of 1 to 4 (small-count rule, amendment section 4.6, condition 7).
for (f in grep("^output/p1/.*\\.csv$", files, value = TRUE)) {
  x <- fread(f, colClasses = "character")
  for (col in grep("^(crashes|count|n)$", names(x), value = TRUE))
    if (any(suppressWarnings(as.integer(x[[col]])) %in% 1:4)) problems <- c(problems, sprintf("%s: count of 1 to 4 in %s", f, col))
}
if ("output/p1/p1_counts.csv" %in% files) {  # P1 counts are published rounded to 5
  v <- fread("output/p1/p1_counts.csv")$crashes
  if (!length(v) || any(v %% 5 != 0)) problems <- c(problems, "output/p1/p1_counts.csv: a count not rounded to 5")
}
if (length(problems)) {
  writeLines(problems)
  stop(length(problems), " problem(s) in the outputs")
}
cat("Output check passed:", length(files), "tables and", length(pngs), "figures.\n")
