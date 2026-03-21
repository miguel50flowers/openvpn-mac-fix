# ADR-001: Privilege Escalation via NSAppleScript

## Status
Active (migration to SMAppService planned)

## Context
The helper daemon runs as root to modify routing tables, DNS, and firewall rules. Installing it requires creating files in `/Library/PrivilegedHelperTools/` and `/Library/LaunchDaemons/`, both root-owned directories.

## Decision
Use `NSAppleScript("do shell script ... with administrator privileges")` to prompt the user for admin credentials and execute the installation commands.

## Rationale
- `SMAppService.daemon()` (macOS 13+) requires a valid Apple Developer ID certificate for code signing. The project currently uses ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) since no Developer ID has been obtained.
- `AuthorizationExecuteWithPrivileges` is deprecated since macOS 10.7.
- The NSAppleScript approach works with ad-hoc signing and provides a native admin prompt.

## Consequences
- Shell command construction risk: paths must be carefully escaped to prevent injection (mitigated with `shellQuote` single-quote escaping).
- The admin dialog is generic (not app-branded).
- Migration to `SMAppService.daemon()` is planned once Developer ID signing is in place.

## Migration Plan
When Developer ID is obtained: replace `HelperInstaller` with `SMAppService.daemon()`, remove shell command construction entirely.
