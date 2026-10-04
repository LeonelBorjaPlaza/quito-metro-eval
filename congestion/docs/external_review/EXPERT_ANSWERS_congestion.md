# Outside expert answers: congestion design

Answers to EXPERT_PROMPT_congestion.md, saved verbatim as received, for side-by-side assessment once all models have answered. Link labels in the original (for example "Quito Informa" or "arxiv.org") came without their addresses.

## Answer 1: Astra 6 ultra (received October 1, 2026)

The design is promising as supporting mechanism evidence, but I would not freeze it as confirmatory yet. The main obstacles are unstable counterfactual prediction, uncertain Waze observation, and differences in policy exposure between CENTER and its donors. Interpolation is a warning about flexibility, but the internal review overstates its implications for conformal inference. My preferred primary candidate is a simpler, intercept-adjusted, nonnegative synthetic control using geographically comparable donor aggregates, conditional on passing explicit measurement and forecasting requirements.

**1. Establish what the outcome actually measures.**

Problem. Weighting whole-cell congestion indices by road length inside CENTER does not generally produce the congestion index of the district's streets. Boundary cells still contribute congestion measured outside the polygon. Moreover, no Waze record does not establish free flow.

Action and rationale. Request congestion numerators clipped to the polygon, with matching road denominators. Otherwise, label the outcome an overlap-weighted H3 congestion index. Request independent measures of probe activity and feed completeness. Without them, interpret the outcome as Waze-reported congestion: metro adoption could reduce both car traffic and the number of Waze users observing remaining traffic.

Pre-period checks. Audit boundary-road shares, numerator–denominator road classes, map vintages, duplicate jam segments, zero frequencies, and processing breaks. Verify whether the severe-persistence error shares inputs with the main outcome.

Rule. Freeze geography, denominator vintage, road eligibility and missingness rules. Retain valid main outcomes when the severe-field error is demonstrably isolated.

Risk. Stable pre-period reporting cannot exclude treatment-induced changes in observation. Neither dropping zeros nor controlling for contemporaneous jam counts solves this.

**2. Correct the policy calendar before interpreting the drift.**

Problem. The proposed chronology omits relevant disruptions. Official Quito records document electricity rationing beginning October 27, 2023, within the holdout. April 2024 also involved electricity disruption, suspended workdays and temporary suspension of pico y placa. Ending P1 in August therefore does not make it outage-free. These documentary checks require no examination of post-opening congestion outcomes. Quito Informa

Action and rationale. Reconstruct the calendar of outages, driving restrictions, roadworks, bus changes and any metro trial operations. Retain P1 as the principal window if substantively appropriate, with an externally dated disruption sensitivity.

The April 2023 change removed restrictions during 20:00–21:00. Your 17, 18 and 19 bins remained restricted, assuming hour-start labels. Morning versus evening is therefore a diagnostic for indirect retiming, not a clean regulatory treatment contrast. Request hour 20 and adjacent hours. Quito Informa

Pre-period checks. Compare gaps before and after April, and June–September against October–November. October outages cannot explain an earlier drift.

Rule. Fix calendar-based sensitivities before opening outcomes; do not select excluded dates by their estimated effects.

Risk. Monthly data may not support useful day-level adjustments.

**3. Rebuild donor eligibility around exposure and observation.**

Problem. None of the three existing pools is automatically defensible. Cumulative road length ever recorded as jammed is a mixture of congestion propensity and observation, not an independent coverage measure. The old monitor-ring minimum–maximum screen has no clear justification for the new CENTER.

Action and rationale. Start from the broader candidate universe, then apply documented measurement-quality and exposure requirements. Prefer donors sharing the driving-restriction regime and plausibly little affected by metro access, feeder connections or commuting changes. I cannot establish that enough such donors exist.

Keep valleys and neighbouring municipalities as separately reported sensitivity pools pending this assessment. Administrative boundaries alone neither validate nor invalidate donors. Likewise, four kilometres is an exposure proxy, not proof of nonexposure.

Pre-period checks. Compare forward forecasts, observation indicators, policy-break responses and road-network characteristics across these strata. Report positive, negative and absolute donor-weight mass by geography; "56% of signed weight" can conceal cancellation.

Rule. Freeze substantive eligibility before optimizing fit. Replace the inherited coverage-range rule with a justified quality rule.

Risk. Pre-period similarity cannot establish that valleys remain unaffected after opening. Stable additive level differences can be accommodated; stable multiplicative measurement differences can still distort trends.

**4. Reduce flexibility; do not treat exact fit as an achievement.**

Problem. With 165 donors and only 23 monthly observations, weakly regularized signed weights have ample scope to interpolate. Polygon averaging may have moved CENTER closer to the donor span, but its precise role requires inspection. If weights sum to one, negative mass of −1.48 implies total absolute weight of 3.96, amplifying donor-specific disturbances.

Action and rationale. My primary candidate is intercept-adjusted, nonnegative SCM on prespecified comparable neighbourhood aggregates, with weights summing to one and a deterministic tie-breaking rule. This accommodates additive offsets, limits extrapolation and aligns spatial aggregation. It remains conditional on Recommendation 5.

