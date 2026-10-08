# Candidate 3 (Leonel, 2026-09-27): gradient design with placebo corridors along other major avenues.
# Pre-period only, January 2022 start, P1, 15 fake placements. Run from road_safety/ after 02_spatial.R
# (and before 07_candidates.R, which adds these rows to its comparison table):
#   Rscript code/08_gradient.R
# Placebo avenue rule, written before any run (plan section 4; decision record 2026-09-27):
# - Candidate ways: named OSM motorway, trunk and primary ways (ROADS_OSM), grouped by normalized
#   name and merged into lines.
# - Drop every part within 4 km of the metro line (so a placebo's 0 to 2 km bands never reach the
#   metro's 2 km zone) and within 500 m of a Trolebus or Ecovia trunk; a segment within 500 m of the
#   Central Norte MetroBus is flagged for a sensitivity.
# - Cut each remaining piece into segments of 5 pseudo-stations spaced 1,554 m (the line's mean
#   station spacing: 21.76 km over 14 gaps). Avenues are walked in alphabetical order, each piece from
#   its start vertex, trying a segment start at every multiple of the spacing; a segment is kept only
#   if every pseudo-station's 2 km disc is clear of the discs of segments already kept (stations at
#   least 4 km apart). Implementation detail: every pseudo-station must lie inside the district (the
#   parish polygons), since the crash records cover the district only.
# - No crash data are read in choosing placebos.
# Statistic, per corridor (the metro, with its 15 stations, or a placebo): crashes within 1 km of its
# nearest (pseudo)station (inner) and 1 to 2 km (outer), monthly, each divided by its training mean;
# gap = inner - outer; effect = mean gap in the fake window minus in the training months, divided by
# the gap's root mean square error over the training months. Rank p = (1 + placebos with an effect at
# least as large in absolute value) / (P + 1); floor 1/(P + 1). Effects are injected into the metro's
# inner band only (thinning for falls, added Poisson draws for rises; 10 draws per placement).
source("code/helpers.R")
Sys.setenv(RS_PRE_START = "2022-01-01")
source("code/power_units.R")
stopifnot(RUN_START == as.Date("2022-01-01"), length(months) == 23L)
out <- "output/power/gradient"
stopifnot(file.exists(ROADS_OSM), file.exists(BRT_OSM), file.exists(PARISH_ZIP))  # before the checksums: a missing file would pass them silently
SEED <- 20260925L
R_DRAWS <- 10L
DELTAS <- c(-0.5, -0.4, -0.3, -0.25, -0.2, -0.15, -0.1, -0.05, 0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5)
SPACING_M <- 1554
N_STATIONS <- 5L
EXCLUDE_LINE_M <- 4000
EXCLUDE_BRT_M <- 500
H <- 9L

dir.create(out, recursive = TRUE, showWarnings = FALSE)
# ---- Placebo corridors (geometry only) --------------------------------------------------------
stopifnot(substr(system2("sha256sum", shQuote(ROADS_OSM), stdout = TRUE), 1, 64) == ROADS_SHA256,
          substr(system2("sha256sum", shQuote(BRT_OSM), stdout = TRUE), 1, 64) == BRT_SHA256,
          substr(system2("sha256sum", shQuote(PARISH_ZIP), stdout = TRUE), 1, 64) == PARISH_SHA256,
          isTRUE(l10n_info()$`UTF-8`))  # the name normalisation needs a UTF-8 locale
norm_street <- function(x) gsub("\\s+", " ", trimws(toupper(chartr("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun", x))))
roads <- st_transform(st_read(ROADS_OSM, layer = "lines", quiet = TRUE), CRS_UTM)
roads <- roads[roads$highway %in% c("motorway", "trunk", "primary") & !is.na(roads$name) & nzchar(roads$name), ]
roads$avenue <- norm_street(roads$name)
osm_brt <- st_transform(st_read(BRT_OSM, layer = "multilinestrings", quiet = TRUE), CRS_UTM)
brt_ref <- ifelse(grepl('"ref"=>"', osm_brt$other_tags), sub('.*"ref"=>"([^"]*)".*', "\\1", osm_brt$other_tags), NA_character_)
brt_net <- grepl('"network"=>"Metrobus-Q"', osm_brt$other_tags)
is_core <- brt_net & brt_ref %in% c("C1", "C4", "C6", "E1", "E1R", "E3", "E4", "E6")
is_cn <- osm_brt$osm_id %in% c("2021069", "85969")
stopifnot(sum(is_core) == 16L, sum(is_cn) == 2L)  # as in 02_spatial.R
brt_core <- st_union(osm_brt[is_core, ])
brt_cn <- st_union(osm_brt[is_cn, ])
district <- st_union(st_transform(st_read(paste0("/vsizip/", normalizePath(PARISH_ZIP)), quiet = TRUE), CRS_UTM))
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG, quiet = TRUE)), CRS_UTM))
stopifnot(abs(as.numeric(st_length(line)) / 14 - SPACING_M) < 1)  # the line's mean spacing, as fixed in the rule
excl <- st_union(st_buffer(line, EXCLUDE_LINE_M), st_buffer(brt_core, EXCLUDE_BRT_M))

