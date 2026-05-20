# ============================================================================
#  00_helpers.R - Quito Metro Air Quality: City-Level Analysis (v4, 2026-05)
# ============================================================================
#
#  Shared functions for satellite city-level analysis. Sourced by each
#  pollutant runner (01_run_AOD.R, 02_run_CO.R, etc.).
#
#  Methodology (binding):
#    - Treatment week: ISO 2023-W48 (Nov 27 - Dec 3, contains Dec 1 Friday
#      Metro opening). Consistent with local pipeline. Replaces V3 which
#      used W49.
#    - Three samples: pre_blackout, full, donut.
#      * pre_blackout: drop everything from 2024-09-15 onward.
#      * full: keep all data (blackout visible in event study).
#      * donut: drop weeks with week_start in [2024-09-15, 2024-12-31].
#        PRIMARY for SDID.
#    - Residualization (split FWL):
#      * SDID: full residualization (13 _w covariates + id_uc_g0 x month FE).
#      * AugSynth: month-FE-only outcome; covariates FWL-residualized on
#        id_uc_g0 x month FE then passed to augsynth() formula (Ridge handles).
#      * Estimation sample: all donors full series + Quito pre-treatment only.
#    - Block aggregation: B=4 non-overlapping weeks aligned to t_int
#      (block_id=0 starts at t_int). Incomplete edge blocks dropped.
#    - Donor pool: Mahalanobis-ranked (rank_extended), N in {50, 100, 150,
#      200}. Primary is 100.
#    - Estimators: SDID (primary), SC (robustness), AugSynth no FE (robust),
#      AugSynth FE (robust).
#    - Inference:
#      * SDID/SC: placebo SE (300 reps), Wald-type. One-sided p computed
#        only when ATT < 0 (pollution-reduction prior). NA otherwise.
#      * AugSynth: conformal. One-sided p computed only when ATT < 0
#        (workaround for known stat_func bug). NA otherwise.
#    - Sub-period decomposition (donut sample):
#      * AugSynth: derive sub-period ATTs from weekly att_vec indexed by
#        block period IDs (P1, P2, overall).
#      * SDID: separate estimations with restricted post-treatment windows.
# ============================================================================

suppressMessages({
  library(dplyr)
  library(readr)
  library(synthdid)
  library(augsynth)
  library(fixest)
  library(ggplot2)
  library(tibble)
  library(tidyr)
  library(stringr)
  library(patchwork)
  library(scales)
  library(lubridate)
})

set.seed(12345)

# ============================================================================
#  CONSTANTS
# ============================================================================

TREATED_ID  <- 2544L                       # Quito UCDB ID
EXCLUDE_IDS <- c(2610L)                    # Cumbaya (too close to Quito)

TREATMENT_YEAR <- 2023
TREATMENT_WEEK <- 48                       # W48 contains Dec 1 (Friday opening)

BLACKOUT_START <- as.Date("2024-09-15")
BLACKOUT_END   <- as.Date("2024-12-31")

# 13 ERA5 winsorized covariates (in Stage 4 panels)
COVARIATES_W <- c(
  "calm_pct_w", "evap_week_mm_w", "rain_freq_pct_w", "rh2m_mean_w",
  "soilT1_mean_w", "soilW1_mean_w", "solar_week_MJ_w", "sp_mean_w",
  "t2m_mean_w", "tp_week_mm_w", "wind10m_dir_w", "wind10m_max_w",
  "wind10m_speed_mean_w"
)

# Plot palette
COL_OBS   <- "#2B2B2B"
COL_SYNTH <- "#377EB8"
COL_LINE  <- "#E41A1C"
COL_P1    <- "#1B9E77"
COL_P2    <- "#D95F02"


# ============================================================================
#  1. DATA LOADING
# ============================================================================

load_panel <- function(panel_csv, outcome_var) {
  cat(sprintf("\n[load_panel] %s\n", panel_csv))
  df <- read_csv(panel_csv, show_col_types = FALSE) %>%
    mutate(
      id_uc_g0   = as.integer(id_uc_g0),
      iso_year   = as.integer(iso_year),
      iso_week   = as.integer(iso_week),
      week_start = as.Date(week_start)
    )

  cat(sprintf("  Raw: %d rows, %d cities, %d weeks\n",
              nrow(df), n_distinct(df$id_uc_g0), n_distinct(df$wdate)))

  df <- df %>% filter(!id_uc_g0 %in% EXCLUDE_IDS)
  cat(sprintf("  After excluding %s: %d cities\n",
              paste(EXCLUDE_IDS, collapse = ","),
              n_distinct(df$id_uc_g0)))

  # Required columns
  required <- c(outcome_var, COVARIATES_W, "id_uc_g0", "iso_year",
                "iso_week", "week_start")
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing columns: %s", paste(missing, collapse = ", ")))
  }

  df
}

load_donor_ranks <- function(donor_csv) {
  cat(sprintf("\n[load_donor_ranks] %s\n", donor_csv))
  donor_ranks <- read_csv(donor_csv, show_col_types = FALSE) %>%
    filter(ID_UC_G0 != TREATED_ID,
           !ID_UC_G0 %in% EXCLUDE_IDS) %>%
    arrange(rank_extended) %>%
    mutate(ID_UC_G0 = as.integer(ID_UC_G0))
  cat(sprintf("  %d donor cities ranked by Mahalanobis (extended)\n",
              nrow(donor_ranks)))
  donor_ranks
}


# ============================================================================
#  2. SAMPLE FILTERING + CALENDAR
# ============================================================================

apply_sample_filter <- function(df, sample) {
  # sample in {"pre_blackout", "full", "donut"}
  if (sample == "pre_blackout") {
    df_out <- df %>% filter(week_start < BLACKOUT_START)
    cat(sprintf("  [sample=pre_blackout] dropped weeks >= %s\n", BLACKOUT_START))
  } else if (sample == "donut") {
    df_out <- df %>% filter(week_start < BLACKOUT_START | week_start > BLACKOUT_END)
    cat(sprintf("  [sample=donut] dropped weeks in [%s, %s]\n",
                BLACKOUT_START, BLACKOUT_END))
  } else if (sample == "full") {
    df_out <- df
    cat("  [sample=full] no filter applied\n")
  } else {
    stop("sample must be one of: pre_blackout, full, donut")
  }
  cat(sprintf("  Rows: %d -> %d  |  Cities: %d -> %d  |  Weeks: %d -> %d\n",
              nrow(df), nrow(df_out),
              n_distinct(df$id_uc_g0), n_distinct(df_out$id_uc_g0),
              n_distinct(df$wdate), n_distinct(df_out$wdate)))
  df_out
}

