#!/usr/bin/env bash
# Unit tests: Repository structure and completeness
# Validates all expected files and dirs exist, gitignore is correct
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="repo-structure"

echo "=== Repository Structure Tests ==="

# --- Required directories ---
echo "--- Required directories ---"
for d in calamares calamares/modules calamares/branding/gentoovm \
         config scripts qemu docs manifests iso tests tests/lib tests/unit \
         .github/workflows; do
    assert_dir_exists "$REPO_DIR/$d"
done

# --- Required files ---
echo "--- Required files ---"
for f in README.md GETTING-STARTED.md ASSURANCE.md CLAUDE.md LICENSE \
         .gitignore .github/dependabot.yml SECURITY.md VERSION \
         calamares/settings.conf \
         config/make.conf config/package.use config/grub-defaults \
         config/gentoovm-postinstall.sh config/README-desktop.md \
         config/gentoovm-kernel-manager config/gentoovm-kernel-manager-gui \
         scripts/build-iso.sh scripts/configure-system.sh \
         scripts/install-desktop-packages.sh scripts/setup-live-session.sh \
         qemu/launch-live.sh qemu/launch-installed.sh \
         manifests/installed-packages.txt \
         iso/gentoovm.iso.sha256 iso/gentoovm.iso.md5 \
         iso/reassemble.sh iso/reassemble.ps1 \
         iso/MAGNET_LINK.txt \
         tests/lib/assertions.sh; do
    assert_file_exists "$REPO_DIR/$f"
done

# --- Checksums reference correct filename ---
echo "--- Checksum integrity ---"
assert_file_contains "$REPO_DIR/iso/gentoovm.iso.sha256" "gentoovm.iso" "SHA256 references gentoovm.iso"
assert_file_contains "$REPO_DIR/iso/gentoovm.iso.md5" "gentoovm.iso" "MD5 references gentoovm.iso"

# --- Magnet link contains tracker ---
echo "--- Torrent distribution ---"
assert_file_contains "$REPO_DIR/iso/MAGNET_LINK.txt" "magnet:" "magnet link present"
assert_file_contains "$REPO_DIR/iso/MAGNET_LINK.txt" "tracker" "tracker in magnet link"

# --- Gitignore covers sensitive patterns ---
echo "--- Gitignore coverage ---"
for pattern in '\.env' '\.key' '\.pem' 'qcow2' 'credentials'; do
    assert_file_contains "$REPO_DIR/.gitignore" "$pattern" "gitignore: $pattern"
done

# --- No large binaries tracked (except ISO parts for release) ---
echo "--- No unexpected large files ---"
LARGE_TRACKED=$(git -C "$REPO_DIR" ls-files | while read -r f; do
    [ -f "$REPO_DIR/$f" ] || continue
    size=$(stat -c%s "$REPO_DIR/$f" 2>/dev/null || echo 0)
    if [ "$size" -gt 10485760 ] && [[ "$f" != iso/* ]] && [[ "$f" != *.png ]]; then
        echo "$f ($((size/1048576))MB)"
    fi
done)
if [ -z "$LARGE_TRACKED" ]; then
    pass "no unexpected large tracked files"
else
    fail "large tracked files: $LARGE_TRACKED"
fi

test_summary