| Option | Assessment |
|---|---|
| Conservative ridge ASCM | Useful sensitivity. Choose the largest penalty within 5% of minimum forward-validation loss, explicitly including the SCM limit. The tolerance is a heuristic. |
| Penalty minimizing holdout error | Permissible tuning, but those months then provide no independent validation. |
| Plain SCM | With an intercept is preferable when additive offsets are credible. Neither version guarantees against interpolation. |
| Abadie–L'Hour penalization | Strong alternative when many dissimilar donors combine into equivalent fits. Its penalty favours individually similar donors; it is not ridge augmentation. |
| Larger donor units | Helpful for comparable measurement scale and lower dimension. Freeze contiguous geography; avoid parishes mixing exposure regimes. |
| Multiple-outcome weights | Promising sensitivity using morning, evening and other hours. Check each outcome's fit; correlated hours are not independent replications. |
| Higher-frequency data | High priority for observing disruptions and validating forecasts. More observations do not automatically provide more independent information. |
| SDID, factors, matrix completion | Secondary alternatives. Additional time weights, ranks or penalties cannot repair invalid donors or changing observation. |

These distinctions follow the regularization arguments in Ben-Michael, Feller and Rothstein (2021), the donor-proximity penalty in Abadie and L'Hour (2021), and the common-weight framework of Sun, Ben-Michael and Feller. jesse-rothstein.com

Pre-period checks. Inspect matrix rank, singular values, penalty scaling, weight stability and leave-neighbourhood-out predictions.

Rule. Fix aggregation independently of outcome fit; reserve richer estimators for declared sensitivities.

Risk. Simplicity limits variance and extrapolation but does not establish identification.

**5. Use forecasting requirements with an explicit failure outcome.**

Problem. The six-month holdout has already informed several decisions. It remains informative, but it is no longer untouched validation. Also, opposite drift signs under SCM and donor-mean DiD show that the counterfactual is unresolved.

Action and rationale. Freeze a narrow comparison: the proposed convex SCM, conservative ridge ASCM and donor-mean DiD. Use forward validation with predefined origins, at least 12 training months, and three- and six-month blocks. Examine signed block-average errors alongside RMSE. Overlapping blocks are dependent.

Plot CENTER, the donor mean and the synthetic donor series separately. Determine whether the disagreement comes from CENTER or from weighted versus unweighted donor movements. Repeat by hour and policy stratum.

Pre-period checks. Assess sustained bias, forecast stability and sensitivity to influential donor neighbourhoods. A nonsignificant pretrend test is insufficient.

Rule. Before further tuning, choose a smallest substantively meaningful effect, δ. An explicit design tolerance could require absolute six-month forecast bias below δ/2 and RMSE below δ. These are judgment-based tolerances, not validity theorems. If all candidates fail, classify the analysis as exploratory.

Risk. Twenty-three months provide limited validation. Do not subtract the observed drift or extrapolate a fitted trend merely to improve the prospective result.

**6. Estimate spatial effects against an explicit external reference.**

Problem. Analysing the buffer is sensible, but naming additional treated zones does not identify spillovers.

Action and rationale. Predefine mutually exclusive CENTER, BELISARIO, remaining CORRIDOR and adjacent exposure bands, followed by candidate donors. Use clipped road outcomes or exclusive cell assignments so different zones do not silently reuse identical whole-cell outcomes.

Estimate each zone's total response to the opening package against plausible unexposed comparators. These are location-specific policy effects; one opening does not separately identify each station's direct effect and spillovers from other stations.

Affected controls contaminate comparisons, a central issue in spatial-interference designs. With negative weights, contamination need not attenuate estimates toward zero. kylebutts.com

Pre-period checks. Map road connections, baseline commuting links, feeder access and shared outcome support.

Rule. Freeze exposure bands and boundaries without post-opening outcomes. Keep CENTER–BELISARIO secondary; any inference must account for shared donors and correlated errors.

Risk. If all credible comparators experience metro effects, only relative spatial effects may be identifiable, not the citywide effect.

**7. Retain conformal inference conditionally, with the correct null and implementation.**

Problem. Pre-period interpolation does not inherently make conformal inference undefined. Chernozhukov, Wüthrich and Zhu's procedure estimates the model under the hypothesized effect using the null-adjusted pre- and post-period data. It need not divide by pre-RMSPE. If that fit interpolates every date, tied raw scores can produce p=1: loss of power, not necessarily mathematical failure. arxiv.org

Action and rationale. If the design passes the preceding requirements, prespecify a full-null circular-shift test using the absolute nine-month mean residual and all 32 shifts, including identity. Its minimum p-value is 1/32=0.03125; rejection at 5% requires a uniquely most-extreme observed score. This resolution belongs to that permutation scheme, not universally to 32 observations.

It tests the sharp zero-effect path. Inverting constant-effect hypotheses does not automatically yield an interval for an unrestricted heterogeneous average effect.

Pre-period checks. Inspect residual dependence, seasonality, drift and pseudo-intervention performance. Exactness requires appropriate invariance; ordinary stationary dependence generally supports approximations rather than finite-sample guarantees. Pre-only tuning alone does not ensure permutation invariance. proceedings.mlr.press

Rule. Freeze score, shifts, nuisance fitting and tie handling. If stability remains implausible, abandon confirmatory significance claims.

Risk. For average effects, I would add the CWZ cross-fitted t-test with K=3 only as a sensitivity: approximately seven-month calibration blocks are short. Its t₂ reference has no positive discrete p-value floor, but that does not improve identification. arxiv.org

**8. Replace unstable placebo scaling and update detectability.**

Problem. Dividing gaps by nearly zero training RMSPE manufactures extreme placebo statistics. Eleven neighbourhoods also provide little inferential resolution.

Action and rationale. Construct nonoverlapping pseudo-neighbourhoods using the same geography, road support, exposure and measurement rules as CENTER. Exclude their own cells and prescribed buffers from their donor pools. Apply the identical estimator-selection procedure.

Report raw gaps and scaling by held-out forecast RMSE. If that denominator is also negligible, report the raw statistic rather than inventing an arbitrary stabilizer.

