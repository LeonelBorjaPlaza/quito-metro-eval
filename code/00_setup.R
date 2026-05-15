#=========================================================
#  00_setup.R
#  Run ONCE on a new machine to set up the project environment
#
#  This initializes renv (package version management) and
#  installs all required packages. After running, renv.lock
#  records exact versions for reproducibility.
#
#  On subsequent machines: just run renv::restore()
#=========================================================
# ---- Step 0: Set CRAN mirror ----
options(repos = c(CRAN = "https://cloud.r-project.org"))

# ---- Step 1: Initialize renv ----
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

renv::init(bare = TRUE)

# ---- Step 2: Install CRAN packages ----
cran_packages <- c(
  "dplyr",
  "readr",
  "tidyr",
  "ggplot2",
  "patchwork",
  "stringr",
  "lubridate",
  "fixest",
  "here",
  "remotes",
  "readxl"
)

install.packages(cran_packages)

# ---- Step 3: Install GitHub packages ----
# augsynth: Augmented Synthetic Control (Ben-Michael et al.)
remotes::install_github("ebenmichael/augsynth")

# synthdid: Synthetic Difference-in-Differences (Arkhangelsky et al.)
remotes::install_github("synth-inference/synthdid")

# ---- Step 4: Snapshot versions ----
renv::snapshot()

cat("\n=== Setup complete ===\n")
cat("All package versions recorded in renv.lock\n")
cat("Commit renv.lock to git for reproducibility.\n")
cat("On a new machine, just run: renv::restore()\n")
