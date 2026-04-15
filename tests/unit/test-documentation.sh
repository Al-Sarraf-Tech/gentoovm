#!/usr/bin/env bash
# Unit tests: Documentation completeness and accuracy
# Validates README, GETTING-STARTED, ASSURANCE, and desktop README
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="documentation"

echo "=== Documentation Tests ==="

# --- README.md sections ---
echo "--- README.md sections ---"
README="$REPO_DIR/README.md"
assert_file_exists "$README"
for section in "Quick Start" "Using Gentoo" "Kernel Management" "VM Optimizations" \
               "How It Was Built" "Troubleshooting" "Download" "Repository Structure"; do
    assert_file_contains "$README" "$section" "README section: $section"
done

# --- Bare metal warning ---
assert_file_contains "$README" "bare metal" "bare metal warning present"
assert_file_contains "$README" "unsupported" "bare metal unsupported stated"

# --- Package count accuracy ---
echo "--- Package count ---"
MANIFEST_COUNT=$(wc -l < "$REPO_DIR/manifests/installed-packages.txt")
if grep -q "$MANIFEST_COUNT" "$README"; then
    pass "README package count matches manifest ($MANIFEST_COUNT)"
else
    STATED=$(grep -oP '\d+ prebuilt packages' "$README" | grep -oP '^\d+')
    fail "README says $STATED packages, manifest has $MANIFEST_COUNT"
fi

# --- GETTING-STARTED.md ---
echo "--- GETTING-STARTED.md ---"
GS="$REPO_DIR/GETTING-STARTED.md"
assert_file_exists "$GS"
assert_file_contains "$GS" "reassemble" "reassembly instructions"
assert_file_contains "$GS" "PowerShell|Windows|\\.ps1" "Windows instructions"
assert_file_contains "$GS" "qemu-system" "QEMU command provided"
assert_file_contains "$GS" "sha256sum|checksum|verify" "checksum verification"

# --- ASSURANCE.md ---
echo "--- ASSURANCE.md ---"
ASSURANCE="$REPO_DIR/ASSURANCE.md"
assert_file_exists "$ASSURANCE"
assert_file_contains "$ASSURANCE" "CI Gates" "CI gates documented"
assert_file_contains "$ASSURANCE" "Release Gating" "release gating documented"
assert_file_contains "$ASSURANCE" "SBOM" "SBOM documented"
assert_file_contains "$ASSURANCE" "repo-guard" "repo-guard documented"
assert_file_contains "$ASSURANCE" "run-unit-tests" "unit tests documented in assurance"

# --- SECURITY.md ---
echo "--- SECURITY.md ---"
SECMD="$REPO_DIR/SECURITY.md"
assert_file_exists "$SECMD"
assert_file_contains "$SECMD" "Supported Versions|Supported versions" "supported versions section"
assert_file_contains "$SECMD" "Reporting|reporting" "reporting section"

# --- Build documentation ---
echo "--- Build docs ---"
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" "Build Requirements" "build requirements documented"
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" "xorriso" "xorriso requirement documented"
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" "mksquashfs" "mksquashfs requirement documented"

# --- Desktop README ---
echo "--- Desktop README ---"
DESKTOP_README="$REPO_DIR/config/README-desktop.md"
assert_file_exists "$DESKTOP_README"
for topic in sudo zram emerge terminal "Kernel Manager" Troubleshoot; do
    assert_file_contains "$DESKTOP_README" "$topic" "desktop README: $topic"
done

# --- No dead internal links ---
echo "--- Internal links ---"
while IFS= read -r link; do
    target="${link#\[*\](}"
    target="${target%)}"
    # Only check relative links (not URLs)
    [[ "$target" == http* ]] && continue
    [[ "$target" == \#* ]] && continue
    # Strip anchor
    target="${target%%#*}"
    [ -z "$target" ] && continue
    # Handle relative GitHub paths
    [[ "$target" == ../../* ]] && continue
    if [ -f "$REPO_DIR/$target" ]; then
        pass "link valid: $target"
    else
        fail "dead link: $target"
    fi
done < <(grep -oE '\[[^]]+\]\([^)]+\)' "$README" 2>/dev/null || true)

test_summary
