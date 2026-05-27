#=========================================================
#  04_models.R
#  Full model battery for local air quality analysis
#
#  12 models = 4 treatment configs x 3 methods
#
#  Treatment configurations:
#    Centro + Belisario co-treated         (M1, M4, M7)
#    Centro only, Belisario dropped        (M2, M5, M8)
#    Centro only, Belisario in donor pool  (M2b, M5b, M8b)
#    Belisario only, Centro dropped        (M3, M6, M9)
#
#  Methods:
#    SDID  (residualized, donut panel)     (M1, M2, M2b, M3)
#    AugSynth (covariates, full panel)     (M4, M5, M5b, M6)
#    AugSynth FE (+ unit FE, full panel)   (M7, M8, M8b, M9)
#
#  ATT vector indexed by raw week_id.
#  Sub-period ATTs = mean of att_vec[week_ids].
#  Inference: conformal, 1-sided and 2-sided.
#
#  Assumes 03_analysis_setup.R has been sourced.
#  Output: console + device only.
#=========================================================


#=========================================================
#  HELPER: Run AugSynth
#=========================================================

run_augsynth <- function(df_input, treatment_var, model_label,
                         exclude_station = NULL, use_fe = FALSE) {

  cat(sprintf("\n%s\n  %s\n%s\n",
              strrep("=", 60), model_label, strrep("=", 60)))

  df_m <- df_input
  if (!is.null(exclude_station)) {
    df_m <- df_m %>% filter(estacion != exclude_station)
  }

  df_m <- df_m %>% mutate(.treated = .data[[treatment_var]])

  rhs <- paste(WEATHER_VARS, collapse = " + ")
  form <- as.formula(paste("ln_outcome ~ .treated |", rhs))

  aug <- augsynth(form,
                  unit = estacion, time = week_id, data = df_m,
                  t_int = t_int, progfunc = "Ridge", scm = TRUE,
                  fixedeff = use_fe)

  # ---- ATT table: 1 row per panel week, indexed by week_id ----
  summ_2s <- summary(aug, inf_type = "conformal")
  att_tbl <- summ_2s$att
  att_vec <- att_tbl$Estimate  # length = total panel weeks
  
  # ---- Sub-period ATTs ----
  att_overall <- mean(att_vec[all_post_ids])
  att_clean   <- mean(att_vec[clean_post_ids])
  att_p1      <- mean(att_vec[p1_ids])
  att_p2      <- if (length(p2_ids) > 0) mean(att_vec[p2_ids]) else NA
  att_bo      <- if (length(blackout_ids) > 0) mean(att_vec[blackout_ids]) else NA
  
  # ---- P-values: 2-sided always; 1-sided only if overall ATT is negative
  #               (pre-specified pollution reduction hypothesis) ----
  p_2s <- summ_2s$average_att$p_val
  if (att_overall < 0) {
    summ_1s <- summary(aug, inf_type = "conformal",
                       stat_func = function(x) -sum(x))
    p_1s <- summ_1s$average_att$p_val
  } else {
    p_1s <- NA_real_
  }

  # Sub-period: share of weeks with individual p < 0.10
  sig_share <- function(ids) {
    pv <- att_tbl$p_val[ids]
    pv <- pv[!is.na(pv)]
    if (length(pv) == 0) return(NA)
    mean(pv < 0.10)
  }

  method_label <- ifelse(use_fe, "AugSynth_FE", "AugSynth")

  # ---- Print ----
  cat(sprintf("\n%-25s  %8s  %8s  %5s\n", "", "ATT", "Pct", "sig%"))
  cat(sprintf("%-25s  %8.4f  %7.1f%%  %4.0f%%\n", "Overall",
              att_overall, (exp(att_overall) - 1) * 100, 100 * sig_share(all_post_ids)))
  cat(sprintf("%-25s  %8.4f  %7.1f%%  %4.0f%%\n", "Clean (non-blackout)",
              att_clean, (exp(att_clean) - 1) * 100, 100 * sig_share(clean_post_ids)))
  cat(sprintf("%-25s  %8.4f  %7.1f%%  %4.0f%%\n", "Period 1",
              att_p1, (exp(att_p1) - 1) * 100, 100 * sig_share(p1_ids)))
  if (!is.na(att_bo)) {
    cat(sprintf("%-25s  %8.4f  %7.1f%%  %5s\n", "Blackout",
                att_bo, (exp(att_bo) - 1) * 100, "--"))
  }
  if (!is.na(att_p2)) {
    cat(sprintf("%-25s  %8.4f  %7.1f%%  %4.0f%%\n", "Period 2",
                att_p2, (exp(att_p2) - 1) * 100, 100 * sig_share(p2_ids)))
  }
  cat(sprintf("\np-value: %s (1-sided), %.4f (2-sided)\n",               ifelse(is.na(p_1s), "  --  ", sprintf("%.4f", p_1s)), p_2s))
  cat(sprintf("L2 imbalance: %.4f (scaled: %.4f, improvement: %.1f%%)\n",
              summ_2s$l2_imbalance, summ_2s$scaled_l2_imbalance,
              100 * (1 - summ_2s$scaled_l2_imbalance)))

  # ---- Weights ----
  omega_df <- tibble(estacion = rownames(aug$weights),
                     weight = as.numeric(aug$weights)) %>%
    arrange(desc(abs(weight)))
  cat("\nDonor weights:\n")
  print(omega_df)

  # ---- Trajectory ----
  Y_cf <- as.numeric(predict(aug, att = FALSE))
  treated_units <- df_m %>% filter(.treated == 1) %>% pull(estacion) %>% unique()
  treated_avg <- df_m %>%
    filter(estacion %in% treated_units) %>%
    group_by(week_id) %>%
    summarise(ln_outcome = mean(ln_outcome, na.rm = TRUE),
              week_label = first(week_label),
              week_date  = first(week_date),
              .groups = "drop")

  traj <- tibble(week_id = sort(unique(df_m$week_id)),
                 Y_synthetic = Y_cf) %>%
    left_join(treated_avg, by = "week_id") %>%
    mutate(Y_treated = ln_outcome,
           difference = Y_treated - Y_synthetic,
           post_period = week_id >= t_int)

  att_df <- att_tbl %>%
    as.data.frame() %>%
    rename(time = Time, estimate = Estimate,
           ci_lower = lower_bound, ci_upper = upper_bound)

  list(label = model_label, method = method_label,
       att_overall = att_overall, att_clean = att_clean,
       att_p1 = att_p1, att_p2 = att_p2, att_bo = att_bo,
       pct_overall = (exp(att_overall) - 1) * 100,
       pct_clean = (exp(att_clean) - 1) * 100,
       pct_p1 = (exp(att_p1) - 1) * 100,
       pct_p2 = if (!is.na(att_p2)) (exp(att_p2) - 1) * 100 else NA,
       p_1s = p_1s, p_2s = p_2s,
       l2 = summ_2s$l2_imbalance,
       l2_scaled = summ_2s$scaled_l2_imbalance,
       traj = traj, att_df = att_df, omega = omega_df,
       aug_obj = aug)
}