build_calendar <- function(df, treatment_year = TREATMENT_YEAR,
                            treatment_week = TREATMENT_WEEK) {
  cal <- df %>%
    distinct(iso_year, iso_week, week_start) %>%
    arrange(iso_year, iso_week) %>%
    mutate(
      time_id    = row_number(),
      week_label = sprintf("%dw%02d", iso_year, iso_week)
    )

  # Locate treatment week
  match_row <- cal %>%
    filter(iso_year == treatment_year, iso_week == treatment_week)

  if (nrow(match_row) == 0) {
    # pre_blackout sample doesn't contain the treatment week, but for that
    # sample we just need t_int >= cal_max + 1 conceptually. Issue a warning
    # and pick the first week after the treatment date.
    treatment_date <- as.Date(paste0(treatment_year, "-01-04")) +
                      (treatment_week - 1) * 7
    cat(sprintf("  WARNING: %d-W%02d not in calendar; treatment date approx %s\n",
                treatment_year, treatment_week, treatment_date))
    t_int <- nrow(cal) + 1   # all-post-empty placeholder, only relevant if
                              # sample == pre_blackout (which doesn't need post)
  } else {
    t_int <- match_row$time_id
  }

  cat(sprintf("  Calendar: %d periods | t_int = %d (target %dw%02d)\n",
              nrow(cal), t_int, treatment_year, treatment_week))

  list(cal = cal, t_int = t_int)
}

attach_calendar <- function(df, cal, t_int) {
  df %>%
    left_join(cal %>% select(iso_year, iso_week, time_id, week_label),
              by = c("iso_year", "iso_week")) %>%
    mutate(
      treat = as.integer(id_uc_g0 == TREATED_ID & time_id >= t_int),
      month = as.integer(month(week_start))
    )
}


# ============================================================================
#  3. SPLIT-FWL RESIDUALIZATION
# ============================================================================
#
#  Two parallel residualizations:
#   - FULL (for SDID): outcome ~ 13 covariates | id_uc_g0 x month FE
#       Used directly by SDID, which cannot accept covariates.
#   - MONTH-FE-ONLY (for AugSynth) + FWL-residualized covariates:
#       outcome ~ 1 | id_uc_g0 x month FE
#       Each covariate ~ 1 | id_uc_g0 x month FE
#       AugSynth gets the month-FE-clean outcome + FWL-clean covariates on RHS.
#       Ridge then learns the covariate-outcome relationship internally.
#
#  Estimation sample for ALL regressions: donors' full series + Quito pre.
# ============================================================================

residualize_split_fwl <- function(df, outcome_var, t_int) {
  cat(sprintf("\n=== Residualization (split FWL) ===\n"))

  df_est <- df %>%
    filter(id_uc_g0 != TREATED_ID |
           (id_uc_g0 == TREATED_ID & time_id < t_int))

  n_obs_est    <- nrow(df_est)
  n_cities_est <- n_distinct(df_est$id_uc_g0)
  n_quito_pre  <- sum(df_est$id_uc_g0 == TREATED_ID)

  cat(sprintf("  Estimation sample: %d obs, %d cities (%d Quito pre)\n",
              n_obs_est, n_cities_est, n_quito_pre))

  # --- 1. FULL residualization for SDID ---
  fml_full <- as.formula(paste(
    outcome_var, "~",
    paste(COVARIATES_W, collapse = " + "),
    "| id_uc_g0^month"
  ))
  cat(sprintf("\n  [FULL]  %s\n", deparse(fml_full)))

  reg_full <- feols(fml_full, data = df_est, notes = FALSE)
  r2_full  <- as.numeric(fixest::r2(reg_full)["wr2"])
  cat(sprintf("    R2(within) = %.4f, N = %d\n", r2_full, reg_full$nobs))

  outcome_adj_col  <- paste0(outcome_var, "_adj")
  grand_mean       <- mean(df[[outcome_var]], na.rm = TRUE)
  df[[outcome_adj_col]] <- df[[outcome_var]] -
                           predict(reg_full, newdata = df) +
                           grand_mean

  # --- 2. MONTH-FE-ONLY residualization for AugSynth ---
  fml_mfe <- as.formula(paste(outcome_var, "~ 1 | id_uc_g0^month"))
  cat(sprintf("\n  [MFE]   %s\n", deparse(fml_mfe)))

  reg_mfe <- feols(fml_mfe, data = df_est, notes = FALSE)
  r2_mfe  <- as.numeric(fixest::r2(reg_mfe)["wr2"])
  cat(sprintf("    Outcome R2(within month-FE only) = %.4f\n", r2_mfe))

  outcome_mfe_col <- paste0(outcome_var, "_adj_monthFE")
  df[[outcome_mfe_col]] <- df[[outcome_var]] -
                           predict(reg_mfe, newdata = df) +
                           grand_mean

  # --- 3. FWL-residualize each covariate on city x month FE ---
  cat(sprintf("\n  [FWL covariates] residualizing %d controls on id_uc_g0^month...\n",
              length(COVARIATES_W)))
  for (cov in COVARIATES_W) {
    fml_cov <- as.formula(paste(cov, "~ 1 | id_uc_g0^month"))
    reg_cov <- feols(fml_cov, data = df_est, notes = FALSE)
    cov_grand <- mean(df[[cov]], na.rm = TRUE)
    df[[paste0(cov, "_resid")]] <- df[[cov]] -
                                    predict(reg_cov, newdata = df) +
                                    cov_grand
    cat(sprintf("    %-25s  R2(within) = %.4f\n",
                cov, as.numeric(fixest::r2(reg_cov)["wr2"])))
  }

  # --- Quito SD reduction diagnostic ---
  quito_diag <- df %>%
    filter(id_uc_g0 == TREATED_ID) %>%
    summarise(
      raw_sd    = sd(.data[[outcome_var]], na.rm = TRUE),
      full_sd   = sd(.data[[outcome_adj_col]], na.rm = TRUE),
      mfe_sd    = sd(.data[[outcome_mfe_col]], na.rm = TRUE)
    )
  cat(sprintf("\n  Quito SD: raw=%.4f -> full_adj=%.4f (%+.1f%%), monthFE_only=%.4f (%+.1f%%)\n",
              quito_diag$raw_sd,
              quito_diag$full_sd, 100*(quito_diag$full_sd/quito_diag$raw_sd - 1),
              quito_diag$mfe_sd,  100*(quito_diag$mfe_sd/quito_diag$raw_sd - 1)))

  attr(df, "r2_within_full") <- r2_full
  attr(df, "r2_within_mfe")  <- r2_mfe
  attr(df, "grand_mean")     <- grand_mean
  attr(df, "n_obs_est")      <- n_obs_est
  attr(df, "n_cities_est")   <- n_cities_est
  attr(df, "outcome_adj_col")     <- outcome_adj_col
  attr(df, "outcome_mfe_col")     <- outcome_mfe_col
  attr(df, "covariates_resid")    <- paste0(COVARIATES_W, "_resid")

  df
}


