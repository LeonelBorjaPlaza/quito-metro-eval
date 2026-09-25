# One clean-session entry point for the complete Phase C report and audit.
stopifnot(file.exists("AGENTS.md"))
for (script in c("02_prepare_blocks.R", "02_descriptives.R", "02_report.R")) {
  status <- system2(file.path(R.home("bin"), "Rscript"), file.path("Scripts/Congestion", script))
  if (status != 0) stop("Phase C stopped in ", script, " with exit status ", status)
}
