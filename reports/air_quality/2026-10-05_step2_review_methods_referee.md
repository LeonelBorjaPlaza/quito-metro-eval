# Methods referee: step 2 results memo

Report of the `methods-referee` agent on `reports/air_quality/2026-10-05_step2_results.md` (draft before `aad1942`), 2026-10-05, saved word for word by the maker. Its interpretive findings are worked into the memo. The claims-auditor later found that some points (the gap path, the Belisario estimand) also hold for the frozen outputs, and the memo now says so. The new analyses it proposes are listed as suggestions in memo section 8 and were not run.

---

## Methods referee report: step 2 results memo (air_quality, workstream A)

**Version reviewed.** `/home/leonelb/projects/quito-metro-eval/.claude/worktrees/aq-revision/reports/air_quality/2026-10-05_step2_results.md`. The memo and `air_quality/output/local/step2/paper_number_map.csv` both changed while I was reviewing them: section 7 now says "308 printed numbers", and the map's header gained `frozen_rounded` and `note`. My comments refer to the latest version I read. The claims-auditor should work from a committed version. I edited nothing and read no raw hourly records.

**Overall.** The memo's numbers match the files I opened. It ran exactly what the plan specified and nothing more. The main problems are in interpretation and in what it leaves out, not in the estimates. Nothing here is CRITICAL. There are six MAJOR findings.

### Short answers to your five questions

1. **Pre-specified and nothing added?** Nothing was added: no new specification, window or donor rule. Several required items are dropped or only partly reported:
   - Check 4.4 is not placed first and does not give the sign.
   - Leave-one-donor-out p-values are missing.
   - Autocorrelation is shown at lag 1 only (the plan asks for lags 1 to 4).
   - Gas block p-values have no floors.
   - Sensitivity rows are missing.
   - Figures 2 and 5 are not in the paper-number map.
2. **Inference.** The mechanics are right, and the floors are correct where they are stated. The interpretation of the pseudo-openings goes further than the evidence (M2). The memo does not say that the block p-value at its floor supports the pre-disruption rejection (M2). "Evidence weakens" in the donut and full windows is likely to be misread (M3).
3. **Main conclusion.** It leads with the result and its sign. Two things are missing: the pre-disruption effect is concentrated in the last 12 weeks of its window (M1), and Belisario's weight plus its now-negative estimate change what M8b measures (M4).
4. **S1, S4 and the noise caveat.** S1 is described correctly but its two changes are not disentangled. The memo never says that S4 moves the treatment week. The noise formula is right as stated.
5. **Before the paper.** See M1 to M6 and the requests under each.

---

## MAJOR

**M1. The pre-disruption estimate comes mostly from June to September 2024. Neither the memo nor the paper says so.**
- **Where:** memo brief bullet 1 and §5 (the gap plots are listed but not described). File: `air_quality/output/local/step2/diagnostics/gaps_M8b_full_PM25.csv`.
- **Why the gaps give the estimate:** the M8b fit uses only the pre-period, so the pre-disruption estimate is the mean of the 42 post gaps in weeks 53 to 94. From the file I get -0.1307, which matches.
- **What the gap path shows:**
  - The 12 weeks from 2024-06-24 to 2024-09-09 average about -0.385 log points and make up about 84 percent of the sum.
  - The first 30 post weeks, 2023-11-27 to 2024-06-17, average about -0.03.
  - Seven of the first eight post weeks are positive, between +0.04 and +0.27.
  - The largest gaps sit just before the window ends: -0.52 (2024-08-19) and -0.64 (2024-09-09).
- **Consequences:**
  - (a) Paper lines 592-602 no longer hold as written: "move below zero during the first months of operation", "not driven by a single post-opening week" and "gradual deepening".
  - (b) The onset falls in the drought and dry-season months the paper itself describes (lines 157-162). A shock that hits Belisario's area differently from Centro's would move the gap without any Metro effect. With only one dry season in the pre-period, a seasonal divergence between Centro and Belisario cannot be separated from a delayed effect. The 2023 dry season (2023-06-26 to 2023-09-18) has a mean gap of about -0.04, which helps, but it is a single year.
  - (c) Ecuador also had rolling power cuts in April 2024. The gaps are -0.31 and -0.27 in two April weeks. The paper does not mention these cuts; confirm and cite them.
