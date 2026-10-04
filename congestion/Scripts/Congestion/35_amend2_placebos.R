# Spatial placebos, descriptive (plan section 7 as amended by Amendments 3 and 4), pre period only.
# Pseudo-targets: seven-cell neighbourhoods (H3 k-ring 1, equal weights) centred on every pool cell whose
# whole ring is in the pool. Neighbourhoods may overlap each other. The pool already excludes CENTER, its
# buffer, CORRIDOR, RING and BELISARIO, so no placebo cell touches CENTER. Each pseudo-target's own seven
# cells are removed from its donor pool. Same estimator and tuning as the targets (33).
# Scale: each gap is divided by max(own full pre-period RMSPE, CENTER's full pre-period RMSPE in the same
# pool) (Amendment 4, item 4). No p-value is computed: conformal inference remains the test.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
pn <- readRDS(file.path(AMEND2_DATA, "panel.rds"))
ft <- readRDS(file.path(AMEND2_DATA, "fits.rds"))
r <- pn$rules$amended
POOLS <- c("primary_screened", "primary_unscreened")
N_CORES <- 4L

con <- duck()
sets <- lapply(setNames(POOLS, POOLS), function(p) {
  members <- r$pools[[p]]
  rings <- lapply(setNames(members, members), function(s)
    sort(DBI::dbGetQuery(con, "SELECT unnest(h3_grid_disk(?, 1)) g", params = list(s))$g))
  Filter(function(g) length(g) == 7L && all(g %in% members), rings)
})
DBI::dbDisconnect(con, shutdown = TRUE)
message("pseudo-neighbourhoods: ", paste(names(sets), lengths(sets), collapse = "; "))

fit_one <- function(p, s) {
  members <- r$pools[[p]]; g <- sets[[p]][[s]]
  y1 <- colMeans(r$Y0_all[g, , drop = FALSE])
  Y0 <- r$Y0_all[setdiff(members, g), , drop = FALSE]
  stopifnot(!any(g %in% rownames(Y0)))
  tune <- tune_lambda(y1, Y0, TRAIN_MONTHS)
  h <- fit_asc(y1, Y0, TRAIN_MONTHS, HOLDOUT_MONTHS, tune$lambda)
  f <- full_fit(y1, Y0, PRE_MONTHS, tune$lambda)
  hg <- h$path[period == "post", gap]
  data.table(pool = p, seed = s, pre_mean = mean(y1), lambda = tune$lambda, lambda_at_grid_edge = tune$at_grid_edge,
             train_rmspe = rmse(h$path[period == "fit", gap]), full_pre_rmspe = rmse(f$path$gap),
             holdout_rmse = rmse(hg), holdout_bias = mean(hg), donors = nrow(Y0))
}
jobs <- rbindlist(lapply(POOLS, function(p) data.table(pool = p, seed = names(sets[[p]]))))
res <- parallel::mclapply(seq_len(nrow(jobs)), function(i) fit_one(jobs$pool[i], jobs$seed[i]), mc.cores = N_CORES)
bad <- vapply(res, inherits, TRUE, "try-error")
if (any(bad)) stop("placebo fits failed: ", paste(jobs$seed[bad], collapse = ", "))
pseudo <- rbindlist(res)

center <- ft$comparison[rule == "amended" & target == "CENTER" & estimator == "ascm" & pool %in% POOLS,
                        .(full_pre_rmspe = fit_rmspe[fit == "full pre"], holdout_rmse = holdout_rmse[fit == "holdout"],
                          holdout_bias = holdout_bias[fit == "holdout"]), by = pool]
