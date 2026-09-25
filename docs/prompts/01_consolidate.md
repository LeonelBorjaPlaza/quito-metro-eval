# Prompt 01. Consolidate the Quito Metro evaluation into one repository

## For Leonel: how to run this prompt

Do the checklist in `PLAN.md` first. Then, in a WSL terminal:

```bash
mkdir -p ~/data/quito-metro-eval
python3 -m zipfile -e /mnt/c/Users/LEONELB/Downloads/quito-metro-kit.zip ~/
cd ~/projects
claude --add-dir ~/data --add-dir ~/quito-metro-kit \
  --add-dir "/mnt/c/Users/LEONELB/OneDrive - Inter-American Development Bank Group/quito-metro-airquality-2026" \
  --add-dir "/mnt/c/Users/LEONELB/Downloads/quito-new-data"
```

If a path on your laptop differs, change it in `~/quito-metro-kit/settings.env` and in the command above. In Claude Code, type: `Read ~/quito-metro-kit/PROMPT_01_consolidate.md and carry it out.` When it asks to approve routine commands (git, cp, rsync, sha256sum, Rscript), choose "Yes, and don't ask again".

Everything below this line is for Claude Code.

---

## Settings

The settings live in `~/quito-metro-kit/settings.env`. Shell variables do not survive from one command to the next, so start every shell command that uses them with:

```bash
set -u; source ~/quito-metro-kit/settings.env;
```

`set -u` makes a command fail on an unset variable instead of pointing it at the wrong folder. Quote every path, since some contain spaces.

## Context

Leonel Borja Plaza (IDB, Transport Division) leads the evaluation of Quito Metro Line 1, which opened on December 1, 2023. The work now sits in two repositories:

1. **Air quality** (`AQ_SRC`, on OneDrive, Windows side). The paper "Underground Relief": augmented synthetic control on REMMAQ monitors (local design) and synthetic difference-in-differences on satellite data (city design). Its state is frozen at the May 31, 2026 draft. The satellite estimation ran on a Google Cloud VM whose code copy is the authoritative one.
2. **Congestion** (`WAZE_SRC`, in WSL). A Waze module on H3 cells, started on September 17, 2026 with Codex. Phases A to D are done, analysis plan v2 is written, and Step 1 has not run.

Two deliveries arrived and sit in `NEW_DATA`: crash records for 2021 to 2026 from the Agencia Metropolitana de Tránsito (a new road safety module), and a PM2.5 file from the Secretaría de Ambiente that covers part of a January to February 2025 gap in the air quality panel. `KIT/repo/docs/correspondence/` summarizes both emails.

Your job is to build one repository in WSL that holds all three modules, stores raw data once and locked, proves that the frozen air quality results reproduce in the new home, and sets up Claude Code (rules, agents, permissions) for parallel workstreams. You start no new analysis.

## What done looks like

- `NEW_REPO` holds `air_quality/`, `congestion/` and `road_safety/`, with the full git history of both sources, and no data files in git.
- Raw inputs sit once in `DATA_STORE/<module>/raw/`, locked, and each module reaches them through symlinks committed in git. The derived data and outputs of both sources sit, locked, in `DATA_STORE/<module>/frozen_<date>/` as reference copies.
- Both new deliveries are stored with their provenance notes.
- WSL R can run the air quality local pipeline, augsynth and synthdid included.
- A replication gate report says whether the new home reproduces the frozen air quality tables, with an independent verifier's verdict.
- The CLAUDE.md files, agents and settings are in place.
- The repository is pushed to a new private GitHub repository, or the push commands are ready for Leonel.
- A final report lists what was done, what failed and what Leonel must do.
- `AQ_SRC` and `WAZE_SRC` are exactly as they were.

## Rules for this task

