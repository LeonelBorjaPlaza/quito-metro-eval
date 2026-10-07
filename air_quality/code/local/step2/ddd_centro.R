#=========================================================
#  ddd_centro.R
#  Step 2, air_quality/docs/revision_plan.md 3A.3 item 9: triple difference
#  at Centro for PM2.5, NO2 and CO, from the hourly panel (main specification).
#
#  For each station and Monday week:
#    D = log(mean over weekday peak hours 07-09 and 17-19)
#        - log(mean over all other hours: weekday off-peak and weekends),
#  using station-weeks with at least half of the peak slots and half of the
#  off-peak hours observed. Then, per window,
#    DDD = (mean D at Centro, post minus pre)
#          - mean over controls of (mean D, post minus pre),
#  controls A: every analysis station with the pollutant except Centro and
#  Belisario; controls B: A plus Belisario. Windows use the week sets of the
#  main weekly panel and the setup scripts' blackout rule (pre_blackout:
#  weeks before 2024-09-15; donut: blackout weeks dropped; full: all).
#  Inference: placebo permutation over the controls (each in turn treated as
#  Centro, the remaining controls as its controls); two-sided rank p-value
#  (1 + #{|placebo| >= |DDD|}) / (1 + #placebos), with its smallest value
#  1 / (1 + #placebos). No Wald or normal p-values.
#
#  Run after 01 and 02, from air_quality/:
#    Rscript code/local/step2/ddd_centro.R > ../logs/aq_step2_ddd.log 2>&1
#  Output: output/local/step2/ddd_centro.csv, ddd_station_d.csv (station means of D)
#=========================================================

suppressMessages({ library(dplyr); library(tidyr); library(readr); library(lubridate) })
root_dir <- here::here()
proc_dir <- file.path(root_dir, "data", "processed")
out_dir  <- file.path(root_dir, "output", "local", "step2")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
stopifnot(Sys.getenv("AQ_SENS") == "")

TREATMENT_WEEK <- floor_date(as.Date("2023-12-01"), "week", week_start = 1)
BLACKOUT_START <- as.Date("2024-09-15"); BLACKOUT_END <- as.Date("2024-12-31")
PEAK <- c(7, 8, 9, 17, 18, 19)

hourly <- read_csv(file.path(proc_dir, "hourly_panel.csv"), show_col_types = FALSE)
stopifnot(nrow(problems(hourly)) == 0)

pols <- c(pm25 = "pm25", no2 = "NO2", co = "CO")
res <- list(); dtab <- list()
for (pol in names(pols)) {
  wp <- read_csv(file.path(proc_dir, sprintf("%s_completepanel_peakweekly.csv", pols[[pol]])),
                 show_col_types = FALSE)
  stations <- sort(unique(wp$estacion))
  # week sets and blackout weeks exactly as the setup scripts define them
  wf <- wp %>% group_by(week_date) %>%
    summarise(po = mean(poweroutage, na.rm = TRUE), wfi = mean(wildfire, na.rm = TRUE), .groups = "drop") %>%
    mutate(week_date = as.Date(week_date),
           blackout = week_date >= BLACKOUT_START & week_date <= BLACKOUT_END & (po > 0.3 | wfi > 0.3))
  windows <- list(full = wf$week_date,
                  donut = wf$week_date[!wf$blackout],
                  pre_blackout = wf$week_date[wf$week_date < BLACKOUT_START])

  h <- hourly %>% filter(date >= as.Date("2022-12-01")) %>%
    select(date, hour_of_day, day_of_week, all_of(paste0(stations, "_", pol))) %>%
    pivot_longer(-c(date, hour_of_day, day_of_week), names_to = "estacion", values_to = "v") %>%
    mutate(estacion = sub(paste0("_", pol, "$"), "", estacion),
           week_date = floor_date(date, "week", week_start = 1),
           peak = day_of_week %in% 1:5 & hour_of_day %in% PEAK) %>%
    filter(week_date %in% wf$week_date)
  sw <- h %>% group_by(estacion, week_date) %>%
    summarise(n_peak_slots = sum(peak), n_off_slots = sum(!peak),
              n_peak = sum(peak & !is.na(v)), n_off = sum(!peak & !is.na(v)),
              m_peak = mean(v[peak], na.rm = TRUE), m_off = mean(v[!peak], na.rm = TRUE),
              .groups = "drop") %>%
    mutate(D = ifelse(n_peak >= n_peak_slots / 2 & n_off >= n_off_slots / 2 & m_peak > 0 & m_off > 0,
                      log(m_peak) - log(m_off), NA_real_),
           post = week_date >= TREATMENT_WEEK)

  for (w in names(windows)) {
    st <- sw %>% filter(week_date %in% windows[[w]]) %>% group_by(estacion) %>%
      summarise(pre_mean = mean(D[!post], na.rm = TRUE), post_mean = mean(D[post], na.rm = TRUE),
                pre_weeks = sum(!is.na(D[!post])), post_weeks = sum(!is.na(D[post])), .groups = "drop") %>%
      mutate(dd = post_mean - pre_mean)
    dtab[[length(dtab) + 1]] <- st %>% mutate(pollutant = toupper(pols[[pol]]), window = w)
    for (ctl in c("A", "B")) {
      controls <- setdiff(stations, c("centro", if (ctl == "A") "belisario"))
      ddd <- st$dd[st$estacion == "centro"] - mean(st$dd[st$estacion %in% controls], na.rm = TRUE)
      plac <- vapply(controls, function(j) {
        st$dd[st$estacion == j] - mean(st$dd[st$estacion %in% setdiff(controls, j)], na.rm = TRUE)
      }, numeric(1))
      plac <- plac[is.finite(plac)]
      res[[length(res) + 1]] <- tibble(
        pollutant = toupper(pols[[pol]]), window = w, controls = ctl,
        control_stations = paste(controls, collapse = ";"),
        ddd = ddd, ddd_pct = (exp(ddd) - 1) * 100,
        centro_pre_weeks = st$pre_weeks[st$estacion == "centro"],
        centro_post_weeks = st$post_weeks[st$estacion == "centro"],
        n_placebos = length(plac),
        p_perm_2s = (1 + sum(abs(plac) >= abs(ddd))) / (1 + length(plac)),
        p_smallest = 1 / (1 + length(plac)),
        placebo_min = min(plac), placebo_max = max(plac))
    }
  }
}
res <- bind_rows(res); write_csv(res, file.path(out_dir, "ddd_centro.csv"))
write_csv(bind_rows(dtab), file.path(out_dir, "ddd_station_d.csv"))
print(res %>% select(pollutant, window, controls, ddd, ddd_pct, n_placebos, p_perm_2s, p_smallest), n = Inf)
cat("\nDone.\n")
