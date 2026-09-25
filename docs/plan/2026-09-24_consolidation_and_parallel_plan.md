# Quito Metro evaluation: one repository, then parallel work

Plan of September 24, 2026

## The plan in brief

We move everything into one repository in WSL, `~/projects/quito-metro-eval`, with three modules: air quality, congestion and road safety. Raw data live once, outside the repository and locked, and each module reaches them through links. Before any new analysis, the new home must reproduce the frozen air quality tables, and an agent that did not do the move checks that it does. Then three workstreams run in parallel, each in its own working copy, and every result is checked by an agent that did not produce it. From Sant'Anna's template we take the verification ideas and four agent designs, not the whole template.

The kit holds this plan, `PROMPT_01_consolidate.md` for Claude Code, `settings.env` with the paths the prompt uses, and a `repo/` folder with the agents, permission settings, rules and first documents that the prompt installs.

## Decisions I made for you

You can change the first and the third in `settings.env`, a short file that comes with the kit.

1. **Name.** `~/projects/quito-metro-eval`, with a new private GitHub repository of the same name. The old GitHub repository stays as the frozen record of the May 31 draft.
2. **History.** Both repositories keep their full history inside the new one. Git calls this a subtree merge: the old commits stay intact, and one merge commit places each repository under its own folder.
3. **Satellite pipeline.** Its code comes in as a snapshot only if you fill in the VM line in `settings.env`. Nothing on the satellite side is re-run.
4. **Old folders.** Nothing is moved or deleted. The OneDrive folder becomes the frozen archive, and you delete `~/projects/waze-metroq` yourself once you are happy with the new repository.
5. **PM2.5 revision.** First a run with only the gap filled and the paper's windows unchanged, so any change in the estimates comes from the filled weeks. Extending the series to later months is a separate run that needs your approval.
6. **Executor.** Claude Code replaces Codex. A link named `AGENTS.md` points to `CLAUDE.md`, so Codex can still read the same rules if you ever want it as an outside checker.

## Before you run the prompt (about ten minutes)

1. **OneDrive.** In File Explorer, right-click `quito-metro-airquality-2026`, choose "Always keep on this device", and wait until every file shows a green check. WSL cannot read files that exist only in the cloud.
2. **New data.** Create `C:\Users\LEONELB\Downloads\quito-new-data\` and save there the two emails as `.msg` files and their two Excel attachments, `REPORTE 2026-175 MATRIZ SINIESTRALIDAD DMQ 2021-2026.xlsx` and `DATOSFALTANTESPM2.5_ANALISISMETRO.xlsx`.
3. **Congestion files from our last chat.** If analysis plan v2 and the Step 1 v2 prompt are not yet in `~/projects/waze-metroq/docs/`, put them there. Committing them is optional, since the prompt captures uncommitted files.
4. **The kit.** Download `quito-metro-kit.zip` to your Downloads folder.
5. **Launch.** Run the commands at the top of the prompt. They unzip the kit into your WSL home and start Claude Code with access to OneDrive, Downloads and the data store. If any path differs on your laptop, edit `~/quito-metro-kit/settings.env` and the launch command.
6. **Optional.** If `gh auth status` works in WSL, the prompt creates the GitHub repository itself. If you want the satellite code snapshot, fill in the VM line in `settings.env`.

## What the prompt does

| Phase | What happens | When it stops |
|---|---|---|
| 0. Preflight | Reads both repositories and the environment without changing anything. | Files not on disk, or too little space on C:. |
| 1. New repository | Creates `quito-metro-eval` with the kit's documents. | |
| 2. Code and history | Brings in both repositories with their history, plus any uncommitted work. | |
| 3. Data | Copies raw inputs into the locked store, keeps the old derived files as reference copies, and adds the two new deliveries. | |
| 4. Environment | Installs the R packages in WSL, augsynth and synthdid included. | A step that needs `sudo`: it gives you the command and carries on with the rest. |
| 5. Claude Code setup | Writes the CLAUDE.md files and the run order, and installs the five agents and the permission settings. | |
| 6. Replication gate | Re-runs the air quality pipeline in a clean copy and compares every table with the frozen one. A separate agent checks the comparison. | Material differences: it reports them and fixes nothing. |
| 7. GitHub and report | Pushes code only, confirms the old folders are untouched, and writes the final report with your to-do list. | Data files or very large files anywhere in the history. |

The replication gate matters most. If the new home did not reproduce the old tables, any change we saw after filling the PM2.5 gap would mix two things, new data and a new computer. The gate separates them before we start.

## How the data are laid out, and why

```
~/data/quito-metro-eval/                 outside git, locked
├── air_quality/raw/                     REMMAQ and other inputs, plus the Secretaría's PM2.5 file
├── air_quality/frozen_<date>/           derived files and tables as they were on OneDrive
├── congestion/raw/                      the Waze delivery and the spatial layers
├── congestion/frozen_<date>/            the deduplicated panel as Codex left it
├── road_safety/raw/2026-09-23_.../      the crash matrix
└── MANIFEST.sha256                      a fingerprint of every file

