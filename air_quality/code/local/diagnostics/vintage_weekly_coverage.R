#=========================================================
#  vintage_weekly_coverage.R
#  Workstream A, step 1 of the move to the 2026-10-04 REMMAQ delivery.
#  Runs the pipeline's own reading and weekly-panel code on the new
#  delivery, in a temporary folder, and records which stations and
#  weeks survive each step, for PM2.5, CO, NO2 and SO2. Counts only;
#  nothing is estimated and no pipeline file is changed or written.
#
#  - 01_read_and_merge.R: every expression is evaluated except the
#    path assignments and the final write; raw_dir points to the new
#    delivery. standardize_name() is wrapped to map the new HUM header
#    "Santonio" to sanantonio (the plan's proposed fix; without it the
#    pipeline would drop San Antonio's humidity).
#  - 02_build_weekly_panels.R: evaluated up to the first panel build,
#    reading the hourly panel the way 02 does (read_csv from a CSV
#    written by write_csv), so its type guessing is tested too;
#    build_weekly_panel() is copied with a capture point after the San
#    Antonio imputation (stage F), just before the all-stations rule.
#  - Two rules: "current" (as written) and "min_half_hours" (a
#    station-week with fewer than half of its weekday peak-hour slots
#    observed is set to missing before the weekly mean; interpolation
#    and the all-stations rule then apply as written).
#  - Donor-pool options: for each pollutant and exclusion set, the panel
#    is rebuilt without the excluded stations (so the San Antonio
#    regression is refitted on the stations that remain), and the weeks
#    kept are counted, with the weeks in which San Antonio's value comes
#    only from the regression.
#
#  Run from air_quality/:
#    Rscript code/local/diagnostics/vintage_weekly_coverage.R > ../logs/aq_vintage_weekly_coverage.log 2>&1
#  Output: output/local/diagnostics/vintage_2026-10-04/weekly_*.csv
#=========================================================

suppressMessages({ library(dplyr); library(tidyr); library(readr); library(lubridate) })

root_dir <- here::here()
code_dir <- file.path(root_dir, "code", "local")
NEW      <- "/home/leonelb/data/quito-metro-eval/air_quality/raw/2026-10-04_remmaq_all_redownload"
out_dir  <- file.path(root_dir, "output", "local", "diagnostics", "vintage_2026-10-04")
tmp_dir  <- file.path(tempdir(), "vintage_weekly")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

assigned_name <- function(e) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]))
    as.character(e[[2]]) else NA_character_
}
is_write <- function(e) any(grepl("write_csv|dir.create", deparse(e, width.cutoff = 500L)))

#---------------------------------------------------------
#  01 on the new delivery
#---------------------------------------------------------
e01 <- new.env()
script01 <- parse(file.path(code_dir, "01_read_and_merge.R"))
assign("raw_dir", NEW, envir = e01)
assign("out_dir", tmp_dir, envir = e01)
n_skipped <- 0L
for (e in script01) {
  nm <- assigned_name(e)
  if (!is.na(nm) && nm %in% c("root_dir", "raw_dir", "out_dir")) { n_skipped <- n_skipped + 1L; next }
  if (is_write(e)) { n_skipped <- n_skipped + 1L; next }
  eval(e, envir = e01)
  if (identical(nm, "standardize_name")) {
    base_std <- e01$standardize_name
    e01$standardize_name <- function(x) { y <- base_std(x); ifelse(y == "santonio", "sanantonio", y) }
  }
}
stopifnot(n_skipped == 5L)   # root_dir, raw_dir, out_dir, dir.create, write_csv
hourly_mem <- e01$panel
cat(sprintf("Hourly panel from the new delivery: %d rows, %s to %s\n",
            nrow(hourly_mem), min(hourly_mem$date), max(hourly_mem$date)))
stopifnot("sanantonio_hum" %in% names(hourly_mem))
write_csv(hourly_mem, file.path(tmp_dir, "hourly_panel.csv"))

#---------------------------------------------------------
#  02 steps 1-7, reading the CSV as 02 does
#---------------------------------------------------------
e02 <- new.env()
assign("proc_dir", tmp_dir, envir = e02)
script02 <- parse(file.path(code_dir, "02_build_weekly_panels.R"))
first_build <- which(vapply(script02, function(e) identical(assigned_name(e), "pm25_panel"), logical(1)))
for (e in script02[seq_len(first_build - 1)]) {
  nm <- assigned_name(e)
  if (!is.na(nm) && nm %in% c("root_dir", "proc_dir")) next
  eval(e, envir = e02)
}
# Did read_csv's type guessing lose anything?
probs <- problems(e02$panel)
num_cols <- grep("_(pm25|co|no2|so2|tmp|hum|vel|dir|llu|rs|pre)$", names(hourly_mem), value = TRUE)
guess_loss <- sapply(num_cols, function(v) sum(!is.na(hourly_mem[[v]]) & is.na(e02$panel[[v]])))
guess <- tibble(column = num_cols,
                type_guessed = sapply(num_cols, function(v) class(e02$panel[[v]])[1]),
                values_lost_by_read_csv = as.integer(guess_loss))
