# GentooVM Build System

This directory contains the complete build system for GentooVM, a custom Gentoo-based Linux distribution optimized for QEMU/KVM virtual machines.

## Quick Rebuild

```bash
# Full rebuild from scratch
cd ~/git/gentoovm

# 1. Extract fresh stage3 (if needed)
sudo tar xpf cache/stage3-*.tar.xz -C build/ --xattrs-include='*.*' --numeric-owner

# 2. Mount chroot
sudo mount --types proc /proc build/proc
sudo mount --rbind /sys build/sys && sudo mount --make-rslave build/sys
sudo mount --rbind /dev build/dev && sudo mount --make-rslave build/dev
sudo mount --bind /run build/run
sudo cp -L /etc/resolv.conf build/etc/resolv.conf

# 3. Sync portage and update base
sudo chroot build emerge-webrsync
sudo chroot build emerge --update --deep --newuse @world

# 4. Install desktop packages
bash scripts/install-desktop-packages.sh

# 5. Configure system
bash scripts/configure-system.sh

# 6. Set up live session
bash scripts/setup-live-session.sh

# 7. Build ISO
bash scripts/build-iso.sh

# 8. Validate
bash run-all-preqemu-validation.sh

# 9. Test in QEMU
bash run-qemu-live-test.sh

# 10. Manual verification
bash run-qemu-final-user-verify.sh
```

## Directory Structure

| Path | Purpose |
|---|---|
| `build/` | Chroot root filesystem |
| `cache/` | Downloaded tarballs, stage3 |
| `staging/` | ISO staging area |
| `config/` | Configuration templates |
| `calamares/` | Calamares installer config |
| `packages/` | Package lists and manifests |
| `hooks/` | Post-install hooks |
| `scripts/` | Build and setup scripts |
| `tests/` | Test suites |
| `logs/` | Build and validation logs |
| `test-results/` | Validation output |
| `qemu/` | QEMU disk images and launch scripts |
| `docs/` | Documentation |
| `manifests/` | Package and artifact manifests |

## Validation Pipeline

Stage 0 runs unit tests against the repo itself (no build environment needed):

0. **Unit Tests** — 13 suites, 580+ assertions across configs, security, docs, build reproducibility, version consistency, ISO distribution, and script quality

Stages 1-7 validate the build workspace (`~/gentoo/build/`):

1. **Static Validation** — config syntax, YAML, shell, permissions
2. **Smoke Tests** — directories, files, artifacts exist
3. **Artifact Integrity** — ISO checksums, contents
4. **Installer Config** — Calamares consistency
5. **Offline Payload** — no remote dependencies
6. **E2E Preflight** — full pre-QEMU readiness check
7. **Regression Suite** — no config regressions

Stages 8-9 are automated QEMU tests:

8. **Live Boot Test** — ISO boots in QEMU, validates kernel → systemd → login sequence
9. **Post-Install Test** — installed system boots from disk

Stage 10 is manual:

10. **Manual Verification** — user inspects the running VM

## Key Files

- `VERSION` — Single source of truth for release version
- `gentoovm.iso` — Final ISO image
- `run-unit-tests.sh` — Run all unit tests (repo-level validation)
- `run-all-preqemu-validation.sh` — Run all validation (stages 0-7)
- `run-qemu-final-user-verify.sh` — Launch VM for manual inspection
- `qemu/launch-installed.sh` — Launch installed system anytime
