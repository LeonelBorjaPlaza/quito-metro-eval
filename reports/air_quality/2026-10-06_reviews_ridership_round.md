# Reviews of the 2026-10-06 round: code review of the ridership script, and claims audit

Saved by the maker. The verifier's report is separate: `reports/verification/2026-10-06_air_quality_0f13136_checkd_ridership.md`.

## Code review of `air_quality/code/local/step2/ridership_test.py` (before commit 0f13136)

**Verdict.** No error that changes a reported number. Month assignment, blackout exclusion, M = 16, shares, Spearman (average ranks), cyclic shifts, adjacent-month differencing, the station-name mapping and the data-source check do what 3C and its amendment say. All six station-placebo rows were recomputed by hand.

**Findings, with what was applied:**
1. **Major. Ties in the station placebo counted in San Francisco's favour**, unlike the cyclic test. No current tie involves San Francisco. Fixed: ties now count against San Francisco. The numbers are unchanged.
2. **Major. The approval and the three changes were not in the plan.** The changes are the May 2025 end (M = 16), the differencing rule, and the post hoc data-source check. Fixed: amendment added under 3C.
3. **Major. A NaN correlation would have given the smallest attainable p**, and missing station-months in the hourly table were not checked. Fixed: assertions added, plus a month-set check between the two files.
4. **Minor.**
   - The script reads the delivery by an absolute store path, with no committed symlink. Logged in `docs/known_issues.md`.
   - There is no sha256 check of the gaps file.
   - pandas and openpyxl versions are not recorded in `ENVIRONMENT.md`.
   - The log of entries equals raw entries in levels, for Spearman. The report now says so.

## Claims audit of 0f13136 (with c5755ff)

**Verdict.** Every number traces to a committed output; there are no number or conversion errors and no Wald or pnorm p-values. All 11 quoted passages match the paper text, and the new numbers in the rewordings match the rebuilt tables.

**Findings, with what was applied:**
1. **No verifier pass on c5755ff and 0f13136.** Done since: PASS WITH NOTES.
2. **Check d prose left out unfavourable results.** These are the block test's 6 of 13 rejections at 10 percent on the main panel and S4's remaining iid rejections. "Comes from" overstated the cause, and the like-for-like comparison was not labelled post hoc. Fixed in the rewordings report and in Refine G3.
3. **Smallest attainable p was missing** in G4, in the mechanism note's data-source check, and for the conformal p-values in the rewordings. Fixed; a sentence on the 1,000 permutations and the 0.001 floor is proposed for Section 4 and the table notes.
4. **Stale lines.** The draft's source line, "check d not yet run" in G3, "nothing new was run" in the mechanism note, and STATUS. Fixed.
5. **The provenance note's HORA statement contradicted the file.** The labels run 00:00 to 23:00 in both periods. Fixed: the email's statement is reported as the email's, with what the file shows: before 2024-03-27, 99.3 percent of validations fall at 01:00 to 12:00, consistent with a 12-hour clock. Also, the "not confidential" statement is sourced to Leonel's message.
6. **Mechanism wording.** G1's proposed text now says the ridership test did not support the mechanism. "Does not explain" became "shows no sign of explaining".
7. **The hourly-file secondary result was not reported.** Added: -0.088, p 0.933 and 0.688.
8. **Rewording 5.** "Small" became "negative but imprecise". The sign change is attributed to both the data and the donor rule, and the 0.737 against 0.740 difference is explained.
9. **Sensitivity table.** "Every p-value above 0.05" now reads "every new-data p-value". S1 and S4 are added; S4's full-window estimate (-14.9) is also below the paper's 15.1.
10. **Minor.** Line ranges of rewordings 3, 4 and 7; rewording 10 now keeps "All p-values are two-sided conformal p-values."; the curly apostrophe; 0.0625 written consistently; the maker's choices listed in the mechanism note.

**Suggestion outside the 11 passages:** lines 92-93, 608-612 and 778 also depend on Belisario's estimate and on significance across windows. Listed in the rewordings report for review.

## Claims audit of 088921e (block p-values, plan 3D, item 10, email draft)

