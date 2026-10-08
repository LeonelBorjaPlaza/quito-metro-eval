# Reproducible aggregate packet and substantive invariants. Does not load P1
# microdata: it reads published P1 tables to extract labels and availability status.
source("code/amend2_helpers.R")
b<-readRDS(file.path(A2_DATA,"build.rds"));assert_pre(b$crashes)
ct<-readRDS(file.path(A2_DATA,"controls.rds"))$controls
checks<-data.table(check=character(),passed=logical())
check<-function(label,ok) {stopifnot(isTRUE(ok));checks<<-rbind(checks,data.table(check=label,passed=ok))}
check("Every outcome date is pre-opening",all(b$crashes$fecha<as.Date("2023-12-01")))
check("All distant parishes retained",b$units[family=="donor",.N]==39)
check("Every unit has rain assignment",all(b$units$unit %in% unique(ct[!is.na(rain_station),unit])))
gpcheck<-readRDS(file.path(A2_DATA,"geographic_predictors.rds"))
check("Geographic predictors cover exactly every unit",setequal(gpcheck$unit,b$units$unit)&&!anyDuplicated(gpcheck$unit))
check("Geographic predictors are finite and nonnegative",all(vapply(gpcheck[,!"population_method"],function(v)if(is.numeric(v))all(is.finite(v)&v>=0)else TRUE,TRUE)))
pops<-fread(file.path(A2_OUT,"parish_population.csv"))
popcheck<-gpcheck[startsWith(unit,"parish_")]
check("Parish allocated populations equal census totals",all(abs(popcheck$population-pops$population[match(sub("^parish_","",popcheck$unit),pops$code)])<1e-5))
check("Every panel outcome is nonnegative",all(b$stack$y>=0))
check("No duplicate unit-cell-month",!anyDuplicated(b$stack[,.(unit,cell,month)]))
check("Every required hourly zero cell exists",nrow(b$hour)==nrow(b$units)*length(A2_MONTHS)*2L*24L)
check("Rings and donor crashes disjoint",!any(b$members[unit %in% A2_RINGS,idx] %in% b$members[unit %in% b$units[family=="donor",unit],idx]))
check("Private vehicle numerators do not exceed denominators",all(b$outcomes$private_vehicles<=b$outcomes$all_vehicles))
check("No forecast fit failure",nrow(fread(file.path(A2_OUT,"forecast_failures.csv")))==0)
fc<-fread(file.path(A2_OUT,"forecast_comparison.csv"))
check("All forecast methods have complete common folds",all(fc$folds==3) && nrow(fc)==2*3*length(A2_TARGETS)*4)
sf<-fread(file.path(A2_OUT,"share_forecast_comparison.csv"))
check("Share forecasts have complete common folds",all(sf$folds==3) && nrow(sf)==2*length(A2_TARGETS)*4)
check("No share forecast fit failure",nrow(fread(file.path(A2_OUT,"share_forecast_failures.csv")))==0)
al<-fread(file.path(A2_OUT,"adjusted_preperiod_leads.csv"))
check("Adjusted leads are finite and pre-period only",all(is.finite(al$log_lead)) && all(as.Date(al$quarter)<as.Date("2023-12-01")))
check("Adjusted ring releases protect withheld nested paths",identical(al,guard_ring_paths(al,c("start","outcome","adjustment"))))
for(fn in c("road_name_agreement.csv")) {
  z<-fread(file.path(A2_OUT,fn));check(paste(fn,"protected counts"),all(is.na(z$matched_crashes)|z$matched_crashes%%5==0))
}
lead<-fread(file.path(A2_OUT,"preperiod_quarterly_leads.csv"))
check("Quarterly diagnostic contains no post-opening date",all(as.Date(lead$quarter)<as.Date("2023-12-01")))
check("Raw ring releases protect withheld nested paths",identical(lead,guard_ring_paths(lead,c("start","outcome"))))
save_csv(checks,file.path(A2_OUT,"validation_checks.csv"))

