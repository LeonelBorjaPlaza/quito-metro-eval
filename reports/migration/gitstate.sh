#!/usr/bin/env bash
# Usage: gitstate.sh aq|waze  -> prints read-only git state of the source
set -u; source ~/quito-metro-kit/settings.env
if [ "$1" = aq ]; then SRC="$AQ_SRC"; G=(git --no-optional-locks -c core.autocrlf=true -c core.filemode=false -C "$SRC"); else SRC="$WAZE_SRC"; G=(git --no-optional-locks -C "$SRC"); fi
echo "## source: $SRC"
echo "## HEAD"; "${G[@]}" rev-parse HEAD
echo "## current branch"; "${G[@]}" branch --show-current
echo "## branches"; "${G[@]}" branch -a -vv
echo "## last 15 commits"; "${G[@]}" log --oneline -15 --date=short --format='%h %ad %s'
echo "## remotes"; "${G[@]}" remote -v
echo "## unpushed"; if "${G[@]}" rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then "${G[@]}" log --oneline @{u}..HEAD; else echo "(no upstream)"; fi
echo "## stashes"; "${G[@]}" stash list
echo "## status (modified + untracked)"; "${G[@]}" status --porcelain=v1 --untracked-files=all
echo "## ignored files with sizes"; "${G[@]}" ls-files --others --ignored --exclude-standard -z | (cd "$SRC" && xargs -0 -r stat -c '%s	%n' ) | sort -k2
