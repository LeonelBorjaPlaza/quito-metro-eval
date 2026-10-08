# Data audit of the AMT crash matrix (workstream C). Run from road_safety/:
#   Rscript code/audit_2026-09-25_tables.R
# Written by the data-auditor agent on 2026-09-25 (report: reports/road_safety/2026-09-25_data_audit.md);
# kept here so the audit tables can be rebuilt from a committed SHA.
# Writes aggregate CSV tables only. Pre-period rule: anything by area or any outcome
# series covers 2021-01-01 to 2023-11-30; later months get district-wide completeness only.
.libPaths(c(normalizePath("_environment/R-library"), .libPaths()))
suppressPackageStartupMessages({library(readxl); library(data.table); library(sf); library(FNN)})
stopifnot(basename(getwd()) == "road_safety")
OUT <- normalizePath("../reports/road_safety", mustWork = TRUE)
TD <- file.path(OUT, "2026-09-25_data_audit_tables"); dir.create(TD, showWarnings = FALSE)
w <- function(x, name) fwrite(x, file.path(TD, name))
DIR <- "data/raw/2026-09-23_amt_siniestros"
F <- file.path(DIR, "REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx")
CUT <- as.IDate("2023-11-30")

# ---------- 1. Inventory ----------
files <- list.files(DIR, recursive = TRUE, full.names = TRUE)
sums <- fread(file.path(DIR, "SHA256SUMS"), header = FALSE, sep = NULL, col.names = "line")
sums[, `:=`(sha = sub(" .*$", "", line), file = sub("^[0-9a-f]+  \\./", "", line))]
man <- readLines(Sys.getenv("QME_MANIFEST", normalizePath(file.path(normalizePath("data/raw"), "..", "..", "MANIFEST.sha256"))))
inv <- rbindlist(lapply(files, function(f) {
  rel <- sub(paste0("^", DIR, "/"), "", f)
  sha <- sub(" .*$", "", system2("sha256sum", shQuote(f), stdout = TRUE))
  data.table(file = rel, bytes = file.size(f), sha256 = sha,
             matches_SHA256SUMS = if (rel == "SHA256SUMS") NA else sha %in% sums$sha & rel %in% sums$file,
             listed_in_store_MANIFEST = any(grepl(sha, man, fixed = TRUE)),
             role = fifelse(grepl("copy_found", rel), "older re-saved copy, inventory only",
                    fifelse(grepl("xlsx$", rel), "audited file", fifelse(grepl("msg$", rel), "delivery email", "checksums"))))
}))
w(inv, "01_inventory_files.csv")

# ---------- read ----------
sl <- read_excel(F, sheet = "SINIESTROS", col_types = "list")
vl <- read_excel(F, sheet = "VEHÍCULOS", col_types = "list")
cls1 <- function(x) if (length(x) == 0 || (is.logical(x) && length(x) == 1 && is.na(x))) "empty" else if (inherits(x, "POSIXct")) "date/time" else if (is.numeric(x)) "number" else "text"
# excel cell-level: formulas and error cells
xml_cells <- function(sheetfile) {
  x <- paste(system2("unzip", c("-p", shQuote(F), sheetfile), stdout = TRUE), collapse = "")
  m <- stringi::stri_extract_all_regex(x, '<c r="[A-Z]+[0-9]+"[^>/]*(/>|>(<f[^>]*>[^<]*</f>)?)')[[1]]
  data.table(col = sub('^<c r="([A-Z]+)[0-9]+".*$', "\\1", m), is_error = grepl('t="e"', m), has_formula = grepl("<f", m),
             formula = ifelse(grepl("<f", m), sub('^.*<f[^>]*>([^<]*)</f>$', "\\1", m), NA_character_))
}
colinfo <- function(L, sheetfile, sheetname) {
  xc <- xml_cells(sheetfile)[-(1:ncol(L))]  # drop header row cells
  letters_ <- c(LETTERS, paste0("A", LETTERS))[seq_len(ncol(L))]
  rbindlist(lapply(seq_along(L), function(i) {
    ty <- table(factor(vapply(L[[i]], cls1, ""), levels = c("number", "text", "date/time", "empty")))
    xi <- xc[col == letters_[i]]
    f <- unique(na.omit(xi$formula)); f <- gsub("[0-9]+", "#", f)
    vals <- vapply(L[[i]], function(x) if (length(x) == 0 || (is.logical(x) && is.na(x))) NA_character_ else as.character(x), "")
    data.table(sheet = sheetname, column = names(L)[i], excel_col = letters_[i], rows = length(L[[i]]),
               cells_number = ty[["number"]], cells_text = ty[["text"]], cells_datetime = ty[["date/time"]],
               cells_empty = ty[["empty"]] - sum(xi$is_error), cells_error_REF = sum(xi$is_error),
               cells_with_formula = sum(xi$has_formula), formula_pattern = if (length(f)) paste(unique(f), collapse = " | ") else "",
               distinct_values = uniqueN(na.omit(vals)))
  }))
}
cols <- rbind(colinfo(sl, "xl/worksheets/sheet1.xml", "SINIESTROS"), colinfo(vl, "xl/worksheets/sheet2.xml", "VEHÍCULOS"))
w(cols, "02_inventory_columns.csv")

