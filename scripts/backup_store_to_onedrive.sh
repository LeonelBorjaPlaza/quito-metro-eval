#!/usr/bin/env bash
# One-way backup of the data store (raw deliveries and frozen references) to OneDrive,
# which the IDB backs up. WSL files are not backed up by anything else.
#
# Leonel runs this by hand, for example after adding a delivery:
#   bash scripts/backup_store_to_onedrive.sh
#
# It copies new and changed files and never deletes anything on the OneDrive side.
set -euo pipefail

DATA_STORE="${DATA_STORE:-$HOME/data/quito-metro-eval}"
ONEDRIVE_BACKUP="${ONEDRIVE_BACKUP:-/mnt/c/Users/LEONELB/OneDrive - Inter-American Development Bank Group/quito-metro-eval_data-backup}"

if [[ ! -d "$DATA_STORE" ]]; then
  echo "Data store not found: $DATA_STORE" >&2
  exit 1
fi
mkdir -p "$ONEDRIVE_BACKUP"
if command -v rsync >/dev/null 2>&1; then
  # -r recursive, -t keep modification times. No permissions or owners (the Windows side
  # ignores them) and no --delete, so older files stay in the backup.
  rsync -rt --info=stats1 "$DATA_STORE"/ "$ONEDRIVE_BACKUP"/
else
  # Without rsync: copy files that are new or newer than the backup copy, keeping times.
  cp -r --update --preserve=timestamps "$DATA_STORE"/. "$ONEDRIVE_BACKUP"/
fi
echo "Backup finished: $DATA_STORE -> $ONEDRIVE_BACKUP"
