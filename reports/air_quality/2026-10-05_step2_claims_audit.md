# Claims audit: step 2 results memo and paper-number map (aad1942)

Report of the `claims-auditor` agent on the memo and map committed at `aad1942`, 2026-10-05, saved word for word by the maker. Its corrections are applied in the next commit, with one exception: it counted 18 map rows with notes, but the map has 16 (12 + 2 + 1 + 1). The memo line numbers below refer to the `aad1942` version.

---

**Verdict.** Every number in the memo and the map traces to a committed output file. I found no wrong rounding and no wrong percent conversion: every `att_pct` and `ddd_pct` in the source files equals 100*(exp(log)-1) to within 3e-14. The map's `frozen_rounded` column matches the printed paper on all 308 rows. The only exception is the one already flagged: Table A.3, M8 donut. The frozen value is -0.15346, so -0.153 is right and Table A.3's printed -0.154 is the typo. Two problems need fixing before this goes out:
- **Misattribution.** Several of the memo's main interpretive points blame the new data for things that were already true of the frozen outputs.
- **Gaps in section 7.** It leaves out paper statements that the new numbers do contradict.

None of the numbers is stale: every source output was last committed in 606ea82, before the memo, and the paper text was last committed on 2026-09-24. The memo quotes no Wald or pnorm p-values.

### Claim table

