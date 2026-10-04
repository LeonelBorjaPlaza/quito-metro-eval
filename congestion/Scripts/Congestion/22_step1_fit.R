# Step 1, item 4. Ridge-augmented SCM for CENTER and BELISARIO on January 2022 to May 2023,
# prediction of the June to November 2023 holdout (used once), benchmarks, then the full
# pre-period fit with the tuned penalty. The contrast is CENTER's gap minus BELISARIO's gap.
# Both the screened and unscreened threshold-20 pools are fit (the primary is Leonel's choice),
# under the amended flag rule (primary) and the plan's original rule (sensitivity; Amendment 1).
# A target's missing unit-months are left out of every fit; nothing is filled.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
stopifnot(identical(panel$months, PRE_MONTHS))

POOLS <- c("primary_unscreened", "primary_screened")
TARGETS <- c("CENTER", "BELISARIO")
DEC22_TRAIN <- DEC22_MONTHS[DEC22_MONTHS <= 202305L]

summarise_path <- function(path, ...) data.table(...,
  n_fit = sum(path$period == "fit"), n_post = sum(path$period == "post"),
  fit_rmspe = rmse(path[period == "fit", gap]),
  holdout_rmse = if (any(path$period == "post")) rmse(path[period == "post", gap]) else NA_real_,
  holdout_bias = if (any(path$period == "post")) mean(path[period == "post", gap]) else NA_real_)

fits <- list(); comparison <- list(); paths <- list(); drop_one <- list(); tuning <- list(); folds <- list()
for (rule in names(panel$rules)) {
  pr <- panel$rules[[rule]]
  peak <- pr$unit_month[block == "peak"]
  target_y <- function(u) { x <- peak[unit == u][order(date)]; setNames(x$value, x$date) }
  dm <- dcast(pr$donor_month[block == "peak"], grid_id ~ date, value.var = "value")
  Y0_all <- as.matrix(dm[, -1]); rownames(Y0_all) <- dm$grid_id
  stopifnot(identical(colnames(Y0_all), as.character(PRE_MONTHS)))
  for (pool in POOLS) {
    donors <- pr$cells[get(paste0("pool_", pool)) == TRUE, grid_id]
    Y0 <- Y0_all[donors, , drop = FALSE]
    stopifnot(!anyNA(Y0))
    for (u in TARGETS) {
      y1 <- target_y(u)
      tr <- available(y1, TRAIN_MONTHS); ho <- available(y1, HOLDOUT_MONTHS)
      pre <- available(y1, PRE_MONTHS); d22 <- available(y1, DEC22_TRAIN); d22f <- available(y1, DEC22_MONTHS)
      key <- paste(rule, pool, u, sep = "|")
      message("Fitting ", key, " with ", length(donors), " donors and ", length(pre), " pre months")
      tune <- tune_lambda(y1, Y0, TRAIN_MONTHS)
      check_order_invariance(y1, Y0, tr, ho, tune$lambda)
      # The December 2022 sensitivity reuses this penalty (approved in the Step 1 plan); it is not re-tuned.
      est <- list(
        ascm = fit_asc(y1, Y0, tr, ho, tune$lambda),
        scm = fit_asc(y1, Y0, tr, ho, method = "scm"),
        did = fit_did(y1, Y0, tr, ho),
        ascm_dec22 = fit_asc(y1, Y0, d22, ho, tune$lambda))
      full <- full_fit(y1, Y0, pre, tune$lambda)
      full_dec22 <- full_fit(y1, Y0, d22f, tune$lambda)
      tag <- list(rule = rule, pool = pool, target = u)
      for (e in names(est)) {
        comparison[[length(comparison) + 1]] <- do.call(summarise_path, c(list(est[[e]]$path), tag, estimator = e,
          window = if (e == "ascm_dec22") "train 2022-12 to 2023-05" else "train 2022-01 to 2023-05"))
        paths[[length(paths) + 1]] <- est[[e]]$path[, c("rule", "pool", "target", "estimator", "fit") := c(tag, list(e, "holdout"))]
      }
      for (f in list(list("ascm", full, "full pre 2022-01 to 2023-11"), list("ascm_dec22", full_dec22, "full pre 2022-12 to 2023-11"))) {
        comparison[[length(comparison) + 1]] <- do.call(summarise_path, c(list(f[[2]]$path), tag, estimator = f[[1]], window = f[[3]]))
        paths[[length(paths) + 1]] <- f[[2]]$path[, c("rule", "pool", "target", "estimator", "fit") := c(tag, list(f[[1]], f[[3]]))]
      }
      # Influence: drop each of the five donors with the largest absolute effective weight in the
      # training fit (the top-donor table in 23 ranks by the full pre-period fit instead).
      top5 <- names(sort(abs(est$ascm$weights), decreasing = TRUE))[1:5]
      drop_one[[key]] <- rbindlist(lapply(top5, function(d) {
        keep <- setdiff(donors, d)
        h <- fit_asc(y1, Y0[keep, ], tr, ho, tune$lambda)
        p <- full_fit(y1, Y0[keep, ], pre, tune$lambda)
        data.table(rule = rule, pool = pool, target = u, dropped = d, weight = est$ascm$weights[[d]],
                   holdout_rmse = rmse(h$path[period == "post", gap]), holdout_bias = mean(h$path[period == "post", gap]),
                   full_pre_rmspe = rmse(p$path$gap))
      }))
      tuning[[key]] <- tune$grid[, c("rule", "pool", "target", "chosen") := c(tag, list(lambda == tune$lambda))]
      folds[[key]] <- tune$folds[, c("rule", "pool", "target") := tag]
      fits[[key]] <- list(rule = rule, pool = pool, target = u, donors = donors, lambda = tune$lambda,
                          lambda_at_grid_edge = tune$at_grid_edge,
                          months = list(train = tr, holdout = ho, pre = pre), holdout = est, full = full, full_dec22 = full_dec22)
    }
  }
}
comparison <- rbindlist(comparison); paths <- rbindlist(paths)

