#=========================================================
#  12_cross_pollutant_master.R
#  Combine the 4 per-pollutant results CSVs into a master,
#  filter to primary specs (M5b/M8b/M2b), and build the
#  headline 4-panel event study figure using M5b.
#
#  Run after 04/06/08/10 export blocks have all run.
#=========================================================

library(dplyr)
library(readr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(stringr)

# ---- Paths ----
root_dir   <- here::here()
tables_dir <- file.path(root_dir, "output", "local", "tables")
figs_dir   <- file.path(root_dir, "output", "local", "figures")

TREATMENT_DATE <- as.Date("2023-12-01")
# Headline-figure shading: calendar span of the flagged Phase 3 blackout
# weeks (the weeks the SDID donut drops) -- matches 11_descriptives.R.
BLACKOUT_START <- as.Date("2024-09-16")
BLACKOUT_END   <- as.Date("2024-12-16")

#---------------------------------------------------------
# 1. Load per-pollutant results, bind into master
#---------------------------------------------------------
cat("Loading per-pollutant results...\n")
results_files <- list(
  pm25 = file.path(tables_dir, "results_PM25.csv"),
  co   = file.path(tables_dir, "results_CO.csv"),
  no2  = file.path(tables_dir, "results_NO2.csv"),
  so2  = file.path(tables_dir, "results_SO2.csv")
)

results_all <- bind_rows(lapply(results_files, function(f) {
  read_csv(f, show_col_types = FALSE)
})) %>%
  mutate(
    spec_short = str_extract(model, "^M\\d+b?"),
    pollutant_label = case_when(
      pollutant == "pm25" ~ "PM2.5",
      pollutant == "co"   ~ "CO",
      pollutant == "no2"  ~ "NO2",
      pollutant == "so2"  ~ "SO2"
    ),
    treatment_config = case_when(
      spec_short %in% c("M1", "M4", "M7")   ~ "Centro+Belisario co-treated",
      spec_short %in% c("M2", "M5", "M8")   ~ "Centro treated, Belisario dropped",
      spec_short %in% c("M2b", "M5b", "M8b") ~ "Centro treated, Belisario in pool",
      spec_short %in% c("M3", "M6", "M9")   ~ "Belisario treated, Centro dropped"
    )
  ) %>%
  select(pollutant, pollutant_label, spec_short, method, treatment_config,
         everything())

write_csv(results_all, file.path(tables_dir, "results_all_pollutants.csv"))
cat(sprintf("  Wrote: results_all_pollutants.csv (%d rows)\n",
            nrow(results_all)))

#---------------------------------------------------------
# 2. Filter to primary specs
#---------------------------------------------------------
primary_specs <- c("M5b", "M8b", "M2b")

results_primary <- results_all %>%
  filter(spec_short %in% primary_specs) %>%
  arrange(factor(pollutant, levels = c("pm25", "co", "no2", "so2")),
          factor(spec_short, levels = primary_specs))

write_csv(results_primary,
          file.path(tables_dir, "results_primary_specs.csv"))
cat(sprintf("  Wrote: results_primary_specs.csv (%d rows)\n",
            nrow(results_primary)))

cat("\nPrimary specs across pollutants (Clean column):\n")
print(results_primary %>%
        select(pollutant, spec_short, method,
               att_clean_pct, att_p1_pct, att_p2_pct, p_2s, p_1s))


#---------------------------------------------------------
# 3. Headline figure: 4-panel event study using M5b
#---------------------------------------------------------
cat("\nBuilding headline event study figure (M5b)...\n")

att_files <- list(
  pm25 = file.path(tables_dir, "att_weekly_PM25.csv"),
  co   = file.path(tables_dir, "att_weekly_CO.csv"),
  no2  = file.path(tables_dir, "att_weekly_NO2.csv"),
  so2  = file.path(tables_dir, "att_weekly_SO2.csv")
)

att_all <- bind_rows(lapply(att_files, function(f) {
  read_csv(f, show_col_types = FALSE)
}))

# Column names from augsynth summary after the rename in run_augsynth:
# time, estimate, Std.Error, ci_lower, ci_upper, p_val, ...
att_m5b <- att_all %>%
  filter(str_detect(model, "^M5b:")) %>%
  mutate(
    pollutant_label = factor(
      pollutant,
      levels = c("pm25", "co", "no2", "so2"),
      labels = c("PM[2.5]", "CO", "NO[2]", "SO[2]")
    ),
    estimate_pct = (exp(estimate) - 1) * 100,
    ci_lower_pct = (exp(ci_lower) - 1) * 100,
    ci_upper_pct = (exp(ci_upper) - 1) * 100
  )

p_headline <- ggplot(att_m5b, aes(x = week_date, y = estimate_pct)) +
  annotate("rect",
           xmin = BLACKOUT_START, xmax = BLACKOUT_END,
           ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "gray60") +
  geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = TREATMENT_DATE, linetype = "dashed",
             color = "gray30", linewidth = 0.5) +
  geom_ribbon(aes(ymin = ci_lower_pct, ymax = ci_upper_pct),
              alpha = 0.2, fill = "#377EB8") +
  geom_line(color = "#1f3a5f", linewidth = 0.6) +
  facet_wrap(~ pollutant_label, scales = "free_y",
             labeller = label_parsed, ncol = 2) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "ATT (% change in pollutant level)",
       caption = paste("M5b primary specification (Centro treated, Belisario in donor pool, AugSynth with weather covariates).",
                       "Shaded ribbon: conformal pointwise CI. Vertical dashed: Metro Quito opening. Gray region: Phase 3 power outages.",
                       sep = "\n")) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1),
        strip.text = element_text(size = 12, face = "bold"),
        plot.caption = element_text(hjust = 0, size = 9, color = "gray30"))

ggsave(file.path(figs_dir, "headline_event_study_M5b.png"),
       plot = p_headline, width = 11, height = 7.5, dpi = 200)
ggsave(file.path(figs_dir, "headline_event_study_M5b.pdf"),
       plot = p_headline, width = 11, height = 7.5)
cat("  Wrote: headline_event_study_M5b.png and .pdf\n")

cat("\n=== Cross-pollutant master complete ===\n")