| ID | Claim (memo line or map row) | Class | Source (file:row:column) | Note |
|---|---|---|---|---|
| C1 | Check 4.4: 19 weeks, 15 in the panel; differences -0.60 / +0.02 / +0.20; none above 10 percent (L15-21) | SUPPORTED | step2/sa_imputation_check_summary.csv | |
| C2 | M8b pre-disruption -0.131, -12.2%, p 0.016; paper -0.130, 0.011 (L22) | SUPPORTED | step2/main_old_vs_new.csv:M8b,pre_blackout | |
| C3 | Only 1 of 12 M8b tests has p ≤ 0.05; one more has p ≤ 0.10 (L23) | SUPPORTED | main_old_vs_new.csv, M8b rows | |
| C4 | "Paper chose M8b partly because it is significant (line 624)" (L24) | OVERSTATED | paper:624-628 | Line 624 says the specification "delivers" the significant effect and the best fit. It gives no motive. |
| C5 | Gap path: 42 gaps average -0.131; last 12 average -0.385 and carry 84%; first 30 average -0.029; 7 of the first 8 positive (L25, L177-181) | SUPPORTED as description | step2/diagnostics/gaps_M8b_full_PM25.csv | The same numbers hold in the frozen run (see F2). |
| C6 | Donut -13.7% (0.199), full -15.6% (0.097); paper values (L26) | SUPPORTED | main_old_vs_new.csv | |
| C7 | Added weeks average -0.141 (7 weeks) and -0.212 (11 weeks); "higher p-values do not come from a fading effect" (L27) | Numbers SUPPORTED; conclusion OVERSTATED | gaps_M8b_full_PM25.csv | Built from slices of the full-window vector. Line 28 itself says the cause is not established. |
| C8 | Pseudo-openings 8/13 rejections; rates 0.615 / 0.769 / 0.077; PM2.5 and gases table (L29, L236-241) | SUPPORTED | pseudo_openings_M8b_summary_*.csv | |
| C9 | "the block test does not share its worry" (L29) | OVERSTATED | block_conformal_PM25.csv | The block test was not run on pseudo-openings; suggestion 2 says so. |
| C10 | Block p 1/94; ACF values (L32, L224-227) | SUPPORTED | block_conformal_*.csv; acf_gaps_M8b_*.csv | |
| C11 | "Belisario's own estimate is now negative" (L33, L319) | OVERSTATED (misattributed) | main_old_vs_new.csv:PM25,M9,pre_blackout | M9 was already -6.0% (p 0.729) in paper Table 5. Only the Table 6 placebo changed sign, and that came from the new donor rule. |
| C12 | Weight 0.849; M9 -6.1 (0.737); M8 -17.2 (0.431) (L34-36) | SUPPORTED | donor_weights_main.csv; main_old_vs_new.csv | |
| C13 | The paper's step "Belisario shows no comparable response" "no longer holds as written" (L37) | OVERSTATED, misquoted | paper:608-612, 668 | M9 barely moved. The quoted phrase is not in the paper. |
| C14 | Table 6, all rows old and new; 0.731 Centro weight; Carapungo 1.12 on Cotocollao; Tumbaco M5b p 0 (L38-40, L108-124) | SUPPORTED | step2/placebo_old_vs_new.csv | |
| C15 | DDD -11.4 / -11.7; rank 2 of 7; p 0.286; floor 0.143; full DDD table (L42-44, L276-289) | SUPPORTED | step2/ddd_centro.csv | |
| C16 | NO2 log effects "move by at most 0.0001" (L47) | ROUNDING | main_old_vs_new.csv, NO2 | The maximum is 0.000104. |
| C17 | "CO changes little" (L48) | OVERSTATED | main_old_vs_new.csv rows CO M1/M2 donut | True for M8b and the AugSynth specifications only. SDID M1 donut goes from -16.9 to -6.9 and M2 donut from -17.7 to -3.5. |
| C18 | Table 5 and Table 7 old and new; the battery's 5 sign changes (L69-102) | SUPPORTED | main_old_vs_new.csv; paper:644-663, 737-756 | |
| C19 | "the vintage alone moves little" (L81) | OVERSTATED | — | The pre-disruption window ends in September 2024, so it cannot show vintage effects on the 2025 weeks, which is where the new delivery differs (Los Chillos refill, Guamaní hours). S2a moves the donut p from 0.199 to 0.094. |
| C20 | Sensitivity table, all 66 cells, and the ranges 13.3-17.4 and 0.058-0.658 (L128-152) | SUPPORTED | step2/sensitivities_long.csv | |
| C21 | "The NO2 rejection comes from a period with long gaps in Centro's NO2 series" (L162) | UNSUPPORTED | — | No S1 NO2 gap path exists (suggestion 6). Weeks with Centro missing are dropped by the all-stations rule. |
| C22 | Simulation SE 0.004; "These are the same result" (L169-170) | SE SUPPORTED; wording OVERSTATED | — | The paper's 0.011 comes from the old data. Say "consistent with simulation noise". |
| C23 | Leave-one-out table and gas highlights (L200-209) | SUPPORTED | loo_centro_M8b_*.csv | Line 198 says "Table 5 prints 0.431". The paper's Table 5 prints 0.392; 0.431 is the new run. |
| C24 | "The 8 rejections are closer to one episode counted several times" (L244) | OVERSTATED | pseudo_openings_M8b_PM25.csv | Not tested (suggestion 1 would test it). The pseudo-effects do not rise steadily: week 38 is +0.107, week 40 +0.059. |
| C25 | Late-2023 gaps +0.263 / +0.336 / +0.223; week 44 +0.160 (p 0.033); week 30 +1.4% (p 0.025) (L244-246) | SUPPORTED | gaps_M8b_full_PM25.csv; pseudo_openings_M8b_PM25.csv | |
| C26 | April 2024 rolling power cuts (L189) | UNSUPPORTED (memo says so) | — | Needs a source before it leaves the repository. |
| C27 | Map: 308 rows, 212 changed, 5 sign rows covering 3 estimates (L294-298) | SUPPORTED | step2/paper_number_map.csv | |
| C28 | "Two cells carry a note" (L300) | UNSUPPORTED | paper_number_map.csv:note | 18 rows carry 4 different notes: the A.3 typo (1 row), Belisario donor rule (2), Table 3 P2 (1), Table A.1 counting window (12). |
| C29 | Verification facts (L11, L359-368) | SUPPORTED | reports/verification/2026-10-05_air_quality_606ea82.md | |
| C30 | "code-reviewer found no sourcing errors"; "methods-referee reviewed" (L370, L381) | UNSUPPORTED | — | No saved review record in the repository. |

### Map check

- **Frozen values against the paper.** I compared `frozen_rounded` by hand with the printed cells for all 308 rows (Tables 5, 7, A.3, 6, 3 and A.1). All match except A.3 M8 donut, which is the expected exception.
- **New and frozen values against the source files.** I recomputed all 228 cells of Tables 5, 7 and A.3 from `crosssample/CrossSample_Summary_*.csv` and the frozen copies: 456 comparisons, 0 mismatches. I also recomputed the 16 Table 6 cells from both spatial placebo files, and the Table 3 and A.1 cells from `descriptives_*.csv` and `window_weeks.csv`. All match.
- **Omissions.** In the tables you listed, the map leaves out only the 8 Table 6 distances, as its notes say. It does not meet plan 4.3 (`air_quality/docs/revision_plan.md`:133), which asks for page and line for every number, plus the text numbers of the abstract and sections 5.1 to 5.3, Table 2, and Figures 2 and 5. The map has no line column, and the memo does not say this departs from the plan.

### Changes needed, most serious first

