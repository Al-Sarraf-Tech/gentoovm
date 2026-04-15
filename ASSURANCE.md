# GentooVM Assurance

This document describes the CI/CD quality gates, security controls, and validation strategy for GentooVM.

---

## CI Gates (ci-shell.yml)

GentooVM CI runs on every push to `main`, on `v*` tags, on pull requests, and on a weekly Monday schedule. All jobs run on self-hosted runners (`[self-hosted, shell-slim]`) with explicit workflow-level permissions.

### 1. Static Validation

Validates the structural correctness of all project files before any functional testing.

- **YAML syntax** -- Parses all Calamares config files and branding descriptor with `pyyaml` to catch syntax errors early.
- **Shell script syntax** -- Runs `bash -n` on every `.sh` file in the repository to detect parse errors.
- **Python syntax** -- Compiles the kernel manager GUI with `py_compile` to verify Python syntax.
- **Executable permissions** -- Ensures all scripts that need to be executable (`scripts/*.sh`, `qemu/*.sh`, `run-*.sh`) have the execute bit set.
- **No hardcoded secrets** -- Scans for private keys, API keys, and tokens across shell, config, Python, and Markdown files.

Why it matters: Catches the cheapest-to-fix errors first and prevents credentials from entering the repository.

### 2. Installer Config Validation

Validates the Calamares installer configuration for correctness.

- **Sequence integrity** -- Verifies that all required show modules (welcome, locale, keyboard, partition, users, summary, finished) and exec modules (partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, users, displaymanager, networkcfg, hwclock, services-systemd, shellprocess, umount) are present in `settings.conf`.
- **Installer defaults** -- Checks that timezone, admin group, geoip, partitioning scheme, filesystem, and GRUB timeout are set correctly.
- **No remote dependencies** -- Ensures Calamares modules do not fetch remote resources during installation (offline install requirement).

Why it matters: A broken installer config means users cannot install the OS. These checks prevent silent misconfiguration.

### 3. Post-Install Script Validation

Validates `config/gentoovm-postinstall.sh` which runs during installation.

- **Script syntax** -- `bash -n` parse check.
- **BIOS and UEFI support** -- Verifies the script handles both boot modes with EFI detection, `i386-pc`, `x86_64-efi`, and `--force` for GPT+BIOS.
- **Post-install features** -- Confirms sudo setup, desktop README, live user cleanup, autologin cleanup, installer shortcut cleanup, zram, sysctl tuning, and earlyoom are all present.

Why it matters: The post-install script is the bridge between the live ISO and a working installed system. Missing any step results in a broken installation.

### 4. README Quality

Validates that project documentation covers all essential topics.

- **Project README sections** -- Checks for Quick Start, Using Gentoo, Kernel Management, VM Optimizations, How It Was Built, Troubleshooting, and bare metal warning.
- **Desktop README completeness** -- Validates that the README placed on the user's desktop covers sudo, zram, Cinnamon, Gentoo, emerge, terminal, packages, troubleshooting, and kernel topics.
- **Bare metal warning** -- Ensures the risk disclaimer for bare metal use is present.
- **Getting Started guide** -- Verifies the guide exists and covers ISO reassembly and Windows instructions.

Why it matters: Users need accurate, complete documentation. Missing sections lead to support burden and user frustration.

### 5. Security Scan

Dedicated security-focused validation. Runs in parallel with lint (needs: repo-guard only).

- **Gitleaks** -- Runs `gitleaks detect` across the full repository history to catch secrets committed at any point.
- **Credential pattern scan** -- Searches for `BEGIN.*PRIVATE KEY` patterns in `.sh`, `.conf`, `.py`, and `.yml` files outside `.git/`. Fails immediately on any match.

ShellCheck and shfmt are handled by the lint job; the security job does not duplicate them.

Why it matters: Prevents credential leakage. Gitleaks covers history, not just the current tree.

### 6. SBOM Generation

Generates a CycloneDX Software Bill of Materials from `manifests/installed-packages.txt`. Runs after `test` passes (`needs: [repo-guard, test]`), on `main` branch only.

- Parses all Gentoo packages into structured CycloneDX 1.4 JSON using an inline Python script — each line becomes a component with `name`, `version`, and `purl` (`pkg:gentoo/...`).
- Uploads `sbom.cdx.json` as a CI artifact (`sbom-cyclonedx`) via `actions/upload-artifact@v4` with 90-day retention.

Why it matters: Enables vulnerability scanning against the full package manifest and provides supply chain transparency. Artifact is downloadable from any CI run.

### 7. Checksum Verification

Validates that ISO integrity files are present.

- Checks for `iso/gentoovm.iso.sha256` and `iso/gentoovm.iso.md5`.
- Checks for the torrent file.

Why it matters: Users depend on checksums to verify download integrity. Missing checksum files mean users cannot validate their ISO.

### 8. Unit Tests

