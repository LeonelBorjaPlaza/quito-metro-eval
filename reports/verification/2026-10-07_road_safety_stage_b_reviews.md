# Amendment 4 Stage B reviews

## Code review

The independent `code-reviewer` found no blocking design, assignment, model or
inference issue before execution. It confirmed the installed fixest API supports
the requested perfect-fit removal, observation mapping and clustered degrees of
freedom. It requested that the note explain omissions and qualify delivery
completeness; both are addressed.

The first preflight failed at the single-symbol data.table homicide filter.
The second failed because `key` is a reserved data.table constructor argument.
The maker changed the filter to `homicide==FALSE` and renamed the specification
column `model_id`. Both failures preceded the fitting marker, so no model ran
during either failed attempt. The reviewer acknowledged these missed runtime
errors and reviewed the corrections without finding a remaining blocking issue.

The completed maker run executed each approved model once. The parish check
reuses the primary fit. The only completion warning was inability to access
the system bus through `timedatectl` while capturing session metadata.
The quarterly PNG was opened and visually inspected by the maker.

## Methods review

The independent `methods-referee` found no critical, major or required minor
change in `reports/road_safety/2026-10-07_amendment4_stage_b.md`, the table or the
figure. It checked the periphery-versus-spine interpretation, pre-opening
patterns, conditional interval interpretation, zero-unit omissions and the
explicitly approved Student-t interval rule. It confirmed that the note avoids
claims about individual risk, citywide effects or a demonstrated causal effect.

## Claims review

The independent `claims-auditor` passed the new note and table. It traced the
displayed estimates and interval rounding to the full-precision output,
recomputed all table intervals without refitting, and checked omitted units,
contributing clusters, delivery months and event-study descriptions. Figure
contents matched the event coefficients and plotting code. The auditor did not
independently inspect the visual layout.

Source paths: `road_safety/code/38_amend4_stage_b.R`,
`road_safety/output/amendment4_stage_b/estimates.csv`,
`road_safety/output/amendment4_stage_b/quarterly_event_study.png`, and ignored
`road_safety/data/derived/amendment4_stage_b/` files `diagnostics.rds`,
`delivery_coverage.csv`, `estimates_full_precision.csv` and
`quarterly_event_study.csv`.

Independent numerical verification passed with notes on committed SHA `b3273b8`;
see `2026-10-07_road_safety_b3273b8.md`. Every requested result matched exactly.
The separate audit of historical files on main is recorded in
`2026-10-07_road_safety_main_release_audit.md`; no historical release was fixed.
