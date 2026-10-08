# District-wide completeness for every year, 2021 to 2026. Run from road_safety/ after 02_spatial.R:
#   Rscript code/05_completeness.R
# With the audit script, the only script that summarises records dated December 2023 or later by
# period (01 and 02 read all dates to build and assign; they write only all-date district-wide totals,
# such as output/spatial/assignment_rates.csv). Under root CLAUDE.md rule 5 it
# writes district-wide completeness only: records per calendar year, months with records, missing or
# flagged fields per year, and category lists (present or absent, no counts). Nothing by area, no
# monthly counts, no outcome shares, no before-and-after comparison.
source("code/helpers.R")
out <- "output/completeness"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
all <- read_parquet(CRASHES_BUILD)  # the build file: no spatial assignment is read here

# Records per year and months with at least one record (68 months expected, January 2021 to August 2026).
per_year <- all[, .(records = .N, months_with_records = uniqueN(month)), by = year][order(year)]
save_csv(per_year, file.path(out, "records_per_year.csv"))
expected <- seq(as.Date("2021-01-01"), as.Date("2026-08-01"), by = "month")
present <- unique(as.Date(sprintf("%d-%02d-01", all$year, all$month)))
save_csv(data.table(expected_months = length(expected), months_with_records = length(present),
                    months_without_records = paste(format(setdiff(expected, present), "%Y-%m"), collapse = " ")),
         file.path(out, "month_coverage.csv"))

# Missing values and flags per year (shares of that year's records).
fields <- c("fecha", "hour", "lat", "lon", "distrito", "jefatura", "parroquia", "administracion", "zona",
            "tipologia", "causa", "severidad", "fallecidos", "lesionados", "vehicles_registered")
miss <- all[, c(list(records = .N), lapply(.SD, function(x) round(mean(is.na(x)), 4))), by = year, .SDcols = fields][order(year)]
setnames(miss, fields, paste0("missing_", fields))
save_csv(miss, file.path(out, "missing_fields_by_year.csv"))
flags <- grep("^flag_", names(all), value = TRUE)
fl <- all[, c(list(records = .N), lapply(.SD, function(x) sum(x, na.rm = TRUE))),
          by = year, .SDcols = setdiff(flags, c("flag_outside_district", "flag_parish_mismatch"))][order(year)]
# The two parish flags are set by 02_spatial.R (point in polygon); only the flags are read from its file.
sp <- read_parquet(CRASHES_SPATIAL)[, .(year, flag_outside_district, flag_parish_mismatch, parroquia_name_unknown)]
fl <- merge(fl, sp[, .(flag_outside_district = sum(flag_outside_district),
                       flag_parish_mismatch = sum(flag_parish_mismatch, na.rm = TRUE),
                       parroquia_name_not_in_polygons = sum(parroquia_name_unknown)), by = year], by = "year")
save_csv(fl, file.path(out, "flags_by_year.csv"))

# Coordinate precision per year: number of decimal places cannot be recovered from doubles, so this
# reports the share of points repeated exactly within the year (a sign of default or snapped locations).
coords <- all[, .(records = .N, share_repeated_exact_point = round(1 - uniqueN(paste(lat, lon)) / .N, 4)), by = year][order(year)]
save_csv(coords, file.path(out, "coordinate_repetition_by_year.csv"))

# Category lists: present (1) or absent (0) by year, no counts.
cat_presence <- function(col) {
  x <- unique(all[!is.na(get(col)), .(year, category = get(col))])
  x <- dcast(x[, present := 1L], category ~ year, value.var = "present", fill = 0L)
  cbind(field = col, x)
}
save_csv(rbindlist(lapply(c("tipologia", "severidad", "zona", "causa"), cat_presence),
                   use.names = TRUE, fill = TRUE), file.path(out, "category_presence_by_year.csv"))
stopifnot(substr(system2("sha256sum", shQuote(RAW_XLSX), stdout = TRUE), 1, 64) == RAW_SHA256)
raw_v <- as.data.table(readxl::read_excel(RAW_XLSX, sheet = "VEHÍCULOS", col_types = "text"))
vp <- unique(raw_v[!is.na(`TIPO DE VEHÍCULO`), .(year = as.integer(`AÑO`), category = trimws(`TIPO DE VEHÍCULO`))])
vp <- dcast(vp[, present := 1L], category ~ year, value.var = "present", fill = 0L)
save_csv(cbind(field = "tipo_de_vehiculo", vp), file.path(out, "vehicle_type_presence_by_year.csv"))
print(per_year)
