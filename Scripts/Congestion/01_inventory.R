# Rscript Scripts/Congestion/01_inventory.R
# Phase B only: inventory and descriptive coverage, with no effect estimation.
source("Scripts/Congestion/inventory_helpers.R")
main <- function() {
  con <- connect_waze()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  query <- function(sql) as.data.table(DBI::dbGetQuery(con, sql))
  schema <- query("DESCRIBE raw")
  keys <- c("grid_id", "date", "hour_of_day", "roadtype")
  measures <- setdiff(schema$column_name, keys)
  raw_n <- query("SELECT count(*) n FROM raw")$n
  message("Validating delivered polygons and constructing the provisional groups.")
  spatial <- make_spatial_groups(con)
  stopifnot(query("SELECT count(*) n FROM (SELECT DISTINCT grid_id FROM raw EXCEPT SELECT grid_id FROM cell_groups)")$n == 0)
  source_info <- data.frame(file = c(grid_path, csv_path, parquet_path),
    bytes = file.info(c(grid_path, csv_path, parquet_path))$size,
    mtime = as.character(file.info(c(grid_path, csv_path, parquet_path))$mtime))
  # Verify CSV once. Reuse only when both file sizes and modification times match.
  certificate_path <- file.path(inventory_dir, "csv_parquet_certificate.rds")
  certificate <- if (file.exists(certificate_path)) readRDS(certificate_path) else NULL
  if (is.null(certificate) || !identical(certificate$source_info, source_info)) {
    message("Checking the full CSV row count and a seeded sample of all 24 fields in one scan.")
    set.seed(20260917)
    indices <- sort(sample.int(as.numeric(raw_n), 256L) - 1L)
    names_csv <- c("delivery_row_index", schema$column_name)
    types_csv <- c("BIGINT", schema$column_type)
    sql_strings <- function(x) paste(DBI::dbQuoteString(con, x), collapse = ",")
    csv_sql <- sprintf("read_csv(%s, header=true, names=[%s], types=[%s])",
      DBI::dbQuoteString(con, csv_path), sql_strings(names_csv), sql_strings(types_csv))
    sample_where <- paste0("delivery_row_index IN (", paste(indices, collapse = ","), ")")
    expressions <- vapply(names_csv, function(column) sprintf(
      "list(%s ORDER BY delivery_row_index) FILTER (WHERE %s) AS %s",
      DBI::dbQuoteIdentifier(con, column), sample_where, DBI::dbQuoteIdentifier(con, paste0("s_", column))), character(1))
    csv_result <- DBI::dbGetQuery(con, paste("SELECT count(*) n_rows, min(delivery_row_index) min_index,",
      "max(delivery_row_index) max_index,", paste(expressions, collapse = ","), "FROM", csv_sql))
    csv_sample <- as.data.frame(lapply(csv_result[paste0("s_", names_csv)], function(x) x[[1]]))
    names(csv_sample) <- names_csv
    parquet_sample <- DBI::dbGetQuery(con, sprintf(
      "SELECT file_row_number AS delivery_row_index, * EXCLUDE (file_row_number) FROM read_parquet(%s, file_row_number=true) WHERE file_row_number IN (%s) ORDER BY file_row_number",
      DBI::dbQuoteString(con, parquet_path), paste(indices, collapse = ",")))
    comparison <- rbindlist(lapply(names_csv, function(column) {
      a <- csv_sample[[column]]; b <- parquet_sample[[column]]
      equal <- is.na(a) & is.na(b)
      valid <- !is.na(a) & !is.na(b)
      if (is.numeric(a)) {
        difference <- abs(as.numeric(a[valid]) - as.numeric(b[valid]))
        equal[valid] <- difference <= 1e-12 * pmax(1, abs(as.numeric(b[valid])))
        maximum <- max(c(0, difference))
      } else { equal[valid] <- a[valid] == b[valid]; maximum <- NA_real_ }
      data.table(column, matches = sum(equal), mismatches = sum(!equal), maximum_absolute_difference = maximum)
    }))
    stopifnot(csv_result$n_rows == raw_n, nrow(csv_sample) == 256L, all(comparison$mismatches == 0))
    certificate <- list(source_info = source_info, raw_csv_rows = csv_result$n_rows,
      parquet_rows = raw_n, sampled_physical_rows = indices, comparison = comparison,
      csv_extra_field = "Unnamed serialized row index, renamed delivery_row_index for validation only",
      csv_index_range = c(csv_result$min_index, csv_result$max_index),
      checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE), seed = 20260917L)
    saveRDS(certificate, certificate_path)
  } else message("Reusing the one-time CSV certificate; all current reads use Parquet.")
  message("Checking duplicate keys and calculating raw-field diagnostics.")
  duplicate_keys <- query(paste("SELECT count(*) n_keys, max(n) max_multiplicity, sum(n-1) extra_rows FROM",
    "(SELECT grid_id,date,hour_of_day,roadtype,count(*) n FROM raw GROUP BY ALL)"))
  DBI::dbExecute(con, "CREATE TABLE canonical AS SELECT DISTINCT * FROM raw")
  canonical_n <- query("SELECT count(*) n FROM canonical")$n
  stopifnot(canonical_n == duplicate_keys$n_keys)
  multiplicity <- query("SELECT multiplicity, count(*) n_keys FROM (SELECT grid_id,date,hour_of_day,roadtype,count(*) multiplicity FROM raw GROUP BY ALL) GROUP BY multiplicity ORDER BY multiplicity")
  roadtypes <- query("SELECT roadtype, count(*) distinct_rows, count(DISTINCT grid_id) cells, count(DISTINCT date) n_months FROM canonical GROUP BY roadtype ORDER BY roadtype")
  roadtype_raw <- query("SELECT roadtype, count(*) raw_rows FROM raw GROUP BY roadtype")
  roadtypes <- merge(roadtypes, roadtype_raw, by = "roadtype")
  numeric_columns <- schema[column_type != "VARCHAR", column_name]
  expressions <- unlist(lapply(seq_len(nrow(schema)), function(i) {
    column <- schema$column_name[i]; id <- DBI::dbQuoteIdentifier(con, column)
    numeric <- column %in% numeric_columns
    expressions <- c(paste0("cast(min(", id, ") AS VARCHAR)"), paste0("cast(max(", id, ") AS VARCHAR)"),
      paste0("count(*) FILTER (WHERE ", id, " IS NULL)"),
      if (numeric) paste0("count(*) FILTER (WHERE ", id, " = -998)") else "0",
      if (numeric) paste0("count(*) FILTER (WHERE ", id, " = -999)") else "0",
      if (numeric) paste0("min(", id, ") FILTER (WHERE ", id, " NOT IN (-998,-999))") else "NULL",
      if (numeric) paste0("max(", id, ") FILTER (WHERE ", id, " NOT IN (-998,-999))") else "NULL",
      if (numeric) paste0("count(*) FILTER (WHERE NOT isfinite(", id, "))") else "0",
      if (numeric) paste0("count(*) FILTER (WHERE ", id, " < 0 AND ", id, " NOT IN (-998,-999))") else "0")
    paste0(expressions, " AS c", i, "_", seq_along(expressions))
  }))
  wide <- DBI::dbGetQuery(con, paste("SELECT", paste(expressions, collapse = ","), "FROM raw"))
  columns <- rbindlist(lapply(seq_len(nrow(schema)), function(i) {
    value <- lapply(seq_len(9L), function(j) wide[[paste0("c", i, "_", j)]][1])
    data.table(column = schema$column_name[i], type = schema$column_type[i], raw_min = value[[1]], raw_max = value[[2]],
      n_na = value[[3]], n_998 = value[[4]], n_999 = value[[5]], clean_min = value[[6]], clean_max = value[[7]],
      n_nonfinite = value[[8]], n_negative_nonsentinel = value[[9]])
  }))
  columns[, `:=`(na_pct = 100 * n_na/as.numeric(raw_n), sentinel_998_pct = 100 * n_998/as.numeric(raw_n),
                 sentinel_999_pct = 100 * n_999/as.numeric(raw_n))]
  DBI::dbExecute(con, paste("CREATE VIEW hygienic AS SELECT", paste(c(keys, vapply(measures, function(column)
    sprintf("CASE WHEN %s IN (-998,-999) THEN NULL ELSE %s END AS %s", column, column, column), character(1))), collapse = ","), "FROM canonical"))
  identity <- query(paste(
    "SELECT CASE WHEN grouping(roadtype)=1 THEN 'ALL BLOCKS (rowwise only)' ELSE roadtype END roadtype,",
    "count(*) n, count(*) FILTER (WHERE abs(residual)<=1e-8) within_1e8,",
    "max(abs(residual)) maximum_absolute_residual, avg(abs(residual)) mean_absolute_residual,",
    "quantile_cont(abs(residual),0.5) median_absolute_residual, quantile_cont(abs(residual),0.99) p99_absolute_residual,",
    "max(abs(t_speed_ratio-100*speed/freeflow_speed)) speed_freeflow_ratio_max_residual,",
    "max(abs(avg_freeflow-freeflow_speed)) freeflow_alias_max_difference FROM",
    "(SELECT *, t_speed_ratio-(100-tci_osm_ratio+tci_osm_ratio*avg_jam_speed_ratio/100) residual FROM hygienic)",
    "GROUP BY GROUPING SETS ((roadtype),()) ORDER BY roadtype"))
  anomalies <- query(paste("SELECT roadtype, count(*) n,",
    "count(*) FILTER (WHERE tci<=0) nonpositive_tci, count(*) FILTER (WHERE tci_osm_ratio=0) zero_tci_ratio,",
    "count(*) FILTER (WHERE tc_spread_osm_ratio<0) negative_spread_ratio,",
    "count(*) FILTER (WHERE tc_spread_osm_ratio>100) spread_ratio_over_100,",
    "count(*) FILTER (WHERE tc_severe_persistance_ratio>100) severe_persistence_over_100,",
    "count(*) FILTER (WHERE tci_severe_osm_ratio>tci_osm_ratio+1e-8) severe_over_total,",
    "count(*) FILTER (WHERE tci_waze_ratio<0) negative_waze_ratio FROM hygienic GROUP BY roadtype ORDER BY roadtype"))
  observed_months <- query("SELECT DISTINCT date FROM canonical ORDER BY date")$date
  calendar <- data.table(date = as.integer(format(seq(as.Date("2019-01-01"), as.Date("2025-12-01"), by = "month"), "%Y%m")))
  calendar[, `:=`(delivered_month = date %in% observed_months, period = period_of(date))]
  stopifnot(all(observed_months %in% calendar$date))
  DBI::dbWriteTable(con, "calendar", as.data.frame(calendar))
  DBI::dbExecute(con, paste(
    "CREATE VIEW completed_all AS SELECT g.grid_id,g.\"group\",c.date,c.delivered_month,c.period,h.hour_of_day,",
    "r.grid_id IS NOT NULL has_record,",
    "CASE WHEN NOT c.delivered_month THEN NULL WHEN r.grid_id IS NULL THEN 0 ELSE r.tci END tci,",
    "CASE WHEN NOT c.delivered_month THEN NULL WHEN r.grid_id IS NULL THEN 0 ELSE r.tc_spread END tc_spread,",
    "CASE WHEN NOT c.delivered_month THEN NULL WHEN r.grid_id IS NULL THEN 0 ELSE r.tci_osm_ratio END tci_osm_ratio,",
    "CASE WHEN NOT c.delivered_month THEN NULL WHEN r.grid_id IS NULL THEN 0 ELSE r.tci_severe_osm_ratio END tci_severe_osm_ratio,",
    "CASE WHEN NOT c.delivered_month THEN NULL WHEN r.grid_id IS NULL THEN 0 ELSE r.tc_spread_osm_ratio END spread_osm_ratio,",
    "r.avg_jam_speed_ratio,r.avg_freeflow FROM cell_groups g CROSS JOIN calendar c",
    "CROSS JOIN range(24) h(hour_of_day) LEFT JOIN (SELECT * FROM hygienic WHERE roadtype='all_roadtype') r",
    "ON r.grid_id=g.grid_id AND r.date=c.date AND r.hour_of_day=h.hour_of_day"))
  cell_month <- query(paste("SELECT grid_id, \"group\", date, bool_and(delivered_month) delivered_month,",
    "count(*) expected_cell_hours, count(*) FILTER (WHERE has_record) distinct_records,",
    "count(*) FILTER (WHERE tci>0) positive_congestion_cell_hours, avg(tc_spread) tcs_metres,",
    "avg(spread_osm_ratio) spread_osm_ratio_sentinel_clean FROM completed_all GROUP BY grid_id,\"group\",date"))
  coverage <- query(paste("SELECT CASE WHEN grouping(\"group\")=1 THEN 'OVERALL' ELSE \"group\" END \"group\", date,",
    "bool_and(delivered_month) delivered_month, count(DISTINCT grid_id) grid_cells, count(*) expected_cell_hours,",
    "count(DISTINCT grid_id) FILTER (WHERE has_record) cells_with_records, count(*) FILTER (WHERE has_record) distinct_records,",
    "count(*) FILTER (WHERE tci>0) positive_congestion_cell_hours,",
    "avg(CASE WHEN delivered_month THEN CASE WHEN tci>0 THEN 1.0 ELSE 0.0 END END) any_congestion_share,",
    "avg(tc_spread) tcs_metres, avg(spread_osm_ratio) spread_osm_ratio_sentinel_clean,",
    "count(*) FILTER (WHERE spread_osm_ratio<0 OR spread_osm_ratio>100) invalid_spread_ratio_hours",
    "FROM completed_all GROUP BY GROUPING SETS ((\"group\",date),(date)) ORDER BY \"group\",date"))
  distribution <- cell_month[, .(min_records = min(distinct_records), p25_records = as.numeric(quantile(distinct_records, .25)),
    median_records = median(distinct_records), p75_records = as.numeric(quantile(distinct_records,.75)),
    max_records = max(distinct_records)), by = .(group, date)]
  overall_distribution <- cell_month[, .(group = "OVERALL", min_records = min(distinct_records),
    p25_records = as.numeric(quantile(distinct_records,.25)), median_records = median(distinct_records),
    p75_records = as.numeric(quantile(distinct_records,.75)), max_records = max(distinct_records)), by = date]
  coverage <- merge(coverage, rbind(distribution, overall_distribution), by = c("group", "date"))
  coverage[, `:=`(month = date_month(date), mean_records_per_cell = distinct_records/grid_cells,
                  period = period_of(date))]
  saveRDS(cell_month, file.path(inventory_dir, "cell_month_coverage.rds"))
  saveRDS(coverage, file.path(inventory_dir, "monthly_coverage.rds"))
  fwrite(cell_month, file.path(inventory_dir, "cell_month_coverage.csv"))
  fwrite(coverage, file.path(inventory_dir, "monthly_coverage.csv"))
  monthly_roadtype <- query("SELECT date, roadtype, count(*) distinct_records, count(DISTINCT grid_id) cells FROM canonical GROUP BY date,roadtype ORDER BY date,roadtype")
  saveRDS(monthly_roadtype, file.path(inventory_dir, "monthly_roadtype_coverage.rds"))
  monthly_duplicates <- query(paste("SELECT date, count(*) raw_rows, count(DISTINCT (grid_id,hour_of_day)) unique_keys,",
    "count(*)*1.0/count(DISTINCT (grid_id,hour_of_day)) mean_copies FROM raw WHERE roadtype='all_roadtype' GROUP BY date ORDER BY date"))
  # The review sample deliberately includes all roadtypes. It is never aggregated across blocks.
  DBI::dbExecute(con, paste("CREATE VIEW review_candidates AS SELECT r.*,g.\"group\",c.period,",
    "CASE WHEN hour_of_day IN (7,8) THEN 'Morning peak' WHEN hour_of_day IN (17,18) THEN 'Evening peak'",
    "WHEN hour_of_day IN (22,23,0,1,2,3,4,5) THEN 'Night' ELSE 'Other' END hour_block,",
    "hash(r.grid_id,r.date,r.hour_of_day,r.roadtype,20260917) sample_order FROM canonical r",
    "JOIN cell_groups g USING(grid_id) JOIN calendar c USING(date)"))
  DBI::dbExecute(con, paste("CREATE TABLE review_seed AS SELECT * FROM review_candidates QUALIFY",
    "row_number() OVER(PARTITION BY \"group\",roadtype,period,hour_block ORDER BY sample_order,grid_id,date,hour_of_day)=1"))
  sample_seed_n <- query("SELECT count(*) n FROM review_seed")$n
  stopifnot(sample_seed_n <= 480L)
  DBI::dbExecute(con, sprintf(paste("CREATE TABLE review_sample AS SELECT * FROM review_seed UNION ALL",
    "(SELECT * FROM review_candidates ANTI JOIN review_seed USING(grid_id,date,hour_of_day,roadtype)",
    "ORDER BY sample_order,grid_id,date,hour_of_day,roadtype LIMIT %d)"), 500L-as.integer(sample_seed_n)))
  sample <- query(paste("SELECT s.* EXCLUDE(sample_order), d.raw_multiplicity FROM review_sample s",
    "JOIN (SELECT grid_id,date,hour_of_day,roadtype,count(*) raw_multiplicity FROM raw GROUP BY ALL) d",
    "USING(grid_id,date,hour_of_day,roadtype) ORDER BY \"group\",date,hour_of_day,roadtype,grid_id"))
  stopifnot(nrow(sample)==500L, length(unique(sample$group))==5L, length(unique(sample$roadtype))==6L)
  fwrite(sample, "reports/waze_sample.csv", na = "NA")
  message("Drawing full-period coverage plots and generating the inventory report.")
  plot_data <- copy(coverage)
  plot_data[,group:=factor(group,levels=c("CENTER","BELISARIO","CORRIDOR","RING","REST","OVERALL"))]
  calendar_caption <- "Dashed line: Dec 2023 opening. Shading: Sep–Dec 2024 disruption. March 2025 is absent from the delivery.\nOne all_roadtype record per cell-month-hour after exact deduplication; monitor neighborhoods use published points."
  plot <- mark_calendar(ggplot(plot_data, aes(month, cells_with_records))) + geom_line(colour = "#245b78", linewidth = .45) +
    facet_wrap(~group, ncol = 1, scales = "free_y") + labs(x = NULL, y = "Cells with a delivered record", title = "Delivered coverage by provisional group", caption = calendar_caption)
  ggsave(file.path(inventory_dir,"coverage_cells.png"),plot,width=10,height=10,dpi=160)
  plot <- mark_calendar(ggplot(plot_data, aes(month, mean_records_per_cell))) +
    geom_ribbon(aes(ymin=p25_records,ymax=p75_records),fill="#245b78",alpha=.18) +
    geom_line(colour="#245b78",linewidth=.45) + facet_wrap(~group,ncol=1) +
    labs(x=NULL,y="Delivered hour slots per cell-month",title="Record coverage, not underlying observation counts",
         caption=paste(calendar_caption,"\nLine: mean across all delivered-grid cells; band: cell-level interquartile range. Maximum is 24."))
  ggsave(file.path(inventory_dir,"coverage_cell_hours.png"),plot,width=10,height=10,dpi=160)
  proxies <- melt(plot_data,id.vars=c("group","month"),measure.vars=c("any_congestion_share","tcs_metres"),
                  variable.name="proxy",value.name="value")
  proxies[,proxy:=factor(proxy,levels=c("any_congestion_share","tcs_metres"),
    labels=c("Cell-hour share with any congestion","Mean TCS spread (metres)"))]
  plot <- mark_calendar(ggplot(proxies,aes(month,value))) + geom_line(colour="#245b78",linewidth=.45) +
    facet_wrap(vars(group,proxy),ncol=2,scales="free_y") + labs(x=NULL,y=NULL,title="Indirect penetration proxies, also sensitive to traffic",
    caption=paste(calendar_caption,"\nAbsent cell-hours in delivered months contribute zero. The globally missing month remains NA."))
  ggsave(file.path(inventory_dir,"indirect_penetration_proxies.png"),plot,width=12,height=11,dpi=160)
  zoom_data <- proxies[month>=as.Date("2023-01-01")]
  plot <- mark_calendar(ggplot(zoom_data,aes(month,value))) +
    annotate("rect",xmin=as.Date("2025-02-01"),xmax=as.Date("2025-05-01"),ymin=-Inf,ymax=Inf,fill="#d6a84b",alpha=.16) +
    geom_line(colour="#245b78",linewidth=.45) + geom_point(size=.6,na.rm=TRUE) +
    facet_wrap(vars(group,proxy),ncol=2,scales="free_y") +
    labs(x=NULL,y=NULL,title="Coverage warning around the missing March 2025 delivery",
         caption=paste(calendar_caption,"\nGold band marks February–April 2025 for provider review. The low adjacent months are not imputed or discarded."))
  ggsave(file.path(inventory_dir,"coverage_gap_2025.png"),plot,width=12,height=11,dpi=160)
  summary <- list(source_info=source_info, raw_rows=as.numeric(raw_n), distinct_rows=as.numeric(canonical_n),
    duplicate_keys=duplicate_keys, multiplicity=multiplicity, schema=schema, columns=columns,
    roadtypes=roadtypes, spatial=spatial, certificate=certificate, identity=identity, anomalies=anomalies,
    calendar=calendar, coverage=coverage, monthly_duplicates=monthly_duplicates, sample=sample, sample_seed_rows=sample_seed_n,
    n_hours=query("SELECT count(DISTINCT hour_of_day) n FROM canonical")$n,
    n_cells=query("SELECT count(DISTINCT grid_id) n FROM canonical")$n,
    raw_all_roadtype_rows=roadtypes[roadtype=="all_roadtype",raw_rows],
    session=sessionInfo())
  saveRDS(summary,file.path(inventory_dir,"inventory_summary.rds"))
  source("Scripts/Congestion/inventory_report.R",local=TRUE)
  write_inventory(summary)
  message("Running the independent audit in a new R session.")
  exit_status <- system2("Rscript", "Scripts/Congestion/01_audit_inventory.R")
  if(exit_status != 0L) stop("Independent inventory audit failed.")
  message("Phase B inventory and ten-number audit complete. No effect estimated.")
}
main()
