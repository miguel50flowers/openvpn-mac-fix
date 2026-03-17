# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