1. **This prompt governs this session.** Where a CLAUDE.md or AGENTS.md in the sources or in the new repository says otherwise (for example, that only Leonel adds raw data), follow this prompt until the migration ends.
2. **Sources are read-only.** Never write to `AQ_SRC` or `WAZE_SRC`: no commits, checkouts, fetches into them, edits or deletions. Read their git state with `git --no-optional-locks`. For `AQ_SRC` also add `-c core.autocrlf=true -c core.filemode=false`, so Windows line endings and file modes do not show up as false changes.
3. **Copy, never move.** Leave both source folders in place. Leonel removes them himself later.
4. **No new analysis.** Do not estimate anything new, do not look at post-opening outcomes for congestion or road safety, and do not change any specification. Re-running the frozen air quality pipeline, unchanged, in Phase 6 is the only estimation allowed.
5. **Flag, don't fix.** Any bug or data problem you find goes to `docs/known_issues.md` with evidence, and you keep going. The only code edits allowed are those needed to run in the new home: absolute or Windows paths turned into relative paths, and Windows line endings removed from scripts that fail under Linux. List every such edit with file and line.
6. **No data in git.** Raw data, derived data and the new deliveries never enter git, and nothing but code, documentation and aggregated output tables goes to GitHub. The crash data came with a commitment: used only for this evaluation and published only in aggregate. Never paste raw records into web tools or chat.
7. **Honest status.** Report exactly what ran, what failed and what you skipped. Never report a number you did not read from a file in this session.
8. **Hard stops.** Stop and report, without working around the problem, if: files in `AQ_SRC` cannot be read (OneDrive cloud-only placeholders); free space on the Windows drive is below twice the data to copy plus 20 GB; an environment step needs `sudo` or network access you do not have (give Leonel the exact command, then carry on with the phases that do not need it).
9. **Resume, never restart.** If `NEW_REPO` or `DATA_STORE` already holds work from an earlier run, read `reports/migration/`, resume from the last finished phase, and never delete the new repository or the store to start over without Leonel's approval.
10. **Otherwise keep going** through all phases without asking. Commit at the end of each phase with a message that says what changed and why. Keep running notes in `reports/migration/` as you go.

## Phase 0. Preflight (read-only)

1. Check that every settings path exists. List `KIT` and `NEW_DATA`. `NEW_DATA` should hold the crash Excel file, the PM2.5 Excel file and two `.msg` emails. Compare the sha256 of both Excel files with the expected values in `KIT/repo/docs/data_provenance/`; a mismatch is a note, not a stop.
2. Free space: `df -h "$HOME"` and `df -h /mnt/c`. The Windows drive is what really limits WSL. Measure the size of both sources.
3. `AQ_SRC`: current branch, other branches, last 15 commits, remotes, commits not yet pushed (`git log --oneline @{u}..HEAD` when an upstream exists), stashes, modified and untracked files, and ignored files with sizes (`git ls-files --others --ignored --exclude-standard`). Read the ten largest files in full (`sha256sum`) to prove they are on disk. If reads fail or files are empty placeholders, hard stop and ask Leonel to set the folder to "Always keep on this device".
4. `WAZE_SRC`: the same, without the autocrlf flags. Note uncommitted files, such as analysis plan v2 and the Step 1 v2 prompt. List every data file (by extension: csv, xlsx, parquet, gpkg, shp, rds and similar) that its history has ever committed, since those would travel into the new repository.
5. Scan the code of both sources for machine-specific paths and working-directory assumptions: `C:/`, `C:\\`, `OneDrive`, `/home/`, `/mnt/`, `setwd(`, `here(`, `here::`, `.Rproj`, `renv`. List the hits as file:line.
6. Environment inventory: Ubuntu release, RAM, `R --version`, whether augsynth, synthdid, fixest, sf, duckdb, data.table and the tidyverse are installed in WSL R, Python and its duckdb, pandas, geopandas and h3 packages, the `duckdb` command line, `rsync`, `stata-mp`, `gh auth status` (and `gh api user -q .login` to confirm the owner in `GITHUB_REPO`), `gcloud --version`.
7. Satellite: find any satellite code inside `AQ_SRC` and note where it is.
8. Save the output of the git state commands of steps 3 and 4. Phase 7 compares them again to prove the sources did not change.

