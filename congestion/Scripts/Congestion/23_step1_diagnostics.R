# Step 1, item 5. Pre-period diagnostics (plan sections 6 and 7): fit quality, weights, top donors,
# influence, leave-one-block-out folds, pseudo-neighbourhood placebos in space, the pre-only MDE
# for CENTER in levels, and the inference setup against the panel's dimensions.
# Pre-period only; provisional zero coding.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
fits <- readRDS(file.path(STEP1_DATA, "fits_pre.rds"))
PRIMARY_RULE <- "amended"
POOLS <- c("primary_unscreened", "primary_screened")

# 1. Weights, intercept and penalty for every augsynth fit (training fit and full pre-period fit).
weights_summary <- rbindlist(lapply(fits$fits, function(f) rbindlist(lapply(c("holdout", "full"), function(w) {
  x <- if (w == "holdout") f$holdout$ascm else f$full
  cbind(data.table(rule = f$rule, pool = f$pool, target = f$target, fit = w, donors = length(f$donors),
                   lambda = f$lambda, lambda_at_grid_edge = f$lambda_at_grid_edge, intercept = x$intercept),
        weight_stats(x$weights, x$synw))
}))))

# 2. Top ten donors of each full pre-period fit, with distances (ranked by the full pre-period fit;
# the drop-one influence check in 22 uses the training fit's five largest donors).
cells <- panel$rules[[PRIMARY_RULE]]$cells
top_donors <- rbindlist(lapply(fits$fits, function(f) {
  w <- f$full$weights
  top <- names(sort(abs(w), decreasing = TRUE))[1:10]
  d <- cells[match(top, grid_id)]
  data.table(rule = f$rule, pool = f$pool, target = f$target, rank = 1:10, grid_id = top,
             effective_weight = w[top], scm_weight = f$full$synw[top],
             km_to_target_seed = (if (f$target == "CENTER") d$dist_center_seed_m else d$dist_belisario_seed_m) / 1000,
             km_to_nearest_station = d$nearest_station_m / 1000, in_coverage_range = d$cov_ok)
}))

# 3. Pseudo-neighbourhoods (plan section 7): seven-cell k-ring-1 sets centred on pool cells whose
# whole ring is in the pool, chosen greedily in ascending H3 id order without overlap (outcome-blind).
con <- duck()
pr <- panel$rules[[PRIMARY_RULE]]
dm <- dcast(pr$donor_month[block == "peak"], grid_id ~ date, value.var = "value")
Y0_all <- as.matrix(dm[, -1]); rownames(Y0_all) <- dm$grid_id
pseudo <- list(); pseudo_sets <- list()
for (pool in POOLS) {
  members <- sort(pr$cells[get(paste0("pool_", pool)) == TRUE, grid_id])
  used <- character(); sets <- list()
  for (s in members) {
    ring <- sort(DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) g", params = list(s))$g)
    if (length(ring) == 7L && all(ring %in% members) && !any(ring %in% used)) {
      sets[[s]] <- ring; used <- c(used, ring)
    }
  }
  pseudo_sets[[pool]] <- sets
  message(pool, ": ", length(sets), " pseudo-neighbourhoods")
  center_full <- fits$fits[[paste(PRIMARY_RULE, pool, "CENTER", sep = "|")]]$full
  for (s in names(sets)) {
    y1 <- colMeans(Y0_all[sets[[s]], , drop = FALSE])
    Y0 <- Y0_all[setdiff(members, sets[[s]]), , drop = FALSE]
    tune <- tune_lambda(y1, Y0, TRAIN_MONTHS)
    h <- fit_asc(y1, Y0, TRAIN_MONTHS, HOLDOUT_MONTHS, tune$lambda)
    f <- full_fit(y1, Y0, PRE_MONTHS, tune$lambda)
    pseudo[[paste(pool, s)]] <- data.table(pool = pool, seed = s, pre_mean = mean(y1), lambda = tune$lambda,
      train_rmspe = rmse(h$path[period == "fit", gap]), holdout_rmse = rmse(h$path[period == "post", gap]),
      holdout_bias = mean(h$path[period == "post", gap]), full_pre_rmspe = rmse(f$path$gap),
      passes_fit_filter = rmse(f$path$gap) <= 3 * rmse(center_full$path$gap))
  }
}
DBI::dbDisconnect(con, shutdown = TRUE)
pseudo <- rbindlist(pseudo)
center_rows <- fits$comparison[rule == PRIMARY_RULE & target == "CENTER" & estimator == "ascm"]
pseudo_summary <- pseudo[, .(pseudo_neighbourhoods = .N, pass_fit_filter = sum(passes_fit_filter),
  median_holdout_rmse = median(holdout_rmse), median_abs_holdout_bias = median(abs(holdout_bias))), by = pool]
