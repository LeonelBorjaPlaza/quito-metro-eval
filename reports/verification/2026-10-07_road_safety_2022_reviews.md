# Corrected Stage B execution and reviews

## Scope and execution

The user's direct instruction restores the January 2022 primary start and adds
only the requested descriptive pedestrian event figure and inner-band typology
and severity models. The original January 2021 results are read from their
committed table, not refitted. The correction record reproduces the full table
that had already been seen.

Script 39's initial maker execution completed the original Stage B models,
the requested event models and the estimable typology models. It stopped before
fitting VOLCAMIENTO, whose unchanged model could not have a finite common-post
coefficient. Leonel then explicitly authorized keeping its row as Not estimable,
with the explanation "too few events to fit", and finishing only severity.

Script 40 ran only the remaining severity models. It checked that the earlier
fit objects, paired-start table, event figures, full-precision main estimates,
event data and saved panels were unchanged. Evidence remains local in
`road_safety/data/derived/amendment4_stage_b_2022/continuation_checks.csv` and
`continuation_unchanged_checks.csv`. No completed maker fit was rerun. The only
continuation warning concerned sandbox `timedatectl` access during session-info
capture. Both event figures were opened and visually inspected.

## Independent preexecution reviews

The `code-reviewer` passed the January 2022 script, historical-plan preservation,
frozen geography, separate window construction, specified finite-cluster
Student-t intervals, reused 2021 sensitivity table, reused ATROPELLO fit and
disclosure rules. Its sole initial wording finding, alphabetical secondary
suppression, was corrected before execution.

The `methods-referee` passed the correction's retrospective transparency and
the requested specification scope. Before execution it also confirmed that
automatic omission of a descriptive category's all-zero outcome month is
the specified PPML separation handling, not a model change. The code allows
only that case for descriptive models; primary/event gates stay unchanged.

After Leonel's continuation instruction, the `code-reviewer` passed script 40
and the shared unchanged estimation functions. It confirmed that the continuation
loads cached state, requires the severity fits to be absent, fits only those
outcomes and checks completed fits and outputs for equality. All code reviews
were read-only and executed no raw-data fits.

## Final methods and claims reviews

The `methods-referee` passed the completed note and results with no required
changes. It checked the corrected interval, start-date sensitivity, descriptive
labels, pre-opening patterns, reporting and spatial-dependence caveats, and the
authorized unavailable row. It confirmed that the note avoids causal certainty
and does not interpret zero-containing intervals as evidence of no effect.

The `claims-auditor` passed Part 1 with no required changes. It traced every
number in the note and paired table to saved full-precision outputs, independently
recomputed descriptive intervals from saved model objects without refitting,
confirmed the original sensitivity table's hash and all reused columns, and
checked event support suppression against the local panels. It checked that the
affected plotted point and interval were removed and the line interrupted.
It verified current file hashes against the continuation's before/after hashes.
Public tables contain model effects and unit/month diagnostics, not crash counts,
count means or fixed effects. This pass does not clear historical releases.

The independent committed-SHA verification passed with notes on `7fac48b`:
every requested result matched exactly. See `2026-10-07_road_safety_7fac48b.md`.
