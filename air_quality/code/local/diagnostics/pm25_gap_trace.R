#=========================================================
#  pm25_gap_trace.R
#  Workstream A, step 1 (Secretaria de Ambiente comment 1).
#  Traces PM2.5 for the weeks around the January-February 2025
#  gap from the raw REMMAQ file to the weekly panel, and says at
#  each step which station-weeks are still present.
#
#  Uses the pipeline's own code: read_remmaq() is taken from
#  01_read_and_merge.R, steps 1-7 and build_weekly_panel() from
#  02_build_weekly_panels.R. build_weekly_panel() is copied with
#  capture points added between its steps; nothing else changes.
#
#  Run after 01 and 02, from air_quality/:
#    Rscript code/local/diagnostics/pm25_gap_trace.R > ../logs/aq_pm25_gap_trace.log 2>&1
#  Input:  data/raw/remmaq/PM2.5.xlsx (read-only)
#          data/processed/hourly_panel.csv, pm25_completepanel_peakweekly.csv
#          frozen_2026-05-29/data/processed/ (same two files; absolute
#          path into the data store, see root CLAUDE.md)
#  Output: output/local/diagnostics/pm25_gap/  (counts and flags only,
#          no pollutant values)
#=========================================================

library(readxl)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(stringr)

root_dir   <- here::here()
code_dir   <- file.path(root_dir, "code", "local")
raw_file   <- file.path(root_dir, "data", "raw", "remmaq", "PM2.5.xlsx")
proc_dir   <- file.path(root_dir, "data", "processed")
frozen_dir <- "/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29/data/processed"
out_dir    <- file.path(root_dir, "output", "local", "diagnostics", "pm25_gap")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Gap in the frozen weekly panel (docs/known_issues.md): weeks starting
# 2025-01-13 to 2025-02-24. The Secretaria wrote "January and February 2025".
# The trace window adds two weeks on each side.
gap_weeks  <- seq(as.Date("2025-01-13"), as.Date("2025-02-24"), by = "week")
win_weeks  <- seq(as.Date("2024-12-30"), as.Date("2025-03-10"), by = "week")
win_start  <- min(win_weeks)
win_end    <- max(win_weeks) + 6
peak_hours <- c(7, 8, 9, 17, 18, 19)

# Evaluate selected top-level expressions of a pipeline script
eval_from_script <- function(file, keep, env) {
  for (e in parse(file)) if (keep(e)) eval(e, envir = env)
  invisible(env)
}
assigned_name <- function(e) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]))
    as.character(e[[2]]) else NA_character_
}

# Pipeline helpers from 01_read_and_merge.R (definitions only)
e01 <- new.env()
eval_from_script(file.path(code_dir, "01_read_and_merge.R"),
                 function(e) assigned_name(e) %in%
                   c("standardize_name", "stations_keep", "read_remmaq"),
                 e01)
stations_keep <- e01$stations_keep

#---------------------------------------------------------
#  Step A. Raw file as stored (independent read, all text)
#---------------------------------------------------------
cat("Step A: raw PM2.5.xlsx\n")
# Every sheet: does any of them hold Los Chillos in the gap? (the pipeline
# reads sheet 1 only)
raw_sheets <- excel_sheets(raw_file)
cat(sprintf("  Sheets: %s\n", paste(raw_sheets, collapse = ", ")))
sheet_check <- lapply(raw_sheets, function(sh) {
  x <- read_excel(raw_file, sheet = sh, col_types = "text")
  d <- as.POSIXct(read_excel(raw_file, sheet = sh,
                             col_types = c("date", rep("skip", ncol(x) - 1L)))[[1]],
                  tz = "UTC")
  lc <- which(e01$standardize_name(names(x)) == "loschillos")
  in_gap <- !is.na(d) & as.Date(d) >= as.Date("2025-01-07") & as.Date(d) <= as.Date("2025-02-28")
  n_lc <- if (length(lc) == 1) sum(!is.na(suppressWarnings(as.numeric(x[[lc]][in_gap])))) else NA_integer_
  cat(sprintf("  Sheet %s: %d rows, %d rows dated 2025-01-07..2025-02-28, Los Chillos values there: %s\n",
              sh, nrow(x), sum(in_gap), n_lc))
  n_lc
})
raw_txt <- read_excel(raw_file, sheet = 1, col_types = "text")
raw_hdr <- names(raw_txt)
cat(sprintf("  Sheet read by the pipeline: %s; header: %s\n", raw_sheets[1],
            paste(raw_hdr, collapse = ", ")))