# ============================================================================
#  4. BLOCK AGGREGATION (B-week non-overlapping, aligned to t_int)
# ============================================================================
#
#  block_id = 0 starts EXACTLY at t_int (so block boundary = treatment date).
#  Pre-treatment blocks have block_id < 0; post-treatment >= 0.
#  Incomplete edge blocks dropped.
#
#  Tracks median week_start per block so we can classify blocks into
#  sub-periods (P1, blackout, P2) for AugSynth decomposition later.
# ============================================================================

block_aggregate <- function(df, B, t_int, outcome_adj_col,
                            outcome_mfe_col, covariates_resid) {
  cat(sprintf("\n=== Block aggregation (B=%d, aligned to t_int=%d) ===\n",
              B, t_int))

  df <- df %>%
    mutate(
      time_offset = time_id - t_int,
      block_id    = ifelse(
        time_offset >= 0,
        floor(time_offset / B),
        -ceiling(-time_offset / B)
      )
    )

  # Pre-compute new column names
  block_outcome_col <- paste0(outcome_adj_col, "_block")
  block_mfe_col     <- paste0(outcome_mfe_col, "_block")

  # Aggregate
  df_blocks <- df %>%
    filter(!is.na(.data[[outcome_adj_col]])) %>%
    group_by(id_uc_g0, block_id) %>%
    summarise(
      !!block_outcome_col := mean(.data[[outcome_adj_col]], na.rm = TRUE),
      !!block_mfe_col     := mean(.data[[outcome_mfe_col]],  na.rm = TRUE),
      across(all_of(covariates_resid), ~mean(.x, na.rm = TRUE)),
      mid_week_start = median(week_start),
      n_weeks = n(),
      .groups = "drop"
    )

  # Drop incomplete edge blocks (n_weeks != B)
  n_before <- nrow(df_blocks)
  df_blocks <- df_blocks %>% filter(n_weeks == B)
  cat(sprintf("  Dropped %d incomplete edge blocks; kept %d\n",
              n_before - nrow(df_blocks), nrow(df_blocks)))

  # Sequential block_time
  block_cal <- df_blocks %>%
    group_by(block_id) %>%
    summarise(mid_week_start = median(mid_week_start), .groups = "drop") %>%
    arrange(block_id) %>%
    mutate(block_time = row_number())

  df_blocks <- df_blocks %>%
    left_join(block_cal %>% select(block_id, block_time),
              by = "block_id")

  t_int_block <- block_cal %>% filter(block_id == 0) %>% pull(block_time)
  if (length(t_int_block) == 0) t_int_block <- NA_integer_

  n_pre  <- sum(block_cal$block_id < 0)
  n_post <- sum(block_cal$block_id >= 0)

  cat(sprintf("  Blocks: %d total (%d pre, %d post)  | t_int_block = %d\n",
              nrow(block_cal), n_pre, n_post, t_int_block))

  list(
    df_blocks         = df_blocks,
    block_cal         = block_cal,
    t_int_block       = t_int_block,
    block_outcome_col = block_outcome_col,
    block_mfe_col     = block_mfe_col,
    B                 = B
  )
}


# ============================================================================
#  5. CLASSIFY POST-TREATMENT BLOCKS INTO SUB-PERIODS
# ============================================================================
#
#  Block sub-period assignment (donut sample omits blackout blocks entirely):
#    P1       : block_id >= 0 AND mid_week_start < BLACKOUT_START
#    blackout : block_id >= 0 AND mid_week_start in [BLACKOUT_START, BLACKOUT_END]
#               (only present in full sample; absent from donut/pre_blackout)
#    P2       : block_id >= 0 AND mid_week_start >  BLACKOUT_END
#
#  Returns named list of block_time vectors for indexing att_vec.
# ============================================================================

classify_blocks <- function(block_cal, t_int_block) {
  post <- block_cal %>%
    filter(block_id >= 0) %>%
    mutate(
      period = case_when(
        mid_week_start <  BLACKOUT_START                       ~ "p1",
        mid_week_start >= BLACKOUT_START &
        mid_week_start <= BLACKOUT_END                         ~ "blackout",
        mid_week_start >  BLACKOUT_END                         ~ "p2",
        TRUE                                                    ~ NA_character_
      )
    )

  ids <- list(
    all_post = post$block_time,
    p1       = post %>% filter(period == "p1") %>% pull(block_time),
    blackout = post %>% filter(period == "blackout") %>% pull(block_time),
    p2       = post %>% filter(period == "p2") %>% pull(block_time)
  )
  ids$clean <- c(ids$p1, ids$p2)   # donut equivalent

  cat(sprintf("\n  Post-block classification: P1=%d, Blackout=%d, P2=%d, Clean=%d\n",
              length(ids$p1), length(ids$blackout),
              length(ids$p2), length(ids$clean)))

  ids
}