## Phase 1. New repository

1. `mkdir -p "$NEW_REPO"`, `git init -b main`, `git config core.autocrlf input`.
2. Copy from `KIT/repo`: `.gitignore`, `docs/` and `scripts/`. Do not create `air_quality/` or `congestion/` yet, because `git subtree add` needs those folders to be absent.
3. Create `road_safety/` with a short `README.md` (what the module is, where its raw data are, and that its first tasks are a data audit and an analysis plan) and `reports/migration/`.
4. Copy `KIT/PLAN.md` to `docs/plan/2026-09-24_consolidation_and_parallel_plan.md` and this prompt to `docs/prompts/01_consolidate.md`.
5. Write `reports/migration/00_preflight.md` from your Phase 0 notes. Commit.

## Phase 2. Code with its history

1. Air quality: `git remote add aq-src "$AQ_SRC"`, `git fetch aq-src`, then `git subtree add --prefix=air_quality aq-src/<branch checked out in AQ_SRC>`. Do not squash, so the history survives. Then `git remote remove aq-src`. If `git subtree` is missing, use the equivalent subtree merge (`git merge -s ours --no-commit --allow-unrelated-histories`, then `git read-tree --prefix=air_quality/ -u`, then commit).
2. Congestion: the same with `WAZE_SRC` and the prefix `congestion`.
3. Other branches with commits that are not on the imported branch: list them in the report; do not import them.
4. Uncommitted work: copy every modified tracked file from each source into its module folder at the same relative path. From untracked, non-ignored files, copy only code and documents (`*.R`, `*.Rmd`, `*.qmd`, `*.py`, `*.ipynb`, `*.sql`, `*.do`, `*.sh`, `*.md`, `*.tex`, `*.bib`, `*.txt`, `*.yml`, `*.yaml`, `*.json`, `*.toml`); everything else goes through the Phase 3 classification. Remove Windows line endings from text files and commit as "Snapshot of uncommitted work in <source> on <date>".
5. Satellite snapshot, only if `GCP_VM_SSH` is set: copy code files only (`*.R`, `*.py`, `*.sh`, `*.md`, `*.txt`, `*.yml`, `*.json`, no data) from `~/v4_2026_05/code/` on the VM, for example as a tar stream over that ssh command, into `air_quality/code/satellite_vm_snapshot_<date>/`, with a README saying it is the authoritative VM copy. Do not touch the existing satellite code. List the files that differ from the copy in `AQ_SRC`; `00_helpers.R` is known to differ. If `GCP_VM_SSH` is empty, add this to the pending list.
6. Put `git log --oneline --graph -40` in the report. Commit.

## Phase 3. Data store, links and the new deliveries

The aim: raw inputs stored once and locked; each module reads them through symlinks committed in git, so code paths stay the same; everything derived is rebuilt inside each checkout, so parallel worktrees never overwrite one another.

1. **Classify** every ignored or data file in each source:
   - **raw input**: no script in the module writes it (search for `write.csv`, `write_csv`, `fwrite`, `saveRDS`, `save(`, `st_write`, `write_sf`, `ggsave`, `pdf(`, `png(`, `write_parquet`, `to_csv`, `to_parquet`, `COPY ... TO`);
   - **derived**: some script writes it;
   - **output**: tables and figures in the output folders, tracked or not.
   When in doubt, class it as raw input and say so. Save the result as `reports/migration/03_data_map.csv` with source path, size, sha256, class, new location and evidence.
