# Security Policy

## Supported Versions

Only the latest release receives security fixes.

| Version | Supported |
|---------|-----------|
| v1.x (latest) | Yes |
| < v1.x | No |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report privately to: jalsarraf0@gmail.com

Include in your report:
- Description of the vulnerability
- Reproduction steps
- Affected component (build script, installer, post-install, ISO)
- Assessed impact

## Response Timeline

- Acknowledgment: within 72 hours
- Critical severity fix: within 7 days
- Other severity: best-effort, typically within 30 days

## Scope

In scope:
- Build scripts (`run-*.sh`, `*.sh` in repo root and subdirectories)
- Installer configuration and scripts
- Post-install scripts
- ISO artifact distribution (integrity, signing)

Out of scope:
- CVEs in upstream Gentoo packages — report to [Gentoo Security](https://security.gentoo.org/)
- Vulnerabilities in QEMU/KVM itself — report to upstream
- The 887 Gentoo packages included in the ISO (tracked by Gentoo GLSA)

## Known Limitations

This is a personal/educational project. Users should be aware of the following by design:

- **VM-only distribution.** GentooVM is built for QEMU/KVM guests only. It is not hardened for bare-metal deployment or production use.
- **Passwordless sudo in live session.** The live installer environment grants passwordless sudo to facilitate the installation process. This is intentional and scoped to the live session only.
- **ACCEPT_LICENSE policy.** The build accepts a broad license set to include all 887 packages. Users who require strict license compliance should audit `make.conf` before use.
- **No enterprise SLA.** Security fixes are provided on a best-effort basis. No guarantee of patch availability for any given vulnerability.