~/projects/quito-metro-eval/             git
├── air_quality/  congestion/  road_safety/   code, docs, outputs; raw data folders are links into the store
├── docs/         plan, prompts, known issues, status board, provenance notes, email summaries
├── reports/      migration, verification and workstream reports
└── .claude/      the five agents and the permission settings
```

Raw data sit in one place, and no program can change them by accident, because the files themselves are read-only, not just forbidden to Claude. Each copy of the code reaches them through links, and everything built from them is rebuilt inside that copy. That is what lets two sessions run the same pipeline at the same time without overwriting each other's files.

## How the parallel work will run

A worktree is a second working folder of the same repository, on its own branch. Claude Code creates one per session with `claude --worktree <name>`. Edits in one worktree never touch another, and git keeps them all in one history.

1. Open three WSL tabs. In each one, from `~/projects/quito-metro-eval`, run `claude --worktree aq-revision`, `claude --worktree congestion-step1` or `claude --worktree road-safety-plan`.
2. Paste that workstream's prompt. I will write the three prompts once the consolidation report is in, because they depend on the real paths and on the run order that the gate confirms.
3. Every session follows the same loop: a plan you approve, the work, `code-reviewer`, a commit, `verifier` on that commit, the report, `methods-referee` for plans and results memos, `claims-auditor`, and a stop for you.
4. You review each report, and paste it here when you want a second reading, as we did with Astra. Then you merge the branch into `main`.
5. Three sessions plus their checkers use your usage limits faster. If you hit them, run A and B first; C needs no heavy estimation.

## The five agents

An agent is a Claude with its own instructions and a clean memory, called by the main session for one job. The one that checks never saw how the work was done, which is the point.

| Agent | Job | When |
|---|---|---|
| `data-auditor` | Coverage, gaps, duplicates, odd values and questions for the provider in any new delivery. | New data, before a module reads it. |
| `code-reviewer` | Reads new code and looks first for errors that change numbers: joins, dates, missing values, samples, windows and inference. | After code is written. |
| `methods-referee` | Checks plans and results memos against the approved plan and our inference rules. | Before a plan goes to you, and before results are reported. |
| `verifier` | Re-runs the work from raw data in its own clean copy, writes down its own numbers, and only then compares them with the reference and with the report. | After each commit that produces results. |
| `claims-auditor` | Traces every number in a document to the file and script behind it, and flags wording that says more than the evidence. | Before anything leaves the repository. |

Four are adapted from Sant'Anna's agents, with credit in each file. The data auditor is new. You can add agents later with a Markdown file in `.claude/agents/` or with the `/agents` command.

## Workstreams after the consolidation

### A. Air quality revision

This answers the Secretaría de Ambiente.

1. **Diagnose the gap.** Trace the seven missing PM2.5 weeks (the weeks starting January 13 through February 24, 2025) through the pipeline, and establish whether the data were missing at download or dropped in processing. `read_remmaq()` and its `df[-1,]` are the first suspect to clear.
2. **Fill it.** The Secretaría's file covers January 13 to 25, about two of the seven weeks. The rest needs a new REMMAQ download, which is your action below. The download should overlap existing data, so we can check that new and old values match before we trust the new ones.
3. **Re-run with the gap filled** and the paper's windows unchanged, and produce an old versus new table for every specification and sample. A check comes free. The pre_blackout estimates use no 2025 data, so they should not move. If they do, some completeness rule depends on the whole series, and that is the first thing to explain.
4. **Belisario.** A table of donor weights for every specification and sample, and a leave-one-out donor sensitivity, which shows how the estimate moves when each donor, Belisario included, is dropped.
5. **Wording.** The mechanism paragraph is paper text. I will draft it here once A, B and C give us the evidence.
6. **Extension** to later months only if you approve it, as a separate run.

### B. Congestion Step 1

Commit analysis plan v2, adapt the Step 1 v2 prompt written for Astra to Claude Code, and fit and freeze the pre-period model. It stops before any post-opening outcome, as the plan says. It needs augsynth working in WSL, which Phase 4 of the consolidation settles. Juan Camilo's answer on absent records decides the final numbers, not Step 1.

### C. Road safety

1. `data-auditor` on the crash matrix, with questions for the provider: the meaning of the ATIPICO typology, the record with "SICARIATO" in the deaths field, and whether recording practices changed between 2021 and 2026.
2. A spatial frame: crashes on the same H3 grid as Waze, and on station catchments and the corridor.
3. Pre-period descriptives only, January 2021 to November 2023.
4. An analysis plan for your approval. Crashes are sparse, about 300 a month in the whole district, so the plan must pick units large enough to detect a plausible effect, and a power calculation will say how large.

## What we take from Sant'Anna, and what we leave

We take these ideas:

- Replicate before extending: the gate in Phase 6.
- The maker never grades the work: the verifier and the claims auditor.
- Blind checking: the verifier computes its own numbers before it opens the reference.
- Every number traced to a file and a script.
- Plan first and scope discipline, written into CLAUDE.md.
- His rule for confidential data: raw data locked and never in git.
- Proportionality: light process while exploring, full checks for numbers that leave the repository.

We leave these:

- The Beamer, Quarto and TikZ machinery: six agents, the palette checks and the slide rules.
- The commit gate with ten checks and a quality score, which assumes LaTeX and Quarto on your laptop.
- Most of the 60 commands and 37 rules. They cost context in every session and add ceremony that a three-module project does not need.
- His permission settings, which switch all prompts off.

## Risks and how the plan handles them

- **OneDrive files not on disk.** The checklist and the preflight catch this before anything is copied.
- **WSL has no backup.** Code goes to GitHub. The data store goes to OneDrive with `scripts/backup_store_to_onedrive.sh`, which you run after each new delivery.
- **augsynth will not install.** Phase 4 finds the exact cause and gives you any `sudo` command, and the rest of the consolidation goes ahead.
- **Long runs.** PM2.5 runs first, long jobs go to the background, and the gases can wait.
- **Confidential data.** Locked files, a history with no data in it, and a rule against pasting records anywhere.
- **Data in an old history.** If either old repository ever committed a data file, for example the raw Waze delivery, the push to GitHub stops and you decide whether to strip it from the history first.
- **The gate fails.** We stop and explain the differences before any new analysis, for the reason given above.

## Your actions outside Claude Code

1. Reply to Dennys Mosquera, who asked for a phone number for future coordination.
2. Download from REMMAQ, with the VPN, hourly PM2.5 for all stations from December 1, 2024 to March 31, 2025. That covers the rest of the gap and overlaps existing data on both sides. If you expect to extend the series, download through the latest month instead. Then add the file to the store with `scripts/add_raw_delivery.sh`, run in a normal terminal.
3. After the consolidation report, run the backup script once, archive the old GitHub repository if you like, and remove `~/projects/waze-metroq` when you are satisfied.
