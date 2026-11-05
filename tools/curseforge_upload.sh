#!/usr/bin/env bash
# Uploads a release zip to CurseForge, tagged with the game versions the
# TOCs are built for (## Interface: 11509 -> 1.15.9, WoW Classic Era;
# 16001 -> 1.60.1, WoW Forever).
#
#   tools/curseforge_upload.sh <zip> <version> <toc[,toc...]> <changelog.md>
#
# A game version CurseForge doesn't list (yet) is left out with a warning;
# with none it knows, the upload fails.
#
# Needs CF_API_TOKEN (CurseForge > account settings > API tokens) and the
# project ID: CF_PROJECT_ID, else the TOC's "## X-Curse-Project-ID:" (the
# "Project ID" on the project page). Without them it says so and does
# nothing. Versions before 1.0 go up as beta, later ones as release
# (CF_RELEASE_TYPE: release, beta or alpha overrides it).
# DRY_RUN=1 prints what would be sent instead of
# uploading (CF_VERSIONS_FILE: a saved game versions list, for testing).
set -euo pipefail

# Stops with a message - in a GitHub Actions run also as an error
# annotation on the run, readable without the full log.
Fail() {
  echo "$1" >&2
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error title=CurseForge upload::$(tr '\n' ' ' <<< "$1")"
  fi
  exit 1
}

