#!/bin/bash
# Fetches QuestieDB (GPL-3.0) at a pinned commit into tests/sim/.cache, for
# the real-data simulations (tests/sim/run.sh). Test data only: it's never
# part of the addon's zip. Run from the repository root.
set -e
COMMIT=47a4756b775e8c73687fd3066d6c13f0bc43a55e
DIR=tests/sim/.cache/QuestieDB
if [ -d "$DIR/.git" ] && [ "$(git -C "$DIR" rev-parse HEAD 2>/dev/null)" = "$COMMIT" ]; then
  exit 0
fi
rm -rf "$DIR"
mkdir -p "$DIR"
git -C "$DIR" init -q
git -C "$DIR" remote add origin https://github.com/Questie/QuestieDB
GIT_LFS_SKIP_SMUDGE=1 git -C "$DIR" fetch -q --depth 1 origin "$COMMIT"
GIT_LFS_SKIP_SMUDGE=1 git -C "$DIR" checkout -q FETCH_HEAD
echo "QuestieDB $COMMIT in $DIR"