Pre-period checks. Examine pseudo-intervention forecast errors, dependence between neighbourhoods and stability of normalization. Recalculate detectability for the new CENTER under several persistence assumptions; the old-ring MDE does not transfer.

Rule. Keep placebos descriptive. Even under exchangeable assignment, 11 placebos plus CENTER give a minimum rank p-value of 1/12=0.0833.

Risk. Matching neighbourhood geometry does not make treatment assignment exchangeable.

**Direct answers to the nine questions.**

1. Interpolation: High dimensionality and weak regularization explain its feasibility. Choose the simpler convex candidate in Recommendation 4, conditional on forecasting performance.
2. Selection without searching for a result: Disclose existing exploration, freeze a small candidate set and publish every prespecified sensitivity. Pre-only selection prevents post-effect searching, not pre-period overfitting.
3. Inference: Conditional circular-shift conformal inference, plus descriptive placebos and an average-effect sensitivity. The proposed minima are 1/32, 1/12, and no discrete floor for the t-test.
4. Donors: None of the current pools deserves automatic primacy. Rebuild eligibility; assess valleys separately. Pre-period checks can reject comparators, not certify nonexposure.
5. Drift: Decompose weighted donor movements, hours and policy regimes. Freeze reporting of all signs; unresolved drift downgrades the causal claim.
6. Spillovers: Estimate disjoint zones against a defensible external reference. Otherwise interpret differences as relative effects.
7. Measurement: Resolve polygon support, observation and denominators first. Historical ever-jammed roads are not independent coverage.
8. Placebos: Match construction, use forecast-based scaling and retain descriptive status.
9. Overall: Potentially useful mechanism evidence. A demanding referee will first ask whether the comparison identifies traffic changes rather than reporting changes or differential shocks. Lower reported congestion also does not establish lower vehicle-kilometres, emissions or causal mediation of the pollution effect.

**I would not:**

- Select a model because it interpolates, achieves significance or yields the expected sign.
- Treat distance, municipal boundaries or good pre-fit as proof of unaffected donors.
- Use unrestricted month permutations merely to obtain smaller p-values.
- Repair drift through an outcome-selected trend, window or bias subtraction.
- Automatically control for bus changes caused by metro integration; these may be part of the policy mechanism.
- Describe P1 as free of electricity disruptions or an insignificant estimate as evidence of no effect.

**The information still needed is:**

- Exact outcome formulas, hour labels, road denominators, polygon provenance and boundary-road shares.
- Independent observation indicators, feed interruptions and provider processing changes.
- Daily or weekly data availability.
- Complete policy, outage, bus-service and trial-operation calendars.
- Baseline commuting and feeder connections for proposed donors.
- The precise meaning of "holdout miss": RMSE, mean error or another statistic.
- Software version, tuning folds, penalty scaling, fitted weights and conformal implementation.
- The smallest congestion change that would materially support the paper's mechanism argument.

## Answer 2: ChatGPT Sol 6.1 ultra (received October 1, 2026)

This could become useful mechanism evidence, but I would not freeze the current confirmatory design. The main concerns are whether the outcome measures congestion in the intended geography, whether changes in Waze observation can mimic congestion reductions, and whether the counterfactual predicts credibly outside its fitting period. My provisional primary estimator would be intercept-adjusted synthetic control with nonnegative weights, using geographically predefined, aggregated donors; ridge augmentation would be a sensitivity analysis. If measurement and forward-prediction checks fail, I would present this as descriptive evidence rather than a causal congestion estimate.

All diagnostics below use pre-opening data. Recommendations are ordered by importance.

**1. Make the measured geography match the estimand.**

Problem: Weighting whole-cell indices by roads inside the historic district does not recover congestion inside the district. Your calculation is

\[
\widetilde Y_{Pt}=
\frac{\sum_i L_{iP}(J_{it}/L_i)}{\sum_i L_{iP}},
\]

where \(J_{it}\) and \(L_i\) cover the whole cell. The desired outcome instead uses congested length inside the polygon. Equality requires equal congestion rates inside and outside each intersecting cell.

Action: Request polygon-clipped jam lengths with compatible road denominators. Otherwise describe CENTER as a road-weighted index of intersecting cells.

Pre-period checks: Calculate boundary-cell contributions, within-polygon road shares, and sensitivity to predefined interior-cell and monitor-ring definitions. Check road classes, directions, map vintages, and clipping consistency.

Decision rule: Freeze the official polygon estimand if clipping is obtainable. Otherwise freeze the explicitly approximate cell-based estimand, with boundary sensitivity reported.

Main risk: Boundary contamination can change both the estimated effect and its connection to the pollution monitor.

**2. Treat observation quality as an identification issue.**

Problem: Zero combines free flow with absent observation. Historical roads ever experiencing a reported jam measure congestion and detection, rather than observation probability alone. Moreover, switching from driving to metro could itself reduce Waze observations.

Action: Request independent probe counts, observable-road support, ingestion uptime, and processing definitions. If unavailable, retain the outcome as Waze-reported congestion and make observation stability an explicit assumption. Do not mechanically adjust for post-treatment Waze use, which could be affected by treatment.

Pre-period checks: Examine zero shares, reporting frequency, support expansion, processing discontinuities, and available independent traffic measurements. Audit duplicate or overlapping jam lengths.

Decision rule: Freeze road definitions, observation rules, and any quality thresholds before estimation. Unexplained reporting instability prevents a strong causal congestion claim.

Main risk: Stable pre-opening reporting cannot establish that treatment leaves reporting unchanged.

**3. Construct donors around policy exposure and transport connections.**

