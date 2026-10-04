# Step 1, item 6. Writes the provisional frozen specification to Output/step1_freeze/.
# Step 2 applies this specification unchanged to post-opening data once Leonel confirms it.
# Committed files hold specifications, donor lists, weights and aggregate fit statistics only.
source("Scripts/Congestion/step1_helpers.R")
panel <- readRDS(file.path(STEP1_DATA, "panel_pre.rds"))
fits <- readRDS(file.path(STEP1_DATA, "fits_pre.rds"))
diag <- readRDS(file.path(STEP1_DATA, "diagnostics_pre.rds"))
git <- function(...) system2("git", c(...), stdout = TRUE)
code_sha <- git("rev-parse", "HEAD")
dirty <- git("status", "--porcelain", "--", "Scripts")
if (length(dirty)) stop("Uncommitted changes under Scripts/: ", paste(dirty, collapse = "; "))

# Inputs and derived files, with sha256.
inputs <- c(raw_parquet, roadlength_path, grid_path, "Data/spatial/MetroStations.gpkg", "Data/spatial/MetroLine.gpkg",
            "Data/spatial/Distancia_REMMAQ_Metro.gpkg", "Output/Waze/inventory/cell_groups.rds", pre_block,
            file.path(STEP1_DATA, c("panel_pre.rds", "fits_pre.rds", "diagnostics_pre.rds")),
            list.files("Scripts/Congestion", pattern = "^(19|2[0-5])_step1|^step1_|^20_run_step1", full.names = TRUE),
            "docs/analysis_plan.md")
checksums <- data.table(file = inputs, bytes = file.size(inputs), sha256 = sha256(inputs),
  role = fifelse(grepl("^Data/Waze/raw|^Data/spatial", inputs), "raw input (read-only store)",
         fifelse(grepl("^Data/Waze/(parquet_step1|step1)", inputs), "derived, rebuilt from raw (ignored)",
         fifelse(grepl("^Scripts", inputs), "code", "reference"))))
fwrite(checksums, file.path(FREEZE_DIR, "input_checksums.csv"))

# Donor pools under both flag rules: membership and missing-month counts, no cell-level data values.
pools <- rbindlist(lapply(panel$rules, function(r) r$cells[group == "REST", c(list(rule = r$rule, grid_id = grid_id,
  km_to_nearest_station = nearest_station_m / 1000, t20 = t20, t12 = t12, in_coverage_range = cov_ok,
  missing_pre_months = missing_months, missing_train = missing_train, missing_holdout = missing_holdout,
  missing_reasons = reasons), .SD), .SDcols = patterns("^pool_")]))
fwrite(pools, file.path(FREEZE_DIR, "donor_pools.csv"))

# Donor weights: full pre-period fit (what Step 2 reproduces) and the training fit.
weights <- rbindlist(lapply(fits$fits, function(f) rbindlist(lapply(c("full_pre", "training"), function(w) {
  x <- if (w == "full_pre") f$full else f$holdout$ascm
  data.table(rule = f$rule, pool = f$pool, target = f$target, fit = w, grid_id = names(x$weights),
             scm_weight = x$synw[names(x$weights)], effective_weight = x$weights)
}))))
stopifnot(weights[, abs(sum(effective_weight) - 1) < 1e-6, by = .(rule, pool, target, fit)]$V1)
fwrite(weights, file.path(FREEZE_DIR, "donor_weights.csv"))

fwrite(fits$comparison, file.path(FREEZE_DIR, "fit_statistics.csv"))
fwrite(fits$contrast, file.path(FREEZE_DIR, "contrast_statistics.csv"))
fwrite(fits$paths[, .(rule, pool, target, estimator, fit, month, period, actual, synthetic, gap)], file.path(FREEZE_DIR, "fit_paths_pre.csv"))
fwrite(diag$weights_summary, file.path(FREEZE_DIR, "weight_statistics.csv"))
fwrite(fits$drop_one, file.path(FREEZE_DIR, "influence_drop_one.csv"))
fwrite(fits$folds, file.path(FREEZE_DIR, "lobo_folds.csv"))
fwrite(diag$mde, file.path(FREEZE_DIR, "mde_center.csv"))
fwrite(diag$inference_dims, file.path(FREEZE_DIR, "inference_dimensions.csv"))
fwrite(diag$pseudo, file.path(FREEZE_DIR, "pseudo_neighbourhood_fits.csv"))
fwrite(rbindlist(lapply(names(diag$pseudo_sets), function(p) rbindlist(lapply(names(diag$pseudo_sets[[p]]), function(s)
  data.table(pool = p, seed = s, grid_id = diag$pseudo_sets[[p]][[s]]))))), file.path(FREEZE_DIR, "pseudo_neighbourhoods.csv"))

