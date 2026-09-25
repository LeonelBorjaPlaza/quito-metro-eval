#==============================================================================
#  04c_spatial_placebo_PM25_M5b_conformalp.R
#  M5b (AugSynth, NO fixed effects) conformal-p placebo across stations.
#  No-FE twin of 04b. Identical logic; the only change is fixedeff = FALSE.
#
#  GOAL: for each of two samples, treat every station in turn against the other
#  seven (canonical pools, Centro included so the p's are comparable), read the
#  NATIVE two-sided conformal p over that sample's post window, and rank stations
#  by it (most significant NEGATIVE effect = rank 1). Hope: Centro is #1.
#
#  Samples:
#    pre_blackout : keep pre-treatment + P1 (drop everything from BLACKOUT_START
#                   onward). Post window = P1. Native conformal p = P1 p.
#    donut        : drop [BLACKOUT_START, BLACKOUT_END]; keep pre + P1 + P2.
#                   Post window = P1+P2. Week_id remapped to contiguous (no gap).
#
#  Estimator: M5b = AugSynth, NO unit FE (fixedeff = FALSE). Same formula /
#  covariates / progfunc / scm as 04_PM2.5.R's M5b. No-FE conformal returns a p
#  natively, so there is no FE fallback here (unlike 04b). Window estimand is the
#  sample's native average_att; conf_p is its two-sided conformal p.
#
#  Unchanged: covariates, ln(pm25_imp), set.seed(12345), t_int, 2x/5x pre-RMSPE
#  filter. Overall (full post) window is NOT computed here.
#
#  PREREQUISITE: 03 setup objects in memory (df, t_int, WEATHER_VARS,
#  BLACKOUT_START/END, POLLUTANT). These scripts call augsynth() directly, so the
#  full 04 battery is NOT required -- sourcing 03 is enough. Run before 05.
#  Writes only the _M5b_conformalp set.
#==============================================================================

## ---- 0. Guard (03 objects only; 04 not required) ----
.need <- c("df","t_int","WEATHER_VARS","ROOT_DIR","BLACKOUT_START","BLACKOUT_END")
.missing <- .need[!vapply(.need, exists, logical(1))]
if (length(.missing) > 0)
  stop("Missing required objects: ", paste(.missing, collapse=", "),
       "\n  Source 03_analysis_setupPM2.5.R first, then this script.")
.poll <- if (exists("POLLUTANT")) as.character(POLLUTANT) else NA_character_
if (!identical(.poll, "pm25"))
  stop("In-memory state is not PM2.5 (POLLUTANT='", .poll, "'). Source 03_analysis_setupPM2.5.R.")

set.seed(12345)
suppressMessages({ library(dplyr); library(tibble); library(readr); library(tidyr); library(augsynth) })

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
    d <- df %>% filter(week_date < BLACKOUT_START)              # truncation, no gap
    list(panel = d, t_int_s = t_int)
  } else if (which_sample == "donut") {
    d <- df %>% filter(week_date < BLACKOUT_START | week_date > BLACKOUT_END)
    wk <- d %>% distinct(week_date) %>% arrange(week_date) %>% mutate(wid = row_number())
    d <- d %>% left_join(wk, by = "week_date") %>%
      mutate(week_id_orig = week_id, week_id = wid)             # remap to contiguous
    tnew <- d %>% filter(week_id_orig >= t_int) %>% summarise(m = min(week_id)) %>% pull(m)
    list(panel = d, t_int_s = tnew)
  } else stop("bad sample")
}

