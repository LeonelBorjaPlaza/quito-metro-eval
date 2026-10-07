# Handoff

Where the project stands, for whoever picks it up next (person or agent). Updated 2026-10-07. Rules: `CLAUDE.md`. Decisions: `DECISIONS.md`. Workstreams: `docs/STATUS.md`. Open problems: `docs/known_issues.md`.

## Air quality revision (workstream A): round closed 2026-10-07

**State.**
- **Re-estimation.** The local analysis is re-estimated on the 2026-10-04 REMMAQ delivery (main specification B3, sensitivities S1-S4, diagnostics, check d, ridership test). Each step was verified on a committed SHA and claims-audited.
- **Paper.** Not edited. Leonel edits it by hand from the change list.
- **Satellite part.** Not revised in this round.

**What Leonel uses to edit the paper.**
- **Change list:** `reports/air_quality/2026-10-06_paper_change_list.md`. Every change, by line in `congestion/docs/paper/Underground-relief.txt`, with current text, proposed text, reason and status.
- **Tables and figures to replace:** `air_quality/output/local/paper/`:
  - tables: `table1`, `table3`, `table5`, `table6`, `table7`, `tableA1`, `tableA3` (`.tex`, with `.csv` beside each);
  - figures: `figure2`, `figure5` (`.png`, `.pdf`).
  - `tables_preview.md` shows them all with the editorial notes.
- **Rebuilding.** The tables come from `air_quality/code/local/step2/paper_tables.py`, which reads committed outputs only and checks the frozen build against the printed paper.

**Main results on the new data** (M8b PM2.5, Centro). Iid conformal p-values have smallest nonzero value 0.001; block p-values have smallest value 1/T.

| Window | Estimate | iid p | Block p |
|---|---|---|---|
| Pre-disruption | -12.2 percent | 0.016 | 0.011, its floor 1/94 |
| Donut | -13.7 percent | 0.199 | 0.242 |
| Full | -15.6 percent | 0.097 | 0.291 |

- **Belisario placebo** without Centro in its donor pool: -6.1 percent (p 0.740).
- **Ridership test:** does not support the mechanism (Spearman +0.256; p 0.667 and 0.438).

**Open.**
1. Items 4 (Table 5 note) and 5 (Tumbaco sentence) of the change list: proposed, awaiting Leonel. Wording to confirm for the Los Chillos sentence and the Figure 2 caption sentence (approved in principle).
2. Refine-dependent text (G1, G4, D3-D8): `reports/air_quality/refine_response_draft.md`.
3. The satellite part, deferred, including the four-week blocks, not checked on the VM.
4. Emails Leonel sends himself (`DECISIONS.md`, 2026-10-07):
   - to the Secretaría, four questions;
   - to Metro de Quito, one question.
5. Data issues in `docs/known_issues.md`:
   - suspected Centro NO2 analyzer fault, mid-June to July 2025 and March to mid-May 2026 (do not cite the S1 NO2 result);
   - SO2 and CO hours added between vintages;
   - Los Chillos PM2.5 timing from late 2024;
   - Metro de Quito station-label swaps.
6. Not computed and not run without Leonel's approval: block p-values for Table A.3 Panel B and the Table 6 placebos.

**Where things are.**
- Code: `air_quality/code/local/step2/`; run order in `air_quality/RUNBOOK.md`.
- Outputs: `air_quality/output/local/` (`step2/`, `crosssample/`, `sensitivity/`, `spatial_placebo/`, `paper/`).
- Reports: `reports/air_quality/`; verifications: `reports/verification/`.
- Raw data through committed symlinks: `air_quality/data/remmaq_2026-10-04`, `air_quality/data/metro_validaciones_2026-10-05`.

## Other workstreams

- **B. Congestion:** stopped on 2026-10-01 before any post-opening month (see `main` and `docs/STATUS.md`).
- **C. Road safety:** in progress in the `road-safety-plan` worktree; not merged.
