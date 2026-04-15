#!/usr/bin/env bash
set -euo pipefail

# Run all unit tests in tests/unit/
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
PASSED=0
SUITE_START=$(date +%s)

echo "=========================================="
echo "  Running Unit Test Suite"
echo "=========================================="

for test in "$REPO_DIR"/tests/unit/test-*.sh; do
    [ -f "$test" ] || continue
    name=$(basename "$test" .sh)
    echo ""
    echo ">>> $name"
    TEST_START=$(date +%s)
    if bash "$test"; then
        ELAPSED=$(( $(date +%s) - TEST_START ))
        PASSED=$((PASSED+1))
        echo ">>> $name: PASSED (${ELAPSED}s)"
    else
        ELAPSED=$(( $(date +%s) - TEST_START ))
        FAILED=$((FAILED+1))
        echo ">>> $name: FAILED (${ELAPSED}s)"
    fi
done

TOTAL_ELAPSED=$(( $(date +%s) - SUITE_START ))

echo ""
echo "=========================================="
if [ "$FAILED" -gt 0 ]; then
    echo "  RESULT: $FAILED suite(s) FAILED, $PASSED passed (${TOTAL_ELAPSED}s)"
    echo "=========================================="
    exit 1
else
    echo "  RESULT: ALL $PASSED SUITES PASSED (${TOTAL_ELAPSED}s)"
    echo "=========================================="
    exit 0
fi
