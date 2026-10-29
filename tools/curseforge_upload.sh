#!/usr/bin/env bash
# Uploads a release zip to CurseForge, tagged with the game version the TOC
# is built for (## Interface: 11509 -> 1.15.9, WoW Classic Era).
#
#   tools/curseforge_upload.sh <zip> <version> <toc> <changelog.md>
#
# Needs CF_API_TOKEN (CurseForge > account settings > API tokens) and the
# project ID: CF_PROJECT_ID, else the TOC's "## X-Curse-Project-ID:" (the
# "Project ID" on the project page). Without them it says so and does
# nothing. DRY_RUN=1 prints what would be sent instead of
# uploading (CF_VERSIONS_FILE: a saved game versions list, for testing).
set -euo pipefail

ZIP=$1 VERSION=$2 TOC=$3 CHANGELOG=$4
API=${CF_API_BASE:-https://wow.curseforge.com/api}
if [ -z "${CF_PROJECT_ID:-}" ]; then
  CF_PROJECT_ID=$(sed -n 's/^## X-Curse-Project-ID: *//p' "$TOC" | tr -d '\r ')
fi

if [ -z "${CF_API_TOKEN:-}" ] || [ -z "${CF_PROJECT_ID:-}" ]; then
  echo "CurseForge upload skipped: no CF_API_TOKEN, or no project ID (CF_PROJECT_ID or ## X-Curse-Project-ID: in $TOC)."
  exit 0
fi

# Interface number -> game version: 11509 -> 1.15.9 (major, two-digit
# minor, two-digit patch).
INTERFACE=$(sed -n 's/^## Interface: *//p' "$TOC" | tr -d '\r' | cut -d, -f1)
GAME_VERSION="$((INTERFACE / 10000)).$((INTERFACE / 100 % 100)).$((INTERFACE % 100))"

if [ -n "${CF_VERSIONS_FILE:-}" ]; then
  VERSIONS=$(cat "$CF_VERSIONS_FILE")
else
  VERSIONS=$(curl -sSf -H "X-Api-Token: $CF_API_TOKEN" "$API/game/versions")
fi
GAME_VERSION_ID=$(jq -r --arg name "$GAME_VERSION" '[.[] | select(.name == $name)][0].id // empty' <<< "$VERSIONS")
if [ -z "$GAME_VERSION_ID" ]; then
  echo "CurseForge has no game version $GAME_VERSION (from ## Interface: $INTERFACE in $TOC)." >&2
  echo "Close ones: $(jq -r --arg major "${GAME_VERSION%.*}" '[.[] | select(.name | startswith($major)) | .name] | join(", ")' <<< "$VERSIONS")" >&2
  exit 1
fi

METADATA=$(jq -n \
  --arg changelog "$(cat "$CHANGELOG")" \
  --arg name "Pathwise $VERSION" \
  --argjson gameVersion "$GAME_VERSION_ID" \
  '{changelog: $changelog, changelogType: "markdown", displayName: $name, gameVersions: [$gameVersion], releaseType: "release"}')

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "Would upload $ZIP to project $CF_PROJECT_ID for $GAME_VERSION (id $GAME_VERSION_ID):"
  echo "$METADATA"
  exit 0
fi

RESPONSE=$(curl -sS -w '\n%{http_code}' -H "X-Api-Token: $CF_API_TOKEN" \
  -F "metadata=$METADATA" -F "file=@$ZIP" "$API/projects/$CF_PROJECT_ID/upload-file")
STATUS=$(tail -n1 <<< "$RESPONSE")
BODY=$(sed '$d' <<< "$RESPONSE")
if [ "$STATUS" != "200" ]; then
  echo "CurseForge upload failed (HTTP $STATUS): $BODY" >&2
  exit 1
fi
echo "Uploaded $ZIP to CurseForge for $GAME_VERSION: file $(jq -r '.id // "?"' <<< "$BODY")."
