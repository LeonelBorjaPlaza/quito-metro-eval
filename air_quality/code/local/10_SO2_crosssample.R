#==============================================================================
#  10_SO2_crosssample.R   (TEMPLATE)
#  Restructured local SO2 estimation: every spec is RE-ESTIMATED separately
#  on each sample (full / donut / pre_blackout), matching the satellite
#  architecture. No more slicing one full-post weekly ATT vector into sub-period
#  means -- each sample carries its own native, window-correct inference.
#
#  Samples (keyed off blackout_week_ids from the 03 setup):
#    full         : all post weeks.
#    donut        : drop blackout_week_ids (keep P1 + P2). week_id remapped.
#    pre_blackout : keep week_date < BLACKOUT_START (drop blackout + P2 -> post = P1).
#
#  Estimators (the existing 12-spec battery, unchanged):
#    SDID (residualized ln_outcome_adj) | AugSynth no-FE | AugSynth FE,
#    each x {Centro+Belisario, Centro(Bel dropped), Centro(Bel in pool), Belisario}.
#  All AugSynth = Ridge-augmented (progfunc="Ridge", scm=TRUE); FE adds fixedeff=TRUE.
#
#  Inference, per sample, procedures unchanged:
#    AugSynth : native two-sided conformal p over the sample's post window
#               (1-sided computed only when ATT<0, as before). CI: augsynth does
#               NOT return a conformal CI for the average effect -> ci_lo/ci_hi NA
#               (flagged). SDID : synthdid estimate; CI = att +-1.96*placebo-SE
#               (300 reps); p = local_placebo_p permutation rank (NA for co-treated).
#
#  Expectations (built-in, self-contained checks below -- NO old 04 needed):
#    - AugSynth point estimates DON'T move: pre_blackout ATT == full-sample
#      weekly ATT averaged over the same P1 weeks (check a); rmspe_pre identical
#      across samples (check b).
#    - SDID estimates DO move per sample (time weights depend on post weeks).
#
#  DO NOT CHANGE (intact): covariates, ln(so2_imp), donor structure, headline
#  specs, set.seed(12345), t_int, 2x/5x pre-fit thresholds. Only the
#  sample-by-sample estimation structure changes.
#
#  NOTE: self-contained template. Once validated, the fit_* helpers move to
#  00_local_sample_helpers.R and CO/NO2/SO2 get thin runners that reuse them.
#  PREREQUISITE: 09_analysis_setupSO2.R sourced (df with ln_outcome &
#  ln_outcome_adj, t_int, WEATHER_VARS, blackout_week_ids, BLACKOUT_START,
#  ROOT_DIR). The OLD 10 is NOT required and need not be rerun: this script is
#  self-validating via checks (a) + (b). If m5b/m8b happen to already be in
#  memory, an optional one-time tie-out (check c) also prints.
#==============================================================================

## ---- 0. Guard ----
.need <- c("df","t_int","WEATHER_VARS","blackout_week_ids","BLACKOUT_START","ROOT_DIR")
.miss <- .need[!vapply(.need, exists, logical(1))]
if (length(.miss) > 0) stop("Missing: ", paste(.miss, collapse=", "),
                            "\n  Source 09_analysis_setupSO2.R first.")
if (!all(c("ln_outcome","ln_outcome_adj") %in% names(df)))
  stop("df must contain ln_outcome and ln_outcome_adj (from 09 setup).")
if (!identical(if (exists("POLLUTANT")) as.character(POLLUTANT) else "", "so2"))
  stop("In-memory state is not SO2. Source 09_analysis_setupSO2.R.")

set.seed(12345)
suppressMessages({ library(dplyr); library(tibble); library(tidyr); library(readr)
                   library(augsynth); library(synthdid) })

POLL <- "so2"

## ---- 1. Build the three samples (panel + sample-specific t_int) ----
make_samples <- function() {
  ti <- as.integer(t_int)
  full <- list(name = "full", panel = df, t_int_s = ti)
  dn <- df %>% filter(!week_id %in% blackout_week_ids)
  wk <- dn %>% distinct(week_date) %>% arrange(week_date) %>% mutate(wid = row_number())
  dn <- dn %>% left_join(wk, by = "week_date") %>% mutate(week_id = wid, week_id_orig = wid)
  # remap: keep mapping from original ids
  map <- df %>% filter(!week_id %in% blackout_week_ids) %>% distinct(week_id, week_date) %>%
    arrange(week_date) %>% mutate(wid = row_number())
  dn <- df %>% filter(!week_id %in% blackout_week_ids) %>%
    left_join(map %>% select(week_date, wid), by = "week_date") %>%
    mutate(week_id_orig = week_id, week_id = wid)
  t_dn <- dn %>% filter(week_id_orig >= t_int) %>% summarise(m = min(week_id)) %>% pull(m)
  donut <- list(name = "donut", panel = dn, t_int_s = as.integer(t_dn))
  pb <- df %>% filter(week_date < BLACKOUT_START)
  preb <- list(name = "pre_blackout", panel = pb, t_int_s = ti)
  list(full, donut, preb)
}

