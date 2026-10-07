#=========================================================
#  sa_imputation_check.R
#  Step 2, check 4.4 of air_quality/docs/revision_plan.md, run after the
#  weekly panels are built and before any estimate.
#
#  Builds the PM2.5 weekly panel of the main specification twice, with the
#  pipeline's own 02 code: as written, and with the San Antonio regression
#  refitted without Los Chillos as a predictor (everything else unchanged).
#  Compares the coefficients, the weeks used to fit them, San Antonio's
#  imputed weekly values, the affected weeks and the weeks kept.
#  A diagnostic: it writes no panel and changes no specification.
#
#  Run after 01, from air_quality/:
#    Rscript code/local/step2/sa_imputation_check.R > ../logs/aq_step2_sa_check.log 2>&1
#  Output: output/local/step2/sa_imputation_check_*.csv (weekly values of
#  San Antonio's imputed PM2.5 are aggregates of the hourly data).
#=========================================================

suppressMessages({ library(dplyr); library(tidyr); library(readr); library(lubridate) })

root_dir <- here::here()
code_dir <- file.path(root_dir, "code", "local")
out_dir  <- file.path(root_dir, "output", "local", "step2")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
stopifnot(Sys.getenv("AQ_SENS") == "", Sys.getenv("AQ_EXCLUDE") == "",
          Sys.getenv("AQ_LC_SHIFT_FROM") == "", Sys.getenv("AQ_MIN_HALF") == "")

assigned_name <- function(e) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]))
    as.character(e[[2]]) else NA_character_
}

# 02 up to the first panel build (main switches), in its own environment
e02 <- new.env()
script02 <- parse(file.path(code_dir, "02_build_weekly_panels.R"))
first_build <- which(vapply(script02, function(e) identical(assigned_name(e), "pm25_panel"), logical(1)))
stopifnot(length(first_build) == 1)
for (e in script02[seq_len(first_build - 1)]) eval(e, envir = e02)

# Two copies of build_weekly_panel(): with Los Chillos as a predictor (as
# written) and without it. Both capture the fitted regression, the weekly
# table before imputation (E) and after (F).
make_variant <- function(drop_lc) {
  txt <- deparse(e02$build_weekly_panel, width.cutoff = 500L)
  pat <- 'c("carapungo", "cotocollao", "guamani", "loschillos", "tumbaco")'
  hit <- grep(pat, txt, fixed = TRUE)
  stopifnot(length(hit) == 1)
  if (drop_lc) txt[hit] <- sub(pat, 'c("carapungo", "cotocollao", "guamani", "tumbaco")', txt[hit], fixed = TRUE)
  hit_lm <- grep("reg_sa <- lm(", txt, fixed = TRUE); stopifnot(length(hit_lm) == 1)
  txt[hit_lm] <- paste0(txt[hit_lm], "; assign(\"reg\", reg_sa, envir = .cap); assign(\"E\", pol_weekly, envir = .cap)")
  hit_bal <- grep("balanced <- pol_weekly %>%", txt, fixed = TRUE); stopifnot(length(hit_bal) == 1)
  txt[hit_bal] <- paste0("assign(\"Fpre\", pol_weekly, envir = .cap); ", txt[hit_bal])
  f <- eval(parse(text = txt), envir = e02)
  environment(f) <- e02
  f
}
e02$.cap <- new.env()

run_variant <- function(drop_lc) {
  rm(list = ls(e02$.cap), envir = e02$.cap)
  f <- make_variant(drop_lc)
  panel <- f(e02$daily, e02$covars_weekly, "pm25", drop_sanantonio = FALSE)
  list(panel = panel, reg = get("reg", envir = e02$.cap), E = get("E", envir = e02$.cap),
       Fpre = get("Fpre", envir = e02$.cap))
}
with_lc <- run_variant(FALSE)
without <- run_variant(TRUE)

# The "with" variant must reproduce the weekly panel 02 writes
written <- read_csv(file.path(root_dir, "data", "processed", "pm25_completepanel_peakweekly.csv"),
                    show_col_types = FALSE)
a <- with_lc$panel %>% arrange(estacion, week_date); b <- written %>% arrange(estacion, week_date)
stopifnot(nrow(a) == nrow(b), all(a$estacion == b$estacion), all(as.Date(a$week_date) == as.Date(b$week_date)),
          max(abs(a$pm25_imp - b$pm25_imp), na.rm = TRUE) < 1e-9)
cat("Variant with Los Chillos reproduces the written PM2.5 panel: TRUE\n")