1. **Section 7 leaves out text the new numbers contradict.** Add these:
   - Line 720: "PM2.5 falls significantly in every window". Donut p is now 0.199 and full p is 0.097.
   - Lines 778-781: M5b "9.5 ... 10.1 ... 13.3 percent, all significant" becomes 9.5 (p 0.019), 11.6 (0.191) and 13.8 (0.057).
   - Line 785: SDID "14.3 to 20.7 percent ... pre-disruption 14.5" becomes 13.9 to 19.8, with pre-disruption 14.9.
   - Line 625: "0.185 to 0.205" becomes 0.188 to 0.207.
   - Line 678: "p-value of 0.012" becomes 0.013.
   - Line 210, Table 1: "8 stations × 116 weeks" becomes 134 weeks.
   - The repeated claims in the introduction (lines 88-95), the results summary (846-848) and the conclusion (860-863).

   Sources: `main_old_vs_new.csv`; map rows 5, 23, 41, 191-197.
2. **The gap-path finding is not new.** The frozen M8b weekly effects (`frozen_2026-05-29/output/local/tables.zip`, `att_weekly_PM25.csv`) give the same pattern: first 30 weeks average -0.029, last 12 average -0.384, 84 percent of the total, 7 of the first 8 weeks positive. So lines 592-602 never matched the paper's own outputs. The memo should say so, not list it under "what the new numbers change" (L322).
   - The memo's own finding also contradicts "in the first months of operation" in the abstract (line 22), introduction (89) and conclusion (861). Yet line 314 says the abstract figures "hold".
   - "Not driven by a single post-opening week" is still literally true: the late effect spans 12 weeks, not one. Drop it from the list of failing phrases.
3. **The Belisario points are misattributed** (L33, L37, L319, L320, L211-216). M9 was -6.0 percent (p 0.729) in the paper and is -6.1 percent (p 0.737) now. The estimand critique is a fair re-reading of numbers the paper already printed (-17.0, -6.0, -12.2), and the memo should present it that way. Only the Table 6 placebo changed sign, and that came from the donor rule. Also replace the made-up quotation at L37 with the paper's actual wording (lines 611 and 668).
4. **Wrong line references:**
   - Abstract: 19-23 should be 21-25.
   - Table 3: 292-306 should be 292-312, since footnote a is at 309-312.
   - "no comparable decline at Belisario" is at line 587, not 588-589.
   - Line 764 belongs to the Table 7 notes, not Table 5.
   - Table 2: 252-261 should be 252-268; the stations row is line 262.
   - The quote the memo calls the "Table A.3 note" is appendix A.2 text at lines 1218-1220.
   - Section 5.1's Table 5 discussion ends at 631, not 634.
5. **Overstated interpretation:**
   - C4: rewrite line 24 so it does not attribute a motive to the authors.
   - C7: soften "do not come from a fading effect" and label the figures as slices of the full-window vector.
   - C9: drop "the block test does not share its worry".
   - C19: drop "the vintage alone moves little".
   - C21: remove the NO2 attribution or mark it as a guess.
   - C24: write "may be" one episode.
   - L343-345: add that in the full window neither M8b (p 0.097) nor M5b (p 0.057) is at or below 0.05.
6. **Map not to plan 4.3.** Add a page and line column, or state in the memo that the map departs from plan 4.3 and why.
7. **Fix "Two cells carry a note"** to 18 rows with 4 notes.
8. **Smallest attainable p.** Lines 40, 123, 148 and 316 write "p = 0". Write "p < 0.001 (no permutation of 1,000 as extreme)", as line 160 does and as the known issue on zero conformal p-values asks.
9. **Minor wording:**
   - C16: "about 0.0001".
   - C17: "CO M8b changes little".
   - C23: line 198 should say "the main run gives 0.431".
   - C22: "consistent with simulation noise".
   - Cotocollao "now significant" (0.061 to 0.047) is inside the noise band the memo itself describes; hedge it.
   - Line 313: the log effect does change at printed precision (-0.130 to -0.131).
10. **Unsourced claims.** Get a source for the April 2024 power cuts, and save or cite the code-reviewer and methods-referee findings.
11. **Notes to add:**
    - Table 6 distances: the spatial placebo files still swap Tumbaco and San Antonio (`dist_corridor_km` gives San Antonio 9.558 and Tumbaco 16.650), so a redrawn Table 6 must take its distances from the paper. This is already a known issue.
    - S3's donut drops 10 PM2.5 weeks and 8 CO weeks, not 14 (verification report, section 2a).
    - Outside this memo's scope: paper Table 9 prints satellite Wald p-values (lines 874-883). This is already a known issue.
