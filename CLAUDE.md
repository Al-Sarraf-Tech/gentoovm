# CLAUDE.md — gentoovm

Custom Gentoo Linux distribution built from scratch for QEMU/KVM virtual machines, with a Cinnamon desktop and one-click GUI installer.

## Build

```bash
bash run-all-preqemu-validation.sh    # pre-QEMU validation
bash run-e2e-preflight.sh             # end-to-end preflight checks
```

## Test

```bash
bash run-e2e-preflight.sh
bash run-qemu-installed-test.sh       # test installed system in QEMU
bash run-qemu-final-user-verify.sh    # final user verification in QEMU
```

## Lint

```bash
shellcheck run-all-preqemu-validation.sh run-e2e-preflight.sh run-qemu-installed-test.sh run-qemu-final-user-verify.sh
```
