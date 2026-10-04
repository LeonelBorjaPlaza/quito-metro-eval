# Step 1, item 3a. Pre-only deduplicated all_roadtype block, rebuilt from the raw Parquet.
# Same rule as 02_prepare_blocks.R (exact full-row deduplication, source multiplicity kept),
# restricted in SQL to January 2022 to November 2023, so no later row is returned or written.
source("Scripts/Congestion/step1_helpers.R")
out_dir <- dirname(pre_block)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
manifest_path <- file.path(out_dir, "manifest.rds")
unlink(c(pre_block, manifest_path))

con <- duck()
DBI::dbExecute(con, sprintf(paste(
  "CREATE TABLE distinct_pre AS SELECT *, count(*)::INTEGER AS raw_multiplicity",
  "FROM read_parquet(%s) WHERE roadtype = 'all_roadtype' AND date BETWEEN %d AND %d GROUP BY ALL"),
  DBI::dbQuoteString(con, raw_parquet), PRE_FIRST, PRE_LAST))
proof <- as.data.table(DBI::dbGetQuery(con, paste(
  "SELECT count(*) AS distinct_rows, sum(raw_multiplicity) AS raw_rows,",
  "count(DISTINCT (grid_id, date, hour_of_day)) AS distinct_keys, min(date) AS first_month,",
  "max(date) AS last_month, count(DISTINCT date) AS months FROM distinct_pre")))
# Every repeated key must be an exact copy, and only pre-period months may be present.
stopifnot(proof$distinct_rows == proof$distinct_keys, proof$first_month == PRE_FIRST,
          proof$last_month == PRE_LAST, proof$months == length(PRE_MONTHS))
DBI::dbExecute(con, sprintf(
  "COPY (SELECT * FROM distinct_pre ORDER BY grid_id, date, hour_of_day) TO %s (FORMAT PARQUET, COMPRESSION ZSTD)",
  DBI::dbQuoteString(con, pre_block)))
DBI::dbDisconnect(con, shutdown = TRUE)

manifest <- list(source = raw_parquet, source_sha256 = sha256(raw_parquet), block = pre_block,
  block_sha256 = sha256(pre_block), proof = proof, months = c(PRE_FIRST, PRE_LAST),
  rule = "Exact full-row deduplication of roadtype all_roadtype, January 2022 to November 2023; raw_multiplicity kept",
  created = as.character(Sys.time()))
saveRDS(manifest, manifest_path)
print(proof)
