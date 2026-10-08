# Small-count audit of main at 4abdbe8

**Not compliant.** The squash changed 436 paths (`git diff --name-only
4abdbe8^ 4abdbe8`). A read-only claims-auditor inspected current main-tree tables,
their writers, historical review evidence and prose. Direct protected counts,
unrounded counts and linked reconstructions remain. No existing release was fixed.

The rule checked is Amendment 4's release rule: round counts to five, withhold
positive small counts and their complements, and protect linked margins.
Geographic unit counts and model estimates are not themselves crash counts.
This inventory reports paths and failure types without repeating protected values.

## Confirmed table failures

Each filename below is a separate file under the stated directory. Some fail
rounding alone; others disclose protected counts or allow reconstruction.

`reports/road_safety/2026-09-25_data_audit_tables/`:

- `02_inventory_columns.csv`
- `03_monthly_completeness_districtwide.csv`
- `05_yearly_completeness_districtwide.csv`
- `06_keys_links_duplicates.csv`
- `07_numeric_id_ranges_by_year.csv`
- `08_near_duplicates_by_year.csv`
- `09_vehreg_vs_vehicle_rows_by_year.csv`
- `10_categories_pre_counts_and_presence.csv`
- `11_vehicle_subcategories_pre.csv`
- `12_area_categories_pre_counts_and_presence.csv`
- `13_parish_zona_pre.csv`
- `14_id_unit_codes_pre.csv`
- `15_severity_vs_counts_pre.csv`
- `16_typology_by_severity_and_vehicles_pre.csv`
- `17_cause_by_typology_pre.csv`
- `18_vehicle_type_by_typology_pre.csv`
- `19_road_user_groups_pre.csv`
- `20_atipico_by_quarter_pre.csv`
- `21_hour_of_day_pre.csv`
- `23_coordinate_quality_by_year.csv`
- `25_repeated_coordinate_pairs_pre.csv`
- `26_points_over_40km_from_centre_by_parish_pre.csv`
- `27_metro_proximity_pre.csv`
- `28_crashes_within_500m_by_station_pre.csv`
- `29_monthly_series_pre_by_severity_and_typology.csv`
- `31_amt_id_year_mismatch.csv`
- `32_vehicle_sentinels_by_type_pre.csv`
- `33_vehicle_value_checks.csv`
- `34_vehicle_type_by_service_pre.csv`

`road_safety/output/build/`:

- `build_summary.csv`
- `fast_road_geometry_check.csv`
- `fast_road_geometry_far.csv`
- `fast_road_geometry_summary.csv`
- `fast_road_names_pre.csv`
- `vehicle_types.csv`

`road_safety/output/completeness/`:

- `coordinate_repetition_by_year.csv`
- `flags_by_year.csv`
- `missing_fields_by_year.csv`
- `records_per_year.csv`

`road_safety/output/descriptives/`:

- `hour_of_day.csv`
- `monthly_by_band.csv`
- `monthly_by_treated_area.csv`
- `monthly_citywide.csv`
- `severity_and_involvement_by_year.csv`
- `severity_by_band.csv`
- `typology.csv`
- `weekday.csv`

`road_safety/output/spatial/`:

- `assignment_rates.csv`
- `pre_counts_by_band.csv`
- `pre_counts_by_parish.csv`
- `pre_counts_by_parish_polygon.csv`
- `pre_counts_by_station.csv`
- `pre_counts_by_treated_area.csv`

Other count tables:

- `road_safety/output/power/candidates/urban_street_removed.csv`
- `road_safety/output/power/gradient/band_counts_pre2022.csv`
- `road_safety/output/power/pool_b/fast_road_shares.csv`
- `road_safety/output/preperiod/fast_fix_changes.csv`

Means from which exact unrounded totals can be recovered by multiplying by the
pre-period month count and identifying the unique compatible integer:

- `road_safety/output/power/donor_units.csv`
- `road_safety/output/power/pool_A_candidates.csv`
- `road_safety/output/power/pool_b/screen_detail.csv`
- `road_safety/output/power/mde_table.csv`
- `road_safety/output/power/candidates/composites.csv`

This was arithmetic inspection of existing files; no power analysis was run.

## Confirmed prose and log failures

- `docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`
- `docs/known_issues.md` (historical entries)
- `road_safety/docs/analysis_plan.md`
- `reports/road_safety/2026-09-25_claims_audit.md`
- `reports/road_safety/2026-09-25_code_review.md`
- `reports/road_safety/2026-09-25_code_review_pass2.md`
- `reports/road_safety/2026-09-25_data_audit.md`
- `reports/road_safety/2026-09-25_step1_report.md`
- `reports/road_safety/2026-10-01_code_review_pass6.md`
- `reports/road_safety/2026-10-01_code_review_pass7.md`
- `reports/road_safety/2026-10-04_model_inventory.md`
- `reports/verification/2026-09-25_road_safety_483dd6c.md`
- `reports/verification/2026-09-25_road_safety_b7d96e3.md`
- `reports/verification/2026-09-28_road_safety_0210ed2.md`
- `reports/verification/2026-10-01_road_safety_914c651.md`
- `reports/verification/2026-10-01_road_safety_leakfix_recheck.md`
- `road_safety/output/p1/session_info.txt`

Historical reviews themselves reproduce protected details, including details
removed from subsequent tables. Relevant evidence includes the code-review
files above and `reports/verification/2026-10-01_road_safety_premerge_scan.md`.

## Figures and linked releases

These figures were generated directly from unrounded count tables without a
release transformation, as shown in `road_safety/code/03_descriptives.R`:

- `road_safety/output/descriptives/hour_of_day.png`
- `road_safety/output/descriptives/monthly_by_band.png`
- `road_safety/output/descriptives/monthly_citywide.png`
- `road_safety/output/descriptives/weekday.png`

This is a rounding failure in plotted inputs; it does not assert that every
exact value can be read from raster pixels.

`road_safety/output/p1/estimates.csv`, together with exact monthly Step 1
counts in `road_safety/output/descriptives/monthly_by_treated_area.csv` and
`monthly_by_band.csv`, permits reconstruction of unrounded large P1 totals.
The evidence is `reports/verification/2026-10-04_road_safety_p1_d7ee00b.md`.
The estimates are not classified as small counts by themselves.

## Limit of certification

The audit cannot certify every possible linked reconstruction across model
coefficients, means, shares, historical prose and graphics. In particular,
`road_safety/output/descriptives/zero_share_by_unit.csv`,
`road_safety/output/power/donor_pools.csv` and the other P1 index and estimate
outputs remain uncertified for joint reconstruction. The current exploratory
direct count columns were checked for rounding and suppression; this is not a
universal cross-release certificate. Later Amendment 3/4 means round totals
before division, so a small-looking mean is not automatically a disclosure.

No universal compliance claim is justified. No raw records were printed, no
files on main were changed, and no estimates, simulations or placebo tests were
run for this audit.