tochr <- function(col) vapply(col, function(x) if (length(x) == 0 || (is.logical(x) && is.na(x))) NA_character_ else if (inherits(x, "POSIXct")) format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC") else if (is.numeric(x)) format(x, digits = 15, scientific = FALSE, trim = TRUE) else as.character(x), "")
isnum <- function(col) vapply(col, is.numeric, TRUE)
numraw <- function(col) vapply(col, function(x) if (is.numeric(x)) as.numeric(x) else NA_real_, 0)
s <- as.data.table(lapply(sl, tochr)); v <- as.data.table(lapply(vl, tochr))
s[, `:=`(lat_isnum = isnum(sl$LATITUD), lon_isnum = isnum(sl$LONGITUD), lat_raw = numraw(sl$LATITUD), lon_raw = numraw(sl$LONGITUD), id_isnum = isnum(sl$SINIESTRO))]
setnames(s, make.names(names(s))); setnames(v, make.names(names(v)))
s[, date := as.IDate(substr(FECHA, 1, 10))][, yr := year(date)][, ym := format(date, "%Y-%m")][, pre := date <= CUT]
s[, hms := substr(HORA, 12, 19)][, hh := as.integer(substr(hms, 1, 2))][, mm := as.integer(substr(hms, 4, 5))]
s[, fall := suppressWarnings(as.numeric(FALLECIDOS))][, les := as.numeric(LESIONADOS)][, vreg := as.numeric(VEHICULOS.REGISTRADOS)]
s[, lat := as.numeric(LATITUD)][, lon := as.numeric(LONGITUD)]
dec_txt <- function(x) ifelse(grepl("\\.", x), nchar(sub("^[^.]*\\.", "", x)), 0L)
dec_num <- function(x) { y <- sub("0+$", "", sprintf("%.12f", x)); nchar(sub("^[^.]*\\.", "", y)) }
s[, lat_dec := ifelse(lat_isnum, dec_num(lat_raw), dec_txt(LATITUD))][, lon_dec := ifelse(lon_isnum, dec_num(lon_raw), dec_txt(LONGITUD))][, mindec := pmin(lat_dec, lon_dec)]
cnt <- v[, .(nveh = .N), by = SINIESTRO]; s <- merge(s, cnt, by = "SINIESTRO", all.x = TRUE); s[is.na(nveh), nveh := 0L]; s[, vdiff := nveh - vreg]
v <- merge(v, s[, .(SINIESTRO, date, yr, ym, pre, TIPOLOGÍA)], by = "SINIESTRO", all.x = TRUE)
meses <- c("ENERO","FEBRERO","MARZO","ABRIL","MAYO","JUNIO","JULIO","AGOSTO","SEPTIEMBRE","OCTUBRE","NOVIEMBRE","DICIEMBRE")
dias <- c("domingo","lunes","martes","miércoles","jueves","viernes","sábado")
# spatial
xy <- st_coordinates(st_transform(st_as_sf(s[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), 32717))
s[, `:=`(X = xy[, 1], Y = xy[, 2])]
ctr <- st_coordinates(st_transform(st_sfc(st_point(c(-78.5123, -0.2202)), crs = 4326), 32717))
s[, d_ctr_km := sqrt((X - ctr[1])^2 + (Y - ctr[2])^2) / 1000]
s[, in_box := lat >= -0.60 & lat <= 0.40 & lon >= -79.10 & lon <= -78.00]
s[, key := paste(LATITUD, LONGITUD)][, mult := .N, by = key]
nn <- get.knnx(as.matrix(s[, .(X, Y)]), as.matrix(s[, .(X, Y)]), k = 16)$nn.index[, -1]
par <- s$PARROQUIA
s[, knn_major := apply(nn, 1, function(ix) { t <- table(par[ix]); names(t)[which.max(t)] })]
s[, knn_same := rowSums(matrix(par[nn], ncol = 15) == par)]
ref <- s[pre == TRUE, .(mx = median(X), my = median(Y)), by = PARROQUIA]
s <- merge(s, ref, by = "PARROQUIA", all.x = TRUE); s[, d_own_km := sqrt((X - mx)^2 + (Y - my)^2) / 1000]
st <- st_transform(st_zm(st_read("../air_quality/data/for_maps/MetroStations.gpkg", quiet = TRUE)), 32717)
ln <- st_transform(st_union(st_zm(st_read("../air_quality/data/for_maps/MetroLine.gpkg", quiet = TRUE))), 32717)
s[, amt_code := !id_isnum]
p <- s[pre == TRUE]  # PRE-PERIOD ONLY from here for anything by area or outcome
pp <- st_as_sf(p[, .(X, Y)], coords = c("X", "Y"), crs = 32717)
D <- st_distance(pp, st); p[, d_station := apply(D, 1, min)][, st_idx := apply(D, 1, which.min)][, d_line := as.numeric(st_distance(pp, ln))]

# ---------- 3. Records per month, district-wide, with recording signatures (all months) ----------
allm <- data.table(ym = format(seq(as.Date("2021-01-01"), as.Date("2026-08-01"), by = "month"), "%Y-%m"))
sm <- s[, .(crashes = .N, id_amt_code_format = sum(amt_code), zona_empty = sum(is.na(ZONA)), causa_REF_error = sum(is.na(CAUSA.PROBABLE)),
            lat_stored_as_number = sum(lat_isnum), lon_stored_as_number = sum(lon_isnum),
            coords_8plus_decimals = sum(mindec >= 8), coords_5_or_fewer_decimals = sum(mindec <= 5),
            hora_minute_multiple_of_5_share = round(mean(mm %% 5 == 0), 3), hora_0000 = sum(hms == "00:00:00"),
            parish_matches_15_nearest_share = round(mean(PARROQUIA == knn_major), 3),
            vehreg_ne_vehicle_rows = sum(vdiff != 0), lowercase_labels = sum(grepl("[a-z]", PARROQUIA) | grepl("[a-z]", JEFATURA))), by = ym]
vm <- v[, .(vehicle_rows = .N, cilindraje_empty = sum(is.na(CILINDRAJE)), cilindraje_zero = sum(CILINDRAJE == "0", na.rm = TRUE),
            subcategoria_empty = sum(is.na(SUB.CATEGORÍA))), by = ym]
mon <- merge(merge(allm, sm, all.x = TRUE), vm, all.x = TRUE)[order(ym)]
mon[, period := fifelse(ym <= "2023-11", "pre (Jan 2021-Nov 2023)", "Dec 2023 on: completeness only")]
# Rule 5 allows records per year only from December 2023 on: for those months, counts become shares
# of the month's records (vehicle fields: of its vehicle rows) and the record counts are withheld.
# (Added by the workstream lead after the audit; the audit tables were corrected the same way.)
crash_counts <- c("id_amt_code_format", "zona_empty", "causa_REF_error", "lat_stored_as_number", "lon_stored_as_number",
                  "coords_8plus_decimals", "coords_5_or_fewer_decimals", "hora_0000", "vehreg_ne_vehicle_rows", "lowercase_labels")
veh_counts <- c("cilindraje_empty", "cilindraje_zero", "subcategoria_empty")
mon[, (c(crash_counts, veh_counts)) := lapply(.SD, as.numeric), .SDcols = c(crash_counts, veh_counts)]
post_m <- mon$ym > "2023-11"
for (cc in crash_counts) set(mon, which(post_m), cc, round(mon[[cc]][post_m] / mon$crashes[post_m], 2))
for (cc in veh_counts) set(mon, which(post_m), cc, round(mon[[cc]][post_m] / mon$vehicle_rows[post_m], 2))
mon[, `:=`(crashes = as.character(crashes), vehicle_rows = as.character(vehicle_rows))]
mon[post_m, `:=`(crashes = "", vehicle_rows = "")]
mon[, count_columns_are := fifelse(post_m, "shares of the month records (counts withheld, rule 5)", "counts")]
w(mon, "03_monthly_completeness_districtwide.csv")
# day gaps
alld <- data.table(date = as.IDate(seq(as.Date("2021-01-01"), as.Date("2026-08-31"), by = "day")))
dd <- merge(alld, s[, .N, by = date], all.x = TRUE); dd[is.na(N), N := 0L]
r <- rle(dd$N == 0); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
gaps <- data.table(gap_start = dd$date[starts], gap_end = dd$date[ends], days = r$lengths, zero = r$values)[zero == TRUE, -"zero"]
w(gaps, "04_zero_crash_days_districtwide.csv")

# ---------- 4. Per year completeness and validity (district-wide) ----------
yrt <- s[, .(crashes = .N, crashes_pre_period = sum(pre),
             mes_matches_fecha = sum(MES == meses[month(date)]), dia_matches_fecha = sum(DIA == dias[wday(date)]), ano_matches_fecha = sum(as.integer(AÑO) == yr),
             zona_empty = sum(is.na(ZONA)), causa_REF_error = sum(is.na(CAUSA.PROBABLE)), fallecidos_non_numeric = sum(is.na(fall)),
             principal_empty = sum(is.na(PRINCIPAL)), secundaria_empty = sum(is.na(SECUNDARIA)),
             secundaria_generic_SN = sum(toupper(trimws(SECUNDARIA)) %in% c("S/N","SN","N/A","NA","SIN NOMBRE","0","-","."), na.rm = TRUE),
             severidad_inconsistent_with_counts = sum(SEVERIDAD != fifelse(fall > 0, "FALLECIDOS", fifelse(les > 0, "LESIONADOS", "DAÑOS MATERIALES")), na.rm = TRUE),
             hora_0000 = sum(hms == "00:00:00"), hora_minute_multiple_of_5_share = round(mean(mm %% 5 == 0), 3),
             id_numeric = sum(!amt_code), id_amt_code_format = sum(amt_code),
             vehreg_eq_rows = sum(vdiff == 0), vehreg_lt_rows = sum(vdiff > 0), vehreg_gt_rows = sum(vdiff < 0),
             sum_vehiculos_registrados = sum(vreg), vehicle_rows = sum(nveh)), by = yr][order(yr)]
vy <- v[, .(veh_marca_empty = sum(is.na(MARCA)), veh_modelo_empty = sum(is.na(MODELO)), veh_ano2_empty = sum(is.na(AÑO2)),
            veh_ano2_zero_or_sindatos = sum(AÑO2 %in% c("0", "SIN DATOS", "SD")), veh_cilindraje_empty = sum(is.na(CILINDRAJE)),
            veh_cilindraje_zero = sum(CILINDRAJE == "0", na.rm = TRUE), veh_subcategoria_empty = sum(is.na(SUB.CATEGORÍA)),
            veh_exact_duplicate_rows = sum(duplicated(.SD))), by = yr, .SDcols = c("SINIESTRO","MARCA","MODELO","AÑO2","CILINDRAJE","TIPO.DE.SERVICIO","TIPO.DE.VEHÍCULO","SUB.CATEGORÍA")]
w(merge(yrt, vy, by = "yr"), "05_yearly_completeness_districtwide.csv")

# ---------- 5. Keys, links, duplicates ----------
keys <- data.table(check = c("crash rows", "distinct SINIESTRO in crash sheet", "vehicle rows", "distinct SINIESTRO in vehicle sheet",
                             "vehicle SINIESTRO not in crash sheet", "crash SINIESTRO without vehicle rows",
                             "SINIESTRO stored as number (crash sheet)", "SINIESTRO in AMT-<year>-<unit>-<n> text format (crash sheet)",
                             "AMT-format IDs whose year differs from FECHA year", "IDs sharing a base number once an A/B suffix is dropped",
                             "vehicle AÑO and MES equal crash AÑO and MES",
                             "numeric IDs: consecutive pairs (ID order) with decreasing FECHA, share",
                             "exact duplicate crashes on all fields except SINIESTRO",
                             "pairs same FECHA, HORA and exact coordinates", "pairs same FECHA and exact coordinates",
                             "exact duplicate vehicle rows (all 10 columns)", "  of which TIPO DE VEHÍCULO = NO IDENTIFICADO"),
                   value = c(nrow(s), uniqueN(s$SINIESTRO), nrow(v), uniqueN(v$SINIESTRO),
                             sum(!unique(v$SINIESTRO) %in% s$SINIESTRO), sum(!s$SINIESTRO %in% v$SINIESTRO),
                             sum(!s$amt_code), sum(s$amt_code),
                             s[amt_code == TRUE & sub("^AMT-([0-9]+)-.*$", "\\1", SINIESTRO) != as.character(yr), .N],
                             sum(duplicated(sub("[AB]$", "", s$SINIESTRO))),
                             v[, sum(AÑO == format(date, "%Y") & MES == meses[month(date)])],
                             round(s[amt_code == FALSE][order(as.numeric(SINIESTRO)), mean(diff(as.integer(date)) < 0)], 3),
                             sum(duplicated(s[, .(FECHA, HORA, LATITUD, LONGITUD, PARROQUIA, PRINCIPAL, SECUNDARIA, FALLECIDOS, LESIONADOS, TIPOLOGÍA, CAUSA.PROBABLE, SEVERIDAD, VEHICULOS.REGISTRADOS)])),
                             sum(duplicated(s[, .(FECHA, HORA, LATITUD, LONGITUD)])), sum(duplicated(s[, .(FECHA, LATITUD, LONGITUD)])),
                             sum(duplicated(v[, 1:10])), v[duplicated(v[, 1:10]) & TIPO.DE.VEHÍCULO == "NO IDENTIFICADO", .N]))
w(keys, "06_keys_links_duplicates.csv")
idspan <- s[amt_code == FALSE, .(crashes_with_numeric_id = .N, id_min = min(as.numeric(SINIESTRO)), id_max = max(as.numeric(SINIESTRO))), by = yr][order(yr)]
idspan[, share_of_id_range_used := round(crashes_with_numeric_id / (id_max - id_min + 1), 3)]
w(idspan, "07_numeric_id_ranges_by_year.csv")
s[, tmin := hh * 60 + mm]
pairs <- s[, { if (.N < 2) NULL else { cm <- combn(.N, 2); d <- sqrt((X[cm[1, ]] - X[cm[2, ]])^2 + (Y[cm[1, ]] - Y[cm[2, ]])^2); dt <- abs(tmin[cm[1, ]] - tmin[cm[2, ]])
  .(d = d, dt = dt, same = TIPOLOGÍA[cm[1, ]] == TIPOLOGÍA[cm[2, ]] & SEVERIDAD[cm[1, ]] == SEVERIDAD[cm[2, ]] & FALLECIDOS[cm[1, ]] == FALLECIDOS[cm[2, ]] & LESIONADOS[cm[1, ]] == LESIONADOS[cm[2, ]]) } }, by = .(date, yr)]
nd <- pairs[, .(pairs_same_day_within_100m_60min = sum(d <= 100 & dt <= 60), of_which_same_typology_severity_counts = sum(d <= 100 & dt <= 60 & same),
                pairs_same_day_within_10m_any_time = sum(d <= 10), of_which_same_time = sum(d <= 10 & dt == 0)), by = yr][order(yr)]
w(nd, "08_near_duplicates_by_year.csv")
vl_t <- s[, .N, by = .(yr, vehicle_rows_minus_registered = vdiff)][order(yr, vehicle_rows_minus_registered)]
w(vl_t, "09_vehreg_vs_vehicle_rows_by_year.csv")

# ---------- 6. Categories: pre-period counts + presence by year ----------
presence <- function(dt, f, idcol = "yr") { x <- unique(dt[, .(category = get(f), y = get(idcol))]); x[, present := 1L]; dcast(x, category ~ y, value.var = "present", fill = 0L) }
catpre <- function(dt, dtpre, f, label, sheet) {
  pr <- presence(dt, f); setnames(pr, setdiff(names(pr), "category"), paste0("present_", setdiff(names(pr), "category")))
  cnt <- dtpre[, .(count_pre_period = .N), by = .(category = get(f))]
  out <- merge(pr, cnt, by = "category", all.x = TRUE); out[is.na(count_pre_period), count_pre_period := 0L]
  out[, `:=`(field = label, sheet = sheet)]; setcolorder(out, c("sheet", "field", "category", "count_pre_period")); out[order(-count_pre_period)] }
cats <- rbind(catpre(s, p, "TIPOLOGÍA", "TIPOLOGÍA", "SINIESTROS"), catpre(s, p, "CAUSA.PROBABLE", "CAUSA PROBABLE", "SINIESTROS"),
              catpre(s, p, "SEVERIDAD", "SEVERIDAD", "SINIESTROS"), catpre(s, p, "FALLECIDOS", "FALLECIDOS", "SINIESTROS"),
              catpre(s, p, "LESIONADOS", "LESIONADOS", "SINIESTROS"), catpre(s, p, "VEHICULOS.REGISTRADOS", "VEHICULOS REGISTRADOS", "SINIESTROS"),
              catpre(s, p, "PROVINCIA", "PROVINCIA", "SINIESTROS"), catpre(s, p, "CANTON", "CANTON", "SINIESTROS"),
              catpre(v, v[pre == TRUE], "TIPO.DE.SERVICIO", "TIPO DE SERVICIO", "VEHÍCULOS"), catpre(v, v[pre == TRUE], "TIPO.DE.VEHÍCULO", "TIPO DE VEHÍCULO", "VEHÍCULOS"),
              fill = TRUE)
cats[field %in% c("CAUSA PROBABLE") & is.na(category), category := "(empty: #REF! formula error)"]
# Outcome-valued fields: protect sparse tails by top-coding values and withholding their presence
# after the opening is withheld (rule 5; added by the workstream lead after code review pass 2).
topcode <- c(FALLECIDOS = 3L, LESIONADOS = 5L, `VEHICULOS REGISTRADOS` = 5L)
yrcols <- grep("^present_", names(cats), value = TRUE)
tc <- cats[field %in% names(topcode)]
tc[, v := suppressWarnings(as.integer(category))]
tc[!is.na(v) & v >= topcode[field], category := paste0(topcode[field], "+")]
tc <- tc[, c(list(count_pre_period = sum(count_pre_period)), lapply(.SD, max)), by = .(sheet, field, category), .SDcols = yrcols]
cats <- rbind(cats[!field %in% names(topcode)], tc, use.names = TRUE)
late <- intersect(c("present_2024", "present_2025", "present_2026"), names(cats))
cats[, (late) := lapply(.SD, as.character), .SDcols = late]
cats[field %in% names(topcode), (late) := "withheld"]
setnames(cats, "present_2023", "present_2023_incl_december")
w(cats, "10_categories_pre_counts_and_presence.csv")
v[, SUBCAT := fifelse(is.na(SUB.CATEGORÍA), "(empty)", SUB.CATEGORÍA)]
sub_t <- v[pre == TRUE, .(count_pre_period = .N), by = .(TIPO.DE.VEHÍCULO, SUBCAT)]
subpr <- unique(v[, .(TIPO.DE.VEHÍCULO, SUBCAT, yr)])[, present := 1L]
subpr <- dcast(subpr, TIPO.DE.VEHÍCULO + SUBCAT ~ yr, value.var = "present", fill = 0L)
setnames(subpr, as.character(2021:2026), c(paste0("present_", 2021:2022), "present_2023_incl_december", paste0("present_", 2024:2026)))
sub_t <- merge(sub_t, subpr, by = c("TIPO.DE.VEHÍCULO", "SUBCAT"), all = TRUE); sub_t[is.na(count_pre_period), count_pre_period := 0L]
setnames(sub_t, "SUBCAT", "SUB.CATEGORÍA")
sub_t[, group_for_study := fcase(TIPO.DE.VEHÍCULO == "MOTOCICLETA", "motorcycle", TIPO.DE.VEHÍCULO == "BUS", "bus", TIPO.DE.VEHÍCULO %in% c("BICICLETA"), "bicycle",
                                 TIPO.DE.VEHÍCULO == "SCOOTER ELECTRICO", "e-scooter (micromobility)", TIPO.DE.VEHÍCULO == "NO IDENTIFICADO", "unidentified (likely hit and run)", default = "")]
w(sub_t[order(TIPO.DE.VEHÍCULO, -count_pre_period)], "11_vehicle_subcategories_pre.csv")
areas <- rbind(catpre(s, p, "DISTRITO", "DISTRITO", "SINIESTROS"), catpre(s, p, "JEFATURA", "JEFATURA", "SINIESTROS"),
               catpre(s, p, "ADMINISTRACION", "ADMINISTRACION", "SINIESTROS"), catpre(s, p, "PARROQUIA", "PARROQUIA", "SINIESTROS"),
               catpre(s, p, "ZONA", "ZONA", "SINIESTROS"), fill = TRUE)
areas[is.na(category), category := "(empty)"]
# Rule 5: a 0 for a parish or administration after the opening would say that area had no crashes.
# Presence for these geographic fields is shown for pre-opening years only (added by the workstream lead).
areas[, (c("present_2024", "present_2025", "present_2026")) := lapply(.SD, as.character), .SDcols = c("present_2024", "present_2025", "present_2026")]
areas[field %in% c("PARROQUIA", "ADMINISTRACION", "JEFATURA", "DISTRITO"), `:=`(present_2024 = "withheld", present_2025 = "withheld", present_2026 = "withheld")]
setnames(areas, "present_2023", "present_2023_incl_december")
w(areas, "12_area_categories_pre_counts_and_presence.csv")
pz <- dcast(p[, .N, by = .(PARROQUIA, ADMINISTRACION, ZONA = fifelse(is.na(ZONA), "EMPTY", ZONA))], PARROQUIA + ADMINISTRACION ~ ZONA, value.var = "N", fill = 0L)
pz[, total_pre := EMPTY + RURAL + URBANA]
w(pz[order(-total_pre)], "13_parish_zona_pre.csv")
idfmt <- p[, .N, by = .(id_unit_code = fifelse(amt_code, sub("^AMT-[0-9]+-(.*)-[0-9]+[AB]?$", "\\1", SINIESTRO), "(numeric id)"))][order(-N)]
w(idfmt, "14_id_unit_codes_pre.csv")

# ---------- 7. Consistency (pre-period cross-tabs) ----------
sev <- p[, .N, by = .(SEVERIDAD, deaths_gt0 = fall > 0, injured_gt0 = les > 0)][order(SEVERIDAD)]
# Non-numeric death-field details are withheld to avoid record-level disclosure
# (after the second verification); it is counted in build_summary.csv (flag_sicariato).
w(sev[!is.na(deaths_gt0)], "15_severity_vs_counts_pre.csv")
tip_sev <- dcast(p[, .N, by = .(TIPOLOGÍA, SEVERIDAD)], TIPOLOGÍA ~ SEVERIDAD, value.var = "N", fill = 0L)
tip_veh <- dcast(p[, .N, by = .(TIPOLOGÍA, v = fifelse(vreg >= 3, "veh_3plus", paste0("veh_", vreg)))], TIPOLOGÍA ~ v, value.var = "N", fill = 0L)
w(merge(tip_sev, tip_veh, by = "TIPOLOGÍA"), "16_typology_by_severity_and_vehicles_pre.csv")
tc <- dcast(p[, .N, by = .(CAUSA.PROBABLE, TIPOLOGÍA)], CAUSA.PROBABLE ~ TIPOLOGÍA, value.var = "N", fill = 0L)
w(tc, "17_cause_by_typology_pre.csv")
tv <- dcast(v[pre == TRUE, .N, by = .(TIPO.DE.VEHÍCULO, TIPOLOGÍA)], TIPO.DE.VEHÍCULO ~ TIPOLOGÍA, value.var = "N", fill = 0L)
w(tv, "18_vehicle_type_by_typology_pre.csv")
inv_c <- v[pre == TRUE, .(moto = any(TIPO.DE.VEHÍCULO == "MOTOCICLETA"), bus = any(TIPO.DE.VEHÍCULO == "BUS"), bici = any(TIPO.DE.VEHÍCULO == "BICICLETA"), scooter = any(TIPO.DE.VEHÍCULO == "SCOOTER ELECTRICO"), unident = any(TIPO.DE.VEHÍCULO == "NO IDENTIFICADO")), by = SINIESTRO]
w(data.table(measure = c("pre-period crashes", "with a motorcycle", "with a bus", "with a bicycle", "with an e-scooter", "with an unidentified vehicle", "ATROPELLO (pedestrian hit)"),
             crashes = c(nrow(p), sum(inv_c$moto), sum(inv_c$bus), sum(inv_c$bici), sum(inv_c$scooter), sum(inv_c$unident), p[TIPOLOGÍA == "ATROPELLO", .N])), "19_road_user_groups_pre.csv")
atq <- p[, .(crashes = .N, atipico = sum(TIPOLOGÍA == "ATIPICO"), atipico_share = round(mean(TIPOLOGÍA == "ATIPICO"), 3)), by = .(yr, quarter = quarter(date))][order(yr, quarter)]
w(atq, "20_atipico_by_quarter_pre.csv")

# ---------- 8. Time of day (pre) ----------
w(p[, .N, by = .(hour = hh)][order(hour)], "21_hour_of_day_pre.csv")
w(data.table(measure = c("minute = 00", "minute = 30", "minute multiple of 5", "minute multiple of 15", "exactly 00:00", "seconds not zero"),
             share_pre = round(c(p[, mean(mm == 0)], p[, mean(mm == 30)], p[, mean(mm %% 5 == 0)], p[, mean(mm %% 15 == 0)], p[, mean(hms == "00:00:00")], p[, mean(substr(hms, 7, 8) != "00")]), 4),
             expected_if_uniform = round(c(1/60, 1/60, 12/60, 4/60, 1/1440, NA), 4)), "22_hora_heaping_pre.csv")

# ---------- 9. Coordinates ----------
cq <- s[, .(crashes = .N, lat_text = sum(!lat_isnum), lat_number = sum(lat_isnum), lon_text = sum(!lon_isnum), lon_number = sum(lon_isnum),
            dec_min_le3 = sum(mindec <= 3), dec_min_4_5 = sum(mindec %in% 4:5), dec_min_6_7 = sum(mindec %in% 6:7), dec_min_ge8 = sum(mindec >= 8),
            zero_coords = sum(lat == 0 | lon == 0), positive_lon = sum(lon > 0), lat_lon_swapped = sum(abs(lat) > 10),
            outside_box_lat_m0.60_0.40_lon_m79.10_m78.00 = sum(!in_box), farther_than_40km_from_centre = sum(d_ctr_km > 40),
            farther_than_10km_from_own_parish_pre_median = sum(d_own_km > 10, na.rm = TRUE), parish_absent_in_pre_reference = sum(is.na(d_own_km)),
            parish_matches_15_nearest_share = round(mean(PARROQUIA == knn_major), 3), none_of_15_nearest_same_parish = sum(knn_same == 0),
            at_repeated_exact_pair = sum(mult >= 2), at_pair_used_5plus = sum(mult >= 5)), by = yr][order(yr)]
w(cq, "23_coordinate_quality_by_year.csv")
w(data.table(measure = c("min latitude", "max latitude", "min longitude", "max longitude", "max distance to Plaza Grande km"),
             # Extremes are single records' locations: rounded to 0.01 degrees (about 1.1 km) and 1 km.
             value = c(round(c(min(s$lat), max(s$lat), min(s$lon), max(s$lon)), 2), round(max(s$d_ctr_km)))),
  "24_coordinate_extent_all_records.csv")
cl <- p[, .(crashes = .N, distinct_dates = uniqueN(date), distinct_parishes = uniqueN(PARROQUIA), distinct_principal_names = uniqueN(toupper(PRINCIPAL)),
            min_decimals = min(mindec),
            # Banded (not metres) after code review pass 2: clusters of 3 or 4 crashes are near single records.
            distance_to_nearest_station_band = fcase(min(d_station) < 1000, "under 1 km", min(d_station) < 2000, "1 to 2 km", default = "over 2 km"),
            years = paste(sort(unique(yr)), collapse = "/")), by = key][crashes >= 3][order(-crashes)][, key := NULL]
cl[, cluster := seq_len(.N)]; setcolorder(cl, "cluster")
w(cl, "25_repeated_coordinate_pairs_pre.csv")
far_pre <- p[d_ctr_km > 40, .N, by = PARROQUIA][order(-N)]
# Parishes with fewer than 5 such points are grouped (a single point is a single record's location;
# changed by the workstream lead after verification).
far_pre <- rbind(far_pre[N >= 5L], far_pre[N < 5L, .(PARROQUIA = "other parishes (fewer than 5 each)", N = sum(N))][N > 0L])
w(far_pre, "26_points_over_40km_from_centre_by_parish_pre.csv")

# ---------- 10. Proximity to metro (pre only) ----------
w(data.table(measure = c("pre-period crashes", "within 250 m of a station", "within 500 m of a station", "within 1000 m of a station", "within 500 m of the line", "within 1000 m of the line",
                         "within 500 m of the line, injury or fatal", "within 500 m of the line, fatal", "within 500 m of the line, ATROPELLO"),
             crashes_35_months = c(nrow(p), p[d_station <= 250, .N], p[d_station <= 500, .N], p[d_station <= 1000, .N], p[d_line <= 500, .N], p[d_line <= 1000, .N],
                                   p[d_line <= 500 & SEVERIDAD != "DAÑOS MATERIALES", .N], p[d_line <= 500 & SEVERIDAD == "FALLECIDOS", .N], p[d_line <= 500 & TIPOLOGÍA == "ATROPELLO", .N]))[, per_month := round(crashes_35_months / 35, 2)],
  "27_metro_proximity_pre.csv")
stc <- p[d_station <= 500, .(crashes_within_500m_pre = .N, injury_or_fatal = sum(SEVERIDAD != "DAÑOS MATERIALES")), by = st_idx]
stc <- merge(data.table(st_idx = seq_len(nrow(st)), station = st$Name), stc, by = "st_idx", all.x = TRUE)
for (c_ in c("crashes_within_500m_pre", "injury_or_fatal")) set(stc, which(is.na(stc[[c_]])), c_, 0L)
w(stc[, -"st_idx"], "28_crashes_within_500m_by_station_pre.csv")

# ---------- 11. Pre-period monthly series ----------
ms <- dcast(p[, .N, by = .(ym, SEVERIDAD)], ym ~ SEVERIDAD, value.var = "N", fill = 0L)
mt <- dcast(p[, .N, by = .(ym, TIPOLOGÍA)], ym ~ TIPOLOGÍA, value.var = "N", fill = 0L)
w(merge(ms, mt, by = "ym"), "29_monthly_series_pre_by_severity_and_typology.csv")
# SICARIATO flag: record-level attributes are not released
# T30 was dropped after code review pass 2 because it contained record-level details.

# ---------- 12. Extra checks ----------
w(s[amt_code == TRUE & sub("^AMT-([0-9]+)-.*$", "\\1", SINIESTRO) != as.character(yr), .N, by = .(crash_year = yr, crash_month = MES, year_in_id = sub("^AMT-([0-9]+)-.*$", "\\1", SINIESTRO))], "31_amt_id_year_mismatch.csv")
sn <- v[pre == TRUE, .(vehicles = .N, cilindraje_zero = sum(CILINDRAJE == "0", na.rm = TRUE), model_year_zero = sum(AÑO2 == "0", na.rm = TRUE), marca_NI = sum(MARCA == "NI", na.rm = TRUE)), by = TIPO.DE.VEHÍCULO][order(-vehicles)]
w(sn, "32_vehicle_sentinels_by_type_pre.csv")
y2 <- suppressWarnings(as.numeric(v$AÑO2)); cy <- suppressWarnings(as.numeric(v$CILINDRAJE))
w(data.table(check = c("model year text not a number (SIN DATOS, SD, other)", "model year = 0", "model year 1 to 1949", "model year more than 1 year after crash year",
                       "cilindraje = 0", "cilindraje 1 to 49", "cilindraje above 20000", "motorcycle with cilindraje above 2000", "bicycle with cilindraje above 0"),
                 vehicles_all_years = c(sum(is.na(y2) & !is.na(v$AÑO2)), sum(y2 == 0, na.rm = TRUE), sum(y2 > 0 & y2 < 1950, na.rm = TRUE), sum(y2 > as.numeric(v$AÑO) + 1, na.rm = TRUE),
                                        sum(cy == 0, na.rm = TRUE), sum(cy > 0 & cy < 50, na.rm = TRUE), sum(cy > 20000, na.rm = TRUE),
                                        v[TIPO.DE.VEHÍCULO == "MOTOCICLETA" & suppressWarnings(as.numeric(CILINDRAJE)) > 2000, .N], v[TIPO.DE.VEHÍCULO == "BICICLETA" & suppressWarnings(as.numeric(CILINDRAJE)) > 0, .N])),
  "33_vehicle_value_checks.csv")
w(dcast(v[pre == TRUE, .N, by = .(TIPO.DE.VEHÍCULO, TIPO.DE.SERVICIO)], TIPO.DE.VEHÍCULO ~ TIPO.DE.SERVICIO, value.var = "N", fill = 0L), "34_vehicle_type_by_service_pre.csv")
cat("done; tables written to", TD, "\n"); print(list.files(TD))