## ---- 2. Permutation p for local SDID (verbatim from 10_SO2.R) ----
local_placebo_p <- function(Y, N0, T0) {
  est_one <- function(M, n0, t0) as.numeric(synthdid_estimate(M, n0, t0))
  att_real <- est_one(Y, N0, T0)
  placebo <- rep(NA_real_, N0)
  for (j in seq_len(N0)) {
    ctrl <- setdiff(seq_len(N0), j)
    Yj <- Y[c(ctrl, j), , drop = FALSE]
    placebo[j] <- tryCatch(est_one(Yj, N0 - 1L, T0), error = function(e) NA_real_)
  }
  pa <- placebo[is.finite(placebo)]; n <- length(pa)
  list(p_1s = if (att_real < 0) (1 + sum(pa <= att_real)) / (1 + n) else NA_real_,
       p_2s = (1 + sum(abs(pa) >= abs(att_real))) / (1 + n), n_placebo = n)
}

## ---- 3. AugSynth fit for one (sample, spec) -> native window inference ----
fit_aug <- function(panel, t_int_s, treated_set, exclude, use_fe) {
  d <- panel; if (!is.na(exclude)) d <- d %>% filter(estacion != exclude)
  d <- d %>% mutate(.treated = as.integer(estacion %in% treated_set & week_id >= t_int_s))
  form <- as.formula(paste("ln_outcome ~ .treated |", paste(WEATHER_VARS, collapse = " + ")))
  aug  <- augsynth(form, unit = estacion, time = week_id, data = d, t_int = t_int_s,
                   progfunc = "Ridge", scm = TRUE, fixedeff = use_fe)
  summ <- summary(aug, inf_type = "conformal")
  att  <- as.numeric(summ$average_att$Estimate)
  p2   <- suppressWarnings(as.numeric(summ$average_att$p_val))
  p1   <- if (!is.na(att) && att < 0)
    suppressWarnings(as.numeric(summary(aug, inf_type = "conformal",
                                        stat_func = function(x) -sum(x))$average_att$p_val))
  else NA_real_
  Y_cf <- as.numeric(predict(aug, att = FALSE))
  wks  <- sort(unique(d$week_id))
  tu   <- d %>% filter(estacion %in% treated_set) %>% group_by(week_id) %>%
    summarise(y = mean(ln_outcome, na.rm = TRUE), .groups = "drop")
  dff  <- tu$y[match(wks, tu$week_id)] - Y_cf
  pre  <- wks < t_int_s
  list(att = att, p2 = p2, p1 = p1, ci_lo = NA_real_, ci_hi = NA_real_,
       rmspe_pre = sqrt(mean(dff[pre]^2, na.rm = TRUE)),
       rmspe_post = sqrt(mean(dff[!pre]^2, na.rm = TRUE)), n_placebo = NA_integer_,
       wks = wks, wk_att = dff,
       weights = paste(sprintf("%s:%.4f", rownames(aug$weights), as.numeric(aug$weights)),
                       collapse = ";"))
}