2. **Copy raw inputs** to `DATA_STORE/<module>/raw/`, keeping their paths relative to the module root. Check every copy's sha256 against the source.
3. **Copy derived data and outputs** to `DATA_STORE/<module>/frozen_<date of the source's last commit>/`, same relative paths. These are the reference copies for Phase 6 and for later "what changed" tables. Do not put them in the working tree. Files that git tracks stay tracked as they are.
4. **Link.** In each module, put a symlink at each raw path the code reads, pointing to its place in the store, always with an absolute target (relative targets break inside worktrees, which sit deeper in the tree). Use one link per folder when the folder holds only raw inputs, and file links when a folder mixes raw and derived files. Commit the links with `git add -f`, since they sit inside ignored folders; `git ls-files -s` shows them with mode 120000. If a module uses `here()`, add an empty `.here` file at the module root so `here()` finds the module folder and not the repository root.
5. **New deliveries.** This one time, you load them yourself.
   - `DATA_STORE/road_safety/raw/2026-09-23_amt_siniestros/`: the crash Excel file and its `.msg`, plus `SHA256SUMS`. Link `road_safety/data/raw` to `DATA_STORE/road_safety/raw` and commit the link.
   - `DATA_STORE/air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/`: the PM2.5 Excel file and its `.msg`, plus `SHA256SUMS`. Do not link it into the module and do not merge it into any panel; workstream A decides how to use it.
   - Check the facts in both notes in `docs/data_provenance/` (sheets, row counts, dates, columns) against the files. Correct anything that does not match and say what you corrected.
6. **Manifest and lock.** Write `DATA_STORE/MANIFEST.sha256` for every file in `raw/` and `frozen_*/`, with paths relative to `DATA_STORE`. Then lock: `find "$DATA_STORE"/*/raw "$DATA_STORE"/*/frozen_* -mindepth 1 -exec chmod a-w {} +` and `chmod a-w "$DATA_STORE"/*/frozen_*`. Leave the top `raw/` folders writable so new dated deliveries can be added.
7. **Checks.** No tracked file under a `raw/` or `frozen_` path except symlinks. No broken links (`find . -xtype l`). List every tracked file above 5 MB. Commit.

## Phase 4. Environment in WSL

1. The target: WSL R runs the air quality local pipeline now, and the congestion Step 1 later, with augsynth, synthdid, fixest and everything else the scripts load.
2. If `air_quality/` has `renv.lock`, run `renv::restore()` from inside `air_quality/`. To avoid compiling everything from source, point CRAN at Posit Package Manager binaries for this Ubuntu release (`https://packagemanager.posit.co/cran/__linux__/<codename>/latest`, for example through `RENV_CONFIG_REPOS_OVERRIDE`). Without a lockfile, install what the scripts load (read their `library()`, `require()` and `pkg::` calls) and create one.
3. augsynth (`ebenmichael/augsynth`) and synthdid (`synth-inference/synthdid`) come from GitHub and failed to install in WSL on September 17. Diagnose from the first error line, not by guessing: a missing system library (give Leonel the exact `sudo apt-get install ...` line), a dependency archived on CRAN, or blocked access to GitHub. Never replace them with a custom estimator.
4. Write `air_quality/ENVIRONMENT.md`: R version, platform, versions of the key packages, and any difference from the versions in the lockfile. Version differences are the first suspect if Phase 6 fails.
5. Congestion: confirm that DuckDB and its h3 extension still work from the new location.
6. If the environment cannot be finished without Leonel, complete Phases 5 and 7, skip Phase 6, and put the exact commands at the top of the final report. Commit.

## Phase 5. Claude Code setup

