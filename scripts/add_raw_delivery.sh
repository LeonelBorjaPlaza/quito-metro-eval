#!/usr/bin/env bash
# Add a new raw data delivery to the shared data store and lock it.
#
# Leonel runs this in his own terminal, not inside Claude Code: only a person adds raw data.
#
# Usage (from the repository root):
#   bash scripts/add_raw_delivery.sh <module> <label> <file_or_folder> [<file_or_folder> ...]
#     <module>  air_quality | congestion | road_safety
#     <label>   short name without spaces, for example remmaq_pm25_redownload
#   The folder is named after the date the data were received. It defaults to today;
#   set RECEIVED_DATE to use another date, for example:
#   RECEIVED_DATE=2026-09-23 bash scripts/add_raw_delivery.sh road_safety crash_update ~/Downloads/file.xlsx
#
# What it does:
#   1. Copies the sources into $DATA_STORE/<module>/raw/<YYYY-MM-DD>_<label>/
#   2. Writes SHA256SUMS for every copied file.
#   3. Makes the new folder and its files read-only.
#   4. Writes a provenance note in docs/data_provenance/ for you to complete and commit.
set -euo pipefail

DATA_STORE="${DATA_STORE:-$HOME/data/quito-metro-eval}"

module="${1:?Give the module: air_quality, congestion or road_safety}"
label="${2:?Give a short label without spaces}"
shift 2
if [[ $# -lt 1 ]]; then
  echo "Give at least one file or folder to copy." >&2
  exit 1
fi
case "$module" in
  air_quality|congestion|road_safety) ;;
  *) echo "Unknown module: $module" >&2; exit 1 ;;
esac
if [[ "$label" =~ [[:space:]] ]]; then
  echo "The label cannot contain spaces." >&2
  exit 1
fi
if [[ ! -d docs ]]; then
  echo "Run this from the repository root (the folder that holds docs/)." >&2
  exit 1
fi

stamp="${RECEIVED_DATE:-$(date +%F)}"
if [[ ! "$stamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "RECEIVED_DATE must look like 2026-09-23." >&2
  exit 1
fi
dest="$DATA_STORE/$module/raw/${stamp}_${label}"
if [[ -e "$dest" ]]; then
  echo "Already exists: $dest" >&2
  exit 1
fi

mkdir -p "$dest"
for src in "$@"; do
  cp -a -- "$src" "$dest"/
done

( cd "$dest" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )

# Lock the delivery: files and folders inside it become read-only, and so does the delivery folder itself.
find "$dest" -mindepth 1 -exec chmod a-w {} +
chmod a-w "$dest"

prov="docs/data_provenance/${module}__${stamp}_${label}.md"
mkdir -p docs/data_provenance
{
  echo "# ${module}: ${stamp}_${label}"
  echo
  echo "- Store folder: \`${dest}\`"
  echo "- Received on ${stamp}; added to the store on $(date +%F) by $(whoami)"
  echo "- Copied from: $*"
  echo "- Sent by or obtained from: <fill in>"
  echo "- What it covers (period, units, variables): <fill in>"
  echo "- Terms of use: <fill in>"
  echo "- Known gaps or caveats: <fill in>"
  echo
  echo "## Files and sha256"
  echo
  echo '```'
  cat "$dest/SHA256SUMS"
  echo '```'
} > "$prov"

echo "Added and locked: $dest"
echo "Provenance note to complete and commit: $prov"
echo "If the module's code reads this delivery at a fixed path, add a symlink to it and commit the link with git add -f."
