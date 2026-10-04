# Amendment 2 to 4 panel: weighted unit-month series for the new units, under both flag rules, from the
# Step 1 cell-month blocks (pre period only). Donor pools are the frozen Step 1 pools minus the buffer
# around the new CENTER (Amendment 4, item 2). Fixed composition: a unit-month exists only if every
# positive-weight cell is valid.
source("Scripts/Congestion/step1_helpers.R")
source("Scripts/Congestion/amend2_helpers.R")
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
geog <- readRDS(file.path(AMEND2_DATA, "geography.rds"))
stopifnot(identical(panel$months, PRE_MONTHS))
UNITS <- c("CENTER", "CORE", "RING7", "BELISARIO_RW", "BELISARIO_EQ", "CORRIDOR")
POOLS <- c("primary_screened", "primary_unscreened", "low_exposure_screened", "low_exposure_unscreened")

by_rule <- lapply(panel$rules, function(pr) {
  cb <- pr$cell_block
  series <- rbindlist(lapply(UNITS, function(u) {
    w <- geog$unit_cells[unit == u & kept == TRUE, .(grid_id, weight)]
    rbindlist(lapply(c("peak", "morning", "evening"), function(b) unit_series(cb, w, b)[, `:=`(unit = u, block = b)]))
  }))
  # Step 1 replication check: RING7 with equal weights is Step 1's CENTER, BELISARIO_EQ is Step 1's BELISARIO.
  for (pair in list(c("RING7", "CENTER"), c("BELISARIO_EQ", "BELISARIO"))) {
    a <- series[unit == pair[1] & block == "peak"][order(date), value]
    b <- pr$unit_month[unit == pair[2] & block == "peak"][order(date), value]
    stopifnot(isTRUE(all.equal(a, b, tolerance = 1e-12)))
  }
  # The rebuilt pools must equal the frozen Step 1 pools before the buffer is removed.
  frozen <- fread(file.path(FREEZE_DIR, "donor_pools.csv"))[rule == pr$rule]
  for (p in POOLS) stopifnot(setequal(pr$cells[get(paste0("pool_", p)) == TRUE, grid_id], frozen[get(paste0("pool_", p)) == TRUE, grid_id]))
  pools <- lapply(setNames(POOLS, POOLS), function(p)
    sort(setdiff(pr$cells[get(paste0("pool_", p)) == TRUE, grid_id], geog$buffer_cells)))
  stopifnot(!any(unlist(pools) %in% c(geog$center_cells, geog$buffer_cells, panel$rings$BELISARIO, geog$corridor_cells)))
  dm <- dcast(pr$donor_month[block == "peak"], grid_id ~ date, value.var = "value")
  Y0_all <- as.matrix(dm[, -1]); rownames(Y0_all) <- dm$grid_id
  list(rule = pr$rule, series = series, pools = pools, Y0_all = Y0_all, slots = pr$slots, cells = pr$cells,
       cell_block = pr$cell_block[block == "peak" & grid_id %in% geog$center_cells])
})

validity <- rbindlist(lapply(by_rule, function(r) r$series[block == "peak", .(
  rule = r$rule, valid_months = sum(!is.na(value)), missing_months = sum(is.na(value)),
  missing_detail = paste(sprintf("%d (%s)", date[is.na(value)], reason[is.na(value)]), collapse = "; ")), by = unit]))
pool_sizes <- rbindlist(lapply(by_rule, function(r) data.table(rule = r$rule, pool = names(r$pools), donors = lengths(r$pools),
  frozen_donors = sapply(names(r$pools), function(p) sum(r$cells[[paste0("pool_", p)]])))))
pool_sizes[, removed_by_buffer := frozen_donors - donors]

saveRDS(list(label = AMEND2_LABEL, rules = by_rule, validity = validity, pool_sizes = pool_sizes),
        file.path(AMEND2_DATA, "panel.rds"))
fwrite(validity, file.path(AMEND2_OUT, "unit_month_validity.csv"))
fwrite(pool_sizes, file.path(AMEND2_OUT, "donor_pool_sizes.csv"))
print(validity); print(pool_sizes)
