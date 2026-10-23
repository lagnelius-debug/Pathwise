#!/bin/sh
# Builds Pathwise-<version>.zip (one "Pathwise" folder, no tests/docs) and
# publishes it as a GitHub release tagged v<version> on the pushed main
# branch. The version comes from Pathwise_Vanilla.toc: bump it (both TOCs)
# before releasing. Usage: tools/release.sh ["release notes"]
set -e
cd "$(dirname "$0")/.."
REPO=lagnelius-debug/Pathwise
VERSION=$(sed -n 's/^## Version: *//p' Pathwise_Vanilla.toc | tr -d '\r')
ZIP="Pathwise-$VERSION.zip"
OUT="${PATHWISE_ZIP_DIR:-..}/$ZIP"

cmp -s Pathwise_Vanilla.toc Pathwise.toc || { echo "TOC files differ"; exit 1; }
lua5.1 tests/run.lua > /dev/null || { echo "Tests fail"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Uncommitted changes"; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Push main first"; exit 1; }

# Zip with a top-level "Pathwise" folder, as Interface/AddOns expects.
STAGE=$(mktemp -d)
git archive --format=tar --prefix=Pathwise/ HEAD | tar -x -C "$STAGE"
rm -rf "$STAGE/Pathwise/tests" "$STAGE/Pathwise/docs" "$STAGE/Pathwise/tools" "$STAGE/Pathwise/CLAUDE.md"
rm -f "$OUT"
(cd "$STAGE" && zip -qr - Pathwise) > "$OUT"
rm -rf "$STAGE"

NOTES=${1:-"Pathwise $VERSION"}
BODY="$NOTES

Download **$ZIP** below (not \"Source code\"), unzip it into World of Warcraft/_classic_era_/Interface/AddOns, and check that the folder is named Pathwise."
ID=$(gh api "repos/$REPO/releases" -f tag_name="v$VERSION" -f target_commitish="$(git rev-parse HEAD)" \
  -f name="Pathwise $VERSION" -f body="$BODY" --jq .id)
gh api -X POST "https://uploads.github.com/repos/$REPO/releases/$ID/assets?name=$ZIP" \
  -H "Content-Type: application/zip" --input "$OUT" --jq .browser_download_url
echo "Built $OUT"
