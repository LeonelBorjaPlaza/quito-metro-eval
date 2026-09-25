# Quito Metro Line 1 evaluation

IDB evaluation of Quito Metro Line 1, which opened for commercial service on December 1, 2023. Lead researcher: Leonel Borja Plaza (IDB, Transport Division). Three modules share this repository.

| Module | Question | State |
|---|---|---|
| `air_quality/` | Effect on PM2.5 and gases at REMMAQ monitors (local design) and on satellite AOD and gases (city design). Paper "Underground Relief". | Frozen at the May 31, 2026 draft. Revision is workstream A. |
| `congestion/` | Effect on congestion around the Centro and Belisario monitors, as a mechanism, with Waze data on H3 cells. | Analysis plan v2. Step 1 (fit and freeze the pre-period model) is workstream B. |
| `road_safety/` | Effect on road crashes near stations and along the corridor, with municipal crash records from 2021 to 2026. | New. Data audit and analysis plan first; workstream C. |

## Repository map

```
quito-metro-eval/
├── CLAUDE.md, AGENTS.md          these rules (AGENTS.md is a symlink, so Codex reads the same file)
├── .claude/                      agents/ (five agents) and settings.json (permissions); worktrees/ is ignored
├── air_quality/                  "Underground Relief" (imported with its history from quito-metro-airquality-2026)
│   ├── code/local/               REMMAQ pipeline, 01-12 plus cross-sample and spatial placebo scripts; runs in WSL
│   ├── code/satellite/           satellite pipeline (cloud_R, laptop_R, python); runs on the GCP VM, not here
│   ├── data/raw, data/for_maps   symlinks into the data store (raw REMMAQ, satellite exports, GHS-UCDB, map layers)
│   ├── data/processed/           derived panels, rebuilt in each checkout (ignored)
│   ├── data/working/             tracked satellite donor tables and UCDB shapes
│   ├── output/                   local and satellite tables and figures (tracked ones stay tracked)
│   ├── renv.lock, renv/          package lockfile; the library itself is ignored
│   └── CLAUDE.md, RUNBOOK.md, ENVIRONMENT.md
├── congestion/                   Waze module (imported with its history from waze-metroq)
│   ├── Scripts/Congestion/       R and DuckDB scripts for phases A-D
│   ├── Data/Waze/raw, Data/spatial   symlinks into the data store (Waze delivery, map layers)
│   ├── Data/Waze/parquet/        deduplicated blocks, rebuilt in each checkout (ignored)
│   ├── Output/Waze/              inventory, descriptives, planning outputs; _environment/ holds the ignored project R library
│   ├── docs/                     provider documentation, paper copy, analysis plans v1 and v2
│   ├── reports/                  phase reports and the review packet
│   └── AGENTS.md, CLAUDE.md
├── road_safety/                  crash module (new)
│   ├── data/raw                  symlink to the store's road_safety/raw/ (AMT crash matrix)
│   └── README.md, CLAUDE.md
├── docs/                         STATUS.md, known_issues.md, data_provenance/, correspondence/, plan/, prompts/
├── reports/                      migration/, verification/, and one folder per module for workstream reports
├── scripts/                      add_raw_delivery.sh, backup_store_to_onedrive.sh
└── logs/                         run logs (ignored)
```

Raw inputs never live in the repository. Each module's raw folders are committed symlinks with absolute targets into `/home/leonelb/data/quito-metro-eval/<module>/raw/`, so every worktree reads the same locked files. `MANIFEST.sha256` at the store root fingerprints every raw and frozen file.

## Hard rules

1. **Raw data are read-only.** They live once in `/home/leonelb/data/quito-metro-eval/<module>/raw/`, locked, and each module reaches them through symlinks committed in git. Never edit, move, delete or re-save them. Only Leonel adds raw data, with `scripts/add_raw_delivery.sh`, run in his own terminal.
2. **Frozen references are read-only.** `/home/leonelb/data/quito-metro-eval/<module>/frozen_*/` holds the derived data and outputs as they were before this repository existed. They are the answer keys for "what changed" tables.
3. **No data in git.** Commit code, documentation and aggregated outputs only. Check `git status` before every commit. Never use `git add -A` or `git add .` without reading the list of files first.
4. **Confidential data.** The crash records in `road_safety` were shared by the Agencia Metropolitana de Tránsito (AMT) for this evaluation only, to be published only in aggregate. REMMAQ and Waze data follow their providers' terms. Never paste raw records into web tools, emails or chat, and never send data over the network.
5. **No post-opening estimates without an approved plan.** In `congestion` and `road_safety`, do not load, describe by area, or estimate outcomes after December 1, 2023 until the module's analysis plan (`congestion/docs/analysis_plan.md` once v2 is committed, `road_safety/docs/analysis_plan.md`) carries Leonel's written approval. In `air_quality`, re-running approved specifications is allowed; a new specification, window or donor rule needs his approval first.
6. **Inference.** With few donors, use rank-based permutation or conformal inference. Never report Wald or pnorm p-values. State the smallest attainable p-value next to any rank-based p-value. Estimate each window separately; never slice a longer window's effect vector. Conformal p-values with missing confidence bounds are correct, not a bug.
7. **Flag, don't fix.** Problems outside your task go to `docs/known_issues.md` with evidence. Never change a design choice to make a problem go away.
8. **Minimal change.** Targeted edits over refactors. The air quality pipeline keeps its structure, including the standalone per-pollutant scripts.
9. **Maker and checker.** A result is done only after the `verifier` agent passes it on a committed SHA. Anything that leaves the repository goes through the `claims-auditor` first.
10. **Numbers.** Never state a number you did not read from a file in this session, and give the path. Never quote numbers from memory or from earlier chats.
11. **Honest status.** Say exactly what ran, what failed and what you skipped.
12. **Plan first.** For anything beyond a small fix, write a short plan (Claude Code plan mode) and wait for Leonel's approval before running code. Do exactly what was asked; list any extra idea as a suggestion at the end instead of doing it.