pseudo <- merge(pseudo, center[, .(pool, center_full_pre_rmspe = full_pre_rmspe)], by = "pool")
pseudo[, `:=`(scale = pmax(full_pre_rmspe, center_full_pre_rmspe), floor_binding = full_pre_rmspe < center_full_pre_rmspe)]
pseudo[, `:=`(scaled_bias = holdout_bias / scale, scaled_rmse = holdout_rmse / scale)]
center[, `:=`(scale = full_pre_rmspe, scaled_bias = holdout_bias / full_pre_rmspe, scaled_rmse = holdout_rmse / full_pre_rmspe)]
# Where CENTER's own full pre-period RMSPE is below 0.001 (an interpolating fit), the floor adds nothing and
# the scaled statistics are degenerate: they are withheld (NA) and flagged, pending Leonel's decision.
# The plan's fit filter (section 7: pseudo-target full pre RMSPE at most three times CENTER's) is reported
# alongside, with unscaled shares after filtering. The scale is the full pre-period RMSPE, as specified;
# the training RMSPE would be the matching scale for a holdout gap.
pseudo[, passes_fit_filter := full_pre_rmspe <= 3 * center_full_pre_rmspe]
placement <- rbindlist(lapply(POOLS, function(p) {
  x <- pseudo[pool == p]; cc <- center[pool == p]; xf <- x[passes_fit_filter == TRUE]
  degenerate <- cc$scale < 0.001
  data.table(pool = p, pseudo_neighbourhoods = nrow(x), floor_binding = sum(x$floor_binding),
    own_rmspe_below_0.001 = sum(x$full_pre_rmspe < 0.001), lambda_at_grid_edge = sum(x$lambda_at_grid_edge),
    center_scale = cc$scale,
    scaled_statistics = if (degenerate) "withheld: CENTER's own RMSPE below 0.001, floor degenerate" else "reported",
    center_holdout_bias = cc$holdout_bias, center_holdout_rmse = cc$holdout_rmse,
    center_scaled_bias = if (degenerate) NA_real_ else cc$scaled_bias,
    center_scaled_rmse = if (degenerate) NA_real_ else cc$scaled_rmse,
    share_abs_scaled_bias_at_least_center = if (degenerate) NA_real_ else mean(abs(x$scaled_bias) >= abs(cc$scaled_bias)),
    share_scaled_rmse_at_least_center = if (degenerate) NA_real_ else mean(x$scaled_rmse >= cc$scaled_rmse),
    share_abs_bias_at_least_center_unscaled = mean(abs(x$holdout_bias) >= abs(cc$holdout_bias)),
    share_rmse_at_least_center_unscaled = mean(x$holdout_rmse >= cc$holdout_rmse),
    pass_fit_filter = nrow(xf), excluded_by_fit_filter = nrow(x) - nrow(xf),
    filtered_share_abs_bias_at_least_center_unscaled = if (nrow(xf)) mean(abs(xf$holdout_bias) >= abs(cc$holdout_bias)) else NA_real_,
    pseudo_bias_p10 = quantile(x$holdout_bias, 0.1), pseudo_bias_median = median(x$holdout_bias), pseudo_bias_p90 = quantile(x$holdout_bias, 0.9),
    pseudo_pre_mean_min = min(x$pre_mean), pseudo_pre_mean_max = max(x$pre_mean))
}))
pseudo[center_full_pre_rmspe < 0.001, `:=`(scaled_bias = NA_real_, scaled_rmse = NA_real_)]

saveRDS(list(sets = sets, pseudo = pseudo, center = center, placement = placement), file.path(AMEND2_DATA, "placebos.rds"))
fwrite(pseudo, file.path(AMEND2_OUT, "placebo_fits.csv"))
fwrite(placement, file.path(AMEND2_OUT, "placebo_placement.csv"))
fwrite(rbindlist(lapply(names(sets), function(p) rbindlist(lapply(names(sets[[p]]), function(s)
  data.table(pool = p, seed = s, grid_id = sets[[p]][[s]]))))), file.path(AMEND2_OUT, "placebo_neighbourhoods.csv"))
g <- ggplot(pseudo, aes(holdout_bias)) + geom_histogram(bins = 30, fill = "grey60") +
  geom_vline(data = center, aes(xintercept = holdout_bias), colour = "#b2182b", linewidth = 0.8) +
  facet_wrap(~pool, ncol = 1, scales = "free_y") +
  labs(title = "Placebo neighbourhoods: mean holdout gap, June to November 2023 (levels, percentage points)",
       subtitle = "Grey: seven-cell pseudo-neighbourhoods (overlapping). Red: CENTER (historic center, road-weighted). Descriptive; no p-value.",
       x = "Mean holdout gap (actual minus synthetic)", y = "Pseudo-neighbourhoods") + theme_minimal(base_size = 9)
ggsave(file.path(AMEND2_OUT, "placebo_holdout_bias.png"), g, width = 8, height = 6, dpi = 150, bg = "white")
print(placement)