cat(sprintf("  Data rows below the header: %d\n", nrow(raw_txt)))

# Typed read of the date column only, to classify each row
raw_dates <- read_excel(raw_file, sheet = 1,
                        col_types = c("date", rep("skip", length(raw_hdr) - 1L)))[[1]]
raw_dates <- as.POSIXct(raw_dates, tz = "UTC")
stopifnot(length(raw_dates) == nrow(raw_txt))
n_bad_date <- sum(is.na(raw_dates))
n_offhour  <- sum(!is.na(raw_dates) & (minute(raw_dates) != 0 | second(raw_dates) != 0))
cat(sprintf("  Rows whose first cell is not a date: %d\n", n_bad_date))
cat(sprintf("  Time stamps not on the exact hour: %d\n", n_offhour))

raw_long <- raw_txt %>%
  select(-1) %>%
  mutate(fecha = round_date(raw_dates, "hour")) %>%
  pivot_longer(-fecha, names_to = "station_raw", values_to = "txt") %>%
  mutate(
    estacion  = e01$standardize_name(station_raw),
    has_value = !is.na(suppressWarnings(as.numeric(txt))),
    date      = as.Date(fecha),
    hour      = hour(fecha)
  ) %>%
  filter(date >= win_start, date <= win_end)

# Any non-numeric text in the window (flags, codes)?
raw_text_cells <- raw_long %>%
  filter(!is.na(txt), !has_value) %>%
  count(estacion, txt, name = "n_cells")
cat(sprintf("  Non-numeric, non-empty cells in the window: %d\n", sum(raw_text_cells$n_cells)))

# Expected hourly time stamps in the window with no raw row at all
expected_hours <- seq(as.POSIXct(win_start, tz = "UTC"),
                      as.POSIXct(win_end + 1, tz = "UTC") - 3600, by = "hour")
n_rows_absent <- length(setdiff(expected_hours, unique(raw_long$fecha)))
cat(sprintf("  Hours in the window with no raw row: %d of %d\n",
            n_rows_absent, length(expected_hours)))

#---------------------------------------------------------
#  Step B. read_remmaq() exactly as in 01_read_and_merge.R
#---------------------------------------------------------
cat("\nStep B: read_remmaq() from 01_read_and_merge.R\n")
pm25_rr <- e01$read_remmaq(raw_file, "PM2.5", "pm25")
cat(sprintf("  read_remmaq rows: %d; raw data rows: %d; rows dropped: %d\n",
            nrow(pm25_rr), nrow(raw_txt), nrow(raw_txt) - nrow(pm25_rr)))
cat(sprintf("  Earliest raw time stamp kept: %s\n",
            as.character(min(pm25_rr$fecha) == min(raw_dates, na.rm = TRUE))))

rr_long <- pm25_rr %>%
  filter(date >= win_start, date <= win_end) %>%
  select(date, hour = hour_of_day, ends_with("_pm25")) %>%
  pivot_longer(ends_with("_pm25"), names_to = "estacion", values_to = "v") %>%
  mutate(estacion = sub("_pm25$", "", estacion), has_value = !is.na(v))

#---------------------------------------------------------
#  Step C. Hourly panel written by 01
#---------------------------------------------------------
cat("\nStep C: hourly panel\n")
same_hourly <- unname(tools::md5sum(file.path(proc_dir, "hourly_panel.csv")) ==
                      tools::md5sum(file.path(frozen_dir, "hourly_panel.csv")))