Problem: Neither the old coverage range nor geographic distance establishes a credible untreated comparison. Valleys may share commuting shocks while having different restrictions, road composition, and Waze observation.

Action: Start from the unscreened universe, then apply documented measurement, policy, and exposure eligibility rules. Prefer urban donors sharing the restriction regime and plausibly having low metro exposure. Use pre-opening commuting connections, feeder plans, and road-network links alongside distance.

Pre-period checks: Compare seasonal responses, the April transition, observation stability, road composition, and forward prediction across eligible pools.

Decision rule: Use policy-matched donors as primary if sufficient credible support exists. Outside-zone and neighbouring-municipality donors are predefined sensitivities. The 4 km pool tests a distance restriction; it does not certify absence of exposure.

Main risk: Suitable donors may not exist. Good pre-fit cannot justify relaxing eligibility until a comparison appears.

Your "trends, not levels" principle is too broad: an intercept accommodates stable additive differences, but different detection rates or congestion intensity can produce different responses to common shocks.

**4. Reduce flexibility before optimizing fit.**

Problem: With 165 donors and 23 pre-period observations, signed weights can reproduce a trajectory lying in the donor matrix's span. Aggregating CENTER changes that geometry; the precise explanation requires the matrix and code. If weights sum to one, negative mass of −1.48 implies positive mass of 2.48 and absolute mass of 3.96.

Action: Use predefined, nonoverlapping donor neighbourhoods with comparable road-network scale. Fit nonnegative weights summing to one plus an intercept. Keep strongly regularized ridge augmentation as a sensitivity. Ridge explicitly trades improved balance against extrapolation; near-zero training error is not its objective in isolation. arxiv.org

Pre-period checks: Inspect singular values, centering, penalty scaling, solver tolerances, weight concentration, and predictions after removing donor neighbourhoods or contiguous months.

Decision rule: Accept the simpler specification only if it passes forward validation. Convex weights can also interpolate.

Main risk: Aggregation reduces flexibility but may discard useful comparators or conceal heterogeneous trends.

**5. Choose through a documented forecasting exercise.**

Problem: The six-month holdout has already informed model development. It cannot subsequently be presented as untouched validation.

Action: Freeze a small candidate set and use rolling-origin prediction, with all preprocessing and tuning repeated within each training fold. Examine three-, six-, and, where feasible, nine-month horizons. Include donor-mean DiD and intercept-adjusted SCM benchmarks.

Pre-period checks: Report forecast RMSPE, signed bias, persistence, and sensitivity across folds. Overlapping folds provide limited independent information.

Decision rule: Define a smallest substantively relevant effect, \(\delta^*\), for the new CENTER. One defensible gate is that validation bias remains below \(\delta^*/2\), without material forecasting deterioration against simpler benchmarks. Fix thresholds and tie rules before executing the comparison. For ridge, choose the largest penalty within 5% of minimum forward-validation loss, rather than the single numerical minimum.

Main risk: Twenty-three months offer little independent validation. The old CENTER's detectable effects cannot be transferred to the new outcome.

**6. Diagnose the drift without promising a statistical correction.**

Problem: Opposite signs across comparisons indicate counterfactual sensitivity. They do not establish which comparison captures the untreated trajectory.

Action: Separate morning and evening forecasts, restriction-zone exposure, and donor geography. Importantly, the April change removed restrictions during 20:00–21:00; the selected evening hours remain restricted under ordinary hourly definitions. AM–PM comparisons therefore diagnose possible retiming or broader responses, rather than direct removal of restrictions in the measured hours. The municipal announcement confirms these schedules. Quito Informa

Pre-period checks: Confirm hour conventions; examine 20:00 and adjacent hours if available, April's partial-month transition, corresponding 2022 months, and reporting changes.

Decision rule: Freeze comparisons and a persistent-bias sensitivity range calibrated from forward-validation errors. Report how conclusions change when that bias continues through P1.

Main risk: A pre-period slope or April dummy can conceal misspecification. Seven fully post-change pre-opening months provide weak evidence about persistence.

**7. Estimate geographic effects while retaining an unaffected reference group.**

Problem: Keeping nearby areas as outcomes is sensible, but estimating them does not eliminate interference assumptions.

Action: Define disjoint CENTER, BELISARIO, remaining CORRIDOR, and buffer zones, with an explicit overlap rule. Estimate each against a common eligible donor universe. Call these geographically distributed effects of the opening. Separating direct effects from network spillovers requires additional assumptions or variation. Spillovers can contaminate controls and contribute to treated-area changes. kylebutts.com

Pre-period checks: Map commuting and network connections; examine zone-specific forecast errors and their covariance.

Decision rule: Freeze zones and exposure classifications from pre-opening information. Estimate the buffer as another exposed zone, while excluding it from donors. Keep CENTER–BELISARIO secondary and account for correlated errors.

Main risk: If the metro affects the whole commuting system, local comparisons identify relative geographic effects rather than the citywide effect.

**8. Specify inference conditionally and distinguish the null from the estimand.**

Problem: Interpolation does not automatically make conformal inference undefined. Dividing by zero RMSPE does; an unscaled test remains defined, although a fully interpolating null fit can yield ties and \(p=1\).

Action: Conditional on credible prediction and temporal stability, retain a CWZ sharp-null test. Impose zero effects in all nine P1 months, fit the null-imputed series over all 32 months, and use the absolute nine-month mean residual with 32 circular shifts and inclusive ties. This differs from ranking frozen pre-fit residuals. Exact validity requires appropriate exchangeability and invariant fitting; pre-only selection does not automatically preserve that argument. arxiv.org

Pre-period checks: Apply the complete procedure at feasible pseudo-openings; inspect residual persistence, seasonal structure, numerical ties, and estimator stability.

