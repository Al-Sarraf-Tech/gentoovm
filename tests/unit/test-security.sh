#!/usr/bin/env bash
# Unit tests: Security posture
# Deep scanning for credentials, permissions, policy, and supply chain
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="security"

echo "=== Security Tests ==="

# --- No hardcoded credentials in tracked files ---
echo "--- Credential scan ---"
SCAN_FILES=$(git -C "$REPO_DIR" ls-files | grep -E '\.(sh|conf|py)$' | grep -v 'tests/' || true)

CRED_FOUND=false
while IFS= read -r f; do
    [ -z "$f" ] && continue
    filepath="$REPO_DIR/$f"
    [ -f "$filepath" ] || continue

    if grep -qP '^-----BEGIN .* PRIVATE KEY-----' "$filepath" 2>/dev/null; then
        fail "private key in $f"
        CRED_FOUND=true
    fi

    if grep -qP 'password\s*=\s*["\x27][^"\x27]{4,}' "$filepath" 2>/dev/null; then
        if ! grep -q 'gentoo:gentoo' "$filepath" 2>/dev/null; then
            fail "possible hardcoded password in $f"
            CRED_FOUND=true
        fi
    fi
done <<< "$SCAN_FILES"
$CRED_FOUND || pass "no hardcoded credentials in tracked files"

# --- Env var for sensitive values ---
echo "--- Sensitive value handling ---"
assert_file_contains "$REPO_DIR/scripts/update-torrent-seed.sh" 'TRANSMISSION_CREDS:?' "torrent creds via env var with error"
assert_file_not_contains "$REPO_DIR/scripts/update-torrent-seed.sh" 'admin:' "no default credentials"

# --- No world-writable files ---
echo "--- File permissions ---"
WORLD_WRITABLE=$(find "$REPO_DIR" -not -path '*/.git/*' -type f -perm -o+w 2>/dev/null | head -5)
if [ -z "$WORLD_WRITABLE" ]; then
    pass "no world-writable files"
else
    fail "world-writable files found: $WORLD_WRITABLE"
fi

# --- Gitignore blocks sensitive file types ---
echo "--- Gitignore security ---"
for pattern in '\.env' '\.key' '\.pem' 'credentials' 'token' 'kubeconfig' '\.p12' '\.pfx' 'id_rsa' 'id_ed25519'; do
    assert_file_contains "$REPO_DIR/.gitignore" "$pattern" "gitignore blocks $pattern"
done

# --- Installer is offline ---
echo "--- Offline installation ---"
assert_file_contains "$REPO_DIR/calamares/modules/welcome.conf" 'internetCheckUrl: ""' "installer offline"
assert_file_contains "$REPO_DIR/calamares/modules/locale.conf" '"none"' "geoip disabled"

# No remote URLs in any calamares module
REMOTE_IN_CALAM=false
for f in "$REPO_DIR/calamares/modules/"*.conf; do
    if grep -qE 'https?://|rsync://|git://' "$f" 2>/dev/null; then
        if ! grep -q 'internetCheckUrl: ""' "$f"; then
            fail "remote URL in calamares/$(basename "$f")"
            REMOTE_IN_CALAM=true
        fi
    fi
done
$REMOTE_IN_CALAM || pass "no remote URLs in installer modules"

# --- Sudo policy ---
echo "--- Sudo policy ---"
assert_file_contains "$REPO_DIR/config/gentoovm-postinstall.sh" "chmod 440" "sudoers file permission locked"
assert_file_not_contains "$REPO_DIR/config/gentoovm-postinstall.sh" "NOPASSWD" "no NOPASSWD in sudo policy"
assert_file_contains "$REPO_DIR/config/gentoovm-postinstall.sh" '%wheel ALL=\(ALL:ALL\) ALL' "sudo via wheel group only"

# --- Live session security ---
echo "--- Live session ---"
# Live session has passwordless polkit (required for installer), but post-install cleans it up
assert_file_contains "$REPO_DIR/config/gentoovm-postinstall.sh" "rm.*live.conf" "postinstall removes live autologin"
assert_file_contains "$REPO_DIR/config/gentoovm-postinstall.sh" "userdel.*gentoo" "postinstall removes live user"

# --- CI action pinning ---
echo "--- CI security ---"
CI_FILE="$REPO_DIR/.github/workflows/ci-shell.yml"
if [ -f "$CI_FILE" ]; then
    if grep -q 'softprops/action-gh-release@[a-f0-9]\{40\}' "$CI_FILE"; then
        pass "release action pinned by SHA"
    else
        fail "release action not pinned by SHA"
    fi

    # Repo-guard prevents unauthorized forks from running CI
    assert_file_contains "$CI_FILE" "repo-guard" "repo-guard job present"
    assert_file_contains "$CI_FILE" "Al-Sarraf-Tech/gentoovm" "repo ownership check"

    # Permissions are explicitly declared
    assert_file_contains "$CI_FILE" "^permissions:" "workflow permissions declared"

    # No untrusted inputs in run: blocks
    # Safe: github.repository, github.ref, secrets.GITHUB_TOKEN
    # Unsafe: github.event.*.title, github.event.*.body, github.head_ref
    if grep -qE 'github\.event\.(issue|pull_request|comment|review)\.' "$CI_FILE" 2>/dev/null; then
        fail "CI uses untrusted event inputs"
    else
        pass "CI free of untrusted event inputs"
    fi
fi

# --- Secrets scanning ---
assert_file_contains "$CI_FILE" "gitleaks" "gitleaks secrets scanning in CI"

# --- SECURITY.md policy ---
echo "--- Security policy ---"
SECMD="$REPO_DIR/SECURITY.md"
assert_file_exists "$SECMD"
assert_file_contains "$SECMD" "Reporting" "vulnerability reporting documented"
assert_file_contains "$SECMD" "Scope|scope" "security scope defined"
assert_file_contains "$SECMD" "jalsarraf0@gmail.com" "report contact provided"

# --- License policy ---
echo "--- License policy ---"
assert_file_contains "$REPO_DIR/config/make.conf" "@FREE" "accepts free licenses"
assert_file_contains "$REPO_DIR/config/make.conf" "@BINARY-REDISTRIBUTABLE" "accepts binary-redistributable"
assert_file_not_contains "$REPO_DIR/config/make.conf" 'ACCEPT_LICENSE="\*"' "no wildcard license acceptance"

# --- Build script safety ---
echo "--- Build script safety ---"
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" "trap.*EXIT" "build-iso has cleanup trap"
assert_file_contains "$REPO_DIR/scripts/build-iso.sh" "SOURCE_DATE_EPOCH" "build uses reproducible timestamps"

test_summary
