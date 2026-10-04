# Runs the Amendment 2 to 4 work (items D.1 to D.4) from raw data, each script in a clean R session,
# pre period only. Run from congestion/ after `bash Scripts/Congestion/19_step1_setup.sh`.
# 20 and 21 rebuild the Step 1 pre-only block and panel (21 keeps every cell's block values); 31 to 36
# build the historic-center units and fit them; 25 scans every Step 1 and Amendment 2 output for months
# from December 2023 on. The Step 1 freeze (24) is not rewritten.
scripts <- c("20_step1_blocks_pre.R", "21_step1_panel.R", "31_amend2_geography.R", "32_amend2_panel.R",
             "33_amend2_fit.R", "34_amend2_drift.R", "35_amend2_placebos.R", "36_amend2_donor_geography.R",
             "25_step1_check_no_post.R")
for (s in scripts) {
  message("Running ", s)
  status <- system2("Rscript", file.path("Scripts/Congestion", s))
  if (status != 0) stop(s, " failed with status ", status)
}
message("Amendment 2 run complete.")
