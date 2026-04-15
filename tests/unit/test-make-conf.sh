#!/usr/bin/env bash
# Unit tests: Portage make.conf configuration
# Validates build settings are safe, complete, and VM-appropriate
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="make-conf"

MAKECONF="$REPO_DIR/config/make.conf"

echo "=== make.conf Tests ==="

assert_file_exists "$MAKECONF"

# --- Compiler flags ---
echo "--- Compiler flags ---"
assert_file_contains "$MAKECONF" "COMMON_FLAGS=.*-O2" "optimization level -O2"
assert_file_contains "$MAKECONF" "-march=x86-64" "x86-64 architecture target"
assert_file_contains "$MAKECONF" '-pipe' "pipe compilation"
assert_file_not_contains "$MAKECONF" "-O3" "no aggressive -O3 optimization"
assert_file_not_contains "$MAKECONF" "-march=native" "no -march=native (non-portable)"

# --- Binary packages ---
echo "--- Binary packages ---"
assert_file_contains "$MAKECONF" "getbinpkg" "binary packages enabled"
assert_file_contains "$MAKECONF" "binpkg-request-signature" "binary package signatures"

# --- USE flags ---
echo "--- USE flags ---"
assert_file_contains "$MAKECONF" "elogind" "elogind session management"
assert_file_contains "$MAKECONF" "dbus" "D-Bus IPC"
assert_file_contains "$MAKECONF" "policykit" "PolicyKit authorization"
assert_file_contains "$MAKECONF" "networkmanager" "NetworkManager"
assert_file_contains "$MAKECONF" "virtio" "virtio support"
assert_file_contains "$MAKECONF" "-bluetooth" "bluetooth disabled (VM)"
assert_file_contains "$MAKECONF" "-cups" "printing disabled (VM)"
assert_file_contains "$MAKECONF" "-test" "test USE flag disabled"

# --- Video drivers ---
echo "--- Video drivers ---"
assert_file_contains "$MAKECONF" "VIDEO_CARDS=.*virtio" "virtio video driver"
assert_file_contains "$MAKECONF" "virgl" "virgl GPU acceleration"
assert_file_contains "$MAKECONF" "qxl" "QXL fallback driver"

# --- GRUB platforms ---
echo "--- GRUB ---"
assert_file_contains "$MAKECONF" 'GRUB_PLATFORMS=.*efi-64' "EFI-64 GRUB platform"
assert_file_contains "$MAKECONF" 'GRUB_PLATFORMS=.*pc' "BIOS PC GRUB platform"

# --- License policy ---
echo "--- License ---"
assert_file_contains "$MAKECONF" "ACCEPT_LICENSE" "license policy defined"

# --- Locale ---
echo "--- Locale ---"
assert_file_contains "$MAKECONF" 'L10N="en"' "English locale"

test_summary