spec <- list(
  status = paste("Step 1 provisional freeze under", ZERO_LABEL, "and plan Amendment 1. Final only after Leonel confirms it (plan section 8, Step 2)."),
  plan = "docs/analysis_plan.md (v2 of 2026-09-22 with Amendment 1 of 2026-09-27)",
  code_commit = code_sha,
  outcome = list(variable = "tci_osm_ratio", roadtype = "all_roadtype", scale = "native 0 to 100 levels",
                 primary_block = "peak", blocks = panel$hours, aggregation = "equal cell weights, then equal hour weights",
                 secondary = "log of target aggregates (CENTER, BELISARIO, CORRIDOR); morning, evening; night 0-4 diagnostic"),
  zero_coding = ZERO_LABEL,
  flag_rules = list(primary = "amended: sentinel -998/-999 in any field or any of the six auxiliary ratios below zero makes the key missing; severe persistence above 100 makes only severe outcomes missing",
                    sensitivity = "plan: severe persistence above 100 also makes the key missing for every outcome"),
  fixed_composition = "a unit-month exists only if every cell-hour is valid; no na.rm, no reweighting, no substitution; a target's missing months are left out of fits",
  calendar = list(pre = c(PRE_FIRST, PRE_LAST), training = range(TRAIN_MONTHS), holdout = range(HOLDOUT_MONTHS),
                  dec2022_sensitivity = range(DEC22_MONTHS), post_blocks = "as in plan section 5"),
  units = list(seeds = as.list(SEEDS), CENTER = panel$rings$CENTER, BELISARIO = panel$rings$BELISARIO,
               CORRIDOR = panel$unit_cells$CORRIDOR),
  donor_rules = list(eligible = "REST cells, centroid more than 2 km from every station, with a pre-period record",
                     threshold = SLOT_THRESHOLD, threshold_sensitivity = SLOT_THRESHOLD_SENS,
                     coverage_screen = list(label = "jam-derived coverage", source = roadlength_path, year = 2022L,
                                            roadtype = "all_roadtype", range = panel$cov_range),
                     low_exposure_m = LOW_EXPOSURE_M, completeness = "complete peak block over January 2022 to November 2023",
                     primary_pool = "Leonel's decision: primary_unscreened or primary_screened"),
  donor_counts = rbindlist(lapply(panel$rules, `[[`, "pool_counts")),
  estimator = list(package = "augsynth", version = as.character(packageVersion("augsynth")),
                   remote_sha = packageDescription("augsynth")$RemoteSha, progfunc = "Ridge", scm = TRUE, fixedeff = TRUE,
                   tuning = paste("leave-one-block-out on January 2022 to May 2023: calendar blocks of 3, 3, 3, 3, 3 and 2 months",
                                  "(a target's missing months removed from their block), augsynth's own lambda grid, minimum pooled MSE.",
                                  "The December 2022 start sensitivity reuses this penalty and is not re-tuned (approved in the Step 1 plan);",
                                  "on six training months it nearly interpolates CENTER."),
                   lambda = rbindlist(lapply(fits$fits, function(f) data.table(rule = f$rule, pool = f$pool, target = f$target,
                                                                              lambda = f$lambda, at_grid_edge = f$lambda_at_grid_edge))),
                   holdout_use = paste("The June to November 2023 holdout was scored for both pools, both rules, the benchmarks, the December 2022",
                                       "start, the drop-one refits and the pseudo-neighbourhoods. Choosing the primary pool after seeing these",
                                       "scores is model selection (plan section 6) and is recorded here when Leonel decides."),
                   benchmarks = list(scm = "augsynth progfunc None, fixedeff FALSE", did = "donor-mean difference-in-differences, equal weights"),
                   contrast = "CENTER gap minus BELISARIO gap from two separate fits; neither target in the other's pool"),
  inference_next = list(conformal = "Chernozhukov-Wuthrich-Zhu, moving-block permutations of the full residual sequence (augsynth conformal_inf type block)",
                        placebos = "seven-cell pseudo-neighbourhoods listed in pseudo_neighbourhoods.csv; fit filter full pre RMSPE <= 3 x CENTER"),
  environment = list(R = paste(R.version$major, R.version$minor, sep = "."), platform = R.version$platform))
jsonlite::write_json(spec, file.path(FREEZE_DIR, "spec.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
cat("Freeze written for code commit", code_sha, "\n")