# ============================================================================
#  6. DONOR SELECTION (Mahalanobis top-N)
# ============================================================================

select_top_donors <- function(donor_ranks, df_blocks, n_target) {
  # n_target == Inf or n_target >= n_available -> all-donors iteration
  available_ids <- unique(df_blocks$id_uc_g0[df_blocks$id_uc_g0 != TREATED_ID])
  donor_ranks_avail <- donor_ranks %>%
    filter(ID_UC_G0 %in% available_ids)
  n_available <- nrow(donor_ranks_avail)

  is_all_donors <- is.infinite(n_target) || n_target >= n_available
  if (is_all_donors) {
    selected     <- donor_ranks_avail$ID_UC_G0
    n_effective  <- n_available
    tag          <- "Nall"
    cat(sprintf("  [ALL DONORS] %d cities available in panel (Mahalanobis-ranked)\n",
                n_effective))
  } else {
    donor_ranks_avail <- donor_ranks_avail %>% slice_head(n = n_target)
    selected     <- donor_ranks_avail$ID_UC_G0
    n_effective  <- nrow(donor_ranks_avail)
    tag          <- sprintf("N%d", n_effective)
    cat(sprintf("  Donor pool requested=%d, effective=%d (top-N intersected with panel)\n",
                n_target, n_effective))
  }

  list(
    selected_ids = selected,
    n_effective  = n_effective,
    tag          = tag,
    donor_table  = donor_ranks_avail,
    is_all       = is_all_donors
  )
}

filter_to_donor_pool <- function(df_blocks, block_cal, selected_ids,
                                  block_outcome_col) {
  df <- df_blocks %>% filter(id_uc_g0 %in% c(TREATED_ID, selected_ids))

  # Enforce balance: keep only block_times present for all selected cities
  n_target_cities <- n_distinct(df$id_uc_g0)
  complete_bt <- df %>%
    group_by(block_time) %>%
    summarise(n_cities = n_distinct(id_uc_g0), .groups = "drop") %>%
    filter(n_cities == n_target_cities) %>%
    pull(block_time)

  df <- df %>% filter(block_time %in% complete_bt)
  block_cal_filt <- block_cal %>% filter(block_time %in% complete_bt)

  cat(sprintf("  Balanced panel: %d cities x %d blocks\n",
              n_target_cities, nrow(block_cal_filt)))

  list(df = df, block_cal = block_cal_filt)
}


# ============================================================================
#  7. SDID + SC ESTIMATION
# ============================================================================
#
#  Inputs:  Y_matrix (units x time), N0 (control units), T0 (pre-periods)
#  Output:  list with att, se, p_1s, p_2s, omega, trajectory
#
#  One-sided p-value: pnorm(att/se) when att < 0, else NA. (We only test
#  pollution-reduction; positive ATTs report two-sided + CI only.)
# ============================================================================

prepare_Y_matrix <- function(df, block_outcome_col) {
  Y_wide <- df %>%
    select(id_uc_g0, block_time, all_of(block_outcome_col)) %>%
    pivot_wider(names_from = block_time, values_from = all_of(block_outcome_col),
                id_cols = id_uc_g0) %>%
    arrange(id_uc_g0)

  unit_ids <- Y_wide$id_uc_g0
  Y_matrix <- as.matrix(Y_wide[, -1])
  rownames(Y_matrix) <- unit_ids

  # Put Quito (treated) last (synthdid convention)
  ti <- which(unit_ids == TREATED_ID)
  if (length(ti) != 1) stop("Quito not unique in Y matrix")
  if (ti != nrow(Y_matrix)) {
    ord <- c((1:nrow(Y_matrix))[-ti], ti)
    Y_matrix <- Y_matrix[ord, ]
    unit_ids <- unit_ids[ord]
  }
  list(Y = Y_matrix, unit_ids = unit_ids)
}

one_sided_wald <- function(att, se) {
  # One-sided test for ATT < 0. Returns NA if ATT not in hypothesized direction.
  if (is.na(att) || is.na(se) || se == 0) return(NA_real_)
  if (att >= 0) return(NA_real_)
  pnorm(att / se)
}

two_sided_wald <- function(att, se) {
  if (is.na(att) || is.na(se) || se == 0) return(NA_real_)
  2 * (1 - pnorm(abs(att / se)))
}

run_sdid <- function(Y, N0, T0, label = "SDID") {
  cat(sprintf("\n  [%s] Y: %d units x %d blocks (N0=%d, T0=%d)\n",
              label, nrow(Y), ncol(Y), N0, T0))

  fit <- synthdid_estimate(Y, N0, T0)
  att <- as.numeric(fit)
  se  <- sqrt(vcov(fit, method = "placebo", replications = 300))

  omega <- attr(fit, "weights")$omega
  Y_tr  <- Y[nrow(Y), ]
  Y_sy  <- colSums(omega * Y[1:N0, ])
  traj  <- tibble(
    block_time     = 1:ncol(Y),
    Y_treated      = Y_tr,
    Y_synthetic   = Y_sy,
    difference    = Y_tr - Y_sy,
    post_treatment = (1:ncol(Y)) > T0
  )

  weights_df <- tibble(
    id_uc_g0 = rownames(Y)[1:N0],
    weight   = as.numeric(omega)[1:N0]
  ) %>% arrange(desc(weight))

  cat(sprintf("    ATT=%.4f  SE=%.4f  pct=%.2f%%  p(1s)=%s  p(2s)=%.4f\n",
              att, se, (exp(att)-1)*100,
              ifelse(is.na(one_sided_wald(att,se)), "  NA  ",
                     sprintf("%.4f", one_sided_wald(att,se))),
              two_sided_wald(att,se)))

  list(method = "SDID",
       att = att, se = se,
       pct = (exp(att) - 1) * 100,
       p_1s = one_sided_wald(att, se),
       p_2s = two_sided_wald(att, se),
       ci_lo = att - 1.96 * se,
       ci_hi = att + 1.96 * se,
       omega = weights_df,
       traj  = traj,
       fit   = fit)
}