pseudo_summary[, center_holdout_rmse := center_rows[window == "train 2022-01 to 2023-05"][match(pseudo_summary$pool, pool), holdout_rmse]]
pseudo_summary[, center_rmse_rank_among_all := sapply(pool, function(p)
  sum(pseudo[pool == p, holdout_rmse] >= center_holdout_rmse[pool == p]))]

# 4. Pre-only MDE for CENTER in levels (plan section 7): calibrated on holdout errors.
# MDE = (z_0.975 + z_0.80) * holdout RMSE * sqrt(inflation / 9), constant effect over the nine P1
# months, two-sided alpha 0.05, power 0.80. Inflation is the AR(1) variance factor for a mean of
# nine months, with rho the lag-1 autocorrelation of the full pre-period residual path over
# calendar-adjacent months only. rho is NA (and so is the AR(1) MDE) when the full pre-period fit
# interpolates (RMSPE below 1e-4): a correlation of rounding noise is meaningless.
# An MDE describes the design; it is never a bound on the true effect.
z <- qnorm(0.975) + qnorm(0.80)
ar1_inflation <- function(rho, n = 9) if (is.na(rho)) NA_real_ else 1 + 2 * sum((1 - (1:(n - 1)) / n) * rho^(1:(n - 1)))
mde <- rbindlist(lapply(fits$fits[sapply(fits$fits, function(f) f$target == "CENTER")], function(f) {
  s_h <- rmse(f$holdout$ascm$path[period == "post", gap])
  rho <- rho_calendar(f$full$path$month, f$full$path$gap, PRE_MONTHS)
  y_pre <- f$full$path$actual
  data.table(rule = f$rule, pool = f$pool, holdout_rmse = s_h, n_holdout = sum(f$holdout$ascm$path$period == "post"),
             rho_pre_residuals = rho, inflation = ar1_inflation(rho),
             mde_pp_iid = z * s_h / 3, mde_pp_ar1 = z * s_h * sqrt(ar1_inflation(rho) / 9),
             center_pre_mean = mean(y_pre), mde_ar1_pct_of_pre_mean = 100 * z * s_h * sqrt(ar1_inflation(rho) / 9) / mean(y_pre))
}))

# 5. Inference setup against the panel's dimensions (plan section 7; counts, not data).
# Moving-block permutations of the full residual sequence: one per cyclic shift of the T periods.
p1_months <- 9L
inference_dims <- rbindlist(lapply(fits$fits, function(f) {
  t_pre <- length(f$months$pre)
  # Missing target months break the pre-period sequence; block permutations in Step 3 must keep these
  # calendar gaps (plan section 5), so the counts below are exact only when calendar_gaps is 0.
  data.table(rule = f$rule, pool = f$pool, target = f$target, pre_months = t_pre,
             calendar_gaps = length(PRE_MONTHS) - t_pre, p1_months = p1_months,
             total_periods = t_pre + p1_months, block_permutations = t_pre + p1_months,
             smallest_attainable_p = 1 / (t_pre + p1_months), donors = length(f$donors))
}))

