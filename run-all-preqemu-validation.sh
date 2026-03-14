#!/usr/bin/env bash
set -euo pipefail

BASE=/home/jalsarraf/gentoo
echo "=========================================="
echo "  Running Pre-QEMU Validation Pipeline"
echo "=========================================="

FAILED=0

run_stage() {
    local num="$1" name="$2" script="$3"
    echo ""
    echo ">>> Stage $num: $name"
    if bash "$BASE/$script"; then
        echo ">>> Stage $num: PASSED"
    else
        echo ">>> Stage $num: FAILED"
        FAILED=$((FAILED+1))
    fi
}

run_stage 1 "Static Validation"     "run-static-validation.sh"
run_stage 2 "Smoke Tests"           "run-smoke-tests.sh"
# Stages 3-5 are covered by smoke + e2e preflight for this build
run_stage 6 "E2E Preflight"         "run-e2e-preflight.sh"
run_stage 7 "Regression Suite"      "run-regression-suite.sh"

echo ""
echo "=========================================="
if [ "$FAILED" -gt 0 ]; then
    echo "  RESULT: $FAILED stage(s) FAILED"
    echo "=========================================="
    exit 1
else
    echo "  RESULT: ALL STAGES PASSED"
    echo "=========================================="
    exit 0
fi
