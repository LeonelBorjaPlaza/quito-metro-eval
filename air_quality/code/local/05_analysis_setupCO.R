#=========================================================
#  03_analysis_setuppm2.5.R
#
#  BLACKOUT POLICY: Only Phase 3 (Sep 18 - Dec 20, 2024).
#  Pre-treatment and Phase 1/2 outages fully preserved.
#
#  AugSynth: full panel. SDID: donut panel (Phase 3 dropped).
#=========================================================

library(dplyr)
library(readr)
library(lubridate)
library(fixest)
library(augsynth)
library(synthdid)
library(ggplot2)
library(tidyr)
library(patchwork)
library(stringr)

set.seed(12345)

#=========================================================
#  PARAMS
#=========================================================

POLLUTANT   <- "co"
OUTCOME_RAW <- "co_imp"

ROOT_DIR <- here::here()
DATA_DIR <- file.path(ROOT_DIR, "data", "processed")

# Step 2 (revision_plan.md 3A): a sensitivity reads its own panel (AQ_SENS tag)
SENS <- Sys.getenv("AQ_SENS", "")
INFILE <- file.path(DATA_DIR, paste0("CO_completepanel_peakweekly",
                                     if (nzchar(SENS)) paste0("_", SENS) else "", ".csv"))

TREATMENT_DATE <- as.Date("2023-12-01")

BLACKOUT_START <- as.Date("2024-09-15")
BLACKOUT_END   <- as.Date("2024-12-31")

PO_THRESHOLD <- 0.3
WF_THRESHOLD <- 0.3

WEATHER_VARS <- c("tmp_imp", "hum_imp", "vel_imp", "dir_imp",
                  "llu_imp", "rs_imp", "pre_imp")

COL_OBS   <- "#2B2B2B"
COL_SYNTH <- "#377EB8"
COL_LINE  <- "#E41A1C"


#=========================================================
#  STEP 1: Load panel
#=========================================================

cat("=== Loading panel ===\n")
df <- read_csv(INFILE, show_col_types = FALSE)

# S4 (revision_plan.md 3A.2): drop every Monday week containing a day of the
# 2023 rationing (2023-10-27 to 2023-12-15), i.e. the weeks starting 2023-10-23
# to 2023-12-11, and renumber week_id; t_int below then falls on 2023-12-18.
stopifnot(nzchar(SENS) || Sys.getenv("AQ_DROP_RATIONING", "") == "")   # never on a main run
if (Sys.getenv("AQ_DROP_RATIONING", "") == "1") {
  rationing_weeks <- seq(as.Date("2023-10-23"), as.Date("2023-12-11"), by = "week")
  n_before <- n_distinct(df$week_date)
  df <- df %>% filter(!as.Date(week_date) %in% rationing_weeks)
  wk_map <- df %>% distinct(week_date) %>% arrange(week_date) %>% mutate(.wid = row_number())
  df <- df %>% left_join(wk_map, by = "week_date") %>% mutate(week_id = .wid) %>% select(-.wid)
  cat(sprintf("Rationing weeks dropped: %d (weeks %d -> %d)\n",
              n_before - n_distinct(df$week_date), n_before, n_distinct(df$week_date)))
}

cat(sprintf("Pollutant: %s\n", toupper(POLLUTANT)))
cat(sprintf("Rows: %d, Stations: %d, Weeks: %d\n",
            nrow(df), n_distinct(df$estacion), n_distinct(df$week_id)))
cat(sprintf("Date range: %s to %s\n", min(df$week_date), max(df$week_date)))


#=========================================================
#  STEP 2: Outcome and treatment variables
#=========================================================

df <- df %>%
  mutate(
    ln_outcome = log(.data[[OUTCOME_RAW]]),
    week_date = as.Date(week_date),
    month = month(week_date)
  )

t_int <- df %>%
  filter(week_date >= floor_date(TREATMENT_DATE, "week", week_start = 1)) %>%
  pull(week_id) %>%
  min()

df <- df %>%
  mutate(
    treated           = as.integer(estacion %in% c("centro", "belisario") &
                                     week_id >= t_int),
    treated_centro    = as.integer(estacion == "centro" & week_id >= t_int),
    treated_belisario = as.integer(estacion == "belisario" & week_id >= t_int)
  )

n_pre  <- n_distinct(df$week_id[df$week_id < t_int])
n_post <- n_distinct(df$week_id[df$week_id >= t_int])

cat(sprintf("t_int = %d, Pre: %d weeks, Post: %d weeks\n", t_int, n_pre, n_post))

for (m in 2:12) {
  df[[paste0("month_", m)]] <- as.integer(df$month == m)
}


#=========================================================
#  STEP 3: Identify Phase 3 blackout weeks
#=========================================================

cat("\n=== Blackout identification (Phase 3 only) ===\n")

