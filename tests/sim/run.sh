#!/bin/bash
# Runs every real-data scenario (tests/sim/scenarios.txt, one process each,
# in parallel) and the reported cases (tests/sim/regressions.lua). Exits 1
# when any fails. From the repository root:  tests/sim/run.sh
#   SIM_JOBS=4        how many at once
#   SIM_BUDGET_MS=40  how long a plan may take
set -e
tests/sim/fetch.sh
JOBS=${SIM_JOBS:-4}
OUT=$(mktemp)
grep -v '^#' tests/sim/scenarios.txt | grep -v '^$' \
  | xargs -P "$JOBS" -L 1 sh -c 'lua5.1 tests/sim/check.lua "$@" 2>&1 || echo "FAIL [$*] (exit $?)"' sh > "$OUT" || true
lua5.1 tests/sim/regressions.lua >> "$OUT" 2>&1 || echo "FAIL regressions (exit $?)" >> "$OUT"
# (A failed scenario prints its problems, then "(exit 1)".)
OK=$(grep '^ok ' "$OUT" | grep -vc ' FAILS ' || true)
BAD=$(grep -c '(exit [0-9]*)$' "$OUT" || true)
grep '^FAIL' "$OUT" | grep -v '(exit [0-9]*)$' || true
echo "Simulations: $OK ok, $BAD failed"
rm -f "$OUT"
[ "$BAD" -eq 0 ]
