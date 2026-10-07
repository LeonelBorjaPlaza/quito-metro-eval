# Claims audit: Refine response draft and mechanism note (1a09eb6)

Report of the `claims-auditor` agent, 2026-10-05, on `reports/air_quality/refine_response_draft.md` and `reports/air_quality/2026-10-05_mechanism_ddd.md` at `1a09eb6`, saved by the maker.
- **What is saved.** The verdict and the list of changes are kept word for word. The claim-by-claim table is summarized: every row was SUPPORTED except those listed under the changes.
- **What was applied.** Every change below is applied in the next commit.
- **Where the auditor was wrong.** Item 6 cites `docs/known_issues.md` line 13 as a Guamaní entry. That line is the Los Chillos entry, and the Guamaní episode is in its last sentence; the fix uses it.

## Verdict

Every number I traced matches its file. All 13 Refine comments are present and in order (G1-G5, D1-D8). No source file changed after 606ea82: the only later output change is `step2/paper_number_map.csv`, which neither document cites. So nothing is STALE and there are no CONVERSION ERRORS.

The problems are in what the documents leave out and how strongly they word things. Two results that go against the paper are missing, two sentences are one-sided, the smallest attainable p-value is missing in several places (rule 6), and there are a few wrong line numbers and quotes.

## Changes needed (summary of the auditor's list, most serious first)

1. **High.** G3 did not report the new iid p-values for the numbers Refine quotes: 0.016, 0.199 and 0.097 against 0.011, 0.041 and 0.006. It also did not propose changing lines 720, 22-24 and 90-92.
2. **High.** G2 was one-sided in two places:
   - "Belisario's own estimate is negative ... not positive" holds only in the pre-disruption window; M9 is +1.3 percent in the donut and +13.9 percent in the full window.
   - "understates" covered only a fall at Belisario; a rise would make M8b overstate Centro's change.
3. **Medium.** G2 gave the leave-one-donor-out result for the pre-disruption window only. Donut p ranges from 0.126 to 0.239 and full p from 0.069 to 0.108.
4. **Medium.** The mechanism note's car-channel conclusion was too firm ("not what the data show", "not the signature"), and its untested channel explanations were stated as if they explained the result.
5. **Medium.** The mechanism note wrongly said the later windows "include the disruption months"; the donut window excludes them.
6. **Medium.** The mechanism note's limits omitted Guamaní's June-November 2023 timing episode, which falls in every window's pre-period.
7. **Medium (rule 6).** Smallest attainable values were missing beside:
   - CO p 0.500 (floor 0.167) in G1 and in the note;
   - NO2 p 0.833 in the note's summary;
   - block p 0.242 (floor 1/120) and 0.291 (floor 1/134) in G3;
   - the iid p-values in D5's proposed text.
8. **Medium.** G4's proposed text missed several passages:
   - "first months of operation" in the abstract (line 22), introduction (lines 89-90) and conclusion (line 861);
   - "not driven by a single post-opening week" (lines 597-601).
9. **Medium.** G4's labels were imprecise:
   - -0.141 is the seven restored weeks only;
   - "the weeks the windows add" means relative to the paper's windows;
   - the frozen outputs end on 2025-03-31.
10. **Medium.** The ridership test left unstated how the opening week (starting 2023-11-27) is assigned to a month. It also did not say that its monthly means are a slice of the gap vector. The auditor checked that the slice means equal the window effects.
11. **Low.** G5 misquoted the abstract; "same particulate direction" also appears at lines 98 and 805.
12. **Low.** D4 misquoted line 668: the paper says "after showing", not "after finding".
13. **Low.** G1's proposed swap did not fit the introduction's wording at line 107, and it gave no lines for the conclusion (864-866) or the results summary (850-853).
14. **Low.** G2 cited "Table 5" for numbers that come from the rebuilt Table 5 (the paper's Table 5 has -17.0, p 0.392 and -6.0, p 0.729).
15. **Low.** D7's range should be lines 403-417.
16. **Low.** The note said "six or seven stations"; it is six to eight.
17. **Low.** G4 could add that the 2025 gaps are less negative than in mid-2024.
18. **Low.** G5 did not mention that the paper's satellite p-values are Wald (normal-approximation) p-values.
19. **Low.** D1 called the code the "OneDrive copy"; it is the repository copy. `block_aggregate` is called with B = 4 at lines 1017 and 1060.
20. **Low.** The note said "before any ridership data exist"; it should say "before any ridership data were requested or seen".
