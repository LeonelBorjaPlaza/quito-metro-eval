# air_quality module

Effect of Quito Metro Line 1 (opened December 1, 2023) on air pollution, for the paper "Underground Relief". Two designs:

- **Local**: weekly peak-hour pollution at eight REMMAQ monitors, with augmented synthetic control (preferred) and synthetic difference-in-differences (robustness). Code in `code/local/`. Runs in WSL.
- **Citywide satellite**: AOD and gases for Quito against Latin American cities, with synthetic difference-in-differences. Code in `code/satellite/`. Runs on the Google Cloud VM, whose copy of the code (`~/v4_2026_05/code/`) is authoritative. Nothing on the satellite side runs here.

## State

Frozen at the May 31, 2026 draft (last source commit `64eb72a`, 2026-05-29, plus the uncommitted cross-sample and spatial placebo scripts captured in commit `033f40e`). The revision that answers the Secretaría de Ambiente is workstream A (`docs/STATUS.md`).

- Frozen derived data and outputs, the answer keys for any "what changed" table: `/home/leonelb/data/quito-metro-eval/air_quality/frozen_2026-05-29/` (`data/processed/`, `output/`, and `.RData`). Read-only.
- Raw inputs: `data/raw` and `data/for_maps` are committed symlinks into `/home/leonelb/data/quito-metro-eval/air_quality/raw/`. Read-only.
- The Secretaría's PM2.5 gap-fill file is stored in `.../air_quality/raw/2026-09-07_secretaria_ambiente_pm25_gapfill/` and is deliberately **not** linked here or merged into any panel. Workstream A decides how to use it.
- Replication of the frozen tables in WSL: `reports/migration/06_replication_gate.md`.

## How to run

`RUNBOOK.md` gives the setup step for a fresh worktree and the run order from raw data to every local table. `ENVIRONMENT.md` records R, the renv restore command and package versions. Work from `air_quality/`; `here::here()` resolves there through `.here`.

## Locked decisions

Each one was checked against the code and the paper text (`congestion/docs/paper/Underground-relief.txt`, extracted from the May 31 PDF) on 2026-09-24. Items marked UNCONFIRMED or CORRECTED need Leonel's confirmation before anyone relies on the original wording.

1. **Treatment date** December 1, 2023, ISO week 2023w48 in the weekly panels. Confirmed: `code/local/02_build_weekly_panels.R:429-436` and `03_analysis_setupPM2.5.R:35,75-78`.
2. **Local estimator**: augmented synthetic control with ridge augmentation and unit fixed effects (`progfunc = "Ridge", scm = TRUE, fixedeff = TRUE`), with two-sided conformal inference. Confirmed: `04_PM2_5_crosssample.R:96-121`.
3. **Preferred specification M8b**: Centro treated, Belisario in the donor pool. Confirmed: `04_PM2_5_crosssample.R:166`, the publication figure `fig_pm25_eventstudy_pub.R`, and paper Table A.3 note ‡.
4. **Main-text sequence**, CORRECTED. Paper Table 5 has four columns: M7 (Centro and Belisario co-treated), **M9 (Belisario treated, Centro excluded)**, M8 (Centro treated, Belisario excluded) and M8b. The note said "M7, M8, M8b".
5. **Appendix**, partly CORRECTED. Table A.3 reports the full battery: M2b (SDID) without p-values, but **M5b with conformal p-values**. The note said M2b and M5b appear without p-values.
6. **Three samples, each estimated separately**: pre_blackout, donut and full. Confirmed: `04_PM2_5_crosssample.R:61-78` (and the same for CO, NO2 and SO2). Never slice a longer window's weekly effects instead; `04_PM2.5.R` does that in its legacy sub-period columns, and the cross-sample scripts replaced it.
7. **Donut window**, CORRECTED. In the cross-sample tables and in the paper (Table 5, Panel B: "excluding Sept. 16 to Dec. 16, 2024"), the donut drops the 14 weeks flagged as Phase 3 blackout or wildfire weeks: the weeks starting 2024-09-16 through 2024-12-16. The weeks starting December 23 and 30 stay in. The note's "September 16 to December 30" matches only the spatial placebo scripts `04b` and `04c`, which drop every week between `BLACKOUT_START` (2024-09-15) and `BLACKOUT_END` (2024-12-31), 16 weeks. See `docs/known_issues.md`.
8. **SDID Wald intervals** are computed but flagged as not used: `ci_type = "wald_se_NOT_USED_in_analysis"` (`04_PM2_5_crosssample.R:139-146,194`). Local SDID enters no main table and has no p-values in the paper (Table A.3, Panel A). Confirmed.
9. **Satellite design**: SDID with a Mahalanobis-ranked Latin American donor pool (`rank_extended`, `code/satellite/cloud_R/00_helpers.R:24,118-127`) and AOD as the primary outcome (paper section 5.4). Confirmed in the OneDrive copy of the code. **UNCONFIRMED: "rank-based two-sided permutation p-values".** The OneDrive copy computes Wald p-values from placebo standard errors with `pnorm` as `p_2s`, and the rank permutation p-value only as an extra diagnostic (`00_helpers.R:29,491-553,591-593`). The paper text reports Wald p-values as primary and permutation p-values as a secondary appendix check (lines 549-556, 836-846, 882-888). The VM copy of `00_helpers.R` differs and was not reachable. Augmented synthetic control as support: not checked.
10. **Peak hours**: 7, 8, 9, 17, 18 and 19 on weekdays. Confirmed: `02_build_weekly_panels.R:59-61`.
11. **Local pre-period** from December 1, 2022: `02_build_weekly_panels.R:96`. The weekly panels start in the week of 2022-11-28 and have 52 pre-treatment weeks (checked in the frozen PM2.5 and CO panels). Confirmed.

## Rules specific to this module

- Keep the structure, including the standalone per-pollutant scripts (root rule 8). Re-running approved specifications is allowed. A new specification, window, donor rule or data source needs Leonel's approval first (root rule 5).
- Any change to the data, such as the PM2.5 gap fill, is compared against `frozen_2026-05-29/` with an old-versus-new table for every specification and sample.
- Seeds: every setup, cross-sample and placebo script calls `set.seed(12345)`. Do not remove them.

## Known issues

See the `air_quality` section of `docs/known_issues.md`. The ones that matter most for workstream A: the seven-week PM2.5 gap from the week of 2025-01-13 to the week of 2025-02-24; the two donut definitions; satellite Wald p-values against root rule 6; the CO, NO2 and SO2 cross-sample scripts not yet verified like PM2.5; and outputs in the frozen folder that no script produces.
