# Fresh-session hostile-review check. Never sources inventory calculations or caches.
# Rscript Scripts/Congestion/01_audit_inventory.R
stopifnot(file.exists("reports/waze_inventory.md"))
Sys.setenv(TZ="America/New_York")
.libPaths(c(normalizePath("Output/Waze/_environment/R-library"),.libPaths()))
audit <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(shared_home=FALSE))
  on.exit(DBI::dbDisconnect(con,shutdown=TRUE))
  DBI::dbExecute(con,"SET threads=3")
  DBI::dbExecute(con,"SET memory_limit='4GB'")
  DBI::dbExecute(con,paste("SET temp_directory =",DBI::dbQuoteString(con,normalizePath("Output/Waze/_cache"))))
  DBI::dbExecute(con,paste("SET extension_directory =",DBI::dbQuoteString(con,normalizePath("Output/Waze/_environment/duckdb_extensions"))))
  DBI::dbExecute(con,"SET autoinstall_known_extensions=false")
  DBI::dbExecute(con,"LOAD h3")
  DBI::dbExecute(con,"CREATE VIEW delivery AS SELECT * FROM read_parquet('Data/Waze/raw/grids_quito_hourly_2019-2025.parquet')")
  # The polygon CSV is a raw reference, distinct from the hourly CSV already verified once.
  DBI::dbExecute(con,"CREATE VIEW polygon_delivery AS SELECT * FROM read_csv('Data/Waze/raw/grids_polygons.csv',header=true)")
  sql <- c(
    raw_rows="SELECT count(grid_id) FROM delivery",
    distinct_rows="SELECT count(*) FROM (SELECT grid_id,date,hour_of_day,roadtype FROM delivery GROUP BY grid_id,date,hour_of_day,roadtype)",
    extra_duplicate_rows="SELECT sum(copies-1) FROM (SELECT count(*) copies FROM delivery GROUP BY grid_id,date,hour_of_day,roadtype)",
    grid_cells="SELECT count(*) FROM polygon_delivery",
    observed_cells="SELECT count(*) FROM (SELECT grid_id FROM delivery GROUP BY grid_id)",
    unobserved_grid_cells="SELECT count(*) FROM polygon_delivery g WHERE NOT EXISTS (SELECT 1 FROM delivery d WHERE d.grid_id=g.grid_id)",
    observed_months="SELECT count(*) FROM (SELECT date FROM delivery GROUP BY date)",
    hour_labels="SELECT count(*) FROM (SELECT hour_of_day FROM delivery GROUP BY hour_of_day)",
    raw_allroad_rows="SELECT count(*) FROM delivery WHERE roadtype='all_roadtype'",
    distinct_allroad_rows="SELECT count(*) FROM (SELECT grid_id,date,hour_of_day FROM delivery WHERE roadtype='all_roadtype' GROUP BY grid_id,date,hour_of_day)",
    allroad_absent_delivered_slots=paste("SELECT (SELECT count(*) FROM polygon_delivery)*(SELECT count(DISTINCT date) FROM delivery)*24 -",
      "(SELECT count(*) FROM (SELECT grid_id,date,hour_of_day FROM delivery WHERE roadtype='all_roadtype' GROUP BY grid_id,date,hour_of_day))"),
    max_key_multiplicity="SELECT max(copies) FROM (SELECT count(*) copies FROM delivery GROUP BY grid_id,date,hour_of_day,roadtype)",
    raw_primary_max="SELECT max(tci_osm_ratio) FROM delivery WHERE tci_osm_ratio NOT IN(-998,-999)",
    distinct_primary_zero="SELECT count(*) FROM (SELECT grid_id,date,hour_of_day,roadtype FROM delivery WHERE tci_osm_ratio=0 GROUP BY grid_id,date,hour_of_day,roadtype)",
    raw_waze_tci_na="SELECT count(*)-count(tci_waze_ratio) FROM delivery",
    raw_waze_tci_sentinel="SELECT count(*) FROM delivery WHERE tci_waze_ratio=-998 OR tci_waze_ratio=-999",
    raw_spread_negative="SELECT count(*) FROM delivery WHERE tc_spread_osm_ratio<0 AND tc_spread_osm_ratio<>-998 AND tc_spread_osm_ratio<>-999",
    raw_severe_persistence_max="SELECT max(tc_severe_persistance_ratio) FROM delivery WHERE tc_severe_persistance_ratio NOT IN(-998,-999)",
    identity_max=paste("SELECT max(abs(t_speed_ratio - (100 + tci_osm_ratio*(avg_jam_speed_ratio/100-1)))) FROM delivery",
      "WHERE t_speed_ratio NOT IN(-998,-999) AND tci_osm_ratio NOT IN(-998,-999) AND avg_jam_speed_ratio NOT IN(-998,-999)"),
    freeflow_alias_max="SELECT max(abs(freeflow_speed-avg_freeflow)) FROM delivery WHERE freeflow_speed NOT IN(-998,-999) AND avg_freeflow NOT IN(-998,-999)",
    invalid_grid_h3="SELECT count(*) FROM polygon_delivery WHERE NOT h3_is_valid_cell(grid_id)",
    grid_centers_outside_box=paste("SELECT count(*) FROM polygon_delivery WHERE h3_cell_to_latlng(grid_id)[1] < -0.45",
      "OR h3_cell_to_latlng(grid_id)[1] > 0.05 OR h3_cell_to_latlng(grid_id)[2] < -78.62 OR h3_cell_to_latlng(grid_id)[2] > -78.30"),
    first_month="SELECT min(date) FROM delivery",last_month="SELECT max(date) FROM delivery")
  report <- readLines("reports/waze_inventory.md",warn=FALSE)
  marker <- match("<!-- INVENTORY_AUDIT_START -->",report)
  if(!is.na(marker)) report <- head(report,marker-1L)
  # Draw before reading any value. No seed search or substitution after seeing results.
  set.seed(9172026)
  chosen <- sample(names(sql),10L,replace=FALSE)
  results <- do.call(rbind,lapply(chosen,function(id) {
    line <- report[startsWith(report,paste0("| ",id," | "))]
    stopifnot(length(line)==1L)
    stated <- as.numeric(trimws(strsplit(line,"|",fixed=TRUE)[[1]][3]))
    recomputed <- as.numeric(DBI::dbGetQuery(con,sql[[id]])[[1]][1])
    tolerance <- 1e-10*max(1,abs(stated))
    data.frame(check=id,report_value=stated,raw_recomputed=recomputed,
      difference=recomputed-stated,result=if(is.finite(recomputed)&&abs(recomputed-stated)<=tolerance) "MATCH" else "MISMATCH")
  }))
  saveRDS(list(seed=9172026L,pool=names(sql),selected=chosen,results=results,queries=sql[chosen],
    R=R.version.string,duckdb=as.character(packageVersion("duckdb"))),"Output/Waze/inventory/independent_audit.rds")
  printable <- results
  printable[2:4] <- lapply(printable[2:4],function(v)sprintf("%.17g",v))
  table <- c(paste0("| ",paste(names(printable),collapse=" | ")," |"),
    "| --- | --- | --- | --- | --- |",
    apply(printable,1,function(v)paste0("| ",paste(v,collapse=" | ")," |")))
  writeLines(c(report,"<!-- INVENTORY_AUDIT_START -->","## Independent ten-number audit","",
    "A fresh R process drew ten checks uniformly without replacement from the 24 numeric checks listed above, using seed 9172026. Each value was read from the report text and independently recomputed from the raw Parquet or raw polygon CSV with separate SQL. The audit did not use the deduplicated inventory table, saved group table or coverage summaries. It never reopened the hourly CSV. Numerical matches use tolerance 1e-10 times max(1, absolute report value).","",table,"",
    sprintf("Matches: %d. Mismatches: %d. The draw, independent queries and results are saved in Output/Waze/inventory/independent_audit.rds.",sum(results$result=="MATCH"),sum(results$result=="MISMATCH"))),"reports/waze_inventory.md")
  print(results,row.names=FALSE)
  stopifnot(all(results$result=="MATCH"))
}
audit()
