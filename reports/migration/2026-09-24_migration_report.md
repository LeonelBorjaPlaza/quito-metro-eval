# Consolidation of the Quito Metro evaluation: migration report

2026-09-24. Prompt: `docs/prompts/01_consolidate.md`. Detailed notes per phase are in `reports/migration/`.

## Result

`~/projects/quito-metro-eval` now holds the three modules (`air_quality/`, `congestion/`, `road_safety/`) with the full git history of both old repositories and no data files added to git. Raw inputs sit once, locked, in `~/data/quito-metro-eval/<module>/raw/`, and each module reaches them through committed symlinks. The old derived data and outputs sit, locked, in `frozen_2026-05-29` (air quality) and `frozen_2026-09-17` (congestion). Both new deliveries are stored with provenance notes checked against the files. WSL R runs the whole air quality local pipeline, augsynth and synthdid included. **Replication gate: PASS WITH NOTES.** All 39 frozen tables were regenerated from raw data in a clean checkout: 25 identical, 14 within 2.8e-14, and every p-value exact. An independent verifier re-ran PM2.5 in its own checkout, without seeing these results, and also returned PASS WITH NOTES. The Claude Code rules, five agents and permissions are in place. **The GitHub push did not happen:** the congestion history contains `reports/waze_sample.csv`, 500 raw Waze records, and removing it is Leonel's decision. Both source folders are exactly as they were.

## What is where

```
~/projects/quito-metro-eval/                 git, branch main
├── CLAUDE.md, AGENTS.md -> CLAUDE.md        repository rules
├── .claude/agents/ (5), settings.json       agents and permissions; worktrees/ ignored
├── air_quality/                             imported from quito-metro-airquality-2026 (history kept)
│   ├── code/local/, code/satellite/         local pipeline (runs in WSL), satellite (runs on the VM)
│   ├── data/raw -> store, data/for_maps -> store, data/working/ (tracked), data/processed/ (rebuilt, ignored)
│   ├── output/                              tracked tables and figures
│   └── CLAUDE.md, RUNBOOK.md, ENVIRONMENT.md, renv.lock, .here
├── congestion/                              imported from waze-metroq (history kept)
│   ├── Scripts/Congestion/, docs/, reports/, Output/Waze/
│   ├── Data/Waze/raw -> store, Data/spatial -> store, Data/Waze/parquet/ (rebuilt, ignored)
│   └── AGENTS.md, CLAUDE.md
├── road_safety/                             new: README.md, CLAUDE.md, data/raw -> store
├── docs/                                    STATUS, known_issues, data_provenance, correspondence, plan, prompts
├── reports/                                 migration/, verification/
└── scripts/                                 add_raw_delivery.sh, backup_store_to_onedrive.sh

~/data/quito-metro-eval/                     outside git; everything below raw/ and frozen_*/ is read-only
├── MANIFEST.sha256                          1,083 files
├── air_quality/raw/                         data/raw (REMMAQ, satellite exports, GHS-UCDB), data/for_maps,
│                                            data/processed/satellite/*.dta, data/working raw CSVs,
│                                            2026-09-07_secretaria_ambiente_pm25_gapfill/
├── air_quality/frozen_2026-05-29/           data/processed, output, .RData (872 files, 3.1 GB)
├── congestion/raw/                          Data/Waze/raw (6.2 GB), Data/spatial, docs/paper
├── congestion/frozen_2026-09-17/            Data/Waze/parquet, Output/Waze, reports (48 files)
└── road_safety/raw/2026-09-23_amt_siniestros/
```

## Phase by phase

| Phase | Status | Evidence |
|---|---|---|
| 0. Preflight | done | `00_preflight.md`: all paths exist, 241 GB free on C:, the ten largest OneDrive files hashed from disk, both Excel sha256 match |
| 1. New repository | done | commit `b5d6dc4` |
| 2. Code with history | done; satellite VM snapshot skipped (`GCP_VM_SSH` empty) | subtree merges `a1cb963` and `dcea3c0`, uncommitted-work snapshot `033f40e`, `02_code_and_history.md` |
| 3. Data store and links | done | `03_data_store.md`, `03_data_map.csv`; 1,078 map copies and 4 deliveries verified by sha256; 5 symlinks; store locked |
| 4. Environment | done | `04_environment.md`, `air_quality/ENVIRONMENT.md`; all 67 lockfile packages at locked versions; DuckDB with h3 works for congestion |
| 5. Claude Code setup | done | `05_claude_setup.md`; commits `281d0e0`, `ddf1322` |
| 6. Replication gate | done: PASS WITH NOTES | `06_replication_gate.md`, `06_compare_*.csv`, verifier report in `reports/verification/` |
| 7. GitHub and report | partly done: push blocked | `07_history_data_files.csv`; sources unchanged; this report |

