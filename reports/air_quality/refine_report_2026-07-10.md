# Underground Relief: The Air Pollution Effects of Quito's First Metro Line

**Date**: 7/10/2026, 4:54:14 PM
**Domain**: Economics
**Taxonomy**: academic/research_paper
**Filter**: Active comments

---

## Overall Feedback

**Interpretation of the destination-access mechanism**

The paper identifies a fascinating empirical contrast between the historic-center station, Centro, and the equidistant non-center station, Belisario. However, the mechanism tracing this contrast strictly to destination access currently rests on a narrow empirical base. The empirical discriminator relies on finding an effect at one historic-center station versus a null effect at one non-center station, complemented by a sparse leave-one-station-out placebo exercise. Furthermore, Table 7 documents a decline in $\mathrm{PM}_{2.5}$ without corresponding post-opening divergences in $\mathrm{NO}_2$ and $\mathrm{CO}$, complicating a straightforward mode-substitution interpretation. Section 5.3 and the conclusion effectively acknowledge the absence of data regarding traffic speeds, ridership ramp-up, bus-route changes, or parking management; yet, the abstract and conclusion utilize strong language asserting a destination-based mode-substitution response. Supplying institutional evidence on transit channel dynamics—such as changes in street management or San Francisco station vehicle flows—or strictly narrowing the interpretation to a localized $\mathrm{PM}_{2.5}$ reduction consistent with destination access would align the narrative with the available data.

**Belisario's role in the causal design**

A pivotal structural feature of the local result is its dependence on Belisario in the donor pool. Table 5 demonstrates that Centro's statistically significant $\mathrm{PM}_{2.5}$ effect emerges prominently in the preferred specification that retains Belisario; excluding Belisario yields a larger, yet imprecise and non-significant point estimate in the pre-disruption window. Additionally, Table 6 indicates that Belisario itself exhibits a positive, albeit insignificant, $\mathrm{PM}_{2.5}$ estimate of 8.5 percent. This dynamic raises the possibility that Centro's synthetic path is structurally anchored by a localized positive shock at Belisario. Given that there are only seven potential $\mathrm{PM}_{2.5}$ donors, Belisario's untreated status and mathematical influence carry intense weight. Providing explicit donor weights, preferred-specification gap plots, leave-one-donor-out diagnostics, and a discussion regarding potential spillover or traffic reallocation estimands would clarify whether the result reflects a strict no-metro counterfactual or a localized relative contrast.

**Time-series calibration for conformal inference**

The statistical claims depend heavily on two-sided conformal $p$-values (e.g., 0.011, 0.041, and 0.006) derived from 52 pre-treatment weeks of weekly pollution outcomes. Given the setting's likely serial correlation, strict seasonality, and the gradual deepening of the post-opening effect depicted in Figure 5, the temporal independence assumptions warrant closer examination. Section 4 offers an intuitive explanation of conformal inference without fully detailing the specific conformity score, the exact treatment-effect shape tested, the handling of residual autocorrelation, or whether the pre-treatment prediction errors are plausibly exchangeable with the post-treatment prediction errors. While the spatial placebo exercise checks for geographic uniqueness, it cannot validate the temporal assumptions underlying the $p$-values. Incorporating residual diagnostics, pseudo-opening tests within the pre-treatment period, seasonally matched conformal variants, or sensitivity analyses to calendar controls would secure the foundation of the reported significance levels.

**Pre-disruption timing and unobserved local changes**

The paper logically motivates the pre-disruption window to bypass the late-2024 blackout and wildfire anomalies. Nevertheless, this nine-month span leaves open the possibility that historic-center policies or activity patterns shifted concurrently with the metro opening. The gradual deepening shown in Figure 5 aligns with passenger ridership ramp-up; however, it is equally consistent with coincident street works, bus-circulation changes, pedestrianization efforts, parking enforcement, or generic tourism recovery specific to the San Francisco and Centro areas. The currently estimated object might represent a bundled local intervention rather than the isolated metro-induced mode substitution emphasized in the introduction. Auditing contemporaneous historic-center policies and, where possible, aligning subperiod estimates with documented implementation milestones or ridership phases would isolate the metro's distinct contribution.

