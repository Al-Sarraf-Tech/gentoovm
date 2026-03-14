# GentooVM Assurance

This document describes the CI/CD quality gates, security controls, and validation strategy for GentooVM.

---

## CI Gates (ci.yml)

GentooVM CI runs 8 jobs on every push to `main`, on `v*` tags, and on pull requests to `main`. All jobs run on `ubuntu-latest` with read-only permissions.

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

- **Sequence integrity** -- Verifies that all required show modules (welcome, locale, keyboard, partition, users, summary, finished) and exec modules (partition, mount, unpackfs, users, shellprocess, umount) are present in `settings.conf`.
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

Dedicated security-focused validation.

- **Credential scan** -- Searches for private keys and hardcoded passwords in scripts and config files.
- **File permissions** -- Detects world-writable files that could be a security risk.
- **Shellcheck** -- Runs shellcheck with warning-level severity on critical scripts to catch common shell scripting vulnerabilities and bugs.

Why it matters: Prevents credential leakage and catches shell scripting security anti-patterns.

### 6. SBOM Generation

Generates a CycloneDX Software Bill of Materials from `manifests/installed-packages.txt`.

- Parses all 889+ Gentoo packages into structured SBOM format with category, name, and version.
- Uploads the SBOM as a build artifact for supply chain auditing.

Why it matters: Enables vulnerability scanning against the full package manifest and provides supply chain transparency.

### 7. Checksum Verification

Validates that ISO integrity files are present.

- Checks for `iso/gentoovm.iso.sha256` and `iso/gentoovm.iso.md5`.
- Checks for the torrent file.

Why it matters: Users depend on checksums to verify download integrity. Missing checksum files mean users cannot validate their ISO.

### 8. Regression Suite

Runs after static-validation, config-validation, and postinstall-validation pass.

- **Config regression** -- Re-validates critical Calamares settings (timezone, users, partition, admin group, display manager).
- **Post-install regression** -- Re-validates critical post-install features (sudo, README, zram, bootloader, cleanup).
- **Repo completeness** -- Verifies all required files exist in the repository (18 files checked).

Why it matters: Guards against regressions that could slip through individual validation jobs. Acts as a final integration check.

---

## Release Gating

The release workflow (`release.yml`) is gated by a `ci-check` job that must pass before any release is created.

### Release Flow

1. **`ci-check` job** -- Runs the key CI validations inline: YAML syntax, shell syntax, Python syntax, executable permissions, secret scanning, Calamares sequence integrity, security scan, checksum verification, and repo completeness.
2. **`release` job** (needs: ci-check) -- Generates a CycloneDX SBOM and creates the GitHub Release with checksums, reassembly scripts, and SBOM attached.
3. **`update-torrent-seed` job** (needs: release) -- Runs on the self-hosted runner to update the Transmission torrent seed with the new ISO.

A tag push (`v*`) will not produce a release if CI validation fails.

### Concurrency Controls

- **ci.yml** -- Uses `ci-${{ github.ref }}` concurrency group with `cancel-in-progress: true`. Redundant CI runs on the same ref are cancelled.
- **release.yml** -- Uses `release-${{ github.ref }}` concurrency group with `cancel-in-progress: false`. Releases are serialized, never cancelled mid-flight.

### Permissions

All jobs use explicit `permissions` blocks following the principle of least privilege:
- CI jobs and the ci-check gate: `contents: read`
- Release job: `contents: write` (required to create GitHub Releases)
- Torrent seed job: `contents: read`

### Secrets

- `GITHUB_TOKEN` -- Used by the release job to create GitHub Releases (provided automatically by GitHub Actions).
- `TRANSMISSION_CREDS` -- Transmission RPC credentials for the torrent seed update. Stored as a repository secret. Never hardcoded in workflow files.

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

The security scan job runs on every CI invocation and checks for:

1. **Private keys** -- `BEGIN.*PRIVATE KEY` patterns in scripts, configs, and Python files
2. **Hardcoded passwords** -- `password\s*=\s*['"]` patterns (excluding documentation)
3. **API keys/tokens** -- `api_key`, `api_token`, `secret_key` patterns
4. **File permissions** -- World-writable files outside `.git/`
5. **Shell scripting issues** -- Shellcheck at warning level on critical scripts

---

## Running Validation Locally

The repository includes shell scripts that mirror the CI validation pipeline:

| Script | Purpose |
|---|---|
| `run-static-validation.sh` | Static analysis (YAML, shell, Python syntax, permissions) |
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
