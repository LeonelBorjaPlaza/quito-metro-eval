# Expert consultation: estimating the Quito Metro's effect on traffic congestion

You are an applied econometrician with deep experience in synthetic control methods, difference-in-differences with spatial spillovers, and the evaluation of transport policy. A research team asks for your independent judgment on a design problem. Be critical. We do not want agreement with our current plan; we want the design you would defend before a demanding referee. If a recommendation depends on a fact you do not have, say so instead of assuming it. We cannot share the data, so treat the numbers below as given.

## 1. The question

Quito, Ecuador, opened its first metro line on December 1, 2023. It is one underground line of about 22 km with 15 stations, running north to south through the city. The team's main paper estimates the metro's effect on air pollution at monitoring stations. This analysis supplies evidence on the mechanism. Did the metro reduce traffic congestion, above all in the historic center, where narrow colonial streets and scarce parking make car trips costly? A second treated unit sits around the Belisario air monitor in north-central Quito.

## 2. Data

- Congestion data come from Waze through a data provider, aggregated to H3 resolution-8 hexagons (about 0.74 km² on average, about 84 ha in central Quito).
- The outcome is a congestion index: the congested road length reported by Waze divided by the cell's total OpenStreetMap road length. It is averaged over the weekday peak hours (7, 8, 9, 17, 18 and 19) and over the business days of each month, with days without a reported jam counted as zero. We use it in levels; logs are a secondary scale.
- A cell-hour without a Waze record is coded as zero congestion. The provider confirms this is their method, and warns that a missing record can mean free flow or simply no Waze users present.
- For each cell, the provider also reports the cumulative length of road on which Waze has recorded a jam since 2019. Its 2022 value, relative to OpenStreetMap road length, serves as a measure of how well Waze observes the cell ("coverage").
- We work with monthly values by cell and hour of day. We do not yet know whether daily or weekly values can be obtained.
- One field, severe-jam persistence, exceeds its logical maximum of 100 in some records, and the provider has not explained why. Our rule makes only the severe-jam outcomes missing in those cases; the main outcome is unaffected.

## 3. Current design

**Timing.**

- Pre-period: January 2022 to November 2023 (23 months), after the pandemic years.
- Holdout check: fit on January 2022 to May 2023, predict June to November 2023.
- Confirmatory window, P1: December 2023 to August 2024 (9 months). P2, from 2025 on, is secondary. September to December 2024 had nationwide scheduled power cuts.

**Units.**

- **CENTER.** The municipality's official historic-district polygon (513.6 ha). Fifteen H3 cells have road inside it. The unit's outcome is the average of the cells' indices, each weighted by the length of 2022 OpenStreetMap drivable road it has inside the polygon. Until recently, CENTER was instead the seven-cell ring (a cell and its six neighbours) around the Centro air monitor. We changed it because the mechanism of interest is the district's street network, not the monitor's location.
- **BELISARIO.** The seven-cell ring around the Belisario monitor, each cell weighted by its road length.
- **CORRIDOR.** Cells along the metro line, a secondary treated tier.
- **Buffer.** A ring of cells around the treated units, excluded from the donor pools.

**Donor pools** (cells far from the line and outside the buffer).

- Screened pool, 165 cells: those whose 2022 Waze coverage falls within the range spanned by the 14 cells of the two original monitor rings. Of the 15 new CENTER cells, 14 fall inside that range and one above it.
- Unscreened pool, about 270 cells.
- A low-exposure pool of cells more than 4 km from any station, as a sensitivity.
- Some donor cells lie outside Quito's metropolitan district, in neighbouring municipalities.

**Estimation and inference.**

- Ridge-augmented synthetic control (augsynth in R; Ben-Michael, Feller and Rothstein 2021), one treated unit per fit. CENTER and BELISARIO are fitted separately, and the difference of their gaps is a secondary contrast.
- Confirmatory inference is conformal inference (Chernozhukov, Wüthrich and Zhu 2021). With 32 periods, the smallest attainable p-value is 1/32. The confirmatory test is CENTER in P1 at the 5% level.
- Eleven pseudo-neighbourhoods built from donor cells serve as descriptive placebos, each gap scaled by its pre-period fit error.
- Nothing after November 2023 has been examined. Every check you propose must use pre-period data only.