week_flags <- df %>%
  group_by(week_date, week_label, week_id) %>%
  summarise(po = mean(poweroutage, na.rm = TRUE),
            wf = mean(wildfire, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(week_date)

blackout_week_ids <- week_flags %>%
  filter(week_date >= BLACKOUT_START &
         week_date <= BLACKOUT_END &
         (po > PO_THRESHOLD | wf > WF_THRESHOLD)) %>%
  pull(week_id)

cat(sprintf("Phase 3 blackout weeks flagged: %d\n", length(blackout_week_ids)))


#=========================================================
#  STEP 4: Classify post-treatment weeks
#  These are RAW week_ids -- used directly to index ATT vectors
#=========================================================

post_weeks <- week_flags %>%
  filter(week_id >= t_int) %>%
  mutate(
    is_blackout = week_id %in% blackout_week_ids,
    period = case_when(
      is_blackout ~ "blackout",
      week_date < BLACKOUT_START ~ "period1",
      week_date > BLACKOUT_END ~ "period2",
      TRUE ~ "blackout"
    )
  )

# Raw week_ids for indexing into ATT vector
all_post_ids    <- post_weeks$week_id
clean_post_ids  <- post_weeks %>% filter(!is_blackout) %>% pull(week_id)
p1_ids          <- post_weeks %>% filter(period == "period1") %>% pull(week_id)
p2_ids          <- post_weeks %>% filter(period == "period2") %>% pull(week_id)
blackout_ids    <- post_weeks %>% filter(is_blackout) %>% pull(week_id)

cat(sprintf("\nPost-treatment breakdown:\n"))
cat(sprintf("  Period 1 (Dec 2023 - mid Sep 2024):  %d weeks (ids %d-%d)\n",
            length(p1_ids), min(p1_ids), max(p1_ids)))
cat(sprintf("  Phase 3 blackout:                    %d weeks (ids %d-%d)\n",
            length(blackout_ids), min(blackout_ids), max(blackout_ids)))
cat(sprintf("  Period 2 (Jan 2025+):                %d weeks (ids %d-%d)\n",
            length(p2_ids), min(p2_ids), max(p2_ids)))
cat(sprintf("  Clean (non-blackout):                %d weeks\n", length(clean_post_ids)))


#=========================================================
#  STEP 5: Residualize for SDID
#=========================================================

cat("\n=== SDID residualization ===\n")

month_dummies <- paste0("month_", 2:12)
resid_formula <- as.formula(
  paste("ln_outcome ~", paste(c(WEATHER_VARS, month_dummies), collapse = " + "))
)

reg_adj <- feols(resid_formula,
                 data = df %>% filter(treated == 0 & treated_belisario == 0))

df$ln_outcome_pred <- predict(reg_adj, newdata = df)
df$ln_outcome_adj  <- df$ln_outcome - df$ln_outcome_pred +
                      mean(df$ln_outcome, na.rm = TRUE)


#=========================================================
#  STEP 6: SDID donut panel (Phase 3 dropped)
#=========================================================

df_donut <- df %>%
  filter(!week_id %in% blackout_week_ids)

donut_week_map <- df_donut %>%
  distinct(week_date, week_label, week_id) %>%
  arrange(week_date) %>%
  mutate(week_id_donut = row_number())

df_donut <- df_donut %>%
  left_join(donut_week_map %>% select(week_id, week_id_donut), by = "week_id") %>%
  mutate(week_id_orig = week_id,
         week_id = week_id_donut) %>%
  select(-week_id_donut)

t_int_donut <- donut_week_map %>%
  filter(week_date >= floor_date(TREATMENT_DATE, "week", week_start = 1)) %>%
  slice_min(week_date) %>%
  pull(week_id_donut)

df_donut <- df_donut %>%
  mutate(
    treated           = as.integer(estacion %in% c("centro", "belisario") &
                                     week_id >= t_int_donut),
    treated_centro    = as.integer(estacion == "centro" &
                                     week_id >= t_int_donut),
    treated_belisario = as.integer(estacion == "belisario" &
                                     week_id >= t_int_donut)
  )

n_pre_donut  <- n_distinct(df_donut$week_id[df_donut$week_id < t_int_donut])
n_post_donut <- n_distinct(df_donut$week_id[df_donut$week_id >= t_int_donut])

cat(sprintf("\nSDID donut: %d pre + %d post (dropped %d Phase 3 weeks)\n",
            n_pre_donut, n_post_donut, length(blackout_week_ids)))
cat(sprintf("Pre-treatment: %d (full) vs %d (donut) -- should match\n",
            n_pre, n_pre_donut))


#=========================================================
#  STEP 7: Summary
#=========================================================

cat("\n=== Panel summary ===\n")
cat(sprintf("Pollutant: %s\n", toupper(POLLUTANT)))
cat(sprintf("Stations: %s\n", paste(sort(unique(df$estacion)), collapse = ", ")))
cat(sprintf("Full panel: %d weeks (%d pre, %d post)\n",
            n_pre + n_post, n_pre, n_post))
cat(sprintf("Donut panel: %d weeks (%d pre, %d post)\n",
            n_pre_donut + n_post_donut, n_pre_donut, n_post_donut))

cat("\n=== SETUP COMPLETE ===\n")
