# Amendment 5, item 3: the scale test, decided before any other choice.
# Units: main-pool donor tiles (DMQ, quality rule, outside CENTER, its buffer, CORRIDOR, RING and
# BELISARIO, complete peak index over the pre period). For each tile: the standard deviation of
# calendar-adjacent monthly changes of the peak index (changes touching June 2022 or November 2023
# excluded) and the mean over the usable pre-period months. OLS of log(sd) on log(mean) across tiles,
# slope with its classical 95 percent interval (an interval, not a test).
# Rule: proportions if the slope exceeds 0.5 or its interval includes 0.5; levels only if the whole
# interval lies below 0.5.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/step1_loader.R")
source("Scripts/Congestion/amend2_helpers.R")
source("Scripts/Congestion/redesign_helpers.R")
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
pr <- panel$rules$amended
con <- duck()
cov <- load_coverage_2022(con)
tl <- build_tiles(con, pr, geog, cov)
DBI::dbDisconnect(con, shutdown = TRUE)

peak <- tile_series(pr$cell_block, tl$members[tile %in% tl$tiles[donor_eligible == TRUE, tile]], "peak")
complete <- peak[, .(complete = !anyNA(value)), by = tile][complete == TRUE, tile]
main <- tl$tiles[donor_eligible == TRUE & dmq == TRUE & tile %in% complete, tile]
x <- peak[tile %in% main][order(tile, date)]
x[, idx := match(date, PRE_MONTHS)]
x[, `:=`(prev_value = shift(value), prev_idx = shift(idx), prev_date = shift(date)), by = tile]
ch <- x[!is.na(prev_idx) & idx == prev_idx + 1L & !(date %in% EXCL_MONTHS) & !(prev_date %in% EXCL_MONTHS),
        .(change = value - prev_value), by = .(tile, date)]
stats <- merge(ch[, .(sd_change = sd(change), n_changes = .N), by = tile],
               x[date %in% USABLE_MONTHS, .(pre_mean = mean(value)), by = tile], by = "tile")
stopifnot(all(stats$n_changes == stats$n_changes[1]), all(stats$pre_mean > 0), all(stats$sd_change > 0))
fit <- lm(log(sd_change) ~ log(pre_mean), data = stats)
ci <- confint(fit, "log(pre_mean)", level = 0.95)
slope <- unname(coef(fit)[2])
decision <- if (slope > 0.5 || (ci[1] <= 0.5 && ci[2] >= 0.5)) "proportions" else "levels"
out <- data.table(units = "main-pool donor tiles (DMQ, quality rule, complete peak index)", tiles = nrow(stats),
  changes_per_tile = stats$n_changes[1], slope = slope, ci95_low = ci[1], ci95_high = ci[2],
  rule = "proportions if slope > 0.5 or the 95% interval includes 0.5; levels only if the whole interval lies below 0.5",
  decision = decision, interval_type = "classical OLS t interval across tiles")
# The decision was recorded first (commit bd2f2d6). A rerun must reproduce it; it may never change it.
dec_path <- file.path(REDESIGN_OUT, "scale_decision.csv")
if (file.exists(dec_path)) {
  tmp <- tempfile(fileext = ".csv"); fwrite(out, tmp)
  if (!identical(readLines(tmp), readLines(dec_path)))
    stop("The rerun scale test differs from the committed decision in ", dec_path, "; it is not overwritten")
}
fwrite(out, dec_path)
# The pool behind the decision (tile ids only, no provider values); 41 asserts its main pool equals it.
fwrite(data.table(tile = sort(main)), file.path(REDESIGN_OUT, "scale_tiles.csv"))
saveRDS(list(stats = stats, fit = fit, decision = out), file.path(REDESIGN_DATA, "scale.rds"))
p <- ggplot(stats, aes(log(pre_mean), log(sd_change))) + geom_point(alpha = 0.6) + geom_smooth(method = "lm", formula = y ~ x, se = TRUE) +
  geom_abline(slope = 0.5, intercept = coef(fit)[1] + (slope - 0.5) * mean(log(stats$pre_mean)), linetype = "dashed", colour = "grey40") +
  labs(title = "Scale test across main-pool donor tiles (pre period, peak index)",
       subtitle = sprintf("Slope %.3f, 95%% interval %.3f to %.3f; %d tiles. Dashed: slope 0.5 through the mean. Decision: %s.", slope, ci[1], ci[2], nrow(stats), decision),
       x = "log pre-period mean", y = "log sd of monthly changes") + theme_minimal(base_size = 9)
ggsave(file.path(REDESIGN_OUT, "scale_test.png"), p, width = 7, height = 5, dpi = 150, bg = "white")
print(out)