#=========================================================
#  HELPER: Run SDID
#=========================================================
#=========================================================
#  HELPER: permutation p-value for local SDID
#=========================================================
#  The Wald p-value (pnorm of att/se) is invalid for the local design:
#  with a donor pool this small the placebo distribution has finite
#  support and cannot justify Gaussian tails. This builds the placebo
#  distribution of ATTs (each donor station in turn as placebo-treated)
#  and returns a rank-based p-value. The smallest p the design can
#  return is 1/(N0 + 1); n_placebo reports N0 so that floor is explicit.
#  Single-treated specs only; co-treated specs return NA.
local_placebo_p <- function(Y, N0, T0) {
  est_one  <- function(M, n0, t0) as.numeric(synthdid_estimate(M, n0, t0))
  att_real <- est_one(Y, N0, T0)
  placebo  <- rep(NA_real_, N0)
  for (j in seq_len(N0)) {
    ctrl <- setdiff(seq_len(N0), j)        # N0 - 1 controls
    Yj   <- Y[c(ctrl, j), , drop = FALSE]  # donor j placebo-treated, real treated dropped
    placebo[j] <- tryCatch(est_one(Yj, N0 - 1L, T0),
                           error = function(e) NA_real_)
  }
  pa <- placebo[is.finite(placebo)]
  n  <- length(pa)
  list(
    p_1s      = if (att_real < 0) (1 + sum(pa <= att_real)) / (1 + n) else NA_real_,
    p_2s      = (1 + sum(abs(pa) >= abs(att_real))) / (1 + n),
    n_placebo = n
  )
}

