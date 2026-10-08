# Road safety clean release

This branch starts at the user-specified `ddde0a8`, before the road-safety squash.
Main remains unchanged at `4abdbe8`. All preparation and commits are local; no
merge or push has been performed.

The current [result note](../../reports/road_safety/2026-10-07_amendment4_stage_b_2022.md)
and its linked artifacts contain the authorized corrected Stage B results.
The original start remains beside the corrected start as the sensitivity.
Independent reproduction passed on maker commit `7fac48b`; result reviews were
recorded at `c05df02`. The original Stage B reproduction passed on `b3273b8`.
The verification records are retained in `reports/verification/`.

## Included and excluded content

This tree includes source code, plans and amendments, provenance, public frozen
geography, reviewed Stage B artifacts and their execution/review records. The
historical crash-derived count tables, descriptive figures, logs, power outputs,
exploratory outputs and earlier reports are excluded. Historical references in
plans and the RUNBOOK identify records retained locally; they are not an
instruction to publish or regenerate those files.

The [main release inventory](../../reports/verification/2026-10-07_road_safety_main_release_audit.md)
defines the previously identified failures. The expressly requested exceptions
to excluding inventoried paths are redacted versions of
`road_safety/docs/analysis_plan.md`, `docs/known_issues.md`, and
`docs/data_provenance/road_safety__2026-09-23_amt_siniestros.md`. Their protected
counts, reconstructible means and linked margins are removed. Amendment 1,
module instructions, correspondence and source comments were also redacted as
needed without changing executable outcome definitions. The non-road-safety
known-issue sections and status rows remain as in the baseline.

Outputs and road-safety reports are ignored by default. Only individually listed
files in `release_allowlist.json` have explicit ignore exceptions. Before each
release commit run `python3 scripts/check_road_safety_release.py --index` from
the repository root, then `--tree HEAD` after committing. The gate checks the
actual staged or committed tree, forbidden paths, raw-data symlinks and ignored
future-file probes. Ignore rules alone do not remove already tracked files.
These checks are not semantic small-count certification. The complete retained
tree passed the claims-auditor's review, including linked disclosures, after the
final historical-plan redaction. See the [claims audit](../../reports/verification/2026-10-07_road_safety_clean_release_claims.md).
Future additions still need that review before their inclusion in the allowlist.

## History limitation

Compliance review concerns the new current tree only. The requested baseline
`ddde0a8` and its ancestors already contain protected AMT provenance and
known-issue prose. This branch redacts their current versions but retains that
history. Repointing main to this branch is therefore not a purge of historical
disclosures. No ancestor rewrite or deletion of local backup history is included.

The proposed replacement uses a single reviewed snapshot directly on `ddde0a8`.
Preparation checkpoints are preserved only on the local
`road-safety-clean-release-checkpoints` branch, so their draft content is not
included in the replacement ancestry.