cat(sprintf("  Rebuilt hourly_panel.csv identical to frozen: %s\n", same_hourly))
hourly <- read_csv(file.path(proc_dir, "hourly_panel.csv"), show_col_types = FALSE)
stopifnot(nrow(problems(hourly)) == 0)

# Link B to C: read_remmaq output (negatives set to NA, as 01 does) must
# equal the hourly panel's PM2.5 columns over the window
rr_win <- pm25_rr %>%
  filter(date >= win_start, date <= win_end) %>%
  select(date, hour_of_day, ends_with("_pm25")) %>%
  mutate(across(ends_with("_pm25"), ~ ifelse(.x < 0, NA, .x)))
hp_win <- hourly %>%
  filter(date >= win_start, date <= win_end) %>%
  select(date, hour_of_day, all_of(setdiff(names(rr_win), c("date", "hour_of_day"))))
b_equals_c <- nrow(rr_win) == nrow(hp_win) &&
  isTRUE(all.equal(as.data.frame(arrange(rr_win, date, hour_of_day)),
                   as.data.frame(arrange(hp_win, date, hour_of_day)),
                   check.attributes = FALSE))
cat(sprintf("  read_remmaq PM2.5 equals hourly panel over the window: %s\n", b_equals_c))
hp_long <- hourly %>%
  filter(date >= win_start, date <= win_end) %>%
  select(date, hour = hour_of_day, day_of_week, ends_with("_pm25")) %>%
  pivot_longer(ends_with("_pm25"), names_to = "estacion", values_to = "v") %>%
  mutate(estacion = sub("_pm25$", "", estacion), has_value = !is.na(v))

# Hours with a value per station-week: all hours, and weekday peak hours
count_hours <- function(d, label) {
  d %>%
    filter(estacion %in% stations_keep) %>%
    mutate(week_date = floor_date(date, "week", week_start = 1),
           peak = hour %in% peak_hours & wday(date, week_start = 1) <= 5) %>%
    group_by(estacion, week_date) %>%
    summarise(!!paste0(label, "_hours")      := sum(has_value),
              !!paste0(label, "_peak_hours") := sum(has_value & peak),
              .groups = "drop")
}
trace_tbl <- count_hours(raw_long, "A_raw") %>%
  full_join(count_hours(rr_long, "B_readremmaq"), by = c("estacion", "week_date")) %>%
  full_join(count_hours(hp_long, "C_hourly"), by = c("estacion", "week_date"))

#---------------------------------------------------------
#  Steps D-H. 02_build_weekly_panels.R
#---------------------------------------------------------
cat("\nSteps D-H: 02_build_weekly_panels.R (steps 1-7 as written)\n")
e02 <- new.env()
# Everything before the first build_weekly_panel() call: loads the hourly
# panel and builds `daily`, `covars_weekly` and the two functions.
script02 <- parse(file.path(code_dir, "02_build_weekly_panels.R"))
first_call <- which(vapply(script02, function(e) assigned_name(e) %in% "pm25_panel",
                           logical(1)))
stopifnot(length(first_call) == 1)
for (e in script02[seq_len(first_call - 1)]) eval(e, envir = e02)

# Add capture points to build_weekly_panel() between its steps
e02$.trace <- new.env()
add_capture <- function(f, after) {
  stmts <- as.list(body(f))
  out <- stmts[1]
  hits <- setNames(integer(length(after)), names(after))
  for (i in seq_along(stmts)[-1]) {
    out <- c(out, stmts[i])
    txt <- paste(deparse(stmts[[i]], width.cutoff = 500L), collapse = " ")
    for (nm in names(after)) {
      if (startsWith(txt, after[[nm]])) {
        hits[nm] <- hits[nm] + 1L
        obj <- if (nm == "G_balanced") quote(balanced) else quote(pol_weekly)
        out <- c(out, list(bquote(assign(.(nm), .(obj), envir = .trace))))
      }
    }
  }
  if (any(hits != 1L)) stop("capture point not matched exactly once: ",
                            paste(names(hits)[hits != 1L], collapse = ", "))
  body(f) <- as.call(out)
  f
}
bwp_traced <- add_capture(e02$build_weekly_panel, c(
  D_weekly_mean   = "pol_weekly <- daily_data %>%",
  E_after_interp  = "pol_weekly[[pol_imp]] <- ifelse(!is.na(pol_weekly[[pol]])",
  F_after_sa_imp  = "if (!drop_sanantonio)",
  G_balanced      = "balanced <- pol_weekly %>%"
))
pm25_traced <- bwp_traced(e02$daily, e02$covars_weekly, "pm25",
                          drop_sanantonio = FALSE)

