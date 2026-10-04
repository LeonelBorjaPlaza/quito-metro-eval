# Congestion module: the item D redesign on pre-period data (Amendment 5, proposed)

Work of 1 October 2026, workstream B, branch `worktree-congestion-step1`. Governing plan: `congestion/docs/analysis_plan.md`, Amendment 5 (proposed, not yet approved). Pre period only (January 2022 to November 2023); no month from December 2023 on was loaded, and nothing was merged. Unless a path says otherwise, file names refer to `congestion/Output/redesign/`, written by `Scripts/Congestion/39_run_redesign.R`. The outcome is a road-weighted index of the hexagons covering the district: Waze-reported congestion, where fewer drivers also means fewer Waze observers.

## Result

**The pre-period work does not yet answer whether the monthly data can sign the effect.** It shows only that an unscaled comparison of CENTER against these 22 placebo tiles cannot sign a plausible effect. Unscaled means CENTER's forecast error is set against the tiles' own errors, not divided by each tile's forecast error; the errors are still in proportions. Such a comparison has 80 percent power only for changes of about 0.92 of CENTER's mean (reduction) or 0.82 (increase). Which effects are plausible is not yet written down (step 1 below). The methods-referee judged that narrower statement to be all the evidence supports, and I agree (see "Methods-referee" below).

- **The empirical minimum detectable effect is about 0.92 of CENTER's pre-period mean** (`mde_empirical.csv`), which is 10.7 index points against a pre-period mean of 11.67. For an increase it is 0.82 of the mean.
  - **How it is computed:** from nine-month forecast errors of the 22 placebo tiles (fit on 12 usable months, forecast the next 9), at two-sided 5 percent and 80 percent power.
  - **It rests on the tails.** The critical value (0.69, the 95th percentile of the absolute nine-month errors) sits between the third- and second-largest tile errors (0.39, derived as noted under Empirical MDE, and 0.71; the largest is 1.30). The median tile misses by 0.16 of its level, about 1.8 index points at CENTER's level (`mde_empirical_distribution.csv`).
  - **It is not the MDE of the plan's own tests.** It does not measure the power of the CWZ test at CENTER, of the scaled placebo rank, or of the direction rule.
  - **It is calibrated on lower units that are noisier in proportions.** The tiles average at most 7 cells, with fit means of 0.21 to 7.44 index points, against CENTER's 15 cells and 11.67.
  - **It is one calendar draw.** All errors come from the same 12-month fit and the same 9-month forecast window.
  - **It describes the design, not the effect,** and it is never a bound on the effect.
- **The estimator contest keeps the default** (`contest_overall.csv`, `contest_decision.csv`). Synthetic control with non-negative weights summing to one, fitted on the morning and evening peaks together, has the lowest forecast error. None of the other estimators comes within 10 percent of it. Its one-month-ahead error is about 25 percent of a tile's level (square root of the horizon-1 MSE, 0.0632; `contest_by_horizon.csv`).
- **Scale: proportions** (`scale_decision.csv`). The slope of log volatility on log level across the main-pool tiles is 1.049 (95 percent interval 0.841 to 1.257), well above 0.5. But CENTER's level lies above every tile's, so the scale is extrapolated to it. The contest suggests a level-dependent lean. For the default, shares are under-predicted on average (+0.031), while the signed error in index points is about zero (-0.0001; `contest_overall.csv`). So the positive share errors must come from low-level tiles, and higher-level units are likely over-predicted. This is inferred; no file reports errors by level.
- **CENTER's pre-opening drift lies inside the placebo range, and most of its size comes with the scale.**
  - Fit to May 2023, CENTER is over-predicted in June to October 2023 by 0.093 of its fit-window mean (11.43 index points) on average, or 1.06 index points, in 4 of 5 months.
  - 13 of the 22 placebo tiles miss by at least as much in absolute value over the same months (`check_center_vs_placebo_jun_oct_2023.csv`).
  - In levels the drift keeps its sign but shrinks to -0.21 index points, with 3 of 5 months negative.
