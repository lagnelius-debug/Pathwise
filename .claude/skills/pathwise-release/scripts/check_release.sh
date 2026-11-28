#!/bin/sh
# After a push to main: waits for the Release workflow run of a commit,
# then shows its result, the newest release and the CurseForge step's
# annotation (notice = uploaded, warning = skipped, error = failed).
# Usage: check_release.sh [SHA] [VERSION]   (defaults: HEAD, the TOC version)
cd "$(git rev-parse --show-toplevel)"
REPO=lagnelius-debug/Pathwise
SHA=$(git rev-parse "${1:-HEAD}")
VERSION=${2:-$(sed -n 's/^## Version: *//p' Pathwise_Vanilla.toc | tr -d '\r')}
ID=""
for _ in $(seq 1 60); do
  RUN=$(gh api "repos/$REPO/actions/runs?head_sha=$SHA&event=push" \
    --jq '[.workflow_runs[] | select(.name == "Release")][0] | "\(.id) \(.status) \(.conclusion)"' 2>/dev/null)
  set -- $RUN
  ID=$1; STATUS=$2; CONCLUSION=$3
  if [ -n "$ID" ] && [ "$ID" != "null" ] && [ "$STATUS" = "completed" ]; then
    break
  fi
  sleep 15
done
if [ -z "$ID" ] || [ "$ID" = "null" ]; then
  echo "no Release run for $SHA (pushed? check https://github.com/$REPO/actions)"; exit 1
fi
echo "run $ID: $STATUS $CONCLUSION  https://github.com/$REPO/actions/runs/$ID"
[ "$STATUS" = "completed" ] || { echo "still running after 15 min"; exit 1; }
TAG=$(gh api "repos/$REPO/releases" --jq '.[0].tag_name')
echo "newest release: $TAG (expected v$VERSION)"
JOB=$(gh api "repos/$REPO/actions/runs/$ID/jobs" --jq '.jobs[0].id')
CF=$(gh api "repos/$REPO/check-runs/$JOB/annotations" \
  --jq '.[] | select(.title | test("CurseForge")) | "\(.annotation_level): \(.message)"')
echo "CurseForge: ${CF:-no annotation (step skipped?)}"
if [ "$CONCLUSION" != "success" ]; then
  echo "failed steps:"
  gh api "repos/$REPO/actions/runs/$ID/jobs" --jq '.jobs[0].steps[] | select(.conclusion == "failure") | "  " + .name'
  exit 1
fi
[ "$TAG" = "v$VERSION" ] || exit 1
