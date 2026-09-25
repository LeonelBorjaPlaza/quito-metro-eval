#!/bin/bash
# ============================================================================
#  bundle_results.sh - Bundle outputs into a single tarball for download
# ============================================================================
#  Run after all 4 pollutants complete:
#    bash bundle_results.sh
#
#  Produces:
#    ~/v4_results_<YYYYMMDD_HHMM>.tar.gz
#  Containing: output/ + logs/
#
#  Download from the SSH window: ⚙ -> Download file -> path of the tarball.
# ============================================================================

set -e
cd "$(dirname "$0")/.."

STAMP=$(date +%Y%m%d_%H%M)
BUNDLE="v4_results_${STAMP}.tar.gz"

echo "Bundling output/ + logs/ into $BUNDLE ..."
tar czf "$BUNDLE" output/ logs/

SIZE=$(du -h "$BUNDLE" | cut -f1)
echo ""
echo "Bundle ready: $(pwd)/$BUNDLE ($SIZE)"
echo ""
echo "Download command (paste path in GCP SSH download dialog):"
echo "  $(pwd)/$BUNDLE"
