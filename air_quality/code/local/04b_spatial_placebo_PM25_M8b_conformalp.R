#==============================================================================
#  04b_spatial_placebo_PM25_M8b_conformalp.R
#  M8b (AugSynth FE) conformal-p placebo across stations, two windows.
#  (This supersedes all earlier spatial-placebo variants.)
#
#  GOAL: for each of two samples, treat every station in turn against the other
#  seven (canonical pools, Centro included so the p's are comparable), read the
#  NATIVE two-sided conformal p over that sample's post window, and rank stations
#  by it (most significant NEGATIVE effect = rank 1). Hope: Centro is #1.
#
#  Samples:
#    pre_blackout : keep pre-treatment + P1 (drop everything from BLACKOUT_START
#                   onward). Post window = P1. Native conformal p = P1 p.
#    donut        : drop the blackout window [BLACKOUT_START, BLACKOUT_END];
#                   keep pre + P1 + P2. Post window = P1+P2 ("clean"). Week_id is
#                   remapped to contiguous so augsynth sees no time gap.
#
#  Estimator: M8b = AugSynth with unit FE (fixedeff = TRUE), exact M8b augsynth()
#  call (same formula/covariates/progfunc/scm as 04_PM2.5.R). FE-conformal MUST
#  return a p; if it fails for ANY station, the whole sample falls back to no-FE
#  for the p (uniformly, so the ranking is comparable) and the FE point estimate
#  is kept in att_fe_log. Window estimand is the sample's native average_att.
#
#  Unchanged: covariates, ln(pm25_imp), set.seed(12345), t_int, 2x/5x pre-RMSPE
#  filter. Overall (full post) window is NOT computed here (use 04d for that).
#
#  PREREQUISITE: 03 + 04 sourced (PM2.5 state, m8b, BLACKOUT_START/END in memory).
#  Run after 04, before 05. Writes only the _M8b_conformalp set.
#==============================================================================

## ---- 0. Guard ----
.need <- c("df","t_int","WEATHER_VARS","run_augsynth","m8b","ROOT_DIR",
           "BLACKOUT_START","BLACKOUT_END")
.missing <- .need[!vapply(.need, exists, logical(1))]
if (length(.missing) > 0)
  stop("Missing required objects: ", paste(.missing, collapse=", "),
       "\n  Source 03_analysis_setupPM2.5.R and 04_PM2.5.R first, then this script.")
.poll <- if (exists("POLLUTANT")) as.character(POLLUTANT) else NA_character_
if (!identical(.poll, "pm25"))
  stop("In-memory state is not PM2.5 (POLLUTANT='", .poll, "'). Run right after 04_PM2.5.R.")

set.seed(12345)
suppressMessages({ library(dplyr); library(tibble); library(readr); library(augsynth) })

## ---- 1. Stations + distances ----
station_dist <- tibble(
  station          = c("belisario","carapungo","centro","cotocollao",
                       "guamani","loschillos","sanantonio","tumbaco"),
  dist_corridor_km = c(0.768, 7.637, 0.610, 5.212, 4.035, 8.618, 9.558, 16.650))
REFERENCE_STATION <- "centro"
all_stations <- station_dist$station
stopifnot(setequal(all_stations, sort(unique(df$estacion))))

## ---- 2. Build the two samples (panel + sample-specific t_int) ----
make_sample <- function(which_sample) {
  if (which_sample == "pre_blackout") {
    d <- df %>% filter(week_date < BLACKOUT_START)            # truncation, no gap
    list(panel = d, t_int_s = t_int)                          # original week_id/t_int OK
  } else if (which_sample == "donut") {
    d <- df %>% filter(week_date < BLACKOUT_START | week_date > BLACKOUT_END)
    wk <- d %>% distinct(week_date) %>% arrange(week_date) %>% mutate(wid = row_number())
    d <- d %>% left_join(wk, by = "week_date") %>%
      mutate(week_id_orig = week_id, week_id = wid)           # remap to contiguous
    tnew <- d %>% filter(week_id_orig >= t_int) %>% summarise(m = min(week_id)) %>% pull(m)
    list(panel = d, t_int_s = tnew)
  } else stop("bad sample")
}