- **Caution on rule 6:** these are readings of the authorized gap plot, not effect estimates. Any claim about a sub-period effect needs its own approved window, estimated separately.
- **What would change my mind:** the raw weekly Centro and Belisario series (levels, not gaps) for mid-2023 to September 2024, showing that Centro fell rather than Belisario rose. Failing that, an approved window ending before late June 2024. The triple difference partly answers this already: in the pre-disruption window it is -11.4 percent, similar to M8b, and it nets out shocks that affect all hours equally. The memo should say so.

**M2. "Oversized" is asserted, but the diagnostics cannot tell test size apart from a real shock at Centro before the opening, and the block test points the other way.**
- **Where:** brief bullet 3 and §5. Files: `pseudo_openings_M8b_PM25.csv`, `acf_gaps_M8b_PM25.csv`, `block_conformal_PM25.csv` and the gaps file, all under `step2/diagnostics/`.
- **The 13 pseudo-openings are nested, not 13 draws.** Every pseudo-post window ends at week 52, so all of them contain the weeks from 2023-09-25 to 2023-11-20. The 8 rejections in 13 are closer to one episode counted many times than to an estimate of size.
- **Those weeks include the 2023 rationing weeks.** In the main fit the gaps there are +0.26 (2023-10-23), +0.34 (2023-10-30) and +0.22 (2023-11-13). The pseudo-effects grow as the fake opening approaches them, reaching +0.160 at week 44.
- **A correctly sized test should reject a real Centro-specific shock.** So the result fits two readings equally well, and they need different fixes:
  - an identification problem: shocks of this size happen at Centro without the Metro;
  - an inference problem: the test rejects too often.
- **Evidence against oversizing:**
  - PM2.5 pre-period autocorrelation is 0.076 at lag 1 and 0.059 or less at lags 2 to 4.
  - The block test, which allows for serial dependence, gives the pre-disruption window its smallest attainable p, 1/94. Bullet 3 lists this p but files it under "calls into question" without saying it supports the rejection.
- **The test reacts to volatility, not only to level.** At week 30 the pseudo-effect is +1.4 percent with p = 0.025. The same applies to the headline: p = 0.016 rejects "no effect in any week", not "average effect is zero". The memo makes this point only for S1.
- **The spatial placebo shows the same pattern** (`placebo_old_vs_new.csv`):
  - M8b, pre-disruption: Cotocollao rejects at 5 percent (+5.2 percent, p = 0.047).
  - M5b: Tumbaco is -28.7 percent with p = 0 in both runs, and Cotocollao has p = 0.038.
- **What would change my mind:** two new diagnostics, each needing Leonel's approval: pseudo-openings on the S4 panel (rationing weeks dropped), and pseudo-openings with block conformal p-values.
  - If the iid rejection rate falls to near nominal without the rationing weeks, the 2023 shock is the explanation.
  - If block pseudo-openings also reject often, the block floor in the real test is no reassurance.

**M3. "The evidence weakens" in the donut and full windows reads as "the effect fades". The added weeks are more negative, not less.**
- **Where:** brief bullet 2 and §2. File: the gaps file.
- **The added weeks:** the 7 restored January-February 2025 weeks average about -0.14. The 11 April to June 2025 weeks average about -0.21. Both are below the pre-disruption mean of -0.131, yet the donut p rose from 0.041 to 0.199.
- **A likely reason:** once the post window is longer than the pre-period (68 of 120 weeks in the donut, 82 of 134 in the full window), a random permutation fills the "post" slot mostly with true post weeks. A sustained shift then loses power. If augsynth's refit under the null also re-estimates the unit fixed effect over all weeks, part of the shift is absorbed as well. I could not check augsynth's internals because the installed package is compiled.
- **Two changes are mixed together:** the memo does not separate the new data vintage from the 18 added weeks. The pre-disruption window, whose length did not change, shows the vintage alone moves little.
- **What would change my mind:** a sentence saying the added weeks have the same sign and larger gaps. With approval, also either the new-vintage donut and full windows cut at the old end date, or a small simulation of conformal power as the post window grows relative to the whole sample.