# The traced run must reproduce the weekly panel the pipeline wrote,
# and that one the frozen panel (up to the known 1e-14 noise in dir_imp).
compare_panels <- function(a, b) {
  a <- arrange(a, estacion, week_date); b <- arrange(b, estacion, week_date)
  stopifnot(identical(names(a), names(b)), nrow(a) == nrow(b),
            all(a$estacion == b$estacion), all(a$week_date == b$week_date))
  num <- names(a)[vapply(a, is.numeric, logical(1))]
  # Missing cells must sit in the same places; other columns must be identical
  stopifnot(all(vapply(names(a), function(v) identical(is.na(a[[v]]), is.na(b[[v]])),
                       logical(1))),
            all(vapply(setdiff(names(a), num), function(v) identical(a[[v]], b[[v]]),
                       logical(1))))
  max(vapply(num, function(v) max(abs(a[[v]] - b[[v]]), na.rm = TRUE), numeric(1)))
}
written <- read_csv(file.path(proc_dir, "pm25_completepanel_peakweekly.csv"),
                    show_col_types = FALSE)
frozen  <- read_csv(file.path(frozen_dir, "pm25_completepanel_peakweekly.csv"),
                    show_col_types = FALSE)
traced_csv <- file.path(tempdir(), "pm25_traced.csv")
write_csv(pm25_traced, traced_csv)
traced <- read_csv(traced_csv, show_col_types = FALSE)
unlink(traced_csv)
d_traced_written <- compare_panels(traced, written)
d_written_frozen <- compare_panels(written, frozen)
cat(sprintf("  Traced run vs written panel, largest difference: %.3g\n", d_traced_written))
cat(sprintf("  Written panel vs frozen panel, largest difference: %.3g\n", d_written_frozen))
stopifnot(d_traced_written < 1e-9, d_written_frozen < 1e-9)

tr <- e02$.trace
present <- function(d, col, label) {
  d %>% transmute(estacion, week_date = as.Date(week_date),
                  !!label := as.integer(!is.na(.data[[col]])))
}
daily_days <- e02$daily %>%
  mutate(week_date = floor_date(date, "week", week_start = 1)) %>%
  group_by(estacion, week_date) %>%
  summarise(D_daily_days = sum(!is.na(pm25)), .groups = "drop")

trace_tbl <- trace_tbl %>%
  left_join(daily_days, by = c("estacion", "week_date")) %>%
  left_join(present(tr$D_weekly_mean,  "pm25",     "D_weekly_mean"),  by = c("estacion", "week_date")) %>%
  left_join(present(tr$E_after_interp, "pm25_imp", "E_after_interp"), by = c("estacion", "week_date")) %>%
  left_join(present(tr$F_after_sa_imp, "pm25_imp", "F_after_sa_imp"), by = c("estacion", "week_date")) %>%
  left_join(tr$F_after_sa_imp %>% group_by(week_date) %>%
              summarise(F_stations_reporting = sum(!is.na(pm25_imp)), .groups = "drop") %>%
              mutate(week_date = as.Date(week_date)),
            by = "week_date") %>%
  left_join(tr$G_balanced %>% distinct(estacion, week_date) %>%
              mutate(week_date = as.Date(week_date), G_in_panel = 1L),
            by = c("estacion", "week_date")) %>%
  left_join(frozen %>% distinct(estacion, week_date) %>% mutate(H_in_frozen = 1L),
            by = c("estacion", "week_date")) %>%
  mutate(across(c(G_in_panel, H_in_frozen), ~ coalesce(.x, 0L)),
         in_gap = week_date %in% gap_weeks) %>%
  filter(week_date %in% win_weeks) %>%
  arrange(week_date, estacion)

