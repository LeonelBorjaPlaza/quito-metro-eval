# Fitting functions for Step 1 (plan section 6). augsynth only; no custom estimator.
suppressPackageStartupMessages(library(augsynth))
stopifnot(packageDescription("augsynth")$RemoteSha == "65c5a6f34f4e4a8b1011182fe12309ef022d992f")

# Long data for augsynth: the target plus donors, `fit_months` as the fitting period and
# `post_months` as the predicted period. Time is an integer index, so a held-out block can be
# placed last (weights, unit means and the ridge step do not depend on the order of periods).
# post_months = NULL adds one placeholder period with value `fill`: augsynth needs a treated
# period, and the weights are functions of the fitting period only (checked in full_fit()).
as_long <- function(y1, Y0, fit_months, post_months, fill = 0) {
  months <- c(fit_months, post_months)
  stopifnot(!anyNA(y1[as.character(months)]), !anyNA(Y0[, as.character(months)]))
  Y <- rbind(TARGET = y1[as.character(months)], Y0[, as.character(months), drop = FALSE])
  if (is.null(post_months)) Y <- cbind(Y, fill)
  n_fit <- length(fit_months)
  # Integer units (target 0, donors 1..n in the order of Y0's rows): augsynth sorts units and
  # drops their names, so integers make the order of its weight vector unambiguous.
  id <- rep(seq_len(nrow(Y)) - 1L, times = ncol(Y))
  data.frame(unit = id, time = rep(seq_len(ncol(Y)), each = nrow(Y)),
             y = as.vector(Y), trt = as.integer(id == 0L & rep(seq_len(ncol(Y)), each = nrow(Y)) > n_fit))
}

fit_asc <- function(y1, Y0, fit_months, post_months, lambda = NULL, method = "ridge", fill = 0) {
  d <- as_long(y1, Y0, fit_months, post_months, fill)
  fit <- suppressMessages(switch(method,
    ridge = augsynth(y ~ trt, unit, time, d, progfunc = "Ridge", scm = TRUE, fixedeff = TRUE, lambda = lambda),
    scm = augsynth(y ~ trt, unit, time, d, progfunc = "None", scm = TRUE, fixedeff = FALSE)))
  months <- c(fit_months, if (is.null(post_months)) NA_integer_ else post_months)
  synth <- as.numeric(predict(fit))
  actual <- c(y1[as.character(fit_months)], if (is.null(post_months)) NA_real_ else y1[as.character(post_months)])
  path <- data.table(month = months, period = rep(c("fit", "post"), c(length(fit_months), length(months) - length(fit_months))),
                     actual = actual, synthetic = synth, gap = actual - synth)
  if (is.null(post_months)) path <- path[period == "fit"]
  stopifnot(identical(as.integer(fit$data$trt), c(1L, rep(0L, nrow(Y0)))),
            isTRUE(all.equal(unname(fit$data$X[-1, , drop = FALSE]), unname(Y0[, as.character(fit_months), drop = FALSE]))))
  w <- setNames(as.numeric(fit$weights), rownames(Y0))
  synw <- if (is.null(fit$synw)) w else setNames(as.numeric(fit$synw), names(w))
  mhat_c <- fit$mhat[fit$data$trt == 0, 1]
  mhat_t <- fit$mhat[fit$data$trt == 1, 1]
  list(fit = fit, path = path, weights = w, synw = synw, lambda = if (method == "ridge") fit$lambda else NA_real_,
       intercept = if (method == "ridge") mhat_t - sum(w * mhat_c) else 0)
}

# Donor-mean difference-in-differences benchmark, equal weights over the pool.
fit_did <- function(y1, Y0, fit_months, post_months) {
  months <- c(fit_months, post_months)
  dm <- colMeans(Y0[, as.character(months), drop = FALSE])
  synth <- mean(y1[as.character(fit_months)]) + dm - mean(dm[as.character(fit_months)])
  actual <- y1[as.character(months)]
  list(path = data.table(month = months, period = rep(c("fit", "post"), c(length(fit_months), length(post_months))),
                         actual = actual, synthetic = synth, gap = actual - synth))
}

