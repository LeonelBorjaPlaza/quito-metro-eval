# Claims audit of the road safety clean release

**PASS for the current release tree.** The complete crash-related tree was
reviewed at `d5129f5`, and the sole required redaction was rechecked at
`5d5fc3016518a1bb1ceccbcbc266cc0bc8116218`. No remaining required redactions were
identified. Certification does not cover protected prose retained in the
user-specified baseline's history.

## Scope and evidence

The read-only `claims-auditor` reviewed retained plans, amendments, provenance,
known issues, module instructions, correspondence, inherited migration/planning
references, source comments and assertions, admitted tables and geometry schemas,
reviewed figures and linked release inputs. It distinguished crash counts from
geographic counts, estimator omissions, model coefficients and explicitly
rounded large counts. It did not run models or alter files.

| Check | Finding |
|---|---|
| Historical protected count tables, figures and reports | Excluded, with only the expressly requested redacted prose paths retained |
| Original plan, known issues and AMT provenance | Redacted; no remaining required corrections identified |
| Corrected Stage B outputs and note | Identical to the independently verified and claims-reviewed maker artifacts |
| Original sensitivity and frozen geography | Identical to their reviewed source artifacts |
| January 2022 correction and prior exposure | Correctly recorded, including the complete previously seen sensitivity table |
| Release path gate | PASS for allowlist, forbidden paths, symlinks and future-file ignore probes |
| Other modules and main | Unchanged |

The initial full-tree pass found an observed monthly count mean and a derived
Poisson-noise benchmark remaining in the original plan. Their protected-release
provenance was not established; exact small-count reconstruction was not
demonstrated. The clean branch redacted those numerical values and preserved
the qualitative methodological explanation. The auditor rechecked that only
this paragraph changed and reran the committed-tree gate before clearing it.

Evidence: `road_safety/docs/analysis_plan.md` at the audited revision,
`scripts/check_road_safety_release.py --tree HEAD`, the release allowlist, and
blob comparisons with verified maker commits `7fac48b`, `c05df02`, `b3273b8`
and geography commit `b0a6ea4`. No analysis code or result changed for this
redaction.

## History and proposed replacement

The release is based on `ddde0a8`, as requested. The final release snapshot is
to be committed directly on that baseline, preserving local draft checkpoints
on `road-safety-clean-release-checkpoints` rather than including them in the
proposed push. Neither the road-safety squash `4abdbe8` nor the draft checkpoint
commits should be ancestors of the replacement tip.

The baseline and its older ancestors already contain protected AMT provenance
and known-issue prose. The corrected current files and exclusion of the squash
do not purge that older history. Main replacement and force-push commands are
for Leonel to execute; no merge, reset of main or push was performed here.
