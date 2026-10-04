#!/usr/bin/env bash
# Step 1 setup for a fresh checkout or worktree. Run from congestion/.
# 1. Copies the ignored project library from the main checkout if it is absent.
# 2. Adds augsynth 0.2.0 (GitHub 65c5a6f), its three missing dependencies, and synthdid 0.0.9
#    (GitHub 70c1ce3) with mvtnorm 1.3-7 (Amendment 5), from the
#    renv cache that the air quality restore filled. No network, no compiling.
# 3. Checks every congestion raw file, read through the committed symlinks, against
#    the store's MANIFEST.sha256.
# 4. Loads augsynth and runs a tiny fit on its bundled example data.
set -euo pipefail
test -f AGENTS.md || { echo "Run from congestion/"; exit 1; }

# The main checkout holds the project library; the shared git directory is <main checkout>/.git.
MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
MAIN_ENV="$MAIN_ROOT/congestion/Output/Waze/_environment"
LIB="Output/Waze/_environment/R-library"
CACHE="$HOME/.cache/R/renv/cache/v5/linux-ubuntu-resolute/R-4.5/x86_64-pc-linux-gnu"
# The data store root, from the committed raw symlink (<store>/congestion/raw/Data/Waze/raw).
RAW_TARGET="$(readlink -f Data/Waze/raw)"
STORE="${RAW_TARGET%/congestion/raw/Data/Waze/raw}"
test -f "$STORE/MANIFEST.sha256" || { echo "No MANIFEST.sha256 under $STORE"; exit 1; }
OUT="Output/Waze/step1"
mkdir -p "$OUT" Output/Waze/_cache

if [ ! -d "$LIB" ]; then
  cp -a "$MAIN_ENV" Output/Waze/
fi

# Versions pinned by air_quality/renv.lock. The other augsynth dependencies already
# resolve from the project or system libraries.
for pkg in augsynth/0.2.0 osqp/1.0.0 FNN/1.1.4.1 LiblineaR/2.10-24 synthdid/0.0.9 mvtnorm/1.3-7; do
  name="${pkg%%/*}"
  if [ ! -d "$LIB/$name" ]; then
    src=( "$CACHE"/"$pkg"/*/"$name" )
    [ "${#src[@]}" -eq 1 ] && [ -d "${src[0]}" ] || { echo "Not in renv cache: $pkg"; exit 1; }
    cp -a "${src[0]}" "$LIB/"
  fi
done

# scpi 4.0.1 (Cattaneo, Feng and Titiunik prediction intervals; Amendment 5, approved by Leonel on
# 2026-10-01) and its dependencies, as Posit Linux binaries from the dated snapshot of 2026-10-01,
# so every checkout gets the same versions. Needs network once; no compiling, no system libraries.
if [ ! -d "$LIB/scpi" ]; then
  Rscript -e '
    lib <- normalizePath("Output/Waze/_environment/R-library")
    .libPaths(c(lib, .libPaths()))
    options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
            paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
    install.packages("scpi", lib = lib, dependencies = c("Depends", "Imports", "LinkingTo"),
                     repos = "https://packagemanager.posit.co/cran/__linux__/resolute/2026-10-01")
    stopifnot(requireNamespace("scpi", quietly = TRUE), as.character(packageVersion("scpi")) == "4.0.1")'
fi

# Store paths map to checkout paths through the committed symlinks.
grep '  congestion/raw/' "$STORE/MANIFEST.sha256" \
  | sed -e 's#  congestion/raw/Data/Waze/raw/#  Data/Waze/raw/#' \
        -e 's#  congestion/raw/Data/spatial/#  Data/spatial/#' \
        -e 's#  congestion/raw/docs/#  docs/#' \
        -e 's#  congestion/raw/2026-09-29_centro_historico_poligono/#  Data/geo/centro_historico_poligono/#' \
        -e 's#  congestion/raw/2026-09-29_historic_center_geography/#  Data/geo/historic_center_geography/#' \
        -e 's#  congestion/raw/2026-09-29_osm_roads_20220101/#  Data/geo/osm_roads_20220101/#' > Output/Waze/_cache/raw_manifest_check.txt
sha256sum -c Output/Waze/_cache/raw_manifest_check.txt > "$OUT/raw_checksum_result.txt"
echo "Raw files checked: $(wc -l < "$OUT/raw_checksum_result.txt"), all OK"

Rscript -e '
.libPaths(c(normalizePath("Output/Waze/_environment/R-library"), .libPaths()))
suppressPackageStartupMessages(library(augsynth))
stopifnot(packageDescription("augsynth")$RemoteSha == "65c5a6f34f4e4a8b1011182fe12309ef022d992f")
data(kansas)
kansas$treated <- kansas$state == "Kansas" & kansas$year_qtr >= 2012.5
fit <- augsynth(lngdpcapita ~ treated, fips, year_qtr, kansas, progfunc = "Ridge", scm = TRUE, fixedeff = TRUE)
stopifnot(is.finite(fit$lambda))
writeLines(c(paste("augsynth", packageVersion("augsynth"), packageDescription("augsynth")$RemoteSha),
  paste("synthdid", packageVersion("synthdid"), packageDescription("synthdid")$RemoteSha), paste("scpi", packageVersion("scpi")),
  capture.output(sessionInfo())), "Output/Waze/step1/setup_session.txt")
cat("augsynth loads and fits.\n")'