Decision rule: With this scheme,

\[
p_{\min}=1/32=3.125\%.
\]

At 5%, the observed statistic must be uniquely most extreme. Characterize serial-data validity as approximate and assumption-dependent. Failed stability gates mean no confirmatory causal claim.

Main risk: Resolution is not calibration. Supplement the test with prediction uncertainty separating weight estimation from counterfactual prediction error, following Cattaneo, Feng and Titiunik, and with the drift sensitivity above. Target the nine-month mean explicitly, including temporal covariance; averaging pointwise interval endpoints is insufficient. PMC

**Applied directly to your nine questions.**

Q1. Why interpolation, and which estimator? The likely explanation is excessive flexibility relative to temporal information, combined with weak penalty selection. Confirm rank, preprocessing, and implementation before concluding that this is ordinary overfitting.

| Option | My assessment |
|---|---|
| Fixed ridge rule | Reasonable sensitivity. Prefer strongest regularization within the declared forecasting tolerance. Choosing the holdout minimum consumes that holdout. |
| Plain SCM | My provisional primary with an intercept and aggregated donors. Without an intercept, stable level differences become an unnecessary matching constraint. |
| Abadie–L'Hour penalized SCM | A strong alternative: its pairwise-discrepancy penalty discourages combinations of individually dissimilar donors. It addresses multiplicity under stated conditions, but does not establish valid donors or prediction. |
| Larger donor units | Preferred design improvement if boundaries are substantively predefined. |
| Multiple outcomes | Promising if hours share a factor structure. Standardize using training-period scales and validate each outcome separately. |
| Higher frequency | Request it early. It improves diagnostics and forecasting opportunities; dependence still limits effective information. |
| SDID, factor models, matrix completion | Limited robustness candidates. They introduce different weighting or low-rank assumptions and cannot repair measurement or donor contamination. |

The penalized-SCM recommendation follows Abadie and L'Hour (2021); the multiple-outcome option follows Sun, Ben-Michael and Feller's working paper, first circulated in 2023. Their gains depend on shared structure, and highly correlated hours need not supply much independent information. economics.mit.edu SDID is supported by Arkhangelsky et al. (2021), but should earn inclusion through the same validation exercise. American Economic Association

Q2. Choosing without bias? Follow recommendation 5, retain every candidate's results, and document that the geography and specification changed before unblinding. Pre-only selection avoids searching for a post-opening result; it still requires honest reporting and appropriate inference.

Q3. Conformal inference? Retain it conditionally, not automatically. The proposed grid is \(1/32\); doubling a one-sided tail instead gives a minimum \(2/32\). The test concerns zero effects throughout P1. Inverting constant-effect trajectories does not automatically give an interval for a heterogeneous average effect.

Q4. Which donors and April treatment? Use substantive eligibility before coverage screening. Outside-zone donors are secondary; administrative boundaries alone are not decisive. Match the restriction regime and explicitly inspect the April transition. Valleys can pass prediction checks, but no pre-period test proves they will escape metro spillovers.

Q5. Drift? Use recommendation 6. Freeze a bias sensitivity analysis and a forecasting gate, rather than selecting whichever estimator produces the preferred drift sign. A nonsignificant pretrend test is insufficient.

Q6. Spillovers? Estimate disjoint exposed zones against plausibly unaffected donors. A buffer becomes an estimable outcome zone. This identifies geographic effects under maintained assumptions, not a structural decomposition of direct and spillover channels.

Q7. Measurement? Fix polygon clipping and observation diagnostics first. Replace the old coverage-range rule with a documented support assessment. Retain fixed road weights only with compatible numerator definitions. Quarantining invalid severe-jam fields is sensible, but the main aggregation still needs its own audit.

Q8. Placebo neighbourhoods? Predefine comparable, preferably nonoverlapping areas by road length, composition, policy exposure, and observation quality. Exclude each placebo's entire constituent area from its donors and run identical preprocessing and tuning. Scale by forward-validation error rather than interpolated training RMSPE; if validation error is also negligible, report unscaled gaps. Eleven placebos plus CENTER yield a minimum descriptive rank of \(1/12=8.33\%\), without establishing random-assignment inference.

Q9. Overall mechanism evidence? Potentially useful corroboration. A demanding referee would first ask whether fewer reported jams represent less congestion and whether the comparison predicts the untreated trajectory. Congested road length is not vehicle kilometres, emissions, or modal substitution, so a credible result supports the proposed mechanism without identifying mediation or quantifying the pollution effect explained.

**I would not:**

- Treat near-perfect training fit as evidence of a credible counterfactual.
- Delete the above-range CENTER cell to preserve the obsolete coverage screen.
- Recode all absent records as missing and analyze detected jams only; that conditions on detection.
- Use unrestricted month permutations to manufacture finer p-values despite dependence.
- Extrapolate a short pretrend correction as the primary counterfactual.
- Treat cells, hours, or overlapping placebo areas as independent replications.
- Select a significant estimator, geography, transformation, or window after unblinding.

**The missing information I would need is:**

- Whether jam numerators can be clipped to polygons, and precisely how indices, denominators, and hourly buckets are constructed.
- Independent observation metrics and the provider's processing history.
- Donor maps, road composition, pre-opening commuting connections, and support within the restriction zone.
- The CV folds, penalty normalization, intercept implementation, installed software version, and definitions of "holdout miss" and exterior signed weight.
- The new CENTER's mean, forward-error covariance, and smallest substantively relevant effect.
- Availability of daily or weekly data.
- The policy, bus-service, roadworks, and operating calendar relevant to attribution during P1. These are missing contextual facts, not additional outcome checks proposed here.

