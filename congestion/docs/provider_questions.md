# Questions for the Waze data provider, for when finer data are requested

Kept by workstream B. Nothing here has been sent: on 2026-10-01 Leonel decided to make one attempt with the data as delivered first (plan Amendment 5, item 1). Answered questions are in `2026-09-29_provider_answers.md`.

## Open

1. Do the monthly hourly averages include weekday holidays and decreed days off in the business-day count, or are those days excluded?
2. Why does `tc_severe_persistance_ratio` exceed 100, which its definition, (TCI / TCS) / N_obs × 100, should not allow? (Plan Amendment 1, still unanswered.)
3. Can weekly or daily values be delivered for the same cells, hours and indicators, for 2022 to 2025?
4. Can jam lengths be clipped to the historic-district polygon, or segment-level jams be delivered for its cells?
5. Can the Waze road length (coverage) be computed year by year rather than as a running maximum since 2019?
6. Is there any measure of the number of Waze users, probes or reports by cell and month?
7. Which OpenStreetMap version and which highway classes does each year's `osm_sum_length` use?
8. Is the annual coverage measure for 2023 fixed before December 2023? (Plan section 11.)
9. Was the February to April 2025 gap re-run, and why are some keys delivered three times? (Plan section 11.)
10. Why do 8,290 fast-road keys have no all-road key? (`docs/known_issues.md`.)
11. Please confirm the hour labels (local time, hour of the start of the bin) and that hours 20 and 21 follow the same definition. The weekday profile peaks at 7:00 and 18:00 (`Output/restart_diagnostics/d3_hour_label_check.csv`), which fits local time.
12. Can jam speeds be delivered at the same finer frequency as the congestion values?

On 2026-10-01 the analysis stopped before any post-opening month (plan Amendment 6). The stop report, `reports/congestion/2026-10-01_stop_report.md`, says how much each request would help a restart.
