#=========================================================
#  old_vs_new.R
#  Step 2 reporting tables (air_quality/docs/revision_plan.md 4.3 and 3A):
#    main_old_vs_new.csv    every specification x window, frozen (2026-05-29)
#                           against the new main run, sign first, with donor weights
#    sensitivities.csv      main and each sensitivity side by side, for the
#                           specifications the paper reports in the main text
#                           (S1, S2a, S2b: donut and full only, as 3A.2 says)
#    placebo_old_vs_new.csv Table 6 (spatial placebos M8b and M5b), frozen against new
#    donor_weights_main.csv donor weights of every main specification, old and new
#    window_weeks.csv       pre and post weeks per pollutant, window and run
#  Smallest attainable p-values: conformal (iid, 1,000 random permutations; the
#  observed order is not counted) can be 0 and its smallest nonzero value is
#  0.001; the SDID permutation p-value's smallest value is 1/(1+n_placebo).
#  The frozen reference is read from the data store (absolute path below).
#  Run after the main run and the sensitivities, from air_quality/:
#    Rscript code/local/step2/old_vs_new.R > ../logs/aq_s2_compare.log 2>&1
#=========================================================

suppressMessages({ library(dplyr); library(tidyr); library(readr); library(lubridate) })
root_dir <- here::here()
FROZEN <- "/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29"
out_dir <- file.path(root_dir, "output", "local", "step2")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
POLS <- c("PM25", "CO", "NO2", "SO2")
PANEL <- c(PM25 = "pm25", CO = "CO", NO2 = "NO2", SO2 = "SO2")
SENS_BY_POL <- list(PM25 = c("S1", "S2a", "S2b", "S3", "S4"), CO = c("S1", "S3", "S4"),
                    NO2 = c("S1", "S3", "S4"), SO2 = c("S1", "S3", "S4"))
NO_PRE_BLACKOUT <- c("S1", "S2a", "S2b")
MAIN_TEXT <- list(PM25 = c("M7", "M9", "M8", "M8b"), CO = "M8b", NO2 = "M8b", SO2 = "M8b")
SPEC_ORDER <- c("M7", "M9", "M8", "M8b", "M5b", "M1", "M2", "M2b", "M3", "M4", "M5", "M6")
TREAT_WEEK <- floor_date(as.Date("2023-12-01"), "week", week_start = 1)
BLACKOUT_START <- as.Date("2024-09-15"); BLACKOUT_END <- as.Date("2024-12-31")
RATIONING <- seq(as.Date("2023-10-23"), as.Date("2023-12-11"), by = "week")

read_req <- function(path, label) {
  if (!file.exists(path)) stop("missing expected output: ", path)
  read_csv(path, show_col_types = FALSE) %>% mutate(run = label)
}
p_smallest <- function(p_type, n_placebo) ifelse(p_type == "conformal", 0.001, 1 / (1 + n_placebo))
p_smallest_kind <- function(p_type) ifelse(p_type == "conformal", "smallest nonzero (0 attainable)", "smallest attainable")

#---- 1. Main: old against new ----
main <- bind_rows(lapply(POLS, function(P) {
  old <- read_req(file.path(FROZEN, "output/local/crosssample", sprintf("CrossSample_Summary_%s.csv", P)), "old")
  new <- read_req(file.path(root_dir, "output/local/crosssample", sprintf("CrossSample_Summary_%s.csv", P)), "new")
  keep <- c("spec", "method", "sample", "att_log", "att_pct", "p_2s", "p_1s", "p_type",
            "rmspe_pre", "rmspe_post", "ratio", "n_placebo", "donor_weights")
  full_join(old %>% select(all_of(keep)), new %>% select(all_of(keep)),
            by = c("spec", "method", "sample", "p_type"), suffix = c("_old", "_new")) %>%
    mutate(pollutant = P, .before = 1)
})) %>%
  mutate(sign_old = sign(att_log_old), sign_new = sign(att_log_new),
         sign_changed = sign_old != sign_new,
         p_smallest_new = p_smallest(p_type, n_placebo_new), p_smallest_kind = p_smallest_kind(p_type),
         spec = factor(spec, levels = SPEC_ORDER),
         sample = factor(sample, levels = c("pre_blackout", "donut", "full"))) %>%
  arrange(match(pollutant, POLS), spec, sample) %>%
  mutate(spec = as.character(spec), sample = as.character(sample)) %>%
  relocate(sign_old, sign_new, sign_changed, .after = sample)
write_csv(main %>% select(-donor_weights_old, -donor_weights_new), file.path(out_dir, "main_old_vs_new.csv"))

