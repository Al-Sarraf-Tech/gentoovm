# CI/CD Hardening Report

**Repository:** gentoovm
**Date:** 2026-03-14
**Branch:** ci/assurance-hardening

---

## Critical Security Fix: Hardcoded Credentials Removed

**Severity:** Critical
**File:** `.github/workflows/release.yml`

The `update-torrent-seed` job contained hardcoded Transmission RPC credentials (`-n "username:password"`) in 7 locations within `transmission-remote` commands. All occurrences have been replaced with the GitHub Actions secret reference `${{ secrets.TRANSMISSION_CREDS }}`.

**Action required:** The repository secret `TRANSMISSION_CREDS` must be configured in GitHub repository settings (Settings > Secrets and variables > Actions) with the value `username:password` before the next release tag is pushed.

**Git history note:** The hardcoded credentials remain in the git history (commit `265ad8e`). Consider one of the following remediation steps:
1. Rotate the Transmission password immediately (recommended)
2. Use `git filter-repo` or BFG Repo-Cleaner to purge the credential from history
3. If the repository was ever public, treat the credential as compromised

---

## Release Gating: CI Must Pass Before Release

**File:** `.github/workflows/release.yml`

Previously, the release workflow triggered on `v*` tags and ran independently of CI. A broken commit could be tagged and released without any validation.

A `ci-check` job has been added to `release.yml` that runs the key CI validations inline. The `release` job now has `needs: ci-check`, ensuring no release is created unless validation passes.

---

## Concurrency Controls Added

### ci.yml
- Concurrency group: `ci-${{ github.ref }}`
- `cancel-in-progress: true` -- superseded CI runs are cancelled to save runner minutes

### release.yml
- Concurrency group: `release-${{ github.ref }}`
- `cancel-in-progress: false` -- release jobs are never cancelled mid-flight to avoid partial releases

---

## Explicit Permissions Added

### ci.yml
- Workflow-level: `permissions: contents: read`
- All 8 jobs: `permissions: contents: read`

### release.yml
- Workflow-level: `permissions: contents: write` (required for release creation)
- `ci-check` job: `permissions: contents: read`
- `release` job: `permissions: contents: write`
- `update-torrent-seed` job: `permissions: contents: read`

This follows the principle of least privilege. No job has more permissions than it needs.

---

## Documentation Added

- **ASSURANCE.md** -- Comprehensive documentation of all 8 CI gates, release gating strategy, SBOM generation, checksum verification, security scanning, and local validation instructions.
- **CI_CD_HARDENING_REPORT.md** -- This report.

---

## Files Changed

| File | Change |
|---|---|
| `.github/workflows/release.yml` | Removed hardcoded credentials (7 occurrences), added ci-check gate, added concurrency controls, added explicit per-job permissions |
| `.github/workflows/ci.yml` | Added concurrency controls, added workflow-level and per-job permissions |
| `ASSURANCE.md` | New -- CI/CD assurance documentation |
| `CI_CD_HARDENING_REPORT.md` | New -- this report |
| `README.md` | Added CI and release badge |

---

## Remaining Risks

1. **Git history contains the credential.** The old password is in commit `265ad8e`. Rotate the password or purge history.
2. **Self-hosted runner security.** The `update-torrent-seed` job runs on a self-hosted runner with access to local filesystems and Transmission. Ensure the runner is hardened and secrets are not logged.
3. **SBOM coverage.** The SBOM is generated from a static package list file. If the ISO is rebuilt without updating `manifests/installed-packages.txt`, the SBOM will be stale.
4. **No branch protection.** Consider enabling branch protection rules on `main` to require CI passage before merge.

---

## Validation

- Verified no hardcoded credentials remain in `.github/workflows/release.yml`
- Verified `ci-check` job is required by `release` job via `needs: ci-check`
- Verified concurrency groups are configured for both workflows
- Verified explicit permissions on all jobs
- YAML syntax of both workflow files confirmed valid