- **The size condition for the conformal test is met only on the pooled count, and weakly** (`check_cwz_size.csv`).
  - Pooled: 4 of 44 pseudo-openings (9.1 percent, against the 10 percent rule).
  - By opening: 1 of 22 with T = 20 (smallest attainable p 0.05), and 3 of 22 with T = 21 (smallest attainable p 0.048; 13.6 percent).
  - The two openings share most of their months, and they use 6-month windows with T of 20 or 21, not the confirmatory 9 months with T = 30.
  - I labeled the pooled row decisive after seeing the results, at code review.
- **What remains: the zone-based checks.** They wait for your check of the traced pico y placa zone (`map_pico_y_placa_zone_for_check.png`). They are the 20:00/21:00 positive control, the valley checks and the in-zone tile counts.

**Before deciding whether to stop, I recommend you do two things in order:**

1. **Write down the range of effects that would matter.** It will be set after seeing the 0.92, and the amendment should say so.
2. **Choose which pre-period computation decides "cannot sign".** The referee proposes four, all on pre-period data only:
   - the power of the actual CWZ test at CENTER, with injected proportional shifts;
   - the scaled-rank MDE;
   - the false-direction rate of the main-plus-anchored sign rule on placebo tiles;
   - the MDE without the two largest tiles.

I have run none of them, because their criterion should be fixed first. The provider questions for finer data are ready in `congestion/docs/provider_questions.md`.

## Scale, decided first (Amendment 5, item 3)

- **The test.** Across the 22 main-pool tiles, OLS of the log standard deviation of calendar-adjacent monthly changes (19 per tile; changes touching June 2022 or November 2023 left out) on the log pre-period mean.
- **The result.** Slope 1.049, with a classical 95 percent interval of 0.841 to 1.257. Decision: proportions. It was committed in `bd2f2d6` before any other redesign result was computed.
- **Check after the BELISARIO rebuild.** The rebuild (below) left the decision byte-identical.

## Donor tiles (Amendment 5, item 4)

Counts from `tile_counts.csv`:

| Step | Tiles |
|---|---|
| H3 resolution-7 tiles touching the delivered grid | 384 |
| All seven cells in the grid | 324 |
| At least 4 of 7 cells meet the saturation rule (mean of at least 20 valid delivered slots per month, Phase C rule) | 44 |
| And no cell in CENTER, its buffer, CORRIDOR, RING or BELISARIO | 26 |
| And a complete peak, morning and evening index over the pre period | 25 |
| **Main pool: in the DMQ** | **22** |
| of which valleys (Tumbaco, Los Chillos, Calderón) | 12 |
| of which low exposure (every cell more than 4 km from a station) | 15 |
| Check pool: neighbouring municipalities | 3 |

- **No neighbouring tiles needed.** With 22 district tiles, the neighbouring-municipality tiles stay a check (the rule calls them in below 20). The code stops rather than adding them automatically if fewer than 20 qualify.
- **Two filters I added.**
  - A tile must have all seven of its cells in the delivered grid (324 of 384), so tiles at the edge of the delivery are left out.
  - A cell labeled "ambiguous" between a valley and a non-valley zonal administration does not count as a valley cell.
- **Scale pool equals the main pool.** The 22 tiles behind the scale test are written to `scale_tiles.csv`, and the units script asserts they equal the main pool. The scale script refuses to overwrite a committed decision it would change.
- **Composition.** Cells with no pre-period record carry no weight in a tile (plan section 1, state e). Each tile's index is total jam length over total road length, using the provider's 2022 OSM length.
- **Map:** `map_tiles.png`.
- **In and out of the zone:** the counts wait for the zone check.

## Estimator contest (Amendment 5, item 5)