write_csv(guess, file.path(out_dir, "weekly_read_csv_type_check.csv"))
cat(sprintf("read_csv parsing problems: %d; columns losing values: %d (values lost: %d)\n",
            nrow(probs), sum(guess_loss > 0), sum(guess_loss)))

# For the coverage below, use the hourly panel exactly as read (no loss);
# if read_csv lost values, rebuild steps 1-7 from the in-memory panel instead.
if (sum(guess_loss) > 0) {
  cat("Rebuilding steps 1-7 from the in-memory hourly panel (read_csv lost values); the outputs then differ from what the pipeline would read.\n")
  e02b <- new.env()
  assign("proc_dir", tmp_dir, envir = e02b)
  for (e in script02[seq_len(first_build - 1)]) {
    nm <- assigned_name(e)
    if (!is.na(nm) && nm %in% c("root_dir", "proc_dir")) next
    if (identical(nm, "panel")) { assign("panel", hourly_mem, envir = e02b); next }
    eval(e, envir = e02b)
  }
  e02 <- e02b
}

#---------------------------------------------------------
#  Instrumented build_weekly_panel(): capture stage E (after
#  short-gap interpolation) and stage F (after the San Antonio
#  imputation, just before the all-stations rule)
#---------------------------------------------------------
e02$.trace <- new.env()
stmts <- as.list(body(e02$build_weekly_panel))
out <- stmts[1]; hits <- c(E = 0L, F = 0L)
for (i in seq_along(stmts)[-1]) {
  out <- c(out, stmts[i])
  txt <- paste(deparse(stmts[[i]], width.cutoff = 500L), collapse = " ")
  if (startsWith(txt, "pol_weekly[[pol_imp]] <- ifelse(!is.na(pol_weekly[[pol]])")) {
    out <- c(out, list(quote(assign("E", pol_weekly, envir = .trace)))); hits["E"] <- hits["E"] + 1L
  }
  if (startsWith(txt, "if (!drop_sanantonio)")) {
    out <- c(out, list(quote(assign("F", pol_weekly, envir = .trace)))); hits["F"] <- hits["F"] + 1L
  }
}
stopifnot(all(hits == 1L))
bwp <- e02$build_weekly_panel
body(bwp) <- as.call(out)
orig_keep <- e02$stations_keep

# weekday peak-hour slots and observed hours per station-week
peak_hours <- c(7, 8, 9, 17, 18, 19)
hp <- hourly_mem %>%
  filter(hour_of_day %in% peak_hours, day_of_week %in% 1:5, date >= as.Date("2022-12-01")) %>%
  mutate(week_date = floor_date(date, "week", week_start = 1))
slots <- hp %>% count(week_date, name = "slots")
obs_hours <- function(pol) {
  hp %>% select(week_date, ends_with(paste0("_", pol))) %>%
    pivot_longer(-week_date, names_to = "estacion", values_to = "v") %>%
    mutate(estacion = sub(paste0("_", pol, "$"), "", estacion)) %>%
    group_by(estacion, week_date) %>% summarise(obs = sum(!is.na(v)), .groups = "drop") %>%
    left_join(slots, by = "week_date")
}

daily_for_rule <- function(pol, rule) {
  dd <- e02$daily
  if (rule == "min_half_hours") {
    low <- obs_hours(pol) %>% filter(obs < slots / 2) %>% transmute(estacion, .wk = week_date, .low = TRUE)
    dd <- dd %>% mutate(.wk = floor_date(date, "week", week_start = 1)) %>%
      left_join(low, by = c("estacion", ".wk")) %>%
      mutate(!!pol := ifelse(coalesce(.low, FALSE), NA, .data[[pol]])) %>%
      select(-.low, -.wk)
  }
  dd
}

# One full build with a given station set (the San Antonio regression is
# refitted on whatever stations remain, as 02 does)
run_build <- function(pol, rule, exclude = character(0)) {
  assign("stations_keep", setdiff(orig_keep, exclude), envir = e02)
  on.exit(assign("stations_keep", orig_keep, envir = e02))
  rm(list = ls(e02$.trace), envir = e02$.trace)
  panel <- bwp(daily_for_rule(pol, rule), e02$covars_weekly, pol,
               drop_sanantonio = (pol != "pm25"))
  pol_imp <- paste0(pol, "_imp")
  E <- get("E", envir = e02$.trace, inherits = FALSE) %>% mutate(week_date = as.Date(week_date))
  Fst <- get("F", envir = e02$.trace, inherits = FALSE) %>% mutate(week_date = as.Date(week_date))
  st <- Fst %>% transmute(estacion, week_date, present = !is.na(.data[[pol_imp]])) %>%
    left_join(E %>% transmute(estacion, week_date, present_before_sa_imputation = !is.na(.data[[pol_imp]])),
              by = c("estacion", "week_date"))
  list(panel = panel, F = st)
}

