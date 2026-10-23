#!/bin/sh
# Releases the pushed main branch: checks it, then pushes an annotated tag
# v<version> (version from Pathwise_Vanilla.toc - bump both TOCs first).
# The tag starts .github/workflows/release.yml on GitHub, which builds
# Pathwise-<version>.zip and publishes it as a release.
# Also builds the same zip locally (../Pathwise-<version>.zip, or in
# $PATHWISE_ZIP_DIR) to hand out directly.
# Usage: tools/release.sh "release notes"
set -e
cd "$(dirname "$0")/.."
VERSION=$(sed -n 's/^## Version: *//p' Pathwise_Vanilla.toc | tr -d '\r')
TAG="v$VERSION"

cmp -s Pathwise_Vanilla.toc Pathwise.toc || { echo "TOC files differ"; exit 1; }
lua5.1 tests/run.lua > /dev/null || { echo "Tests fail"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Uncommitted changes"; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Push main first"; exit 1; }
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" > /dev/null; then
  echo "$TAG already exists: bump the version"; exit 1
fi

tools/build_zip.sh "${PATHWISE_ZIP_DIR:-..}/Pathwise-$VERSION.zip"
git tag -a "$TAG" -m "${1:-Pathwise $VERSION}"
git push origin "$TAG"
echo "Pushed $TAG; GitHub builds the release: https://github.com/lagnelius-debug/Pathwise/releases/tag/$TAG"
