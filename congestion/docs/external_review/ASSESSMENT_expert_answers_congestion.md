# Assessment of the outside expert answers on the congestion design

As of October 1, 2026. This note compares the three answers saved in EXPERT_ANSWERS_congestion.md (Astra 6 ultra, ChatGPT Sol 6.1 ultra and Fable 5.1) with our current plan, and proposes what to change.

## Bottom line

All three experts reach the same verdict: do not freeze the current model. The near-perfect fit comes mechanically from having far more donor cells than months; it is not a sign of a good match. All three propose the same core fix, a less flexible model built from larger donor units and chosen by how well it forecasts months it has not seen. All three would present the result as evidence consistent with the mechanism, and as a confirmatory test only if measurement and forecasting checks pass.

Our draft choice of estimator survives: synthetic control with an intercept and weights that are zero or positive. Our plan lacked four things that all three ask for:

- donor units built like CENTER;
- a forecasting contest to choose the estimator;
- a fix, or an honest label, for what the outcome measures;
- a calendar of shocks.

Two of our own ideas did not survive. The morning-against-evening test for pico y placa was wrong, because the April 2023 change touched only 20:00 to 21:00, outside the measured hours. And the principle "trends, not levels" is too broad as stated. It holds for stable additive differences, but a lower Waze detection rate scales reported congestion down by a proportion, and so do many shocks. That argues for comparing proportional changes, as we already decided for crashes.

## Where all three agree

| Topic | What they say | What it changes |
|---|---|---|
| The interpolating fit | With 165 donors against 23 months, signed weights can copy almost any path. An exact fit is not an achievement. | Ridge with a cross-validated penalty cannot be the primary estimator. |
| Primary estimator | Synthetic control with an intercept, weights zero or positive and summing to one. Ridge only as a sensitivity, with the largest penalty within 5% of the best forecast loss. | Confirms our draft. |
| Donor units | Aggregate single cells into larger, predefined, non-overlapping units with similar road networks. Fable proposes H3 resolution-7 tiles of seven resolution-8 cells each. | New: fewer, steadier donors, built like CENTER. |
| Choosing the estimator | Fix a small menu in advance and score it by rolling-origin forecasts. The June to November 2023 holdout has been used too often to count as clean validation. | New: replaces choosing by CENTER's own fit. |
| What the outcome measures | Weighting whole-cell indices by in-polygon road length does not measure the district's streets. Either obtain jam lengths clipped to the polygon, or call the outcome a road-weighted index of the hexagons that cover the district. | New request to the provider, or a relabel. |
| Waze observation | Fewer drivers after the opening means fewer Waze users reporting, so a fall in reported jams may partly reflect fewer observers. This is an identification problem. | New: ask for observation data, and describe results as reported congestion unless it arrives. |
| The coverage screen | Cumulative "ever jammed" length mixes congestion with observation, and its range came from the old monitor rings. | Replace the inherited screen. |
| Pico y placa in April 2023 | The change removed the restriction between 20:00 and 21:00. Hours 17 to 19 stayed restricted, so morning against evening does not test it. | Our test was wrong. Fable proposes hours 20 and 21 as a positive control. |
| Conformal inference | Keep it only on a model that cannot interpolate, with the statistic named: the absolute value of the average P1 residual, with circular shifts. The smallest p-value is 1/32, so a 5% test needs the most extreme rank. | Names the test, as we asked for crashes. |
| Placebos | Build them like CENTER, keep each placebo's own area out of its donors, scale gaps by out-of-sample forecast error, and treat them as descriptive. | Fixes the degenerate scaling. |
| Drift | Neither subtract it nor extend a trend in the main estimate. Diagnose it, and report how a continuing drift would change the conclusion. | Confirms our draft rule. |
| The smallest meaningful effect | Decide now how large a fall in congestion would matter for the air-quality argument, and use it to judge forecast quality. | New decision for you. |

## Where they differ

| Topic | Astra | ChatGPT | Fable | My view |
|---|---|---|---|---|
| Scale | Multiplicative measurement differences distort trends. | "Trends, not levels" is too broad. | Fit in proportions if a pre-period test shows that units with higher congestion swing more; settle this first. | Adopt Fable's test, decided before anything else. |
| Main donor pool | Prefer donors under the same driving restriction; valleys and other municipalities as separate checks. | Prefer donors inside the restriction zone if enough exist; others as checks. | District tiles as the main pool, valleys included and tested three ways; other municipalities only if fewer than 20 district tiles qualify. | Fable's. The zone hugs the line, so few unexposed tiles exist inside it, and the measured hours were restricted throughout. Count the in-zone tiles to confirm. |
| Spillovers for CENTER | A central issue; separate zones identify only relative effects. | The same. | Not the main threat for CENTER; the counterfactual and coincident shocks matter more. | Fable's, for CENTER. Spillovers still matter for the corridor and for donors near feeder routes. |
| Drift | Never subtract it to improve the result. | A persistent-bias sensitivity calibrated from forecast errors. | Report an anchored estimate and a breakdown multiple beside the main estimate; claim the mechanism only if they agree in sign. | Fable's rule, reported beside the main estimate and never instead of it. |
| Weekly data | Request early. | Request early. | If it arrives before the freeze, it becomes the primary panel. | Fable's. It is the largest gain in information available. |
| Extra outcome | None. | None. | A secondary outcome from jam speeds, which depend less on how many users report. | Worth asking the provider. |
| Rings | Disjoint zones. | Disjoint zones. | Rings by distance; read CENTER as a metro effect only if ring estimates shrink with distance. | Fable's gate is simple and persuasive. |

## Facts checked

