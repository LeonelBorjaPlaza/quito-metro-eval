# Pre-only rough power calibration

CENTER combined-peak pre mean: 11.301003 percentage points. CENTER minus saturated REST residual SD: 1.370248. Independent-normal reference MDE: 1.509360 pp.

| method | draws | noise_sd | critical95 | mde80 | null_rejection | mde_percent_of_pre_mean |
| --- | --- | --- | --- | --- | --- | --- |
| Circular blocks L=1 | 10000.0000 | 1.3702 | 1.0328 | 1.4860 | 0.0500 | 13.1493 |
| Circular blocks L=3 | 10000.0000 | 1.3702 | 1.1533 | 1.6810 | 0.0500 | 14.8748 |
| Circular blocks L=6 | 10000.0000 | 1.3702 | 1.2705 | 1.8520 | 0.0500 | 16.3879 |
| Donor-cell historical placebos, CENTER-noise scaled | 271.0000 | 1.3343 | 2.9536 | 3.7570 | 0.0480 | 33.2448 |

No outcome dated December 2023 or later is read. Each bootstrap generates a hypothetical 23-month baseline and nine-month evaluation from centered pre residuals. Circular blocks of length 1, 3 and 6 preserve different amounts of serial dependence. The 95th percentile of absolute null errors sets a two-sided critical value; constant negative shifts in increments of 0.001 pp find 80 percent simulated rejection.

The spatial exercise holds out January-September 2023 against a 2022 baseline for each saturated donor cell versus the mean of the others. It rescales each historical shift by its 2022 residual SD and CENTER's 2022 residual SD. These are dependent one-cell placebos, not interchangeable seven-cell treatment assignments. They provide a stress calibration, not a valid randomization test. No post-opening effect is fitted.

All calculations use a simple equal-donor benchmark, not optimized synthetic-control weights. Short pre support, trends, selected coverage, overlapping spatial shocks, and a contiguous nine-month simulation for a noncontiguous P2 limit transfer. These numbers are rough planning bounds, not achieved power or a promise for the eventual estimator.