## ---- 3. One augsynth fit (exact M8b call) + native p + rmspe + weights ----
fit_one <- function(panel, t_int_s, treated_station, donor_stations, use_fe) {
  d <- panel %>% filter(estacion %in% c(treated_station, donor_stations)) %>%
    mutate(.treated = as.integer(estacion == treated_station & week_id >= t_int_s))
  form <- as.formula(paste("ln_outcome ~ .treated |", paste(WEATHER_VARS, collapse = " + ")))
  aug  <- augsynth(form, unit = estacion, time = week_id, data = d, t_int = t_int_s,
                   progfunc = "Ridge", scm = TRUE, fixedeff = use_fe)
  summ <- summary(aug, inf_type = "conformal")
  avg  <- summ$average_att
  # native window estimand + 2-sided conformal p
  att  <- as.numeric(avg$Estimate)
  p2   <- suppressWarnings(as.numeric(avg$p_val))
  # rmspe (same construction as run_augsynth/compute_fit, sample t_int)
  Y_cf <- as.numeric(predict(aug, att = FALSE))
  wks  <- sort(unique(d$week_id))
  tr   <- d %>% filter(estacion == treated_station) %>% arrange(week_id)
  Yobs <- tr$ln_outcome[match(wks, tr$week_id)]
  dff  <- Yobs - Y_cf
  pre  <- wks < t_int_s
  list(att = att, p2 = p2,
       rmspe_pre  = sqrt(mean(dff[pre]^2,  na.rm = TRUE)),
       rmspe_post = sqrt(mean(dff[!pre]^2, na.rm = TRUE)),
       weights = paste(sprintf("%s:%.4f", rownames(aug$weights), as.numeric(aug$weights)),
                       collapse = ";"))
}

valid_p <- function(x) is.finite(x)

## ---- 4. Run one sample: try FE for all 8; if any p invalid, fall back no-FE ----
run_sample <- function(which_sample) {
  s   <- make_sample(which_sample)
  cat(sprintf("\n=== sample=%s (t_int_s=%d, weeks=%d) ===\n",
              which_sample, s$t_int_s, dplyr::n_distinct(s$panel$week_id)))

  fit_all <- function(use_fe) lapply(all_stations, function(st)
    tryCatch(fit_one(s$panel, s$t_int_s, st, setdiff(all_stations, st), use_fe),
             error = function(e) { cat(sprintf("  fit error %s (fe=%s): %s\n", st, use_fe, e$message)); NULL }))

  feL  <- fit_all(TRUE)
  feOK <- all(vapply(feL, function(r) !is.null(r) && valid_p(r$p2), logical(1)))
  if (feOK) {
    primL <- feL; psrc <- "FE"
    feAtt <- vapply(feL, function(r) r$att, numeric(1))
  } else {
    cat("  FE-conformal failed/NA for >=1 station -> falling back to no-FE for the p (uniform).\n")
    noL <- fit_all(FALSE); psrc <- "noFE_fallback"
    primL <- noL
    feAtt <- vapply(feL, function(r) if (!is.null(r)) r$att else NA_real_, numeric(1))
  }

  tib <- tibble(
    sample      = which_sample,
    station     = all_stations,
    att_log     = vapply(primL, function(r) if (is.null(r)) NA_real_ else r$att, numeric(1)),
    conf_p      = vapply(primL, function(r) if (is.null(r)) NA_real_ else r$p2, numeric(1)),
    p_source    = psrc,
    att_fe_log  = feAtt,
    rmspe_pre   = vapply(primL, function(r) if (is.null(r)) NA_real_ else r$rmspe_pre, numeric(1)),
    rmspe_post  = vapply(primL, function(r) if (is.null(r)) NA_real_ else r$rmspe_post, numeric(1)),
    donor_weights = vapply(primL, function(r) if (is.null(r)) NA_character_ else r$weights, character(1))
  ) %>%
    mutate(att_pct = (exp(att_log) - 1) * 100,
           ratio   = rmspe_post / rmspe_pre) %>%
    left_join(station_dist, by = "station")
  tib
}

## ---- 5. Run both samples ----
res <- bind_rows(run_sample("pre_blackout"), run_sample("donut"))

## consistency: rmspe_pre should match across samples (shared pre-period -> same weights)
chk <- res %>% select(sample, station, rmspe_pre) %>%
  tidyr::pivot_wider(names_from = sample, values_from = rmspe_pre) %>%
  mutate(d = abs(pre_blackout - donut))
