#=========================================================
#  pm25_window_weeks.R
#  Workstream A, follow-up to step 1. Counts the weeks that enter
#  each PM2.5 window the paper reports (pre_blackout, donut, full)
#  for M7, M9, M8 and M8b, now and with the seven gap weeks
#  (starting 2025-01-13 to 2025-02-24) restored. Counts only:
#  nothing is estimated.
#
#  Uses the pipeline's own code: 03_analysis_setupPM2.5.R is sourced
#  as is (setup only), and make_samples() is taken from
#  04_PM2_5_crosssample.R. The "restored" counts apply the same
#  date rules to the week list plus the restored weeks; the rules are
#  first checked against make_samples() on the current panel (same
#  week sets, not only the same counts).
#
#  Two restored scenarios:
#    all7         all seven weeks come back. Assumes all eight stations
#                 end up with a value in each of them, which needs Los
#                 Chillos for 2025-01-27 to 2025-02-28 from REMMAQ.
#    gapfill_only the Secretaria's file alone (2025-01-13 to 2025-01-25)
#                 restores only the weeks starting January 13 and 20; the
#                 five weeks after stay a gap longer than the two-week
#                 interpolation, so the balance rule still drops them.
#
#  Run after 01 and 02, from air_quality/:
#    Rscript code/local/diagnostics/pm25_window_weeks.R > ../logs/aq_pm25_window_weeks.log 2>&1
#  Output: output/local/diagnostics/pm25_gap/pm25_window_weeks.csv
#=========================================================

source(file.path(here::here(), "code", "local", "03_analysis_setupPM2.5.R"))

out_dir <- file.path(ROOT_DIR, "output", "local", "diagnostics", "pm25_gap")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# make_samples() from the cross-sample script, definition only
for (e in parse(file.path(ROOT_DIR, "code", "local", "04_PM2_5_crosssample.R"))) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) &&
      identical(e[[2]], as.name("make_samples"))) eval(e)
}
stopifnot(exists("make_samples"))
samples <- make_samples()

# Specifications: which station each one drops (from 04_PM2_5_crosssample.R:164-167).
# None of them filters weeks, so the week counts are the same for all four.
specs <- tibble::tribble(
  ~spec, ~treated,            ~exclude,
  "M7",  "centro,belisario",  NA,
  "M9",  "belisario",         "centro",
  "M8",  "centro",            "belisario",
  "M8b", "centro",            NA
)

count_now <- function(s) {
  wk <- s$panel %>% distinct(week_id, week_date)
  tibble(window = s$name,
         weeks_now = nrow(wk),
         pre_now   = sum(wk$week_id <  s$t_int_s),
         post_now  = sum(wk$week_id >= s$t_int_s),
         first_week_now = min(wk$week_date),
         last_week_now  = max(wk$week_date))
}
now <- bind_rows(lapply(samples, count_now))

# Same windows as date rules on a list of week start dates
gap_weeks      <- seq(as.Date("2025-01-13"), as.Date("2025-02-24"), by = "week")
gapfill_weeks  <- as.Date(c("2025-01-13", "2025-01-20"))
treat_week     <- floor_date(TREATMENT_DATE, "week", week_start = 1)
blackout_dates <- week_flags$week_date[week_flags$week_id %in% blackout_week_ids]
rule_weeks <- function(weeks) {
  list(full         = weeks,
       donut        = weeks[!weeks %in% blackout_dates],
       pre_blackout = weeks[weeks < BLACKOUT_START])
}
count_rule <- function(weeks) {
  rw <- rule_weeks(weeks)
  tibble(window = names(rw), w = rw) %>%
    rowwise() %>%
    mutate(weeks = length(w), pre = sum(w < treat_week), post = sum(w >= treat_week)) %>%
    ungroup() %>%
    select(window, weeks, pre, post)
}
weeks_now      <- sort(unique(as.Date(df$week_date)))
stopifnot(!any(gap_weeks %in% weeks_now),
          all(gap_weeks > BLACKOUT_END))          # outside the blackout window
rule_now <- count_rule(weeks_now)
chk <- now %>% inner_join(rule_now, by = "window")
stopifnot(nrow(chk) == 3, all(chk$weeks_now == chk$weeks),
          all(chk$pre_now == chk$pre), all(chk$post_now == chk$post))
rw_now <- rule_weeks(weeks_now)
for (smp in samples) {
  stopifnot(setequal(unique(as.Date(smp$panel$week_date)), rw_now[[smp$name]]))
}
cat("Date rules reproduce make_samples() on the current panel: TRUE\n")

restored <- count_rule(sort(c(weeks_now, gap_weeks))) %>%
  rename(weeks_all7 = weeks, pre_all7 = pre, post_all7 = post) %>%
  left_join(count_rule(sort(c(weeks_now, gapfill_weeks))) %>%
              rename(weeks_gapfill_only = weeks, pre_gapfill_only = pre,
                     post_gapfill_only = post), by = "window")

n_stations <- n_distinct(df$estacion)
out <- tidyr::crossing(specs, window = c("pre_blackout", "donut", "full")) %>%
  mutate(units  = n_stations - !is.na(exclude),
         donors = units - lengths(strsplit(treated, ","))) %>%
  left_join(now, by = "window") %>%
  left_join(restored, by = "window") %>%
  mutate(spec = factor(spec, levels = specs$spec),
         window = factor(window, levels = c("pre_blackout", "donut", "full"))) %>%
  arrange(spec, window) %>%
  select(spec, treated, exclude, units, donors, window, weeks_now, pre_now, post_now,
         weeks_all7, pre_all7, post_all7,
         weeks_gapfill_only, pre_gapfill_only, post_gapfill_only,
         first_week_now, last_week_now)

write_csv(out, file.path(out_dir, "pm25_window_weeks.csv"))
print(out, n = Inf, width = Inf)
