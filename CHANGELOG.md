# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