## ---- 4. SDID fit for one (sample, spec) ----
fit_sdid <- function(panel, t_int_s, treated_set, exclude, multi) {
  d <- panel; if (!is.na(exclude)) d <- d %>% filter(estacion != exclude)
  d <- d %>% mutate(.treated = as.integer(estacion %in% treated_set & week_id >= t_int_s))
  dp <- d %>% select(estacion, week_id, ln_outcome_adj, .treated) %>%
    rename(treated = .treated) %>% arrange(estacion, week_id) %>% as.data.frame()
  pm  <- panel.matrices(dp, outcome = "ln_outcome_adj")
  est <- synthdid_estimate(pm$Y, pm$N0, pm$T0)
  se  <- as.numeric(sqrt(vcov(est, method = "placebo", replications = 300)))
  att <- as.numeric(est)
  if (multi) { p1 <- NA_real_; p2 <- NA_real_; np <- NA_integer_ }
  else { pp <- local_placebo_p(pm$Y, pm$N0, pm$T0); p1 <- pp$p_1s; p2 <- pp$p_2s; np <- pp$n_placebo }
  omega <- attr(est, "weights")$omega
  Y_tr  <- if (multi) colMeans(pm$Y[(pm$N0+1):nrow(pm$Y), , drop = FALSE]) else pm$Y[nrow(pm$Y), ]
  Y_syn <- colSums(omega * pm$Y[1:pm$N0, ])
  dff   <- Y_tr - Y_syn; post <- seq_along(Y_tr) > pm$T0
  # NOTE: ci_lo/ci_hi are a Wald (att +- 1.96*se) interval and are NOT part of the
  #   analysis -- do not use them for inference. With ~6 donors the placebo
  #   distribution has finite support and cannot justify Gaussian tails (same reason
  #   local_placebo_p exists; see also the original 04 comment). Computed for
  #   completeness only; the reported SDID inference is the permutation p. Flagged
  #   in the output as ci_type = "wald_se_NOT_USED_in_analysis".
  #   TODO(someday): drop, or replace with a permutation/placebo-based interval.
  list(att = att, p2 = p2, p1 = p1, ci_lo = att - 1.96*se, ci_hi = att + 1.96*se,
       rmspe_pre = sqrt(mean(dff[!post]^2)), rmspe_post = sqrt(mean(dff[post]^2)),
       n_placebo = np,
       weights = paste(sprintf("%s:%.4f", rownames(pm$Y)[1:pm$N0], as.numeric(omega)),
                       collapse = ";"))
}

## ---- 5. Spec battery (the existing 12) ----
specs <- tribble(
  ~spec, ~method,   ~treated,            ~exclude,    ~multi,
  "M1",  "SDID",    "centro,belisario",  NA,          TRUE,
  "M2",  "SDID",    "centro",            "belisario", FALSE,
  "M2b", "SDID",    "centro",            NA,          FALSE,
  "M3",  "SDID",    "belisario",         "centro",    FALSE,
  "M4",  "AugNoFE", "centro,belisario",  NA,          TRUE,
  "M5",  "AugNoFE", "centro",            "belisario", FALSE,
  "M5b", "AugNoFE", "centro",            NA,          FALSE,
  "M6",  "AugNoFE", "belisario",         "centro",    FALSE,
  "M7",  "AugFE",   "centro,belisario",  NA,          TRUE,
  "M8",  "AugFE",   "centro",            "belisario", FALSE,
  "M8b", "AugFE",   "centro",            NA,          FALSE,
  "M9",  "AugFE",   "belisario",         "centro",    FALSE
)

## ---- 6. Run every (spec x sample) ----
samples <- make_samples()
cat(sprintf("Samples: %s\n", paste(sprintf("%s(t_int=%d,wk=%d)",
   vapply(samples, `[[`, "", "name"),
   vapply(samples, `[[`, 0L, "t_int_s"),
   vapply(samples, function(s) dplyr::n_distinct(s$panel$week_id), 0L)), collapse=" | ")))

rows <- list(); full_wk <- list()
for (i in seq_len(nrow(specs))) {
  sp <- specs[i, ]; tset <- strsplit(sp$treated, ",")[[1]]
  for (smp in samples) {
    f <- tryCatch({
      if (sp$method == "SDID") fit_sdid(smp$panel, smp$t_int_s, tset, sp$exclude, sp$multi)
      else fit_aug(smp$panel, smp$t_int_s, tset, sp$exclude, use_fe = (sp$method == "AugFE"))
    }, error = function(e) { cat(sprintf("  ERR %s/%s: %s\n", sp$spec, smp$name, e$message)); NULL })
    if (is.null(f)) next
    if (smp$name == "full" && sp$method != "SDID")
      full_wk[[sp$spec]] <- list(wks = f$wks, att = f$wk_att)
    rows[[length(rows)+1]] <- tibble(
      pollutant = POLL, spec = sp$spec, method = sp$method, sample = smp$name,
      att_log = f$att, att_pct = (exp(f$att)-1)*100,
      p_2s = f$p2, p_1s = f$p1,
      p_type   = if (sp$method=="SDID") "permutation" else "conformal",
      ci_lo = f$ci_lo, ci_hi = f$ci_hi,
      ci_type  = if (sp$method=="SDID") "wald_se_NOT_USED_in_analysis" else "conformal_avg_CI_unavailable(NA)",
      rmspe_pre = f$rmspe_pre, rmspe_post = f$rmspe_post, ratio = f$rmspe_post/f$rmspe_pre,
      n_placebo = f$n_placebo, donor_weights = f$weights)
  }
}
cross <- bind_rows(rows)

