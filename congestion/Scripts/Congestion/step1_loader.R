# The only readers of Waze outcomes and road coverage in Step 1. Both fail if a month or year
# at or after the opening (December 2023) gets through.

# Outcome records from the pre-only deduplicated block (all_roadtype, January 2022 to November 2023).
load_pre_outcomes <- function(con, columns) {
  stopifnot(file.exists(pre_block), !any(c("date", "grid_id", "hour_of_day") %in% columns))
  sql <- sprintf(paste("SELECT grid_id, date::INTEGER AS date, hour_of_day::INTEGER AS hour_of_day, %s",
                       "FROM read_parquet(%s) WHERE date BETWEEN %d AND %d"),
                 paste(columns, collapse = ", "), DBI::dbQuoteString(con, pre_block), PRE_FIRST, PRE_LAST)
  x <- as.data.table(DBI::dbGetQuery(con, sql))
  stopifnot(nrow(x) > 0L, all(x$date >= PRE_FIRST), all(x$date <= PRE_LAST), all(x$date %in% PRE_MONTHS))
  x
}

# Cumulative Waze jam length per cell for 2019 to 2022 (Amendment 5, item 2 adoption check). No later
# year is read: 2023 contains a treated month.
load_waze_length_to_2022 <- function(con) {
  x <- as.data.table(DBI::dbGetQuery(con, sprintf(paste("SELECT year::INTEGER AS year, grid_id, waze_sum_length FROM read_csv(%s, header = true)",
    "WHERE roadtype = 'all_roadtype' AND year BETWEEN 2019 AND 2022"), DBI::dbQuoteString(con, roadlength_path))))
  stopifnot(nrow(x) > 0L, max(x$year) <= 2022L, !anyDuplicated(x[, .(grid_id, year)]))
  x
}

# 2022 all_roadtype road coverage per cell (plan section 3 screen). No other year is read.
load_coverage_2022 <- function(con) {
  sql <- sprintf(paste("SELECT year::INTEGER AS year, grid_id, waze_sum_length, osm_sum_length, perc_waze_coverage",
                       "FROM read_csv(%s, header = true) WHERE year = 2022 AND roadtype = 'all_roadtype'"),
                 DBI::dbQuoteString(con, roadlength_path))
  x <- as.data.table(DBI::dbGetQuery(con, sql))
  stopifnot(nrow(x) > 0L, all(x$year == 2022L), !anyDuplicated(x$grid_id))
  x
}
