#!/usr/bin/env bash
# Unit tests: Version consistency
# Validates that version is consistent across VERSION file, branding, and distribution
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="version-consistency"

echo "=== Version Consistency Tests ==="

# --- VERSION file exists and is well-formed ---
echo "--- VERSION file ---"
VERSION_FILE="$REPO_DIR/VERSION"
assert_file_exists "$VERSION_FILE"

VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    pass "VERSION format valid: $VERSION"
else
    fail "VERSION format invalid: '$VERSION' (expected X.Y or X.Y.Z)"
fi

# --- Branding matches VERSION ---
echo "--- Branding version ---"
BRANDING="$REPO_DIR/calamares/branding/gentoovm/branding.desc"
assert_yaml_value "$BRANDING" "strings.version" "$VERSION" "branding version matches VERSION"
assert_yaml_value "$BRANDING" "strings.shortVersion" "$VERSION" "branding shortVersion matches VERSION"

VERSIONED_NAME="GentooVM $VERSION"
assert_yaml_value "$BRANDING" "strings.versionedName" "$VERSIONED_NAME" "branding versionedName"
assert_yaml_value "$BRANDING" "strings.shortVersionedName" "$VERSIONED_NAME" "branding shortVersionedName"

# --- Torrent filename contains version ---
echo "--- Distribution version ---"
TORRENT=$(find "$REPO_DIR/iso" -name '*.torrent' -type f | head -1)
if [ -n "$TORRENT" ]; then
    TORRENT_NAME=$(basename "$TORRENT")
    if [[ "$TORRENT_NAME" == *"$VERSION"* ]]; then
        pass "torrent filename contains version ($TORRENT_NAME)"
    else
        fail "torrent filename '$TORRENT_NAME' missing version $VERSION"
    fi
else
    skip "no torrent file to check"
fi

# --- Product name consistency ---
echo "--- Product name ---"
assert_yaml_value "$BRANDING" "strings.productName" "GentooVM" "branding productName"
assert_yaml_value "$BRANDING" "componentName" "gentoovm" "branding componentName"
assert_yaml_value "$BRANDING" "strings.bootloaderEntryName" "GentooVM" "branding bootloader entry"

# build-iso.sh ISO label
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" 'volid.*GENTOOVM' "ISO volume label matches"

# GRUB distributor
assert_file_contains "$REPO_DIR/config/grub-defaults" 'GRUB_DISTRIBUTOR="GentooVM"' "GRUB distributor matches"

# EFI bootloader ID
assert_yaml_value "$REPO_DIR/calamares/modules/bootloader.conf" "efiBootloaderId" "GentooVM" "EFI bootloader ID matches"

test_summary