1. Copy `KIT/repo/.claude/` (five agents and `settings.json`) into `NEW_REPO/.claude/`.
2. Root `CLAUDE.md`: copy `KIT/repo/CLAUDE.md` and fill in its two `<FILL: ...>` sections from what you found. Keep it under 150 lines. Then `ln -s CLAUDE.md AGENTS.md` at the root, so Codex reads the same rules.
3. `air_quality/CLAUDE.md`: what the module is; that its state is frozen at the May 31, 2026 draft and where the frozen references are; how to run it (point to `RUNBOOK.md`); known issues. Add these decisions from Leonel's notes after checking each against the code, and mark as UNCONFIRMED any you cannot confirm:
   - Treatment date December 1, 2023 (ISO week 48 in the weekly panels).
   - Local design: augmented synthetic control with ridge augmentation and unit fixed effects, with conformal inference. Preferred specification M8b: Centro treated, Belisario in the donor pool. Main-text sequence M7, M8, M8b; M2b and M5b in the appendix without p-values.
   - Every specification is estimated separately on three samples: pre_blackout, donut and full. The donut drops September 16 to December 30, 2024.
   - SDID Wald intervals are computed but flagged as not used; SDID local inference is not in the main tables.
   - Satellite design: SDID with a Mahalanobis-ranked Latin American donor pool (`rank_extended`), AOD primary, rank-based two-sided permutation p-values, augmented synthetic control as support.
   - Peak hours in the weekly panels: 7, 8, 9, 17, 18 and 19 on weekdays (`02_build_weekly_panels.R`, around line 60). Local pre-period from December 1, 2022 (52 weeks).
4. `air_quality/RUNBOOK.md`: first a "Setup in a fresh checkout" step (`renv::restore(prompt = FALSE)` from `air_quality/`, which links packages from the renv cache, and `mkdir -p` for every folder the scripts write to), then the local pipeline's run order from raw data to output tables, read from the driver script, README or script numbering, with inputs, outputs and expected run time. Phase 6 tests it.
5. `congestion/CLAUDE.md`: start with the line `@AGENTS.md`, so Claude Code reads the Codex instructions already there. Add that the governing plan is analysis plan v2 of 2026-09-22 (to be committed as `congestion/docs/analysis_plan.md` in workstream B) and that, where `AGENTS.md` disagrees with it, the plan wins. List the disagreements you find in the report; do not resolve them.
6. `road_safety/CLAUDE.md`: the data (see the provenance note), rules 4 and 5 of the root `CLAUDE.md` in full, and the first tasks in order (data audit, spatial frame, pre-period descriptives, analysis plan draft). No estimation.
7. Commit.

## Phase 6. Replication gate

The new home must reproduce the frozen air quality tables before anyone changes anything. Otherwise we could never tell a change caused by new data from a change caused by the move.

