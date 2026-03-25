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
- [x] Homebrew Cask for `.dmg` distribution
- [x] Phase 1 migration dialog (detect and remove old installation)
- [x] Privileged helper daemon with XPC communication
- [x] Native VPN detection (Swift, replaces shell-based utun check)
- [x] CI/CD pipeline for `.dmg` + `.pkg` releases
- [x] Dock icon toggle (Show in Dock preference) — v2.0.8
- [x] Configurable update check frequency — v2.0.4
- [x] AppLogger structured logging — v2.0.2
- [x] Multi-item appcast with per-version release notes — v2.0.8
- [x] Unit tests (30 XCTest tests covering Shared models, log parsing) — v3.1.0
- [ ] Code-sign and notarize the `.app`/`.dmg` for Gatekeeper (pending Apple Developer ID)
- [ ] Homebrew formula/cask SHA256 integrity (currently empty/`:no_check`)

## Phase 2.5 — Production polish

- [x] Keyboard shortcuts for menu bar actions (⌘F Fix Now, ⌘L View Logs, ⌘, Preferences, ⌘Q Quit)
- [x] Accessibility labels for VoiceOver (status indicators, buttons, log viewer) — v3.1.0
- [x] XPC reconnection with exponential backoff on helper crash (3 retries with 1s/2s/4s delays) — v3.1.0
- [x] Architecture Decision Records (4 ADRs: privilege escalation, XPC serialization, dual-logger, ad-hoc signing) — v3.1.0
- [x] Dependency injection protocols (`XPCClientProtocol`, `NotificationServiceProtocol`) for testable ViewModels — v3.1.0
- [x] Typed Result API (`FixResult`, `XPCError`) replacing raw tuples — v3.1.0
- [x] HelperTool decomposition (extracted `Phase1Migrator`, `StateNotifier`, SRP compliance) — v3.1.0
- [x] Security hardening: log moved from `/tmp` to `/var/log/VPNFix/` (0o644), XPC signature verification always active, shell injection hardening — v3.1.0
- [x] Shared `RoutingTableParser` eliminating duplicated VPN detection logic — v3.1.0
- [x] UI state machine for Dashboard (`ViewState` enum: loading/loaded/error/empty) — v3.1.0
- [x] Onboarding flow for first launch (permission requests, helper install explanation) — v4.3.0

## Phase 3 — Multi-VPN Support & Network Diagnostics

- [x] VPN client auto-detection (17 VPN clients: OpenVPN, WireGuard, NordVPN, ExpressVPN, Surfshark, CyberGhost, Proton VPN, Mullvad, PIA, IPVanish, Windscribe, TunnelBear, Cisco AnyConnect, GlobalProtect, Pulse Secure, Zscaler, FortiClient) — v3.0.0
- [x] Fix engine per VPN client (8 modular fix modules: Common, OpenVPN, WireGuard, KillSwitch, Proxy, AnyConnect, GlobalProtect, FortiClient) — v3.0.0
- [x] DNS leak detection and auto-fix — v3.0.0
- [x] Kill switch cleanup (detect and clean stale pf rules from any VPN client) — v3.0.0
- [x] Orphaned interface cleanup (detect and destroy stale utun/ipsec interfaces) — v3.0.0
- [x] Stale proxy settings fix (clean SOCKS/HTTP/PAC proxy configs left by VPN disconnect) — v3.0.0
- [x] Network diagnostics dashboard (DNS servers, default gateway, active interfaces, PF rules, proxy settings) — v3.0.0
- [x] Dashboard UI overhaul: severity badges, per-issue fix descriptions, dismiss/undismiss, collapsible diagnostics — v3.0.3
- [x] Show Dashboard on launch toggle — v3.1.3
- [ ] Hide/remove VPN from Dashboard (per-client visibility toggle, persisted in UserDefaults, "Manage VPNs" panel to restore hidden clients) — see `docs/VPN-DASHBOARD-MANAGEMENT.md`
- [ ] Manually add VPN client (app picker via `NSWorkspace`/Launch Services, or select from known list; custom entries stored in UserDefaults with bundle ID + app path + interface type) — see `docs/VPN-DASHBOARD-MANAGEMENT.md`
- [ ] CLI companion tool (`vpnfix status`, `vpnfix diagnose`, `vpnfix fix --all`)

## Phase 3.5 — Unified UI & Community

