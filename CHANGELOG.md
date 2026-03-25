# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [4.3.0] - 2026-03-25

### Added

- Onboarding flow for first launch — 4-step guided setup explaining app features, helper installation with context, and quick preferences (notifications, launch at login)
- "Reset Onboarding" button in Settings > General

## [4.2.1] - 2026-03-25

### Fixed

- FortiClient detector no longer falsely reports "Connected" when FortiClient is open but not tunneling — was matching generic utun interfaces created by other VPNs (e.g. OpenVPN)

## [4.2.0] - 2026-03-23

### Fixed

- OpenVPN detection now recognizes OpenVPN Connect (`ovpnagent`, `ovpnhelper`) and Tunnelblick (`tunnelblickd`) processes — fixes menu bar showing "Connected" while dashboard showed "Disconnected"
- Menu bar VPN state now detects all VPN types (WireGuard, FortiClient, GlobalProtect, IKEv2/IPSec) — previously only detected OpenVPN routing signature
- Menu bar now shows accurate multi-VPN connected count and issue count (`refreshClientCounts()` was defined but never called)

### Changed

- All VPN detectors updated with expanded process name lists for more reliable detection (WireGuard, FortiClient, GlobalProtect, CiscoAnyConnect, ExpressVPN, Surfshark, PIA, PulseSecure, Zscaler, Windscribe, ProtonVPN, CyberGhost)
- FortiClient detector now checks both `ppp0` and `utun` interfaces (modern versions use Network Extension)
- WireGuard detector adds utun+IPv4 fallback for App Store NE-based tunnels

### Added

- Scan interval picker in General Settings (10s, 30s, 60s, 2min, 5min) with dynamic timer restart
- Multi-process detection helpers (`isAnyProcessRunning`, `firstRunningProcess`, `hasUtunWithIPv4`) in DetectionUtilities

## [4.1.0] - 2026-03-23

### Added

- "Send Feedback" and "Report Issue" buttons in About view — opens pre-filled GitHub issues with device info and recent logs
- GitHub issue templates (bug report, feature request, feedback) with structured YAML forms
- Pull request template, CODEOWNERS, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
- GitHub Sponsors funding configuration
- Stale issues workflow and Dependabot configuration for Swift and GitHub Actions dependencies

## [4.0.2] - 2026-03-23

### Changed

- README updated to reflect v4.0 unified single-window UI, corrected keyboard shortcuts, and updated architecture diagram
- Added landing page URL (vpn-fix.maecly.com) to README badge, AboutView, Homebrew Cask and Formula homepages

## [4.0.1] - 2026-03-23

### Fixed

- Helper status icon in menu bar now shows green/red color (was overridden by parent style)
- Sidebar no longer shows colored banner bleed-through from detail views
- General Settings organized into sections: Monitoring, App, Updates, Helper

## [4.0.0] - 2026-03-23

### Changed

- **Unified single-window UI**: Replaced 3 separate windows (Dashboard, Settings, Log Viewer) with a single NavigationSplitView window featuring a collapsible sidebar
- Sidebar organized into Monitor (Dashboard, VPN Clients, Network, Logs) and Settings (General, Notifications, Advanced, About) sections with SF Symbol icons
- Fix All and Scan actions moved to unified toolbar, accessible from all sections
- Menu bar simplified — "Open Dashboard" now opens the unified window
- Removed standalone Preferences and Log Viewer windows

## [3.1.3] - 2026-03-23

### Added

- "Show Dashboard on launch" toggle in Settings General tab

## [3.1.2] - 2026-03-23

### Fixed