run_sc <- function(Y, N0, T0, label = "SC") {
  fit <- sc_estimate(Y, N0, T0)
  att <- as.numeric(fit)
  se  <- sqrt(vcov(fit, method = "placebo", replications = 300))
  omega <- attr(fit, "weights")$omega

  Y_tr <- Y[nrow(Y), ]
  Y_sy <- colSums(omega * Y[1:N0, ])
  traj <- tibble(
    block_time     = 1:ncol(Y),
    Y_treated      = Y_tr,
    Y_synthetic    = Y_sy,
    difference     = Y_tr - Y_sy,
    post_treatment = (1:ncol(Y)) > T0
  )
  weights_df <- tibble(
    id_uc_g0 = rownames(Y)[1:N0],
    weight   = as.numeric(omega)[1:N0]
  ) %>% arrange(desc(weight))

  cat(sprintf("  [%s] ATT=%.4f  SE=%.4f  pct=%.2f%%  p(1s)=%s  p(2s)=%.4f\n",
              label, att, se, (exp(att)-1)*100,
              ifelse(is.na(one_sided_wald(att,se)), "  NA  ",
                     sprintf("%.4f", one_sided_wald(att,se))),
              two_sided_wald(att,se)))

  list(method = "SC",
       att = att, se = se,
       pct = (exp(att) - 1) * 100,
       p_1s = one_sided_wald(att, se),
       p_2s = two_sided_wald(att, se),
       ci_lo = att - 1.96 * se,
       ci_hi = att + 1.96 * se,
       omega = weights_df,
       traj  = traj,
       fit   = fit)
}


# ============================================================================
#  8. AUGSYNTH ESTIMATION
# ============================================================================
#
#  Uses month-FE-only outcome + FWL-residualized covariates on RHS.
#  Ridge handles the covariate-outcome relationship internally.
#
#  Sub-period ATTs derived from summary()$att$Estimate, indexed by block_time.
#
#  One-sided p-value: only computed when att_overall < 0. Otherwise NA.
#  This avoids the stat_func bug (negative direction hardcoded).
# ============================================================================

run_augsynth <- function(df_aug, block_mfe_col, covariates_resid,
                          t_int_block, period_ids, use_fe,
                          label = NULL) {

  if (is.null(label)) label <- ifelse(use_fe, "AugSynth_FE", "AugSynth_noFE")
  cat(sprintf("\n  [%s] N=%d obs from %d cities  use_fe=%s\n",
              label, nrow(df_aug),
              n_distinct(df_aug$id_uc_g0), use_fe))

  rhs <- paste(covariates_resid, collapse = " + ")
  form <- as.formula(paste(block_mfe_col, "~ treat_unit |", rhs))

  fit <- tryCatch(
    augsynth(form, unit = id_uc_g0, time = block_time, t_int = t_int_block,
             data = df_aug, progfunc = "Ridge", scm = TRUE,
             fixedeff = use_fe),
    error = function(e) {
      cat(sprintf("  ERROR augsynth: %s\n", e$message))
      return(NULL)
    }
  )
  if (is.null(fit)) return(NULL)

  # Two-sided conformal (default)
  summ_2s   <- summary(fit, inf_type = "conformal")
  att_tbl   <- summ_2s$att                     # 1 row per panel time
  att_vec   <- att_tbl$Estimate                # indexed by block_time
  att_avg   <- summ_2s$average_att$Estimate
  p_2s      <- summ_2s$average_att$p_val

  # One-sided conformal: only compute if att_avg < 0 (pollution-reduction prior)
  if (!is.na(att_avg) && att_avg < 0) {
    summ_1s <- summary(fit, inf_type = "conformal",
                        stat_func = function(x) -sum(x))
    p_1s    <- summ_1s$average_att$p_val
  } else {
    p_1s    <- NA_real_
  }

  # Sub-period ATTs (mean of att_vec over block_time IDs)
  safe_mean <- function(ids) {
    v <- att_vec[ids]
    v <- v[!is.na(v)]
    if (length(v) == 0) return(NA_real_)
    mean(v)
  }
  att_p1       <- safe_mean(period_ids$p1)
  att_p2       <- safe_mean(period_ids$p2)
  att_blackout <- safe_mean(period_ids$blackout)
  att_clean    <- safe_mean(period_ids$clean)
  att_overall  <- safe_mean(period_ids$all_post)

  cat(sprintf("    Overall ATT=%.4f (%.1f%%)  Clean=%.4f (%.1f%%)\n",
              att_overall, (exp(att_overall) - 1) * 100,
              att_clean,   (exp(att_clean)   - 1) * 100))
  cat(sprintf("    P1=%.4f (%.1f%%)  P2=%s\n",
              att_p1, (exp(att_p1) - 1) * 100,
              ifelse(is.na(att_p2), "NA",
                     sprintf("%.4f (%.1f%%)", att_p2, (exp(att_p2) - 1) * 100))))
  cat(sprintf("    p(1s)=%s  p(2s)=%.4f  L2=%.4f  improvement=%.1f%%\n",
              ifelse(is.na(p_1s), "  NA  ", sprintf("%.4f", p_1s)),
              p_2s, summ_2s$l2_imbalance,
              100 * (1 - summ_2s$scaled_l2_imbalance)))

  # Trajectory
  Y_cf <- as.numeric(predict(fit, att = FALSE))
  treated_avg <- df_aug %>%
    filter(id_uc_g0 == TREATED_ID) %>%
    select(block_time, Y_treated = all_of(block_mfe_col)) %>%
    arrange(block_time)
  traj <- tibble(block_time = sort(unique(df_aug$block_time)),
                 Y_synthetic = Y_cf) %>%
    left_join(treated_avg, by = "block_time") %>%
    mutate(difference = Y_treated - Y_synthetic,
           post_treatment = block_time >= t_int_block)

  weights_df <- tibble(
    id_uc_g0 = rownames(fit$weights),
    weight   = as.numeric(fit$weights)
  ) %>% arrange(desc(abs(weight)))

  list(method        = label,
       att_overall   = att_avg,             # AugSynth's own average (= mean att_vec post)
       att_overall_alt = att_overall,       # our recomputed mean for sanity
       att_clean     = att_clean,
       att_p1        = att_p1,
       att_p2        = att_p2,
       att_blackout  = att_blackout,
       pct_overall   = (exp(att_avg)    - 1) * 100,
       pct_clean     = (exp(att_clean)  - 1) * 100,
       pct_p1        = (exp(att_p1)     - 1) * 100,
       pct_p2        = if (!is.na(att_p2)) (exp(att_p2) - 1) * 100 else NA_real_,
       pct_blackout  = if (!is.na(att_blackout)) (exp(att_blackout) - 1) * 100 else NA_real_,
       p_1s          = p_1s,
       p_2s          = p_2s,
       l2_imbalance  = summ_2s$l2_imbalance,
       l2_scaled     = summ_2s$scaled_l2_imbalance,
       omega         = weights_df,
       att_tbl       = att_tbl,
       traj          = traj,
       fit           = fit)
}


