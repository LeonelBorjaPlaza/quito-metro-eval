# Report renderer for 01_inventory.R. Numeric Waze results come from its summary.
write_inventory <- function(s) {
  meanings <- c(
    date = "Month label YYYYMM, not an observation timestamp (provider section 7).",
    grid_id = "H3 resolution-8 cell identifier (section 3).",
    hour_of_day = "Hour label 0 through 23, averaged over days in the month (section 7.1).",
    roadtype = "Stacked free-flow speed class or all-road aggregate (section 3.1).",
    avg_jam_speedkmh = "Mean speed during observed congestion, km/h; dictionary jam_speedkmh alias (section 5.2).",
    avg_jam_speed_ratio = "Delivered mean jam-speed/free-flow percentage; candidate jam_speed_ratio alias (section 5.3).",
    avg_freeflow = "Monthly segment free flow aggregated to the reporting unit, km/h (section 5.1).",
    tci = "Traffic congestion intensity: summed jam-line length over feed observations, metres times observations, then summarized (section 4.1).",
    tci_severe = "Severe TCI, documented as severe_tci. Severe-event definition conflicts between sections 6 and 9.",
    tci_osm_ratio = "Primary outcome: 100 times TCI divided by OSM road length and nominal feed observations (section 4.2).",
    tci_waze_ratio = "TCI percentage normalized by the annually observed Waze road network (section 4.2).",
    tci_severe_osm_ratio = "Secondary outcome: severe TCI percentage with the OSM denominator (section 6).",
    tci_severe_waze_ratio = "Severe TCI percentage with the Waze network denominator (section 6).",
    tc_spread = "TCS: length of segments congested at least once in the source window, metres, then summarized (section 4.3).",
    tc_severe_spread = "TCS restricted to severe events, metres (section 6).",
    tc_spread_osm_ratio = "100 times TCS divided by OSM road length (section 4.4).",
    tc_spread_waze_ratio = "100 times TCS divided by Waze road length (section 4.4).",
    tc_severe_spread_osm_ratio = "Severe TCS as a percentage of OSM road length (section 6).",
    tc_severe_spread_waze_ratio = "Severe TCS as a percentage of Waze road length (section 6).",
    tc_persistance_ratio = "TCP: 100 times TCI/TCS divided by nominal feed observations; delivered spelling retained (section 4.5).",
    tc_severe_persistance_ratio = "Severe TCP, nominally a percentage of the source window (section 6).",
    freeflow_speed = "Second delivered free-flow field, km/h; numerically compared with avg_freeflow below.",
    speed = "Constructed expected speed blending jam and free-flow speeds using congestion intensity, km/h (section 5.4).",
    t_speed_ratio = "Delivered speed percentage relative to free flow; documented speed_ratio alias (section 5.5)."
  )
  dictionary <- copy(s$columns)
  dictionary[, meaning := unname(meanings[column])]
  stopifnot(!anyNA(dictionary$meaning))
  dictionary[, raw_range := paste0(raw_min," to ",raw_max)]
  dictionary[, nonsentinel_range := ifelse(type=="VARCHAR", raw_range,
    paste0(fmt(clean_min)," to ",fmt(clean_max)))]
  dictionary[, `:=`(NA_percent=fmt(na_pct), sentinel_998_percent=fmt(sentinel_998_pct),
                    sentinel_999_percent=fmt(sentinel_999_pct))]
  file_table <- data.table(File=basename(s$source_info$file),
    Format=c("CSV / WKT","CSV","Parquet"),Bytes=fmt_n(s$source_info$bytes),
    Rows=fmt_n(c(nrow(s$spatial$cells),s$certificate$raw_csv_rows,s$raw_rows)),
    Columns=c(2L,nrow(s$schema)+1L,nrow(s$schema)))
  cells <- s$spatial$cells
  n_grid <- nrow(cells)
  allroad <- s$roadtypes[roadtype=="all_roadtype"]
  n_delivered_months <- sum(s$calendar$delivered_month)
  expected_delivered <- n_grid*n_delivered_months*24
  expected_calendar <- n_grid*nrow(s$calendar)*24
  absent_delivered <- expected_delivered - allroad$distinct_rows
  identity <- s$identity
  overall_identity <- identity[roadtype=="ALL BLOCKS (rowwise only)"]
  allroad_identity <- identity[roadtype=="all_roadtype"]
  missing_months <- paste(format(date_month(s$calendar[delivered_month==FALSE,date]),"%Y-%m"),collapse=", ")
  row_presence <- fmt(100*allroad$distinct_rows/expected_delivered)
  neighborhood_table <- s$spatial$neighborhoods[,.(group,
    `Published-point seed (not a verified monitor cell)`=published_point_seed,grid_id)]
  group_summary <- merge(s$spatial$groups,
    s$coverage[,.(minimum_monthly_cells=min(cells_with_records[delivered_month]),
      maximum_monthly_cells=max(cells_with_records[delivered_month]),
      records_in_delivered_months=sum(distinct_records),
      mean_slots_per_cell_month=mean(mean_records_per_cell[delivered_month])),by=group],by="group",all.x=TRUE)
  group_summary[, mean_slots_per_cell_month:=fmt(mean_slots_per_cell_month)]
  coverage_table <- copy(s$coverage)
  coverage_table[, entry:=paste0(cells_with_records," / ",formatC(mean_records_per_cell,format="f",digits=3))]
  coverage_wide <- dcast(coverage_table,date~group,value.var="entry")
  setcolorder(coverage_wide,c("date","CENTER","BELISARIO","CORRIDOR","RING","REST","OVERALL"))
  coverage_wide[,date:=format(date_month(date),"%Y-%m")]
  yearly <- s$coverage[delivered_month==TRUE,.(
    delivered_months=.N,mean_any_congestion_share=mean(any_congestion_share),
    mean_TCS_metres=mean(tcs_metres)),by=.(year=date%/%100L,group)]
  yearly[,`:=`(mean_any_congestion_share=fmt(mean_any_congestion_share),mean_TCS_metres=fmt(mean_TCS_metres))]
  selected_yearly <- yearly[group %in% c("CENTER","BELISARIO","REST","OVERALL")][order(year,group)]
  failures <- dictionary[n_negative_nonsentinel>0 | n_nonfinite>0 |
                          (column %in% c("tc_severe_persistance_ratio","tci_waze_ratio") & clean_max>100),
    .(column,n_negative_nonsentinel,n_nonfinite,nonsentinel_range)]
  request <- data.table(
    Requested=c("Geography","Frequency","Weekday peak aggregation","All-hours/all-days aggregation",
      "Start and end","Indicator suite","Free-flow diagnostics","Underlying observation and jam counts",
      "Quality flags","Road classes","Raw CSV and Parquet equivalence"),
    Delivered=c(
      sprintf("%d grid polygons; %d centers outside requested box; %d polygons intersect it. H3 checks below.",n_grid,sum(!cells$centroid_in_request_box),sum(cells$intersects_request_box)),
      "Monthly profiles by hour of day; no weekly or individual-day dimension.",
      "No day-of-week dimension. Use morning bins 7,8 and evening bins 17,18 over all days; weekdays cannot be isolated.",
      "24 hourly labels permit all-hours summaries after completion; no separate daily or day-of-week records.",
      paste("January 2019 through December 2025, with missing",missing_months,"and sparse cell-hour coverage."),
      "TCI, severe TCI, TCS, severe TCS, OSM/Waze ratios, TCP, severe TCP, jam speeds and constructed speeds are present with naming aliases.",
      "Two near-identical aggregated free-flow columns; no segment-level night observations or road-length series.",
      "Not delivered. Counts have been requested; use indirect proxies only.",
      "flag_corr_type is absent. Provider says summarized tables filter upstream, which cannot be verified here.",
      "Six stacked free-flow speed classes, including all_roadtype; large is fast roads, not a functional class.",
      "Full row counts and a seeded 256-row, all-field value comparison pass; the CSV has an additional serialized row index."))
  # Explicit report-number pool. The separate audit draws ten without replacement.
  facts <- data.table(id=c("raw_rows","distinct_rows","extra_duplicate_rows","grid_cells","observed_cells",
    "unobserved_grid_cells","observed_months","hour_labels","raw_allroad_rows","distinct_allroad_rows",
    "allroad_absent_delivered_slots","max_key_multiplicity","raw_primary_max","distinct_primary_zero",
    "raw_waze_tci_na","raw_waze_tci_sentinel","raw_spread_negative","raw_severe_persistence_max",
    "identity_max","freeflow_alias_max","invalid_grid_h3","grid_centers_outside_box","first_month","last_month"),
    value=c(s$raw_rows,s$distinct_rows,as.numeric(s$duplicate_keys$extra_rows),n_grid,s$n_cells,n_grid-s$n_cells,
      n_delivered_months,s$n_hours,allroad$raw_rows,allroad$distinct_rows,absent_delivered,s$duplicate_keys$max_multiplicity,
      s$columns[column=="tci_osm_ratio",clean_max], # Raw and nonsentinel primary maxima coincide.
      sum(s$anomalies$zero_tci_ratio),
      s$columns[column=="tci_waze_ratio",n_na],s$columns[column=="tci_waze_ratio",n_998+n_999],
      s$columns[column=="tc_spread_osm_ratio",n_negative_nonsentinel],
      s$columns[column=="tc_severe_persistance_ratio",clean_max],
      overall_identity$maximum_absolute_residual,overall_identity$freeflow_alias_max_difference,
      sum(!cells$valid_h3),sum(!cells$centroid_in_request_box),min(s$calendar[delivered_month==TRUE,date]),max(s$calendar[delivered_month==TRUE,date])))
  facts[,value:=as.numeric(value)]
  stopifnot(!anyNA(facts$value))
  saveRDS(facts,file.path(inventory_dir,"report_numeric_facts.rds"))
  fact_table <- copy(facts); fact_table[,value:=sprintf("%.17g",value)]
  sample_by_group <- s$sample[,.(rows=.N,roadtypes=uniqueN(roadtype),months=uniqueN(date),
    earliest_month=min(date),latest_month=max(date)),by=group][order(group)]
  text <- c("# Waze delivery inventory", "", paste("Phase B. Generated",Sys.Date(),"by `Rscript Scripts/Congestion/01_inventory.R`. No treatment effect is estimated."), "",
    "## Decisions carried forward", "",
    "The authors accepted Phase A and fixed this module's monthly calendar: P1 is December 2023 through August 2024; disruption is all of September through December 2024; P2 is January through December 2025. The three future estimands correspond to P1, P1 plus P2, and the full window. Waze P2 is longer than the paper's P2. Morning bins are 7 and 8 and evening bins 17 and 18, pending author confirmation. The night bins used here are 22, 23, 0, 1, 2, 3, 4 and 5, inclusive of hour label 5. No weekday restriction is possible.", "",
    "All cited paper estimates must come from the May 31 PDF, which postdates the CSV export. The paper CSVs are reserved for trajectories and donor weights. Phase A conflicts P1 and P3 remain author items and have not been investigated further. The present report does not cite CSV treatment estimates.", "",
    "## Files and one-time format check", "",md_table(file_table),"",
    sprintf("The CSV and Parquet both contain %s rows. A seeded sample of %d physical rows agrees across all %d substantive columns, with numerical tolerance 1e-12 times max(1, absolute reference value), identical character values and matching NA locations. The unnamed CSV index is a serialization field, not an extra analysis dimension. The largest sampled absolute numerical discrepancy is %s. The certificate records file sizes, modification times, sampled row indices and per-column discrepancies in `Output/Waze/inventory/csv_parquet_certificate.rds`. Subsequent runs reuse it unless an input fingerprint changes; all remaining computations read the Parquet.",fmt_n(s$raw_rows),length(s$certificate$sampled_physical_rows),nrow(s$schema),fmt(max(s$certificate$comparison$maximum_absolute_difference,na.rm=TRUE))),"",
    "## Row keys, duplicates and sparse coverage", "",
    sprintf("The raw delivery contains %s distinct cell-month-hour-roadtype keys and %s additional duplicate rows. SELECT DISTINCT across every delivered column yields exactly the key count. Thus every repeated key has identical values in all delivered fields. The maximum multiplicity is %s. Exact deduplication is safe for this inventory and prevents repeated copies from changing group weights; the raw inputs remain untouched. Within all_roadtype, the monthly mean number of raw copies per distinct record ranges from %s to %s. The source of the repeated copies is unknown.",fmt_n(s$distinct_rows),fmt_n(s$duplicate_keys$extra_rows),fmt_n(s$duplicate_keys$max_multiplicity),fmt(min(s$monthly_duplicates$mean_copies)),fmt(max(s$monthly_duplicates$mean_copies))),"",
    md_table(s$multiplicity),"",md_table(s$roadtypes),"",
    sprintf("Across all roadtype blocks, the data cover %s distinct cells, %d observed months and %d hour labels. The polygon grid contains %s cells, leaving %s with no delivered record in any month or roadtype. All IDs in the panel occur in the polygon reference. The hour labels span 0 through 23. There is no day-of-week dimension, flag_corr_type, observation count, jam count or direct road-length field.",fmt_n(s$n_cells),n_delivered_months,s$n_hours,fmt_n(n_grid),fmt_n(n_grid-s$n_cells)),"",
    sprintf("The all_roadtype panel is sparse. It contains %s distinct records against %s possible cell-month-hour slots over the %d months with any delivery, or %s percent. Every delivered record has positive TCI; a present row therefore identifies a cell-hour profile with observed congestion. There are %s absent slots within delivered months. Under the authors' convention, these slots enter congestion aggregates as zero, including grid cells that never appear. This interpretation remains a substantive assumption about provider coverage, not proof of no traffic. Zero tci_osm_ratio values can coexist with positive TCI, so 'any congestion' is defined by tci > 0 rather than by the intensity ratio.",fmt_n(allroad$distinct_rows),fmt_n(expected_delivered),n_delivered_months,row_presence,fmt_n(absent_delivered)),"",
    sprintf("The full calendar has %s cell-hour slots. %s is wholly absent across every cell, hour and roadtype. The completed lattice retains that month, but leaves congestion outcomes and penetration proxies NA there. Record-coverage counts are zero because nothing was delivered. Treating a citywide delivery gap as zero congestion would create an artificial collapse. This is an explicit exception to zero-filling sparse records within otherwise delivered months, and must remain in the memo. No missing month is interpolated.",fmt_n(expected_calendar),missing_months),"",
    "Jam speed is conditional on jams. An absent congestion record does not imply jam_speed_ratio = 0, which would mean stopped traffic. Its value stays undefined for zero-congestion slots. Free-flow speed also stays missing where no value was delivered. Exact -998 and -999 sentinels become NA, and existing NA values stay NA. No flag filter can be applied because the field is absent. No trimming rule for other invalid values is silently imposed.","",
    "## Spatial validation and provisional groups", "",
    sprintf("All %d polygon IDs have valid H3 syntax: %d invalid, with resolutions %s. All %d delivered polygons pass sf validity checks. Reconstructing each boundary with DuckDB H3 in full-precision WKB and comparing in UTM 17S gives a maximum paired Hausdorff distance of %s metres and maximum relative area error %s. All boundaries match at a 0.01 metre tolerance. This checks shape and location, without relying on vertex order. The observed grid bounds are longitude %s to %s and latitude %s to %s. There are %d cell centers inside the requested box, %d polygon intersections, and %d polygons wholly within it. This is consistent with selecting intersecting cells, rather than strict center or full-polygon inclusion; the provider's exact selection rule is not confirmed. Keep the delivered extent and record these edge cells explicitly.",n_grid,sum(!cells$valid_h3),paste(sort(unique(cells$resolution)),collapse=","),sum(cells$valid_polygon),fmt(max(cells$boundary_hausdorff_m)),fmt(max(cells$relative_area_error)),fmt(s$spatial$bounds["xmin"]),fmt(s$spatial$bounds["xmax"]),fmt(s$spatial$bounds["ymin"]),fmt(s$spatial$bounds["ymax"]),sum(cells$centroid_in_request_box),sum(cells$intersects_request_box),sum(cells$within_request_box)),"",
    "Station coordinates come from MetroStations.gpkg, with unused Z/M dimensions dropped in memory and its embedded CRS transformed correctly. Monitor points come from Distancia_REMMAQ_Metro.gpkg. These are the authors' copies from the air-quality repository; no source layer is edited. The Centro and Belisario coordinates are rounded to 0.01 degrees. The following seeds identify the published points, not verified physical monitor cells. Each neighborhood contains the seed and six H3 neighbors. A true single-monitor-cell option requires precise coordinates.","",md_table(neighborhood_table),"",
    "For consistent Phase B and Phase C labels, assign CENTER and BELISARIO first. Assign remaining cells with an H3 center within 1 km of any Line 1 station to CORRIDOR, then remaining cells within 2 km to RING, then REST. All distances use the H3 center and sf geodesic distance. Including San Francisco among the remaining corridor buffers prevents a cell near that station from entering REST after CENTER changes to the monitor neighborhood. The original 1 km San Francisco and Belisario-point buffers are retained as separate candidate flags in the spatial output. These descriptive labels do not lock the authors' final treated-unit definition.","",md_table(group_summary),"",
    "`Output/Waze/inventory/cell_groups.rds` stores all polygons, memberships, distance measures, original candidate buffers and validation results. The auxiliary cell_groups.csv is regenerated locally and ignored by git. Spatial groups are disjoint and exhaustive; RING is excluded from a future REST donor pool.","",
    "## Field dictionary and raw hygiene", "",
    "The following definitions map the actual delivered names to `docs/waze_documentation.md`. The document describes source-window quantities that are then averaged into monthly hour profiles; a monthly TCI or TCS value must not be called a count of unique events over that entire month. Types below are DuckDB types. Ranges and percentages use all raw rows, including duplicate copies, to describe exactly what arrived. The non-sentinel range excludes only -998, -999 and NA. A percentage shown as 0 is exactly zero.","",
    md_table(dictionary[,.(column,type,meaning)]),"",
    md_table(dictionary[,.(column,raw_range,nonsentinel_range,NA_percent,sentinel_998_percent,sentinel_999_percent)]),"",
    "The polygon CSV has two nonmissing character columns: grid_id is the same H3 identifier and h3_geometry_r8 is WKT POLYGON geometry. Its spatial range and boundary checks appear above. The hourly CSV has one additional index column; it is excluded from the substantive dictionary.","",
    "The provider defines roadtype by segment free-flow speed: small <30 km/h, medium 30–50 inclusive, large >50, minor_2_levels <40, major_2_levels >40, and all_roadtype as the combined network. Exactly 40 km/h is omitted by the documented strict two-level split. Call large 'fast roads'. Never add stacked blocks together as though they were disjoint: they include two alternative partitions and the total.","",
    "The severe definition remains contradictory: section 6 uses Waze jam levels 3 and 4, while section 9 uses speed below 40 percent of free flow. The provider must confirm the operational definition. Free flow does not divide tci_osm_ratio, whose denominator is road length times nominal observations. It can affect jam detection, severe classification, speed ratios and roadtype assignment. The aggregated night reference can therefore matter without being the direct denominator of the primary outcome.","",
    "## Speed identities and invalid values", "",
    "At the source-observation level, the documented formulas imply S = 100 - T + T J / 100, where S is speed_ratio, T is tci_osm_ratio and J is jam_speed_ratio, all measured in percent. In the delivered names this becomes t_speed_ratio = 100 - tci_osm_ratio + tci_osm_ratio * avg_jam_speed_ratio / 100. The numerical check below uses each distinct delivered row after sentinel recoding, without combining roadtypes. The ALL BLOCKS row pools residual diagnostics only; it is not a congestion aggregate.","",md_table(identity),"",
    sprintf("The claimed identity does not hold exactly in the delivered aggregates. Its largest absolute residual is %s percentage points overall and %s in all_roadtype; %s of %s all_roadtype rows pass tolerance 1e-8. Averaging a product need not equal multiplying averages, so upstream aggregation is a plausible explanation, but the supplied fields do not establish the cause. Keep the authors' three-outcome hierarchy and exclusion of speed_ratio; do not justify that exclusion by claiming exact redundancy in this delivered panel. The two free-flow fields differ by at most %s km/h, consistent with floating-point aliases.",fmt(overall_identity$maximum_absolute_residual),fmt(allroad_identity$maximum_absolute_residual),fmt_n(allroad_identity$within_1e8),fmt_n(allroad_identity$n),fmt(overall_identity$freeflow_alias_max_difference)),"",
    "Some delivered percentages remain outside their conceptual bounds after exact sentinel recoding. Negative fractional values may reflect sentinel contamination before averaging, but this has not been confirmed. Severe persistence can greatly exceed 100. Preserve these records and ask the provider about the aggregation pipeline. The TCS penetration proxy below uses tc_spread in metres, which is nonnegative, rather than the contaminated OSM spread percentage.","",md_table(failures),"",md_table(s$anomalies),"",
    "## Coverage and indirect penetration proxies", "",
    "All summaries in this section select only all_roadtype and use the completed cell-month-hour lattice. Record counts measure delivered monthly hour profiles, not underlying Waze observations, users, vehicles or jam events. Direct counts and flags were not supplied, and counts have been requested. Both the share of cell-hours with any congestion and mean TCS spread can change because of actual traffic as well as reporting penetration. Neither isolates penetration.","",
    "![Cells with records](../Output/Waze/inventory/coverage_cells.png)","",
    "![Mean and interquartile range of delivered hour slots](../Output/Waze/inventory/coverage_cell_hours.png)","",
    "![Indirect penetration proxies](../Output/Waze/inventory/indirect_penetration_proxies.png)","",
    "![Coverage around the missing 2025 month](../Output/Waze/inventory/coverage_gap_2025.png)","",
    "Coverage and TCS drop together in February and April 2025 around the wholly missing March month. The pattern occurs across groups, so provider completeness for the whole February–April interval needs review. These adjacent months remain as delivered; partial coverage is a hypothesis, not a confirmed cause. Do not treat this dip as evidence about the metro. CENTER and BELISARIO have much denser hour-profile coverage than REST, making uniform penetration assumptions questionable even when their time trends look similar. The figures show levels and raw trajectories only.","",
    "The cell-hour share is the number of completed slots with tci > 0 divided by all grid cells times 24 in a delivered month. It is a profile-coverage measure, not the fraction of underlying hourly timestamps that were congested. Mean TCS uses tc_spread with absent slots zero-filled within delivered months and equal cell-hour weights. No road-length weighting is possible from a directly supplied road-length field. The next table pools the monthly descriptive proxies within each year, excluding the missing delivery month. These are raw summaries, not pre/post effects.","",md_table(selected_yearly),"",
    "Each entry below is cells with any delivered record / mean delivered hour slots per grid cell. Means include cells with zero records. The missing month's zero record counts describe the delivery, not traffic. The full cell-month distribution, including every cell's count and group, is saved in cell_month_coverage.rds; monthly means, quartiles, maxima, proxy values and denominators are in monthly_coverage.rds, all under Output/Waze/inventory/.","",md_table(coverage_wide),"",
    "## Delivery versus the July 2026 request", "",md_table(request),"",
    "## Review sample and reproducibility", "",
    sprintf("`reports/waze_sample.csv` contains exactly %d distinct observed rows with all original fields, plus group, period, hour_block and raw_multiplicity. Missing values are written as NA; source sentinels remain visible in this review artifact. One deterministic hash-ranked row is drawn from each available group-by-roadtype-by-period-by-hour-block stratum (%d strata), then the remaining rows are drawn by the same stable hash order to reach 500. The hash includes seed 20260917; DuckDB's version is recorded in the saved session. This is a coverage-oriented review sample, not a probability sample for analysis. All six roadtypes, all five groups, pre-opening and post-opening periods, peaks and off-peaks are represented.",nrow(s$sample),s$sample_seed_rows),"",md_table(sample_by_group),"",
    "Run `Rscript Scripts/Congestion/01_inventory.R` from the repository root. It creates the inventory, spatial metadata, coverage outputs, plots and review sample, then starts the independent audit in a fresh R process. The first run validates the CSV; later runs use its fingerprinted certificate. `01_audit_inventory.R` can also run by itself. No R package installation, model fit, ATT, event study, post-indicator regression, synthetic control or SDID fit occurs. Data/ and the frozen air-quality inputs are never written or committed. Only the review sample is exempt from the general generated-CSV ignore rule.","",
    "## Explicit numeric checks eligible for the random audit", "",
    "These raw-source checks provide the declared sampling pool for the independent ten-number audit. Values use enough digits to reproduce the stored result. The audit draws ten uniformly without replacement with seed 9172026 and does not use the inventory's derived tables to recompute them.","",md_table(fact_table),"",
    "## Items to carry into the strategy memo", "",
    "Keep author conflicts P1 and P3 unresolved. Record the deliberate monthly calendar and longer Waze P2, uncertain monitor locations, all-day peak profiles, missing March 2025, exact duplicated records, incomplete cell-hour coverage, the lack of direct observation/flag fields, invalid auxiliary ratios, failure of the delivered speed identity, the ambiguous severe threshold, and the speed-based meaning of fast roads. Coordinate precision conditions the single-cell option; no physical monitor cell is claimed. Boundary-box discrepancies, if any, are quantified above and must be described as delivered rather than silently recut.",""
  )
  writeLines(text,"reports/waze_inventory.md")
}