- **Design.** Every main-pool tile served as the target, with the other 21 as donors. Cut-offs fell at usable months 12 to 20, and each forecast covered up to the next three usable months (fewer at cut-offs 19 and 20): 528 forecasts per estimator.
- **Errors.** On the fitting scale they are shares of the tile's fit-window mean; index points are shown beside them. A positive signed error means the estimator under-predicted.

| Estimator | MSE (share²) | Relative to the default | Mean signed error (share) | Share of errors negative | MSE (index points²) | Mean signed error (index points) |
|---|---|---|---|---|---|---|
| Synthetic control, default | 0.0748 | 1.00 | +0.031 | 0.49 | 0.587 | -0.000 |
| Synthetic DiD | 0.0841 | 1.12 | +0.003 | 0.53 | 0.650 | -0.082 |
| Ridge (largest penalty within 5%) | 0.0980 | 1.31 | +0.010 | 0.53 | 0.861 | -0.060 |
| DiD against the tile mean | 0.1063 | 1.42 | 0.000 | 0.55 | 0.897 | -0.164 |

By horizon (`contest_by_horizon.csv`):

| Horizon | Default: MSE, mean signed error | Synthetic DiD | Ridge | DiD |
|---|---|---|---|---|
| 1 month | 0.0632, +0.021 | 0.0743, +0.001 | 0.0831, +0.002 | 0.0990, 0.000 |
| 2 months | 0.0912, +0.034 | 0.0999, +0.003 | 0.1163, +0.015 | 0.1215, 0.000 |
| 3 months | 0.0710, +0.041 | 0.0786, +0.004 | 0.0965, +0.016 | 0.0983, 0.000 |

- **The default leans one way.** As a share of level, it under-predicts placebo tiles slightly (+0.021 to +0.041, growing with horizon), but its signed error in index points is near zero. So the lean comes from tiles with low levels, where shares are large. Index points here are each tile's own ("tile index points"), so their bases differ across tiles.
- **DiD's signed error is zero by identity.** With every tile as target against the mean of the others, the errors sum to zero each month. Bias can be compared only among the other three.
- **The SDID horizons are not quite like for like.** synthdid fits its time weights on the donors over all forecast months together. Its one-month forecast therefore uses donor values from the later months, though never the target's.
- **Tie rule as implemented.** Challengers within a factor 1/0.9 of the best count as tied (`contest_decision.csv`). No challenger came within 10 percent of the default, so it did not arise.

## Checks on pre-period data (Amendment 5, item 7)

- **CENTER against the placebo tiles, June to October 2023** (`check_center_vs_placebo_jun_oct_2023.csv`, `check_center_jun_oct_2023_paths.csv`). Fit on usable months to May 2023; November 2023 is out.

  | Scale | CENTER's mean error | CENTER's RMSE | Months negative | Tiles at or below CENTER's mean error | Tiles at least as large in absolute value | Tile mean errors (min, median, max) |
  |---|---|---|---|---|---|---|
  | Proportions (decided) | -0.093 (-1.06 index points) | 0.122 | 4 of 5 | 7 of 22 | 13 of 22 | -0.18, -0.03, +0.76 |
  | Levels | -0.21 index points | 0.87 | 3 of 5 | 7 of 22 | 11 of 22 | -0.54, -0.08, +1.87 |

  - **The drift survives the change of scale in sign.** CENTER's error lies inside the placebo range on both scales.
  - **The anchored estimate's pre-period piece.** The mean June to October 2023 gap is -0.093 of the fit mean, or -1.06 index points: weights fitted on usable months January 2022 to May 2023, by the default estimator in proportions.
