# Amendment 5, item 5: the estimator contest, scored by rolling-origin forecasts on placebo tiles.
# Every main-pool tile acts in turn as the target, with the other main-pool tiles as donors (its own
# area is kept out). Cut-offs at usable months 12 to 20 (June 2022 and November 2023 are not usable);
# each cut-off forecasts the next three usable months that exist. Errors are on the decided scale (in
# proportions: shares of the tile's fit-window mean) and in index points. CENTER is not scored.
# Rule: the default (sc) stands unless another estimator lowers the mean squared error on the fitting
# scale by at least 10 percent; ties go to the simpler estimator (did, sc, sdid, ridge).
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_fit_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
source("Scripts/Congestion/redesign_forecast.R")
u <- readRDS(file.path(REDESIGN_DATA, "units.rds"))
SCALE <- u$scale$decision
main <- u$unit_meta[type == "donor tile", unit]
mats <- level_mats(u$series, main)
CUTOFFS <- 12:20
N_CORES <- 4L

jobs <- CJ(target = main, cutoff = CUTOFFS, method = METHODS)
res <- parallel::mclapply(seq_len(nrow(jobs)), function(i) {
  j <- jobs[i]
  fit_m <- USABLE_MONTHS[seq_len(j$cutoff)]
  fc_m <- USABLE_MONTHS[(j$cutoff + 1):min(j$cutoff + 3, length(USABLE_MONTHS))]
  out <- tryCatch(forecast_one(j$method, j$target, setdiff(main, j$target), mats, fit_m, fc_m, SCALE),
                  error = function(e) data.table(month = NA_integer_, horizon = NA_integer_, forecast = NA_real_, actual = NA_real_,
                                                 error = NA_real_, error_index_points = NA_real_, fit_mean = NA_real_, failure = conditionMessage(e)))
  cbind(j, out)
}, mc.cores = N_CORES)
check_parallel(res, nrow(jobs))
fc <- rbindlist(res, fill = TRUE)
failures <- if ("failure" %in% names(fc)) fc[!is.na(failure)] else fc[0]
if (nrow(failures)) stop("forecast failures: ", nrow(failures), "; first: ", failures$failure[1])
n_expected <- length(main) * length(METHODS) * sum(pmin(length(USABLE_MONTHS) - CUTOFFS, 3L))
stopifnot(nrow(fc) == n_expected)

# "tile index points": each error in its own tile's index points (bases differ across tiles).
NOTES <- c(did = "signed error is zero by identity: with every tile as target against the mean of the others, errors sum to zero each month; compare bias only among sc, sdid and ridge",
           sdid = "synthdid fits its time weights on the donors over all forecast months together, so the horizon-1 forecast uses donor values of later horizons (no target data)",
           sc = "", ridge = "")
by_h <- fc[, .(forecasts = .N, mse = mean(error^2), mean_signed_error = mean(error),
               mse_tile_index_points = mean(error_index_points^2), mean_signed_error_tile_index_points = mean(error_index_points)),
           by = .(method, horizon)][order(method, horizon)]
overall <- fc[, .(forecasts = .N, tiles = uniqueN(target), mse = mean(error^2), mean_signed_error = mean(error),
                  share_errors_negative = mean(error < 0), mse_tile_index_points = mean(error_index_points^2),
                  mean_signed_error_tile_index_points = mean(error_index_points)), by = method]
overall[, mse_relative_to_sc := mse / overall[method == "sc", mse]]
overall[, note := NOTES[method]]
# Decision: the default stands unless another estimator lowers MSE by at least 10 percent; among those
# that do, the lowest MSE wins, with ties (within 10 percent of each other) to the simpler one.
challengers <- overall[method != "sc" & mse <= 0.9 * overall[method == "sc", mse]]
winner <- if (!nrow(challengers)) "sc" else {
  best <- min(challengers$mse)
  near <- challengers[mse <= best / 0.9, method]
  SIMPLICITY[SIMPLICITY %in% near][1]
}
decision <- data.table(scale = SCALE, tiles = length(main), cutoffs = paste(range(CUTOFFS), collapse = " to "),
  default = "sc", winner = winner,
  rule = paste("default (sc) stands unless another estimator lowers mean squared error (fitting scale) by at least 10 percent;",
               "among such challengers, those within a factor 1/0.9 of the best count as tied, and ties go to the simpler (did, sc, sdid, ridge)"))

saveRDS(list(forecasts = fc, by_horizon = by_h, overall = overall, decision = decision), file.path(REDESIGN_DATA, "contest.rds"))
fwrite(by_h, file.path(REDESIGN_OUT, "contest_by_horizon.csv"))
fwrite(overall, file.path(REDESIGN_OUT, "contest_overall.csv"))
fwrite(decision, file.path(REDESIGN_OUT, "contest_decision.csv"))
print(overall); print(by_h); print(decision)
