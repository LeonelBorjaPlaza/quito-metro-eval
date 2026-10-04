# Amendment 2 to 4, item D.1 and D.3: augsynth fits for the new units, pre period only, with the Step 1
# estimator and tuning (plan section 6): leave-one-block-out penalty on January 2022 to May 2023, the June
# to November 2023 holdout (which is also the backdated fit with June 2023 as treatment date, Amendment 4
# item 7), the two frozen benchmarks, the full pre-period fit, drop-one influence, a plain synthetic
# control next to every ridge fit (Amendment 4 item 6), the MDE and the inference dimensions.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
pn <- readRDS(file.path(AMEND2_DATA, "panel.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))

SPECS <- rbind(
  CJ(rule = "amended", target = c("CENTER", "CORE", "RING7", "BELISARIO_RW", "BELISARIO_EQ", "CORRIDOR"),
     pool = c("primary_screened", "primary_unscreened"), sorted = FALSE),
  CJ(rule = "amended", target = "CENTER", pool = c("low_exposure_screened", "low_exposure_unscreened"), sorted = FALSE),
  CJ(rule = "plan", target = "CENTER", pool = c("primary_screened", "primary_unscreened"), sorted = FALSE))

summarise_path <- function(path, ...) data.table(...,
  n_fit = sum(path$period == "fit"), n_post = sum(path$period == "post"),
  fit_rmspe = rmse(path[period == "fit", gap]),
  holdout_rmse = if (any(path$period == "post")) rmse(path[period == "post", gap]) else NA_real_,
  holdout_bias = if (any(path$period == "post")) mean(path[period == "post", gap]) else NA_real_)

fits <- list(); comparison <- list(); paths <- list(); drop_one <- list(); folds <- list(); wstats <- list(); weights <- list()
grids <- list()
for (i in seq_len(nrow(SPECS))) {
  s <- SPECS[i]; r <- pn$rules[[s$rule]]
  x <- r$series[unit == s$target & block == "peak"][order(date)]
  y1 <- setNames(x$value, x$date)
  donors <- r$pools[[s$pool]]
  Y0 <- r$Y0_all[donors, , drop = FALSE]
  stopifnot(!anyNA(Y0), identical(colnames(Y0), as.character(PRE_MONTHS)))
  tr <- available(y1, TRAIN_MONTHS); ho <- available(y1, HOLDOUT_MONTHS); pre <- available(y1, PRE_MONTHS)
  key <- paste(s$rule, s$pool, s$target, sep = "|")
  message("Fitting ", key, " with ", length(donors), " donors and ", length(pre), " pre months")
  tune <- tune_lambda(y1, Y0, TRAIN_MONTHS)
  check_order_invariance_1e6(y1, Y0, tr, ho, tune$lambda)  # amend2_helpers.R: 1e-6, see note there
  est <- list(ascm = fit_asc(y1, Y0, tr, ho, tune$lambda), scm = fit_asc(y1, Y0, tr, ho, method = "scm"),
              did = fit_did(y1, Y0, tr, ho))
  full <- list(ascm = full_fit(y1, Y0, pre, tune$lambda), scm = full_fit(y1, Y0, pre, method = "scm"))
  tag <- list(rule = s$rule, pool = s$pool, target = s$target)
  for (e in names(est)) {
    comparison[[length(comparison) + 1]] <- do.call(summarise_path, c(list(est[[e]]$path), tag, estimator = e, fit = "holdout"))
    paths[[length(paths) + 1]] <- copy(est[[e]]$path)[, c("rule", "pool", "target", "estimator", "fit") := c(tag, list(e, "holdout"))]
  }
  for (e in names(full)) {
    comparison[[length(comparison) + 1]] <- do.call(summarise_path, c(list(full[[e]]$path), tag, estimator = e, fit = "full pre"))
    paths[[length(paths) + 1]] <- copy(full[[e]]$path)[, c("rule", "pool", "target", "estimator", "fit") := c(tag, list(e, "full pre"))]
    for (w in c("training", "full pre")) {
      f <- if (w == "training") est[[e]] else full[[e]]
      wstats[[length(wstats) + 1]] <- cbind(as.data.table(tag), estimator = e, fit = w, donors = length(donors),
        lambda = if (e == "ascm") tune$lambda else NA_real_, lambda_at_grid_edge = if (e == "ascm") tune$at_grid_edge else NA,
        intercept = f$intercept, most_negative_weight = min(f$weights), largest_weight = max(f$weights),
        weight_stats(f$weights, f$synw))
      weights[[length(weights) + 1]] <- as.data.table(c(tag, list(estimator = e, fit = w, grid_id = names(f$weights),
                                                   scm_weight = f$synw[names(f$weights)], effective_weight = f$weights)))
    }
  }
  top5 <- names(sort(abs(est$ascm$weights), decreasing = TRUE))[1:5]
  drop_one[[key]] <- rbindlist(lapply(top5, function(d) {
    keep <- setdiff(donors, d)
    h <- fit_asc(y1, Y0[keep, ], tr, ho, tune$lambda); p <- full_fit(y1, Y0[keep, ], pre, tune$lambda)
    as.data.table(c(tag, list(dropped = d, weight = est$ascm$weights[[d]], holdout_rmse = rmse(h$path[period == "post", gap]),
               holdout_bias = mean(h$path[period == "post", gap]), full_pre_rmspe = rmse(p$path$gap))))
  }))
  folds[[key]] <- tune$folds[, c("rule", "pool", "target") := tag]
  # Pooled leave-one-block-out MSE at every penalty on augsynth's grid, to show how flat the choice is.
  grids[[key]] <- copy(tune$grid)[, c("rule", "pool", "target", "chosen") := c(tag, list(lambda == tune$lambda))]
  fits[[key]] <- c(tag, list(donors = donors, lambda = tune$lambda, lambda_at_grid_edge = tune$at_grid_edge,
                              months = list(train = tr, holdout = ho, pre = pre), holdout = est, full = full))
}
comparison <- rbindlist(comparison); paths <- rbindlist(paths); wstats <- rbindlist(wstats); weights <- rbindlist(weights)
stopifnot(weights[, abs(sum(effective_weight) - 1) < 1e-6, by = .(rule, pool, target, estimator, fit)]$V1)

# Contrasts: target gap minus BELISARIO gap, months valid for both, same rule, pool, estimator and fit.
CONTRASTS <- list(c("CENTER", "BELISARIO_RW", "primary"), c("CENTER", "BELISARIO_EQ", "sensitivity: equal-weight BELISARIO"),
                  c("RING7", "BELISARIO_EQ", "Step 1 contrast with the buffer donor removed"))
contrast_paths <- rbindlist(lapply(CONTRASTS, function(cc) {
  a <- paths[target == cc[1]]; b <- paths[target == cc[2]]
  m <- merge(a, b, by = c("rule", "pool", "estimator", "fit", "month", "period"), suffixes = c("_a", "_b"))
  m[!is.na(gap_a) & !is.na(gap_b), .(rule, pool, estimator, fit, month, period, contrast = paste(cc[1], "minus", cc[2]),
                                      role = cc[3], gap = gap_a - gap_b)]
}))
contrast <- contrast_paths[, .(n_fit = sum(period == "fit"), n_post = sum(period == "post"), fit_rmspe = rmse(gap[period == "fit"]),
  holdout_rmse = if (any(period == "post")) rmse(gap[period == "post"]) else NA_real_,
  holdout_bias = if (any(period == "post")) mean(gap[period == "post"]) else NA_real_), by = .(contrast, role, rule, pool, estimator, fit)]

# MDE in levels (Step 1 definitions, plan section 7): two-sided 5 percent, power 0.80, constant effect over
# nine P1 months, scaled by the augsynth holdout RMSE. iid: errors cancel as independent monthly errors;
# persistent: the holdout error persists through P1 (three times the iid figure). Never a bound on the effect.
z <- qnorm(0.975) + qnorm(0.80)
mde <- rbindlist(lapply(fits[sapply(fits, function(f) f$target %in% c("CENTER", "CORE", "RING7"))], function(f) {
  g <- f$holdout$ascm$path[period == "post", gap]
  data.table(rule = f$rule, pool = f$pool, target = f$target, holdout_rmse = rmse(g), holdout_bias = mean(g),
             bias_share_of_mse = mean(g)^2 / mean(g^2), n_holdout = length(g), all_gaps_same_sign = length(unique(sign(g))) == 1L,
             mde_iid = z * rmse(g) / 3, mde_persistent = z * rmse(g), pre_mean = mean(f$full$ascm$path$actual))
}))
# Inference dimensions (Amendment 3: CENTER P1 is the single confirmatory test). P1 is assumed to keep
# all nine months; Step 3 recounts after the composition rule.
inference_dims <- rbindlist(lapply(fits, function(f) data.table(rule = f$rule, pool = f$pool, target = f$target,
  pre_months = length(f$months$pre), p1_months_assumed = 9L, total_periods = length(f$months$pre) + 9L,
  smallest_attainable_p = 1 / (length(f$months$pre) + 9L), donors = length(f$donors))))

saveRDS(list(label = AMEND2_LABEL, fits = fits, comparison = comparison, paths = paths, wstats = wstats, weights = weights,
             contrast = contrast, contrast_paths = contrast_paths, drop_one = rbindlist(drop_one), folds = rbindlist(folds), grids = rbindlist(grids),
             mde = mde, inference_dims = inference_dims), file.path(AMEND2_DATA, "fits.rds"))
fwrite(comparison, file.path(AMEND2_OUT, "fit_statistics.csv"))
fwrite(paths[, .(rule, pool, target, estimator, fit, month, period, actual, synthetic, gap)], file.path(AMEND2_OUT, "fit_paths_pre.csv"))
fwrite(wstats, file.path(AMEND2_OUT, "weight_statistics.csv"))
fwrite(weights, file.path(AMEND2_OUT, "donor_weights.csv"))
fwrite(contrast, file.path(AMEND2_OUT, "contrast_statistics.csv"))
fwrite(rbindlist(drop_one), file.path(AMEND2_OUT, "influence_drop_one.csv"))
fwrite(rbindlist(folds), file.path(AMEND2_OUT, "lobo_folds.csv"))
fwrite(rbindlist(grids), file.path(AMEND2_OUT, "lobo_grid.csv"))
fwrite(mde, file.path(AMEND2_OUT, "mde.csv"))
fwrite(inference_dims, file.path(AMEND2_OUT, "inference_dimensions.csv"))
print(comparison[fit == "holdout" & rule == "amended"], nrows = 100)
print(wstats[estimator == "ascm" & fit == "full pre"][, .(rule, pool, target, lambda, lambda_at_grid_edge, most_negative_weight, total_negative, sum_abs)])
print(mde); print(contrast[estimator == "ascm" & rule == "amended"])
