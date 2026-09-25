# Phase 5. Claude Code setup, 2026-09-24

## Result

The five agents and the permission settings from the kit are in `.claude/`. The root `CLAUDE.md` has its two sections filled in (95 lines) and `AGENTS.md` links to it. Each module has its own `CLAUDE.md`, and `air_quality/` has a `RUNBOOK.md` and an `ENVIRONMENT.md`.

## Files

| File | What it holds |
|---|---|
| `.claude/agents/{data-auditor,code-reviewer,methods-referee,verifier,claims-auditor}.md` | Copied unchanged from the kit |
| `.claude/settings.json` | Copied unchanged from the kit (accept edits by default; deny edits under `raw/` and `frozen_*`, `chmod`, `sudo`, `rm -rf`, force pushes, history rewrites) |
| `CLAUDE.md` | Kit text plus the repository map and the environment section |
| `AGENTS.md` | Symlink to `CLAUDE.md` |
| `air_quality/CLAUDE.md` | State, frozen references, how to run, the eleven locked decisions checked against the code and paper, module rules, known issues |
| `air_quality/RUNBOOK.md` | Setup in a fresh checkout, then the run order from raw data to every local table; run times filled in from the Phase 6 gate |
| `air_quality/ENVIRONMENT.md` | Written in Phase 4 |
| `congestion/CLAUDE.md` | Starts with `@AGENTS.md`; the governing plan (v2 of 2026-09-22, the plan wins over `AGENTS.md`), how to run, the project library |
| `road_safety/CLAUDE.md` | The data, root rules 4 and 5 in full, the four first tasks, no estimation |

## Locked decisions in `air_quality/CLAUDE.md`: what the check found

| Decision in Leonel's notes | Result |
|---|---|
| Treatment December 1, 2023, ISO week 48 | Confirmed (`02_build_weekly_panels.R:429-436`, `03_analysis_setupPM2.5.R:35`) |
| Augmented synthetic control, ridge, unit fixed effects, conformal inference | Confirmed (`04_PM2_5_crosssample.R:96-121`) |
| Preferred M8b, Centro treated, Belisario in the pool | Confirmed |
| Main-text sequence M7, M8, M8b | Corrected: Table 5 is M7, M9, M8, M8b |
| M2b and M5b in the appendix without p-values | Partly corrected: M2b has none, M5b has conformal p-values (Table A.3) |
| Three samples, each estimated separately | Confirmed (`04_PM2_5_crosssample.R:61-78`) |
| Donut drops September 16 to December 30, 2024 | Corrected: the cross-sample tables and the paper drop the 14 flagged weeks starting 2024-09-16 through 2024-12-16. Only the spatial placebo scripts drop the 16 weeks through the week of 2024-12-30. Logged in known issues. |
| SDID Wald intervals computed but not used; no local SDID inference in main tables | Confirmed |
| Satellite: SDID, Mahalanobis `rank_extended` donors, AOD primary | Confirmed in the OneDrive code and the paper |
| Satellite: rank-based two-sided permutation p-values | UNCONFIRMED: the OneDrive code and the paper use Wald p-values as primary and permutation p-values as a secondary check. Logged in known issues. |
| Satellite: augmented synthetic control as support | Not checked (satellite outputs only) |
| Peak hours 7, 8, 9, 17, 18, 19 on weekdays, `02_build_weekly_panels.R` around line 60 | Confirmed (lines 59-61) |
| Local pre-period from December 1, 2022, 52 weeks | Confirmed (line 96; 52 pre-treatment weeks in the frozen panels) |

## Where `congestion/AGENTS.md` disagrees with analysis plan v2

Listed, not resolved. `congestion/CLAUDE.md` says the plan wins.

1. **Hour bins.** AGENTS.md ("Author decisions accepted before Phase B" and "before Phase C"): morning bins 7 and 8, evening bins 17 and 18, "pending author confirmation". Plan v2, section 4: bins 7, 8, 9, 17, 18 and 19, matching the paper's panel script; section 11: "Hour bins and the primary window are settled."
2. **Zero coding of absent records.** AGENTS.md (Phase B status): "complete other absent cell-hours as zero congestion under the authors' sparse-panel convention". Plan v2, section 1: zero coding only after the provider confirms in writing; until then provisional, used for diagnostics and pre-period fits only, and no final estimate.
3. **Weekdays in the hourly profiles.** AGENTS.md section 2: confirm whether a day-of-week dimension exists; if not, the peak block averages over weekends. Plan v2, section 1: the provider confirmed that hourly profiles use Monday to Friday only (email of 2026-09-17).
4. **Severe congestion threshold.** AGENTS.md section 2: 40 percent of free flow per the provider's email, not confirmed. Plan v2, section 1: confirmed as Waze jam levels 3 and 4, equivalent to speed below 40 percent of free flow.
5. **Contaminated keys.** AGENTS.md (Phase B status): negative spread ratios and severe persistence above 100 found, "no silent trimming rule has been chosen". Plan v2, section 1: a fixed flag rule makes such keys missing for every outcome.
6. **Creating `docs/analysis_plan.md`.** AGENTS.md (Session amendments): "Do not create `docs/analysis_plan.md`; the authors will write it after review." This consolidation's plan: workstream B commits plan v2 as `congestion/docs/analysis_plan.md`.
7. **Status of the air quality analysis.** AGENTS.md rule 0.3: "The air quality analysis is finished and frozen. Do not modify anything that belongs to it." Now workstream A revises it under root rule 5.
8. **Outcomes.** AGENTS.md (before Phase C): outcomes include `tc_spread` in metres. Plan v2, section 4: primary `tci_osm_ratio`; secondary morning and evening blocks, `tci_severe_osm_ratio`, `avg_jam_speed_ratio`, the fast-road block and the length-weighted aggregate. `tc_spread` is not listed as an outcome.
9. **Pre period and paper alignment.** AGENTS.md section 1 frames the module around the paper's windows; plan v2, section 5 uses January 2022 to November 2023 (23 months) as the pre period, with the paper's December 2022 start as a sensitivity. It adds a coverage screen, a low-exposure donor sensitivity and a 1-km San Francisco alternative geography that AGENTS.md does not have.
10. **Group membership rule.** AGENTS.md: CORRIDOR is "cells within 1 km of any other Line 1 station". Plan v2, section 2: membership by cell centroid, sets disjoint. The counts are the same (7, 7, 34, 56), but the rule is stated differently.

The Step 1 v2 prompt that the plan refers to is not in either repository.