- **Rationing from October 27, 2023.** Confirmed. Daytime cuts of about four hours a day in the Sierra, with Quito windows of 08:00 to 12:00, 12:00 to 16:00 and 16:00 to 18:00. The last window overlaps the evening peak. The cuts were expected to end around Christmas and were suspended at times; the government declared them over on February 23, 2024. They fall in the last weeks of the holdout and in December 2023, the first treated month.
- **April 18 and 19, 2024.** Confirmed. The government suspended work, and Quito lifted pico y placa on both days, during the April power cuts.
- **The national strike of June 2022.** Confirmed: June 13 to 30, 2022, inside the pre-period.
- **Not verifiable from here.** Fable cites material that was not in the prompt: "the September descriptives", a "saturation rule", jam-speed and fast-road fields in the delivery, the paper's weekly panels, and monitor coordinates rounded to 0.01 degrees. If Fable has your project files, these can be checked against them. If not, treat them as unverified.

Sources: [Bloomberg Línea, October 26, 2023](https://www.bloomberglinea.com/latinoamerica/ecuador/horario-de-los-apagones-en-ecuador-de-cuanto-seran-y-hasta-cuando/); [Quito Informa, October 27, 2023](https://www.quitoinforma.gob.ec/2023/10/27/horarios-de-cortes-de-energia-en-quito-por-disposicion-del-gobierno-nacional/); [Primicias, February 23, 2024](https://www.primicias.ec/noticias/economia/noboa-cortes-luz-apagones-electricidad/); [Primicias, April 2024 work suspension](https://www.primicias.ec/noticias/economia/suspension-gobierno-trabajo-ecuador-noboa-abril/); [Ecuavisa, pico y placa lifted on April 18 and 19, 2024](https://www.ecuavisa.com/amp/noticias/quito/apagones-pico-placa-se-suspende-jueves-18-viernes-19-abril-CL7184455); [Expreso, the 2022 national strike](https://www.expreso.ec/actualidad/paro-nacional-2022-ecuador-movilizaciones-acuerdos-protestas-205356.html).

## The revised plan

1. **Scale.** Settle it first with Fable's pre-period test: across donor units, regress the log volatility of monthly changes on the log pre-period mean. Fit in proportions if the slope exceeds 0.5, and in levels otherwise.
2. **Donor units.** Build H3 resolution-7 tiles from cells that meet a documented quality rule, with each tile's index computed as total jam length over total road length. District tiles outside the buffer form the main pool, valleys included. Tiles in neighbouring municipalities are a check, and join the main pool only if fewer than 20 district tiles qualify.
3. **Estimator contest.** The menu is fixed in advance:
   - synthetic control with an intercept, fitted on the morning and evening peaks together (the default);
   - synthetic difference-in-differences;
   - ridge with the largest penalty within 5% of the best;
   - difference-in-differences against the tile mean.

   Score them by rolling-origin forecasts on placebo tiles. The default stands unless another estimator lowers forecast error by at least 10%.
4. **Calendar.** Record the June 2022 strike, the rationing from October 27, 2023, the curfew of January 8 to April 6, 2024, the cuts of April 16 to about May 1, 2024 with April 18 and 19 off work, and the fuel price rise of June 28, 2024. Leave the strike and the rationing months out of the weight fit, and report P1 with and without December 2023.
5. **Checks.** Use hours 20 and 21 as a positive control for April 2023, run the three valley checks, and compute rolling forecast errors for each distance ring.
6. **Inference.** Use the absolute average P1 residual with circular shifts, plus CENTER's rank among placebo tiles and the Cattaneo, Feng and Titiunik prediction intervals. The test is confirmatory only if the placebo tiles reject at no more than 10% at pseudo-openings.
7. **Outcome label.** Unless clipped jam lengths arrive, call the outcome a road-weighted index of the hexagons covering the district. If observation shifts, describe any fall as fewer reported jams.
8. **Freeze.** Commit the code, then go to Step 2.

## Decisions for you

1. **Scale.** Adopt Fable's pre-period test. Recommended.
2. **Main donor pool.** District tiles including the valleys, tested (recommended), or tiles inside the restriction zone only.
3. **The smallest congestion change that matters.** It sets the forecasting standard. I can propose a value from the air-quality estimates and the literature (Anderson 2014; Gu, Jiang, Zhang and Zou 2021).
4. **Requests to the provider.** These are worth sending now:
   - weekly or daily values;
   - jam lengths clipped to the district polygon, or segment-level jams for its cells;
   - coverage computed year by year;
   - any measure of Waze users or reports by cell and month;
   - jam speeds;
   - hour labels, and data for hours 20 and 21;
   - the still-missing explanation of severe persistence above 100.
5. **Framing.** Supporting evidence consistent with the mechanism; confirmatory only if the checks pass. Recommended.
6. **Monitor coordinates.** Ask the Secretaría de Ambiente for exact coordinates, if Fable's claim about rounding holds.

## Decisions taken (October 1)

1. **Scale.** Settle it first with Fable's test.
2. **Main donor pool.** District tiles, valleys included and tested (Fable's approach).
3. **Smallest meaningful effect.** Not fixed. The sign is what matters. The session reports, before any post-opening month is loaded, the smallest effect whose sign the design could detect, taken from nine-month forecast errors on placebo tiles. If the monthly data cannot sign a plausible effect, the analysis stops with an explanation, and Leonel works with the provider on finer data.
4. **Provider.** No requests for now. One solid attempt with the data as delivered, so that any later request asks for exactly what is needed.
5. **Framing.** Not a concern for now.
6. **Monitor coordinates.** Not needed. The published coordinates (for example, Mejía and others 2024, Heliyon, Table 1) are themselves rounded to 0.01 degrees: Belisario at 0.18° S, 78.49° W and Centro at 0.22° S, 78.51° W. A light check of Belisario's street address is enough.
