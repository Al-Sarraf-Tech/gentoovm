#!/usr/bin/env bash
# Unit tests: Build reproducibility
# Validates that build-iso.sh has all controls needed for deterministic output
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="build-reproducibility"

BUILD_SCRIPT="$REPO_DIR/scripts/build-iso.sh"

echo "=== Build Reproducibility Tests ==="

# --- Script fundamentals ---
echo "--- Script fundamentals ---"
assert_file_exists "$BUILD_SCRIPT"
assert_shell_syntax "$BUILD_SCRIPT"
assert_script_strict "$BUILD_SCRIPT"

# --- Cleanup trap ---
echo "--- Error recovery ---"
assert_file_contains "$BUILD_SCRIPT" "trap.*cleanup.*EXIT" "EXIT trap for cleanup"
assert_file_contains "$BUILD_SCRIPT" "mountpoint" "checks for leaked mounts"

# --- Reproducibility controls ---
echo "--- Reproducibility ---"
assert_file_contains "$BUILD_SCRIPT" "SOURCE_DATE_EPOCH" "SOURCE_DATE_EPOCH for deterministic timestamps"
assert_file_contains "$BUILD_SCRIPT" "-reproducible" "mksquashfs --reproducible flag"
assert_file_contains "$BUILD_SCRIPT" "GENTOOVM_KERNEL_VERSION" "kernel version pinnable via env var"

# --- Toolchain documentation ---
echo "--- Toolchain docs ---"
assert_file_contains "$BUILD_SCRIPT" "Build Requirements" "requirements header"
assert_file_contains "$BUILD_SCRIPT" "xorriso" "xorriso documented"
assert_file_contains "$BUILD_SCRIPT" "mksquashfs|squashfs-tools" "squashfs-tools documented"
assert_file_contains "$BUILD_SCRIPT" "dracut" "dracut documented"
assert_file_contains "$BUILD_SCRIPT" "mkfs.vfat|dosfstools" "dosfstools documented"

# --- BIOS + EFI dual boot ---
echo "--- Dual boot support ---"
assert_file_contains "$BUILD_SCRIPT" "grub-mkstandalone|grub2-mkstandalone" "grub standalone builder"
assert_file_contains "$BUILD_SCRIPT" "x86_64-efi" "EFI boot image"
assert_file_contains "$BUILD_SCRIPT" "i386-pc" "BIOS boot image"
assert_file_contains "$BUILD_SCRIPT" "BOOTX64.EFI" "EFI boot binary"

# --- ISO metadata ---
echo "--- ISO metadata ---"
assert_file_contains "$BUILD_SCRIPT" 'volid.*GENTOOVM' "ISO volume ID"
assert_file_contains "$BUILD_SCRIPT" "iso-level 3" "ISO 9660 level 3"

# --- Checksum generation ---
echo "--- Checksums ---"
assert_file_contains "$BUILD_SCRIPT" "sha256sum" "SHA256 checksum generated"
assert_file_contains "$BUILD_SCRIPT" "md5sum" "MD5 checksum generated"

# --- Compression settings ---
echo "--- Compression ---"
assert_file_contains "$BUILD_SCRIPT" "comp zstd" "squashfs uses zstd"
assert_file_contains "$BUILD_SCRIPT" "Xcompression-level" "compression level specified"

# --- Proper exclusions in squashfs ---
echo "--- Squashfs exclusions ---"
for excl in proc sys dev run tmp "var/cache/distfiles" "var/cache/binpkgs" "var/tmp/portage"; do
    assert_file_contains "$BUILD_SCRIPT" "-e $excl" "squashfs excludes $excl"
done

test_summary