ZIP=$1 VERSION=$2 TOCS=$3 CHANGELOG=$4
TOC=${TOCS%%,*}
API=${CF_API_BASE:-https://wow.curseforge.com/api}
if [ -z "${CF_PROJECT_ID:-}" ]; then
  CF_PROJECT_ID=$(sed -n 's/^## X-Curse-Project-ID: *//p' "$TOC" | tr -d '\r ')
fi

if [ -z "${CF_API_TOKEN:-}" ] || [ -z "${CF_PROJECT_ID:-}" ]; then
  MESSAGE="CurseForge upload skipped: no CF_API_TOKEN, or no project ID (CF_PROJECT_ID or ## X-Curse-Project-ID: in $TOC)."
  echo "$MESSAGE"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::notice title=CurseForge upload::$MESSAGE"
  fi
  exit 0
fi

Warn() {
  echo "$1" >&2
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning title=CurseForge upload::$1"
  fi
}

if [ -n "${CF_VERSIONS_FILE:-}" ]; then
  VERSIONS=$(cat "$CF_VERSIONS_FILE")
else
  VERSIONS=$(curl -sS -w '\n%{http_code}' -H "X-Api-Token: $CF_API_TOKEN" "$API/game/versions") \
    || Fail "Couldn't reach CurseForge for its game versions."
  if [ "$(tail -n1 <<< "$VERSIONS")" != "200" ]; then
    Fail "CurseForge refused the game versions request (HTTP $(tail -n1 <<< "$VERSIONS")): $(sed '$d' <<< "$VERSIONS" | head -c 300). Is the CURSEFORGE_API_TOKEN secret right?"
  fi
  VERSIONS=$(sed '$d' <<< "$VERSIONS")
fi
# The kinds of game version ("WoW Classic Era", ...), to report what each
# tag is; not needed for the upload.
if [ -n "${CF_VERSION_TYPES_FILE:-}" ]; then
  TYPES=$(cat "$CF_VERSION_TYPES_FILE")
elif [ -n "${CF_VERSIONS_FILE:-}" ]; then
  TYPES="[]"
else
  TYPES=$(curl -sSf -H "X-Api-Token: $CF_API_TOKEN" "$API/game/version-types" 2>/dev/null || echo "[]")
fi
# Interface number -> game version: 11509 -> 1.15.9 (major, two-digit
# minor, two-digit patch). Each TOC's (and each of a TOC's interfaces).
GAME_VERSIONS=() GAME_VERSION_IDS=()
for TOC_FILE in ${TOCS//,/ }; do
  for INTERFACE in $(sed -n 's/^## Interface: *//p' "$TOC_FILE" | tr -d '\r ' | tr ',' ' '); do
    GAME_VERSION="$((INTERFACE / 10000)).$((INTERFACE / 100 % 100)).$((INTERFACE % 100))"
    # (Every game version of that name: the same number can exist for more
    # than one kind of game.)
    IDS=$(jq -r --arg name "$GAME_VERSION" '[.[] | select(.name == $name) | .id] | join(" ")' <<< "$VERSIONS")
    if [ -z "$IDS" ]; then
      Warn "CurseForge has no game version $GAME_VERSION (from ## Interface: $INTERFACE in $TOC_FILE); left out. Close ones: $(jq -r --arg major "${GAME_VERSION%.*}" '[.[] | select(.name | startswith($major)) | .name] | join(", ")' <<< "$VERSIONS")"
    else
      for ID in $IDS; do
        if [[ " ${GAME_VERSION_IDS[*]} " != *" $ID "* ]]; then
          KIND=$(jq -r --argjson id "$ID" --argjson types "$TYPES" \
            '([.[] | select(.id == $id)][0].gameVersionTypeID) as $type | ([$types[] | select(.id == $type)][0].name // ("type " + ($type | tostring)))' <<< "$VERSIONS")
          GAME_VERSIONS+=("$GAME_VERSION ($KIND)")
          GAME_VERSION_IDS+=("$ID")
        fi
      done
    fi
  done
done
if [ ${#GAME_VERSION_IDS[@]} -eq 0 ]; then
  Fail "CurseForge knows none of the game versions in $TOCS."
fi
GAME_VERSION=$(IFS=,; echo "${GAME_VERSIONS[*]}" | sed 's/,/, /g')

RELEASE_TYPE=${CF_RELEASE_TYPE:-}
if [ -z "$RELEASE_TYPE" ]; then
  if [ "${VERSION%%.*}" = "0" ]; then RELEASE_TYPE=beta; else RELEASE_TYPE=release; fi
fi
case "$RELEASE_TYPE" in
  release|beta|alpha) ;;
  *) Fail "CF_RELEASE_TYPE must be release, beta or alpha (not \"$RELEASE_TYPE\")." ;;
esac

METADATA=$(jq -n \
  --arg changelog "$(cat "$CHANGELOG")" \
  --arg name "Pathwise $VERSION" \
  --argjson gameVersions "[$(IFS=,; echo "${GAME_VERSION_IDS[*]}")]" \
  --arg releaseType "$RELEASE_TYPE" \
  '{changelog: $changelog, changelogType: "markdown", displayName: $name, gameVersions: $gameVersions, releaseType: $releaseType}')

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "Would upload $ZIP to project $CF_PROJECT_ID for $GAME_VERSION:"
  echo "$METADATA"
  exit 0
fi

# (--form-string: the metadata as it is - with -F, curl reads a ";" in the
# changelog as the start of an option and cuts the JSON short.)
RESPONSE=$(curl -sS -w '\n%{http_code}' -H "X-Api-Token: $CF_API_TOKEN" \
  --form-string "metadata=$METADATA" -F "file=@$ZIP" "$API/projects/$CF_PROJECT_ID/upload-file") \
  || Fail "Couldn't reach CurseForge to upload."
STATUS=$(tail -n1 <<< "$RESPONSE")
BODY=$(sed '$d' <<< "$RESPONSE")
if [ "$STATUS" != "200" ]; then
  Fail "CurseForge upload failed (HTTP $STATUS): $(head -c 500 <<< "$BODY")"
fi
MESSAGE="Uploaded $ZIP to CurseForge for $GAME_VERSION as $RELEASE_TYPE: file $(jq -r '.id // "?"' <<< "$BODY")."
echo "$MESSAGE"
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo "::notice title=CurseForge upload::$MESSAGE"
fi
