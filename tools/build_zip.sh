#!/bin/sh
# Builds the installable addon zip from the committed HEAD: one top-level
# "Pathwise" folder (as Interface/AddOns expects), without tests, docs and
# tools. Usage: tools/build_zip.sh <output.zip>
set -e
cd "$(dirname "$0")/.."
OUT=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
STAGE=$(mktemp -d)
git archive --format=tar --prefix=Pathwise/ HEAD | tar -x -C "$STAGE"
rm -rf "$STAGE/Pathwise/tests" "$STAGE/Pathwise/docs" "$STAGE/Pathwise/tools" \
  "$STAGE/Pathwise/.github" "$STAGE/Pathwise/CLAUDE.md" "$STAGE/Pathwise/SECURITY.md"
rm -f "$OUT"
(cd "$STAGE" && zip -qr "$OUT" Pathwise)
rm -rf "$STAGE"
