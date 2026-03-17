# TODO — openvpn-mac-fix Roadmap

## Phase 1 — Improve current solution (quick wins)

- [ ] Create a `.pkg` installer (macOS native) for one-click install without terminal
- [ ] Add versioning (git tags, version variable in scripts)
- [ ] Add Homebrew tap formula (`brew install openvpn-mac-fix`)
- [ ] Improve logging (log rotation, configurable verbosity)

## Phase 2 — Native macOS menu bar app (Swift/SwiftUI)

- [ ] Menu bar icon showing VPN status (connected / disconnected / fixing)
- [ ] Real-time notifications through the app (replace `osascript`)
- [ ] One-click install/uninstall of the daemon from the app
- [ ] View logs from the app
- [ ] Auto-update mechanism
- [ ] Preferences panel (enable/disable, notification settings)

## Phase 3 — Advanced features

- [ ] Support for other VPN clients (WireGuard, Tunnelblick, built-in macOS VPN)
- [ ] Network diagnostics dashboard
- [ ] Automatic reconnection option
- [ ] CLI companion tool (`vpnfix status`, `vpnfix logs`, etc.)

---

## Recommendation

The **recommended next step is Phase 1** — specifically the `.pkg` installer and Homebrew tap.

**Why:**

- Lowers the barrier to entry dramatically (no `git clone` + terminal needed)
- The current shell-based solution works well — no need to rewrite yet
- A menu bar app (Phase 2) is a larger effort and can build on top of Phase 1
