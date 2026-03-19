# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
- Replaced `NSLog` calls with `AppLogger` in `XPCClient`, `NotificationService`, and `PreferencesView` so all events write to the log file (`/tmp/vpn-monitor.log`) and appear in the Log Viewer

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