avenues <- sort(unique(roads$avenue), method = "radix")  # byte order, the same under every locale
kept <- list(); kept_pts <- matrix(numeric(), 0, 2)
for (a in avenues) {
  g <- st_union(st_geometry(roads[roads$avenue == a, ]))
  if (inherits(g, "sfc_MULTILINESTRING")) g <- st_line_merge(g)
  g <- suppressWarnings(st_difference(g, excl))
  if (length(g) == 0L || all(st_is_empty(g))) next
  pieces <- suppressWarnings(st_cast(st_collection_extract(g, "LINESTRING"), "LINESTRING"))
  for (j in seq_along(pieces)) {
    len <- as.numeric(st_length(pieces[j]))
    if (len < (N_STATIONS - 1L) * SPACING_M) next
    starts <- seq(0, len - (N_STATIONS - 1L) * SPACING_M, by = SPACING_M)
    for (s0 in starts) {
      pts <- st_line_sample(pieces[j], sample = (s0 + (0:(N_STATIONS - 1L)) * SPACING_M) / len)
      xy <- st_coordinates(st_cast(pts, "POINT"))[, 1:2, drop = FALSE]
      if (nrow(xy) != N_STATIONS) next
      if (!all(lengths(st_within(st_cast(pts, "POINT"), district)) > 0L)) next
      if (nrow(kept_pts) && min(as.matrix(dist(rbind(kept_pts, xy)))[nrow(kept_pts) + seq_len(N_STATIONS), seq_len(nrow(kept_pts))]) < 4000) next
      # The road itself between the first and last pseudo-station, sampled every 50 m (for the flag).
      seg_line <- st_sfc(st_linestring(st_coordinates(st_cast(st_line_sample(pieces[j],
                    sample = unique(c(seq(s0, s0 + (N_STATIONS - 1L) * SPACING_M, by = 50), s0 + (N_STATIONS - 1L) * SPACING_M)) / len), "POINT"))[, 1:2]), crs = CRS_UTM)
      kept[[length(kept) + 1L]] <- data.table(corridor = sprintf("P%02d", length(kept) + 1L), avenue = a, piece = j,
                                              piece_km = round(len / 1000, 2), start_m = s0, x = list(xy[, 1]), y = list(xy[, 2]),
                                              central_norte = as.numeric(st_distance(seg_line, brt_cn)) < EXCLUDE_BRT_M,
                                              min_dist_line_km = round(min(as.numeric(st_distance(st_cast(pts, "POINT"), line))) / 1000, 2))
      kept_pts <- rbind(kept_pts, xy)
    }
  }
}
placebos <- rbindlist(kept)
P <- nrow(placebos)
cat("Placebo corridors:", P, "\n")
save_csv(placebos[, .(segments = .N, central_norte_flagged = sum(central_norte), min_dist_line_km = min(min_dist_line_km)),
                  by = .(avenue)][order(avenue)], file.path(out, "placebo_avenues.csv"))
# One row per placebo (geometry only, no crash data): its avenue, the length of the remaining piece it
# was cut from, where it starts on that piece, its distance from the line, and the Central Norte flag.
save_csv(placebos[, .(corridor, avenue, piece_km, start_km = round(start_m / 1000, 3),
                      segment_km = round((N_STATIONS - 1L) * SPACING_M / 1000, 3), min_dist_line_km, central_norte)],
         file.path(out, "placebo_corridors.csv"))
# Pseudo-station positions (UTM 17S, geometry only), read by 10_preperiod_checks.R for the placebo-highway
# comparator.
save_csv(placebos[, .(station = seq_len(N_STATIONS), x_utm = round(unlist(x), 1), y_utm = round(unlist(y), 1)), by = corridor],
         file.path(out, "placebo_stations.csv"))

