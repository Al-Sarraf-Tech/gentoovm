#!/usr/bin/env bash
# Unit tests: Shell script quality across the entire repo
# Validates strict mode, syntax, permissions, and shellcheck compliance
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="script-quality"

echo "=== Script Quality Tests ==="

# Collect all shell scripts
mapfile -t SCRIPTS < <(find "$REPO_DIR" -name '*.sh' -not -path '*/.git/*' -type f | sort)

# --- Syntax ---
echo "--- Shell syntax ---"
for f in "${SCRIPTS[@]}"; do
    assert_shell_syntax "$f"
done

# --- Strict mode ---
echo "--- Strict mode (set -euo pipefail) ---"
for f in "${SCRIPTS[@]}"; do
    # Skip test lib (it sets this for sourcing scripts)
    [[ "$f" == */lib/assertions.sh ]] && continue
    assert_script_strict "$f"
done

# --- Executable permissions on entry points ---
echo "--- Executable permissions ---"
for f in "$REPO_DIR"/run-*.sh "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/qemu/*.sh "$REPO_DIR"/iso/reassemble.sh; do
    [ -f "$f" ] && assert_executable "$f"
done

# --- Shebang lines ---
echo "--- Shebang lines ---"
for f in "${SCRIPTS[@]}"; do
    if head -1 "$f" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash'; then
        pass "shebang: $(basename "$f")"
    else
        fail "missing/wrong shebang: $(basename "$f")"
    fi
done

# --- No hardcoded secrets in scripts (exclude test files that contain scan patterns) ---
echo "--- No secrets in scripts ---"
for f in "${SCRIPTS[@]}"; do
    [[ "$f" == */tests/* ]] && continue
    assert_file_not_contains "$f" 'BEGIN.*PRIVATE KEY' "no private keys: $(basename "$f")"
done

# --- ShellCheck (if available) ---
echo "--- ShellCheck ---"
if command -v shellcheck &>/dev/null; then
    for f in "${SCRIPTS[@]}"; do
        if shellcheck --severity=warning "$f" &>/dev/null; then
            pass "shellcheck: $(basename "$f")"
        else
            fail "shellcheck warnings: $(basename "$f")"
        fi
    done
else
    skip "shellcheck not installed"
fi

test_summary