- [x] **Unified single-window UI**: Replaced 3 separate windows (Dashboard, Settings, Log Viewer) with a single NavigationSplitView window featuring collapsible sidebar — v4.0.0
- [x] Sidebar organized into Monitor (Dashboard, VPN Clients, Network, Logs) and Settings (General, Notifications, Advanced, About) sections — v4.0.0
- [x] Landing page (vpn-fix.maecly.com) — v4.0.2
- [x] In-app "Send Feedback" and "Report Issue" buttons with pre-filled GitHub issues (device info + recent logs, IP redaction) — v4.1.0
- [x] GitHub issue templates (bug report, feature request, feedback) with YAML forms — v4.1.0
- [x] Pull request template — v4.1.0
- [x] CODEOWNERS (@miguel50flowers @MigelAngelEC) — v4.1.0
- [x] Community files: CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md — v4.1.0
- [x] GitHub Sponsors funding configuration — v4.1.0
- [x] Dependabot for Swift and GitHub Actions dependencies — v4.1.0
- [x] Stale issues workflow (60 days stale, 7 days to close) — v4.1.0
- [ ] Branch protection rules on `main` (require PR reviews, CI status checks, CODEOWNERS review)

## Phase 4 — Network Repair Toolkit (non-VPN)

- [ ] DNS flush one-click (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`)
- [ ] DHCP release/renew (`ipconfig set en0 BOOTP` → `ipconfig set en0 DHCP`)
- [ ] Network interface reset (down/up on stuck interfaces)
- [ ] mDNSResponder restart (fix Bonjour/local DNS issues)
- [ ] Network preferences reset (backup + delete SystemConfiguration plists)
- [ ] IPv6 toggle (enable/disable per interface)
- [ ] MTU auto-detection and fix (detect MTU issues, reset to 1500 or optimal value)
- [ ] Firewall rules audit (show active pf rules, identify stale VPN anchors)
- [ ] "Fix Everything" one-click button (run full repair chain: routes → DNS → pf → interfaces → proxy → DHCP)
- [ ] Automatic reconnection option

## Phase 5 — Advanced Features & Polish

- [ ] Widgets (macOS 14+ WidgetKit for VPN/network status on desktop)
- [ ] Menu bar expandable status (connection time, IP, latency, DNS server)
- [ ] Export diagnostics report (generate PDF/text report for IT support)
- [ ] SMAppService migration (replace AppleScript privilege elevation with modern macOS API)
- [ ] Localization (Spanish first, then community translations)
- [ ] VPN-specific error code database (lookup table of known errors → causes → fixes)
- [ ] macOS version compatibility advisor (alert if VPN has known issues on current macOS version)

---

## Notes

- **GitHub Packages** does not apply here — it's for code packages (npm, Docker, etc.), not macOS installers. The `.pkg` in GitHub Releases is the correct approach.
- **`.pkg` vs `.dmg`**: The `.pkg` remains available for shell-script-only users. Phase 2's `.dmg` + `.app` is the primary distribution for the native app experience.
- **Code signing**: Pipeline is scaffolded in `.github/workflows/release.yml`. Once an Apple Developer ID certificate is obtained, uncomment the signing/notarization steps. Testing and accessibility are recommended prerequisites before pursuing notarization.
- **Testing**: 30 XCTest unit tests added in v3.1.0 covering Shared models (Codable, severity ordering, VPN client classification) and log parsing. Expanding coverage to VPNDetector, LogViewModel, and AppPreferences is the next priority.
- **Accessibility**: Full VoiceOver support added in v3.1.0 with semantic labels, hints, and `accessibilityHidden` on decorative elements across all views.
- **Re-branding**: As the tool expands beyond OpenVPN, consider renaming from "openvpn-mac-fix" to something broader like **"NetFix"**, **"VPN Fix Pro"**, or **"MacNetRepair"**. The current name limits discoverability for users with non-OpenVPN issues.
- **Market gap**: As of March 2026, there is **no direct competitor** in the "VPN fixer" category on macOS. See `docs/COMPETITIVE-ANALYSIS.md` for details. Existing tools are VPN clients, network monitors, or general utilities — none specialize in repairing VPN-caused network damage.
- **Localization**: Moved from Phase 2.5 to Phase 5 to consolidate all localization work after features stabilize.
- **VPN Dashboard Management**: Research on hiding/adding VPN clients, macOS detection APIs, and UI patterns documented in `docs/VPN-DASHBOARD-MANAGEMENT.md`.
- **Open source infrastructure**: Full GitHub community setup deployed in v4.1.0 — issue templates, PR template, CODEOWNERS, contributing guidelines, security policy, Dependabot, stale bot, and GitHub Sponsors.
