#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# Stage 8b: QEMU Installation Test
# Calamares is a GUI installer — fully automated headless testing is not
# feasible without a display server and input automation. This test verifies
# the pre-conditions that make installation possible.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="qemu-install-preconditions"

BASE="${GENTOOVM_BUILD_ROOT:-/home/jalsarraf/gentoo}"

echo "=== Stage 8b: Installation Pre-Condition Tests ==="

# --- Calamares config is installable ---
echo "--- Calamares config ---"
assert_file_exists "$REPO_DIR/calamares/settings.conf"
assert_file_contains "$REPO_DIR/calamares/settings.conf" "shellprocess" "post-install hook in sequence"

# --- Post-install script is valid ---
echo "--- Post-install script ---"
assert_file_exists "$REPO_DIR/config/gentoovm-postinstall.sh"
assert_shell_syntax "$REPO_DIR/config/gentoovm-postinstall.sh"
assert_script_strict "$REPO_DIR/config/gentoovm-postinstall.sh"

# --- Installer desktop shortcut template ---
echo "--- Installer shortcut ---"
assert_file_contains "$REPO_DIR/scripts/setup-live-session.sh" "install-gentoovm.desktop" "installer shortcut created"
assert_file_contains "$REPO_DIR/scripts/setup-live-session.sh" "pkexec calamares" "installer runs with pkexec"

# --- Polkit rule for installer ---
echo "--- Polkit ---"
assert_file_contains "$REPO_DIR/scripts/setup-live-session.sh" "polkit" "polkit rule for installer"

# --- ISO exists for testing ---
echo "--- ISO availability ---"
if [ -f "$BASE/gentoovm.iso" ]; then
    ISO_SIZE=$(stat -c%s "$BASE/gentoovm.iso" 2>/dev/null || echo 0)
    if [ "$ISO_SIZE" -gt 1073741824 ]; then
        pass "ISO exists and >1GB ($((ISO_SIZE/1048576)) MB)"
    else
        fail "ISO too small ($((ISO_SIZE/1048576)) MB)"
    fi
else
    skip "ISO not present (build required)"
fi

echo ""
echo "NOTE: Full GUI installation requires manual verification via:"
echo "  bash run-qemu-final-user-verify.sh"

test_summary