inv<-rbindlist(lapply(c("estimates.csv","described_only.csv","not_run.csv"),function(fn) {
  z<-fread(file.path("output/p1",fn));z[,.(file=paste0("road_safety/output/p1/",fn),id,
    kind=if(fn=="not_run.csv") "not run or superseded" else ifelse(is.na(estimate_pct),"withheld; status seen",if(fn=="described_only.csv") "described estimate seen" else "estimate seen"),
    label=if(fn=="not_run.csv") reason else label)]
}))
inv<-rbind(inv,data.table(file="road_safety/output/p1/leave_one_out.csv",id="I4",kind="estimates seen",label="Every leave-one-distant-parish-out registered P1 run"))
save_csv(inv,file.path(A2_OUT,"p1_seen_inventory.csv"))
meta<-readLines(file.path(A2_DATA,"extraction.json"))
writeLines(meta,file.path(A2_OUT,"extraction_provenance.json"))

sel<-fread(file.path(A2_OUT,"headline_selection.csv"))
means<-fread(file.path(A2_OUT,"preperiod_monthly_means.csv"))
rn<-fread(file.path(A2_OUT,"road_name_agreement.csv"))
dr<-fread(file.path(A2_OUT,"drift_flattening.csv"))
ad<-fread(file.path(A2_OUT,"adjusted_drift_flattening.csv"))
sh<-fread(file.path(A2_OUT,"share_headline_selection.csv"))
md<-fread(file.path(A2_OUT,"conditional_mde.csv"))
sim<-md[start==2022 & block_months==3 & method=="anchored_equal_tail" &
  unit %in% c("corridor_0_600","historic_center") & outcome %in% c("all_crashes","private_car_crashes")]