run_sdid <- function(df_input, treatment_var, model_label,
                     exclude_station = NULL, multi_treated = FALSE) {

  cat(sprintf("\n%s\n  %s\n%s\n",
              strrep("=", 60), model_label, strrep("=", 60)))

  df_m <- df_input
  if (!is.null(exclude_station)) {
    df_m <- df_m %>% filter(estacion != exclude_station)
  }

  df_panel <- df_m %>%
    select(estacion, week_id, ln_outcome_adj, all_of(treatment_var)) %>%
    rename(treated = !!treatment_var) %>%
    arrange(estacion, week_id) %>%
    as.data.frame()

  pm <- panel.matrices(df_panel, outcome = "ln_outcome_adj")
  est <- synthdid_estimate(pm$Y, pm$N0, pm$T0)
  se  <- sqrt(vcov(est, method = "placebo", replications = 300))

  att <- as.numeric(est)
  pct <- (exp(att) - 1) * 100
  
  # Inference: permutation (placebo) test over donor stations.
  if (multi_treated) {
    p_1s <- NA_real_; p_2s <- NA_real_; n_placebo <- NA_integer_
    cat("  (co-treated spec: permutation p not computed)\n")
  } else {
    perm      <- local_placebo_p(pm$Y, pm$N0, pm$T0)
    p_1s      <- perm$p_1s
    p_2s      <- perm$p_2s
    n_placebo <- perm$n_placebo
  }
  
  cat(sprintf("ATT: %.4f (%.1f%%), SE: %.4f\n", att, pct, se))
  cat(sprintf("95%% CI: (%.4f, %.4f)\n", att - 1.96*se, att + 1.96*se))
  cat(sprintf("p-value: %s (1-sided), %s (2-sided)  [perm, N0=%s]\n",
              ifelse(is.na(p_1s), "  --  ", sprintf("%.4f", p_1s)),
              ifelse(is.na(p_2s), "  --  ", sprintf("%.4f", p_2s)),
              ifelse(is.na(n_placebo), "--", as.character(n_placebo))))

  # Trajectory
  omega <- attr(est, "weights")$omega
  if (multi_treated) {
    Y_tr <- colMeans(pm$Y[(pm$N0 + 1):nrow(pm$Y), , drop = FALSE])
  } else {
    Y_tr <- pm$Y[nrow(pm$Y), ]
  }
  Y_syn <- colSums(omega * pm$Y[1:pm$N0, ])

  traj <- tibble(
    week_id = 1:length(Y_tr),
    Y_treated = Y_tr, Y_synthetic = Y_syn,
    difference = Y_tr - Y_syn,
    post_period = week_id > pm$T0
  ) %>%
    left_join(df_m %>% distinct(week_id, week_label), by = "week_id")

  omega_df <- tibble(
    estacion = rownames(pm$Y)[1:pm$N0],
    weight = as.numeric(omega)[1:pm$N0]
  ) %>% arrange(desc(abs(weight)))
  cat("Donor weights:\n")
  print(omega_df)

  list(label = model_label, method = "SDID",
       att = att, pct = pct, se = se,
       ci_lo = att - 1.96*se, ci_hi = att + 1.96*se,
       p_1s = p_1s, p_2s = p_2s, n_placebo = n_placebo,
       traj = traj, omega = omega_df, T0 = pm$T0)
}


#=========================================================
#  HELPER: Event study plot
#=========================================================

