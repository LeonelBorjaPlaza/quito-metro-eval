# Verification (light, no reruns): block p-value cells in the paper tables, commit f4735ce

Report of the `verifier` agent, 2026-10-06, saved by the maker (summary of the agent's report; the per-cell table is kept).

## Verdict

**PASS.** 72 block conformal p-value cells were checked, with 0 mismatches:
- Tables 5 and 7, and Table A.3 Panel C (bracketed);
- the CSV and the TeX version of each.

## Checks on every cell

- **Value.** The cell equals `p_block` in `air_quality/output/local/step2/diagnostics/block_conformal_{PM25,CO,NO2,SO2}.csv`, rounded to 3 decimals.
- **Same fit.** The block file's `att_log` equals the cross-sample `att_log` (largest difference 0). The table's log effect and iid p equal the cross-sample `att_log` and `p_2s`.
- **Multiple of 1/T.** Every `p_block` is a whole multiple of 1/n_weeks (n_weeks 94, 120 and 134). The floors in the notes (1/94 = 0.011, 1/120 = 0.008, 1/134 = 0.007) are right, and the notes also state the iid floor of 0.001.

## Provenance

- **Source files unchanged.** The block_conformal and CrossSample_Summary files were committed in `606ea82` and have not changed since. The clean re-run in `reports/verification/2026-10-05_air_quality_606ea82.md` reproduced them byte for byte.
- **Cell values unchanged since `088921e`.** The only table changes since then are the removed Panel B "[not computed]" rows and the † and ‡ markers in Table A.3.

| Pollutant | Spec | Window | Block p | k/T | iid p | log |
|---|---|---|---|---|---|---|
| PM2.5 | M7 | pre | 0.521 | 49/94 | 0.655 | -0.126 |
| PM2.5 | M7 | donut | 0.733 | 88/120 | 0.877 | -0.063 |
| PM2.5 | M7 | full | 0.776 | 104/134 | 0.922 | 0.028 |
| PM2.5 | M9 | pre | 0.691 | 65/94 | 0.737 | -0.063 |
| PM2.5 | M9 | donut | 0.775 | 93/120 | 0.863 | 0.013 |
| PM2.5 | M9 | full | 0.784 | 105/134 | 0.863 | 0.130 |
| PM2.5 | M8 | pre | 0.394 | 37/94 | 0.431 | -0.188 |
| PM2.5 | M8 | donut | 0.692 | 83/120 | 0.775 | -0.139 |
| PM2.5 | M8 | full | 0.493 | 66/134 | 0.767 | -0.074 |
| PM2.5 | M8b | pre | 0.011 | 1/94 | 0.016 | -0.131 |
| PM2.5 | M8b | donut | 0.242 | 29/120 | 0.199 | -0.147 |
| PM2.5 | M8b | full | 0.291 | 39/134 | 0.097 | -0.170 |
| CO | M8b | pre / donut / full | 1.000 | T/T | 1.000 | -0.057 / -0.076 / -0.103 |
| NO2 | M8b | pre / donut / full | 0.840 / 0.567 / 0.701 | 79/94, 68/120, 94/134 | 0.967 / 0.610 / 0.716 | -0.064 / -0.055 / -0.060 |
| SO2 | M8b | pre / donut / full | 0.340 / 0.333 / 0.410 | 32/94, 40/120, 55/134 | 0.248 / 0.120 / 0.249 | -0.053 / 0.095 / 0.070 |

## Notes (not errors)

1. **PM2.5 M8b pre-disruption.** Its block p is exactly the floor, 1/94.
2. **A second iid column.** The block_conformal files also carry `p_iid_reseeded` (for example 0.021 against the tables' 0.016 for PM2.5 M8b pre-disruption). The tables correctly use the cross-sample `p_2s` from the same fit. A reader opening the block files could be confused by it.

## Not checked

- The cyclic-shift calculation itself. It relies on the byte-identical reproduction in the 606ea82 verification.
- Manuscript wording outside the tables.