# 6. Figure: pre-period paths for the primary rule (actual, full-period fit, holdout prediction).
pp <- fits$paths[rule == PRIMARY_RULE & estimator == "ascm" & fit %in% c("holdout", "full pre 2022-01 to 2023-11")]
pp[, date := as.Date(paste0(month, "01"), "%Y%m%d")]
pp[, series := fifelse(fit == "holdout", "training fit, then holdout prediction", "full pre-period fit")]
stopifnot(max(pp$date) < as.Date("2023-12-01"))
g <- ggplot(pp, aes(date)) +
  annotate("rect", xmin = as.Date("2023-06-01"), xmax = as.Date("2023-11-01"), ymin = -Inf, ymax = Inf, fill = "grey85") +
  geom_line(data = unique(pp[fit == "holdout", .(date, actual, pool, target)]), aes(y = actual), colour = "black", linewidth = 0.6) +
  geom_line(aes(y = synthetic, colour = series), linetype = "dashed") +
  facet_grid(target ~ pool, scales = "free_y") +
  labs(title = "Step 1 augsynth fits, pre period only (amended flag rule)",
       subtitle = "Black: actual peak tci_osm_ratio. Grey band: June to November 2023 holdout. Provisional zero coding.",
       x = NULL, y = "Peak TCI / OSM (%)", colour = NULL) + theme_minimal(base_size = 9) + theme(legend.position = "bottom")
ggsave(file.path(STEP1_OUT, "fit_paths_pre.png"), g, width = 10, height = 6.5, dpi = 150)

diag <- list(label = ZERO_LABEL, weights_summary = weights_summary, top_donors = top_donors, pseudo = pseudo,
             pseudo_sets = pseudo_sets, pseudo_summary = pseudo_summary, mde = mde, inference_dims = inference_dims)
saveRDS(diag, file.path(STEP1_DATA, "diagnostics_pre.rds"))
for (n in c("weights_summary", "top_donors", "pseudo", "mde", "inference_dims")) fwrite(diag[[n]], file.path(STEP1_OUT, paste0(n, ".csv")))

txt <- c("# Step 1 pre-period diagnostics", "",
  sprintf("%s. Generated by Scripts/Congestion/23_step1_diagnostics.R. No outcome after November 2023.", ZERO_LABEL), "",
  "## Weights, intercept and penalty", "",
  "Training fit (January 2022 to May 2023) and full pre-period fit. total_negative is the sum of negative effective weights; effective_n is 1 / HHI of absolute weights.", "",
  md_table(weights_summary), "",
  "## Top ten donors of each full pre-period fit", "", md_table(top_donors), "",
  "## Influence: drop one of the five largest donors (training fit, same penalty)", "", md_table(fits$drop_one), "",
  "## Leave-one-block-out folds at the chosen penalty", "", md_table(fits$folds), "",
  sprintf("## Pseudo-neighbourhood placebos, %s rule", PRIMARY_RULE), "",
  "Fit filter: full pre-period RMSPE at most three times CENTER's. center_rmse_rank_among_all counts pseudo-neighbourhoods whose holdout RMSE is at least CENTER's.", "",
  md_table(pseudo_summary), "", md_table(pseudo), "",
  "## Pre-only minimum detectable effect for CENTER, levels", "",
  "Two-sided alpha 0.05, power 0.80, constant effect over nine P1 months, scale from the holdout RMSE. This describes the design and is never a bound on the true effect.", "",
  md_table(mde), "",
  "## Inference setup against the panel's dimensions", "",
  "Moving-block permutations of the full residual sequence give one permutation per period, so the smallest attainable p-value is 1 / (pre months + P1 months).", "",
  md_table(inference_dims), "")
writeLines(txt, file.path(STEP1_OUT, "diagnostics.md"))
print(weights_summary); print(pseudo_summary); print(mde); print(top_donors[rule == PRIMARY_RULE & target == "CENTER"])
