# Status board

One line per workstream. Update it when a workstream starts, stops for review, or merges. `claude --worktree <name>` puts each worktree in `.claude/worktrees/<name>/` on the branch `worktree-<name>`.

| Workstream | Worktree (branch) | State | Latest report | Waiting on |
|---|---|---|---|---|
| 0. Consolidation | main checkout (`main`) | done 2026-09-24, except the GitHub push (blocked: raw Waze records in the congestion history) | `reports/migration/2026-09-24_migration_report.md` | Leonel: decide on `congestion/reports/waze_sample.csv` in the history, then push |
| A. Air quality revision | `aq-revision` (`worktree-aq-revision`) | not started; replication gate passed with notes, so it can start | | REMMAQ download for the rest of the PM2.5 gap (Leonel); decisions on the donut definition and satellite p-values (`docs/known_issues.md`) |
| B. Congestion Step 1 | `congestion-step1` (`worktree-congestion-step1`) | not started; augsynth now installs in WSL (air quality library), not yet in the congestion library | | The Step 1 v2 prompt (Leonel); commit plan v2 as `congestion/docs/analysis_plan.md`; AGENTS.md vs plan disagreements (`reports/migration/05_claude_setup.md`) |
| C. Road safety plan | `road-safety-plan` (`worktree-road-safety-plan`) | not started; data stored, locked and checked | | Nothing; can start |