#---- 2. Window weeks (pre/post) per run ----
window_weeks <- function(panel_path, drop_rationing = FALSE) {
  wp <- read_csv(panel_path, show_col_types = FALSE)
  wf <- wp %>% group_by(week_date) %>%
    summarise(po = mean(poweroutage, na.rm = TRUE), wfi = mean(wildfire, na.rm = TRUE), .groups = "drop") %>%
    mutate(week_date = as.Date(week_date),
           blackout = week_date >= BLACKOUT_START & week_date <= BLACKOUT_END & (po > 0.3 | wfi > 0.3))
  if (drop_rationing) wf <- wf %>% filter(!week_date %in% RATIONING)
  sets <- list(full = wf$week_date, donut = wf$week_date[!wf$blackout],
               pre_blackout = wf$week_date[wf$week_date < BLACKOUT_START])
  bind_rows(lapply(names(sets), function(w) tibble(sample = w,
    weeks_pre = sum(sets[[w]] < TREAT_WEEK), weeks_post = sum(sets[[w]] >= TREAT_WEEK),
    first_week = min(sets[[w]]), last_week = max(sets[[w]]),
    stations = n_distinct(wp$estacion))))
}
ww <- bind_rows(lapply(POLS, function(P) {
  f <- sprintf("%s_completepanel_peakweekly", PANEL[[P]])
  runs <- c(old = file.path(FROZEN, "data/processed", paste0(f, ".csv")),
            new = file.path(root_dir, "data/processed", paste0(f, ".csv")),
            setNames(file.path(root_dir, "data/processed", paste0(f, "_", SENS_BY_POL[[P]], ".csv")),
                     SENS_BY_POL[[P]]))
  bind_rows(lapply(names(runs), function(r) {
    stopifnot(file.exists(runs[[r]]))
    window_weeks(runs[[r]], drop_rationing = (r == "S4")) %>% mutate(pollutant = P, run = r, .before = 1)
  }))
}))
write_csv(ww, file.path(out_dir, "window_weeks.csv"))

#---- 3. Sensitivities beside the main run (main-text specifications) ----
sens <- bind_rows(lapply(POLS, function(P) {
  base <- read_req(file.path(root_dir, "output/local/crosssample", sprintf("CrossSample_Summary_%s.csv", P)), "main")
  ss <- lapply(SENS_BY_POL[[P]], function(s) read_req(file.path(root_dir, "output/local/sensitivity", s,
                                     "crosssample", sprintf("CrossSample_Summary_%s.csv", P)), s))
  bind_rows(c(list(base), ss)) %>% filter(spec %in% MAIN_TEXT[[P]]) %>%
    filter(!(run %in% NO_PRE_BLACKOUT & sample == "pre_blackout")) %>%
    mutate(pollutant = P, p_smallest = p_smallest(p_type, n_placebo)) %>%
    select(pollutant, spec, sample, run, att_log, att_pct, p_2s, p_smallest, p_type,
           rmspe_pre, rmspe_post, ratio, donor_weights)
}))
write_csv(sens, file.path(out_dir, "sensitivities_long.csv"))
sens_wide <- sens %>% select(pollutant, spec, sample, run, att_pct, p_2s) %>%
  pivot_wider(names_from = run, values_from = c(att_pct, p_2s), names_vary = "slowest")
write_csv(sens_wide, file.path(out_dir, "sensitivities.csv"))

#---- 4. Table 6 placebos (M8b and M5b): old against new ----
pl <- bind_rows(lapply(c(M8b = "M8b", M5b = "M5b"), function(sp) {
  f <- sprintf("spatial_placebo_PM25_%s_conformalp.csv", sp)
  o <- read_req(file.path(FROZEN, "output/local/spatial_placebo", f), "old")
  n <- read_req(file.path(root_dir, "output/local/spatial_placebo", f), "new")
  full_join(o %>% select(sample, station, att_log, att_pct, conf_p, donor_weights),
            n %>% select(sample, station, att_log, att_pct, conf_p, donor_weights),
            by = c("sample", "station"), suffix = c("_old", "_new")) %>%
    mutate(estimator = sp, .before = 1)
})) %>%
  mutate(sign_changed = sign(att_log_old) != sign(att_log_new),
         note = ifelse(station == "belisario",
                       "new data AND new donor rule (Centro removed from Belisario's donors)", "new data"))
write_csv(pl, file.path(out_dir, "placebo_old_vs_new.csv"))

#---- 5. Donor weights of every main specification, old and new ----
dw <- main %>% select(pollutant, spec, method, sample, donor_weights_old, donor_weights_new) %>%
  pivot_longer(c(donor_weights_old, donor_weights_new), names_to = "run", values_to = "w") %>%
  mutate(run = sub("donor_weights_", "", run)) %>% filter(!is.na(w)) %>%
  separate_rows(w, sep = ";") %>%
  separate(w, into = c("donor", "weight"), sep = ":", convert = TRUE) %>%
  pivot_wider(names_from = run, values_from = weight, names_prefix = "weight_")
write_csv(dw, file.path(out_dir, "donor_weights_main.csv"))

cat("Main rows:", nrow(main), " sign changes:", sum(main$sign_changed, na.rm = TRUE), "\n")
print(main %>% filter(spec %in% c("M7", "M9", "M8", "M8b")) %>%
        select(pollutant, spec, sample, sign_changed, att_pct_old, att_pct_new, p_2s_old, p_2s_new), n = Inf)
cat("\nDone.\n")