plot_event_study <- function(result) {

  if (result$method == "SDID") {
    traj <- result$traj %>% mutate(event_time = week_id - result$T0)
    att_mean <- mean(traj$difference[traj$post_period], na.rm = TRUE)

    p <- ggplot(traj, aes(x = event_time, y = difference)) +
      geom_line(color = COL_OBS, linewidth = 0.8) +
      geom_hline(yintercept = 0, color = "gray50", linewidth = 0.5) +
      geom_hline(yintercept = att_mean, linetype = "dashed",
                 color = COL_SYNTH, linewidth = 0.8) +
      geom_vline(xintercept = 0, linetype = "dashed",
                 color = COL_LINE, linewidth = 0.8) +
      annotate("text", x = max(traj$event_time) - 2, y = att_mean,
               label = sprintf("ATT = %.3f (%.1f%%)", result$att, result$pct),
               hjust = 1, vjust = -0.8, size = 3.5, color = COL_SYNTH) +
      labs(x = "Weeks relative to Metro opening",
           y = "Obs - Synth (adjusted)",
           subtitle = result$label) +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank())

  } else {
    traj <- result$traj %>% mutate(event_time = week_id - t_int)
    traj <- traj %>%
      left_join(result$att_df, by = c("week_id" = "time"))

    bo_events <- traj %>% filter(week_id %in% blackout_ids) %>% pull(event_time)

    p <- ggplot(traj, aes(x = event_time, y = difference)) +
      geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
                  alpha = 0.15, fill = COL_OBS, na.rm = TRUE) +
      geom_line(color = COL_OBS, linewidth = 0.8) +
      geom_hline(yintercept = 0, color = "gray50", linewidth = 0.5) +
      geom_vline(xintercept = 0, linetype = "dashed",
                 color = COL_LINE, linewidth = 0.8)

    if (length(bo_events) > 0) {
      p <- p + annotate("rect",
                        xmin = min(bo_events) - 0.5,
                        xmax = max(bo_events) + 0.5,
                        ymin = -Inf, ymax = Inf,
                        alpha = 0.10, fill = "red") +
        annotate("text", x = mean(bo_events),
                 y = max(traj$ci_upper, na.rm = TRUE) * 0.85,
                 label = "Blackout", size = 3, color = "gray40",
                 fontface = "italic")
    }

    # Period average lines
    if (!is.na(result$att_p1)) {
      p1_ev <- traj %>% filter(week_id %in% p1_ids) %>% pull(event_time)
      if (length(p1_ev) > 0) {
        p <- p + annotate("segment",
                          x = min(p1_ev), xend = max(p1_ev),
                          y = result$att_p1, yend = result$att_p1,
                          linetype = "dashed", color = "#1B9E77", linewidth = 0.8) +
          annotate("text", x = max(p1_ev), y = result$att_p1,
                   label = sprintf("P1: %.1f%%", result$pct_p1),
                   hjust = 1, vjust = -0.8, size = 3, color = "#1B9E77")
      }
    }

    if (!is.na(result$att_p2)) {
      p2_ev <- traj %>% filter(week_id %in% p2_ids) %>% pull(event_time)
      if (length(p2_ev) > 0) {
        p <- p + annotate("segment",
                          x = min(p2_ev), xend = max(p2_ev),
                          y = result$att_p2, yend = result$att_p2,
                          linetype = "dashed", color = "#D95F02", linewidth = 0.8) +
          annotate("text", x = max(p2_ev), y = result$att_p2,
                   label = sprintf("P2: %.1f%%", result$pct_p2),
                   hjust = 1, vjust = -0.8, size = 3, color = "#D95F02")
      }
    }

    p <- p +
      labs(x = "Weeks relative to Metro opening", y = "ATT",
           subtitle = result$label) +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank())
  }

  print(p)
  invisible(p)
}


#=========================================================
#  HELPER: Pre-treatment fit
#=========================================================

compute_fit <- function(result) {
  traj <- result$traj
  pre  <- traj %>% filter(!post_period)
  post <- traj %>% filter(post_period)
  tibble(
    Model = result$label, Method = result$method,
    RMSPE_pre  = sqrt(mean(pre$difference^2, na.rm = TRUE)),
    RMSPE_post = sqrt(mean(post$difference^2, na.rm = TRUE)),
    Ratio = sqrt(mean(post$difference^2, na.rm = TRUE)) /
            sqrt(mean(pre$difference^2, na.rm = TRUE)),
    MAE_pre = mean(abs(pre$difference), na.rm = TRUE)
  )
}