**Reconciling local mechanisms with citywide satellite results**

The citywide satellite analysis introduces an unresolved tension regarding the spatial scale of the effects. Table 8 reports a preferred citywide aerosol optical depth (AOD) decline of -0.113 log points, which closely mirrors the highly localized Centro $\mathrm{PM}_{2.5}$ reduction of -0.130 log points. Because AOD captures aerosol loading across the citywide atmospheric column rather than local surface exposure, a decline of this magnitude at a municipal scale is difficult to reconcile with a mechanism defined by its sharp spatial concentration in the historic center. This alignment implies either unexpectedly broad geographic spillovers or a form of shared, citywide confounding. The text characterizes the satellite analysis as complementary, but the abstract and conclusion deploy it directly as partisan corroboration. Given the raw donor imbalances in Table A.2, presenting post-weight pre-trend plots, donor weights, placebo-rank diagnostics, and residualization sensitivity would help parse the result. Alternatively, positioning the AOD decline strictly as a contextual non-contradiction rather than causal momentum for the historic-center mechanism would tighten the overall internal logic.

**Status**: [Pending]

---

## Detailed Comments (8)

### 1. Satellite timing is inconsistent in Table 1

**Status**: [Pending]

**Quote**:
> | Temporal resolution | Weekly averages of weekday peak-hour readings | Weekly satellite retrievals, aggregated to four-week blocks for estimation |
| Pre-treatment period | 52 weeks before the opening week | 100 weeks before the opening week |
| Post-opening windows | Pre-disruption, donut, and full | Pre-disruption, donut, and full |
| Panel size before estimation | $\mathrm{PM}_{2.5}$ : 8 stations × 116 weeks; gases: 7 stations × 134 weeks | Pollutant-specific balanced panels, with 227 weekly observations per city |

**Feedback**:
The citywide satellite time scale appears internally inconsistent. Table 1 says weekly satellite retrievals are “aggregated to four-week blocks for estimation,” while the data description, Table 4, the figures, and the “227 weekly observations per city” language all describe a weekly panel. This matters for interpreting the SDID time index, the 100-week pre-treatment period, and the alignment of the blackout/donut windows.

---

### 2. Appendix A.1 does not show the promised satellite diagnostics

**Status**: [Pending]

**Quote**:
> ## A. 1 Satellite coverage, imputation, and balance diagnostics

Table A.2. Satellite pre-treatment diagnostics for the preferred 100-city donor pool
| Variable | AOD | CO | $\mathrm{NO}_{2}$ | $\mathrm{SO}_{2}$ |
| :--- | :--- | :--- | :--- | :--- |
| Transformed outcome | 0.196 | -0.386 | 0.616 | -0.050 |
| Calm hours | 1.688 | 1.294 | 1.573 | 1.684 |
| Evaporation | 0.224 | 0.217 | 0.259 | 0.249 |
| Rain frequency | 2.242 | 1.739 | 1.971 | 2.025 |
| Relative humidity | 1.413 | 1.219 | 1.353 | 1.384 |
| Soil temperature | -2.364 | -1.935 | -2.405 | -2.540 |
| Soil moisture | 1.714 | 1.524 | 1.657 | 1.685 |
| Solar radiation | -1.365 | -1.269 | -1.333 | -1.352 |
| Surface pressure | -2.433 | -2.036 | -2.568 | -2.642 |
| Temperature | -2.465 | -2.077 | -2.569 | -2.652 |
| Precipitation | 1.656 | 1.277 | 1.353 | 1.369 |
| Wind direction | 2.140 | 2.162 | 2.152 | 2.158 |
| Maximum wind speed | -1.647 | -1.290 | -1.502 | -1.638 |
| Mean wind speed | -1.071 | -1.195 | -1.169 | -1.217 |


