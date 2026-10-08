# Check of the name-based fast-road flag (01_build.R) against road geometry (Leonel, 2026-10-01).
# Diagnostic only: the outcome definition is not changed. Pre-period crashes only (January 2021 to
# November 2023, through load_pre()), the same period as output/power/pool_b/fast_road_shares.csv.
# Run from road_safety/ after 02_spatial.R: Rscript code/09_fast_road_check.R
# Method, fixed before running:
# - Fast-road geometry: OSM ways (ROADS_OSM, 2022-01-01, motorway to secondary with links) whose
#   normalized name matches 01_build.R's fast-road pattern (FAST_ROAD_PATTERN, PASAJE excluded);
#   Mariscal Sucre geometry: ways named "MARISCAL SUCRE" or "AVENIDA MARISCAL SUCRE".
# - A crash is "on" the road when its coordinates lie within 50 m of that geometry (25 m and 100 m
#   reported district-wide as sensitivities).
# - "Would change flag": name flag on but the crash is not within the distance (name only), or name
#   flag off but the crash is within the distance (geometry only). Proximity alone is weaker evidence
#   than the name: a crash on a side street can lie within 50 m of a fast road.
# Output, aggregates only: output/build/fast_road_geometry_check.csv (by parish polygon and treated area;
# small counts withheld, with secondary suppression against the district row), fast_road_geometry_summary.csv
# (district-wide, by distance), fast_road_geometry_far.csv (where the off-road matches lie),
# fast_road_geometry_ways.csv and mariscal_sucre_plain_ways.csv (OSM ways used).
source("code/helpers.R")
out <- "output/build"
stopifnot(file.exists(ROADS_OSM), file.exists(PARISH_ZIP),
          substr(system2("sha256sum", shQuote(ROADS_OSM), stdout = TRUE), 1, 64) == ROADS_SHA256,
          substr(system2("sha256sum", shQuote(PARISH_ZIP), stdout = TRUE), 1, 64) == PARISH_SHA256,
          isTRUE(l10n_info()$`UTF-8`))
FAST_ROAD_PATTERN <- paste0("SIMON BOLIVAR|INTEROCEANICA|RUTA VIVA|PANAMERICANA|AUTOPISTA GENERAL RUMINAHUI|",
                            "CORDOVA GALARZA|^E ?-?35$|INTERVALLES")  # as in 01_build.R
