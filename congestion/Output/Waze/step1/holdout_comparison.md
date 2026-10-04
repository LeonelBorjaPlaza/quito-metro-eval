# Step 1 holdout comparison

provisional zero coding. Gap = actual minus prediction, in percentage points of tci_osm_ratio (peak block). Bias is the mean holdout gap.
Rules: amended (primary, Amendment 1) and plan (original flag rule, sensitivity). Pools: threshold-20 REST with and without the 2022 jam-derived coverage screen.
Estimators: ascm (augsynth, ridge, unit intercept, tuned penalty), scm (augsynth without augmentation or intercept), did (donor-mean difference-in-differences), ascm_dec22 (December 2022 start).

## CENTER and BELISARIO

| rule | pool | target | estimator | window | n_fit | n_post | fit_rmspe | holdout_rmse | holdout_bias |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| amended | primary_unscreened | CENTER | ascm | train 2022-01 to 2023-05 | 17 | 6 | 0.1838 | 0.6792 | -0.5618 |
| amended | primary_unscreened | CENTER | scm | train 2022-01 to 2023-05 | 17 | 6 | 0.1954 | 0.6889 | -0.5712 |
| amended | primary_unscreened | CENTER | did | train 2022-01 to 2023-05 | 17 | 6 | 1.2815 | 1.2204 | 0.7722 |
| amended | primary_unscreened | CENTER | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.0000 | 0.6709 | -0.3160 |
| amended | primary_unscreened | CENTER | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.2170 |    NA |    NA |
| amended | primary_unscreened | CENTER | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.0032 |    NA |    NA |
| amended | primary_unscreened | BELISARIO | ascm | train 2022-01 to 2023-05 | 17 | 6 | 0.8260 | 2.4326 | -2.2688 |
| amended | primary_unscreened | BELISARIO | scm | train 2022-01 to 2023-05 | 17 | 6 | 0.9441 | 1.9897 | -1.8681 |
| amended | primary_unscreened | BELISARIO | did | train 2022-01 to 2023-05 | 17 | 6 | 2.8277 | 2.0598 | 1.5532 |
| amended | primary_unscreened | BELISARIO | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.0570 | 1.2079 | -1.0979 |
| amended | primary_unscreened | BELISARIO | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.8291 |    NA |    NA |
| amended | primary_unscreened | BELISARIO | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.2923 |    NA |    NA |
| amended | primary_screened | CENTER | ascm | train 2022-01 to 2023-05 | 17 | 6 | 0.1165 | 0.6766 | -0.5911 |
| amended | primary_screened | CENTER | scm | train 2022-01 to 2023-05 | 17 | 6 | 0.3613 | 0.6422 | -0.4705 |
| amended | primary_screened | CENTER | did | train 2022-01 to 2023-05 | 17 | 6 | 1.2797 | 1.1998 | 0.7713 |
| amended | primary_screened | CENTER | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.0000 | 0.6317 | -0.3571 |
| amended | primary_screened | CENTER | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.1144 |    NA |    NA |
| amended | primary_screened | CENTER | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.0261 |    NA |    NA |
| amended | primary_screened | BELISARIO | ascm | train 2022-01 to 2023-05 | 17 | 6 | 1.1016 | 0.9194 | -0.6425 |
| amended | primary_screened | BELISARIO | scm | train 2022-01 to 2023-05 | 17 | 6 | 1.2623 | 0.7338 | -0.3634 |
| amended | primary_screened | BELISARIO | did | train 2022-01 to 2023-05 | 17 | 6 | 2.8051 | 2.0330 | 1.5523 |
| amended | primary_screened | BELISARIO | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.1876 | 0.9978 | -0.9427 |
| amended | primary_screened | BELISARIO | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 1.0021 |    NA |    NA |
| amended | primary_screened | BELISARIO | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.3390 |    NA |    NA |
| plan | primary_unscreened | CENTER | ascm | train 2022-01 to 2023-05 | 15 | 5 | 0.1530 | 1.2968 | -1.0405 |
| plan | primary_unscreened | CENTER | scm | train 2022-01 to 2023-05 | 15 | 5 | 0.1618 | 1.2946 | -1.0415 |
| plan | primary_unscreened | CENTER | did | train 2022-01 to 2023-05 | 15 | 5 | 1.2095 | 1.2518 | 1.1024 |
| plan | primary_unscreened | CENTER | ascm_dec22 | train 2022-12 to 2023-05 | 5 | 5 | 0.0000 | 0.6333 | -0.2888 |
| plan | primary_unscreened | CENTER | ascm | full pre 2022-01 to 2023-11 | 20 | 0 | 0.2368 |    NA |    NA |
| plan | primary_unscreened | CENTER | ascm_dec22 | full pre 2022-12 to 2023-11 | 10 | 0 | 0.0473 |    NA |    NA |
| plan | primary_unscreened | BELISARIO | ascm | train 2022-01 to 2023-05 | 17 | 6 | 0.9499 | 1.4492 | -1.1357 |
| plan | primary_unscreened | BELISARIO | scm | train 2022-01 to 2023-05 | 17 | 6 | 1.0523 | 1.1366 | -0.8415 |
| plan | primary_unscreened | BELISARIO | did | train 2022-01 to 2023-05 | 17 | 6 | 2.8565 | 2.1356 | 1.6751 |
| plan | primary_unscreened | BELISARIO | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.1358 | 1.3273 | -0.7691 |
| plan | primary_unscreened | BELISARIO | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.9066 |    NA |    NA |
| plan | primary_unscreened | BELISARIO | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.3106 |    NA |    NA |
| plan | primary_screened | CENTER | ascm | train 2022-01 to 2023-05 | 15 | 5 | 0.0000 | 1.4866 | -1.2460 |
| plan | primary_screened | CENTER | scm | train 2022-01 to 2023-05 | 15 | 5 | 0.3524 | 1.2560 | -0.9570 |
| plan | primary_screened | CENTER | did | train 2022-01 to 2023-05 | 15 | 5 | 1.2082 | 1.2615 | 1.1208 |
| plan | primary_screened | CENTER | ascm_dec22 | train 2022-12 to 2023-05 | 5 | 5 | 0.0000 | 0.6166 | -0.3143 |
| plan | primary_screened | CENTER | ascm | full pre 2022-01 to 2023-11 | 20 | 0 | 0.0000 |    NA |    NA |
| plan | primary_screened | CENTER | ascm_dec22 | full pre 2022-12 to 2023-11 | 10 | 0 | 0.0000 |    NA |    NA |
| plan | primary_screened | BELISARIO | ascm | train 2022-01 to 2023-05 | 17 | 6 | 0.0000 | 1.5204 | -1.0641 |
| plan | primary_screened | BELISARIO | scm | train 2022-01 to 2023-05 | 17 | 6 | 1.4341 | 1.0555 | 0.6524 |
| plan | primary_screened | BELISARIO | did | train 2022-01 to 2023-05 | 17 | 6 | 2.8244 | 2.1338 | 1.6999 |
| plan | primary_screened | BELISARIO | ascm_dec22 | train 2022-12 to 2023-05 | 6 | 6 | 0.0000 | 0.9283 | -0.4949 |
| plan | primary_screened | BELISARIO | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.0000 |    NA |    NA |
| plan | primary_screened | BELISARIO | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.0000 |    NA |    NA |

