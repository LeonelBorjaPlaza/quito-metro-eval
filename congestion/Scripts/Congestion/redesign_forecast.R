# Forecasting engine for the Amendment 5 estimator menu (contest, checks, MDE). Pre period only.
# Every series is on the decided scale: in proportions, each unit's block series is divided by its own
# mean over the fitting months, so the counterfactual is rebuilt in index points as that mean times the
# forecast ratio. The menu (Amendment 5, item 5):
#   sc     default: synthetic control, weights >= 0 summing to one (augsynth, progfunc None), fitted on the
#          morning and evening series stacked; on proportions each unit's block mean over the fit is 1, so
#          the intercept is absorbed by the normalization; in levels each block is demeaned first
#   sdid   synthetic difference-in-differences (synthdid 0.0.9) on the peak series
#   ridge  augsynth ridge with unit intercept on the peak series, penalty = the largest on augsynth's grid
#          whose leave-one-block-out error is within 5 percent of the best
#   did    difference-in-differences against the equal-weight donor mean, peak series
suppressPackageStartupMessages(library(synthdid))
stopifnot(packageDescription("synthdid")$RemoteSha == "70c1ce3eac58e28c30b67435ca377bb48baa9b8a")
METHODS <- c("sc", "sdid", "ridge", "did")
SIMPLICITY <- c("did", "sc", "sdid", "ridge")   # ties go to the simpler estimator

# mats: list of unit-by-month matrices (levels) for blocks peak, morning, evening; colnames = months.
scale_block <- function(M, fit_months, scale) {
  mu <- rowMeans(M[, as.character(fit_months), drop = FALSE])
  if (scale == "proportions") { stopifnot(all(mu > 0)); M / mu } else M - mu
}

# Forecast the target's peak series at fc_months; returns forecasts and errors on the fitting scale and
# in index points.
forecast_one <- function(method, target, donors, mats, fit_months, fc_months, scale) {
  fm <- as.character(fit_months); cm <- as.character(fc_months)
  units <- c(target, donors)
  P <- scale_block(mats$peak[units, , drop = FALSE], fit_months, scale)
  fc <- switch(method,
    did = colMeans(P[donors, cm, drop = FALSE]),
    sc = {
      S <- cbind(scale_block(mats$morning[units, , drop = FALSE], fit_months, scale)[, fm, drop = FALSE],
                 scale_block(mats$evening[units, , drop = FALSE], fit_months, scale)[, fm, drop = FALSE])
      colnames(S) <- c(paste0("m", fm), paste0("e", fm))
      y1 <- S[target, ]; Y0 <- S[donors, , drop = FALSE]
      f <- fit_asc(y1, Y0, colnames(S), NULL, method = "scm")
      w <- f$weights[donors]
      stopifnot(abs(sum(w) - 1) < 1e-6, all(w > -1e-6))
      colSums(w * P[donors, cm, drop = FALSE])
    },
    ridge = {
      y1 <- P[target, c(fm, cm)]; Y0 <- P[donors, c(fm, cm), drop = FALSE]
      tune <- tune_lambda(y1, Y0, fit_months)
      g <- tune$grid
      lam <- max(g$lambda[g$mse <= 1.05 * min(g$mse)])
      f <- fit_asc(y1, Y0, fit_months, fc_months, lambda = lam)
      setNames(f$path[period == "post", synthetic], cm)
    },
    sdid = {
      Y <- rbind(P[donors, c(fm, cm), drop = FALSE], P[target, c(fm, cm), drop = FALSE])
      est <- synthdid_estimate(Y, N0 = length(donors), T0 = length(fm))
      eff <- as.numeric(synthdid_effect_curve(est))
      setNames(P[target, cm] - eff, cm)
    })
  base <- mean(mats$peak[target, fm])
  actual <- P[target, cm]
  err <- actual - fc[cm]
  data.table(month = as.integer(cm), horizon = seq_along(cm), forecast = fc[cm], actual = actual, error = err,
             error_index_points = if (scale == "proportions") err * base else err, fit_mean = base)
}

# Build level matrices for a set of units from the long series (unit, date, value, block).
level_mats <- function(series, units) {
  lapply(setNames(c("peak", "morning", "evening"), c("peak", "morning", "evening")), function(b) {
    d <- dcast(series[block == b & unit %in% units], unit ~ date, value.var = "value")
    M <- as.matrix(d[, -1]); rownames(M) <- d$unit
    stopifnot(identical(colnames(M), as.character(PRE_MONTHS)))
    M[units, , drop = FALSE]
  })
}