**Verdict.** No wrong numbers. All 36 block p-values in Tables 5, 7 and A.3, their floors, the pseudo-opening counts, the NO2 ranks, the ridership caveats and the email's figures match their files. The fixes were in wording, and all are applied in the next commit:
- **F1.** The proposed Section 4 paragraph implied that the block test fixes the iid test's over-rejection. It now also gives the block test's 6 of 13 at 10 percent and its effective 5 percent level (0.038), mentions the nesting, and drops the causal claim.
- **F2.** "Every PM2.5 estimate" and "every PM2.5 table" became "wherever both were computed (Tables 5, 7 and A.3)".
- **F3.** The email now separates the 12 label swaps from the 8 small differences, and says the system total differs in March and May 2025.
- **F4.** Plan 3D no longer says flatly that the iid test over-rejects. The known issue on the pseudo-openings is updated.
- **F5.** The Table 6 note and the Figure 5 note now carry the 0.001 floor.
- **F6.** G1's NO2 text says no window is significant (0.167 is the smallest attainable p), and that the post-disruption weeks include late December 2024.
- **F7.** G3 now says the decision is approved and the wording is proposed.
- **F8.** The A.3-specific bracket wording was removed from the notes of Tables 5 and 7.

## Claims audit of the paper change list (594f990)

**Verdict.**
- All 48 quoted "current text" fragments match the paper at their lines.
- Every proposed number matches its source.
- The rebuilt `.tex` notes carry the paper's full text with only the stated changes, and no editorial brackets.

**Fixes applied in the next commit:**
1. **Item 4 (Table 5 note) overstated.** Belisario is negative and about half of Centro's only in the pre-disruption window; in the donut and full windows it is positive (+1.3, +13.9 percent). The wording now says so, in the change list and in Refine D4.
2. **Item 5 (Tumbaco) implied that the looser pre-period fit explains the large p.** The two RMSPEs are now given without a causal link. The p change from 0.785 to 0.768 is now its own new-data row.
3. **The Centro NO2 entry was partly wrong.**
   - The other stations ranged from 17.3 to 28.7 µg/m3 that week, not 19 to 29.
   - Centro's outage begins in the week of 2025-07-21, not right after the panel. The low level lasts five more weeks, so it is a level shift.
   - The fix is in the known issues and in the change list's Figure 2 row.
4. **SO2 ratios.** They are 3.3 to 3.7 at four stations, 4.6 at Tumbaco and 6.8 at Los Chillos, not "three to four times". Counts are stated through 2025-06-22. The added NO2 hour is mentioned. The title of question 8 now covers dropped hours too.
5. **Line 727 added.** The SO2 pre-disruption estimate, -2.5 to -5.1 percent, still "close to zero".
6. **Rewording 9's missing level.** Raised with Leonel, since he has approved that text.
7. **Status labels.** Line 778 is now "Proposed" (from the rewordings report, not the Refine draft). The approval sources for item 10 and the Section 4 paragraph are given (Leonel's decisions A2 and A3).
8. **Smaller points.**
   - Quote for lines 89-90 and 861 ("during the first months").
   - Row order.
   - Lines 535-536 proposed for review.
   - The "Conformal p" label noted as an option to relabel.

## Verification and claims audit of 7c036c5 (closing the round, 2026-10-07)

**Verifier (light): PASS WITH NOTES** (`reports/verification/2026-10-07_air_quality_7c036c5_tables_no2.md`). The Tables 5 and 7 relabel changed no number, and the NO2 arithmetic and raw-store ratios match.

**Claims auditor.** No number errors. Fixes applied in the closing commit:
1. **Figure 2 caption.** It now reads "in the last week", "likely reflects", and "do not fall relative to Belisario's" (in absolute terms Centro's CO and PM2.5 also fell that week).
2. **The second suspected-fault run.** Centro's NO2 recovers in mid-September 2025, then has single low weeks and an outage, then a second low run from 2026-03-09 to 2026-05-11 (0.40 to 0.64 of Belisario's, with CO and PM2.5 not lower relative to Belisario's). This is now in `docs/known_issues.md`, the step 2 memo note and the change list. It strengthens the decision not to cite S1 NO2.
3. "So it is not a local traffic change" became "So a local traffic change is unlikely".
4. Line 778 now says "at the 5 percent level".
5. "Stops reporting" and "partial reporting at the same low level" replaced by the observed sequence.
6. **Los Chillos sentence.** "Robust" became "similar"; "two hours earlier"; the p-values are labelled iid.
7. **Rule 6.** "p = 0 (no permutation of 1,000 as extreme; smallest nonzero 0.001)".
8. **Housekeeping.** `DECISIONS.md` and the 2026-10-07 verification report are committed with this round. The approval definitions in the change list are updated. The satellite note is moved into the header list. The Refine decisions heading is dated.
