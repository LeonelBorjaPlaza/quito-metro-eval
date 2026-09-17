# Run once from the repository root. This is the only Phase C script that reads raw Waze.
source("Scripts/Congestion/inventory_helpers.R")
out <- "Data/Waze/parquet"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
paths <- file.path(out, paste0(c("all_roadtype", "large"), ".parquet"))
manifest_path <- file.path(out, "deduplication_manifest.rds")
if (all(file.exists(c(paths, manifest_path)))) {
  message("Reusing the two deduplicated blocks; no raw scan.")
} else {
  stopifnot(!any(file.exists(c(paths, manifest_path))))
  con <- connect_waze()
  # GROUP BY ALL both removes exact copies and preserves their source multiplicity.
  DBI::dbExecute(con, "CREATE TABLE distinct_blocks AS SELECT *, count(*)::INTEGER raw_multiplicity
    FROM raw WHERE roadtype IN ('all_roadtype','large') GROUP BY ALL")
  proof <- DBI::dbGetQuery(con, "SELECT roadtype, count(*) distinct_rows, sum(raw_multiplicity) raw_rows,
    count(DISTINCT (grid_id,date,hour_of_day)) distinct_keys FROM distinct_blocks GROUP BY roadtype")
  stopifnot(all(proof$distinct_rows == proof$distinct_keys),
    proof$distinct_rows[proof$roadtype == "all_roadtype"] == 1314213,
    proof$distinct_rows[proof$roadtype == "large"] == 852218)
  for (block in c("all_roadtype", "large")) DBI::dbExecute(con, sprintf(
    "COPY (SELECT * FROM distinct_blocks WHERE roadtype='%s' ORDER BY grid_id,date,hour_of_day)
     TO '%s/%s.parquet' (FORMAT PARQUET, COMPRESSION ZSTD)", block, out, block))
  manifest <- list(source = parquet_path, source_bytes = file.info(parquet_path)$size,
    source_md5 = unname(tools::md5sum(parquet_path)), proof = proof,
    rule = "Exact full-row deduplication, retain raw_multiplicity; no outcome transformations",
    created = as.character(Sys.time()))
  saveRDS(manifest, manifest_path)
  DBI::dbDisconnect(con, shutdown = TRUE)
  message("Wrote both blocks. All subsequent work reads Data/Waze/parquet only.")
}
print(readRDS(manifest_path)$proof)