- Helper status in menu bar rendering as empty space — replaced `Circle()` shape with SF Symbol `circle.fill` Label (shapes don't render in NSMenu)
- "Check for Updates" not working — Sparkle framework was not linked to VPNFix target in project.yml
- Added "Check for Updates..." button to Settings General tab

## [3.1.1] - 2026-03-23

### Fixed

- Settings window growing unbounded — reverted to fixed 450x320 frame
- "Show in Dock" toggle not applying — replaced `onChange(of:)` with custom `Binding` setter (`@AppStorage` doesn't trigger `objectWillChange` in `ObservableObject`)
- Same `onChange` fix applied to "Launch at Login" and "Update Check Frequency" controls
- Helper status text wrapping to 2 lines in menu bar — added `.lineLimit(1)`
- "Check for Updates" window not appearing — added `NSApp.activate()` before Sparkle call
- Copyright updated to 2026 with link to maecly.com

## [3.1.0] - 2026-03-21

### Added

- **Test infrastructure**: XCTest target with 30 unit tests covering Shared models (Codable round-trips, severity ordering, VPN client classification) and log parsing
- **Architecture Decision Records**: 4 ADRs in `docs/adr/` documenting privilege escalation, XPC serialization, dual-logger design, and ad-hoc signing decisions
- **Dependency injection protocols**: `XPCClientProtocol` and `NotificationServiceProtocol` enabling testable ViewModels with injected dependencies
- **XPC retry with exponential backoff**: 3 retries with 1s/2s/4s delays on proxy errors, with automatic connection reset between attempts
- **Localization infrastructure**: `Localizable.strings` base file created for future `String(localized:)` migration
- **HelperTool decomposition**: Extracted `Phase1Migrator` and `StateNotifier` from HelperTool, reducing it from 310 to ~200 lines (SRP compliance)
- **Log-level filtering at write time**: `HelperLogger` now respects `VPN_MONITOR_LOG_LEVEL` environment variable, skipping DEBUG/INFO writes when level is higher
- **CI workflow**: GitHub Actions `ci.yml` for build verification on PRs and pushes to main
- **Typed Result API**: `FixResult` enum and `XPCError` type replacing raw `(Bool, String)` tuples; typed `XPCClient` convenience methods (`detectAllVPNClientsTyped`, `getNetworkDiagnosticsTyped`, `runFixTyped`, etc.)
- **UI state machine**: `DashboardViewModel.ViewState` enum with `.loading`, `.loaded`, `.error`, `.empty` states; Dashboard now shows appropriate feedback for each state
- **Command result tracking**: `DetectionUtilities.CommandResult` struct with exit code and timeout status for error propagation in fix operations
- **Shared routing table parser**: `RoutingTableParser` in Shared target eliminates duplicated VPN detection logic between app and helper
- Accessibility labels and VoiceOver support across all SwiftUI views
  - VPNClientCard: status circles, issue count badges, Fix All button, fix result banners, and no-issues row now announce state to VoiceOver
  - SeverityBadge: announces severity level by text instead of relying on color alone
  - NetworkStatusBanner: combined accessibility element describing overall health status
  - DiagnosticRow: combined label/value element with status announced as text
  - MenuBarView: status header, fix button, and helper status indicator are VoiceOver-accessible
  - BottomToolbar: Fix All and Scan buttons have labels, hints, and dynamic values
  - LogViewerView: log line count, Copy All/Clear Logs hints, and combined log entry labels
  - IssueRow: dismiss button and fix button have labels and hints
- Decorative icons and color-only status circles marked with `.accessibilityHidden(true)`

### Changed

- PreferencesView frame changed from fixed `(width: 450, height: 320)` to `(minWidth: 450, minHeight: 320)` for dynamic type support

### Security

- **Helper log moved** from `/tmp/vpn-monitor.log` (0o666 world-writable) to `/var/log/VPNFix/vpn-monitor.log` (0o644 root-write, world-read) to prevent log injection attacks
- **XPC signature verification always active**: removed `#if !DEBUG` compile-time guard that disabled code signature verification in debug builds; verification now runs unconditionally
- **Shell command injection hardened**: `HelperInstaller` now uses single-quote shell escaping (`shellQuote`) for dynamic Bundle.main paths, preventing `$`, backtick, and semicolon interpretation; fixed broken escaping in `VPNFixApp.removePhase1ArtifactsWithAdmin`

### Fixed

- `CommonFixModule.fix()` now propagates individual step failures instead of always returning success; DNS flush, DHCP renew, and route restoration each report their own exit codes
- `HelperTool.detectAllVPNClients` and `getNetworkDiagnostics` now return error JSON instead of empty success (`"[]"` / `"{}"`) on encoding failure
- `FixEngine.fixAll` now runs `CommonFixModule` once after all client-specific fixes complete, preventing race conditions from concurrent DNS flush and route restoration
- Extracted duplicated VPN detection logic from `VPNStatusViewModel.detectVPNViaNetstat()` to shared `RoutingTableParser`
- All ViewModels annotated with `@MainActor` for compile-time main-thread safety

## [3.0.5] - 2026-03-20

### Fixed

- Fix FortiClient false-positive stale routes detection — removed generic `utun` interface check that flagged iCloud Private Relay and other non-FortiClient tunnels as stale FortiClient routes, causing the "Fix" button to loop endlessly; now only checks for `ppp0` (FortiClient SSLVPN-specific)

## [3.0.4] - 2026-03-20

### Fixed

- Dashboard not opening on app launch — SwiftUI creates Window scenes lazily; replaced single `DispatchQueue.main.async` with retry-based window lookup (up to 5s)
- Fix button showing no visible UI feedback — spinner now stays visible until post-fix rescan completes, then shows green "Fix applied" or red "Fix failed" banner (auto-clears after 5s)
- "Check for Updates" not working — v3.0.3 appcast.xml had unfilled CI placeholders; pulled CI-signed appcast with valid EdDSA signature

## [3.0.3] - 2026-03-20

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