# ============================================================================
#  9. PRE-TREATMENT FIT
# ============================================================================

compute_fit <- function(traj, label) {
  pre  <- traj %>% filter(!post_treatment)
  post <- traj %>% filter( post_treatment)
  tibble(
    Model       = label,
    RMSPE_pre   = sqrt(mean(pre$difference^2,  na.rm = TRUE)),
    RMSPE_post  = sqrt(mean(post$difference^2, na.rm = TRUE)),
    Ratio       = sqrt(mean(post$difference^2, na.rm = TRUE)) /
                  sqrt(mean(pre$difference^2,  na.rm = TRUE)),
    MAE_pre     = mean(abs(pre$difference),  na.rm = TRUE),
    T_pre       = nrow(pre),
    T_post      = nrow(post)
  )
}


# ============================================================================
#  10. PLOTTING HELPERS
# ============================================================================

plot_trajectory <- function(traj, t_int_block, title, ylab = "Adjusted outcome",
                            block_labels = NULL) {
  p <- traj %>%
    pivot_longer(c(Y_treated, Y_synthetic), names_to = "series", values_to = "value") %>%
    mutate(series = recode(series, Y_treated = "Quito (Observed)",
                            Y_synthetic = "Synthetic Control")) %>%
    ggplot(aes(x = block_time, y = value, color = series, group = series)) +
    geom_line(linewidth = 1) +
    geom_vline(xintercept = t_int_block, linetype = "dashed",
               color = COL_LINE, linewidth = 0.8) +
    scale_color_manual(values = c("Quito (Observed)" = COL_OBS,
                                   "Synthetic Control" = COL_SYNTH)) +
    labs(x = "Block (4-week)", y = ylab, color = NULL, title = title) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom",
          panel.grid.minor = element_blank())

  if (!is.null(block_labels)) {
    p <- p + scale_x_continuous(breaks = block_labels$block_time,
                                 labels = block_labels$label)
  }
  p
}

plot_event_study <- function(traj, att, t_int_block, title,
                              blackout_block_ids = integer(0),
                              att_p1 = NA, att_p2 = NA, p1_ids = NULL,
                              p2_ids = NULL) {
  ev <- traj %>% mutate(event_time = block_time - t_int_block)

  p <- ggplot(ev, aes(x = event_time, y = difference)) +
    geom_line(color = COL_OBS, linewidth = 1) +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.5) +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = COL_LINE,
               linewidth = 0.8) +
    annotate("text", x = -0.5, y = max(ev$difference, na.rm = TRUE),
             label = sprintf("ATT = %.3f (%.1f%%)", att, (exp(att)-1)*100),
             color = COL_SYNTH, hjust = -0.05, vjust = 1, size = 4) +
    labs(x = "Blocks relative to Metro opening",
         y = "Treatment effect", title = title) +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank())

  # Shade blackout
  if (length(blackout_block_ids) > 0) {
    bo_ev <- ev %>% filter(block_time %in% blackout_block_ids) %>% pull(event_time)
    if (length(bo_ev) > 0) {
      p <- p + annotate("rect",
                         xmin = min(bo_ev) - 0.5,
                         xmax = max(bo_ev) + 0.5,
                         ymin = -Inf, ymax = Inf,
                         alpha = 0.10, fill = "red") +
        annotate("text", x = mean(bo_ev),
                 y = max(ev$difference, na.rm = TRUE) * 0.85,
                 label = "Blackout", size = 3, color = "gray40",
                 fontface = "italic")
    }
  }

  # Period segments
  if (!is.na(att_p1) && !is.null(p1_ids) && length(p1_ids) > 0) {
    p1_ev <- ev %>% filter(block_time %in% p1_ids) %>% pull(event_time)
    if (length(p1_ev) > 0) {
      p <- p + annotate("segment",
                         x = min(p1_ev), xend = max(p1_ev),
                         y = att_p1, yend = att_p1,
                         linetype = "dashed", color = COL_P1, linewidth = 0.8)
    }
  }
  if (!is.na(att_p2) && !is.null(p2_ids) && length(p2_ids) > 0) {
    p2_ev <- ev %>% filter(block_time %in% p2_ids) %>% pull(event_time)
    if (length(p2_ev) > 0) {
      p <- p + annotate("segment",
                         x = min(p2_ev), xend = max(p2_ev),
                         y = att_p2, yend = att_p2,
                         linetype = "dashed", color = COL_P2, linewidth = 0.8)
    }
  }
  p
}


# ============================================================================
#  11. SAVE OUTPUTS
# ============================================================================