## Contrast, CENTER gap minus BELISARIO gap

| rule | pool | estimator | fit | n_fit | n_post | fit_rmspe | holdout_rmse | holdout_bias |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| amended | primary_screened | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.9410 |    NA |    NA |
| amended | primary_screened | ascm | holdout | 17 | 6 | 1.0435 | 0.6218 | 0.0514 |
| amended | primary_screened | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.3292 |    NA |    NA |
| amended | primary_screened | ascm_dec22 | holdout | 6 | 6 | 0.1876 | 0.7612 | 0.5856 |
| amended | primary_screened | did | holdout | 17 | 6 | 1.7796 | 1.0256 | -0.7810 |
| amended | primary_screened | scm | holdout | 17 | 6 | 1.0542 | 0.7141 | -0.1071 |
| amended | primary_unscreened | ascm | full pre 2022-01 to 2023-11 | 23 | 0 | 0.7175 |    NA |    NA |
| amended | primary_unscreened | ascm | holdout | 17 | 6 | 0.6999 | 2.0271 | 1.7070 |
| amended | primary_unscreened | ascm_dec22 | full pre 2022-12 to 2023-11 | 12 | 0 | 0.2898 |    NA |    NA |
| amended | primary_unscreened | ascm_dec22 | holdout | 6 | 6 | 0.0570 | 1.0937 | 0.7819 |
| amended | primary_unscreened | did | holdout | 17 | 6 | 1.7796 | 1.0256 | -0.7810 |
| amended | primary_unscreened | scm | holdout | 17 | 6 | 0.8234 | 1.6091 | 1.2969 |
| plan | primary_screened | ascm | full pre 2022-01 to 2023-11 | 20 | 0 | 0.0000 |    NA |    NA |
| plan | primary_screened | ascm | holdout | 15 | 5 | 0.0000 | 0.6517 | 0.2398 |
| plan | primary_screened | ascm_dec22 | full pre 2022-12 to 2023-11 | 10 | 0 | 0.0000 |    NA |    NA |
| plan | primary_screened | ascm_dec22 | holdout | 5 | 5 | 0.0000 | 0.8798 | 0.3979 |
| plan | primary_screened | did | holdout | 15 | 5 | 1.4877 | 1.2264 | -1.0294 |
| plan | primary_screened | scm | holdout | 15 | 5 | 1.1027 | 1.6257 | -1.5070 |
| plan | primary_unscreened | ascm | full pre 2022-01 to 2023-11 | 20 | 0 | 0.7191 |    NA |    NA |
| plan | primary_unscreened | ascm | holdout | 15 | 5 | 0.8281 | 1.2518 | 0.3526 |
| plan | primary_unscreened | ascm_dec22 | full pre 2022-12 to 2023-11 | 10 | 0 | 0.3088 |    NA |    NA |
| plan | primary_unscreened | ascm_dec22 | holdout | 5 | 5 | 0.1482 | 1.0298 | 0.3942 |
| plan | primary_unscreened | did | holdout | 15 | 5 | 1.4885 | 1.2296 | -1.0331 |
| plan | primary_unscreened | scm | holdout | 15 | 5 | 0.9133 | 1.0875 | 0.0054 |

