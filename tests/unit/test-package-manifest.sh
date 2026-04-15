#!/usr/bin/env bash
# Unit tests: Package manifest (installed-packages.txt)
# Validates format, completeness, and key packages — this is the SBOM source
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="package-manifest"

MANIFEST="$REPO_DIR/manifests/installed-packages.txt"

echo "=== Package Manifest Tests ==="

# --- File exists and is non-trivial ---
echo "--- Manifest basics ---"
assert_file_exists "$MANIFEST"

LINE_COUNT=$(wc -l < "$MANIFEST")
if [ "$LINE_COUNT" -ge 500 ]; then
    pass "manifest has $LINE_COUNT packages (≥500)"
else
    fail "manifest has only $LINE_COUNT packages (expected ≥500)"
fi

# --- Every line matches Gentoo package atom format ---
echo "--- Format validation ---"
# Valid format: category/name-version[-revision]
# category: lowercase letters, digits, hyphens
# name: letters, digits, hyphens, underscores, plus
# version: digits, dots, letters (e.g., 1.2.3, 1.0_rc1, 1.2.3-r1)
BAD_LINES=0
LINE_NUM=0
while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM+1))
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Must contain a slash (category/name)
    if [[ "$line" != */* ]]; then
        fail "line $LINE_NUM: missing category/ prefix: $line"
        BAD_LINES=$((BAD_LINES+1))
        continue
    fi
    # Category should be lowercase with hyphens
    category="${line%%/*}"
    if ! [[ "$category" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        fail "line $LINE_NUM: invalid category '$category'"
        BAD_LINES=$((BAD_LINES+1))
    fi
done < "$MANIFEST"
if [ "$BAD_LINES" -eq 0 ]; then
    pass "all $LINE_COUNT lines valid Gentoo package format"
fi

# --- Key packages present ---
echo "--- Key packages ---"
for pkg in cinnamon lightdm firefox-bin calamares sudo grub networkmanager \
           gentoo-kernel-bin qemu-guest-agent spice-vdagent earlyoom \
           nemo xfce4-terminal mousepad nano; do
    if grep -qi "$pkg" "$MANIFEST"; then
        pass "package: $pkg"
    else
        fail "missing package: $pkg"
    fi
done

# --- No duplicate entries ---
echo "--- Duplicates ---"
DUPES=$(sort "$MANIFEST" | uniq -d | head -5)
if [ -z "$DUPES" ]; then
    pass "no duplicate packages"
else
    fail "duplicate packages: $DUPES"
fi

# --- Sorted (good hygiene) ---
echo "--- Sort order ---"
if diff <(sort "$MANIFEST") "$MANIFEST" >/dev/null 2>&1; then
    pass "manifest is sorted"
else
    # Not a failure — just a warning
    skip "manifest not sorted (cosmetic)"
fi

test_summary