- **Size of the conformal test** (`check_cwz_size.csv`).
  - **Method:** the statistic is the absolute mean residual over a 6-month pseudo-P1; the model is refit on all periods under the null, with circular shifts.
  - **Openings:** two pseudo-openings per tile, with T = 20 (usable months 15 to 20 as pseudo-P1) and T = 21 (16 to 21).
  - **Rejections at 5 percent:** 1 of 22 and 3 of 22 respectively, 4 of 44 together (9.1 percent). The smallest attainable p-values are 1/20 = 0.05 and 1/21 = 0.048 (`check_cwz_size.csv`), so a tile rejects only when its statistic ranks first.
  - **Pooled, the rate is under 10 percent; by opening, one exceeds it.** I labeled the pooled row decisive after seeing the results, at code review, and read that way the rule is met. The opening with T = 21 alone exceeds 10 percent (13.6 percent). Whether the pooled count stands is your decision (Decision 3).
- **Rings** (`check_rings_forecast.csv`, `ring_units.csv`).
  - **The units:** 38 ring units, built as resolution-7 tiles within each ring and segment. Segments come from station latitude: the five northern, central and southern stations each, an approximation of the station order. Cells of CENTER's buffer enter a ring only if they are within 2 km of a station.
  - **The test:** each unit's rolling-origin forecast error against the main tiles, on the contest's design.
  - **Forecastability varies a lot:**
    - corridor north 0.011 and ring north 0.017, against the placebo tiles' 0.075;
    - ring south 0.143, with a signed error of +0.161, so its south units are under-predicted.
- **Jam speed** (`check_speed.csv`). CENTER has a jam-speed value in all 21 usable months. Its correlation with the main index is -0.31, against a median of -0.33 across tiles.
- **Adoption** (`adoption_check.csv`). These are yearly increments of cumulative jam length as a share of whole-cell 2022 OSM length, up to 2022 only.

  | Year | CENTER | Donor tiles (median, interquartile range) |
  |---|---|---|
  | 2020 | 0.056 | 0.066 (0.048 to 0.096) |
  | 2021 | 0.000 | 0.001 (0.000 to 0.009) |
  | 2022 | 0.002 | 0.006 (0.000 to 0.009) |

  - Through 2022, CENTER's jam extent was not growing faster than the donors'; 2023 is not covered.
  - The denominator is each unit's whole-cell 2022 OSM length, held fixed across years.
  - Cells with no row in a year count as zero: 3 of 151 donor cells in 2019 and 1 in 2020, none in CENTER (`adoption_check_missing_rows.csv`).
- **Not run yet:** the 20:00/21:00 positive control, the valley checks and the in-zone tile counts. They wait for the zone check.

## Empirical MDE (decision information)

- **Method** (`mde_empirical.csv`):
  - each placebo tile is fit on usable months 1 to 12 (January 2022 to January 2023, June 2022 out) and forecast for usable months 13 to 21 (February to October 2023);
  - its mean error over the nine months is taken;
  - the critical value c is the 95th percentile of the absolute mean errors (0.693);
  - the MDE is the smallest shift d with |mean error + d| > c for at least 80 percent of tiles.
