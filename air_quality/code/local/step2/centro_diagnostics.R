#=========================================================
#  centro_diagnostics.R
#  Step 2 diagnostics of air_quality/docs/revision_plan.md, 3A.3 items 4-8:
#    4 leave-one-donor-out for Centro (M8b, all three windows)
#    5 gap plot (M8b, full window)
#    6 residual autocorrelation of the M8b gaps (lags 1-4; descriptive)
#    7 pseudo-openings inside the pre-period (M8b; weeks 20, 22, ..., 44)
#    8 block conformal p-value beside the iid one (PM2.5: M7, M8, M8b, M9;
#      gases: M8b; all three windows)
#
#  Run in the same R session right after a setup script (03, 05, 07 or 09),
#  main specification only (no AQ_SENS), from air_quality/, for example:
#    Rscript -e 'source("code/local/05_analysis_setupCO.R"); source("code/local/step2/centro_diagnostics.R")'
#  Output: output/local/step2/diagnostics/*_<POL>.csv and figures/gap_M8b_<POL>.{png,pdf}
#
#  Estimation calls are the cross-sample script's (augsynth, progfunc = "Ridge",
#  scm = TRUE, fixedeff as the specification says); windows come from its
#  make_samples(). Conformal p-values: iid uses 1,000 random permutations and
#  does not count the observed order, so it can be 0 and its smallest nonzero
#  value is 0.001; block uses the T cyclic shifts of the sample's weeks,
#  including the identity, so its smallest value is 1/T. Every conformal call
#  here is reseeded (set.seed(12345)), so its iid p-value ("p_iid_reseeded")
#  can differ by simulation noise from the cross-sample table's p for the same
#  estimate; the paper's p-values are the cross-sample table's.
#=========================================================

.need <- c("df", "t_int", "WEATHER_VARS", "blackout_week_ids", "BLACKOUT_START", "ROOT_DIR", "POLLUTANT")
stopifnot(all(vapply(.need, exists, logical(1))))
stopifnot(Sys.getenv("AQ_SENS") == "")
suppressMessages({ library(dplyr); library(tidyr); library(readr); library(augsynth); library(ggplot2) })

POL <- toupper(POLLUTANT)
out_dir <- file.path(ROOT_DIR, "output", "local", "step2", "diagnostics")
fig_dir <- file.path(ROOT_DIR, "output", "local", "step2", "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# make_samples() from the cross-sample script (definition only; identical in all four)
for (e in parse(file.path(ROOT_DIR, "code", "local", "04_PM2_5_crosssample.R"))) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("make_samples"))) eval(e)
}
samples <- make_samples()
names(samples) <- vapply(samples, `[[`, "", "name")

# One fit: the cross-sample call, with the conformal type as an argument
fit <- function(panel, t_int_s, treated_set, exclude, use_fe, type = "iid") {
  d <- panel %>% filter(!estacion %in% exclude) %>%
    mutate(.treated = as.integer(estacion %in% treated_set & week_id >= t_int_s))
  form <- as.formula(paste("ln_outcome ~ .treated |", paste(WEATHER_VARS, collapse = " + ")))
  aug <- augsynth(form, unit = estacion, time = week_id, data = d, t_int = t_int_s,
                  progfunc = "Ridge", scm = TRUE, fixedeff = use_fe)
  set.seed(12345)
  summ <- summary(aug, inf_type = "conformal", type = type)
  wks <- sort(unique(d$week_id))
  y1 <- d %>% filter(estacion %in% treated_set) %>% group_by(week_id) %>%
    summarise(y = mean(ln_outcome, na.rm = TRUE), .groups = "drop")
  gap <- y1$y[match(wks, y1$week_id)] - as.numeric(predict(aug, att = FALSE))
  list(att = as.numeric(summ$average_att$Estimate),
       p = suppressWarnings(as.numeric(summ$average_att$p_val)),
       n_weeks = length(wks), wks = wks, gap = gap, pre = wks < t_int_s,
       weights = paste(sprintf("%s:%.4f", rownames(aug$weights), as.numeric(aug$weights)), collapse = ";"))
}
stations <- sort(unique(df$estacion))

#---- 8. Block conformal beside iid (and the M8b fits reused below) ----
specs <- tibble::tribble(
  ~spec, ~treated,           ~exclude,
  "M7",  "centro,belisario", "",
  "M8",  "centro",           "belisario",
  "M8b", "centro",           "",
  "M9",  "belisario",        "centro")
if (POLLUTANT != "pm25") specs <- specs %>% filter(spec == "M8b")
blk <- list(); m8b_full <- NULL
for (i in seq_len(nrow(specs))) for (smp in samples) {
  tset <- strsplit(specs$treated[i], ",")[[1]]
  exc <- if (nzchar(specs$exclude[i])) specs$exclude[i] else character(0)
  fi <- tryCatch(fit(smp$panel, smp$t_int_s, tset, exc, TRUE, "iid"), error = function(e) NULL)
  fb <- tryCatch(fit(smp$panel, smp$t_int_s, tset, exc, TRUE, "block"), error = function(e) NULL)
  if (is.null(fi) || is.null(fb)) { cat(sprintf("  ERR block %s %s\n", specs$spec[i], smp$name)); next }
  # a block p-value is a multiple of 1/T; guards against `type` not reaching conformal_inf
  stopifnot(abs(fb$p * fb$n_weeks - round(fb$p * fb$n_weeks)) < 1e-8)
  if (specs$spec[i] == "M8b" && smp$name == "full") m8b_full <- fi
  blk[[length(blk) + 1]] <- tibble(pollutant = POL, spec = specs$spec[i], sample = smp$name,
                                   att_log = fi$att, p_iid_reseeded = fi$p, p_iid_smallest_nonzero = 0.001,
                                   p_block = fb$p, p_block_smallest = 1 / fb$n_weeks, n_weeks = fb$n_weeks)
  cat(sprintf("  block %s %s: att %+.4f p_iid_reseeded %.3f p_block %.3f (T=%d)\n",
              specs$spec[i], smp$name, fi$att, fi$p, fb$p, fb$n_weeks))
}
write_csv(bind_rows(blk), file.path(out_dir, sprintf("block_conformal_%s.csv", POL)))