cat(sprintf("\n[check] max |rmspe_pre(pre_blackout) - rmspe_pre(donut)| = %.2e (should be ~0)\n",
            max(chk$d, na.rm = TRUE)))

## ---- 6. Pre-fit filter (2x/5x on Centro's pre-RMSPE, per sample) ----
res <- res %>% group_by(sample) %>%
  mutate(ref_pre = rmspe_pre[station == REFERENCE_STATION],
         included_2x = rmspe_pre <= 2 * ref_pre,
         included_5x = rmspe_pre <= 5 * ref_pre) %>% ungroup()

## ---- 7. Rank on the two-sided conformal p (most significant NEGATIVE = 1) ----
## Centro rank = # stations that are negative AND have conf_p <= Centro's conf_p.
## (positive-att stations are not "significant negatives" and rank after.)
rank_block <- function(d) {
  cp  <- d$conf_p[d$station == REFERENCE_STATION]
  cneg<- isTRUE(d$att_log[d$station == REFERENCE_STATION] < 0)
  N   <- nrow(d)
  k   <- if (cneg) sum(d$att_log < 0 & d$conf_p <= cp, na.rm = TRUE) else N
  list(p = cp, rank = as.integer(k), N = as.integer(N), pp = k / N)
}
ranks <- lapply(c("pre_blackout","donut"), function(sm) {
  blk2x <- res %>% filter(sample == sm, included_2x)
  rb    <- rank_block(blk2x)
  c(sample = sm, rb)
})

## ---- 8. P2-driven flag: significant (p<0.05) in donut but not pre_blackout ----
SIG <- 0.05
sig_wide <- res %>% mutate(sig = conf_p < SIG & att_log < 0) %>%
  select(sample, station, sig) %>%
  tidyr::pivot_wider(names_from = sample, values_from = sig)
p2_driven <- sig_wide %>% filter(donut & !pre_blackout) %>% pull(station)

## ---- 9. Write ----
out_dir <- file.path(ROOT_DIR, "output", "local", "spatial_placebo")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write_csv(res %>% select(sample, station, dist_corridor_km, att_log, att_pct, conf_p,
                         p_source, att_fe_log, rmspe_pre, rmspe_post, ratio,
                         included_2x, included_5x, donor_weights) %>%
            arrange(sample, conf_p),
          file.path(out_dir, "spatial_placebo_PM25_M8b_conformalp.csv"))

con <- file(file.path(out_dir, "spatial_placebo_PM25_M8b_conformalp_log.txt"), "w")
lines <- c("M8b conformal-p placebo across stations  [windows: pre_blackout=P1, donut=P1+P2]",
           "================================================================",
           "Estimator: AugSynth FE (M8b). Canonical pools (each station vs other 7).",
           "Rank statistic: two-sided conformal p, most significant NEGATIVE = rank 1.",
           sprintf("p_source per sample: %s",
                   paste(unique(res$sample), "=", tapply(res$p_source, res$sample, `[`, 1)[unique(res$sample)],
                         collapse = " | ")),
           "")
for (r in ranks) lines <- c(lines,
  sprintf("[%s] Centro conf_p = %s, rank %d/%d (2x set), spatial-placebo p = %.3f",
          r$sample, ifelse(is.na(r$p),"NA",sprintf("%.4f", r$p)), r$rank, r$N, r$pp))
lines <- c(lines, "",
  sprintf("P2-driven (sig p<%.2f & neg in donut, NOT in pre_blackout): %s",
          SIG, if (length(p2_driven)==0) "none" else paste(p2_driven, collapse=", ")),
  sprintf("Floor: N=8 -> min rank p = 0.125 (corroborative, not significance)."))
writeLines(lines, con); close(con)

cat("\n=== Done. Outputs in", out_dir, "===\n")
print(res %>% select(sample, station, dist_corridor_km, att_pct, conf_p, p_source,
                     ratio, included_2x) %>% arrange(sample, conf_p), n = 16)
for (r in ranks) cat(sprintf("[%s] Centro p=%s rank %d/%d (placebo p=%.3f)\n",
                             r$sample, ifelse(is.na(r$p),"NA",sprintf("%.4f",r$p)), r$rank, r$N, r$pp))