## ---- 7. Pre-fit filter (2x/5x on the Centro reference, per sample) ----
cross <- cross %>% group_by(sample) %>%
  mutate(ref_pre = rmspe_pre[spec == "M5b"],     # Centro no-FE pool = M5b reference
         included_2x = rmspe_pre <= 2 * ref_pre,
         included_5x = rmspe_pre <= 5 * ref_pre) %>% ungroup() %>% select(-ref_pre)

## ---- 8. FAITHFULNESS CHECKS (self-contained: NO old 04 required) ----
cat("\n--- checks ---\n")
# P1 week ids in the full panel (post weeks before the blackout)
p1_ids_full <- df %>% filter(week_id >= t_int, week_date < BLACKOUT_START) %>%
  distinct(week_id) %>% pull(week_id)

# (a) Core property: AugSynth point estimate is window-invariant. pre_blackout ATT
#     (native average over P1) must equal the full-sample weekly ATT averaged over
#     the SAME P1 weeks. Proves the restructure changed inference, not the estimate.
cat("  [check a] pre_blackout ATT == full-sample weekly ATT over P1 (AugSynth):\n")
maxd_a <- 0
for (lab in names(full_wk)) {
  wa <- full_wk[[lab]]
  m_full_p1 <- mean(wa$att[wa$wks %in% p1_ids_full], na.rm = TRUE)
  a_pre <- cross$att_log[cross$spec == lab & cross$sample == "pre_blackout"]
  if (length(a_pre) == 1) {
    d <- abs(m_full_p1 - a_pre); maxd_a <- max(maxd_a, d)
    cat(sprintf("      %-4s full-over-P1 %+.6f vs pre_blackout %+.6f (|diff|=%.2e)\n",
                lab, m_full_p1, a_pre, d))
  }
}
cat(sprintf("      -> max |diff| = %.2e (should be ~0)\n", maxd_a))

# (b) AugSynth rmspe_pre invariant across samples (weights pre-fit); SDID may vary
inv <- cross %>% filter(method != "SDID") %>% group_by(spec) %>%
  summarise(spread = max(rmspe_pre) - min(rmspe_pre), .groups = "drop")
cat(sprintf("  [check b] max AugSynth rmspe_pre spread across samples = %.2e (should be ~0)\n",
            max(inv$spread, na.rm = TRUE)))

# (c) OPTIONAL one-time tie-out to legacy 10 -- runs ONLY if m5b/m8b are already in
#     memory. Not required and not rerun: (a)+(b) self-validate this script.
chk_legacy <- function(spec_lab, obj_name) {
  if (!exists(obj_name)) return(invisible())
  a_new <- cross$att_log[cross$spec == spec_lab & cross$sample == "full"]
  a_old <- as.numeric(get(obj_name)$att_overall)
  cat(sprintf("  [check c] %s full %+.6f vs legacy %s$att_overall %+.6f (|diff|=%.2e)\n",
              spec_lab, a_new, obj_name, a_old, abs(a_new - a_old)))
}
chk_legacy("M5b", "m5b"); chk_legacy("M8b", "m8b")

## ---- 9. Write CrossSample_Summary ----
out_dir <- file.path(ROOT_DIR, "output", "local", "crosssample")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
cross <- cross %>% arrange(match(method, c("AugNoFE","AugFE","SDID")), spec,
                           match(sample, c("pre_blackout","donut","full")))
write_csv(cross, file.path(out_dir, sprintf("CrossSample_Summary_%s.csv", toupper(POLL))))
cat(sprintf("\n[saved] %s\n", file.path(out_dir, sprintf("CrossSample_Summary_%s.csv", toupper(POLL)))))

## headline view (Centro specs, per-sample ATT% and p side by side)
headline <- cross %>% filter(spec %in% c("M2b","M5b","M8b")) %>%
  select(spec, method, sample, att_pct, p_2s) %>%
  pivot_wider(names_from = sample, values_from = c(att_pct, p_2s))
print(headline)
cat("\n=== done (SO2 cross-sample) ===\n")
