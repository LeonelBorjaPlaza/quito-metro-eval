# Amendment 2: shared pre-period fence and protected aggregate writers.
source("code/helpers.R")
# Keep individual warnings in run logs rather than an unexpanded summary.
options(warn = 1)
A2_DATA <- "data/derived/amendment2"
A2_OUT <- "output/amendment2"
dir.create(A2_OUT, recursive = TRUE, showWarnings = FALSE)
A2_MONTHS <- seq(as.Date("2021-01-01"), as.Date("2023-11-01"), by = "month")
A2_RINGS <- c("ring_0_300", "ring_300_600", "ring_600_1000", "ring_1000_2000")
A2_TARGETS <- c(A2_RINGS, "corridor_0_600", "historic_center", "arterials", "station_roads_300", "spillover")
norm_a2 <- function(x) {
  x <- toupper(iconv(x, to = "ASCII//TRANSLIT"))
  gsub(" +", " ", trimws(gsub("[^A-Z0-9 ]", " ", x)))
}
round5 <- function(x) 5 * round(x / 5)
small_a2 <- function(x) !is.na(x) & x > 0 & x < 5
# No exact count totals, rates or shares leave this build. Small numerators OR
# complements suppress their rate. Counts that are released are rounded to five.
release_counts <- function(x, cols, file) {
  z <- copy(x)
  for (nm in cols) {
    v <- z[[nm]]
    set(z, NULL, nm, ifelse(small_a2(v), NA_real_, round5(v)))
  }
  z[, disclosure := "counts rounded to 5; positive counts below 5 withheld"]
  save_csv(z, file.path(A2_OUT, file))
}
release_share <- function(num, den) {
  ifelse(den < 10 | small_a2(num) | small_a2(den - num), NA_real_,
         5 * round(100 * round5(num) / pmax(round5(den), 5) / 5))
}
assert_pre <- function(x, date = "fecha") stopifnot(
  nrow(x) > 0L, !anyNA(x[[date]]), min(x[[date]]) >= as.Date("2021-01-01"),
  max(x[[date]]) < as.Date("2023-12-01"))
check_sha_a2 <- function(path, sha) stopifnot(file.exists(path),
  substr(system2("sha256sum", shQuote(path), stdout = TRUE), 1, 64) == sha)

# A released corridor and ring path can reconstruct a withheld nested path.
# Retain this family only when every ring and its corridor can be released.
guard_ring_paths <- function(z, groups) {
  z <- copy(z)
  protected <- c(A2_RINGS, "corridor_0_600")
  if ("start" %in% groups) {
    # Whole-path suppression also covers overlapping starts for non-ring units.
    z[, start_complete := all(c(2021L, 2022L) %in% start),
      by = c(setdiff(groups, "start"), "unit")]
    z <- z[start_complete == TRUE]
    z[, start_complete := NULL]
  }
  z[, family_complete := all(protected %in% unit), by = groups]
  # Starts share calendar quarters. Never release a longer-start path that can
  # reconstruct a withheld shorter-start ring path through common benchmarks.
  across_starts <- setdiff(groups, "start")
  if ("start" %in% groups) z[, family_complete :=
    all(family_complete) && all(c(2021L, 2022L) %in% start), by = across_starts]
  z <- z[!unit %in% protected | family_complete]
  z[, family_complete := NULL]
  z
}