Notes. Entries are normalized pre-treatment differences between Quito and the preferred 100-city donor pool. Outcomes are transformed as in the estimation: $\log$ for $\mathrm{AOD}, \mathrm{CO}$, and $\mathrm{NO}_{2}$, and inverse hyperbolic sine for $\mathrm{SO}_{2}$. Weather covariates are weekly ERA5-Land controls. These diagnostics describe the raw donor pool before estimator weighting and residualization, so they should be interpreted as sample diagnostics rather than as final synthetic-control fit.

**Feedback**:
The text in Section 3.3 states that 'Detailed coverage, imputation, and balance diagnostics are reported in Appendix A.1.' Furthermore, the heading for Appendix A.1 is 'Satellite coverage, imputation, and balance diagnostics.' However, this appendix section solely contains Table A.2, which reports raw, pre-treatment normalized differences for the 100-city donor pool. The detailed statistics on coverage and imputation (beyond the summary in Table 4 and Figure 4) are missing, as are post-weighting balance diagnostics. Addressing this discrepancy by either providing the missing tables or modifying the cross-references and section titles will improve the clarity and transparency of the structural setup for the citywide analysis.

---

### 3. SO2 interpretation and summary conflict with window definitions in Introduction and Section 5.3

**Status**: [Pending]

**Quote**:
> $\mathrm{SO}_{2}$ behaves differently. It is close to zero and statistically insignificant in the pre-disruption window, but turns positive once later post-opening weeks are included. The donut estimate is 13.1 percent, with a two-sided conformal $p$-value of 0.055 , and the full-window estimate is 10.0 percent. This pattern is consistent with the diesel-combustion signature expected from widespread generator use during the late-2024 energy crisis. Rather than supporting a metro effect, the $\mathrm{SO}_{2}$

**Feedback**:
The $\mathrm{SO}_{2}$ interpretation appears to need clarification, and this issue also appears in the Introduction's summary of the $\mathrm{SO}_{2}$ results. Table 7's largest and most suggestive $\mathrm{SO}_{2}$ increase is in the donut window, which excludes the Sept. 16-Dec. 16 blackout and wildfire weeks, while the full window that retains those weeks is smaller and less precise. As written, this makes the attribution of the positive $\mathrm{SO}_{2}$ pattern to diesel-generator use during the late-2024 energy crisis insufficiently supported unless the estimate is being driven by transition/post-disruption weeks or persistent crisis-related effects outside the excluded disruption block.

---

### 4. Section 5.1: Belisario donor validity is overclaimed

**Status**: [Pending]

**Quote**:
> The second column treats Belisario as the affected station and excludes Centro from the donor pool. Belisario is almost as close to the metro corridor as Centro, but its estimates are small, imprecise, and not statistically significant in the clean windows. This first establishes Belisario as a placebo-treated station with no comparable response, which in turn supports using it as a valid donor for Centro.

**Feedback**:
The Belisario placebo diagnostic is somewhat over-interpreted here. The nonsignificant Belisario estimates support the view that Belisario does not show a comparable post-opening response, but they do not establish that Belisario is unaffected or fully valid as a donor, especially given its proximity to the metro corridor.

---

### 5. Belisario placebo comparison and validation claims in Sections 4 and 5.2

**Status**: [Pending]

**Quote**:
> Table 6 reports the station-level placebo estimates for the pre-disruption window. Because the placebo re-estimates every station, including Centro, through the same leave-one-out routine, the Centro estimate differs trivially from the configured estimate in Table 5. Centro is the only station with a statistically significant negative effect. Its estimated reduction is 12.2 percent, with a two-sided conformal $p$-value of 0.012 . Belisario, despite being almost equidistant from the metro corridor, has a positive and statistically insignificant estimate of 8.5 percent. This connects directly to the identification sequence in Table 5: the same station that anchors Centro's preferred counterfactual does not show a comparable response when treated as the exposed station.

