stopifnot(file.exists("AGENTS.md"))
Sys.setenv(TZ = "America/New_York")
.libPaths(c(normalizePath("Output/Waze/_environment/R-library"), .libPaths()))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(ggplot2))
options(width = 160)
out <- "Output/Waze/descriptives"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dates <- as.integer(format(seq(as.Date("2019-01-01"), as.Date("2025-12-01"), by = "month"), "%Y%m"))
gap <- c(202502L, 202503L, 202504L)
outcomes <- c("tci_osm_ratio", "tci_severe_osm_ratio", "avg_jam_speed_ratio", "tc_spread")
labels <- c(tci_osm_ratio = "TCI / OSM (%)", tci_severe_osm_ratio = "Severe TCI / OSM (%)",
            avg_jam_speed_ratio = "Jam speed / free flow (%)", tc_spread = "TCS spread (metres)")
cols <- c(CENTER = "#bc3b32", BELISARIO = "#225ea8", CORRIDOR = "#8856a7", RING = "#d89920",
          REST = "#777777", REST_saturated = "#00856a")
date_month <- function(x) as.Date(paste0(substr(x, 1, 4), "-", substr(x, 5, 6), "-01"))
safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
fmt <- function(x, digits = 4L) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "f"))
md_table <- function(x) {
  x <- as.data.frame(x)
  x[] <- lapply(x, function(v) if (is.numeric(v)) fmt(v) else as.character(v))
  c(paste0("| ", paste(names(x), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(x)), collapse = " | "), " |"),
    apply(x, 1, function(v) paste0("| ", paste(v, collapse = " | "), " |")))
}
connect_clean <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:")
  DBI::dbExecute(con, "SET threads=4")
  DBI::dbExecute(con, "SET memory_limit='4GB'")
  for (b in c("all_roadtype", "large")) DBI::dbExecute(con, sprintf(
    "CREATE VIEW %s AS SELECT * FROM read_parquet('Data/Waze/parquet/%s.parquet')", b, b))
  con
}
calendar <- function(p, pre_only = FALSE) {
  p <- p + theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  if (!pre_only) p <- p +
    annotate("rect", xmin = as.Date("2024-09-01"), xmax = as.Date("2025-01-01"), ymin = -Inf, ymax = Inf,
             fill = "grey40", alpha = .13) +
    annotate("rect", xmin = as.Date("2025-02-01"), xmax = as.Date("2025-05-01"), ymin = -Inf, ymax = Inf,
             fill = "#e9a128", alpha = .24) +
    geom_vline(xintercept = as.Date("2023-12-01"), colour = "#9c3026", linetype = "dashed")
  p
}
cal_caption <- "Dashed: Dec 2023 opening. Grey: Sep-Dec 2024 disruption. Amber: Feb-Apr 2025 delivery gap (NA)."
save_plot <- function(p, name, width = 11, height = 7) {
  ggsave(file.path(out, paste0(name, ".png")), p, width = width, height = height, dpi = 150)
}