#=========================================================
#  RUN ALL 12 MODELS
#=========================================================

cat(sprintf("\n\n%s\n  %s: FULL MODEL BATTERY (12 models)\n%s\n",
            strrep("#", 60), toupper(POLLUTANT), strrep("#", 60)))

# ---- SDID (donut panel, residualized) ----

m1 <- run_sdid(df_donut, "treated",
               "M1: SDID Centro+Belisario",
               multi_treated = TRUE)

m2 <- run_sdid(df_donut, "treated_centro",
               "M2: SDID Centro (Bel. dropped)",
               exclude_station = "belisario")

m2b <- run_sdid(df_donut, "treated_centro",
                "M2b: SDID Centro (Bel. in pool)")

m3 <- run_sdid(df_donut, "treated_belisario",
               "M3: SDID Belisario (Centro dropped)",
               exclude_station = "centro")


# ---- AugSynth (full panel, covariates, no FE) ----

m4 <- run_augsynth(df, "treated",
                   "M4: AugSynth Centro+Belisario")

m5 <- run_augsynth(df, "treated_centro",
                   "M5: AugSynth Centro (Bel. dropped)",
                   exclude_station = "belisario")

m5b <- run_augsynth(df, "treated_centro",
                    "M5b: AugSynth Centro (Bel. in pool)")

m6 <- run_augsynth(df, "treated_belisario",
                   "M6: AugSynth Belisario (Centro dropped)",
                   exclude_station = "centro")


# ---- AugSynth FE (full panel, covariates, unit FE) ----

m7 <- run_augsynth(df, "treated",
                   "M7: AugSynth_FE Centro+Belisario",
                   use_fe = TRUE)

m8 <- run_augsynth(df, "treated_centro",
                   "M8: AugSynth_FE Centro (Bel. dropped)",
                   exclude_station = "belisario", use_fe = TRUE)

m8b <- run_augsynth(df, "treated_centro",
                    "M8b: AugSynth_FE Centro (Bel. in pool)",
                    use_fe = TRUE)

m9 <- run_augsynth(df, "treated_belisario",
                   "M9: AugSynth_FE Belisario (Centro dropped)",
                   exclude_station = "centro", use_fe = TRUE)


#=========================================================
#  SUMMARY TABLE
#=========================================================

cat(sprintf("\n\n%s\n  %s: SUMMARY TABLE\n%s\n\n",
            strrep("=", 70), toupper(POLLUTANT), strrep("=", 70)))

# ---- AugSynth models ----
aug_models <- list(m4, m5, m5b, m6, m7, m8, m8b, m9)

cat("AugSynth (full panel):\n")
cat(sprintf("%-40s  %7s  %7s  %7s  %7s  %7s  %7s  %7s\n",
            "Model", "All", "Clean", "P1", "P2", "Blkout", "p(1s)", "p(2s)"))
cat(sprintf("%s\n", strrep("-", 115)))

for (m in aug_models) {
  p2_str  <- if (!is.na(m$pct_p2)) sprintf("%6.1f%%", m$pct_p2) else "    --"
  bo_str  <- if (!is.na(m$att_bo)) sprintf("%6.1f%%", (exp(m$att_bo) - 1) * 100) else "    --"
  p1s_str <- if (is.na(m$p_1s)) "    --" else sprintf("%6.3f", m$p_1s)
  cat(sprintf("%-40s  %6.1f%%  %6.1f%%  %6.1f%%  %s  %s  %s  %6.3f\n",
              m$label,
              m$pct_overall,
              m$pct_clean,
              m$pct_p1,
              p2_str, bo_str,
              p1s_str, m$p_2s))
}

# ---- SDID models ----
sdid_models <- list(m1, m2, m2b, m3)

cat(sprintf("\nSDID (donut panel, Phase 3 dropped):\n"))
cat(sprintf("%-40s  %7s  %7s  %7s  %14s  %7s  %7s\n",
            "Model", "ATT", "Pct", "SE", "95% CI", "p(1s)", "p(2s)"))
cat(sprintf("%s\n", strrep("-", 110)))

