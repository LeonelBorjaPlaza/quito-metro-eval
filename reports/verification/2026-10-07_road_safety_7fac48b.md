# Independent verification: corrected January 2022 Stage B

**PASS WITH NOTES.** The independent verifier reproduced every requested result
at commit `7fac48b76b6705f5f70e2a65c052eaa3d6297741`. No numerical discrepancy or
unsupported reported result was found.

## What ran

Isolated checkout: `/tmp/road-safety-verification/.Codex/worktrees/verify-7fac48b`,
detached at that SHA. Corrected Stage B outputs were removed without reading
them; no derived data existed. Approved geography registries and the original
sensitivity table were preserved as fixed inputs. From `road_safety/`:

```bash
Rscript code/00_setup.R
Rscript code/39_amend4_stage_b_2022.R
```

Both commands completed successfully. The estimation run took 12.11 seconds
(`logs/verify_2022.log` in the verification checkout). The only warning was
unavailable system-bus access from `timedatectl`; there were no estimation
warnings or convergence failures. Neither the original 2021 models nor the
maker's severity-continuation script was rerun.

The verifier recorded its own outputs in `logs/own_numbers_before_reference/`
before comparing with the committed releases and the maker's ignored exact
outputs. It read the maker's note after those comparisons.

## Comparisons

All rows, columns, text fields and missing values were checked. Every numeric
difference was zero; integer fields matched exactly.

| File or quantity | Comparison |
|---|---|
| Paired-start `estimates.csv` | Identical |
| `descriptive_types_severity.csv` | Identical |
| `descriptive_types_severity.md` | Byte-identical |
| Both quarterly PNG figures | Byte-identical |
| Main, descriptive and event full-precision CSVs | Identical |
| Input hashes, coverage and category registries | Identical |
| All fit diagnostics | Identical objects |
| Panels and category-support objects | Identical objects |

Evidence: verification `logs/comparison.json` and
`logs/diagnostic_comparison.csv`. Independent recalculation of intervals,
contributing clusters, omissions and quarterly disclosure flags passed.
The earliest inner-band pedestrian point is correctly withheld. Both figures
were visually inspected. Evidence: `logs/own_fit_checks.csv` and
`logs/withheld_event_points.csv`.

The original sensitivity table's hash and all reused cells are unchanged.
ATROPELLO reuses the inner pedestrian fit. VOLCAMIENTO remains unavailable with
the authorized explanation. Omitted descriptive-category months have zero
outcomes across all original units.

## Claims, rules and limits

No unsupported claim was found in
`reports/road_safety/2026-10-07_amendment4_stage_b_2022.md`. Its rounded estimates,
intervals, severity statements and pre-opening descriptions match the independent
outputs. No rule violation was found. Raw sources resolve through committed
symlinks, match the store manifest and remained unchanged. Approved plan and
frozen-registry hashes passed. Model formulas and intervals match the authorized
specification. Released outputs contain no p-values, raw crash counts, support
values or fixed effects. No random step or unauthorized model was run.

The original sensitivity models and Stage A geography were not regenerated;
their frozen inputs were checked. This verifies the final pipeline and outputs,
not an independent reconstruction of the maker's interruption and continuation
history. Administrative timestamps and completion messages were not required
to match. Delivery-month presence does not prove exhaustive AMT reporting.