## Answer 3: Fable 5.1 (received October 1, 2026)

**Verdict**

Do not freeze the current model. Its near-perfect pre-period fit is mechanical, not a good match. With 165 donor cells and 23 months, weights that may turn negative can reproduce almost any average of cells, which is why five of the eleven placebos interpolate too, and conformal inference has nothing to test once residuals are forced to zero. The remedy is less flexibility rather than a better-tuned penalty. That means weights that are zero or positive and add to one, a scale on which CENTER and the donors move alike, donor units built like the treated units, and an estimator chosen only on pre-period forecasts. With these changes the design can support the air-quality paper, but monthly data, one treated unit and an outcome that depends on how many Waze users drive mean I would present it as evidence consistent with the mechanism rather than as a confirmatory test, unless weekly data arrive.

**Recommendations**

**1. Make synthetic control with an intercept the primary estimator, fitted on both peaks**

Problem. The ridge correction has one free weight per donor and one balance condition per month. When donors outnumber months, a small penalty always finds an exact fit, and nothing makes that fit hold outside the fitting window. Its holdout miss (0.827) is already worse than plain synthetic control's (0.749).

What to do. Use weights that are zero or positive and sum to one, fitted to each unit's deviations from its own pre-period mean (Doudchenko and Imbens 2016; Ferman and Pinto 2021). Fit one set of weights to the morning-peak and evening-peak series stacked together, following Sun, Ben-Michael and Feller (2023). These weights cannot extrapolate. They absorb stable level differences, and they must match two series month by month, which a chance match on one series rarely does. Keep the ridge as a sensitivity.

Pre-period checks. The effective number of donors (one over the sum of squared weights), and the pre-period error compared with the month-to-month noise of donor units.

Decision rule. A fit whose pre-period error falls below half that noise is fitting noise and is disqualified.

Main risk. If CENTER lies outside anything the donors can average to, the fit is biased. Recommendations 2 and 3 address the two likeliest causes.

**2. Fit the weights in proportions rather than index points**

Problem. In the September descriptives, the saturated cells averaged about half of CENTER's level. If holidays, blackouts and school calendars move congestion proportionally, CENTER swings about twice as many index points as a typical donor. Weights that add to one cannot produce swings larger than every donor's. So the convex fit misses, and the ridge gets there by leverage, with large positive weights on some donors offset by negative weights on others. That is what your negative weights of -1.48 look like.

Here I disagree with your "trends, not levels" principle. A stable level difference is harmless only if shocks add the same number of points at every level, and Roth and Sant'Anna (2023) show this is a substantive assumption when levels differ. The same holds for measurement, since a lower Waze detection rate scales reported jams down rather than subtracting a constant.

What to do. Divide each unit's series by its pre-period mean before fitting. Then build CENTER's counterfactual as its pre-period mean times the weighted donor ratios, so the estimand stays in index points. Chen and Roth's (2024) objection to logs concerns zeros in unit-level outcomes, and these aggregates are strictly positive.

Pre-period checks. Across donor units, regress the log volatility of monthly changes on the log pre-period mean. Redo the holdout with difference-in-differences (DiD) and synthetic control on both scales, since the sign flip between them may be this same problem.

Decision rule. Fit in proportions if that slope exceeds 0.5, and in levels otherwise. Settle this before any other choice.

Main risk. Ratios are unstable for units with low means. The saturation rule and the tiling below limit this.

**3. Rebuild the donor pool from units shaped like the treated units**

Problem. Against 17 to 23 months, 165 or 270 single cells guarantee an exact fit once weights may be negative. Single cells are also far noisier than CENTER, which averages fifteen cells, so donors and placebos differ from the treated unit in noise as well as in place. The ridge fit also put 56% of its signed weight outside the metropolitan district (DMQ), where the transit authority and local holidays differ.

What to do. Tile the donor area into non-overlapping H3 resolution-7 parents. Each covers seven resolution-8 cells, a centre cell and its six neighbours. That is the shape of the BELISARIO ring and roughly the size of CENTER's polygon. Keep a tile when most of its cells meet the saturation rule, and build every unit's index as total jam length over total road length. Make DMQ tiles outside the buffer the primary pool, with neighbouring municipalities as a sensitivity, in line with Abadie's (2021) advice to use small pools of similar units. Ask the provider now for weekly values, which would give about 100 pre-period points and match the paper's weekly panels.

Pre-period checks. The number of qualifying tiles, and CENTER's volatility compared with its distribution across tiles.

Decision rule. If fewer than 20 DMQ tiles qualify, tiles from neighbouring municipalities join the primary pool. If weekly data arrive before the freeze, the weekly panel becomes primary.

Main risk. Fewer donors make a poor fit more likely and coarsen placebo inference.

**4. Choose the estimator through a frozen protocol scored on placebo tiles**

Problem. The unit, pool, screen and penalty have each changed after inspecting pre-period fits. Choosing whatever makes CENTER's own pre-period look best favours specifications that overfit CENTER. Ferman, Pinto and Possebom (2020) show how much room such searches leave in synthetic control.

What to do. Add an addendum to the analysis plan that fixes the units, tiling, scale rule, inference, decision rules and a menu of four estimators:

- the default from Recommendation 1;
- synthetic difference-in-differences (Arkhangelsky et al. 2021), whose penalty comes from a noise-based formula rather than from cross-validation;
- ridge with the largest penalty within 5% of the best tuning error;
- DiD against the equal-weighted tile mean.

