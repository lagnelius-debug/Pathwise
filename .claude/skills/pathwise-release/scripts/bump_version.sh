#!/bin/sh
# Bumps "## Version:" in the four TOCs to NEW, after checking they all hold
# the same version now and CHANGELOG.md has no section for NEW yet.
# Usage: bump_version.sh NEW        (run from anywhere in the repo)
set -e
cd "$(git rev-parse --show-toplevel)"
NEW=$1
echo "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "usage: $0 X.Y.Z" >&2; exit 1; }
OLD=$(sed -n 's/^## Version: *//p' Pathwise_Vanilla.toc | tr -d '\r')
for toc in Pathwise.toc Pathwise_Vanilla.toc Pathwise_Forever.toc Pathwise_Camelot.toc; do
  v=$(sed -n 's/^## Version: *//p' "$toc" | tr -d '\r')
  [ "$v" = "$OLD" ] || { echo "$toc has $v, Pathwise_Vanilla.toc has $OLD" >&2; exit 1; }
done
[ "$OLD" != "$NEW" ] || { echo "already $NEW" >&2; exit 1; }
if grep -qx "## $NEW" CHANGELOG.md; then
  echo "note: CHANGELOG.md already has a section for $NEW"
fi
sed -i "s/^## Version: $OLD\$/## Version: $NEW/" Pathwise*.toc
echo "$OLD -> $NEW"
grep -H '^## Version:' Pathwise*.toc
