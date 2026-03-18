# TODO — openvpn-mac-fix Roadmap

## Phase 1 — Improve current solution (quick wins)

- [x] Create a `.pkg` installer (macOS native) for one-click install without terminal
- [x] Add versioning (git tags, version variable in scripts)
- [x] Add Homebrew tap formula (`brew install openvpn-mac-fix`)
- [x] Improve logging (log rotation, configurable verbosity)

## Phase 2 — Native macOS app with `.dmg` installer (Swift/SwiftUI)

- [x] Create `.app` bundle (Swift/SwiftUI) wrapping the existing shell scripts
- [x] Package as `.dmg` for drag-to-Applications install (standard macOS distribution)
- [x] Menu bar icon showing VPN status (connected / disconnected / fixing)
- [x] Real-time notifications through the app (replace `osascript`)
- [x] One-click install/uninstall of the daemon from the app
- [x] View logs from the app
- [x] Auto-update mechanism (Sparkle framework)
- [x] Preferences panel (enable/disable, notification settings)
- [ ] Code-sign and notarize the `.app`/`.dmg` for Gatekeeper (pending Apple Developer ID)
- [x] Homebrew Cask for `.dmg` distribution
- [x] Phase 1 migration dialog (detect and remove old installation)
- [x] Privileged helper daemon with XPC communication
- [x] Native VPN detection (Swift, replaces shell-based utun check)
- [x] CI/CD pipeline for `.dmg` + `.pkg` releases

## Phase 3 — Advanced features

- [ ] Support for other VPN clients (WireGuard, Tunnelblick, built-in macOS VPN)
- [ ] Network diagnostics dashboard
- [ ] Automatic reconnection option
- [ ] CLI companion tool (`vpnfix status`, `vpnfix logs`, etc.)

---

## Notes

- **GitHub Packages** does not apply here — it's for code packages (npm, Docker, etc.), not macOS installers. The `.pkg` in GitHub Releases is the correct approach.
- **`.pkg` vs `.dmg`**: The `.pkg` remains available for shell-script-only users. Phase 2's `.dmg` + `.app` is the primary distribution for the native app experience.
- **Code signing**: Pipeline is scaffolded. Once an Apple Developer ID certificate is obtained, uncomment the signing/notarization steps in `.github/workflows/release.yml`.