save_iteration_outputs <- function(out_tables, out_graphs, tag,
                                    results_list, block_labels = NULL,
                                    period_ids = NULL,
                                    t_int_block = NULL) {
  dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)
  dir.create(out_graphs, showWarnings = FALSE, recursive = TRUE)

  # Helper to coerce maybe-NULL maybe-vector to length-1 numeric (NA if missing).
  safe_num <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_real_)
    suppressWarnings(as.numeric(x)[1])
  }
  safe_chr <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_character_)
    as.character(x)[1]
  }

  safe_write <- function(tbl, path, label) {
    tryCatch({
      readr::write_csv(tbl, path)
      cat(sprintf("    wrote %s (%d rows)\n", basename(path), nrow(tbl)))
    }, error = function(e) {
      cat(sprintf("    ERROR writing %s: %s\n", basename(path), e$message))
      cat("    Column types:\n")
      for (nm in names(tbl)) {
        cat(sprintf("      %-20s  class=%s  length=%d\n",
                    nm, class(tbl[[nm]])[1], length(tbl[[nm]])))
      }
    })
  }

  # 1) ATT summary table
  summary_rows <- lapply(results_list, function(r) {
    if (is.null(r)) return(NULL)
    # Use explicit if-else, NOT ifelse (which mis-handles NULL "yes" branch).
    att_overall <- if (is.null(r$att_overall)) r$att else r$att_overall
    pct_overall <- if (is.null(r$pct_overall)) r$pct else r$pct_overall
    tibble(
      method       = safe_chr(r$method),
      att_overall  = safe_num(att_overall),
      pct_overall  = safe_num(pct_overall),
      att_clean    = safe_num(r$att_clean),
      pct_clean    = safe_num(r$pct_clean),
      att_p1       = safe_num(r$att_p1),
      pct_p1       = safe_num(r$pct_p1),
      att_p2       = safe_num(r$att_p2),
      pct_p2       = safe_num(r$pct_p2),
      att_blackout = safe_num(r$att_blackout),
      pct_blackout = safe_num(r$pct_blackout),
      se           = safe_num(r$se),
      ci_lo        = safe_num(r$ci_lo),
      ci_hi        = safe_num(r$ci_hi),
      p_1s         = safe_num(r$p_1s),
      p_2s         = safe_num(r$p_2s),
      l2_imbalance = safe_num(r$l2_imbalance)
    )
  })
  summary_tbl <- bind_rows(summary_rows)
  safe_write(summary_tbl, file.path(out_tables, sprintf("Summary_%s.csv", tag)),
              "summary")

  # 2) Donor weights (long format) - coerce id_uc_g0 to character for bind_rows safety
  weights_long <- bind_rows(lapply(results_list, function(r) {
    if (is.null(r) || is.null(r$omega)) return(NULL)
    om <- r$omega
    if (!"id_uc_g0" %in% names(om)) return(NULL)
    om %>%
      mutate(id_uc_g0 = as.character(id_uc_g0),
             weight   = as.numeric(weight),
             method   = as.character(r$method))
  }))
  safe_write(weights_long, file.path(out_tables, sprintf("Weights_%s.csv", tag)),
              "weights")

  # 3) Trajectories
  traj_long <- bind_rows(lapply(results_list, function(r) {
    if (is.null(r) || is.null(r$traj)) return(NULL)
    r$traj %>%
      mutate(method = as.character(r$method),
             block_time = as.integer(block_time),
             Y_treated  = as.numeric(Y_treated),
             Y_synthetic = as.numeric(Y_synthetic),
             difference = as.numeric(difference),
             post_treatment = as.logical(post_treatment))
  }))
  safe_write(traj_long, file.path(out_tables, sprintf("Trajectories_%s.csv", tag)),
              "trajectories")

  # 4) Pre-treatment fit
  fit_tbl <- bind_rows(lapply(results_list, function(r) {
    if (is.null(r) || is.null(r$traj)) return(NULL)
    compute_fit(r$traj, r$method)
  }))
  safe_write(fit_tbl, file.path(out_tables, sprintf("PreTreatmentFit_%s.csv", tag)),
              "fit")

  # 5) Figures (one trajectory + one event study per method)
  for (r in results_list) {
    if (is.null(r)) next
    bo_ids <- if (!is.null(period_ids)) period_ids$blackout else integer(0)
    att_for_es <- if (is.null(r$att_overall)) r$att else r$att_overall

    # Trajectory plot
    tryCatch({
      p_tr <- plot_trajectory(r$traj, t_int_block,
                                title = sprintf("%s [%s]", r$method, tag))
      ggsave(file.path(out_graphs, sprintf("Trajectory_%s_%s.png", r$method, tag)),
             plot = p_tr, width = 9, height = 5, dpi = 200)
    }, error = function(e) {
      cat(sprintf("    ERROR plot trajectory %s: %s\n", r$method, e$message))
    })

    # Event study
    tryCatch({
      p_es <- plot_event_study(r$traj, att_for_es, t_int_block,
                                title = sprintf("%s event study [%s]", r$method, tag),
                                blackout_block_ids = bo_ids,
                                att_p1 = if (!is.null(r$att_p1)) r$att_p1 else NA,
                                att_p2 = if (!is.null(r$att_p2)) r$att_p2 else NA,
                                p1_ids = if (!is.null(period_ids)) period_ids$p1 else NULL,
                                p2_ids = if (!is.null(period_ids)) period_ids$p2 else NULL)
      ggsave(file.path(out_graphs, sprintf("EventStudy_%s_%s.png", r$method, tag)),
             plot = p_es, width = 9, height = 5, dpi = 200)
    }, error = function(e) {
      cat(sprintf("    ERROR plot event study %s: %s\n", r$method, e$message))
    })
  }

  summary_tbl
}


# ============================================================================
#  12. MAIN ORCHESTRATOR
# ============================================================================
#
#  Runs the full pipeline for one (pollutant, sample) combination,
#  looping over donor pool sizes. Returns grand summary tibble.
# ============================================================================