sim<-dcast(sim,start+outcome+unit+scenario+null_size+size_gate~direction,value.var="conditional_mde_pct_training_mean")
main<-sel[start==2022 & outcome %in% c("all_crashes","private_car_crashes"),.(outcome,unit,ASCM,PPML,winner)]
display_or_withheld<-function(z)if(nrow(z))md_table(z)else"Withheld jointly across starts under the disclosure rule."
calibration_text<-"Full-count calibration under the corrected definition is not yet complete; no corrected size result is claimed in this interim snapshot. All full-estimator power simulations were cancelled; power and MDE planning figures come only from the historical residual prototype."
if(file.exists(file.path(A2_OUT,"full_calibration_size.csv"))) {
  ns<-fread(file.path(A2_OUT,"full_calibration_size.csv"))
  rt<-if(file.exists(file.path(A2_OUT,"full_calibration_runtime.csv")))fread(file.path(A2_OUT,"full_calibration_runtime.csv"))else data.table()
  calibration_text<-c("Null rejection rates from `road_safety/output/amendment2/full_calibration_size.csv`:","",
    "Both corridor baselines fail the declared 7.5% continued-drift size screen. The trend-carrying variants reject more often and fail every tested scenario; they do not repair inference in this calibration. The all-crash corridor baseline also fails the stationary and serial/seasonal screens, and the historic-center baseline fails the stationary screen. Binomial uncertainty is shown below: marginal screen failures are not proof of a precise population rejection rate. Keep both baseline and trend estimates in the future main table under the prespecified rule, with failed-size qualifications.","",
    md_table(ns[,.(case,scenario,trend_variant,replications,numerical_errors,rejection_rate,mc_se,mc_lower,mc_upper,size_gate)]),"",
    "Full-estimator calibration covers null size only. No full-estimator power or MDE was estimated. Null method-selection shares and reassignment counts are in `full_calibration_curves.csv`; numerical failures are in `full_calibration_errors.csv`.","",
    "All null replications were atomically saved without fitting errors, but the master exited 1 while parsing its final timing statement. The failure is consistent with the inserted guard changing a file being streamed; that cause is not proven. Current scientific source matches the frozen source and parses correctly. Summary 22 and this packet were regenerated directly from saved checkpoints. Successful-stage wall time is unavailable, as recorded in `full_calibration_runtime.csv`. Its checkpoint timestamp span and the curves' summed worker elapsed seconds are not stage wall time:","",if(nrow(rt))md_table(rt)else"Stage wall time unavailable.")
}
writeLines(c(
"# Amendment 2: pre-period feasibility packet",
"", "Workstream C. Requested report date: 2026-10-05. Draft for Leonel; no post-opening redesign estimates.",
"", "## Result and status",
"", "The continuation rebuilds entrance-based rings, full supplied historical OSM streets and road-length predictors, and parish census population/density. It reruns count and private-share forecasts and adjusted pre-period drift diagnostics. Full-count calibration status and any numerical failures are reported below. Enforcement, works and some policy dates remain unresolved, nonblocking limitations. All power simulations are cancelled; full-estimator calibration covers size only, with prototype figures used for planning. The amendment requires approval before any post-opening redesign estimate.",
"", "Only pre-opening crash, vehicle and rain outcomes were materialized. The Excel extractor scans routing date/key fields before decoding outcome cells; it necessarily reads ZIP bytes to reach selected rows and resolve shared strings. It never constructs excluded outcome records. No September 2024-or-later outcome is loaded, no new P1 or P2 effect is estimated, and the registered P1 report stays unchanged. The seen-specification inventory is `road_safety/output/amendment2/p1_seen_inventory.csv`.",
"", "## Built units and outcomes",
"", "The build retains every distant parish separately and builds disjoint rings, their corridor aggregate, the historic area, a separate spillover zone, station profiles and units from the full supplied historical OSM motor-road network. Current mapped subway entrances are authorized treatment geometry; the station audit explicitly lists fallbacks. Historical ways are split at shared vertices, and geometry alone defines assignment. No parish was screened out for volume. The inference-only composite registry is `road_safety/output/amendment2/placebo_composites.csv`.",
"", "The private build contains the complete crash-group × severity × road-type stack, private-car crash counts, involved-vehicle numerators and denominators, unidentified vehicles and the secondary outcomes. The hourly table includes zero cells. Published pre-period means are derived from rounded totals, suppress small positive totals and complements, and jointly protect nested ring margins; exact analysis cells stay ignored and local.",
"", "Selected monthly means, from `road_safety/output/amendment2/preperiod_monthly_means.csv` (2022 start; rounded-total means, not exact counts):", "",
md_table(means[start==2022 & unit %in% c(A2_RINGS,"corridor_0_600","historic_center","spillover") & outcome %in% c("all_crashes","private_car_crashes"),.(unit,outcome,monthly_mean)]),
"", "Geometry/name agreement, from `road_safety/output/amendment2/road_name_agreement.csv`. The agreement sample pools January 2021 through November 2023. Rates are rounded to a five-percentage-point grid and counts to five; geometry determines assignment, while names diagnose it:", "",
md_table(rn[tolerance_m==30,.(family,tolerance_m,agreement_pct,matched_crashes)]),
"", "Station-by-station geometry audit from `road_safety/output/amendment2/station_geometry.csv`:", "",
md_table(fread(file.path(A2_OUT,"station_geometry.csv"))),
"", "Ring changes relative to station points, protected and rounded, from `entrance_ring_changes.csv`:", "",
md_table(fread(file.path(A2_OUT,"entrance_ring_changes.csv"))),
"", "The source audit is `reports/data_audits/2026-10-05_amendment2_deliveries.md`. Public road lengths and allocated population/density for every registered unit appear in `geographic_predictors.csv`; `parish_road_lengths.csv` covers every DMQ parish, including non-comparators. The LEEME explains municipal transcription and census/cartographic limitations. Exact fine census source-table transcription could not be independently checked against the original municipal PDFs, which are not in the delivery.",
"", "Every unit has a nearest rain monitor assigned from geometry, including zero-crash units (`rain_assignment.csv`). `rain_coverage.csv` separates complete totals from partial observations. The model pilot uses coverage-qualified scaling and training-only missing-value imputation with flags. Pico exposure is reconstructed from the congestion module's approximate public boundary, including its disclosed southeast closure. No Waze outcomes enter.",
"", "## Held-out forecasts",
"", "The table uses the same forward held-out quarters for all methods and compares errors on the original count scale, normalized by the training mean. Both estimators use pre-fitted rain/calendar/pico controls. PPML retains treated-season effects; ASCM removes only finite control factors and retains seasonal variation in its quarterly history. ASCM additionally uses training crash/hour/pico predictors, road length from the full supplied historical OSM extract by class, and supplied census population/density. For non-parish units, population is allocated by parish intersection area; that uniform-density approximation is used only as a predictor. The full comparison, including pooled and regularized equal weights and the earlier start, is `road_safety/output/amendment2/forecast_comparison.csv`. Penalty choices and fold-specific road collapse are in `penalty_tuning.csv` and `sparsity_decisions.csv`.",
"", "The declared forecast rule chooses these headlines, subject to the unresolved inference and event-input gates. Single-unit ASCM uses ridge augmentation; rings use partially pooled multisynth with fixed-effects augmentation. Joint ring selection uses joint unrounded loss, so an individual ring's displayed error need not favor the selected joint model. Missing/failed folds make selection unresolved. Values below are from `headline_selection.csv`:", "",
md_table(main),
"", "Aggregate private-vehicle-share validation uses one numerator/exposure cell per unit-month. ASCM fits a quarterly Beta-half regularized share, explicitly including a prior mean for zero-exposure donors; held-out errors use actual shares. This is a provisional convention requiring sensitivity/approval, not a measured share for empty cells. The full comparison includes flags for predictions outside the unit interval, with no silent clipping. Selected results from `share_forecast_comparison.csv`:", "",
md_table(sf[start==2022 & unit %in% c("corridor_0_600","historic_center"),.(unit,method,share_rmse_pp,predictions_outside_unit_interval)]),
"", "Private-vehicle-share headline selection for all target families, from `road_safety/output/amendment2/share_headline_selection.csv`:", "",
md_table(sh[start==2022]),
"", "No source of post-opening outcomes enters training, tuning or validation. Poisson separation warnings concern zero cells, whose limiting prediction is zero. The pipeline retains their parishes. Short quarterly histories generate augsynth/multisynth warnings; the warnings are a substantive limitation, not suppressed evidence of a strong fit.",
"", "## Drift",
"", "The available quarterly leads are descriptive indexed gaps against pooled comparators. They are not coefficients from the adjusted PPML or ASCM event study. `preperiod_quarterly_leads.csv` suppresses a unit's path when underlying quarterly outcomes or complements are too sparse. Whole-path withholding propagates across both pre-period starts for every target. If a ring path is withheld, all ring and corridor paths for that outcome are withheld jointly across starts, including their flattening diagnostics; the adjusted paths apply the same rule. Some headline drift paths are therefore wholly withheld. `drift_flattening.csv` compares the absolute change in that gap across successive 2023 quarters; its flag is descriptive and carries no p-value.",
"", "Selected diagnostics from `road_safety/output/amendment2/drift_flattening.csv`:", "",
display_or_withheld(dr[start==2022 & outcome %in% c("all_crashes","private_car_crashes") & unit %in% c("corridor_0_600","historic_center"),.(outcome,unit,early_2023_gap_change,late_2023_gap_change,flattens_2023)]),
"", "Adjusted PPML quarterly leads are also available in `adjusted_preperiod_leads.csv`. They freeze full-pre-period nuisance estimates, then estimate unit/cell, month/cell and treated quarter effects. The version with pre-estimated treated seasonality chooses a decomposition of the same data; flatter leads are not independent proof that drift ended. The version removing the explicit treated-seasonality factor is reported beside it; other nuisance coefficients retain their original estimates alongside seasonality, so this is not a full refit without seasonality. Partial quarters carry their exposure. The corridor combines inner-ring fitted counts before the contrast. An undefined nuisance offset withholds the complete family diagnostic and is recorded in `adjusted_lead_failures.csv`; rows are never silently discarded or zero-filled to bypass that failure.",
"", "Selected adjusted log-gap changes from `adjusted_drift_flattening.csv`; these descriptive flags have no regression p-value:", "",
display_or_withheld(ad[start==2022 & outcome %in% c("all_crashes","private_car_crashes") & unit %in% c("corridor_0_600","historic_center"),.(outcome,unit,adjustment,early_change,late_change,flattens_2023)]),
"", "## Historical residual prototype, retained as the earlier record",
"", "The prototype extrapolates pre-period normalized residuals into synthetic long-window calendars. It preserves the disruption gap and the vehicle omission. It compares a legacy absolute-mean statistic with an anchored equal-tail block-rank rule under independent noise, serial/seasonal noise and continued drift. The changed tail rule, rather than centering alone, changes rejection behavior. This exercise does not simulate counts, refit the complete estimators or repeat method selection. The earlier packet used station-point geography and lacked the new road/population predictors; the residual prototype did not fit the full learners. The continuation changes geography, generator and fitted estimator, so this comparison does not isolate an estimator change.",
"", "The following appendix figures are conditional detectable shifts as percentages of the pre-period treated mean. They are not percentage effects on future counterfactual crashes. A missing value means the size tolerance fails or power never sustains the target. The full `simulation_curves.csv` reports Monte Carlo intervals; `conditional_mde.csv` reports both directions, starts, rings and block lengths. The nominal test level and the more permissive pragmatic size tolerance are documented in the amendment. Passing this diagnostic gate does not certify inference.", "",
md_table(sim[,.(outcome,unit,scenario,null_size,size_gate,fall,rise)]),
"", "Source: `road_safety/output/amendment2/conditional_mde.csv`, main start, block length three, anchored equal-tail prototype. Monte Carlo rank resolution is not independent time information: the file separately reports rank grid, identity-tie floor and exhaustive allocation floor. No actual effect p-value is reported here. These historical prototype numbers cannot validate a headline minimum detectable fall or rise. Full-count continuation results are separate below.",
"", "## Full-count continuation calibration",
"", "Simulations generate integer crash counts and private/day/hour marks from the fitted pre-period mean model and dispersion, preserve the excluded calendar months and vehicle omission, and refit both estimators, controls, sparse-cell decisions, tuning and headline selection. Serial/seasonal and continued-drift scenarios additionally impose the declared covariance stress and positive latent standard-deviation floor; those assumptions are not estimated variability. Each visited conformal assignment refits the entire learner. The earlier candidate encountered missing PPML predictions for a separated zero-count treated season; restoring its Poisson mean-zero limit also exposed an undefined seasonal division in the old ASCM adjustment. The corrected candidate retains that season's Poisson mean-zero limit but removes only finite linear control factors from ASCM, with the exposure and superseded-run record in the execution note. Exact early nonrejection uses tail-count bounds; it does not return an invented p-value. The test uses identity plus thirty-nine calendar-admissible quarter assignments, so its smallest two-sided p-value is 0.05. Its empirical size, not rank-grid fineness, is the criterion. See `road_safety/docs/amendment2_continuation_execution.md`.",
"", "The full-estimator calibration covers size only, with 200 independent null replications per cell. All power simulations and power-confirmation cells were cancelled by Leonel. Reported binomial intervals describe Monte Carlo uncertainty in size, not confidence intervals for a Quito effect. This calibration conditions on fitted data-generating parameters: full refitting carries repeated-sample slope-estimation error, but does not propagate uncertainty in the generator slope or provide a J1-equivalent interval. The independent checker checks the first 20 same-seed replications of every scheduled trend-null cell for both corridor outcomes, supplementing the accepted exact check of all nine completed baseline null cells. The final verifier record distinguishes completed checks from any pending checks. This is subset verification, not a full rerun of the remaining rejection rates.",
"", "Prototype planning figures are approximately 15% for corridor all crashes, 20% for corridor private-car crashes and 30% for historic-center all crashes. Source: `road_safety/output/amendment2/conditional_mde.csv`, 2022 start, three-month blocks, anchored equal-tail stationary scenario; both fall and rise have those values. They are conditional shifts relative to the pre-period treated mean from a residual prototype with earlier geography/predictors, not validated full-estimator minimum detectable effects or evidence that the actual analysis has 80% power at those effects. Scenario-specific qualifications and the prototype drift-size failures remain in the appendix table above.",
"", "Continued drift is prespecified as follows: if a baseline test fails the declared continued-drift size screen, report the trend-carrying variant beside that baseline in the main results table. Keep the forecast-selected headline and show both estimates, rank-based uncertainty and calibration limits; do not replace the baseline silently. Report the variant even if its own size check fails, and label that failure explicitly. This rule is a design instruction for the approved future analysis, not permission to load post-opening outcomes now.",
"", calibration_text,
"", "## Missing inputs and unfinished work",
"", "| Item | Where it would come from / completion needed |",
"|---|---|",
"| Population approximation | Supplied parish totals are joined by DPA. Non-parish estimates assume uniform population within each parish; finer census sectors would improve this predictor. |",
"| Rain | Source exists. Remaining issues are missing observations, hourly timestamp convention, and aggregation for broad rings. See LLU.xlsx and rain coverage outputs. |",
"| Enforcement | AMT/ANT device logs, road/date deployment, sanction-enabled dates and legal suspensions; public July announcement alone cannot establish the exact road-specific treatment. |",
"| Metro works | Metro/EPMMOP station-specific street closure/reopening and reinstatement dates. |",
"| Policy calendar | Resolve primary-source fuel dates, exact 2025 protest end and service-hour changes; preserve the corrected rationing and curfew chronology in the amendment. |",
"| Full model validation | Check the full-count calibration status and numerical-error table when available. The retained residual prototype is not a substitute. Share smoothing and the conditional seasonality decomposition also need review before freezing. |",
"", "Missing enforcement, works and policy inputs do not block this packet or the analysis after approval. The amendment prespecifies how audited dates and local exposure will enter sensitivities when supplied, while preserving the frozen main specification.",
"", "## What ran, failed and was skipped",
"", "The continuation used local deliveries and no network. It rebuilt entrance geometry, roads in the full supplied historical OSM extract, pre-period units and census/road predictors, then ran count/share forecasts and adjusted leads. Full-count calibration uses ignored checkpoints and logs. The old residual prototype was retained unchanged from cc471a4. Fit failures and invariant checks are recorded in `forecast_failures.csv`, `share_forecast_failures.csv` and `validation_checks.csv`. No download was attempted; the supplied PBFs resolved the earlier acquisition dependency. The full old builders were not run because they load all dates. P1/P2 redesign effects, in-space effect inference and Conley–Taber effect inference were not run. No merge or push is authorized.",
"", "Code review and methods review cover the final size-only scope and preserve any failed numerical or size gate. Independent verification is performed on the committed code SHA, and the claims audit checks this packet before final delivery. Review documents and exact verification SHA will be recorded alongside this report; a successful numerical replication does not approve the scientific design.",
"", "Stop for Leonel after the review packet is committed. This local record does not authorize loading post-period outcomes; unresolved size or numerical gates remain explicit; full-estimator power was cancelled."
),"../reports/road_safety/2026-10-05_amendment2_preperiod.md")
cat("Aggregate packet generated and invariants passed.\n")