1. Commit on `main`. From the repository root, create a clean checkout: `git worktree add .claude/worktrees/gate-aq HEAD`. It holds the raw symlinks and the tracked files. Inside it, run the `RUNBOOK.md` setup step, then delete every derived and output file listed in `03_data_map.csv`, tracked outputs included (this checkout is temporary), so that every table you compare must be produced by this run. Note the time the run starts.
2. Run the local pipeline from raw, unchanged, following `RUNBOOK.md`. Run PM2.5 first, since it carries the headline, then the gases. Time the first specification and extrapolate. Long runs go in the background with a log in `logs/`; meanwhile continue with the checks you can do. If the whole run would exceed about four hours, finish PM2.5, and leave the gases pending with the exact command.
3. A failure because an input is missing: first search for a script that writes the file. If one does, the run order is wrong; fix `RUNBOOK.md`, not the store. Only if no script writes it and a copy exists in `frozen_` is it an orphan input. Then add it to the raw store (unlock only that folder, copy, lock again, and append its line to `MANIFEST.sha256`), add the link on `main` in the main checkout (the gate checkout is detached, so commits there would be lost), commit on `main`, run `git checkout --detach main` inside the gate checkout, and re-run. Record it in `docs/known_issues.md` as an input without a producing script.
4. Compare every regenerated table with its frozen copy, using a script you save as `reports/migration/compare_outputs.R` or `.py`: same rows and columns; integers exact; every other number classed as identical, numerical noise (absolute difference at most 1e-6), small (at most 1e-3) or material (above 1e-3). Rank-based and conformal p-values should match exactly. Any expected table that is missing or older than the run start is a failure. Scripts with random steps and no seed explain small differences in placebo-based numbers; list them.
5. Independent check. The `verifier` agent is not registered in this session, because the session started outside the repository. First create its own checkout from the repository root: `git worktree add .claude/worktrees/verify-<short-sha> <sha>`. Then launch a general-purpose subagent and tell it: to read `.claude/agents/verifier.md` and follow it; that its checkout is that absolute path; to start every command with `cd <that path> &&`; and never to touch the gate checkout or the main checkout. Give it the commit SHA, the module, the PM2.5 steps of `RUNBOOK.md` and its setup step, the reference folder `DATA_STORE/air_quality/frozen_<date>/`, and the quantities to check (every table in the output folder). Do not give it your comparison results. Save its report as `reports/verification/<date>_air_quality_<short-sha>.md`.
6. Write `reports/migration/06_replication_gate.md`: verdict first (PASS, PASS WITH NOTES or FAIL), then the tables compared, the largest differences, orphan inputs, run time, and the verifier's verdict. On FAIL, list likely causes (package versions, data, unseeded randomness, operating-system numerics) and try no fixes.
7. Congestion smoke test: if the module has a script that builds the deduplicated panel, run it in the gate checkout and compare row counts and file hashes with `DATA_STORE/congestion/frozen_*/`. This rebuild reads post-opening records only mechanically, so report totals and hashes only, never outcome values by period.
8. Remove both temporary checkouts (`git worktree remove --force` for `gate-aq` and `verify-<short-sha>`) after saving what the reports need. Commit on `main`.

## Phase 7. GitHub and the final report

1. Before pushing, list every tracked file, and every file anywhere in the history, with a data extension (`csv`, `tsv`, `xlsx`, `xls`, `dta`, `sav`, `rds`, `rda`, `RData`, `parquet`, `feather`, `gpkg`, `shp`, `dbf`, `geojson`, `nc`, `tif`, `zip`, `msg`), with path and size, and the ten largest blobs in the history. Aggregated output tables that the old repositories already tracked in their output folders may go. If anything else appears, such as raw Waze files committed in the congestion history, or any blob exceeds 50 MB, do not push. Report the list; removing files from the history before the first push is Leonel's decision.
2. If nothing blocks the push and `gh auth status` succeeds: `gh repo create "$GITHUB_REPO" --private --source . --remote origin --push`. Otherwise give Leonel the two commands: add the remote for an empty private repository he creates on github.com, and `git push -u origin main`.
3. Re-run the saved git state commands of Phase 0 on both sources and confirm the output is identical. Report any difference.
4. Update `docs/STATUS.md`: consolidation done or blocked, and what each workstream now waits on.
5. Write `reports/migration/2026-09-24_migration_report.md`, commit and push. Its structure:
   - **Result**, in one paragraph: what exists now and the replication verdict.
   - **What is where**: the tree, two levels deep, plus the data store.
   - **Phase by phase**: a table with status (done, partly done, skipped, failed) and one line of evidence each.
   - **Replication gate**: verdict, largest differences, the verifier's verdict.
   - **Code edits**: every path or line-ending edit, as file:line.
   - **Known issues added.**
   - **Pending for Leonel**, numbered, each with the exact command or action. Always include: run `bash scripts/backup_store_to_onedrive.sh` once (WSL is not backed up); once satisfied, rename or delete `~/projects/waze-metroq`; keep the OneDrive folder as the frozen archive; optionally archive the old GitHub repository; and a smoke test of the new setup: `cd ~/projects/quito-metro-eval && claude`, accept the trust dialog, run `/agents` to see the five agents, and ask "What are the hard rules in this repository?".
6. End your session with a short version of that report in the chat: result first, then the pending list.
