# Verification: air_quality, PM2.5 local pipeline, commit ddf1322

Independent verifier (general-purpose subagent following `.claude/agents/verifier.md`), run in its own checkout `.claude/worktrees/verify-ddf1322` on 2026-09-24. It received the SHA, the RUNBOOK steps (setup, 1, 2, 3), the reference folder and the list of tables. It did not receive the maker's comparison results. Its report follows as returned, apart from formatting.

## Verdict

PASS WITH NOTES. On commit ddf1322, every table the PM2.5 run writes matches the frozen reference. Seven differ only by numerical noise of 3e-14 or less, the other two are byte-identical, and every conformal and permutation p-value matches exactly. The notes cover code practices, not replication failures.

## What you ran

- **Checkout:** `/home/leonelb/projects/quito-metro-eval/.claude/worktrees/verify-ddf1322`. `git rev-parse HEAD` returns `ddf13226f6ec183b0e7b8e59e15dc2a88889741c`, and the working tree was clean before the run.
- **Inputs:** `data/raw` and `data/for_maps` are the committed symlinks into `/home/leonelb/data/quito-metro-eval/air_quality/raw/data/`. The sha256 of all 11 REMMAQ inputs read by `01` (PM2.5, CO, NO2, SO2, TMP, HUM, VEL, DIR, LLU, RS, PRE .xlsx) matches `MANIFEST.sha256`. The 11 reference files compared also match the manifest.
- **Cleaning:** deleted every file under `data/processed/` (it did not exist) and under `output/local/{tables,figures,crosssample,spatial_placebo,diagnostics}` before running. `output/local/blackout_comparison/` was not on the list, and no script writes it, so it was left alone.
- **Steps**, all run from `air_quality/` with logs in `logs/` at the checkout root:

| Step | Command | Wall clock | Exit | Warnings |
|---|---|---|---|---|
| 0. Setup | renv restore with `RENV_CONFIG_INSTALL_REMOTES=FALSE` and the resolute repository override, then `mkdir -p` | 20 s | 0 | renv 1.2.2 bootstrapped itself by download; system packages libicu-dev and libx11-dev reported missing (not needed) |
| 1. Hourly panel | `01_read_and_merge.R` | 86 s | 0 | "50 or more warnings". A rerun with `options(warn=1)` shows all are readxl "Expecting numeric ... got 'NA'" (literal `NA` text in numeric cells). Harmless; the rerun output was byte-identical. |
| 2. Weekly panels | `02_build_weekly_panels.R` | 8 s | 0 | none |
| 3. PM2.5 | `03`, `04_PM2.5.R`, `04_PM2_5_crosssample.R`, `04b`, `04c`, `fig_pm25_eventstudy_pub.R` in one session | 3,319 s (55 min 19 s) | 0 | two ggplot "Removed 53 rows ... geom_ribbon" warnings from the figure script |

- **Step 3 breakdown** (approximate, from file times): `04_PM2.5.R` about 10 min, the cross-sample script about 31 min, `04b` about 7 min, `04c` plus the figure about 7 min.
- **Package versions:** augsynth 0.2.0 (65c5a6f), synthdid 0.0.9 (70c1ce3), fixest 0.14.1, dplyr 1.2.1, readr 2.2.0.
- **Stray file:** the scripts left an untracked `air_quality/Rplots.pdf`, from the default graphics device.
- **Built-in checks in the cross-sample script:** (a) the pre_blackout AugSynth ATT equals the full-sample weekly ATT over P1, largest difference 0; (b) the AugSynth pre-period RMSPE spread across samples is 0; (c) the full-sample M5b and M8b ATTs tie out to `04_PM2.5.R`, difference 0.

### My numbers, recorded before opening the reference

From `logs/my_numbers_crosssample.txt` and `logs/my_numbers_spatial.txt` in the verifier's checkout.

**CrossSample_Summary_PM25.csv** (att_log / p_2s):

| Spec | pre_blackout | donut | full |
|---|---|---|---|
| M5b | -0.09998357 / 0.011 | -0.10647032 / 0.020 | -0.14327277 / 0.003 |
| M8b | -0.13011202 / 0.011 | -0.13240574 / 0.041 | -0.16413808 / 0.006 |
| M2b (SDID, permutation, n_placebo 7, smallest attainable p = 1/8 = 0.125) | -0.15684231 / 0.375 | -0.15428346 / 0.250 | -0.23244701 / 0.125 |

**Centro rows of the spatial placebo files:**

| File | Sample | att_log | conf_p | Rank | Spatial-placebo p |
|---|---|---|---|---|---|
| M8b | pre_blackout | -0.13011202 | 0.012 | 1/8 | 0.125 |
| M8b | donut | -0.13511273 | 0.031 | 1/8 | 0.125 |
| M5b | pre_blackout | -0.09998357 | 0.003 | 2/8 | 0.250 |
| M5b | donut | -0.10899248 | 0.017 | 2/8 | 0.250 |

The smallest attainable spatial-placebo p is 0.125, since N = 8.

## Comparison table

