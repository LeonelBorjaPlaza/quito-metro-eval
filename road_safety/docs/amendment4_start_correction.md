# Amendment 4: correction of the primary pre-period start

**Approved directly by Leonel on 2026-10-07, after the first Stage B results were
seen.** This corrects a legitimate error in his Amendment 4 instructions; it is
not an outcome-driven choice of a new primary start or retrospective registration.

The [2026-09-27 decision record](../../docs/correspondence/2026-09-27_road_safety_design_decisions.md)
and section 5 of [the original analysis plan](analysis_plan.md) specify January
2022 as primary and January 2021 as a sensitivity. The rationale was to omit
the COVID-19 recovery and the October–December 2021 recording block. Amendment 4
erroneously specified January 2021. Its originally approved text is preserved
in [analysis_plan_amendment_4_original.md](analysis_plan_amendment_4_original.md).

## Results already seen before this correction

Leonel saw the complete initial Stage B table below, its all-crash quarterly
event study and its note before requesting the correction. The earlier P1 and
exploratory outputs had also been seen, as the original amendment states.
The initial Stage B run is committed at `b3273b8`; independent verification is
recorded at `9c3ef43`. These estimates remain the **2021-start sensitivity**.

| Model | Outcome | Ring | Estimate (%) | 95% interval (%) | Clusters | Omitted units |
|---|---|---|---:|---|---:|---:|
| Main primary | All crashes | 0–500 m | 19.043 | 4.194 to 36.008 | 97 | 0 |
| Main | All crashes | 500 m–1 km | 4.554 | −6.155 to 16.486 | 97 | 0 |
| Main | Pedestrian | 0–500 m | 72.519 | 24.189 to 139.657 | 87 | 10 |
| Main | Pedestrian | 500 m–1 km | 19.334 | −13.063 to 63.804 | 87 | 10 |
| Main plus valley | All crashes | 0–500 m | 14.460 | 0.864 to 29.888 | 181 | 87 |
| Beyond 2 km of line | All crashes | 0–500 m | 10.202 | −3.995 to 26.498 | 79 | 0 |
| Main, parish clustering | All crashes | 0–500 m | 19.043 | 3.413 to 37.035 | 32 | 0 |

Source: [original Stage B table](../output/amendment4_stage_b/estimates.csv),
SHA-256 `120e5304422d2fa40d47b0cdc3aa6b13f464860b9867744141dc723861d04e55`.
These are model effects and unit counts, not released crash counts.

## Authorized rerun and descriptive additions

Refit the original Stage B specifications on January 2022–August 2026, leaving
the post-opening period, frozen geography, outcomes, fixed effects, separation
handling and finite-cluster Student-t intervals unchanged. Reuse the committed
2021-start table without refitting it. Add only the pedestrian quarterly figure
and the requested typology/severity table for the corrected window. The existing
ATROPELLO inner-ring estimate is reused in that table, not fitted a second time.
Each other recorded typology is a separate crash indicator. Severity indicators
are SEVERIDAD = DAÑOS MATERIALES and SEVERIDAD in {LESIONADOS, FALLECIDOS}; the
existing homicide exclusion applies throughout. No typologies are merged or
redefined. These additions are descriptive with pointwise intervals.

All new raw records, count panels, model objects, support checks and exact
diagnostics remain ignored locally. Released model effects have rounded display
precision and contain no counts, count means or fixed effects. Before releasing
a descriptive category, check its total and its complement among all crashes
in each treated/comparison by pre/post cell. Withhold the category's estimate
and interval if a positive cell or complement is below five. If exactly one
typology is withheld, withhold the first remaining typology in alphabetical order as a
linked-margin precaution. Do not remove its row or combine categories. If the
unchanged model is not estimable, retain a labelled unavailable row and stop
for Leonel before any model change. Apply the same support/complement checks
to pedestrian event-study treated/comparison quarters, withholding affected
quarterly points and intervals if required. Such disclosure suppression changes
neither the estimation sample nor the model. Separation omissions remain the
approved estimator's perfect-fit handling, not a volume screen. For the new
descriptive categories, a month with zero outcome counts across all units has
a separated month fixed effect. Its automatic removal does not change the
finite treatment coefficient in the specified PPML model. Record these omitted
months locally and in the descriptive table; stop if an omitted month has any
positive original outcome count. Primary and event-study month checks remain
unchanged. This implementation rule was reviewed before the corrected run.

Execution: write and review the corrected code; run the authorized specifications;
update the requested outputs and note; commit; independently verify from raw on
the committed SHA; methods and claims reviews; commit the review record locally.
Do not merge, push, run power calculations, simulations, placebos or other models.

## Authorized continuation after the descriptive stop

The corrected main models, event figures and estimable typology models completed
before the run stopped at VOLCAMIENTO. Leonel then explicitly instructed: keep
VOLCAMIENTO as **Not estimable**, with the table note **too few events to fit**;
finish only the remaining severity fits; do not change the model or rerun any
completed fit. Script 40 implements that continuation from the saved local
panels and models, checking that prior fitted objects and outputs stay unchanged.
For independent reproduction in a fresh checkout, script 39 incorporates the
same unavailable row and proceeds to severity without stopping there again.