# ---- Band counts per corridor (pre-period, January 2022 to November 2023) ---------------------
pre22 <- pre[fecha >= RUN_START][, t := match(month_start(fecha), months)]
stopifnot(!anyNA(pre22$t))
pts <- st_transform(st_as_sf(pre22[, .(lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_UTM)
pxy <- st_coordinates(pts)
OUTCOMES <- c("all_crashes", "injury_or_fatal", "urban_street_all", "urban_street_injury")
pre22[, `:=`(all_crashes = TRUE, urban_street_all = !fast_road, urban_street_injury = injury_or_fatal & !fast_road)]
band_series <- function(d_m, oc) {  # d_m: distance of each pre-period crash to the corridor's nearest station
  inner <- tabulate(pre22$t[d_m < 1000 & pre22[[oc]]], length(months))
  outer <- tabulate(pre22$t[d_m >= 1000 & d_m < 2000 & pre22[[oc]]], length(months))
  rbind(inner = inner, outer = outer)
}
dist_to <- function(sx, sy) sqrt(outer(pxy[, 1], sx, "-")^2 + outer(pxy[, 2], sy, "-")^2)
d_metro <- pre22$dist_station_m
d_plac <- lapply(seq_len(P), function(i) apply(dist_to(placebos$x[[i]], placebos$y[[i]]), 1, min))
series <- lapply(setNames(OUTCOMES, OUTCOMES), function(oc) c(
  list(metro = band_series(d_metro, oc)), setNames(lapply(d_plac, band_series, oc = oc), placebos$corridor)))
small <- function(k) fifelse(k >= 1L & k <= 4L, NA_integer_, k)
# All crashes and injury or fatal crashes only; injury is withheld where all crashes is withheld or the
# difference (damage-only crashes) is 1 to 4, so no withheld count can be recovered by subtraction.
bc <- rbindlist(lapply(names(series$all_crashes), function(cn) {
  a <- rowSums(series$all_crashes[[cn]]); i <- rowSums(series$injury_or_fatal[[cn]])
  data.table(corridor = cn, band = c("inner 0-1 km", "outer 1-2 km"), all_crashes = small(as.integer(a)),
             injury_or_fatal = fifelse(between(a - i, 1, 4) | between(a, 1, 4), NA_integer_, small(as.integer(i))))
}))
save_csv(bc, file.path(out, "band_counts_pre2022.csv"))

# ---- Power: 15 placements, rank against the placebo corridors --------------------------------
opens <- 1:(length(months) - H + 1L)
stat_of <- function(S, post, train) {  # S: 2 x T counts (inner, outer); NA when a training mean is 0
  base <- rowMeans(S[, train, drop = FALSE]); if (any(base == 0)) return(c(stat = NA_real_, effect = NA_real_))  # unusable placebo
  gap <- S["inner", ] / base[1] - S["outer", ] / base[2]
  rmse <- sqrt(mean((gap[train] - mean(gap[train]))^2))
  eff <- mean(gap[post]) - mean(gap[train])
  c(stat = abs(eff) / rmse, effect = eff)
}
inject <- function(y, delta) {
  if (delta < 0) rbinom(length(y), y, 1 + delta) else if (delta > 0) y + rpois(length(y), delta * y) else y
}
designs <- CJ(outcome = OUTCOMES, placebo_set = c("all", "no_central_norte"), sorted = FALSE)
run_design <- function(i) {
  g <- designs[i]
  set.seed(SEED + 40000L + i)
  pl <- if (g$placebo_set == "all") placebos$corridor else placebos[central_norte == FALSE, corridor]
  res <- list()
  for (k in opens) {
    post <- k:(k + H - 1L); train <- setdiff(seq_along(months), post)
    ps <- vapply(pl, function(cn) stat_of(series[[g$outcome]][[cn]], post, train)[["stat"]], 0)
    stopifnot(!any(is.nan(ps)))  # a NaN (zero fit error and zero effect) would be dropped silently below
    ps <- ps[!is.na(ps)]
    # Forward subset: the last three windows with training before the window only (panel cut after it).
    fwd_p <- NA_real_
    if (k >= length(opens) - 2L) {
      cols <- seq_len(k + H - 1L); tr_f <- seq_len(k - 1L)
      pf <- vapply(pl, function(cn) stat_of(series[[g$outcome]][[cn]][, cols], post, tr_f)[["stat"]], 0)
      stopifnot(!any(is.nan(pf)))
      pf <- pf[!is.na(pf)]
      sf <- stat_of(series[[g$outcome]]$metro[, cols], post, tr_f)[["stat"]]
      fwd_p <- (1 + sum(pf >= sf - 1e-12)) / (length(pf) + 1)
    }
    for (delta in DELTAS) for (r in seq_len(if (delta == 0) 1L else R_DRAWS)) {
      S <- series[[g$outcome]]$metro
      S["inner", post] <- inject(S["inner", post], delta)
      st <- stat_of(S, post, train)
      res[[length(res) + 1L]] <- data.table(fake_open = k, delta = delta, draw = r, placebos = length(ps), p_forward = fwd_p,
                                            placebos_forward = if (k >= length(opens) - 2L) length(pf) else NA_integer_,
                                            p = (1 + sum(ps >= st[["stat"]] - 1e-12)) / (length(ps) + 1),
                                            effect = st[["effect"]])
    }
  }
  cbind(g, rbindlist(res))
}
sims <- rbindlist(parallel::mclapply(seq_len(nrow(designs)), run_design, mc.cores = as.integer(Sys.getenv("RS_CORES", "8"))))
curves <- sims[, .(power_05 = mean(p <= 0.05), power_10 = mean(p <= 0.10), runs = .N, placebos_min = min(placebos)),
               by = .(outcome, placebo_set, delta)]
save_csv(curves, file.path(out, "gradient_power_curves.csv"))
mde <- function(delta, power, sign) {
  x <- data.table(delta, power)[sign * delta > 0][order(abs(delta))]
  ok <- rev(cumprod(rev(x$power >= 0.8))) == 1
  if (!any(ok)) NA_real_ else abs(x$delta[which(ok)[1]])
}
size_fails <- function(k, n, alpha) k / n > max(alpha, 1 / n)
label <- function(m, attainable, fail) fifelse(!attainable, "not attainable", fifelse(fail, "size fails", fifelse(is.na(m), "> 50", as.character(round(100 * m)))))
nul <- sims[delta == 0]
tab <- curves[, .(placebos = placebos_min[1], smallest_rank_p = round(1 / (placebos_min[1] + 1), 4),
                  m_dec_05 = mde(delta, power_05, -1), m_inc_05 = mde(delta, power_05, 1),
                  m_dec_10 = mde(delta, power_10, -1), m_inc_10 = mde(delta, power_10, 1)), by = .(outcome, placebo_set)]
tab <- merge(tab, nul[, .(rej05 = sum(p <= 0.05), rej10 = sum(p <= 0.10), n = .N,
                          fwd05 = sum(p_forward <= 0.05, na.rm = TRUE), fwd10 = sum(p_forward <= 0.10, na.rm = TRUE),
                          n_fwd = sum(!is.na(p_forward)), placebos_forward_min = min(placebos_forward, na.rm = TRUE),
                          fake_effect_mean_pct = round(100 * mean(effect), 1), fake_effect_min_pct = round(100 * min(effect), 1),
                          fake_effect_max_pct = round(100 * max(effect), 1)), by = .(outcome, placebo_set)], by = c("outcome", "placebo_set"))
rows <- tab[, .(
  design = "gradient (inner 0-1 km minus outer 1-2 km), placebo corridors", pool = paste0("placebo corridors (", placebo_set, ")"),
  outcome, variant = "rank", donors = placebos, fake_effect_mean_pct, fake_effect_min_pct, fake_effect_max_pct,
  null_rejections_05 = sprintf("%d of %d", rej05, n), null_rejections_10 = sprintf("%d of %d", rej10, n),
  size_check_05 = fifelse(smallest_rank_p > 0.05, "not testable", fifelse(size_fails(rej05, n, 0.05), "fails", "passes")),
  size_check_10 = fifelse(smallest_rank_p > 0.10, "not testable", fifelse(size_fails(rej10, n, 0.10), "fails", "passes")),
  forward_rejections_05 = sprintf("%d of %d", fwd05, n_fwd), forward_rejections_10 = sprintf("%d of %d", fwd10, n_fwd),
  forward_placebos_min = placebos_forward_min,
  runs_per_effect_size = n * R_DRAWS, smallest_p_simulated = smallest_rank_p,
  mde_decrease_05_pct = label(m_dec_05, smallest_rank_p <= 0.05, size_fails(rej05, n, 0.05)),
  mde_increase_05_pct = label(m_inc_05, smallest_rank_p <= 0.05, size_fails(rej05, n, 0.05)),
  mde_decrease_10_pct = label(m_dec_10, smallest_rank_p <= 0.10, size_fails(rej10, n, 0.10)),
  mde_increase_10_pct = label(m_inc_10, smallest_rank_p <= 0.10, size_fails(rej10, n, 0.10)))]
save_csv(rows, file.path(out, "gradient_rows.csv"))
writeLines(c(capture.output(sessionInfo()), paste("seed", SEED), paste("placebo corridors", P),
             paste("roads sha256", ROADS_SHA256), paste("GEOS, GDAL, PROJ:", paste(sf::sf_extSoftVersion()[c("GEOS", "GDAL", "PROJ")], collapse = ", "))),
           file.path(out, "gradient_session_info.txt"))
print(rows[, .(pool, outcome, donors, fake_effect_mean_pct, null_rejections_05, null_rejections_10,
               mde_decrease_05_pct, mde_increase_05_pct, mde_decrease_10_pct, mde_increase_10_pct)])