**M4. Belisario's weight and its sign change alter what M8b estimates and weaken the paper's argument. The memo reports the facts but not what follows from them.**
- **Where:** brief bullets 4-5, §3 and §5. Files: `sensitivities_long.csv`, `placebo_old_vs_new.csv`.
- **M8b is close to a two-station comparison.** With Belisario at 0.849, it is essentially Centro relative to Belisario.
- **Belisario's estimate is now negative:** M9 gives -6.1 percent, p = 0.737. That is not evidence of "no comparable response", the claim at paper lines 608-612 and 679-681 and in the corridor-versus-destination logic at 588-589. Belisario's own fit (pre RMSPE 0.190) cannot detect an effect of that size.
- **The three pre-disruption estimates fit one story.** M8 (Centro against the other stations) is -0.188. M9 (Belisario against the others) is -0.063. M8 minus 0.85 times M9 is about -0.135, close to M8b's -0.131. That is consistent with both stations near the line falling, Centro by more. If so, M8b measures Centro's effect net of Belisario's, which understates Centro's own effect.
- **The old +8.5 percent was contaminated.** Centro carried 0.731 of Belisario's synthetic in the old placebo, as plan 3A.3 item 2 anticipated. The paper printed both -6.0 (Table 5) and +8.5 (Table 6) for Belisario and its text used the positive one.
- **Distance:** the known issue on Belisario's distance (1.04 to 1.44 km rather than 0.77 km) bears on "similarly close".
- **What would change my mind:** a paragraph that:
  - states the estimand as Centro relative to a counterfactual that is mostly Belisario;
  - acknowledges that significance rests on that comparison (M8 has p = 0.431);
  - qualifies the paper's "Belisario shows no response" step.

**M5. The paper-number map departs from plan 4.3.**
- **Where:** memo §7 and `paper_number_map.csv`.
- **What is missing:** plan 4.3 lists Tables 2, 3, 5, 6, 7, A.1 and A.3, Figures 2 and 5, and the text of the abstract and sections 5.1 to 5.3. The map has no Table 2, Figure 2 or Figure 5 rows. §7 does not list:
  - the Figure 5 narrative at lines 592-602 (see M1);
  - the Figure 2 text at lines 315-318;
  - the reasoning at lines 608-612 that depends on Belisario's sign (see M4).
- **Table 2** is probably unchanged (distances and pollutant check marks); the memo should say so explicitly.
- **What would change my mind:** map rows, or explicit statements, for Table 2 and Figures 2 and 5, plus these text lines in §7.

**M6. Multiple tests are not acknowledged.**
- **Where:** the brief and §2. File: `sensitivities_long.csv` (main rows).
- **The count:** of the 12 M8b pollutant-by-window tests in the main run, one has p ≤ 0.05 (PM2.5 pre-disruption) and one more has p ≤ 0.10 (PM2.5 full). The paper also chose its preferred specification partly because it is the significant one (line 624).
- **What would change my mind:** one sentence giving this count beside the headline.

## MINOR

1. **Check 4.4 (plan 4.4.3).** The plan requires it before any estimate, with the sign first. The memo puts it last in the brief and gives no sign.
   - From `step2/sa_imputation_check_summary.csv`, mean signed difference (with minus without Los Chillos): -0.597 in the pre-period (3 weeks), +0.019 from December 2023 to September 2024 (3 weeks), +0.195 from October 2024 on (13 weeks), +0.042 overall (19 weeks).
   - Largest absolute difference: 2.336. No week changes by more than 10 percent.
2. **Sensitivity table is incomplete** against plans 3A.2 and 4.3. `sensitivities_long.csv` has rows the memo omits:
   - full-window rows for M7, M8 and M9;
   - full-window rows for every gas;
   - pre-disruption rows for the gases under S3 and S4.

   Two of the omitted cells are among the few small p-values: S1 NO2 full (-11.6 percent, p = 0.001) and S1 SO2 full (+1.0 percent, p = 0.035). Leaving them out looks selective even if it was not.