Score each estimator by rolling-origin forecasts. Refit at each cut-off from about month 12 to month 20, forecast the next three undisrupted months, and average the squared errors over all placebo tiles rather than over CENTER. Leave June 2022 (the national strike) and November 2023 (rotating blackouts) out of the weight fit and the permutation set, for reasons documented outside the data. Refit the winner on the full pre-period and commit the code before any post-opening month is loaded.

Pre-period checks. The contest itself, reported in full.

Decision rule. The default stands unless another estimator lowers mean placebo forecast error by at least 10%. Ties go to the simpler estimator.

Main risk. With 23 months the scores are noisy, which is why the default holds unless it is clearly beaten.

**5. Keep conformal inference only for a fit that cannot interpolate, and check its size**

Problem. The Chernozhukov, Wüthrich and Zhu (2021) test refits the model on all months under the null and permutes the residuals over time. A refit that reproduces every month leaves no residuals, so the test is empty. Its validity also needs stable, weakly dependent residuals, which 23 months cannot establish.

What to do. Run the test on the Recommendation 1 estimator, with the P1 average as the statistic. Use moving-block permutations, which shift the series in a circle so the nine-month window lands on every block of consecutive months. Report two supporting results whatever they show.

- CENTER's rank among all tiles treated as placebos (Abadie, Diamond and Hainmueller 2010). Scale each gap by the tile's out-of-sample forecast error from Recommendation 4, because an overfit model can push in-sample error to zero.
- Prediction intervals from Cattaneo, Feng and Titiunik (2021).

The smallest attainable p-values are 1/30 with monthly data, below 1/100 with weekly data, and 1/(N+1) for the rank with N tiles.

Pre-period checks. Run the full test on every placebo tile at pseudo-openings inside the pre-period, and record how often it rejects at 5%. Run it on CENTER with a June 2023 pseudo-opening.

Decision rule. The CENTER test for P1 is confirmatory if p ≤ 0.05 and placebo rejections stay at or below 10%. Otherwise the conformal p-value is descriptive, and the claim rests on the rank, which needs at least 19 tiles to reach 5%.

Main risk. Low power. Replace the parametric range for the minimum detectable effect (0.63 to 1.90) with an empirical one from nine-month placebo forecast errors.

**6. Build a calendar of local shocks, test the driving restriction directly, and fix a drift rule**

Problem. The drift changes sign with the comparison, and documented shocks fall in the holdout and the first treated month. Rotating blackouts by substation began on 27 October 2023 and were to last until the Christmas and New Year holidays, and some hit the evening peak, such as a 16:00 to 18:00 cut in Sangolquí on 1 November. Traffic lights fail during cuts, so unequal exposure moves the gap. The provider's averages cover Monday to Friday, so weekday holidays and decreed days off sit inside them. One example is 18 and 19 April 2024, when the government suspended work and Quito lifted the driving restriction. [Logo de Primicias +2](https://www.primicias.ec/noticias/economia/horarios-cortes-luz-quito-12diciembre)

