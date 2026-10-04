# Runs Step 1 from raw data to the freeze, each script in a clean R session. The no-post-opening
# check runs before the freeze is written (so a failure leaves the committed freeze untouched) and
# again after it. Run from congestion/ after `bash Scripts/Congestion/19_step1_setup.sh`.
scripts <- c("20_step1_blocks_pre.R", "21_step1_panel.R", "22_step1_fit.R", "23_step1_diagnostics.R",
             "25_step1_check_no_post.R", "24_step1_freeze.R", "25_step1_check_no_post.R")
for (s in scripts) {
  message("Running ", s)
  status <- system2("Rscript", file.path("Scripts/Congestion", s))
  if (status != 0) stop(s, " failed with status ", status)
}
message("Step 1 complete.")
