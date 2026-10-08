# road_safety module

Evaluate recorded road crashes around Quito Metro Line 1. The locked AMT workbook covers January 2021–August 2026 and remains outside git at `data/raw/2026-09-23_amt_siniestros/`. Use the delivered workbook, not the re-saved copy. The provenance note documents the schema and checksums; observed counts are omitted from this release.

The current authority is `docs/analysis_plan_amendment_4.md` and its approved start correction. Primary pre-period begins January 2022; January 2021 is the sensitivity. Preserve the approved specifications and stop for Leonel if data force a change. The RUNBOOK gives the current run order. Historical code is retained for reproducibility, not as authority to run additional analyses.

Raw data and frozen references are read-only. Exact records, panels, diagnostic counts and unreviewed reports stay local. Released crash counts must be rounded to five; withhold positive counts below five and their complements, including linked margins. Outputs and road-safety reports are ignored by default; adding a release artifact requires explicit path approval, code review where relevant and claims audit. Run `python3 scripts/check_road_safety_release.py --index` before a release commit and `--tree HEAD` after it. This gate checks paths and ignore rules, not semantic disclosure safety.

Follow root maker/checker rules. Commit locally; do not merge or push without authorization.