What to do. Map the substation schedules to tiles, compute peak-hour blackout exposure by tile and month, and count weekday non-working days. Put the June 2022 strike, the January 2024 security emergency and the gasoline price rise of 28 June 2024 on the same calendar. [primicias](https://primicias.ec/noticias/economia/nuevo-precio-gasolina-extra-ecuador-ecopais)

On April 2023, I disagree with the morning-versus-evening test. Hours 17 to 19 stayed restricted under both schedules, so the change should not move them. Use hours 20 and 21 as a positive control instead, a past event whose effect we can predict in sign. After 10 April 2023, congestion at 20:00 should rise inside the zone relative to outside it, and congestion at 21:00 should fall. Press reports from April and December 2024 still give the evening restriction as 16:00 to 20:00, so no later change seems to touch P1. [elcomercio](https://www.elcomercio.com/actualidad/quito/pico-y-placa-quito-martes-30-de-abril.html)[primicias](https://primicias.ec/quito/horario-pico-placa-transito-amt-17diciembre-85640)

Pre-period checks. Whether CENTER's holdout errors lie within the placebo tiles' errors for the same months. Whether the drift survives the change of scale. Whether gaps track blackout exposure or holidays. Whether the positive control appears.

Decision rule. Report an anchored estimate beside the primary one. Fit weights on January 2022 to May 2023, then subtract the mean June to October 2023 gap from the mean P1 gap. Also report how large a continuing drift would have to be, as a multiple of the drift seen before the opening, to erase the effect, in the spirit of Rambachan and Roth (2023). Claim the mechanism only if both estimates share a sign and that multiple exceeds one. Report P1 with and without December 2023.

Main risk. The anchored estimate is noisier, and it over-corrects if the drift was noise.

**7. Replace the coverage screen and add a speed-based outcome**

Problem. Coding absent records as zero mixes fewer jams with fewer Waze users. The metro itself removes drivers, so part of any fall may be fewer probes rather than faster traffic. The coverage measure is built from jams and is cumulative, so it saturates at the core and keeps growing elsewhere even with flat adoption. It cannot separate adoption from accumulation, and the screen was calibrated on the old monitor rings.

What to do. Replace the coverage-range screen with the saturation rule and the tiling. Ask the provider for coverage computed year by year, the best adoption check available without jam counts. Use years up to 2022, because 2023 contains a treated month. Add a secondary outcome from the delivery's jam speed fields, if they are clean, since speeds depend less on how many users report. Road-length weighting is fine. Tabulate the out-of-range persistence values by month. If they cluster in time, ask whether the provider's pipeline changed, because that could touch the main outcome too.

Pre-period checks. Yearly coverage trends for CENTER and its weighted donors, and how the main index and the speed outcome move together within CENTER.

Decision rule. If donor coverage grows faster than CENTER's before the opening, state now that a fall in the main index will be described as fewer reported jams, and give the speed outcome equal space.

Main risk. Yearly coverage may be unavailable, and speeds may share the sampling problem.

**8. Estimate spillovers by distance rings, without letting them drive the design**

Problem. For the CENTER test the donors lie beyond a buffer, so I do not see spillovers as the main threat there. The counterfactual and coincident shocks matter more. Spillovers matter for reading the corridor results and for whether far donors are clean, for instance where feeder buses reach the terminals.

What to do. Before fitting, fix mutually exclusive rings by distance to the nearest station:

- CENTER and BELISARIO;
- the existing corridor tier;
- rings at increasing distance out to the edge of the buffer;
- donors beyond the buffer.

Tile each ring into units of similar size, split into north, centre and south, and estimate each against the same donors with the same estimator. This follows the ring logic of Butts (2021), a working paper whose publication status I have not checked. Add the delivery's fast-road series for the arterials parallel to the line, since Anderson (2014) finds that transit relieves congestion most on the congested routes its riders would otherwise drive.

Pre-period checks. Each ring's rolling-origin forecast error against the donors.

Decision rule. Read CENTER's estimate as a metro effect only if ring estimates shrink with distance. An outer-ring effect similar in sign and size to CENTER's points to a city-wide change.

Main risk. These are many low-powered comparisons, and feeder-bus changes can create effects far from the line.

**Answers to the questions**

1. The interpolating fit. With more donors than months, an exact fit exists once weights may be negative, and a tiny penalty picks the smallest such weights. The tuning curve is flat, so the smallest penalty wins by chance. The new CENTER is also smoother than single cells and above most of them in level, so the convex fit misses.

   On the options:

   - Fixed-penalty rule. It treats the symptom. On a curve this flat, any rule that prefers the simplest model among near-ties lands near the top of the grid, which is synthetic control with an intercept anyway.
   - Penalty tuned on the holdout. It spends the holdout.
   - My primary. Synthetic control with an intercept on both peaks and tiled donors, with weekly data if possible (Recommendations 1 to 3).
   - Main alternative. Synthetic difference-in-differences.
   - Penalized synthetic control (Abadie and L'Hour 2021). A useful sensitivity, but the "interpolation" it penalizes is averaging over dissimilar donors, a different problem.
   - Factor models and matrix completion. They add tuning choices that 23 months cannot discipline.
   - Keeping single cells. If you want them, use robust synthetic control (Amjad, Shah and Shen 2018), with the rank set by the Gavish and Donoho (2014) threshold rather than by cross-validation.

2. Choosing without bias. Recommendation 4.
3. Inference. Recommendation 5.
4. Donor pool. Tile the saturated cells and keep DMQ tiles. Use the low-exposure pool as the spillover sensitivity, and cells outside the DMQ only as a sensitivity or fallback. Keep tiles outside the restriction zone. Leave the April 2023 change unadjusted, since it does not touch the measured hours. For the valleys, run three checks:

   - forecast valley tiles from in-zone tiles, and the reverse, in rolling windows;
   - check whether their gaps move with weekday holidays, when the core loses commuters and the valleys may gain leisure trips;
   - check that they show no response at 20:00 after April 2023.

   Keep the valleys if their forecast errors fall within the in-zone range.

5. The drift. Recommendation 6.
6. Spillovers. Recommendation 8.
7. Measurement. Recommendation 7, starting with the coverage screen.
8. Placebos. Replace the eleven pseudo-neighbourhoods with every donor tile, run through the identical pipeline and scaled by out-of-sample error (Recommendation 5).
9. Overall. As specified, no. With these changes, yes, as supporting evidence. A referee would object first that the counterfactual is an artifact. The fit is perfect, the weights are negative, more than half the weight sits outside the city, and the treated unit was redefined after inspecting fits. Next, the referee would note that Waze records reported jams, which fall when drivers leave the road even at unchanged speeds. Then power, because the closest studies, Anderson (2014) and Gu, Jiang, Zhang and Zou (2021), use high-frequency traffic data. State the congestion change the air-quality estimate would require, so readers can judge whether the test could detect it.

**What I would not do**

- Make ridge with a cross-validated penalty the primary estimator, or tune the penalty on the holdout. Both reward fitting noise, and the second spends your only out-of-sample check.
- Change the treated unit again. Keep the polygon as primary. The monitor coordinates in the spatial layer are rounded to 0.01 degrees, about a kilometre, so any monitor ring, BELISARIO included, needs exact coordinates from the Secretaría de Ambiente.
- Judge donor quality from the interpolating weights, such as the 56% outside the DMQ. Those weights are an artifact.
- Extrapolate the drift into P1 as a trend. Six months cannot pin one down.
- Scale placebo gaps by in-sample fit error, which rewards overfitting.
- Drop or keep the valleys without the tests under question 4.

**Information I would need**

- Whether weekly or daily values exist, and whether weekday holidays can be excluded from the averages.
- Coverage computed year by year, and whether the jam speed fields are clean.
- Substation blackout schedules and service areas for late 2023 and for April 2024, when another round of cuts took place. [primicias](https://primicias.ec/economia/inflacion-julio2024-ecuador-pasajes-avion-gasolina-75761)
- Confirmation from the AMT that the restriction's hours and zone did not change between April 2023 and August 2024.
- Bus route and feeder changes around the opening, and any trial or free-ride service before 1 December 2023.
- Street closures, pedestrian streets and works in the historic district from 2022 to 2024, which change the road-length denominator.
- The pre-period error of plain synthetic control for the new CENTER, and the augsynth cross-validation settings.
- How many DMQ tiles pass the saturation rule.
