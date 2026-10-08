# Pre-period evidence for the plan amendment of 2026-10-01 (Leonel's change of course). Pre-period crashes
# only (January 2021 to November 2023, through load_pre()); nothing after the opening is read.
# Run from road_safety/ after 02_spatial.R and 08_gradient.R: Rscript code/10_preperiod_checks.R
# Writes output/preperiod/ (aggregates only; counts of 1 to 4 withheld, also where a published total minus
# the count would be 1 to 4):
#   zone_counts.csv         pre-period crashes by role (zone) x severity x road type
#   fast_fix_changes.csv    crashes whose fast-road or Mariscal Sucre flag changes with the approved fix
#   pretrend_leads.csv      quarterly event-study leads of each target against each comparator, with bands
#   pretrend_summary.csv    linear pre-trend of the gap, its null band and the smallest detectable trend
#   damage_drift.csv        damage-only (and other) trends of treated and comparison areas separately
#   ring_checks.csv         forward fake effects of the 1 to 2 km ring against pool B and the distant parishes
#   brt_in_ring.csv         Trolebus/Ecovia and Central Norte trunk length inside the ring and the catchments
# Method (amendment section 6), fixed before running:
# - Roles: treated = within 1 km of a station; ring = 1 to 2 km; comparator = parishes entirely beyond
#   2 km of the line (all of them, no volume screen); intermediate = the rest of the district; historic
#   center = inside GeoQuito's Area Historica (overlaps treated and ring); placebo highways = within 2 km
#   of a placebo pseudo-station (08_gradient.R; a subset of comparator and intermediate areas).
# - Scale: each monthly series divided by its mean over the months used (proportional scale); gap =
#   target index - comparator index (comparators pooled: their crashes summed).
# - Leads: opening-aligned quarters (Mar-May, Jun-Aug, Sep-Nov, Dec-Feb), full quarters only; lead =
#   mean gap in the quarter - mean gap in Sep-Nov 2023. Bands: 90 percent pointwise, from a moving-block
#   bootstrap (blocks of 3 months, 2,000 draws) of the residuals of the gap around its linear trend, i.e.
#   what noise alone gives (code review pass 7; the bands from the demeaned gap, which also count any
#   real trend as noise, are reported beside them).
# - Pre-trend: least-squares slope of the monthly gap, in percent of the mean per 12 months; its null
#   band (5th to 95th percentile of bootstrap slopes); smallest detectable trend = smallest slope that a
#   two-sided 10 percent test (|slope| beyond the 90th percentile of bootstrap |slopes|) would detect in
#   at least 80 percent of draws. Evidence to show, not a pass or fail test.
# - Seeds: one per pair (SEED + its position), so adding a pair does not change the others.
# - A pair is shown only when every quarter has at least 5 crashes in both target and comparator.
source("code/helpers.R")
out <- "output/preperiod"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
SEED <- 20261001L
B <- 2000L
stopifnot(file.exists(CENTRO_GEOJSON), substr(system2("sha256sum", shQuote(CENTRO_GEOJSON), stdout = TRUE), 1, 64) == CENTRO_SHA256,
          file.exists(BRT_OSM), substr(system2("sha256sum", shQuote(BRT_OSM), stdout = TRUE), 1, 64) == BRT_SHA256,
          file.exists("output/power/gradient/placebo_stations.csv"))
small <- function(k) !is.na(k) & k >= 1L & k <= 4L

pre <- load_pre(CRASHES_SPATIAL)
stopifnot(all(c("fast_road_confirmed", "ms_confirmed", "road_type") %in% names(pre)))  # 02_spatial.R with the fix
months <- seq(PRE_START, month_start(PRE_END), by = "month")
pre[, t := match(month_start(fecha), months)]
ptab <- fread(PARISHES_TABLE)
distant <- ptab[wholly_beyond_2km == TRUE & brt_core_crosses_part_beyond_2km == FALSE, parish_code]
stopifnot(setequal(distant, ptab[wholly_beyond_2km == TRUE, parish_code]))  # the BRT filter drops none
pre[, zone := fcase(dist_station_m < 1000, "treated (1 km catchments)", dist_station_m < 2000, "ring (1 to 2 km)",
                    parish_code %in% distant, "comparator (distant parishes)", !is.na(parish_code), "intermediate",
                    default = "outside the district")]
