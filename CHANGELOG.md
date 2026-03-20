# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Fix `ps -axo comm` pipe deadlock: read stdout asynchronously to prevent ~64KB buffer blocking `waitUntilExit()` (was causing 5s timeout every detection cycle)
- Skip `ps` process scan in `getNetworkDiagnostics()` via `includeProcesses: false` — saves ~6s per call since diagnostics don't need process data

### Changed

- **Dashboard UI overhaul:**
  - VPN client cards now show actual issue descriptions with severity badges (critical/high/medium/low) and per-issue fix descriptions
  - Replaced grid layout with full-width list cards for better readability
  - Added dismiss/undismiss support for individual issues (persisted in preferences)
  - "Show dismissed" toggle and "Undismiss All" button when issues are hidden
  - Network Diagnostics renamed to "System Network Status" with subtitle clarifying scope, wrapped in collapsible DisclosureGroup
  - Fix button now shows what each fix will do (e.g., "Remove leftover routes and flush DNS")
  - Dashboard opens automatically on app launch (default changed to true)
  - Added reusable SeverityBadge component with color-coded pills

## [3.0.2] - 2026-03-20

### Fixed

- Fix Dashboard hang: restore fast `currentState()` using only `netstat -rn` for 10s menu bar polling (was running full 17-detector scan blocking XPC queue)
- Add 5-second timeout to all shell commands (`runCommand`) to prevent XPC queue blocking from hung `pfctl`/`scutil` processes
- Cache process list in `DetectionCache` — single `ps` invocation per detection cycle instead of 17 separate spawns
- Replace broken `lazy var` cache with fresh `DetectionCache` instance per detection cycle to prevent stale data
- Remove `detectAllVPNClients` from 10s poll timer (only runs on dashboard's 30s scan timer)

## [3.0.0] - 2026-03-20

### Added

- **Phase 3: Multi-VPN Support, Dashboard & Network Diagnostics**
- Dashboard window (800x600) with VPN client cards, network diagnostics, and Fix All/Scan toolbar (Cmd+D from menu bar)
- Detection engine with pluggable protocol-based detectors for 17 VPN clients:
  - Consumer: OpenVPN, WireGuard, NordVPN, ExpressVPN, Surfshark, CyberGhost, Proton VPN, Mullvad, PIA, IPVanish, Windscribe, TunnelBear
  - Enterprise: Cisco AnyConnect, GlobalProtect, Pulse Secure/Ivanti, Zscaler, FortiClient
- Per-client issue detection: stale routes, kill switch pf rules, DNS leaks, orphaned interfaces, stale proxies, daemon persistence
- Fix module engine with 8 specialized fix modules: Common, OpenVPN, WireGuard, KillSwitch, Proxy, AnyConnect, GlobalProtect, FortiClient
- Network diagnostics panel: DNS servers, default gateway, active interfaces, public IP, PF rules, proxy settings
- XPC protocol extensions: detectAllVPNClients, runFixForClient, runFixAll, getNetworkDiagnostics, vpnClientsChanged callback
- Menu bar aggregate status showing active VPN count and issue count with "Open Dashboard" button
- New preferences: scan interval (default 30s), auto-fix on detect, show dashboard on launch
- Multi-VPN notifications: issues detected per client, per-client fix applied, fix all completed
- VPN client cards with SF Symbol icons (no trademarked logos), status badges, and per-client Fix buttons
- Network status banner with color-coded health indicator (green=healthy, blue=VPN active, red=issues)

## [2.0.14] - 2026-03-20

### Fixed
- Fixed Clear Logs button permanently breaking log tailing (file watchers now restart after clear)

## [2.0.13] - 2026-03-20

### Fixed
- App updates now auto-reinstall helper daemon when version mismatch detected (triggers admin password prompt)
- Log Viewer now reliably shows logs — app writes to ~/Library/Logs/VPNFix/ (no more /tmp permission issues)
- Log Viewer shows both app and helper daemon log entries merged by timestamp
- Removed fragile /tmp permission-fixing code in favor of user-writable log path

## [2.0.12] - 2026-03-20

### Fixed
- Log Viewer still empty when helper daemon not running — AppLogger now checks writability and falls back to NSLog
- Log file permissions now set to 666 in all creation paths (AppLogger, LogViewModel, HelperInstaller)
- Phase 1 cleanup no longer deletes active log file
- Added XPC method for app to request helper fix log permissions on startup
- Local builds (make dmg) now always embed correct version without requiring make clean

## [2.0.11] - 2026-03-20

### Fixed

- Log Viewer showing no entries — app-side logger couldn't write to root-owned log file; helper now sets world-writable permissions

## [2.0.10] - 2026-03-20

### Fixed

- "Launch at Login" toggle now works with ad-hoc signed builds — replaced `SMAppService` (requires Apple Developer ID) with a user-level LaunchAgent plist (`~/Library/LaunchAgents/com.miguel50flowers.VPNFix.plist`)
- Launch at Login toggle now syncs with actual plist state on Preferences open

### Added

- Comprehensive logging across all app and helper components for full transparency when Log Level "All" is selected
  - App initialization: dock icon policy, notification permission, helper install check, Phase 1 migration scan
  - VPNStatusViewModel: init/deinit lifecycle, polling setup, startup retries, local VPN route detection details
  - XPCClient: all method calls (getVPNState, runFix, installWatcher, etc.), connection creation/reuse, state pushes from helper
  - HelperInstaller: binary/daemon status checks, plist generation, admin command execution, install/uninstall/reinstall flow
  - NotificationService: init, permission requests, skipped notifications (disabled in preferences), delivery confirmation
  - SparkleUpdater: controller init, human-readable update check frequency
  - HelperTool: state requests/results, version lookup paths, Phase 1 artifact removal details, state push to app, resolv.conf change handling
  - ScriptRunner: script requests, path resolution (installed vs bundle), process execution, environment vars, completion with exit code
  - VPNDetector: detection requests, netstat execution, route check results (0/1 and 128.0/1)
  - FileWatcher: file descriptor opens, event flags (write/delete/rename/attrib), retry scheduling and success

## [2.0.9] - 2026-03-20

### Fixed

- VPN not detected on app launch — app now runs local `netstat -rn` detection immediately, before the XPC helper is available
- "Fix Now" getting permanently stuck in "Fixing..." state when XPC connection drops or script hangs
- Added rapid startup retries (1s interval for 5 seconds) so XPC state resolves faster on launch
- Added 30-second timeout on fix operations with user-visible error message
- Added 45-second process-level timeout in ScriptRunner to terminate hung scripts

## [2.0.8] - 2026-03-19

### Added

- Dock icon toggle in Preferences (General tab) — show/hide app in Dock at runtime
- "View Logs" button in Preferences (Advanced tab) — opens Log Viewer window directly

### Fixed

- Sparkle update dialog now shows correct per-version release notes instead of hardcoded v2.0.0 notes
- Appcast.xml restructured with multi-item history (one item per release, cumulative notes)
- `make release` now auto-generates appcast items from CHANGELOG.md instead of sed-replacing a single item

## [2.0.7] - 2026-03-19

### Fixed

- Release workflow: checkout `main` before pushing `appcast.xml` to prevent detached-HEAD failures

## [2.0.6] - 2026-03-19

### Added

- "All" log level option in Preferences (shows every log entry, now the default)
- Functional log filtering in Log Viewer — respects the selected log level (ALL > DEBUG > INFO > WARN > ERROR)
- Comprehensive app-side logging via `AppLogger` for:
  - VPN state transitions (old → new state)
  - Manual fix requests and results
  - Monitoring enable/disable toggle
  - Notification dispatch (connect, disconnect, fix applied, test)
  - Update check triggers and frequency changes
  - Helper install, reinstall, uninstall, and skip-if-active flow

### Fixed

- Log Viewer now filters entries by the configured log level (previously showed everything regardless of setting)
- Replaced `NSLog` calls with `AppLogger` in `XPCClient`, `NotificationService`, and `PreferencesView` so all events write to the log file and appear in the Log Viewer

## [2.0.5] - 2026-03-19

### Changed

- Appcast.xml now uses placeholders for build number, EdDSA signature, and DMG length — filled automatically by CI
- Release workflow integrates Sparkle signing to produce properly signed DMG updates
- Added `PROD` environment to release workflow for secrets access

## [2.0.4] - 2026-03-19

### Added

- Update check frequency setting in Preferences (Automatic, Daily, Weekly, Monthly, Manual)
- Selection persisted via `AppStorage` and applied to Sparkle's `SPUUpdater` on launch and on change

## [2.0.3] - 2026-03-19

### Fixed

- Menu bar dropdown layout: replaced `HStack` (Image + Text) with `Label` to prevent macOS `MenuBarExtra` from splitting icon and text into separate menu items

## [2.0.2] - 2026-03-19

### Added

- `AppLogger` service for consistent app-side logging to `/tmp/vpn-monitor.log`
- `HelperInstaller` for managing privileged helper tool installation, reinstall, uninstall, and status checks
- "About" tab in Preferences with app version, description, and GitHub link
- "Send Test Notification" button in Preferences
- "Copy All" button in Log Viewer
- VPN state change notifications (`postVPNConnected`, `postVPNDisconnected`)
- Helper daemon logger with structured levels and log rotation

### Changed

- Updated VPN state SF Symbols for better visual representation
- Streamlined menu bar interactions and helper installation logic in `VPNFixApp`
- Improved empty-state UI in Log Viewer
- Enhanced error handling and logging throughout helper tool
- Updated README with new feature highlights, DMG installer instructions, and centered layout

## [2.0.1] - 2026-03-18

### Fixed

- CHANGELOG ordering: moved old `[Unreleased]` content to `[1.1.0]`, added empty `[Unreleased]` at top
- README: corrected minimum macOS from 12+ (Monterey) to 13+ (Ventura)
- `make release` now updates `appcast.xml` versions/DMG URL and guards commit with `--quiet` check
- `build-pkg.sh` now cleans only pkg artifacts instead of entire build directory

## [2.0.0] - 2026-03-18

### Added

- Native SwiftUI menu bar app ("VPN Fix") with real-time VPN status
- Privileged helper daemon (`VPNFixHelper`) with XPC communication
- Swift-native VPN detection via utun interface monitoring
- `DispatchSource` file watcher on resolv.conf (replaces LaunchDaemon WatchPaths)
- Native macOS notifications via `UNUserNotificationCenter`
- Log viewer window with live tailing and auto-scroll
- Preferences panel (monitoring toggle, notifications, log level, launch at login)
- Sparkle 2.x auto-update integration with EdDSA signing
- Phase 1 migration dialog (detects and removes old shell-based installation)
- `.dmg` installer with drag-to-Applications (`build-dmg.sh`)
- Homebrew Cask (`Casks/vpn-fix.rb`) for `brew install --cask vpn-fix`
- Sparkle appcast feed (`appcast.xml`)
- XcodeGen `project.yml` for reproducible Xcode project generation
- CI/CD pipeline builds both `.dmg` and `.pkg` on tagged releases
- `make app` and `make dmg` targets
- Code signing pipeline scaffolded (deferred until Apple Developer ID obtained)
- Xcode project with two targets: VPNFix (app) and VPNFixHelper (tool)
- Universal binary support (arm64 + x86_64)
- New app icons (Connection Bridge design)
- `make release v=X.Y.Z` target for automated version bumps, tagging, and push

### Changed

- Minimum macOS version raised to 13 (Ventura) for `SMAppService` and `MenuBarExtra`
- VPN detection reimplemented in Swift (no longer spawns bash)
- Notifications use native `UNUserNotificationCenter` instead of `osascript`
- `.github/workflows/release.yml` extended with Xcode build, DMG creation
- `Makefile` extended with `app`, `dmg`, and `clean` targets
- `.gitignore` updated for Xcode artifacts
- `README.md` pkg example updated to v2.0.0

## [1.1.0] - 2026-03-17

### Added

- Version system (`VERSION` file, `__VERSION__` placeholder in scripts)
- Log rotation (rotates at 1MB, keeps 3 old files)
- Configurable log level via `VPN_MONITOR_LOG_LEVEL` env var (INFO/DEBUG)
- `debug()` logging function for verbose diagnostics
- `.pkg` installer for one-click macOS install (`make pkg`)
- `pkg/preinstall` and `pkg/postinstall` scripts
- `build-pkg.sh` build script
- Homebrew formula (`Formula/openvpn-mac-fix.rb`)
- `.gitignore` for `build/` directory
- `make version` and `make pkg` targets

### Changed

- `install.sh` now shows version in banner and replaces `__VERSION__` in scripts
- `uninstall.sh` now cleans up rotated log files (`/tmp/vpn-monitor.log*`)
- `make logs` now shows rotated log files
- LaunchDaemon plist includes `EnvironmentVariables` for log level

## [1.0.0] - 2026-03-17

### Added

- VPN disconnect monitor script (`scripts/vpn-monitor.sh`) that detects when OpenVPN disconnects
- Network recovery script (`scripts/fix-vpn-disconnect.sh`) that restores internet connectivity
- LaunchDaemon plist for event-driven monitoring
- `install.sh` and `uninstall.sh` scripts for easy setup and removal
- Makefile with `install`, `uninstall`, `status`, `logs`, and `test` targets
- MIT License

### Changed

- Removed OpenVPN Connect config and `block-outside-dns` steps from installer
- Translated all files to English