## 4. What we found, using pre-period data only

**With the old seven-cell CENTER (an earlier step).**

- The cross-validated ridge penalty sat at the top of its grid in 5 of 8 fits, so the model was close to synthetic control with an intercept.
- Pre-period fit error (RMSPE) for CENTER was 0.114 with the screened pool and 0.217 with the unscreened pool, against a pre-period mean of 10.43.
- The holdout miss was about 0.68 with either pool. A simple difference-in-differences against the donor mean missed by about 1.2.
- All six holdout months fell below the prediction, by 0.47 to 0.59 on average. This is a drift before the opening.
- The minimum detectable effect is 1.90 index points if the model's errors persist from month to month, and 0.63 if they do not.

**With the new CENTER polygon.**

- Screened pool: cross-validation picks the smallest ridge penalty on the grid. The fit then reproduces the pre-period almost exactly (RMSPE 3.0e-7), with negative weights summing to -1.48. The choice is close to arbitrary, because 16 of the 21 grid values come within 5% of the best tuning error.
- Holdout, screened pool: plain synthetic control misses June to November 2023 by 0.749, and the ridge fit by 0.827.
- Unscreened pool: pre-period RMSPE 0.227, holdout miss about 0.99.
- In the ridge fit, about 56% of the signed donor weight sits on cells outside the metropolitan district.
- Drift: the synthetic fits put CENTER below its prediction in 5 of the 6 holdout months, and the corridor tier shows over-prediction too. A difference-in-differences against the donor mean gives the opposite sign. In the same months of 2022, CENTER's gaps change sign from month to month.
- Placebos: 5 of the 11 pseudo-neighbourhoods also fit almost perfectly (RMSPE below 0.001). Neither near-zero outcomes nor a placebo's own cells serving as its donors explain it; they interpolate as CENTER does.
- An internal methods review concluded that the model is not ready to freeze, because conformal inference is not well defined when the pre-period fit interpolates.

## 5. Local context that may matter

- **Driving restriction ("pico y placa").** On weekdays, private cars whose plates end in two given digits may not circulate inside a zone covering Quito's urban core. The zone is bounded by Av. Morán Valverde to the south, by Calle de los Narcisos, Av. Córdova Galarza and Av. Simón Bolívar to the north, by Av. Simón Bolívar to the east and by Av. Mariscal Sucre to the west. CENTER, BELISARIO and most of the metro line lie inside the zone. The suburban valleys (Cumbayá, Tumbaco, Los Chillos) and the neighbouring municipalities lie outside it. Before April 10, 2023, the restricted hours were 06:00 to 09:30 and 16:00 to 21:00. From that date the evening restriction ends at 20:00. The change came two months before the holdout window and applies only inside the zone. We have not checked for later changes.
- **Buses.** Bus services may have been adjusted around the metro's opening; we have not documented this yet.
- **Waze use.** Waze adoption may have grown unevenly across the city over time.

## 6. The team's working principles (challenge them if you disagree)

- **Spillovers are the main threat.** Car users who switch to the metro, and traffic diverted around stations, can affect areas near the line. We prefer to estimate effects for nearby areas as separate zones rather than assume them unaffected or drop them.
- **Trends, not levels.** Comparators should be judged by their trends and their exposure to the metro, not by their levels. Stable differences in level or in measurement are acceptable.
- **No unexplained dropping.** Data should not be dropped without a stated reason, because clean comparators are scarce.
- **The valleys.** The suburban valleys may be valuable comparators despite their different setting.

## 7. Questions