write_csv(trace_tbl, file.path(out_dir, "pm25_gap_trace_station_week.csv"))

# Week-level summary for the window
week_tbl <- trace_tbl %>%
  group_by(week_date, in_gap) %>%
  summarise(
    stations_with_raw_peak_hours = sum(A_raw_peak_hours > 0),
    stations_in_hourly_panel     = sum(C_hourly_peak_hours > 0),
    stations_weekly_mean         = sum(D_weekly_mean),
    stations_after_interp        = sum(E_after_interp),
    stations_after_sa_imp        = sum(F_after_sa_imp),
    missing_after_sa_imp         = paste(estacion[F_after_sa_imp == 0], collapse = " "),
    week_in_panel                = max(G_in_panel),
    week_in_frozen               = max(H_in_frozen),
    .groups = "drop")
write_csv(week_tbl, file.path(out_dir, "pm25_gap_trace_week.csv"))
print(week_tbl, n = Inf, width = Inf)

# Every week the balance rule drops, over the whole panel, and why
dropped_all <- tr$F_after_sa_imp %>%
  mutate(week_date = as.Date(week_date)) %>%
  group_by(week_date) %>%
  summarise(n_reporting = sum(!is.na(pm25_imp)),
            missing_stations = paste(estacion[is.na(pm25_imp)], collapse = " "),
            .groups = "drop") %>%
  filter(n_reporting < length(stations_keep)) %>%
  mutate(in_gap = week_date %in% gap_weeks)
write_csv(dropped_all, file.path(out_dir, "pm25_balance_dropped_weeks.csv"))
cat(sprintf("\nWeeks dropped by the balance rule, whole panel: %d of %d\n",
            nrow(dropped_all), n_distinct(tr$F_after_sa_imp$week_date)))
print(dropped_all %>% count(missing_stations, name = "n_weeks"), n = Inf)

# Raw coverage by station-day in the window (hours with a value, 0-24)
raw_day <- raw_long %>%
  group_by(estacion, date) %>%
  summarise(raw_hours = sum(has_value),
            raw_peak_clock_hours = sum(has_value & hour %in% peak_hours),
            .groups = "drop") %>%
  mutate(weekday = wday(date, week_start = 1) <= 5)
write_csv(raw_day, file.path(out_dir, "pm25_raw_station_day_window.csv"))

# Run facts
facts <- tibble(
  item = c("raw_sheets", "loschillos_values_2025-01-07_to_02-28_by_sheet",
           "raw_data_rows", "raw_rows_first_cell_not_date", "raw_timestamps_off_hour",
           "raw_hours_absent_in_window", "read_remmaq_equals_hourly_in_window",
           "read_remmaq_rows", "read_remmaq_rows_dropped",
           "raw_text_cells_in_window", "hourly_panel_identical_to_frozen",
           "traced_vs_written_max_abs_diff", "written_vs_frozen_max_abs_diff",
           "panel_weeks_written", "panel_weeks_frozen"),
  value = c(paste(raw_sheets, collapse = ";"), paste(unlist(sheet_check), collapse = ";"),
            nrow(raw_txt), n_bad_date, n_offhour, n_rows_absent, b_equals_c,
            nrow(pm25_rr),
            nrow(raw_txt) - nrow(pm25_rr), sum(raw_text_cells$n_cells),
            same_hourly, d_traced_written, d_written_frozen,
            n_distinct(written$week_date), n_distinct(frozen$week_date))
) %>% mutate(value = vapply(value, function(v) format(v, scientific = FALSE), character(1)))
write_csv(facts, file.path(out_dir, "pm25_gap_trace_facts.csv"))
print(facts)
cat(sprintf("\nSaved tables to %s\n", out_dir))
