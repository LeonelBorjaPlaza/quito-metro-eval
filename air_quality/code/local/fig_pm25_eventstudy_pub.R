#==============================================================================
#  fig_pm25_eventstudy_pub.R   (v2)
#  Publication event-study figure, PM2.5, FE specification (Centro treated,
#  Belisario retained in donor pool; augmented SCM + unit FE + weather).
#  Single panel. NO title, NO caption, NO in-graph notes (put those in LaTeX).
#  y-axis = log ATT. Disruption window shaded (unlabelled).
#
#  Inset summary box = the three estimation samples, read directly from
#  CrossSample_Summary_PM25.csv (matches the paper table; nothing hand-keyed):
#      Pre-disruption (P1) | Donut (P1+P2) | Full post
#  showing log ATT and the two-sided conformal p for each.
#
#  Reads from disk only -- NO re-estimation:
#    output/local/tables/att_weekly_PM25.csv                 (weekly path; FE = "M8b:")
#    output/local/crosssample/CrossSample_Summary_PM25.csv   (window ATT + conformal p)
#==============================================================================

suppressPackageStartupMessages({ library(dplyr); library(readr); library(stringr); library(ggplot2) })

## ---- paths ----
ROOT       <- if (exists("ROOT_DIR")) ROOT_DIR else here::here()
tables_dir <- file.path(ROOT, "output", "local", "tables")
cross_dir  <- file.path(ROOT, "output", "local", "crosssample")
figs_dir   <- file.path(ROOT, "output", "local", "figures")
dir.create(figs_dir, showWarnings = FALSE, recursive = TRUE)

## ---- timeline constants (use in-memory setup values if present) ----
TREATMENT_DATE <- if (exists("TREATMENT_DATE")) as.Date(TREATMENT_DATE) else as.Date("2023-12-04")
BLACKOUT_START <- if (exists("BLACKOUT_START")) as.Date(BLACKOUT_START) else as.Date("2024-09-15")
BLACKOUT_END   <- if (exists("BLACKOUT_END"))   as.Date(BLACKOUT_END)   else as.Date("2024-12-31")

## ---- palette (verbatim from headline_event_study_M5b) ----
COL_LINE   <- "#1f3a5f"   # ATT line
COL_RIBBON <- "#377EB8"   # CI ribbon
COL_BAND   <- "gray60"    # disruption shading

## ---- 1. weekly ATT path (FE spec) ----
att <- read_csv(file.path(tables_dir, "att_weekly_PM25.csv"), show_col_types = FALSE)
fe  <- att %>% filter(str_detect(model, "^M8b:")) %>% arrange(week_date)
if (nrow(fe) == 0)
  stop("No FE-spec rows ('M8b:') in att_weekly_PM25.csv. Re-run legacy 04_PM2.5.R.")

## Break the line/ribbon across calendar gaps (e.g. the 7-week PM2.5 hole in
## early 2025): insert one NA-valued row at the midpoint of any >7-day jump so
## geom_line/geom_ribbon do not interpolate a flat segment across absent weeks.
gap_idx <- which(diff(as.numeric(fe$week_date)) > 7)
if (length(gap_idx) > 0) {
  fillers <- tibble(
    week_date = fe$week_date[gap_idx] + (fe$week_date[gap_idx + 1] - fe$week_date[gap_idx]) / 2,
    estimate = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_)
  fe <- bind_rows(fe, fillers) %>% arrange(week_date)
}

## ---- 2. per-window summary, straight from CrossSample_Summary (no hand-keying) ----
cs <- read_csv(file.path(cross_dir, "CrossSample_Summary_PM25.csv"), show_col_types = FALSE)
box_df <- cs %>%
  filter(spec == "M8b", sample %in% c("pre_blackout", "donut", "full")) %>%
  mutate(ord = match(sample, c("pre_blackout", "donut", "full")),
         lab = c("Pre-disruption", "Donut", "Full post")[ord]) %>%
  arrange(ord)
if (nrow(box_df) != 3)
  stop("Expected 3 M8b rows (pre_blackout/donut/full) in CrossSample_Summary_PM25.csv; got ",
       nrow(box_df), ".")

## period tags shown next to the names; "full post" gets none
tag <- c("Pre-disruption" = " (P1)", "Donut" = " (P1+P2)", "Full post" = "")
## readable lines in the plot's own (sans) font -- no monospace table
box_lines <- sprintf("%s%s:  %.3f   (p = %.3f)",
                     box_df$lab, tag[box_df$lab], box_df$att_log, box_df$p_2s)
box_txt   <- paste(box_lines, collapse = "\n")

## anchor the box at the BOTTOM, just after the opening (post-period, above the x-axis)
xr <- range(fe$week_date, na.rm = TRUE)
yr <- range(c(fe$ci_lower, fe$ci_upper, fe$estimate), na.rm = TRUE)
x_box <- TREATMENT_DATE + 0.015 * diff(as.numeric(xr))   # just right of the opening line
y_box <- yr[1] + 0.02 * diff(yr)                          # just above the panel floor

## P1 / P2 labels centred over their windows, near the top
p1_mid <- TREATMENT_DATE + (BLACKOUT_START - TREATMENT_DATE) / 2
p2_mid <- BLACKOUT_END   + (xr[2] - BLACKOUT_END) / 2
y_top  <- yr[2] - 0.01 * diff(yr)

## ---- 3. figure ----
p <- ggplot(fe, aes(x = week_date, y = estimate)) +
  annotate("rect", xmin = BLACKOUT_START, xmax = BLACKOUT_END,
           ymin = -Inf, ymax = Inf, alpha = 0.15, fill = COL_BAND) +
  geom_hline(yintercept = 0, color = "gray40", linewidth = 0.4) +
  geom_vline(xintercept = TREATMENT_DATE, linetype = "dashed",
             color = "gray30", linewidth = 0.5) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, fill = COL_RIBBON) +
  geom_line(color = COL_LINE, linewidth = 0.7) +
  annotate("text", x = p1_mid, y = y_top, label = "P1",
           vjust = 1, size = 3.4, color = "gray35", fontface = "italic") +
  annotate("text", x = p2_mid, y = y_top, label = "P2",
           vjust = 1, size = 3.4, color = "gray35", fontface = "italic") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "ATT (log points)") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(file.path(figs_dir, "fig_pm25_eventstudy.png"), p, width = 8, height = 5, dpi = 300)
ggsave(file.path(figs_dir, "fig_pm25_eventstudy.pdf"), p, width = 8, height = 5)
cat("Wrote: fig_pm25_eventstudy.png and .pdf  ->", figs_dir, "\n")