# 1. Coefficients and the weeks used to fit them (computed outside mutate(),
# where a column named with_lc would mask the fitted object)
n_fit_with <- nobs(with_lc$reg); n_fit_without <- nobs(without$reg)
coefs <- full_join(
  tibble(term = names(coef(with_lc$reg)), with_lc = unname(coef(with_lc$reg))),
  tibble(term = names(coef(without$reg)), without_lc = unname(coef(without$reg))), by = "term") %>%
  mutate(nobs_with_lc = n_fit_with, nobs_without_lc = n_fit_without)
write_csv(coefs, file.path(out_dir, "sa_imputation_check_coefficients.csv"))
print(coefs, n = Inf)

# 2. San Antonio's weekly values: observed (before imputation) and imputed
# "observed" = a weekly value before the regression (measured, or filled by the
# two-week interpolation); the rest are imputed by the regression
sa_obs <- with_lc$E %>% filter(estacion == "sanantonio") %>%
  transmute(week_date = as.Date(week_date), observed = !is.na(pm25_imp))
get_sa <- function(v, lab) {
  # San Antonio after the regression and before the all-stations rule
  v$Fpre %>% filter(estacion == "sanantonio") %>%
    transmute(week_date = as.Date(week_date), !!lab := pm25_imp)
}
treat <- floor_date(as.Date("2023-12-01"), "week", week_start = 1)
cmp <- sa_obs %>%
  left_join(get_sa(with_lc, "sa_with_lc"), by = "week_date") %>%
  left_join(get_sa(without, "sa_without_lc"), by = "week_date") %>%
  mutate(period = case_when(week_date < treat ~ "a_pre_period",
                            week_date < as.Date("2024-10-01") ~ "b_2023-12_to_2024-09",
                            TRUE ~ "c_2024-10_on"),
         in_panel_with_lc = !is.na(sa_with_lc), in_panel_without_lc = !is.na(sa_without_lc))
imp <- cmp %>% filter(!observed)

summ <- imp %>% mutate(d = sa_with_lc - sa_without_lc, rel = d / sa_without_lc) %>%
  group_by(period) %>%
  summarise(imputed_weeks_with_lc = sum(!is.na(sa_with_lc)),
            imputed_weeks_without_lc = sum(!is.na(sa_without_lc)),
            weeks_imputed_in_one_fit_only = sum(is.na(sa_with_lc) != is.na(sa_without_lc)),
            weeks_both = sum(!is.na(d)),
            mean_signed_diff = mean(d, na.rm = TRUE),
            mean_abs_diff = mean(abs(d), na.rm = TRUE),
            max_abs_diff = suppressWarnings(max(abs(d), na.rm = TRUE)),
            weeks_rel_change_gt_10pct = sum(abs(rel) > 0.10, na.rm = TRUE),
            .groups = "drop")
summ <- bind_rows(summ, imp %>% mutate(d = sa_with_lc - sa_without_lc, rel = d / sa_without_lc) %>%
  summarise(period = "all", imputed_weeks_with_lc = sum(!is.na(sa_with_lc)),
            imputed_weeks_without_lc = sum(!is.na(sa_without_lc)),
            weeks_imputed_in_one_fit_only = sum(is.na(sa_with_lc) != is.na(sa_without_lc)),
            weeks_both = sum(!is.na(d)), mean_signed_diff = mean(d, na.rm = TRUE),
            mean_abs_diff = mean(abs(d), na.rm = TRUE),
            max_abs_diff = suppressWarnings(max(abs(d), na.rm = TRUE)),
            weeks_rel_change_gt_10pct = sum(abs(rel) > 0.10, na.rm = TRUE)))
write_csv(summ, file.path(out_dir, "sa_imputation_check_summary.csv"))
print(summ, width = Inf)

# 3. Weeks entering or leaving the panel under the all-stations rule
wk_with <- unique(as.Date(with_lc$panel$week_date)); wk_without <- unique(as.Date(without$panel$week_date))
weeks <- tibble(weeks_with_lc = length(wk_with), weeks_without_lc = length(wk_without),
                only_with_lc = paste(sort(setdiff(wk_with, wk_without)), collapse = ";"),
                only_without_lc = paste(sort(setdiff(wk_without, wk_with)), collapse = ";"))
write_csv(weeks, file.path(out_dir, "sa_imputation_check_weeks.csv"))
print(weeks, width = Inf)

# Week-by-week imputed values (San Antonio, weekly peak-hour means; no hourly records)
write_csv(imp %>% select(week_date, period, sa_with_lc, sa_without_lc),
          file.path(out_dir, "sa_imputation_check_imputed_weeks.csv"))
cat("\nDone.\n")
