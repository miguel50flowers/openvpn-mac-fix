# ADR-003: Dual Logger Design (HelperLogger + AppLogger)

## Status
Active

## Context
The app (user space) and helper (root daemon) both need to write logs. They run as different users with different file system permissions.

## Decision
Two separate loggers writing to two separate files:
- `HelperLogger` → `/var/log/VPNFix/vpn-monitor.log` (root-owned, 0o644)
- `AppLogger` → `~/Library/Logs/VPNFix/vpn-monitor.log` (user-owned)

The `LogViewModel` tails both files and merges entries by timestamp.

## Rationale
- The helper runs as root; writing to a user-owned path would require knowing the active user.
- The app cannot write to root-owned paths.
- Sending all logs over XPC would add complexity and could cause message ordering issues.
- Both loggers use the same timestamp format, enabling reliable merge-sort in the log viewer.

## Alternatives Considered
- **Single shared log file**: Requires world-writable permissions (security risk, now fixed in C2).
- **XPC-only log transport**: Adds latency and complexity; logs during XPC connection failures would be lost.
- **Apple `os_log`/`Logger`**: Would unify logging but requires different reading strategies (Console.app API) and loses the simple file-tail UX.

## Consequences
- Two log files to manage (rotation handled independently).
- Log viewer must merge and sort from two sources (implemented in `LogViewModel`).
- Log-level filtering at write time reduces unnecessary disk I/O.
