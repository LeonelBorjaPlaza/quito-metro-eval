# Runs the item D redesign (plan Amendment 5, proposed) from raw data, each script in a clean R session,
# pre period only. Run from congestion/ after `bash Scripts/Congestion/19_step1_setup.sh`.
# 20 and 21 rebuild the pre-only block and panel; 31 the Amendment 2 geography; 40 the scale test
# (decided first); 41 tiles, units, rings and the adoption check; 42 the estimator contest; 43 the
# pre-period checks and the empirical MDE; 44 the pico y placa zone (approved by Leonel on 2026-10-01 with
# a straight-segment closure); 45 the restart diagnostics after the stop (Amendment 6);
# 25 scans every output for months from December 2023 on.
scripts <- c("20_step1_blocks_pre.R", "21_step1_panel.R", "31_amend2_geography.R", "40_redesign_scale.R",
             "41_redesign_units.R", "42_redesign_contest.R", "43_redesign_checks.R", "44_redesign_zone.R",
             "45_restart_diagnostics.R", "25_step1_check_no_post.R")
for (s in scripts) {
  message("Running ", s)
  status <- system2("Rscript", file.path("Scripts/Congestion", s))
  if (status != 0) stop(s, " failed with status ", status)
}
message("Redesign run complete.")