run_pollutant_sample <- function(POLLUTANT,
                                  OUTCOME_VAR,
                                  SAMPLE,
                                  N_DONORS_LIST = c(50, 100, 150, 200, Inf),
                                  B = 4,
                                  PANEL_CSV  = NULL,
                                  DONOR_CSV  = NULL,
                                  OUT_ROOT   = "~/v4_2026_05/output") {

  t_start <- Sys.time()
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(sprintf(" POLLUTANT=%s  SAMPLE=%s  B=%d\n",
              toupper(POLLUTANT), SAMPLE, B))
  cat(sprintf(" Outcome: %s\n", OUTCOME_VAR))
  cat(sprintf(" Donor pool sizes: %s\n", paste(N_DONORS_LIST, collapse = ", ")))
  cat(sprintf(" Start: %s\n", t_start))
  cat(strrep("=", 70), "\n", sep = "")

  # Output dirs
  out_dir    <- file.path(OUT_ROOT, toupper(POLLUTANT), SAMPLE)
  out_graphs <- file.path(out_dir, "graphs")
  out_tables <- file.path(out_dir, "tables")
  dir.create(out_graphs, showWarnings = FALSE, recursive = TRUE)
  dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

  # 1. Load panel + donor file
  df_raw       <- load_panel(PANEL_CSV, OUTCOME_VAR)
  donor_ranks  <- load_donor_ranks(DONOR_CSV)

  # 2. Apply sample filter
  df_filt <- apply_sample_filter(df_raw, SAMPLE)

  # 3. Calendar + t_int
  cal_info <- build_calendar(df_filt)
  cal      <- cal_info$cal
  t_int    <- cal_info$t_int

  df <- attach_calendar(df_filt, cal, t_int)

  # 4. Residualization
  df <- residualize_split_fwl(df, OUTCOME_VAR, t_int)

  outcome_adj_col   <- attr(df, "outcome_adj_col")
  outcome_mfe_col   <- attr(df, "outcome_mfe_col")
  covariates_resid  <- attr(df, "covariates_resid")

  # 5. Block aggregation
  ba <- block_aggregate(df, B, t_int,
                         outcome_adj_col, outcome_mfe_col, covariates_resid)
  df_blocks         <- ba$df_blocks
  block_cal         <- ba$block_cal
  t_int_block       <- ba$t_int_block
  block_outcome_col <- ba$block_outcome_col
  block_mfe_col     <- ba$block_mfe_col

  # 6. Classify post-blocks
  period_ids <- classify_blocks(block_cal, t_int_block)

  # 7. Loop over donor pool sizes
  grand <- tibble()
  for (n_target in N_DONORS_LIST) {
    cat("\n", strrep("#", 70), "\n", sep = "")
    target_str <- if (is.infinite(n_target)) "ALL" else sprintf("TOP %d", n_target)
    cat(sprintf(" %s/%s — %s DONORS\n",
                toupper(POLLUTANT), SAMPLE, target_str))
    cat(strrep("#", 70), "\n", sep = "")

    sel <- select_top_donors(donor_ranks, df_blocks, n_target)
    pool <- filter_to_donor_pool(df_blocks, block_cal,
                                  sel$selected_ids, block_outcome_col)
    df_pool   <- pool$df
    block_cal_filt <- pool$block_cal
    t_int_block_filt <- block_cal_filt %>%
      filter(block_id == 0) %>% pull(block_time)
    if (length(t_int_block_filt) == 0) t_int_block_filt <- t_int_block

    # Recompute period IDs given the filtered block_cal
    period_ids_iter <- classify_blocks(block_cal_filt, t_int_block_filt)

    tag <- sel$tag

    # SDID + SC
    Ym <- prepare_Y_matrix(df_pool, block_outcome_col)
    N0 <- nrow(Ym$Y) - 1
    T0 <- t_int_block_filt - 1

    res_sdid <- tryCatch(run_sdid(Ym$Y, N0, T0, label = "SDID"),
                          error = function(e) {
                            cat(sprintf("  ERROR SDID: %s\n", e$message))
                            NULL
                          })
    res_sc   <- tryCatch(run_sc(Ym$Y, N0, T0, label = "SC"),
                          error = function(e) {
                            cat(sprintf("  ERROR SC: %s\n", e$message))
                            NULL
                          })

    # AugSynth (no FE) + AugSynth (FE)
    df_aug <- df_pool %>%
      mutate(treat_unit = as.integer(id_uc_g0 == TREATED_ID)) %>%
      select(id_uc_g0, block_time, all_of(block_mfe_col), treat_unit,
             all_of(covariates_resid)) %>%
      filter(!is.na(.data[[block_mfe_col]]))

    res_aug_no <- tryCatch(
      run_augsynth(df_aug, block_mfe_col, covariates_resid,
                    t_int_block_filt, period_ids_iter, use_fe = FALSE),
      error = function(e) {
        cat(sprintf("  ERROR AugSynth (no FE): %s\n", e$message))
        NULL
      }
    )
    res_aug_fe <- tryCatch(
      run_augsynth(df_aug, block_mfe_col, covariates_resid,
                    t_int_block_filt, period_ids_iter, use_fe = TRUE),
      error = function(e) {
        cat(sprintf("  ERROR AugSynth (FE): %s\n", e$message))
        NULL
      }
    )

    # Save per-iteration outputs
    results_list <- list(SDID = res_sdid, SC = res_sc,
                          AugSynth_noFE = res_aug_no,
                          AugSynth_FE = res_aug_fe)
    summary_tbl <- save_iteration_outputs(
      out_tables, out_graphs, tag,
      results_list, period_ids = period_ids_iter,
      t_int_block = t_int_block_filt
    )

    grand <- bind_rows(grand,
                       summary_tbl %>% mutate(N_donors = sel$n_effective,
                                              N_requested = n_target))
  }

  # Save grand summary
  grand_path <- file.path(out_tables, "GrandSummary.csv")
  write_csv(grand, grand_path)
  cat(sprintf("\n[Grand summary saved] %s\n", grand_path))

  # Residualization diagnostics
  diag_tbl <- tibble(
    metric = c("n_obs_est", "n_cities_est", "r2_within_full",
                "r2_within_mfe", "grand_mean", "t_int", "t_int_block",
                "B", "n_pre_blocks", "n_post_blocks"),
    value  = as.character(c(
      attr(df, "n_obs_est"),
      attr(df, "n_cities_est"),
      round(attr(df, "r2_within_full"), 4),
      round(attr(df, "r2_within_mfe"), 4),
      round(attr(df, "grand_mean"), 4),
      t_int, t_int_block, B,
      sum(block_cal$block_id < 0),
      sum(block_cal$block_id >= 0)
    ))
  )
  write_csv(diag_tbl, file.path(out_tables, "ResidualizationDiagnostics.csv"))

  t_end <- Sys.time()
  cat(sprintf("\n=== %s/%s complete in %.1f min ===\n",
              toupper(POLLUTANT), SAMPLE,
              as.numeric(difftime(t_end, t_start, units = "mins"))))

  invisible(grand)
}