#---- 4. Leave-one-donor-out for Centro (M8b) ----
loo <- list()
donors <- setdiff(stations, "centro")
for (smp in samples) {
  full <- fit(smp$panel, smp$t_int_s, "centro", character(0), TRUE)
  loo[[length(loo) + 1]] <- tibble(pollutant = POL, sample = smp$name, dropped = "(none)",
                                   att_log = full$att, p_iid_reseeded = full$p, weights = full$weights)
  for (dn in donors) {
    f <- tryCatch(fit(smp$panel, smp$t_int_s, "centro", dn, TRUE), error = function(e) NULL)
    loo[[length(loo) + 1]] <- tibble(pollutant = POL, sample = smp$name, dropped = dn,
                                     att_log = if (is.null(f)) NA_real_ else f$att,
                                     p_iid_reseeded = if (is.null(f)) NA_real_ else f$p,
                                     weights = if (is.null(f)) NA_character_ else f$weights)
  }
  cat(sprintf("  LOO %s done\n", smp$name))
}
loo <- bind_rows(loo) %>% mutate(att_pct = (exp(att_log) - 1) * 100)
write_csv(loo, file.path(out_dir, sprintf("loo_centro_M8b_%s.csv", POL)))

#---- 5 and 6. Gaps (M8b, full window), their autocorrelation, and the plot ----
wk_dates <- df %>% distinct(week_id, week_date) %>% arrange(week_id)
gaps <- tibble(week_id = m8b_full$wks, gap = m8b_full$gap, pre = m8b_full$pre) %>%
  left_join(wk_dates, by = "week_id") %>%
  mutate(blackout = week_id %in% blackout_week_ids)
write_csv(gaps %>% mutate(pollutant = POL), file.path(out_dir, sprintf("gaps_M8b_full_%s.csv", POL)))
acf_tab <- bind_rows(lapply(c(TRUE, FALSE), function(is_pre) {
  g <- gaps$gap[gaps$pre == is_pre]
  a <- acf(g, lag.max = 4, plot = FALSE, na.action = na.pass)$acf[2:5]
  # lags count kept weeks (weeks dropped by the all-stations rule are skipped)
  tibble(pollutant = POL, period = if (is_pre) "pre" else "post", weeks = length(g),
         lag = 1:4, autocorrelation = round(a, 4))
}))
write_csv(acf_tab, file.path(out_dir, sprintf("acf_gaps_M8b_%s.csv", POL)))
tw <- wk_dates$week_date[wk_dates$week_id == t_int]
p <- ggplot(gaps, aes(as.Date(week_date), gap)) +
  geom_rect(data = gaps %>% filter(blackout), inherit.aes = FALSE,
            aes(xmin = as.Date(week_date), xmax = as.Date(week_date) + 7, ymin = -Inf, ymax = Inf),
            fill = "grey85") +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = as.Date(tw), colour = "#E41A1C", linetype = "dashed") +
  geom_line(colour = "#2B2B2B") + geom_point(size = 0.8, colour = "#2B2B2B") +
  labs(x = NULL, y = "Centro minus synthetic Centro (log points)",
       title = sprintf("%s, M8b, full window: weekly gap", POL),
       subtitle = "Dashed line: treatment week. Grey: blackout weeks dropped by the donut sample.") +
  theme_minimal(base_size = 10)
ggsave(file.path(fig_dir, sprintf("gap_M8b_%s.png", POL)), p, width = 8, height = 4, dpi = 200)
ggsave(file.path(fig_dir, sprintf("gap_M8b_%s.pdf", POL)), p, width = 8, height = 4)

#---- 7. Pseudo-openings inside the pre-period (M8b) ----
pre_panel <- df %>% filter(week_id < t_int)
stopifnot(n_distinct(pre_panel$week_id) == t_int - 1, t_int - 44 >= 9)
ps <- bind_rows(lapply(seq(20, 44, by = 2), function(tp) {
  f <- tryCatch(fit(pre_panel, tp, "centro", character(0), TRUE), error = function(e) NULL)
  tibble(pollutant = POL, pseudo_week = tp, pre_weeks = tp - 1, post_weeks = t_int - tp,
         att_log = if (is.null(f)) NA_real_ else f$att, p_iid_reseeded = if (is.null(f)) NA_real_ else f$p)
}))
write_csv(ps, file.path(out_dir, sprintf("pseudo_openings_M8b_%s.csv", POL)))
ps_sum <- ps %>% summarise(pollutant = POL, dates = n(),
                           fitted = sum(!is.na(p_iid_reseeded)),
                           reject_05 = mean(p_iid_reseeded <= 0.05, na.rm = TRUE),
                           reject_10 = mean(p_iid_reseeded <= 0.10, na.rm = TRUE),
                           share_negative = mean(att_log < 0, na.rm = TRUE))
write_csv(ps_sum, file.path(out_dir, sprintf("pseudo_openings_M8b_summary_%s.csv", POL)))
print(ps_sum)
cat(sprintf("\n=== centro diagnostics done (%s) ===\n", POL))
