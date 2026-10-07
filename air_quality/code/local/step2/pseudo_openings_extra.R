#=========================================================
#  pseudo_openings_extra.R
#  Check d of air_quality/docs/revision_plan.md, section 3B: pseudo-openings
#  inside the PM2.5 pre-period (M8b), each with the iid and the block
#  conformal p-value, on the main panel and on the S4 panel (2023 rationing
#  weeks dropped). A diagnostic of the existing specification.
#
#  Run in the same R session right after 03_analysis_setupPM2.5.R, from air_quality/:
#    main: Rscript -e 'source("code/local/03_analysis_setupPM2.5.R"); source("code/local/step2/pseudo_openings_extra.R")'
#    S4:   AQ_SENS=S4 AQ_DROP_RATIONING=1 Rscript -e '<same>'
#  Input: df, t_int, WEATHER_VARS, ROOT_DIR from the setup script; on the main
#  panel also output/local/step2/diagnostics/pseudo_openings_M8b_PM25.csv
#  (reproduction check).
#  Output: output/local/step2/diagnostics/pseudo_openings_block_{main,S4}_PM25.csv
#          and pseudo_openings_block_summary_{main,S4}_PM25.csv
#
#  The estimation call is fit() of centro_diagnostics.R, taken by parse (the
#  definition only), so it is the same M8b call with set.seed(12345) before
#  each conformal call. Floors: iid smallest nonzero 0.001 (0 attainable);
#  block 1/T, T = weeks in the pseudo sample. The pseudo-post windows are
#  nested (all end at the last pre-period week). Any failed fit stops the run.
#  Block test levels: p <= 0.05 and p <= 0.10 are, with T = 52, levels 2/52 and
#  5/52; with T = 47, 2/47 and 4/47 (columns level_05, level_10).
#=========================================================

.need <- c("df", "t_int", "WEATHER_VARS", "ROOT_DIR", "POLLUTANT")
stopifnot(all(vapply(.need, exists, logical(1))), POLLUTANT == "pm25")
SENS <- Sys.getenv("AQ_SENS", "")
stopifnot(SENS %in% c("", "S4"), (SENS == "S4") == (Sys.getenv("AQ_DROP_RATIONING", "") == "1"))
RUN <- if (SENS == "S4") "S4" else "main"
suppressMessages({ library(dplyr); library(readr); library(augsynth) })

out_dir <- file.path(ROOT_DIR, "output", "local", "step2", "diagnostics")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# fit() from centro_diagnostics.R (definition only)
for (e in parse(file.path(ROOT_DIR, "code", "local", "step2", "centro_diagnostics.R"))) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("fit"))) eval(e)
}
stopifnot(exists("fit"), is.function(fit))

pre_panel <- df %>% filter(week_id < t_int)
T_pre <- n_distinct(pre_panel$week_id)
stopifnot(T_pre == t_int - 1)
dates <- if (RUN == "main") seq(20, 44, by = 2) else seq(20, 38, by = 2)
stopifnot(t_int - max(dates) >= 9, T_pre == if (RUN == "main") 52 else 47)

# The pseudo-opening weeks fall on the same calendar dates in both panels
wk <- pre_panel %>% distinct(week_id, week_date) %>% arrange(week_id)
stopifnot(all(as.Date(wk$week_date[match(dates, wk$week_id)]) ==
              as.Date("2022-11-28") + 7 * (dates - 1)),
          max(as.Date(wk$week_date)) == if (RUN == "main") as.Date("2023-11-20") else as.Date("2023-10-16"))

rows <- lapply(dates, function(tp) {
  fi <- fit(pre_panel, tp, "centro", character(0), TRUE, "iid")      # errors stop the run
  fb <- fit(pre_panel, tp, "centro", character(0), TRUE, "block")
  # a block p is a positive multiple of 1/T (the unshifted order always counts)
  stopifnot(abs(fb$p * fb$n_weeks - round(fb$p * fb$n_weeks)) < 1e-8, fb$p >= 1 / fb$n_weeks - 1e-12,
            fb$n_weeks == T_pre, abs(fi$att - fb$att) < 1e-12)          # same fit, two p types
  cat(sprintf("  %s pseudo week %d: att %+.4f p_iid %.3f p_block %.4f\n", RUN, tp, fi$att, fi$p, fb$p))
  tibble(pollutant = "PM25", run = RUN, pseudo_week = tp,
         pseudo_date = as.Date("2022-11-28") + 7 * (tp - 1),
         pre_weeks = tp - 1, post_weeks = t_int - tp,
         att_log = fi$att, p_iid = fi$p, p_iid_smallest_nonzero = 0.001,
         p_block = fb$p, p_block_smallest = 1 / fb$n_weeks)
})
ps <- bind_rows(rows)

# Main panel: the iid results must reproduce the committed diagnostic
if (RUN == "main") {
  old <- read_csv(file.path(out_dir, "pseudo_openings_M8b_PM25.csv"), show_col_types = FALSE)
  chk <- inner_join(ps, old, by = "pseudo_week", suffix = c("", ".old"))
  print(chk %>% select(pseudo_week, att_log, att_log.old, p_iid, p_iid_reseeded))
  stopifnot(nrow(chk) == length(dates), max(abs(chk$att_log - chk$att_log.old)) < 1e-9,
            all(chk$p_iid == chk$p_iid_reseeded))
  cat("Main iid results reproduce pseudo_openings_M8b_PM25.csv: TRUE\n")
}

write_csv(ps, file.path(out_dir, sprintf("pseudo_openings_block_%s_PM25.csv", RUN)))
summ <- bind_rows(lapply(c("iid", "block"), function(ty) {
  p <- if (ty == "iid") ps$p_iid else ps$p_block
  tibble(pollutant = "PM25", run = RUN, p_type = ty, dates = nrow(ps), fitted = sum(!is.na(p)),
         reject_05 = mean(p <= 0.05), reject_10 = mean(p <= 0.10),
         share_negative = mean(ps$att_log < 0),
         p_smallest = if (ty == "iid") 0 else 1 / T_pre,
         p_smallest_nonzero = if (ty == "iid") 0.001 else 1 / T_pre,
         level_05 = if (ty == "iid") 0.05 else floor(0.05 * T_pre) / T_pre,
         level_10 = if (ty == "iid") 0.10 else floor(0.10 * T_pre) / T_pre)
}))
write_csv(summ, file.path(out_dir, sprintf("pseudo_openings_block_summary_%s_PM25.csv", RUN)))
print(summ)
cat(sprintf("\n=== pseudo-openings with block p done (%s) ===\n", RUN))
