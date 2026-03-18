# TODO — openvpn-mac-fix Roadmap

## Phase 1 — Improve current solution (quick wins)

- [x] Create a `.pkg` installer (macOS native) for one-click install without terminal
- [x] Add versioning (git tags, version variable in scripts)
- [x] Add Homebrew tap formula (`brew install openvpn-mac-fix`)
- [x] Improve logging (log rotation, configurable verbosity)

## Phase 2 — Native macOS app with `.dmg` installer (Swift/SwiftUI)

- [ ] Create `.app` bundle (Swift/SwiftUI) wrapping the existing shell scripts
- [ ] Package as `.dmg` for drag-to-Applications install (standard macOS distribution)
- [ ] Menu bar icon showing VPN status (connected / disconnected / fixing)
- [ ] Real-time notifications through the app (replace `osascript`)
- [ ] One-click install/uninstall of the daemon from the app
- [ ] View logs from the app
- [ ] Auto-update mechanism (Sparkle framework)
- [ ] Preferences panel (enable/disable, notification settings)
- [ ] Code-sign and notarize the `.app`/`.dmg` for Gatekeeper

## Phase 3 — Advanced features

- [ ] Support for other VPN clients (WireGuard, Tunnelblick, built-in macOS VPN)
- [ ] Network diagnostics dashboard
- [ ] Automatic reconnection option
- [ ] CLI companion tool (`vpnfix status`, `vpnfix logs`, etc.)

---

## Notes

- **GitHub Packages** does not apply here — it's for code packages (npm, Docker, etc.), not macOS installers. The `.pkg` in GitHub Releases is the correct approach.
- **`.pkg` vs `.dmg`**: The current `.pkg` works well for the shell-script-based solution. Phase 2's `.dmg` + `.app` is the next evolution for a fully native experience.

## Recommendation

The **recommended next step is Phase 2** — a native Swift/SwiftUI `.app` with `.dmg` installer.

**Why:**

- Phase 1 is complete (`.pkg`, versioning, Homebrew, logging)
- A `.dmg` with drag-to-Applications is the most familiar install experience for macOS users
- The menu bar app provides real-time status without checking logs manually
