# Status board

One line per workstream. Update it when a workstream starts, stops for review, or merges. `claude --worktree <name>` puts each worktree in `.claude/worktrees/<name>/` on the branch `worktree-<name>`.

| Workstream | Worktree (branch) | State | Latest report | Waiting on |
|---|---|---|---|---|
| 0. Consolidation | main checkout (`main`) | in progress | `reports/migration/` | |
| A. Air quality revision | `aq-revision` (`worktree-aq-revision`) | not started | | Consolidation; REMMAQ download for the rest of the PM2.5 gap (Leonel) |
| B. Congestion Step 1 | `congestion-step1` (`worktree-congestion-step1`) | not started | | Consolidation (augsynth working in WSL) |
| C. Road safety plan | `road-safety-plan` (`worktree-road-safety-plan`) | not started | | Consolidation |