for (s in sdid_models) {
  p1s_str <- if (is.na(s$p_1s)) "    --" else sprintf("%6.3f", s$p_1s)
  cat(sprintf("%-40s  %7.4f  %6.1f%%  %6.4f  [%.3f, %.3f]  %s  %6.3f\n",
              s$label, s$att, s$pct, s$se, s$ci_lo, s$ci_hi,
              p1s_str, s$p_2s))
}


#=========================================================
#  FIT DIAGNOSTICS
#=========================================================

cat("\n=== Pre-treatment fit ===\n")
all_models <- c(sdid_models, aug_models)
fit_tbl <- bind_rows(lapply(all_models, compute_fit))
print(fit_tbl, n = 12)


#=========================================================
#  DONOR WEIGHT COMPARISON
#=========================================================

cat("\n=== Donor weights: Centro treated, Belisario in pool (M2b, M5b, M8b) ===\n")
w_comp <- m5b$omega %>% rename(AugSynth = weight) %>%
  full_join(m8b$omega %>% rename(AugSynth_FE = weight), by = "estacion") %>%
  full_join(m2b$omega %>% rename(SDID = weight), by = "estacion") %>%
  arrange(estacion)
print(w_comp)

cat("\n=== Donor weights: Centro+Belisario co-treated (M1, M4, M7) ===\n")
w_comp2 <- m4$omega %>% rename(AugSynth = weight) %>%
  full_join(m7$omega %>% rename(AugSynth_FE = weight), by = "estacion") %>%
  full_join(m1$omega %>% rename(SDID = weight), by = "estacion") %>%
  arrange(estacion)
print(w_comp2)


#=========================================================
#  EVENT STUDY PLOTS
#=========================================================

cat("\n=== Event studies ===\n")
for (m in c(aug_models, sdid_models)) {
  plot_event_study(m)
}

cat(sprintf("\n=== %s: ALL 12 MODELS COMPLETE ===\n", toupper(POLLUTANT)))
cat("Model objects in memory: m1-m9, m2b, m5b, m8b\n")
cat("Use plot_event_study(m5b) to re-examine any model.\n")


#=========================================================
#  EXPORT: CSVs and figures for paper-ready output
#=========================================================

library(ggplot2)

OUTPUT_DIR  <- file.path(ROOT_DIR, "output", "local")
TABLES_DIR  <- file.path(OUTPUT_DIR, "tables")
FIGURES_DIR <- file.path(OUTPUT_DIR, "figures")
dir.create(TABLES_DIR,  showWarnings = FALSE, recursive = TRUE)
dir.create(FIGURES_DIR, showWarnings = FALSE, recursive = TRUE)

cat(sprintf("\n=== Exporting CSVs and figures for %s ===\n", toupper(POLLUTANT)))

# ---- Helper extractors (uniform row schema across method types) ----
extract_aug_result <- function(m) {
  tibble(
    pollutant        = POLLUTANT,
    model            = m$label,
    method           = m$method,
    att_overall_log  = as.numeric(m$att_overall),
    att_overall_pct  = as.numeric(m$pct_overall),
    att_clean_log    = as.numeric(m$att_clean),
    att_clean_pct    = as.numeric(m$pct_clean),
    att_p1_log       = as.numeric(m$att_p1),
    att_p1_pct       = as.numeric(m$pct_p1),
    att_p2_log       = as.numeric(m$att_p2),
    att_p2_pct       = as.numeric(m$pct_p2),
    att_blackout_log = as.numeric(m$att_bo),
    att_blackout_pct = if (!is.na(m$att_bo)) (exp(as.numeric(m$att_bo)) - 1) * 100 else NA_real_,
    p_1s             = as.numeric(m$p_1s),
    p_2s             = as.numeric(m$p_2s),
    l2_imbalance     = as.numeric(m$l2),
    scaled_l2        = as.numeric(m$l2_scaled),
    se               = NA_real_,
    ci_lo            = NA_real_,
    ci_hi            = NA_real_
  )
}

