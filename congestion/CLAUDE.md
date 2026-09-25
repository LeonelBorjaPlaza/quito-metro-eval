@AGENTS.md

# congestion module: notes for Claude Code

The file imported above, `congestion/AGENTS.md`, holds the Codex instructions from the September 17, 2026 sessions (phases A to D). Read it as history and context. These notes and the root `CLAUDE.md` take precedence over it.

## Governing plan

- The governing document is **analysis plan v2 of 2026-09-22**, now at `congestion/docs/analysis_plan_v2.md`. Workstream B commits it as `congestion/docs/analysis_plan.md`. Until Leonel's written approval is recorded there, root rule 5 applies: no post-opening outcomes are loaded, described by area, or estimated.
- Where `AGENTS.md` disagrees with the plan, **the plan wins**. Known disagreements are listed in `reports/migration/05_claude_setup.md`, among them hour bins (AGENTS.md: 7, 8, 17, 18; plan: 7, 8, 9, 17, 18, 19), zero coding of absent records (AGENTS.md: zero; plan: provisional until the provider confirms), and the provider's answers on weekdays and the severe threshold. None of them has been resolved here.
- Step 1 (fit and freeze the pre-period model) is workstream B. The Step 1 v2 prompt written for Codex is not in this repository; Leonel supplies it.

## Running the scripts

- Run from `congestion/`. Every path in the scripts is relative to it (`Data/...`, `Output/Waze/...`, `reports/...`).
- Raw inputs: `Data/Waze/raw` and `Data/spatial` are committed symlinks into `/home/leonelb/data/quito-metro-eval/congestion/raw/`. Read-only.
- `Data/Waze/parquet/` (the deduplicated blocks) is derived. In a new checkout, rebuild it with `Rscript Scripts/Congestion/02_prepare_blocks.R`. The copy as Codex left it is in `/home/leonelb/data/quito-metro-eval/congestion/frozen_2026-09-17/`.
- Packages come from the project library `Output/Waze/_environment/R-library`, which git ignores. It exists in the main checkout only; in a new worktree run `cp -a ~/projects/quito-metro-eval/congestion/Output/Waze/_environment Output/Waze/` first. DuckDB 1.5.5 and its h3 extension work from there (checked 2026-09-24). augsynth and synthdid are not installed in that library yet.
- `reports/waze_sample.csv` holds 500 raw Waze records and is tracked by the history. Do not add more record-level extracts to git; see `docs/known_issues.md`.
