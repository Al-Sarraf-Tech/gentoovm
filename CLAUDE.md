# CLAUDE.md — gentoovm

Custom Gentoo Linux distribution built from scratch for QEMU/KVM virtual machines, with a Cinnamon desktop and one-click GUI installer.

## Build

```bash
bash run-all-preqemu-validation.sh    # pre-QEMU validation (stages 1-7)
bash run-e2e-preflight.sh             # end-to-end preflight checks
```

## Test

```bash
make test                             # or: bash run-unit-tests.sh
```

## Lint

```bash
make lint                             # or: shellcheck --severity=warning $(find . -name '*.sh' -not -path './.git/*')
```