1. **The interpolating fit.** Why does the ridge fit interpolate for the new CENTER, and what would you do about it? Compare at least the options below, and add better ones if you know them. Which would you choose as primary, and why?
   - A ridge penalty fixed by a rule set in advance, such as the largest penalty within 5% of the best tuning error, or the one that minimizes holdout error.
   - Plain synthetic control, with or without an intercept.
   - Penalized synthetic control (Abadie and L'Hour 2021).
   - Fewer, larger donor units, for example cells aggregated into neighbourhoods or parishes.
   - Weights fitted on several outcomes at once, such as the morning peak, the evening peak and other hours (Sun, Ben-Michael and Feller 2023).
   - Higher-frequency data, if obtainable.
   - Other estimators, such as synthetic difference-in-differences, factor models or matrix completion.
2. **Choosing without bias.** How should the estimator be chosen without looking at post-opening data, so that the choice cannot be accused of searching for a result?
3. **Inference.** Is conformal inference still the right confirmatory tool? What exactly would you use instead or in addition, and what is the smallest attainable p-value under your proposal?
4. **Donor pool.**
   - Which pool: screened, unscreened or low-exposure?
   - Should cells outside the metropolitan district, or outside the pico y placa zone, be used?
   - How should the April 2023 schedule change be handled?
   - Can any pre-period check tell us whether the valleys are good comparators?
5. **The pre-opening drift.** Its sign depends on the comparison. How would you diagnose it with pre-period data? One example is the morning against the evening peak, since the April 2023 change touched only the evening. What rule, if any, would you fix in advance for the post-opening estimates?
6. **Spillovers.** How would you structure CENTER, CORRIDOR, the buffer and the donors so that spillovers are estimated rather than assumed away?
7. **Measurement.** Are there problems with the zero coding, the coverage screen, Waze adoption growth or the road-length weighting that you would fix first?
8. **Placebo neighbourhoods.** Given that some interpolate, how should they be built and scaled, or should they be replaced?
9. **Overall.** Is this design sound as mechanism evidence in an air-quality paper? What would a demanding referee object to first?

## 8. How to answer

- Start with a verdict of three to five sentences.
- Then give at most eight recommendations, most important first. For each, state:
  - the problem;
  - what to do, and why;
  - the pre-period checks to run;
  - the decision rule to fix in advance;
  - the main risk.
- Then answer questions 1 to 9 briefly, referring back to your recommendations where they overlap.
- Then list what you would not do and why, and the information you would need that we did not give.
- Cite methods papers where they support a recommendation. Do not invent citations; if you are unsure of one, say so.
- Aim for 1,500 to 2,500 words.

## 9. Optional: the internal review's points

The internal methods review raised nine major points, summarized below. Take them into account. Section, guard and amendment numbers refer to our internal analysis plan, which you have not seen.

1. The test statistic (mean absolute residual, sharp null) tests "no effect in any month", not the P1 average, and is unsigned. The plan does not name which null gives the confirmatory p-value. The smallest attainable p-value is 1/32 = 0.03125, so a 5 percent test rejects only at rank one.
2. The holdout drift runs in the hypothesis direction, and no drift rule exists. The holdout has been used many times without being recorded as model selection, as section 6 requires.
3. Amendments 2 to 4 do not record which results had been seen when each was decided. Amendment 3, item 1 (screened pool) gives a reason from the old ring unit. Amendment 4 entered in the same commit as the item D outputs.
4. Section 1's safeguard on mixed zeros was replaced once it was triggered. Section 9's statement that the screen guards road coverage no longer holds after provider answer 3. Measurement change works in the hypothesis direction.
5. Section 9a's bias signs assume non-negative weights, and they contradict section 9 ("the sign of the bias is not assumed"). Guard 3 must say whether weights are signed or absolute. Guard 1 uses stations, not the alignment.
6. The estimand no longer matches "Quito" or the "historic center's roads":
   - 0.56 of the weight lies outside the DMQ;
   - section 4 still gives equal cell weights;
   - CENTER mixes in-polygon weights with whole-cell values;
   - CENTER now contains station-access cells.
7. The contrast compares units built on different principles. Because CENTER interpolates, the contrast's pre-period residuals equal BELISARIO's. It has no defined p-value procedure, and localization is not tested.
8. The dropped-month rule leaves the disruption months, donor gaps, unit-specific gaps and P1 gaps open. The superseded "not adjacent" sentence is not struck.
9. The placebos collapse in the primary pool: the fit filter keeps only an interpolating placebo, and the floor is degenerate. The v2 placebo text still says "non-overlapping".
