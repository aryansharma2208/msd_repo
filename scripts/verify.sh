#!/usr/bin/env bash
# Check that a running hello-service answers correctly.
# Usage: scripts/verify.sh http://<host>[:port]
# Exit code 0 = healthy, 1 = something failed (message says what).
set -euo pipefail

BASE="${1:?usage: $0 http://host[:port]}"
BASE="${BASE%/}"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "Checking $BASE/health ..."
health="$(curl -fsS --max-time 5 "$BASE/health")" || fail "/health did not return HTTP 200"
echo "$health" | grep -q '"status": "ok"' || fail "/health body was not status ok: $health"
echo "  OK  $health"

echo "Checking $BASE/ ..."
body="$(curl -fsS --max-time 5 "$BASE/")" || fail "/ did not return HTTP 200"
[ -n "$body" ] || fail "/ returned an empty body"
echo "  OK  $body"

echo "Checking unknown path returns 404 ..."
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$BASE/nope")"
[ "$code" = "404" ] || fail "expected 404, got $code"
echo "  OK  404"

echo "All checks passed."