## Working in parallel

- One workstream per worktree and branch. From the repository root: `claude --worktree <name>`, which creates `.claude/worktrees/<name>/` on branch `worktree-<name>`. Names: `aq-revision`, `congestion-step1`, `road-safety-plan`.
- Raw data come through the committed symlinks. Every derived file is rebuilt inside your own worktree. Never point code at another worktree's files.
- A new worktree has no package library and no derived folders, since git does not track them. Before running a module in a new worktree, run the setup step at the top of its `RUNBOOK.md` (it restores packages from the renv cache and creates the folders the scripts write to).
- Merge into `main` only after Leonel has reviewed the workstream's report.
- Keep `docs/STATUS.md` current, one line per workstream.

## Agents

Defined in `.claude/agents/`.

- `data-auditor`: first look at a new data delivery.
- `code-reviewer`: read-only review of new or changed analysis code.
- `methods-referee`: review of analysis plans and results memos.
- `verifier`: independent re-run from raw on a clean checkout of a committed SHA, compared with a reference.
- `claims-auditor`: traces every number in an outgoing document to its file.

Order for any result: an approved plan, the code, `code-reviewer`, commit, `verifier`, the report, `methods-referee` for plans and results memos, `claims-auditor`, then Leonel.

## Writing

Reports and memos in plain English. Lead with the result, then explain how you got there, with short subtitles. Active voice, complete sentences, no em dashes. Translate jargon. Reports go in `reports/<module>/` with the date in the file name.

## Environment

- **R 4.5.2** (Ubuntu 26.04 under WSL2). Compilers gcc/g++ 15.2. `sudo` asks for a password, so Claude cannot install system packages; the system libraries for sf (GDAL 3.12, GEOS 3.14, PROJ 9.7) are present.
- **air_quality**: renv. `air_quality/.Rprofile` activates renv 1.2.2; the library links from the shared cache `~/.cache/R/renv/cache/`. Restore with `RENV_CONFIG_INSTALL_REMOTES=FALSE RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/resolute/latest" Rscript -e 'renv::restore(prompt = FALSE)'` from `air_quality/`. Without `INSTALL_REMOTES=FALSE`, renv pulls MCPanel (outside the lockfile), which fails under GCC 15 and rolls back the whole restore. Key versions: augsynth 0.2.0 (GitHub 65c5a6f), synthdid 0.0.9 (GitHub 70c1ce3), fixest 0.14.1, dplyr 1.2.1, readr 2.2.0. Details: `air_quality/ENVIRONMENT.md`.
- **congestion**: no renv. Scripts prepend the ignored project library `congestion/Output/Waze/_environment/R-library` (duckdb 1.5.5, arrow 25.0.1, data.table 1.18.6.1, fixest 0.14.2, sf from the system) and load the DuckDB h3 extension from `Output/Waze/_environment/duckdb_extensions`. Both exist only in the main checkout; in a new worktree copy them first: `cp -a ~/projects/quito-metro-eval/congestion/Output/Waze/_environment congestion/Output/Waze/`. h3jsr does not work (V8 needs libnode.so.127). augsynth and synthdid are not in that library yet; workstream B must add them (they install from GitHub; see the air quality restore).
- **Python** 3.14.6 with pandas and openpyxl; no duckdb, geopandas or h3 modules. No duckdb command-line tool; use DuckDB from R.
- **Stata**: binaries exist in the home folder, unused by any pipeline here. **gcloud**: not installed, so the satellite VM is out of reach from WSL.
- **GitHub**: `gh` is logged in as LeonelBorjaPlaza.

## Module details

Each module has its own `CLAUDE.md` with run commands and locked decisions. `air_quality/RUNBOOK.md` gives the run order from raw data to outputs; the other modules get one as their pipelines take shape.