- **Reference:** `/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29/`.
- **Method:** cell by cell (`logs/compare.py`, output in `logs/compare_out.txt`, both in the verifier's checkout).
- **Result:** column names and order match in every file. Missing-value patterns match. Every text cell matches, including the donor-weight strings. Every p-value column (p_1s, p_2s, conf_p, p_val) matches exactly.

| File | Rows x cols compared | Largest abs. difference | Class |
|---|---|---|---|
| data/processed/hourly_panel.csv | 195024 x 94 | 0 (byte-identical) | identical |
| data/processed/pm25_completepanel_peakweekly.csv | 928 x 26 | 2.8e-14 (dir_imp) | noise |
| tables/results_PM25.csv | 12 x 24 | 1.0e-16 (se) | noise |
| tables/donor_weights_PM25.csv | 75 x 5 | 0 (byte-identical) | identical |
| tables/trajectories_PM25.csv | 1336 x 9 | 0 (byte-identical) | identical |
| tables/att_weekly_PM25.csv | 928 x 10 | 0 (byte-identical) | identical |
| crosssample/CrossSample_Summary_PM25.csv | 36 x 19 | 9.7e-17 (ci_hi) | noise |
| spatial_placebo/spatial_placebo_PM25_M8b_conformalp.csv | 16 x 14 | 1.2e-14 (att_pct) | noise |
| spatial_placebo/spatial_placebo_PM25_M5b_conformalp.csv | 16 x 13 | 1.1e-14 (att_pct) | noise |
| spatial_placebo/..._M8b_conformalp_log.txt | 11 lines | text identical; only the line endings differ (the reference uses CRLF) | identical |
| spatial_placebo/..._M5b_conformalp_log.txt | 10 lines | text identical; only the line endings differ (the reference uses CRLF) | identical |

Every value written down in step 5 equals the reference exactly. Every file on the list was produced by the run and exists in the reference.

## Unsupported claims

There is no maker's report for this check, so there is nothing to list. Nothing under `reports/` was opened.

## Rule violations

None of these is a replication failure. The first three are rule issues; the last three are observations for `docs/known_issues.md`.

1. **Sliced windows in a reported table.** The `att_clean_*`, `att_p1_*`, `att_p2_*` and `att_blackout_*` columns of `results_PM25.csv` are means of the full-panel weekly ATT vector, not separate estimates (`air_quality/code/local/04_PM2.5.R:57-61`). This is the legacy practice that `air_quality/CLAUDE.md` item 6 already flags. The per-window estimates in `CrossSample_Summary_PM25.csv` do not have this problem.
2. **A Wald interval without a "not used" flag.** `results_PM25.csv` carries SDID `se`, `ci_lo` and `ci_hi`, a Wald interval (att ± 1.96·se), with no label (`04_PM2.5.R:205,252-253`). The cross-sample file labels the same interval `ci_type = "wald_se_NOT_USED_in_analysis"`. No `pnorm` or Wald p-value is computed anywhere in the PM2.5 scripts; the p-values are conformal (AugSynth) or rank permutation (SDID).
3. **Smallest attainable p is missing from one table.** `results_PM25.csv` has no `n_placebo` column, so it does not state the smallest attainable p-value next to its SDID permutation p-values. `CrossSample_Summary_PM25.csv` does: n_placebo is 6 or 7, so the floor is 1/7 or 1/8.
4. **Conformal p-values depend on the seed and call order.** augsynth's conformal inference defaults to `type = "iid"` with `ns = 1000` random permutations (`augsynth:::conformal_inf`), and the synthdid placebo standard error uses 300 random replications. All of this is seeded: `set.seed(12345)` is called in `03`, the cross-sample script, `04b` and `04c`. `04_PM2.5.R` has no seed of its own and relies on the seed from `03` in the same session. The results therefore reproduce only in this exact order, and the same test gives different p-values in different scripts. For Centro M5b pre_blackout, with an identical ATT of -0.09998357, the conformal p is 0.011 in CrossSample and 0.003 in the spatial placebo file. For Centro M8b pre_blackout it is 0.011 against 0.012.
5. **One-sided conformal p-values of exactly 0.** 7 of the 24 AugSynth rows in `CrossSample_Summary_PM25.csv`, and 2 of the 8 AugSynth rows in `results_PM25.csv`, have `p_1s = 0`. A valid permutation p-value cannot be 0.
6. **Nothing else found.** No script writes into `raw/` or `frozen_*`. All outputs go to `here::here()` paths inside the checkout. Loading post-opening air quality outcomes to re-run approved specifications is allowed under root rule 5.

## What you could not check

- **Figures:** `event_study_PM25_{M5b,M8b,M2b}.png` and `fig_pm25_eventstudy.{png,pdf}` were not compared: they were not on the list, and PNGs are not byte-reproducible. The three event-study PNGs do differ in bytes from the committed versions.
- **Unrun steps:** sections 4 to 7 (gases, diagnostics, cross-pollutant master and the map) were not run, as instructed. The CO, NO2 and SO2 weekly panels that step 2 wrote were not compared.
- **Maker's report:** none exists for this check.
- **Checkout state:** the deletions of tracked output files remain in the verifier's checkout as unstaged changes. No commits and no code changes were made.

## Caller's note

The caller checked notes 4 and 5 against the code and the frozen files: `augsynth:::conformal_inf` defaults to `type = "iid"` and `ns = 1000`; `04_PM2.5.R` has no `set.seed`; and the frozen `CrossSample_Summary_PM25.csv` and `results_PM25.csv` have `p_1s = 0` in 7 of 24 and 2 of 8 AugSynth rows. Notes 1 to 5 are recorded in `docs/known_issues.md`. The verdict's count ("seven differ only by numerical noise ... the other two are byte-identical") does not match the comparison table, which shows 5 files at noise level, 4 byte-identical and 2 logs identical apart from line endings. The table is the detailed record.