norm_street <- function(x) gsub("\\s+", " ", trimws(toupper(chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", x))))
roads <- st_transform(st_read(ROADS_OSM, layer = "lines", quiet = TRUE), CRS_UTM)
roads$nm <- norm_street(roads$name)
# OSM names differ from the AMT's: the E35 is matched on its `ref` tag as well as on the name (pass 6).
roads$ref <- ifelse(grepl('"ref"=>"', roads$other_tags), sub('.*"ref"=>"([^"]*)".*', "\\1", roads$other_tags), NA_character_)
is_fast <- (!is.na(roads$nm) & grepl(FAST_ROAD_PATTERN, roads$nm) & !grepl("^PASAJE", roads$nm)) |
  (!is.na(roads$ref) & grepl("(^|;)\\s*E ?-?35\\s*($|;)", roads$ref))
fast_geom <- st_union(roads[is_fast, ])
ms_ways <- roads[!is.na(roads$nm) & roads$nm %in% c("MARISCAL SUCRE", "AVENIDA MARISCAL SUCRE"), ]
ms_geom <- st_union(ms_ways)
# The OSM ways used as fast-road and Mariscal Sucre geometry (public OSM data): name, class, ref, km.
save_csv(rbind(data.table(set = "fast road", osm_road = roads$nm[is_fast], highway = roads$highway[is_fast], ref = roads$ref[is_fast],
                          km = as.numeric(st_length(roads[is_fast, ])) / 1000),
               data.table(set = "Mariscal Sucre", osm_road = ms_ways$nm, highway = ms_ways$highway, ref = ms_ways$ref,
                          km = as.numeric(st_length(ms_ways)) / 1000))[, .(ways = .N, km = round(sum(km), 2)), by = .(set, osm_road, highway, ref)][
           order(set, osm_road, highway)], file.path(out, "fast_road_geometry_ways.csv"))

pre <- load_pre(CRASHES_SPATIAL)
pts <- st_transform(st_as_sf(pre[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
pre[, `:=`(d_fast = as.numeric(st_distance(pts, fast_geom)), d_ms = as.numeric(st_distance(pts, ms_geom)))]

# Where the ways named plain "MARISCAL SUCRE" lie (geometry only): parish of each way's midpoint.
par <- st_transform(st_read(paste0("/vsizip/", normalizePath(PARISH_ZIP)), quiet = TRUE), CRS_UTM)
plain <- ms_ways[ms_ways$nm == "MARISCAL SUCRE", ]
mid <- suppressWarnings(st_point_on_surface(st_geometry(plain)))
save_csv(data.table(osm_way = plain$osm_id, highway = plain$highway,
                    parish = par$dpa_despar[vapply(st_intersects(mid, par), function(i) if (length(i)) i[1] else NA_integer_, 0L)],
                    length_m = round(as.numeric(st_length(plain)))), file.path(out, "mariscal_sucre_plain_ways.csv"))

small <- function(k) k >= 1L & k <= 4L
D <- 50
tab_of <- function(d, unit) d[, .(
  unit = unit, crashes = .N,
  fast_name = sum(fast_road), fast_name_not_near = sum(fast_road & d_fast > D), fast_near_not_name = sum(!fast_road & d_fast <= D),
  ms_name = sum(av_mariscal_sucre), ms_name_not_near = sum(av_mariscal_sucre & d_ms > D), ms_near_not_name = sum(!av_mariscal_sucre & d_ms <= D))]
treated_units <- c("station catchments 1 km (pooled)", "station catchments 500 m (pooled)", "corridor 500 m of line")
tab <- rbind(tab_of(pre[catchment_1km == TRUE], treated_units[1]),
             tab_of(pre[catchment_500 == TRUE], treated_units[2]),
             tab_of(pre[corridor_500 == TRUE], treated_units[3]),
             rbindlist(lapply(sort(unique(na.omit(pre$parroquia_polygon))), function(p) tab_of(pre[parroquia_polygon == p], p))))
# Primary withholding: a cell is withheld when it is 1 to 4, or when a published total it is part of
# minus the cell is 1 to 4: name flag on and near = name - name_not_near; name flag off = crashes - name;
# name flag off and not near = crashes - name - near_not_name.
w <- copy(tab)
for (k in c("fast", "ms")) {
  nm <- w[[paste0(k, "_name")]]; nn <- w[[paste0(k, "_name_not_near")]]; ng <- w[[paste0(k, "_near_not_name")]]
  hide_nm <- small(nm) | small(w$crashes - nm)
  hide_nn <- small(nn) | small(nm - nn) | hide_nm
  hide_ng <- small(ng) | small(w$crashes - nm - ng) | hide_nm
  set(w, which(hide_nn), paste0(k, "_name_not_near"), NA_integer_)
  set(w, which(hide_ng), paste0(k, "_near_not_name"), NA_integer_)
  set(w, which(hide_nm), paste0(k, "_name"), NA_integer_)
}
set(w, which(small(w$crashes)), "crashes", NA_integer_)

summ <- rbindlist(lapply(c(25, 50, 100), function(dd) pre[, .(
  distance_m = dd, crashes = .N, fast_name = sum(fast_road), fast_name_not_near = sum(fast_road & d_fast > dd),
  fast_near_not_name = sum(!fast_road & d_fast <= dd), ms_name = sum(av_mariscal_sucre),
  ms_name_not_near = sum(av_mariscal_sucre & d_ms > dd), ms_near_not_name = sum(!av_mariscal_sucre & d_ms <= dd))]))
stopifnot(!any(small(as.matrix(summ[, -1]))))  # district totals are never 1 to 4
# Secondary suppression (pass 6): the 50 m district row is the total of the parish rows plus the crashes
# outside every parish polygon (0 to n_out of them in any column). For each column the withheld parish
# cells could be pinned down when only one is withheld, when the remainder (total - published parish
# cells) leaves them no room but 1 each, or, if all of them are 1 to 4, forces them all to 4. While that
# is so, the smallest published parish cell of at least 5 is also withheld; if none is left, the
# district total of that column is withheld instead (in every row where it is the same total).
n_out <- pre[is.na(parroquia_polygon), .N]
is_par <- !w$unit %in% treated_units
s50 <- summ[distance_m == 50]
dist_free <- c("crashes", "fast_name", "ms_name")
for (col in setdiff(names(w), "unit")) {
  repeat {
    v <- w[[col]]; hid <- which(is_par & is.na(v)); k <- length(hid); if (k == 0L) break
    R <- s50[[col]] - sum(v[is_par], na.rm = TRUE)
    truth <- tab[[col]][hid]
    pinned <- k == 1L || R <= k || (all(truth >= 1L & truth <= 4L) && R - n_out >= 4L * k)
    if (!pinned) break
    cand <- which(is_par & !is.na(v) & v >= 5L)
    if (!length(cand)) {
      if (col %in% dist_free) set(summ, NULL, col, NA_integer_) else set(summ, which(summ$distance_m == 50), col, NA_integer_)
      break
    }
    set(w, cand[which.min(v[cand])], col, NA_integer_)
  }
}
save_csv(w, file.path(out, "fast_road_geometry_check.csv"))
# Where the name-flagged crashes that lie off the named geometry are (district-wide, aggregates only):
# distance bands, for Tumbaco and Cumbaya together and for the rest of the district; for the Tumbaco and
# Cumbaya ones more than 500 m away, the OSM road nearest to them (roads with fewer than 5 grouped);
# Mariscal Sucre matches more than 1 km from the avenue. Cells of 1 to 4 are withheld, and a band is
# withheld in both groups when either group's value, or the district value, is 1 to 4.
tc <- pre$parroquia_polygon %in% c("TUMBACO", "CUMBAYA")
br <- c(50, 250, 500, 1000, Inf)  # coarse bands, so that no cell needs withholding
bands <- data.table(band_m = levels(cut(0, br)),
                    tumbaco_cumbaya = as.vector(table(cut(pre[fast_road & d_fast > 50 & tc, d_fast], br))),
                    rest_of_district = as.vector(table(cut(pre[fast_road & d_fast > 50 & !tc, d_fast], br))))
hide <- small(bands$tumbaco_cumbaya) | small(bands$rest_of_district) | small(bands$tumbaco_cumbaya + bands$rest_of_district)
bands[hide, `:=`(tumbaco_cumbaya = NA_integer_, rest_of_district = NA_integer_)]
far <- pre[fast_road & d_fast > 500 & tc]
nf <- st_nearest_feature(st_transform(st_as_sf(far[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM), roads)
near_road <- data.table(osm_road = roads$nm[nf])[, .N, by = osm_road]
near_road[N < 5L | is.na(osm_road), osm_road := "other roads (fewer than 5 crashes each)"]
near_road <- near_road[, .(crashes = sum(N)), by = osm_road][order(-crashes)]
if (any(small(near_road$crashes))) near_road[small(crashes), crashes := NA_integer_]
ms_far <- pre[av_mariscal_sucre & d_ms > 1000]
save_csv(rbind(bands[, .(table = "fast-road flag, > 50 m from the named geometry, by distance", item = band_m,
                         tumbaco_cumbaya, rest_of_district)],
               near_road[, .(table = "Tumbaco and Cumbaya, > 500 m: nearest OSM road", item = osm_road,
                             tumbaco_cumbaya = crashes, rest_of_district = NA_integer_)],
               data.table(table = "Mariscal Sucre flag, > 1 km from the avenue", item = c("crashes", "parishes", "in the 1 km catchments"),
                          tumbaco_cumbaya = NA_integer_,
                          rest_of_district = c(fifelse(small(nrow(ms_far)), NA_integer_, nrow(ms_far)),
                                               uniqueN(ms_far$parroquia_polygon), sum(ms_far$catchment_1km)))),
         file.path(out, "fast_road_geometry_far.csv"))
save_csv(summ, file.path(out, "fast_road_geometry_summary.csv"))
writeLines(c(capture.output(sessionInfo()), paste("roads sha256", ROADS_SHA256), paste("distance m", D)),
           file.path(out, "fast_road_geometry_session_info.txt"))
print(summ)
print(w[unit %in% c(treated_units[1], "CONOCOTO", "TUMBACO", "CUMBAYA", "CALDERON", "CARCELEN", "COMITE DEL PUEBLO",
                    "COTOCOLLAO", "EL CONDADO", "PONCEANO")])