pre[, damage_only := !injury_or_fatal]
# Pool B (sensitivity comparator): distant parishes passing the volume screen (as in power_units.R).
scr <- pre[parish_code %in% distant, .(m = .N / length(months), z = 1 - uniqueN(t) / length(months)), by = parish_code]
poolB <- scr[m >= 3 & z <= 0.2, parish_code]
stopifnot(length(poolB) == 9L)
# Historic center and placebo highways.
centro <- st_transform(st_read(CENTRO_GEOJSON, quiet = TRUE), CRS_UTM)
pts <- st_transform(st_as_sf(pre[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
pre[, centro := lengths(st_within(pts, centro)) > 0]
ps <- fread("output/power/gradient/placebo_stations.csv")
xy <- st_coordinates(pts)
dmin <- apply(sqrt(outer(xy[, 1], ps$x_utm, "-")^2 + outer(xy[, 2], ps$y_utm, "-")^2), 1, min)
pre[, placebo_highway := dmin < 2000]

# 1. Crashes by role, severity and road type (pre-period, both spans).
zc <- rbindlist(lapply(list(c(13L, 35L)), function(r) {  # 2022-23 only (the 35-month span would allow subtraction against fast_fix_changes)
  d <- pre[t >= r[1] & t <= r[2]]
  rbind(d[, .(crashes = .N), by = .(zone, severity = fifelse(injury_or_fatal, "injury or fatal", "damage only"), road_type)],
        d[centro == TRUE, .(zone = "historic center (overlaps treated and ring)", crashes = .N),
          by = .(severity = fifelse(injury_or_fatal, "injury or fatal", "damage only"), road_type)],
        d[placebo_highway == TRUE, .(zone = "placebo highways (within 2 km of a placebo pseudo-station)", crashes = .N),
          by = .(severity = fifelse(injury_or_fatal, "injury or fatal", "damage only"), road_type)])[,
    period := fifelse(r[1] == 1L, "2021-01 to 2023-11", "2022-01 to 2023-11")][]
}))
zc <- CJ(period = unique(zc$period), zone = unique(zc$zone), severity = c("injury or fatal", "damage only"), road_type = c("city", "fast"))[
  zc, on = .(period, zone, severity, road_type), crashes := i.crashes][is.na(crashes), crashes := 0L][]
zc <- zc[zone != "outside the district"]  # 1 to 4 crashes; dropped from every table here
# Rounded to the nearest 5 (verifier on e2dea41): exact zone totals, subtracted from the citywide monthly
# totals in output/descriptives/, would give the 1 to 4 crashes outside every parish polygon.
zc[, crashes := as.integer(5L * round(crashes / 5))]
setorder(zc, period, zone, severity, road_type)
save_csv(zc, file.path(out, "zone_counts.csv"))

# 2. Flag changes with the approved fast-road fix, by role (pre-period, 35 months).
fx <- function(d, unit) d[, .(unit = unit, crashes = .N,
  fast_name = sum(fast_road), fast_removed = sum(fast_road & !fast_road_confirmed),
  ms_name = sum(av_mariscal_sucre), ms_removed = sum(av_mariscal_sucre & !ms_confirmed))]
ff <- rbind(rbindlist(lapply(setdiff(sort(unique(pre$zone)), "outside the district"), function(z) fx(pre[zone == z], z))),
            fx(pre[centro == TRUE], "historic center"))
# No pool B row (verifier on e2dea41): subtracted from the comparator row, or combined with the shares in
# output/power/pool_b/fast_road_shares.csv, it revealed counts of 1 to 4.
# The district total of Mariscal Sucre matches far from the avenue is published (fast_road_geometry_far.csv),
# so any nonzero removal by area would let the others be worked out: nonzero values are withheld.
for (k in c("fast", "ms")) {
  nm <- ff[[paste0(k, "_name")]]; rm <- ff[[paste0(k, "_removed")]]
  hide <- small(rm) | small(nm - rm) | small(nm) | small(ff$crashes - nm)
  set(ff, which(hide), paste0(k, "_removed"), NA_integer_)
  set(ff, which(small(nm) | small(ff$crashes - nm)), paste0(k, "_name"), NA_integer_)
}
set(ff, which(ff$ms_removed > 0L), "ms_removed", NA_integer_)
# Crash and name-match totals rounded to the nearest 5 (Leonel, 2026-10-01): exact zone totals,
# subtracted from district totals published elsewhere, would give counts for the crashes outside every
# parish polygon.
for (col in c("crashes", "fast_name", "ms_name")) set(ff, NULL, col, as.integer(5L * round(ff[[col]] / 5)))
set(ff, which(small(ff$crashes)), "crashes", NA_integer_)
save_csv(ff, file.path(out, "fast_fix_changes.csv"))

# 3. Pre-trends: event-study leads and linear trend of the gap, with bootstrap bands.
series <- function(d, t0) { v <- tabulate(d$t, length(months)); v[t0:length(months)] }
qlab <- quarter_start(months)
block_boot <- function(x, L = 3L) {  # moving-block bootstrap of a vector
  n <- length(x); starts <- sample.int(n - L + 1L, ceiling(n / L), replace = TRUE)
  unlist(lapply(starts, function(s) x[s:(s + L - 1L)]))[seq_len(n)]
}
pretrend <- function(Tc, Cc, t0, label) {
  mm <- months[t0:length(months)]; q <- quarter_start(mm)
  full_q <- names(which(table(q) == 3L))
  qT <- tapply(Tc, q, sum)[full_q]; qC <- tapply(Cc, q, sum)[full_q]
  if (any(qT < 5) || any(qC < 5)) return(list(leads = data.table(pair = label, quarter = NA_character_, note = "counts too small"),
                                              summ = data.table(pair = label, note = "counts too small")))
  gap <- Tc / mean(Tc) - Cc / mean(Cc)
  tt <- seq_along(gap)
  in_q <- format(q) %in% full_q
  ref <- format(max(as.Date(full_q)))
  lead_of <- function(g) { a <- tapply(g[in_q], format(q[in_q]), mean); a - a[ref] }
  slope_of <- function(g) 12 * 100 * unname(coef(lm(g ~ tt))[2])
  L0 <- lead_of(gap); s0 <- slope_of(gap)
  g0 <- unname(resid(lm(gap ~ tt)))  # residuals around the linear trend
  gd <- gap - mean(gap)              # demeaned (first version), reported beside
  bl <- replicate(B, { g <- block_boot(g0); c(lead_of(g), slope = slope_of(g)) })
  bd <- replicate(B, { g <- block_boot(gd); c(lead_of(g), slope = slope_of(g)) })
  band <- apply(bl[names(L0), , drop = FALSE], 1, quantile, c(0.05, 0.95))
  bandd <- apply(bd[names(L0), , drop = FALSE], 1, quantile, c(0.05, 0.95))
  sb <- bl["slope", ]; q90 <- quantile(abs(sb), 0.90)
  sbd <- bd["slope", ]; q90d <- quantile(abs(sbd), 0.90)
  grid <- seq(0, 300, by = 0.5)
  det <- grid[which(vapply(grid, function(s) mean(abs(sb + s) > q90) >= 0.8, TRUE))[1]]
  detd <- grid[which(vapply(grid, function(s) mean(abs(sbd + s) > q90d) >= 0.8, TRUE))[1]]
  list(leads = data.table(pair = label, quarter = names(L0), lead_pct = round(100 * L0, 1),
                          band_low_pct = round(100 * band[1, ], 1), band_high_pct = round(100 * band[2, ], 1),
                          band_low_demeaned_pct = round(100 * bandd[1, ], 1), band_high_demeaned_pct = round(100 * bandd[2, ], 1),
                          reference = names(L0) == ref, note = ""),
       summ = data.table(pair = label, months = length(gap), quarters = length(full_q), slope_pct_per_year = round(s0, 1),
                         null_band_low = round(quantile(sb, 0.05), 1), null_band_high = round(quantile(sb, 0.95), 1),
                         detectable_trend_pct_per_year = det,
                         null_band_low_demeaned = round(quantile(sbd, 0.05), 1), null_band_high_demeaned = round(quantile(sbd, 0.95), 1),
                         detectable_trend_demeaned = detd, note = ""))
}
sel <- function(z) switch(z,
  treated = pre[zone == "treated (1 km catchments)"], ring = pre[zone == "ring (1 to 2 km)"],
  intermediate = pre[zone == "intermediate"], near_fast = pre[zone %in% c("treated (1 km catchments)", "ring (1 to 2 km)") & road_type == "fast"],
  treated_city = pre[zone == "treated (1 km catchments)" & road_type == "city"], centro = pre[centro == TRUE],
  distant = pre[zone == "comparator (distant parishes)"], poolB = pre[parish_code %in% poolB],
  placebo = pre[placebo_highway == TRUE & road_type == "fast"], distant_fast = pre[zone == "comparator (distant parishes)" & road_type == "fast"],
  distant_city = pre[zone == "comparator (distant parishes)" & road_type == "city"],
  ring_cmp = pre[zone == "ring (1 to 2 km)"],
  distant_no_calderon = pre[zone == "comparator (distant parishes)" & parish_code != CALDERON_CODE])
CALDERON_CODE <- ptab[parish == "CALDERON", parish_code]
stopifnot(length(CALDERON_CODE) == 1L, CALDERON_CODE %in% distant)
outcome_rows <- function(d, oc) switch(oc, all = d, injury = d[injury_or_fatal == TRUE], damage = d[damage_only == TRUE])
pairs <- rbind(
  CJ(target = c("treated", "ring", "intermediate", "treated_city", "centro"), comparator = c("distant", "poolB"),
     outcome = c("injury", "all", "damage"), sorted = FALSE),
  CJ(target = "near_fast", comparator = c("distant", "distant_fast", "placebo"), outcome = c("injury", "all", "damage"), sorted = FALSE),
  CJ(target = "treated_city", comparator = "distant_city", outcome = c("injury", "all", "damage"), sorted = FALSE),
  # Added for the headline set (amendment section 4.5): treated area against the ring (E5) and against the
  # distant parishes without Calderon (E6). Appended, so the seeds of the earlier pairs do not change.
  CJ(target = "treated", comparator = c("ring_cmp", "distant_no_calderon"), outcome = c("injury", "all", "damage"), sorted = FALSE))
res <- list()
for (start in c(2022L, 2021L)) {
  t0 <- if (start == 2022L) 13L else 1L
  pp <- if (start == 2022L) pairs else pairs[target == "treated" & comparator == "distant"]  # 2021: the drift check
  for (i in seq_len(nrow(pp))) {
    p <- pp[i]
    lab <- sprintf("%s vs %s, %s, start %d", p$target, p$comparator, p$outcome, start)
    set.seed(SEED + 1000L * (start - 2020L) + i)
    res[[length(res) + 1L]] <- pretrend(series(outcome_rows(sel(p$target), p$outcome), t0),
                                        series(outcome_rows(sel(p$comparator), p$outcome), t0), t0, lab)
  }
}
save_csv(rbindlist(lapply(res, `[[`, "leads"), fill = TRUE), file.path(out, "pretrend_leads.csv"))
save_csv(rbindlist(lapply(res, `[[`, "summ"), fill = TRUE), file.path(out, "pretrend_summary.csv"))

# Composition of the pooled comparator: the largest parishes' shares of its crashes, January 2022 to
# November 2023 (main period), injury or fatal and all crashes; parishes with fewer than 5 crashes not listed.
cs <- pre[zone == "comparator (distant parishes)" & t >= 13L, .(injury_or_fatal = sum(injury_or_fatal), all_crashes = .N), by = parish_code]
cs <- merge(cs, ptab[, .(parish_code, parish)], by = "parish_code")
cs[, `:=`(share_injury_or_fatal_pct = round(100 * injury_or_fatal / sum(injury_or_fatal), 1), share_all_pct = round(100 * all_crashes / sum(all_crashes), 1))]
save_csv(cs[order(-injury_or_fatal)][1:5][injury_or_fatal >= 5 & all_crashes >= 5, .(parish, share_injury_or_fatal_pct, share_all_pct)],
         file.path(out, "comparator_composition.csv"))

# 4. Damage-only drift: trends of treated and comparison areas separately (each index's own slope), 2021 and 2022 starts.
dr <- rbindlist(lapply(c(2021L, 2022L), function(start) {
  t0 <- if (start == 2022L) 13L else 1L
  rbindlist(lapply(c("damage", "injury", "all"), function(oc) rbindlist(lapply(c("treated", "distant", "poolB"), function(a) {
    set.seed(SEED + 50000L + 100L * (start - 2020L) + 10L * match(oc, c("damage", "injury", "all")) + match(a, c("treated", "distant", "poolB")))
    v <- series(outcome_rows(sel(a), oc), t0); idx <- v / mean(v); tt <- seq_along(idx)
    s0 <- 12 * 100 * unname(coef(lm(idx ~ tt))[2])
    sb <- replicate(B, { g <- block_boot(unname(resid(lm(idx ~ tt)))); 12 * 100 * unname(coef(lm(g ~ tt))[2]) })
    data.table(start = start, outcome = oc, area = a, slope_pct_per_year = round(s0, 1),
               null_band_low = round(quantile(sb, 0.05), 1), null_band_high = round(quantile(sb, 0.95), 1))
  }))))
}))
save_csv(dr, file.path(out, "damage_drift.csv"))

# 5. Ring checks. (a) Forward fake effects of the ring (DID, index scale): against pool B (equal weights
# over its 9 parishes, as in 04b) and against the pooled distant parishes; 9-month fake windows ending by
# November 2023, training before the window (2022 start: 12 to 14 months; 2021 start: 18 to 26 months).
fake_ring <- function(target, start, oc, comp) {
  t0 <- if (start == 2022L) 13L else 1L
  Tc <- series(outcome_rows(sel(target), oc), t0)
  Cm <- if (comp == "poolB") sapply(poolB, function(pc) series(outcome_rows(pre[parish_code == pc], oc), t0))
        else matrix(series(outcome_rows(sel("distant"), oc), t0), ncol = 1)
  n <- length(Tc); mt <- if (start == 2022L) 12L else 18L
  rbindlist(lapply((mt + 1L):(n - 8L), function(k) {
    tr <- seq_len(k - 1L); po <- k:(k + 8L)
    base <- colMeans(Cm[tr, , drop = FALSE]); keep <- base > 0
    gap <- Tc / mean(Tc[tr]) - rowMeans(sweep(Cm[, keep, drop = FALSE], 2, base[keep], "/"))
    data.table(target = target, comparator = comp, outcome = oc, start = start, fake_open = format(months[t0 + k - 1L]),
               fake_effect_pct = round(100 * (mean(gap[po]) - mean(gap[tr])), 1))
  }))
}
rc <- rbindlist(lapply(c(2022L, 2021L), function(st) rbindlist(lapply(c("all", "injury"), function(oc)
  rbind(fake_ring("ring", st, oc, "poolB"), fake_ring("ring", st, oc, "distant"),
        fake_ring("treated", st, oc, "poolB"), fake_ring("treated", st, oc, "distant"))))))
save_csv(rc, file.path(out, "ring_checks.csv"))
# (b) BRT trunk length inside the ring and inside the 1 km catchments (geometry only).
osm <- st_transform(st_read(BRT_OSM, layer = "multilinestrings", quiet = TRUE), CRS_UTM)
ref <- ifelse(grepl('"ref"=>"', osm$other_tags), sub('.*"ref"=>"([^"]*)".*', "\\1", osm$other_tags), NA_character_)
core <- grepl('"network"=>"Metrobus-Q"', osm$other_tags) & ref %in% c("C1", "C4", "C6", "E1", "E1R", "E3", "E4", "E6")
cn <- osm$osm_id %in% c("2021069", "85969")
stopifnot(sum(core) == 16L, sum(cn) == 2L)
stations <- st_transform(st_zm(st_read(STATIONS_GPKG, quiet = TRUE)), CRS_UTM)
c1 <- st_union(st_buffer(stations, 1000)); c2 <- st_union(st_buffer(stations, 2000)); ring <- st_difference(c2, c1)
len_km <- function(lines, area) { x <- suppressWarnings(st_intersection(st_union(lines), area)); if (length(x)) sum(as.numeric(st_length(x))) / 1000 else 0 }
a_km2 <- c(as.numeric(st_area(c1)), as.numeric(st_area(ring))) / 1e6
te_km <- c(len_km(osm[core, ], c1), len_km(osm[core, ], ring))
save_csv(data.table(area = c("1 km catchments", "ring 1 to 2 km"), area_km2 = round(a_km2, 1), trolebus_ecovia_km = round(te_km, 1),
                    central_norte_km = round(c(len_km(osm[cn, ], c1), len_km(osm[cn, ], ring)), 1),
                    trolebus_ecovia_km_per_km2 = round(te_km / a_km2, 2)), file.path(out, "brt_in_ring.csv"))
# Historic center geometry facts (no crash data).
save_csv(data.table(area_km2 = round(as.numeric(st_area(centro)) / 1e6, 2),
                    share_within_1km_of_a_station = round(as.numeric(st_area(st_intersection(st_geometry(centro), c1))) / as.numeric(st_area(centro)), 3),
                    share_within_2km_of_a_station = round(as.numeric(st_area(st_intersection(st_geometry(centro), c2))) / as.numeric(st_area(centro)), 3),
                    stations_inside = paste(stations$Name[lengths(st_within(stations, centro)) > 0], collapse = "; ")),
         file.path(out, "historic_center.csv"))
writeLines(c(capture.output(sessionInfo()), paste("seed", SEED), paste("bootstrap draws", B),
             paste("centro sha256", CENTRO_SHA256), paste("BRT sha256", BRT_SHA256),
             paste("placebo stations md5", unname(tools::md5sum("output/power/gradient/placebo_stations.csv")))),
           file.path(out, "session_info.txt"))
cat("done\n")