3. **S1.**
   - The memo states both changes, the donor pool and the window, but not that a difference from the main result cannot be attributed to either one.
   - Leave-one-donor-out helps. Dropping Guamaní barely moves PM2.5. It turns CO positive (+5.4 percent pre-disruption, the memo's own §5), so CO's S1 sign flip (+10.8 percent) is plausibly the donor change.
   - The S1 pre-disruption estimate was computed (verifier report) but, by the plan, not reported. It would isolate the donor change at a fixed window, but reporting it needs Leonel's approval.
   - The S1 NO2 rejection (p below 0.001) comes from a period with long outages at Centro's NO2 monitor, a typical sign of an instrument change. Ask for the S1 NO2 gap plot before giving that p any weight.
4. **S4.**
   - The memo never says that S4 also moves the treatment week to 2023-12-18 and cuts the pre-disruption sample to 47 pre and 39 post weeks (verifier panel table).
   - It also removes the positive late-2023 gaps: pre RMSPE falls from 0.129 to 0.113.
   - Its agreement with the main result (-12.5 percent, p = 0.018) is real evidence against the rationing weeks driving the result. Say so and link it to M2.
5. **Leave-one-donor-out p-values** (plan 3A.3 item 4), from `step2/diagnostics/loo_centro_M8b_PM25.csv`, for the six non-Belisario drops:
   - pre-disruption: 0.005 to 0.029;
   - donut: 0.126 to 0.239;
   - full: 0.069 to 0.108.

   These support robustness and belong in the table. For the gases the memo gives highlights, not ranges.
6. **Autocorrelation** (plan item 6 asks for lags 1 to 4).
   - PM2.5 post-period lags 2 to 4 are 0.35, 0.38 and 0.32. That slow decay looks like a level shift.
   - Gas pre-period lag-1 values of 0.33 to 0.46 make the iid test questionable for the gases too. No conclusion changes, since no gas result is significant.
7. **Block table.** The gas row has no floors (plan item 8).
8. **Triple difference.**
   - With 6 placebos the floor is 1/7 (0.143), so the test cannot reject even at 10 percent. "Not distinguishable from its placebos" is therefore not evidence against an effect.
   - Better wording: Centro ranks second of seven. One control has a larger negative value: placebo minimum -0.131 against Centro's -0.121 pre-disruption, controls A (`step2/ddd_centro.csv`).
   - Name that station. If it is Los Chillos, its timing shift cannot explain the pre-disruption value, because the window ends before the shift.
   - Note that Centro has 41 and 81 post weeks here, against 42 and 82 in the main panel.
9. **Spatial placebo claim.** "Centro is the only station with a significant negative estimate" holds under M8b only; Tumbaco has p = 0 under M5b. Also, Carapungo's synthetic puts a weight of 1.12 on Cotocollao, i.e. extrapolates. The placebos have no pre-set rule for excluding poorly fitted stations.
10. **Simulation noise.**
    - The formula is right for one p-value. A difference between two independent runs has a standard error about √2 times larger.
    - At the headline (p = 0.016) the standard error is about 0.004. The memo prints 0.016, 0.013 and 0.021 for the same estimate, and the paper printed 0.011; these are all the same result. Say so in one line.
    - The S2a donut difference (0.094 against 0.199) is not noise.
    - With approval, consider more permutations for the headline p-values in the paper, so that three-decimal values are stable.

## WORDING

- "0.0106" suggests false precision; write "1/94 (0.011), the smallest attainable value".
- Put the iid floor (0.001) next to the headline p in the brief and in every paper table note, not only in the opening paragraph (rule 6).
- "p = 0.000": a permutation p-value cannot be zero (`docs/known_issues.md`). Write "p < 0.001 (0 of 1,000 permutations)".
- Brief, sensitivities bullet: say "PM2.5 M8b" before "every sensitivity keeps a reduction"; M7 and M9 do not.
- "is therefore oversized" should become "may be oversized, or Centro had a real pre-opening shock" (M2).
- §5 autocorrelation: add "or an effect that begins in mid-2024".
- "Dropping Belisario gives -17.2 percent, p = 0.406": this is M8 by construction, with a reseeded p (0.431 in Table 5). Say so.
- S4 column header: add "(treatment week 2023-12-18)".
- §7 abstract item: qualify "only station" with "under M8b" and mention Cotocollao's p = 0.047.

## Overall judgment

The numbers are reproducible and the run followed the plan. The pre-disruption point estimate (-12.2 percent) is stable across the new data vintage, S3, S4 and every leave-one-out drop except Belisario's. It is fair to report it as unchanged.

What the memo needs before these numbers go into the paper is mostly interpretation. The effect is mostly a Centro-versus-Belisario divergence that opens in mid-2024, not a shift at the opening. Both stations near the line now point downward. The pseudo-opening result is better read as evidence of a large Centro-specific deviation before the opening, around the 2023 rationing, than as proof that the test rejects too often; the block test still gives its strongest possible answer. The weaker donut and full p-values come with negative added weeks and should not be read as the effect fading.

I would let the numbers go forward once M1 to M6 are addressed in the text. Separately, Leonel should decide whether to approve two new diagnostics (pseudo-openings on the S4 panel and with block p-values) and the raw Centro and Belisario series around mid-2024.