## Replication gate

- **Verdict: PASS WITH NOTES.** 39 tables compared: 25 identical, 14 at floating-point noise (largest 2.8e-14, in the imputed wind direction of the weekly panels; 1.2e-14 in the spatial placebo percent effects; 1.4e-17 in the unused SDID Wald bounds of `CrossSample_Summary_PM25.csv`). No small or material differences, every p-value exact, no missing or stale table, no orphan inputs. The hourly panel is byte-identical.
- Notes: six frozen outputs have no producing script and could not be regenerated; figures were not compared by content.
- Run time: 57 minutes from raw data, with the PM2.5 and gas blocks in parallel.
- Congestion smoke test: both deduplicated Parquet blocks are byte-identical to the frozen copies.
- Independent verifier (`reports/verification/2026-09-24_air_quality_ddf1322.md`): **PASS WITH NOTES** on commit `ddf1322`. It ran setup and steps 1 to 3 from raw data and produced all 11 PM2.5 files. By its table, 4 are byte-identical, 2 logs are identical apart from line endings, and 5 are within 2.8e-14. Every p-value matches exactly, and its blind-recorded numbers equal the reference. Its notes are about existing code, not the move: conformal p-values depend on seed and call order; 9 AugSynth rows have a one-sided p-value of exactly 0; and the legacy `results_*.csv` tables slice windows and carry an unlabeled SDID Wald interval.

## Sources unchanged

`reports/migration/gitstate.sh` was re-run on both sources at the end of Phase 6 and again just before the final commit. Its output (HEAD, branches, last 15 commits, remotes, unpushed commits, stashes, modified and untracked files, and every ignored file with its size) is byte-identical to the Phase 0 snapshots `00_gitstate_aq_src.txt` (11,608 lines) and `00_gitstate_waze_src.txt` (1,571 lines). Every git command against the sources used `--no-optional-locks`; the only other access was reading and copying files.

## Code edits

Only edits needed to run in the new home (commit `a091013`):

- `air_quality/code/local/05_analysis_setupCO.R:33`: `co_completepanel_peakweekly.csv` became `CO_completepanel_peakweekly.csv` (the file `02_build_weekly_panels.R:473` writes; the lower-case name only worked on Windows).
- `air_quality/code/local/fig1_metro_airquality_map.R:40`: the absolute OneDrive path became `here::here()`.
- Line endings: no script needed changing (git stores them with LF). CRLF was removed from the two output logs `air_quality/output/local/spatial_placebo/spatial_placebo_PM25_{M5b,M8b}_conformalp_log.txt` when they entered git (commit `033f40e`).
- Not code, but a change to the tracked tree: the four files tracked under `air_quality/data/raw/` were untracked when that folder became a symlink into the store (commit `2ebb0c0`). They stay in the history and in the store.

## Known issues added (`docs/known_issues.md`)

air_quality:

1. Two donut definitions: the cross-sample tables and the paper drop the 14 flagged weeks from 2024-09-16 to 2024-12-16, while `04b`/`04c` drop 16 weeks through the week of 2024-12-30.
2. Satellite p-values are Wald (`pnorm`) as primary in the OneDrive code and the paper, against root rule 6 and Leonel's notes.
3. The header of `02_build_weekly_panels.R` says event days are dropped; the code does not drop them.
4. `master.R` and the old README do not cover the cross-sample, spatial placebo and publication-figure scripts, and the README gives wrong output paths.
5. Six frozen outputs have no producing script.
6. The Figure 1 packages are not in `renv.lock`.
7. `01b_donor_pool_selection.py:32` has a case mismatch (`ghs_ucdb` against `GHS_UCDB`).
8. Correction: `ucdb_donor_distances_all.csv` does have a producer (`01b_donor_pool_selection.py:329`); the open problem is the path.
9. Status update on `read_remmaq()` and `df[-1,]`.
10. The CO case mismatch, now fixed.
11. From the verifier: conformal p-values depend on the seed and the call order (the model scripts inherit the setup script's seed).
12. From the verifier: 9 AugSynth rows have a one-sided conformal p-value of exactly 0.
13. From the verifier: the legacy `results_*.csv` tables slice sub-period effects, carry an unlabeled SDID Wald interval, and omit the smallest attainable p-value.

congestion:

1. `reports/waze_sample.csv` (raw records) is in the history.
2. AGENTS.md disagrees with plan v2 on ten points.
3. The Step 1 v2 prompt is missing.
4. The congestion library has no augsynth or synthdid.

road_safety:

1. The old copy of the crash matrix has English day names.

Decisions in Leonel's notes that the code or paper contradicts are listed in `air_quality/CLAUDE.md` and `05_claude_setup.md`: the donut window, the Table 5 sequence (M7, M9, M8, M8b), M5b p-values in the appendix, and the satellite p-values (unconfirmed).

## Pending for Leonel

1. **Decide on the raw Waze records in the congestion history, then push.** The push was not attempted. `reports/migration/07_history_data_files.csv` lists all 210 data-file paths in the history.
   - The blocker is `congestion/reports/waze_sample.csv` (committed in `16fbfa9`): 500 record-level rows of the Waze delivery, 196 KB.
   - For review, not blocking under the prompt's rule but outside output folders:
     - 22 copies of the air quality paper tables in `congestion/docs/paper/results/`;
     - the satellite donor tables and GHS-UCDB shapes in `air_quality/data/working/`;
     - `ecuador_blackouts_2024.xlsx` (news-compiled blackout dates).
   - The air quality items are already in your private GitHub repository `quito-metro-airquality-2026`.
   - No blob exceeds 50 MB; the largest is `congestion/Output/Waze/descriptives/cell_month_blocks.rds` at 14.8 MB.
   - To strip the sample before the first push (this rewrites every commit SHA from the congestion import on, so the SHAs cited in `reports/migration/` stop matching):
     ```bash
     pipx install git-filter-repo     # or: sudo apt-get install git-filter-repo
     cd ~/projects/quito-metro-eval
     git filter-repo --force --invert-paths --path reports/waze_sample.csv --path congestion/reports/waze_sample.csv
     echo "congestion/reports/waze_sample.csv" >> .gitignore && git add .gitignore && git commit -m "Keep the Waze review sample out of git"
     ```
   - Then push. Either create an empty private repository named `quito-metro-eval` on github.com, or run `gh repo create LeonelBorjaPlaza/quito-metro-eval --private`, and then:
     ```bash
     cd ~/projects/quito-metro-eval
     git remote add origin https://github.com/LeonelBorjaPlaza/quito-metro-eval.git
     git push -u origin main
     ```
2. **Back up the data store once** (WSL is not backed up): `cd ~/projects/quito-metro-eval && bash scripts/backup_store_to_onedrive.sh`. The store holds 12 GB (`du -sh`), 6.2 GB of it the Waze delivery.
3. **Smoke test of the new setup:** `cd ~/projects/quito-metro-eval && claude`, accept the trust dialog, run `/agents` to see the five agents, and ask "What are the hard rules in this repository?".
4. **Rule on the contradicted notes** in `air_quality/CLAUDE.md` (locked decisions 4, 5, 7 and 9):
   - Which donut definition is intended (the 14 flagged weeks in the tables, or the 16 weeks in `04b`/`04c`).
   - The Table 5 sequence (M7, M9, M8, M8b).
   - M5b p-values in the appendix.
   - Whether the satellite design reports Wald or rank permutation p-values (the OneDrive code and the paper use Wald, against root rule 6).
5. **Satellite VM snapshot**, skipped. Install gcloud (`sudo apt-get install google-cloud-cli`, after adding Google's apt repository) or use your usual ssh, set `GCP_VM_SSH` in `~/quito-metro-kit/settings.env`, then copy the code only, for example:
   ```bash
   cd ~/projects/quito-metro-eval && d=air_quality/code/satellite_vm_snapshot_$(date +%F) && mkdir -p $d
   $GCP_VM_SSH --command 'cd ~/v4_2026_05/code && tar -cf - $(find . -type f \( -name "*.R" -o -name "*.py" -o -name "*.sh" -o -name "*.md" -o -name "*.txt" -o -name "*.yml" -o -name "*.json" \))' | tar -xf - -C $d
   ```
   Add a README saying it is the authoritative VM copy, and diff it against `air_quality/code/satellite/` (`00_helpers.R` is known to differ).
6. **Congestion Step 1 v2 prompt**: it is in neither repository. Save it in `congestion/docs/` for workstream B.
7. **REMMAQ download** for the rest of the PM2.5 gap (hourly PM2.5, all stations, December 1, 2024 to March 31, 2025, or through the latest month), then add it with `scripts/add_raw_delivery.sh` in your own terminal.
8. **Old folders.** Once satisfied, rename or delete `~/projects/waze-metroq`. Keep the OneDrive folder `quito-metro-airquality-2026` as the frozen archive; nothing in it was changed. Its extra copies of the two deliveries are now stored in the dated delivery folders. Optionally archive the old GitHub repository: `gh repo archive LeonelBorjaPlaza/quito-metro-airquality-2026`.
9. **Stray local files:** `~/projects/quito-metro-eval/logs/` (ignored) holds the Phase 4 and gate logs, including the verifier's logs. Delete them when no longer needed.