extract_sdid_result <- function(s) {
  tibble(
    pollutant        = POLLUTANT,
    model            = s$label,
    method           = s$method,
    att_overall_log  = as.numeric(s$att),
    att_overall_pct  = as.numeric(s$pct),
    att_clean_log    = NA_real_,
    att_clean_pct    = NA_real_,
    att_p1_log       = NA_real_,
    att_p1_pct       = NA_real_,
    att_p2_log       = NA_real_,
    att_p2_pct       = NA_real_,
    att_blackout_log = NA_real_,
    att_blackout_pct = NA_real_,
    p_1s             = as.numeric(s$p_1s),
    p_2s             = as.numeric(s$p_2s),
    l2_imbalance     = NA_real_,
    scaled_l2        = NA_real_,
    se               = as.numeric(s$se),
    ci_lo            = as.numeric(s$ci_lo),
    ci_hi            = as.numeric(s$ci_hi)
  )
}

# ---- 1) Results table: one row per model, all 12 specs ----
results_tbl <- bind_rows(
  bind_rows(lapply(aug_models, extract_aug_result)),
  bind_rows(lapply(sdid_models, extract_sdid_result))
) %>%
  left_join(fit_tbl %>% rename(model = Model, method = Method),
            by = c("model", "method"))

results_file <- file.path(TABLES_DIR,
                          sprintf("results_%s.csv", toupper(POLLUTANT)))
write_csv(results_tbl, results_file)
cat(sprintf("  Wrote: %s\n", basename(results_file)))


# ---- 2) Donor weights, long format ----
weights_long <- bind_rows(
  lapply(c(aug_models, sdid_models), function(m) {
    tibble(pollutant     = POLLUTANT,
           model         = m$label,
           method        = m$method,
           donor_station = m$omega$estacion,
           weight        = m$omega$weight)
  })
)

weights_file <- file.path(TABLES_DIR,
                          sprintf("donor_weights_%s.csv", toupper(POLLUTANT)))
write_csv(weights_long, weights_file)
cat(sprintf("  Wrote: %s\n", basename(weights_file)))


# ---- 3) Trajectories: actual vs synthetic over time ----
# NOTE: AugSynth Y_treated/Y_synthetic are in raw log scale; SDID is in
# residualized log scale (after weather/month adjustment). Compare within
# method only. The `difference` column is the within-method residual.
trajectories <- bind_rows(
  lapply(c(aug_models, sdid_models), function(m) {
    m$traj %>%
      as_tibble() %>%
      select(week_label, Y_treated, Y_synthetic, difference, post_period) %>%
      mutate(pollutant = POLLUTANT,
             model     = m$label,
             method    = m$method)
  })
) %>%
  left_join(df %>% distinct(week_label, week_date),
            by = "week_label")

traj_file <- file.path(TABLES_DIR,
                       sprintf("trajectories_%s.csv", toupper(POLLUTANT)))
write_csv(trajectories, traj_file)
cat(sprintf("  Wrote: %s\n", basename(traj_file)))


# ---- 4) Week-by-week ATTs from AugSynth (for event study figures) ----
week_map <- df %>% distinct(week_id, week_label, week_date)

att_weekly <- bind_rows(
  lapply(aug_models, function(m) {
    m$att_df %>%
      as_tibble() %>%
      mutate(pollutant = POLLUTANT,
             model     = m$label,
             method    = m$method)
  })
) %>%
  left_join(week_map, by = c("time" = "week_id"))

att_file <- file.path(TABLES_DIR,
                      sprintf("att_weekly_%s.csv", toupper(POLLUTANT)))
write_csv(att_weekly, att_file)
cat(sprintf("  Wrote: %s\n", basename(att_file)))


# ---- 5) Event study figures: M5b (primary), M8b (FE), M2b (SDID) ----
key_specs <- list(M5b = m5b, M8b = m8b, M2b = m2b)

for (spec_label in names(key_specs)) {
  m <- key_specs[[spec_label]]
  p <- plot_event_study(m)
  fig_file <- file.path(FIGURES_DIR,
                        sprintf("event_study_%s_%s.png",
                                toupper(POLLUTANT), spec_label))
  ggsave(fig_file, plot = p, width = 7, height = 4.5, dpi = 200)
  cat(sprintf("  Wrote: %s\n", basename(fig_file)))
}

cat(sprintf("\nAll %s outputs saved under: %s\n",
            toupper(POLLUTANT), OUTPUT_DIR))