rmse <- function(g) sqrt(mean(g^2))

# Months where the target has a valid unit-month; missing months are left out, never filled.
available <- function(y1, months) months[!is.na(y1[as.character(months)])]

# Leave-one-block-out tuning of the ridge penalty on the training months (plan section 6).
# Blocks are three calendar months; a target's missing months are then removed from their block.
lobo_blocks <- function(months) split(months, ceiling(seq_along(months) / 3))
tune_lambda <- function(y1, Y0, train_months) {
  blocks <- Filter(length, lapply(lobo_blocks(train_months), function(b) available(y1, b)))
  train_months <- available(y1, train_months)
  grid <- fit_asc(y1, Y0, train_months, NULL)$fit$lambdas
  errs <- rbindlist(lapply(seq_along(grid), function(i) rbindlist(lapply(seq_along(blocks), function(b) {
    f <- fit_asc(y1, Y0, setdiff(train_months, blocks[[b]]), blocks[[b]], lambda = grid[i])
    f$path[period == "post", .(lambda_index = i, lambda = grid[i], fold = b, month, gap)]
  }))))
  by_lambda <- errs[, .(mse = mean(gap^2)), by = .(lambda_index, lambda)]
  best <- by_lambda[which.min(mse)]
  list(lambda = best$lambda, at_grid_edge = best$lambda_index %in% range(by_lambda$lambda_index),
       grid = by_lambda, folds = errs[lambda_index == best$lambda_index,
       .(fold_rmse = rmse(gap), n_months = .N, months = paste(range(month), collapse = "-")), by = fold])
}

# Full-period fit: placeholder check that two fills give identical weights and fitted path.
full_fit <- function(y1, Y0, months, lambda, method = "ridge") {
  a <- fit_asc(y1, Y0, months, NULL, lambda, method, fill = 0)
  b <- fit_asc(y1, Y0, months, NULL, lambda, method, fill = 1)
  stopifnot(isTRUE(all.equal(a$weights, b$weights, tolerance = 1e-8)),
            isTRUE(all.equal(a$path$synthetic, b$path$synthetic, tolerance = 1e-8)))
  a
}

# Tests the premise of the fold construction: weights and intercept do not depend on the order
# in which the fitting months are given.
check_order_invariance <- function(y1, Y0, fit_months, post_months, lambda, seed = 20260927) {
  set.seed(seed)
  a <- fit_asc(y1, Y0, fit_months, post_months, lambda)
  b <- fit_asc(y1, Y0, sample(fit_months), post_months, lambda)
  stopifnot(isTRUE(all.equal(a$weights, b$weights, tolerance = 1e-8)),
            isTRUE(all.equal(a$intercept, b$intercept, tolerance = 1e-8)),
            isTRUE(all.equal(a$path[period == "post", synthetic], b$path[period == "post", synthetic], tolerance = 1e-8)))
  invisible(TRUE)
}

# Lag-1 autocorrelation over calendar-adjacent months only (plan section 5). NA when the
# residuals are numerically zero (an interpolating fit), where a correlation is meaningless.
rho_calendar <- function(months, gap, all_months, tol = 1e-4) {
  if (rmse(gap) < tol) return(NA_real_)
  g <- setNames(rep(NA_real_, length(all_months)), all_months)
  g[as.character(months)] <- gap
  ok <- !is.na(g[-1]) & !is.na(g[-length(g)])
  cor(g[-1][ok], g[-length(g)][ok])
}

weight_stats <- function(w, synw) {
  a <- abs(w) / sum(abs(w))
  data.table(sum_weights = sum(w), total_negative = sum(w[w < 0]), sum_abs = sum(abs(w)),
             n_nonzero_scm = sum(abs(synw) > 1e-6), hhi_abs = sum(a^2), effective_n = 1 / sum(a^2),
             top5_abs_share = sum(sort(a, decreasing = TRUE)[1:min(5, length(a))]))
}
