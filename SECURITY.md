# Security Policy

## Supported Versions

Only the latest release receives security updates.

| Version | Supported          |
| ------- | ------------------ |
| 4.x     | :white_check_mark: |
| < 4.0   | :x:                |

## Reporting a Vulnerability

**Do not open a public issue.** Please report security vulnerabilities via email to **security@maecly.com**.

Include the following in your report:

- Description of the vulnerability
- Steps to reproduce
- Impact assessment (severity, affected components)

**Response timeline:**

- Acknowledgment within **48 hours**
- Resolution timeline provided within **7 days**

We will coordinate disclosure with you once a fix is available.

## Security Model

- **Privileged helper daemon** communicates with the main app over XPC, with code signature verification to prevent unauthorized callers.
- **Log files** are written to `/var/log/VPNFix/` with restricted permissions (`0644`), readable by the system but not world-writable.
- **No telemetry** -- VPN Fix does not collect, transmit, or store any network traffic data or usage analytics.