# Contrast: CENTER gap minus BELISARIO gap, over months valid for both targets.
contrast_paths <- dcast(paths, rule + pool + estimator + fit + month + period ~ target, value.var = "gap")
contrast_paths <- contrast_paths[!is.na(CENTER) & !is.na(BELISARIO)][, gap := CENTER - BELISARIO]
contrast <- contrast_paths[, .(n_fit = sum(period == "fit"), n_post = sum(period == "post"),
  fit_rmspe = rmse(gap[period == "fit"]),
  holdout_rmse = if (any(period == "post")) rmse(gap[period == "post"]) else NA_real_,
  holdout_bias = if (any(period == "post")) mean(gap[period == "post"]) else NA_real_), by = .(rule, pool, estimator, fit)]

saveRDS(list(label = ZERO_LABEL, fits = fits, comparison = comparison, paths = paths, contrast = contrast,
             contrast_paths = contrast_paths, drop_one = rbindlist(drop_one), tuning = rbindlist(tuning),
             folds = rbindlist(folds)), file.path(STEP1_DATA, "fits_pre.rds"))
fwrite(comparison, file.path(STEP1_OUT, "holdout_comparison.csv"))
fwrite(contrast, file.path(STEP1_OUT, "contrast_comparison.csv"))
writeLines(c("# Step 1 holdout comparison", "",
  sprintf("%s. Gap = actual minus prediction, in percentage points of tci_osm_ratio (peak block). Bias is the mean holdout gap.", ZERO_LABEL),
  "Rules: amended (primary, Amendment 1) and plan (original flag rule, sensitivity). Pools: threshold-20 REST with and without the 2022 jam-derived coverage screen.",
  "Estimators: ascm (augsynth, ridge, unit intercept, tuned penalty), scm (augsynth without augmentation or intercept), did (donor-mean difference-in-differences), ascm_dec22 (December 2022 start).", "",
  "## CENTER and BELISARIO", "", md_table(comparison), "",
  "## Contrast, CENTER gap minus BELISARIO gap", "", md_table(contrast), ""),
  file.path(STEP1_OUT, "holdout_comparison.md"))
print(comparison, nrows = 200); print(contrast, nrows = 200)