sets <- list(none = character(0), guamani = "guamani", sanantonio = "sanantonio",
             loschillos = "loschillos", guamani_sanantonio = c("guamani", "sanantonio"),
             guamani_loschillos = c("guamani", "loschillos"),
             guamani_sanantonio_loschillos = c("guamani", "sanantonio", "loschillos"))

wk_rows <- list(); opt_rows <- list(); res <- list()
for (pol in c("pm25", "co", "no2", "so2")) {
  for (rule in c("current", "min_half_hours")) {
    for (nm in names(sets)) {
      ex <- sets[[nm]]
      # San Antonio is not in the gas panels: skip sets that differ only by it
      if (pol != "pm25" && "sanantonio" %in% ex) next
      r <- run_build(pol, rule, ex)
      kept <- unique(as.Date(r$panel$week_date))
      w <- r$F %>% group_by(week_date) %>%
        summarise(stations = n(), reporting = sum(present),
                  missing = paste(estacion[!present], collapse = " "),
                  sanantonio_from_regression_only = any(estacion == "sanantonio" & present &
                                                          !present_before_sa_imputation),
                  .groups = "drop") %>%
        mutate(pollutant = pol, rule = rule, excluded = nm, kept = week_date %in% kept)
      stopifnot(all(w$kept == (w$reporting == w$stations)))
      if (nm == "none") { res[[paste(pol, rule)]] <- r; wk_rows[[length(wk_rows) + 1]] <- w }
      opt_rows[[length(opt_rows) + 1]] <- w
    }
  }
}
weeks <- bind_rows(wk_rows) %>%
  select(pollutant, rule, week_date, stations, reporting, missing, sanantonio_from_regression_only, kept)
write_csv(weeks, file.path(out_dir, "weekly_stage_F_by_week.csv"))

# By month, from the week of 2024-12-30: weeks in month, weeks kept, stations missing in dropped weeks
by_month <- weeks %>%
  filter(week_date >= as.Date("2024-12-30")) %>%
  mutate(month = format(week_date, "%Y-%m")) %>%
  group_by(pollutant, rule, month) %>%
  summarise(weeks = n(), weeks_kept = sum(kept),
            missing_stations = paste(sort(unique(unlist(strsplit(missing[!kept], " ")))), collapse = " "),
            .groups = "drop")
write_csv(by_month, file.path(out_dir, "weekly_kept_by_month.csv"))

# Summary per pollutant and rule (current pool)
summ <- weeks %>% group_by(pollutant, rule) %>%
  summarise(weeks_total = n(), weeks_kept = sum(kept),
            last_week_kept = max(week_date[kept]),
            first_week_dropped_from_2025_03_31 = {
              x <- week_date[!kept & week_date >= as.Date("2025-03-31")]
              if (length(x)) min(x) else as.Date(NA)
            },
            last_week_of_unbroken_run_from_2025_03_03 = {
              o <- order(week_date); wk <- week_date[o]; k <- kept[o]
              sel <- wk >= as.Date("2025-03-03"); wk <- wk[sel]; k <- k[sel]
              if (!k[1]) as.Date(NA) else wk[max(which(cumprod(k) == 1))]
            },
            .groups = "drop")
write_csv(summ, file.path(out_dir, "weekly_summary.csv"))
print(summ, width = Inf)

# Donor-pool options, each rebuilt with its own station set. Periods:
# pre-period (from 2022-12), post to 2025-03, post from 2025-04; the
# blackout weeks are included (the donut sample would drop 14 of them).
treat <- floor_date(as.Date("2023-12-01"), "week", week_start = 1)
opts <- bind_rows(opt_rows) %>%
  mutate(period = case_when(week_date < treat ~ "pre",
                            week_date < as.Date("2025-04-01") ~ "post_to_2025-03",
                            TRUE ~ "post_2025-04_on")) %>%
  group_by(pollutant, rule, excluded, period) %>%
  summarise(weeks = n(), weeks_kept = sum(kept),
            weeks_kept_with_sanantonio_from_regression_only = sum(kept & sanantonio_from_regression_only),
            .groups = "drop") %>%
  pivot_wider(names_from = period,
              values_from = c(weeks, weeks_kept, weeks_kept_with_sanantonio_from_regression_only))
write_csv(opts, file.path(out_dir, "weekly_donor_pool_options.csv"))
print(opts, n = Inf, width = Inf)

# Monthly weeks present per station at stage F, from 2025-04, both rules (current pool)
st <- bind_rows(lapply(names(res), function(k) {
  p <- strsplit(k, " ")[[1]]
  res[[k]]$F %>% mutate(pollutant = p[1], rule = p[2])
})) %>%
  filter(week_date >= as.Date("2025-04-01")) %>%
  mutate(month = format(week_date, "%Y-%m")) %>%
  group_by(pollutant, rule, estacion, month) %>%
  summarise(weeks = n(), weeks_present = sum(present),
            weeks_present_before_sa_imputation = sum(present_before_sa_imputation), .groups = "drop")
write_csv(st, file.path(out_dir, "weekly_station_presence_by_month.csv"))
cat(sprintf("\nSaved tables to %s\n", out_dir))
