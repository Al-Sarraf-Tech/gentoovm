#!/usr/bin/env bash
# Unit tests: ISO distribution artifacts
# Validates checksums, torrent, reassembly scripts, split parts, and distribution completeness
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="iso-distribution"

ISO_DIR="$REPO_DIR/iso"

echo "=== ISO Distribution Tests ==="

# --- Required distribution files ---
echo "--- Distribution files ---"
for f in gentoovm.iso.sha256 gentoovm.iso.md5 reassemble.sh reassemble.ps1 MAGNET_LINK.txt; do
    assert_file_exists "$ISO_DIR/$f"
done

# --- Linux reassembly script ---
echo "--- reassemble.sh ---"
assert_shell_syntax "$ISO_DIR/reassemble.sh"
assert_executable "$ISO_DIR/reassemble.sh"
assert_script_strict "$ISO_DIR/reassemble.sh"
assert_file_contains "$ISO_DIR/reassemble.sh" "sha256sum" "reassembly verifies SHA256"
assert_file_contains "$ISO_DIR/reassemble.sh" "cat gentoovm.iso.part" "reassembly concatenates parts"
assert_file_contains "$ISO_DIR/reassemble.sh" "CHECKSUM MISMATCH" "reassembly reports integrity failure"

# --- PowerShell reassembly script ---
echo "--- reassemble.ps1 ---"
assert_file_exists "$ISO_DIR/reassemble.ps1"
assert_file_contains "$ISO_DIR/reassemble.ps1" "Get-FileHash" "PS verifies hash"
assert_file_contains "$ISO_DIR/reassemble.ps1" "SHA256" "PS uses SHA256"
assert_file_contains "$ISO_DIR/reassemble.ps1" "CopyTo" "PS streams parts together"
assert_file_contains "$ISO_DIR/reassemble.ps1" "CHECKSUM MISMATCH" "PS reports integrity failure"
assert_file_contains "$ISO_DIR/reassemble.ps1" "ErrorActionPreference.*Stop" "PS strict error mode"

# --- Torrent file ---
echo "--- Torrent ---"
TORRENT_FILES=$(find "$ISO_DIR" -name '*.torrent' -type f)
if [ -n "$TORRENT_FILES" ]; then
    pass "torrent file exists"
    # Verify torrent is non-trivial (at least a few KB)
    TORRENT_SIZE=$(stat -c%s "$ISO_DIR"/*.torrent 2>/dev/null | head -1)
    if [ "${TORRENT_SIZE:-0}" -gt 1000 ]; then
        pass "torrent file non-trivial (${TORRENT_SIZE} bytes)"
    else
        fail "torrent file too small (${TORRENT_SIZE} bytes)"
    fi
else
    fail "no torrent file found"
fi

# --- Magnet link quality ---
echo "--- Magnet link ---"
MAGNET="$ISO_DIR/MAGNET_LINK.txt"
assert_file_contains "$MAGNET" "xt=urn:btih:" "magnet has info hash"
assert_file_contains "$MAGNET" "dn=" "magnet has display name"
assert_file_contains "$MAGNET" "tr=" "magnet has trackers"

# Count trackers (S-tier: ≥5 for redundancy)
TRACKER_COUNT=$(grep -o 'tr=' "$MAGNET" | wc -l)
if [ "$TRACKER_COUNT" -ge 5 ]; then
    pass "magnet has $TRACKER_COUNT trackers (≥5)"
else
    fail "magnet has only $TRACKER_COUNT trackers (want ≥5)"
fi

# Verify tracker protocols are public/open (may be URL-encoded)
if grep -qE 'udp(://|%3A%2F%2F)tracker' "$MAGNET"; then
    pass "magnet uses public UDP trackers"
else
    fail "magnet lacks public UDP trackers"
fi

# --- Checksum format ---
echo "--- Checksum format ---"
if grep -qE '^[a-f0-9]{64}\s+gentoovm\.iso$' "$ISO_DIR/gentoovm.iso.sha256"; then
    pass "SHA256 format correct (64 hex + filename)"
else
    fail "SHA256 format incorrect"
fi
if grep -qE '^[a-f0-9]{32}\s+gentoovm\.iso$' "$ISO_DIR/gentoovm.iso.md5"; then
    pass "MD5 format correct (32 hex + filename)"
else
    fail "MD5 format incorrect"
fi

# --- Split parts ---
echo "--- Split ISO parts ---"
PART_COUNT=$(find "$ISO_DIR" -name 'gentoovm.iso.part.*' -type f | wc -l)
if [ "$PART_COUNT" -ge 2 ]; then
    pass "ISO split into $PART_COUNT parts"
else
    fail "expected ≥2 ISO parts, found $PART_COUNT"
fi

# Verify each part is under GitHub's 2GB limit
OVERSIZED=false
while IFS= read -r part; do
    PART_SIZE=$(stat -c%s "$part" 2>/dev/null || echo 0)
    if [ "$PART_SIZE" -gt 2147483648 ]; then
        fail "part $(basename "$part") exceeds 2GB ($((PART_SIZE/1048576)) MB)"
        OVERSIZED=true
    fi
done < <(find "$ISO_DIR" -name 'gentoovm.iso.part.*' -type f)
$OVERSIZED || pass "all parts under 2GB GitHub limit"

# --- Torrent seed script ---
echo "--- Torrent seed script ---"
SEED_SCRIPT="$REPO_DIR/scripts/update-torrent-seed.sh"
assert_file_exists "$SEED_SCRIPT"
assert_script_strict "$SEED_SCRIPT"
assert_file_contains "$SEED_SCRIPT" "TRANSMISSION_CREDS" "uses env var for credentials"
assert_file_not_contains "$SEED_SCRIPT" 'password=' "no hardcoded password"
assert_file_contains "$SEED_SCRIPT" "transmission-create" "creates torrent via transmission"
assert_file_contains "$SEED_SCRIPT" "transmission-show.*magnet" "extracts magnet link"

# --- SECURITY.md exists for distribution trust ---
echo "--- Distribution trust ---"
assert_file_exists "$REPO_DIR/SECURITY.md"

test_summary
