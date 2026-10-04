# Status board

One line per workstream. Update it when a workstream starts, stops for review, or merges. `claude --worktree <name>` puts each worktree in `.claude/worktrees/<name>/` on the branch `worktree-<name>`.

| Workstream | Worktree (branch) | State | Latest report | Waiting on |
|---|---|---|---|---|
| 0. Consolidation | main checkout (`main`) | done 2026-09-24, except the GitHub push (blocked: raw Waze records in the congestion history) | `reports/migration/2026-09-24_migration_report.md` | Leonel: decide on `congestion/reports/waze_sample.csv` in the history, then push |
| A. Air quality revision | `aq-revision` (`worktree-aq-revision`) | not started; replication gate passed with notes, so it can start | | REMMAQ download for the rest of the PM2.5 gap (Leonel); decisions on the donut definition and satellite p-values (`docs/known_issues.md`) |
| B. Congestion Step 1 | `congestion-step1` (`worktree-congestion-step1`) | stopped 2026-10-01 before any post-opening month (Amendment 6): monthly data cannot sign a plausible effect (empirical MDE 0.92 of CENTER's mean); four restart diagnostics run on pre-period data; to be squash-merged into main for the record | `reports/congestion/2026-10-01_stop_report.md` | A restart with finer provider data (`congestion/docs/provider_questions.md`) |
| C. Road safety plan | `road-safety-plan` (`worktree-road-safety-plan`) | not started; data stored, locked and checked | | Nothing; can start |
