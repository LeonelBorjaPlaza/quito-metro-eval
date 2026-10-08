# Item 3: clean build. Run from road_safety/: Rscript code/01_build.R
# Reads both sheets of the AMT crash matrix as text, fixes types, links vehicles to crashes,
# derives severity and involvement flags, and writes one row per crash to
# data/derived/crashes.parquet (git-ignored). Problems are flagged, never dropped.
# Saves district-wide counts only (output/build/), with no dates and no areas, plus one pre-period table of
# the street-name variants counted as fast roads (fast_road_names_pre.csv; mentions in PRINCIPAL or
# SECUNDARIA over all pre-period rows, so a crash naming two fast roads counts twice; variants under 5 grouped).
source("code/helpers.R")

stopifnot(substr(system2("sha256sum", shQuote(RAW_XLSX), stdout = TRUE), 1, 64) == RAW_SHA256)

sheets <- readxl::excel_sheets(RAW_XLSX)
stopifnot(identical(sheets, c("SINIESTROS", "VEHÍCULOS")))
s <- as.data.table(readxl::read_excel(RAW_XLSX, sheet = "SINIESTROS", col_types = "text"))
v <- as.data.table(readxl::read_excel(RAW_XLSX, sheet = "VEHÍCULOS", col_types = "text"))
stopifnot(ncol(s) == 23L, ncol(v) == 10L)
trim <- function(x) { x <- trimws(x); x[x == ""] <- NA_character_; x }
s[, names(s) := lapply(.SD, trim)]
v[, names(v) := lapply(.SD, trim)]
n_s <- nrow(s); n_v <- nrow(v)

# Keys: one row per crash in SINIESTROS; every vehicle row carries a crash ID.
stopifnot(!anyNA(s$SINIESTRO), uniqueN(s$SINIESTRO) == n_s)

# Date: FECHA is an Excel serial day number. AÑO and MES are checked against it.
num <- function(x) suppressWarnings(as.numeric(x))
fecha <- as.Date(num(s$FECHA), origin = "1899-12-30")
stopifnot(!anyNA(fecha))
meses <- c("ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO",
           "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE")
dias <- c("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")
mes_recorded <- match(toupper(s$MES), meses)
dia_recorded <- match(tolower(s$DIA), dias)
weekday <- as.integer(format(fecha, "%u"))  # 1 = Monday

# Time: HORA is a fraction of a day, sometimes written in scientific notation.
# The fractional part is used (a date-plus-time value keeps its time), and 24:00 wraps to 00:00.
hora_frac <- num(s$HORA)
minute_of_day <- as.integer(round((hora_frac %% 1) * 1440)) %% 1440L
hora_ok <- !is.na(minute_of_day)

# Coordinates: stored partly as text; all should convert.
lat <- num(s$LATITUD); lon <- num(s$LONGITUD)
# Coarse plausibility box around the district. The polygon check waits for the parish layer.
coord_far <- is.na(lat) | is.na(lon) | lat < -0.7 | lat > 0.3 | lon < -79.1 | lon > -78.0
# Possible default or snapped locations: an exact coordinate pair shared by 5 or more records (any date;
# a data-quality flag, not an outcome). Threshold set in Step 1 after the data audit (T25).
REPEAT_MIN <- 5L
point_key <- paste(lat, lon)
repeated_point <- ave(seq_along(point_key), point_key, FUN = length) >= REPEAT_MIN