Runs after lint passes (`needs: [repo-guard, lint]`). Executes `bash run-unit-tests.sh`, which drives 13 test suites in `tests/unit/`:

1. Calamares configuration
2. Post-install safety
3. Script quality
4. `make.conf` correctness
5. Repository structure
6. ISO distribution
7. Security
8. Documentation
9. Assertion library
10. Build reproducibility
11. Package manifest
12. Version consistency
13. Config management

Why it matters: Real unit tests covering all major subsystems. Lint must pass before tests run, ensuring tests are not executed against files with syntax errors.

---

## Release Gating

The release job in `ci-shell.yml` is gated by `repo-guard`, `test`, and `security` jobs that must all pass before any release is created.

### Release Flow

1. **`repo-guard` job** -- Verifies repository ownership (`Al-Sarraf-Tech/gentoovm`) before any other job runs.
2. **`lint` job** (needs: repo-guard) -- Bash syntax, ShellCheck, shfmt must pass. **`security` job** (needs: repo-guard) runs in parallel -- gitleaks + credential pattern scan must pass.
3. **`test` job** (needs: repo-guard, lint) -- Runs `bash run-unit-tests.sh` across all 13 unit test suites.
4. **`sbom` job** (needs: repo-guard, test) -- Generates CycloneDX SBOM on `main`; uploads as CI artifact.
5. **`release` job** (needs: repo-guard, test, security) -- Builds `release-assets/` at job time (copies checksums, reassembly scripts, torrent, split ISO parts; generates SBOM inline; produces `SHA256SUMS`), then creates the GitHub Release with all assets. Runs only on `v*` tags.

The `release-assets/` directory does not pre-exist in the repository; it is constructed entirely during the release job. A tag push (`v*`) will not produce a release if `test` or `security` jobs fail.

### Concurrency Controls

- **ci-shell.yml** -- Uses `gentoovm-ci-${{ github.ref }}` concurrency group with `cancel-in-progress: true`. Redundant CI runs on the same ref are cancelled.

### Permissions

The workflow declares `permissions: contents: write, id-token: write, security-events: write` at the top level, which allows the release job to create GitHub Releases. All jobs run with the minimum access needed for their function.

### Secrets

- `GITHUB_TOKEN` -- Used by the release job to create GitHub Releases (provided automatically by GitHub Actions).
- `TRANSMISSION_CREDS` -- Transmission RPC credentials for the torrent seed update script. Must be configured as a repository secret. Never hardcoded in workflow or script files.

---

## SBOM

The SBOM is generated from `manifests/installed-packages.txt`, which lists all Gentoo packages installed in the ISO image.

- Format: CycloneDX 1.4 JSON
- Each package is parsed into category (Gentoo category), name, and version
- Generated during both CI (as artifact) and release (attached to the GitHub Release)
- Can be fed into vulnerability scanners (e.g., `grype`, `trivy`) for CVE detection

---

## Checksum Verification

ISO integrity is protected by two checksum files tracked in the repository:

- `iso/gentoovm.iso.sha256` -- SHA-256 hash
- `iso/gentoovm.iso.md5` -- MD5 hash (for compatibility)

Users verify after download:
```bash
sha256sum -c gentoovm.iso.sha256
md5sum -c gentoovm.iso.md5
```

The reassembly scripts (`reassemble.sh`, `reassemble.ps1`) automatically verify checksums after concatenating split ISO parts.

---

## Security Scan

The security job runs on every CI invocation in parallel with lint and checks for:

1. **Gitleaks** -- Full repository history scan via `gitleaks detect --source=. --no-banner --exit-code=1`
2. **Private key patterns** -- `BEGIN.*PRIVATE KEY` in `.sh`, `.conf`, `.py`, `.yml` files (excluding `.git/`)

Shell scripting quality (ShellCheck, shfmt) is handled exclusively by the lint job.

---

## Running Validation Locally

The repository includes shell scripts that mirror the CI validation pipeline:

| Script | Purpose |
|---|---|
| `run-static-validation.sh` | Static analysis (YAML, shell, Python syntax, permissions) |
| `run-unit-tests.sh` | Unit tests — all 13 suites in `tests/unit/` |
| `run-smoke-tests.sh` | Quick smoke tests |
| `run-e2e-preflight.sh` | End-to-end preflight checks |
| `run-regression-suite.sh` | Full regression suite |
| `run-all-preqemu-validation.sh` | All pre-QEMU stages (1-7) in sequence |
| `run-qemu-live-test.sh` | QEMU ISO boot test (stage 8) |
| `run-qemu-install-test.sh` | QEMU install test |
| `run-qemu-installed-test.sh` | Installed system boot test (stage 9) |
| `run-qemu-final-user-verify.sh` | Final user verification |

Run the full pre-QEMU validation:
```bash
bash run-all-preqemu-validation.sh
```

Run the full pipeline including QEMU tests:
```bash
bash run-all-preqemu-validation.sh
bash run-qemu-live-test.sh
bash run-qemu-installed-test.sh
```
