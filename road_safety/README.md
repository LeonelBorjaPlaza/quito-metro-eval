# Road safety module

The approved Amendment 4 evaluates recorded crashes around Quito Metro stations using monthly PPML. Read `docs/analysis_plan_amendment_4.md`, its start correction, and `RUNBOOK.md` for the specification and execution record.

The AMT crash matrix covers January 2021–August 2026. It stays locked outside git under `/home/leonelb/data/quito-metro-eval/road_safety/raw/`, reached through `data/raw`. Results may be published only in aggregate and under the small-count rule. See `../docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`.

Historical source code and redacted plans are retained. Earlier crash-derived count tables, figures and reports are excluded from the clean release. Current artifacts must appear in the explicit release allowlist and pass claims review. The path gate does not certify that model outputs and prose cannot jointly disclose protected values.
