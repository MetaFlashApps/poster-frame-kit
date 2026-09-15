# Security Policy

## Supported Versions

PosterFrameKit is currently pre-release. Security fixes are applied to the
latest tagged pre-release and the default development branch. Older pre-release
tags do not receive separate security updates.

## Reporting a Vulnerability

Please do not disclose a suspected vulnerability, exploit, malicious media
sample, or sensitive system information in a public issue.

Use GitHub's private vulnerability reporting for this repository when it is
available under the **Security** tab. If that option is unavailable, open a
public issue containing no technical details and request a private reporting
channel from the maintainers.

Include, when possible:

- affected version or commit;
- affected Apple platform and OS version;
- a minimal reproduction using generated or safely shareable input;
- potential impact; and
- whether the issue is already public elsewhere.

The maintainers will acknowledge the report, validate its scope, and coordinate
disclosure. No response-time guarantee is made while the project is pre-release.

## Scope

Security issues include unsafe pixel-buffer handling, crashes caused by crafted
input, concurrency violations with security impact, accidental network access,
and package-supply-chain compromise. Thumbnail quality and unsupported
container formats are normally correctness issues rather than security
vulnerabilities.