**Feedback**:
The Belisario placebo comparison in Table 6 is not quite the same validation exercise as the Belisario-treated specification in Table 5. Table 6’s leave-one-station-out rule appears to include Centro in Belisario’s donor pool, whereas Table 5 deliberately excludes Centro when testing Belisario. Since Centro is the main treated location and is estimated to experience a $\mathrm{PM}_{2.5}$ decline, the positive 8.5 percent Belisario placebo estimate could partly reflect that donor-pool difference. This issue also applies to the text in Section 4, which claims the generic leave-one-out exercise validates Belisario as an untreated donor. The clean Belisario falsification is therefore the Centro-excluded estimate in Table 5, while the Table 6 row and the corresponding claims in Section 4 should be interpreted more cautiously as a network placebo diagnostic.

---

### 6. Abstract overstates spatial concentration finding

**Status**: [Pending]

**Quote**:
> The citywide analysis finds that satellite aerosol optical depth (AOD) moves in the same particulate direction, while satellite gas outcomes do not show a consistent pattern. The findings show that, in this setting, the air-quality benefits of a metro are concentrated at a destination where car access is difficult, a pattern that simple corridor proximity cannot explain. The results suggest that large transit investments may deliver stronger environmental gains when complemented by policies that make car access less attractive in dense destinations.

**Feedback**:
The abstract’s statement that the findings “show” metro air-quality benefits are concentrated at the historic-center destination is somewhat stronger than the evidence can establish. The local results show that the only statistically significant monitored-station $\mathrm{PM}_{2.5}$ reduction occurs at Centro and are inconsistent with a simple Centro-versus-Belisario proximity story, but the sparse monitoring network and negative citywide AOD estimates mean the full spatial extent of benefits is not established.

---

### 7. Section 4 blurs estimand and estimator

**Status**: [Pending]

**Quote**:
> For each treated unit, the object of interest is the average post-opening difference between observed pollution and the pollution path that would have occurred absent the metro:

$$
\tau_{i}=\frac{1}{T_{1}} \sum_{t \geq T_{0}}\left(Y_{i t}-\widehat{Y}_{i t}(0)\right)
$$

where $\tau_{i}$ is the treatment effect, $T_{0}$ is the week of the metro opening, $T_{1}$ is the number of postopening periods used in the estimate, and $\widehat{Y}_{i t}(0)$ is a synthetic counterfactual constructed from units not assigned to treatment.

**Feedback**:
The treatment-effect definition in Section 4 appears to mix the causal estimand with its estimator: $\tau_i$ is defined using $\widehat{Y}_{it}(0)$ rather than the untreated potential outcome $Y_{it}(0)$. This makes the object look estimator-dependent before augmented synthetic control and SDID are introduced as alternative ways to estimate the counterfactual path.

---

### 8. Table 2 note blurs Belisario’s proximity role

**Status**: [Pending]

**Quote**:
> ${ }^{\mathrm{a}}$ Straight-line distance from the monitoring station to the nearest Metro Line 1 stop.
Source: REMMAQ, Secretaría de Ambiente, Municipio de Quito. Stations are ordered by distance to the nearest metro stop. Centro is the main treated station in the local analysis. Belisario is the nearest station and the key comparison for distinguishing proximity from destination access. San Antonio reports $\mathrm{PM}_{2.5}$ only.

**Feedback**:
The Table 2 note appears to use “Belisario is the nearest station” imprecisely: Table 2 reports Centro as closer to a Metro Line 1 stop, at 0.61 km versus 0.77 km for Belisario. If Belisario is intended to be the nearest comparison or donor station, that distinction matters because the Centro–Belisario proximity contrast is central to the design.

---
