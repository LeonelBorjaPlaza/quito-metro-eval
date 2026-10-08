# Status board

One line per workstream. Update it when a workstream starts, stops for review, or merges. `claude --worktree <name>` puts each worktree in `.claude/worktrees/<name>/` on the branch `worktree-<name>`.

| Workstream | Worktree (branch) | State | Latest report | Waiting on |
|---|---|---|---|---|
| 0. Consolidation | main checkout (`main`) | done 2026-09-24, except the GitHub push (blocked: raw Waze records in the congestion history) | `reports/migration/2026-09-24_migration_report.md` | Leonel: decide on `congestion/reports/waze_sample.csv` in the history, then push |
| A. Air quality revision | `aq-revision` (`worktree-aq-revision`) | round closed 2026-10-07: local re-estimation on the 2026-10-04 REMMAQ delivery verified and claims-audited; paper tables and figures rebuilt; consolidated change list (47 text entries); satellite part deferred; no paper text changed | `reports/air_quality/2026-10-06_paper_change_list.md`; `HANDOFF.md`; `DECISIONS.md` | Leonel: edit the paper by hand; approve items 4 and 5 and confirm two wordings; Refine-dependent text; send the two emails |
| B. Congestion Step 1 | `congestion-step1` (`worktree-congestion-step1`) | stopped 2026-10-01 before any post-opening month (Amendment 6): monthly data cannot sign a plausible effect (empirical MDE 0.92 of CENTER's mean); four restart diagnostics run on pre-period data; to be squash-merged into main for the record | `reports/congestion/2026-10-01_stop_report.md` | A restart with finer provider data (`congestion/docs/provider_questions.md`) |
| C. Road safety plan | `road-safety-clean-release` | Corrected January 2022 Stage B verified on 7fac48b; requested outputs and note reviewed; clean current tree passed claims audit after redaction; original 2021 results retained as sensitivity | `reports/road_safety/2026-10-07_amendment4_stage_b_2022.md` | Leonel executes main replacement and push if desired; retained baseline history is not sanitized |