# Fast roads (diagnostic for the comparison pool, Leonel 2026-09-27): a crash is on a fast road when
# PRINCIPAL or SECUNDARIA names one of the intercity or peri-urban highways below. Av. Mariscal Sucre
# (the Occidental), an urban expressway, is flagged separately; urban arterials are not included.
norm_street <- function(x) gsub("\\s+", " ", trimws(toupper(chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", x))))
FAST_ROAD_PATTERN <- paste0("SIMON BOLIVAR|INTEROCEANICA|RUTA VIVA|PANAMERICANA|AUTOPISTA GENERAL RUMINAHUI|",
                            "CORDOVA GALARZA|^E ?-?35$|INTERVALLES")
is_fast <- function(x) { x <- norm_street(x); !is.na(x) & grepl(FAST_ROAD_PATTERN, x) & !grepl("^PASAJE", x) }
is_occidental <- function(x) { x <- norm_street(x); !is.na(x) & x == "MARISCAL SUCRE" }
fast_road <- is_fast(s$PRINCIPAL) | is_fast(s$SECUNDARIA)
occidental <- is_occidental(s$PRINCIPAL) | is_occidental(s$SECUNDARIA)

# Deaths and injuries. SICARIATO-flagged entries are kept with deaths set to NA.
sicariato <- !is.na(s$FALLECIDOS) & grepl("SICARIATO", s$FALLECIDOS, fixed = TRUE)
fallecidos <- as.integer(num(s$FALLECIDOS))
lesionados <- as.integer(num(s$LESIONADOS))
stopifnot(sum(is.na(fallecidos) & !is.na(s$FALLECIDOS)) == sum(sicariato),
          sum(is.na(lesionados) & !is.na(s$LESIONADOS)) == 0L)

severity <- c("DAÑOS MATERIALES" = "damage_only", "LESIONADOS" = "injury", "FALLECIDOS" = "fatal")[s$SEVERIDAD]
stopifnot(!anyNA(severity))
severity_inconsistent <- (severity == "fatal" & !is.na(fallecidos) & fallecidos == 0L) |
  (severity != "fatal" & !is.na(fallecidos) & fallecidos > 0L) |
  (severity == "injury" & lesionados == 0L) |
  (severity == "damage_only" & lesionados > 0L)

crashes <- data.table(
  crash_id = s$SINIESTRO,
  fecha = fecha,
  year = as.integer(format(fecha, "%Y")),
  month = as.integer(format(fecha, "%m")),
  weekday = weekday,
  minute_of_day = ifelse(hora_ok, minute_of_day, NA_integer_),
  hour = ifelse(hora_ok, minute_of_day %/% 60L, NA_integer_),
  lat = lat, lon = lon,
  distrito = s$DISTRITO, jefatura = s$JEFATURA, parroquia = toupper(s$PARROQUIA),
  administracion = s$ADMINISTRACION, zona = s$ZONA,
  tipologia = s$`TIPOLOGÍA`, causa = s$`CAUSA PROBABLE`,
  severidad = s$SEVERIDAD, severity = unname(severity),
  injury_or_fatal = severity %in% c("injury", "fatal"),
  pedestrian = s$`TIPOLOGÍA` == "ATROPELLO",
  fallecidos = fallecidos, lesionados = lesionados,
  vehicles_registered = as.integer(num(s$`VEHICULOS REGISTRADOS`)),
  flag_sicariato = sicariato,
  flag_zona_missing = is.na(s$ZONA),
  flag_parroquia_case = !is.na(s$PARROQUIA) & s$PARROQUIA != toupper(s$PARROQUIA),  # normalised to upper case
  flag_coord_far = coord_far,
  flag_repeated_point = repeated_point,
  fast_road = fast_road,
  av_mariscal_sucre = occidental,
  flag_outside_district = NA,  # stays NA until the parish boundary layer is in the store
  flag_parish_mismatch = NA,   # recorded PARROQUIA vs the polygon containing the point: also waits for it
  flag_hora_invalid = !hora_ok,
  flag_year_mismatch = num(s$`AÑO`) != as.integer(format(fecha, "%Y")),
  flag_month_mismatch = is.na(mes_recorded) | mes_recorded != as.integer(format(fecha, "%m")),
  flag_weekday_mismatch = is.na(dia_recorded) | dia_recorded != weekday,
  flag_severity_inconsistent = severity_inconsistent
)

# Vehicles: counts per crash by type (TIPO DE VEHÍCULO), and a check against VEHICULOS REGISTRADOS.
setnames(v, "TIPO DE VEHÍCULO", "vtype")
veh <- v[, .(
  n_vehicle_rows = .N,
  n_motorcycle = sum(vtype %in% "MOTOCICLETA"),
  n_bus = sum(vtype %in% "BUS"),
  n_bicycle = sum(vtype %in% "BICICLETA"),
  n_scooter = sum(vtype %in% "SCOOTER ELECTRICO"),
  n_truck = sum(vtype %in% "CAMION"),
  n_unidentified = sum(vtype %in% "NO IDENTIFICADO"),
  n_type_missing = sum(is.na(vtype))
), by = .(crash_id = SINIESTRO)]
orphan_vehicle_rows <- sum(!v$SINIESTRO %in% crashes$crash_id)
crashes <- merge(crashes, veh, by = "crash_id", all.x = TRUE, sort = TRUE)
count_cols <- grep("^n_", names(crashes), value = TRUE)
crashes[, (count_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0L, x)), .SDcols = count_cols]
crashes[, `:=`(
  any_motorcycle = n_motorcycle > 0L, any_bus = n_bus > 0L, any_bicycle = n_bicycle > 0L,
  flag_no_vehicle_rows = n_vehicle_rows == 0L,
  flag_vehicle_count_mismatch = is.na(vehicles_registered) | vehicles_registered != n_vehicle_rows
)]
stopifnot(nrow(crashes) == n_s)

dir.create(DERIVED_DIR, recursive = TRUE, showWarnings = FALSE)
write_parquet(crashes, CRASHES_BUILD)

# Street-name variants counted as fast roads, pre-period only; variants with fewer than 5 crashes grouped.
pre_rows <- fecha < OPENING
fr <- data.table(name = norm_street(c(s$PRINCIPAL[pre_rows], s$SECUNDARIA[pre_rows])))
fr <- fr[!is.na(name) & (grepl(FAST_ROAD_PATTERN, name) & !grepl("^PASAJE", name) | name == "MARISCAL SUCRE"),
         .(mentions_pre = .N), by = name][order(-mentions_pre)]
fr[, group := fifelse(name == "MARISCAL SUCRE", "Av. Mariscal Sucre (reported separately)", "fast road")]
fr <- rbind(fr[mentions_pre >= 5L], fr[mentions_pre < 5L, .(name = "other variants (fewer than 5 each)",
                                                           mentions_pre = sum(mentions_pre), group = "fast road")][mentions_pre > 0L])
save_csv(fr, "output/build/fast_road_names_pre.csv")

# District-wide counts for the whole file, with no dates and no areas.
flag_cols <- grep("^flag_", names(crashes), value = TRUE)
summary <- rbind(
  data.table(item = c("crash rows read", "crash rows written", "distinct crash IDs",
                      "vehicle rows read", "vehicle rows linked to a crash", "vehicle rows with no crash",
                      "crashes with at least one vehicle row"),
             n = c(n_s, nrow(crashes), uniqueN(crashes$crash_id), n_v, n_v - orphan_vehicle_rows,
                   orphan_vehicle_rows, sum(crashes$n_vehicle_rows > 0L))),
  # A flag never checked (all NA, for example flag_outside_district) is reported as NA, not 0.
  data.table(item = flag_cols, n = vapply(flag_cols, function(f)
    if (all(is.na(crashes[[f]]))) NA_real_ else sum(crashes[[f]], na.rm = TRUE), numeric(1))),
  data.table(item = paste0(flag_cols, " (NA)"), n = vapply(flag_cols, function(f) sum(is.na(crashes[[f]])), numeric(1)))
)
save_csv(summary, "output/build/build_summary.csv")
vtypes <- v[, .(vehicle_rows = .N), by = .(tipo_de_vehiculo = vtype)][order(-vehicle_rows)]
save_csv(vtypes, "output/build/vehicle_types.csv")
save_csv(data.table(column = names(crashes), type = vapply(crashes, function(x) class(x)[1], "")),
         "output/build/derived_columns.csv")
print(summary)
cat("Wrote", CRASHES_BUILD, "with", nrow(crashes), "crashes and", ncol(crashes), "columns.\n")