- **Result:** a reduction of 0.916 of CENTER's level, or 10.69 index points; an increase of 0.825, or 9.62 index points.
- **Caveats** (`mde_empirical_distribution.csv`):
  - With 22 tiles, c (R's type-7 95th percentile) sits between the third- and second-largest absolute errors (0.385 and 0.709; the largest is 1.296), so the figure rests on the tails. The third-largest value is not a column of the file. It follows from the type-7 formula and two committed values: (0.693 - 0.95 x 0.709)/0.05 = 0.385. The median absolute error is 0.157 and the 75th percentile 0.254.
  - The MDE is found on a grid of step 0.0011 (4,001 points from 0 to 4.58). The verifier's exact values (its report, no file) are 0.9155 (reduction) and 0.8243 (increase).
  - The tiles' fit-window means (0.21 to 7.44 index points, median 2.74) lie below CENTER's (11.67). The scale test supports proportions (slope near 1), but it cannot rule out that CENTER's proportional noise is smaller than the tiles'. In proportions, CENTER's June to October 2023 RMSE (0.122) is at or below that of 15 of the 22 tiles. In levels, only 2 of the 22 tiles reach CENTER's RMSE of 0.87 (`check_center_vs_placebo_jun_oct_2023.csv`). So the noise ranking depends on the scale.
  - It is not the MDE of the CWZ test, of the scaled rank or of the direction rule (see Result).

## Geography

- **BELISARIO** (`congestion/docs/belisario_address_check.csv`). The monitor stands on Colegio San Gabriel's administrative building (Av. América).
  - The whole campus outline (OSM way 282603573, 15 vertices) lies in cell 8866d338c9fffff, not in the stored seed 8866d33aa3fffff. The two cells are neighbours, and the campus centroid is 880 m from the published point. That is more than rounding to 0.01 degree can move a point (at most about 790 m, the referee's arithmetic), and the campus longitude (-78.497) would round to -78.50, not -78.49. So the published coordinates look truncated rather than rounded, or the monitor is not where the address puts it.
  - **The ring is rebuilt around 8866d338c9fffff**, as you instructed. Old-ring cells outside it return to their distance group.
  - The address comes from web-search excerpts of REMMAQ documents that refused direct download (cited in the file). The note was moved from `Output/redesign/` to `congestion/docs/`, because no script produces it (verifier). The OSM campus outline is staged for the store; the command is under "Answers to your two questions".
- **Pico y placa zone, for your check** (`map_pico_y_placa_zone_for_check.png`, `zone_summary.csv`). The zone is traced by code from the five official boundary streets in the 2022 OSM major roads.
  - **No official vector layer was found** on GeoQuito.
  - **Tracing method.**
    - In OSM, each street breaks at junctions, so the streets are buffered and the enclosed area is taken, then grown back by the same distance.
    - A 100 m buffer was the smallest that closed the ring.
    - One gap is real: Av. Morán Valverde ends about 1.2 km short of Av. Simón Bolívar (a one-off measurement written into `44_redesign_zone.R`; no output file holds it). It is closed with Av. Pedro Vicente Maldonado and Av. Gonzalo Pérez Bustamante (magenta on the map).
  - **Result.**
    - The zone covers 12,125 ha and contains 14 of the 15 stations (Quitumbe is outside) and the Belisario point.
    - It contains 0.91 of CENTER's area: the historic district reaches west of Av. Mariscal Sucre.
  - **Not used yet.** Nothing uses the zone until you approve it.

## Calendar, environment and changes

- **Calendar:** `congestion/docs/calendar_shocks.csv` lists every event in item 6 with sources. It includes your correction: rationing from 27 October to about 19 December 2023, then suspended and not resumed. June 2022 and November 2023 leave the fit and the permutation set, which leaves 21 usable pre months and a floor of 1/30 with nine P1 months.
- **scpi:** 4.0.1 installed with its dependencies as Posit binaries from the 2026-10-01 snapshot. No system library was needed, and a small simplex example ran. `19_step1_setup.sh` installs it in any checkout, and the approved list is in `congestion/CLAUDE.md`. synthdid 0.0.9 comes from the renv cache.
- **Panel script:** `21_step1_panel.R` now also keeps per-cell jam-speed sums in the ignored panel. A rerun left the tracked Step 1 outputs unchanged.
- **No-post check:** `25_step1_check_no_post.R` also scans the redesign folders. It found no value dated December 2023 or later. It scanned 97 files in the last full run here (`logs/redesign_run_full2.log`, ignored), and 98 when rerun alone after 43 added a file. By the verifier's reports, it scans 82 in a clean checkout of `231a113` and 83 at `19a4d28`, since this worktree also holds older derived files.

## Answers to your two questions

- **Registering the parish delivery in `MANIFEST.sha256`.** It is already registered. The manifest holds all seven files (lines 1121 to 1127, including `SHA256SUMS`), and their hashes match, so there is nothing to run. To check:

  ```
  cd /home/leonelb/data/quito-metro-eval && grep 'road_safety/raw/2026-09-25_geoquito_parroquias/' MANIFEST.sha256 | sha256sum -c
  ```

  (The command I drafted earlier would have added duplicate lines.)
- **Optional: storing the BELISARIO evidence.** If you want it in the store, this adds the OSM campus outline (`sg_campus.json`), its Overpass query (`sg2.txt`) and a source note. The files sit in this session's scratchpad under `/tmp`, which a WSL restart clears, so run it soon:

  ```
  cd /home/leonelb/projects/quito-metro-eval/.claude/worktrees/congestion-step1
  RECEIVED_DATE=2026-10-01 bash scripts/add_raw_delivery.sh congestion belisario_monitor_location /tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/delivery/belisario_monitor_location/*
  ```
- **The leftover verifier worktree** (`.claude/worktrees/agent-aea4637215996826c`). Its only change is `congestion/Output/Waze/step1/raw_checksum_result.txt`, which holds 34 "FAILED open or read" lines. They come from the first verifier's setup run at `ae1d50c`, before the manifest-mapping fix. It is safe to remove.

## Decisions for you

1. **The zone map.** Approve it, or correct it; the zone-based checks run after.
2. **Whether the monthly data can sign the effect.** First write down the range of effects that matters, labeled as set after seeing the 0.92. Then choose which pre-period computation decides it (the referee's four options, under Result). Only the narrower statement is supported now.
3. **The CWZ size rule.** Does 4 of 44, pooled, count, given that the openings overlap and do not match the confirmatory configuration?
4. **The confirmatory test's specification:**
   - the null on the proportional scale;
   - the normalization months in the refit;
   - whether an explicit intercept is used;
   - P1 with or without December 2023.
5. **The direction rule, made operational:**
   - the drift and extrapolation behind the flip multiple;
   - "distance from the center" against the station-distance rings;
   - how many ring groups must shrink.
6. **What happens if the valley check removes the valley tiles.** They are 12 of the 22, and the 10 left plus 3 neighbouring tiles fall below 20. This is needed before you approve the zone, since approval triggers the check.
7. **The scale.** It is extrapolated to CENTER, and the contest shows a level-dependent lean. Revisiting it now would be model selection after results, and the amendment should record it as such.
8. **Amendment 5** stays marked proposed until you approve it, with the maker's choices recorded (next section).

## Choices made after seeing results (for the amendment record)

The referee lists these, and I agree they should be recorded as decided after results:

- **Labels and fixes added at code review:** the pooled CWZ row labeled decisive, and the fixed adoption denominator.
- **The zone tracing:** the connector box and the list of buffer widths.
- **The BELISARIO rebuild,** as carried out.
- **My earlier readings in this report:** "does not depend on two extreme tiles" (withdrawn) and "the drift is ordinary" (narrowed).
- **Filters fixed before the scale result** (they define its pool), but not written in the plan:
  - all seven cells in the grid;
  - ambiguous cells not counted as valley;
  - cells without a pre-period record carry no weight.

## What ran, and status of every check

- **Pipeline:** `Rscript Scripts/Congestion/39_run_redesign.R` from raw, each script in a clean session.
- **Code-reviewer: done.**
  - By its report, it found no forecast-month leakage, no indexing error, and no confirmed wrong number. It could not run R.
  - Its major points are all addressed:
    - the adoption denominator, now fixed per unit (only the adoption table changed);
    - the DiD identity and the SDID horizon notes;
    - guards against lost parallel jobs;
    - the scale decision protected, with the scale pool asserted;
    - the CWZ rows labeled.
  - Its minor points are fixed or documented here. That includes the second road-length reader, moved to `step1_loader.R`, and the synthdid and scpi versions, now checked and recorded.
  - The full pipeline was rerun after the fixes: the scale decision reproduced unchanged, and the no-post check scanned 97 files in this worktree at that point.
- **Verifier, first run at `231a113`: failed on provenance only.** Statements here are from its report; no file.
  - Every computed output reproduced byte for byte. Its own code (synthetic control with `quadprog`, not augsynth) matched the scale test, tile counts, contest MSEs, MDE and CENTER's June to October errors to within 1e-8.
  - It failed the commit because `belisario_address_check.csv` was in `Output/redesign/` with no producing script. I moved it to `congestion/docs/`.
  - It found that the MDE distribution file was not yet committed (now in `af38ee1`), and it corrected two statements in this report: where the critical value sits, and the file counts.
  - It found three earlier committed files whose values equal single cells' provider values, now in `docs/known_issues.md`, congestion section.
  - Its brief gave it the expected numbers, so its check of those was not fully blind.
- **Verifier, second run at `19a4d28`: passed with notes.** Statements here are from its report; no file.
  - Rerun from raw in a fresh worktree. Setup passed (71 raw files match the manifest), and the run exited cleanly in 392 seconds.
  - All 61 committed files in `Output/redesign/` (21 files), `Output/Waze/step1/` and `Output/step1_amendment2/` are byte-identical, and every file in `Output/redesign/` was written by the run.
  - Its own code reproduces `mde_empirical_distribution.csv` to within 5e-9, and the scale test, tile counts, contest MSEs, MDE and CENTER check as before.
  - The only tracked output without a producing script is the hand-written Step 1 freeze README.
  - In a clean checkout of `19a4d28`, the no-post check scans 83 files.
  - It left its worktree `.claude/worktrees/verify-19a4d28` in place, because its deletions were blocked. You can remove it from the repository root (a forced worktree removal).
- **Methods-referee: done.** Statements here are from its report; it ran no code. I changed no design choice in response, only the report's wording and a committed summary of the MDE distribution.
  - **Bottom line:** from reading the code and outputs, it found no error in how the numbers are computed (it ran no code).
  - **Critical:** the stop conclusion rests on an MDE that is not the MDE of the confirmatory test, the scaled rank or the direction rule. It is calibrated on noisier, lower tiles in one calendar draw, and no plausible range was written in advance. The Result section now carries only the narrower statement.
  - **Major:**
    - the proportional scale is extrapolated to CENTER, with a level-dependent lean in the hypothesis direction;
    - the size condition is met only on the pooled count, on overlapping openings that do not match the confirmatory configuration;
    - the confirmatory test is underspecified (null scale, normalization, intercept, which P1);
    - the direction rule is not operational (flip multiple, ring gate);
    - there is no contingency if the valley tiles drop out;
    - measurement is still unguarded and acts in the hypothesis direction;
    - CENTER's full-period fit and weights are not reported;
    - the role and scale of the placebo rank are ambiguous.
  - **Minor:**
    - a report slip on the one-month error (fixed);
    - untraceable MDE figures (now in `mde_empirical_distribution.csv`);
    - BELISARIO's coordinates look truncated, not rounded;
    - the zone connector was the maker's choice;
    - superseded text is unmarked in sections 6, 7 and 9;
    - the sensitivities' status under the redesign is unstated;
    - donor gaps and the P1 events have no rule;
    - the maker's filters are not in the plan;
    - contest scoring weights low tiles heavily, though the ranking is the same in index points.
  - **Its judgment:** the redesign is a real improvement and mostly faithful, but it would not freeze or stop on this round.
- **Claims-auditor: done.** By its report, every table value and nearly every figure matches its file after rounding, with no rule breach.
  - Its corrections are applied. They cover:
    - the verifier status;
    - the stale manifest command (the parish delivery was already registered);
    - the CWZ wording and smallest attainable p-values;
    - the level-lean wording;
    - the exact terms of the Result sentence;
    - the noise ranking by scale;
    - the third-largest error's source;
    - file counts, the grid step and the gap length;
    - attributions.