## ---- 3. One augsynth fit (M5b, no FE) + native p + rmspe + weights ----
fit_one <- function(panel, t_int_s, treated_station, donor_stations) {
  d <- panel %>% filter(estacion %in% c(treated_station, donor_stations)) %>%
    mutate(.treated = as.integer(estacion == treated_station & week_id >= t_int_s))
  form <- as.formula(paste("ln_outcome ~ .treated |", paste(WEATHER_VARS, collapse = " + ")))
  aug  <- augsynth(form, unit = estacion, time = week_id, data = d, t_int = t_int_s,
                   progfunc = "Ridge", scm = TRUE, fixedeff = FALSE)   # M5b: no FE
  summ <- summary(aug, inf_type = "conformal")
  avg  <- summ$average_att
  att  <- as.numeric(avg$Estimate)
  p2   <- suppressWarnings(as.numeric(avg$p_val))
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

## ---- 4. Run one sample (all 8 stations, no-FE) ----
run_sample <- function(which_sample) {
  s <- make_sample(which_sample)
  cat(sprintf("\n=== sample=%s (t_int_s=%d, weeks=%d) ===\n",
              which_sample, s$t_int_s, dplyr::n_distinct(s$panel$week_id)))
  L <- lapply(all_stations, function(st)
    tryCatch(fit_one(s$panel, s$t_int_s, st, setdiff(all_stations, st)),
             error = function(e) { cat(sprintf("  fit error %s: %s\n", st, e$message)); NULL }))
  tibble(
    sample   = which_sample,
    station  = all_stations,
    att_log  = vapply(L, function(r) if (is.null(r)) NA_real_ else r$att, numeric(1)),
    conf_p   = vapply(L, function(r) if (is.null(r)) NA_real_ else r$p2, numeric(1)),
    p_source = "noFE",
    rmspe_pre  = vapply(L, function(r) if (is.null(r)) NA_real_ else r$rmspe_pre, numeric(1)),
    rmspe_post = vapply(L, function(r) if (is.null(r)) NA_real_ else r$rmspe_post, numeric(1)),
    donor_weights = vapply(L, function(r) if (is.null(r)) NA_character_ else r$weights, character(1))
  ) %>%
    mutate(att_pct = (exp(att_log) - 1) * 100, ratio = rmspe_post / rmspe_pre) %>%
    left_join(station_dist, by = "station")
}

## ---- 5. Run both samples ----
res <- bind_rows(run_sample("pre_blackout"), run_sample("donut"))

## consistency: rmspe_pre should match across samples (shared pre-period)
chk <- res %>% select(sample, station, rmspe_pre) %>%
  pivot_wider(names_from = sample, values_from = rmspe_pre) %>%
  mutate(d = abs(pre_blackout - donut))
cat(sprintf("\n[check] max |rmspe_pre(pre_blackout) - rmspe_pre(donut)| = %.2e (should be ~0)\n",
            max(chk$d, na.rm = TRUE)))

## ---- 6. Pre-fit filter (2x/5x on Centro's pre-RMSPE, per sample) ----
res <- res %>% group_by(sample) %>%
  mutate(ref_pre = rmspe_pre[station == REFERENCE_STATION],
         included_2x = rmspe_pre <= 2 * ref_pre,
         included_5x = rmspe_pre <= 5 * ref_pre) %>% ungroup()

## ---- 7. Rank on the two-sided conformal p (most significant NEGATIVE = 1) ----
rank_block <- function(d) {
  cp   <- d$conf_p[d$station == REFERENCE_STATION]
  cneg <- isTRUE(d$att_log[d$station == REFERENCE_STATION] < 0)
  N    <- nrow(d)
  k    <- if (cneg) sum(d$att_log < 0 & d$conf_p <= cp, na.rm = TRUE) else N
  list(p = cp, rank = as.integer(k), N = as.integer(N), pp = k / N)
}
ranks <- lapply(c("pre_blackout","donut"), function(sm) {
  rb <- rank_block(res %>% filter(sample == sm, included_2x)); c(sample = sm, rb)
})

## ---- 8. P2-driven flag: significant (p<0.05 & negative) in donut but not pre_blackout ----
SIG <- 0.05
sig_wide <- res %>% mutate(sig = conf_p < SIG & att_log < 0) %>%
  select(sample, station, sig) %>% pivot_wider(names_from = sample, values_from = sig)
p2_driven <- sig_wide %>% filter(donut & !pre_blackout) %>% pull(station)

## ---- 9. Write ----
out_dir <- file.path(ROOT_DIR, "output", "local", "spatial_placebo")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write_csv(res %>% select(sample, station, dist_corridor_km, att_log, att_pct, conf_p,
                         p_source, rmspe_pre, rmspe_post, ratio,
                         included_2x, included_5x, donor_weights) %>%
            arrange(sample, conf_p),
          file.path(out_dir, "spatial_placebo_PM25_M5b_conformalp.csv"))

con <- file(file.path(out_dir, "spatial_placebo_PM25_M5b_conformalp_log.txt"), "w")
lines <- c("M5b conformal-p placebo across stations  [windows: pre_blackout=P1, donut=P1+P2]",
           "================================================================",
           "Estimator: AugSynth NO FE (M5b). Canonical pools (each station vs other 7).",
           "Rank statistic: two-sided conformal p, most significant NEGATIVE = rank 1.",
           "")
for (r in ranks) lines <- c(lines,
  sprintf("[%s] Centro conf_p = %s, rank %d/%d (2x set), spatial-placebo p = %.3f",
          r$sample, ifelse(is.na(r$p),"NA",sprintf("%.4f", r$p)), r$rank, r$N, r$pp))
lines <- c(lines, "",
  sprintf("P2-driven (sig p<%.2f & neg in donut, NOT in pre_blackout): %s",
          SIG, if (length(p2_driven)==0) "none" else paste(p2_driven, collapse=", ")),
  "Floor: N=8 -> min rank p = 0.125 (corroborative, not significance).")
writeLines(lines, con); close(con)

cat("\n=== Done. Outputs in", out_dir, "===\n")
print(res %>% select(sample, station, dist_corridor_km, att_pct, conf_p, p_source,
                     ratio, included_2x) %>% arrange(sample, conf_p), n = 16)
for (r in ranks) cat(sprintf("[%s] Centro p=%s rank %d/%d (placebo p=%.3f)\n",
                             r$sample, ifelse(is.na(r$p),"NA",sprintf("%.4f",r$p)), r$rank, r$N, r$pp))
