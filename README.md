<p align="center">
  <img src=".github/assets/icon.png" width="128" height="128" alt="VPN Fix">
</p>
<h3 align="center">VPN Fix</h3>
<p align="center">
  Fix internet connectivity after VPN disconnects on macOS.
</p>
<p align="center">
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest"><img src="https://img.shields.io/github/v/release/miguel50flowers/openvpn-mac-fix?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/miguel50flowers/openvpn-mac-fix?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+">
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/miguel50flowers/openvpn-mac-fix/ci.yml?style=flat-square&label=CI" alt="CI"></a>
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/miguel50flowers/openvpn-mac-fix/release.yml?style=flat-square&label=Release" alt="Release"></a>
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/releases"><img src="https://img.shields.io/github/downloads/miguel50flowers/openvpn-mac-fix/total?style=flat-square" alt="Downloads"></a>
</p>

---

## The Problem

When VPN clients disconnect on macOS, your internet often breaks. This happens because:

1. VPN clients create network routes (e.g. `0/1` and `128.0/1`) that redirect all traffic through the VPN tunnel
2. On disconnect, these routes **are not properly removed**
3. The default route to your local gateway disappears
4. DNS is left pointing to VPN servers that are no longer reachable
5. Kill switch firewall rules (`pf`) may persist, blocking all traffic
6. Proxy settings and orphaned network interfaces can linger

This affects OpenVPN, WireGuard, NordVPN, Cisco AnyConnect, GlobalProtect, and many others. Most users end up **rebooting their Mac** to fix it. VPN Fix does it instantly.

## Features

- **Menu bar app** -- Lives in your menu bar with real-time VPN status indicator
- **Multi-VPN support** -- Detects and fixes 17 VPN clients automatically
- **Dashboard** -- Per-client status cards with issues, severity badges, and one-click fixes
- **Network diagnostics** -- DNS servers, default gateway, active interfaces, PF rules, proxy settings
- **7 issue types detected** -- Stale routes, kill switch rules, DNS leaks, orphaned interfaces, stale proxies, daemon persistence
- **8 fix modules** -- Specialized fixes per VPN client + common fixes (DNS flush, DHCP renew, route restoration)
- **Notifications** -- Native macOS alerts for VPN events and applied fixes
- **Log viewer** -- Built-in viewer with real-time tailing, filtering, and dual-source log merging
- **Auto-update** -- Sparkle-powered updates with EdDSA signature verification
- **Universal binary** -- Runs natively on Apple Silicon and Intel
- **Keyboard shortcuts** -- Quick access to all actions from the menu bar
- **Accessibility** -- Full VoiceOver support with semantic labels and hints
- **Secure architecture** -- Privileged helper daemon with XPC and code signature verification

## Supported VPN Clients

| Consumer | Enterprise |
|----------|------------|
| OpenVPN | Cisco AnyConnect |
| WireGuard | Palo Alto GlobalProtect |
| NordVPN | Pulse Secure / Ivanti |
| ExpressVPN | Zscaler |
| Surfshark | FortiClient |
| CyberGhost | |
| Proton VPN | |
| Mullvad | |
| Private Internet Access | |
| IPVanish | |
| Windscribe | |
| TunnelBear | |

## Installation

### Option 1: DMG (recommended)

Download the latest `.dmg` from [Releases](https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest), open it, and drag **VPN Fix** to your Applications folder.

> **Note:** Since the app is not yet notarized, macOS Gatekeeper will block it on first launch. Right-click the app and select **Open**, then click **Open** in the dialog.

### Option 2: Homebrew Cask

```bash
brew install --cask vpn-fix
```

### Option 3: Homebrew Formula (shell scripts only)

```bash
brew tap miguel50flowers/openvpn-mac-fix
brew install openvpn-mac-fix
cd $(brew --prefix)/Cellar/openvpn-mac-fix/*/libexec && sudo ./install.sh
```

### Option 4: .pkg Installer

Download the latest `.pkg` from [Releases](https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest) and double-click to install.

### Option 5: Build from source

See [Build from Source](#build-from-source) below.

## Requirements

- macOS 13+ (Ventura or later)
- Admin password (required to install the privileged helper daemon)

## How It Works

VPN Fix uses a two-tier architecture to safely perform privileged network operations:

```
┌─────────────────────┐         XPC          ┌─────────────────────┐
│    VPN Fix.app       │ ◄──────────────────► │    VPNFixHelper      │
│    (user space)      │   code-signed IPC    │    (runs as root)    │
│                      │                      │                      │
│  SwiftUI menu bar    │                      │  17 VPN detectors    │
│  Dashboard window    │                      │  8 fix modules       │
│  Preferences         │                      │  File watcher        │
│  Notifications       │                      │  Script runner       │
│  Log viewer          │                      │  Network diagnostics │
└─────────────────────┘                      └─────────────────────┘
```

- **VPN Fix.app** -- The SwiftUI menu bar app you interact with. Shows VPN status, hosts the dashboard, and sends notifications. Runs as your regular user.
- **VPNFixHelper** -- A privileged daemon installed as a LaunchDaemon (`/Library/PrivilegedHelperTools/VPNFixHelper`). Runs as root to perform operations that require elevated privileges: removing routes, flushing DNS, cleaning firewall rules, renewing DHCP.
- **XPC** -- Secure inter-process communication between app and helper. Every connection is verified via code signature to prevent unauthorized access.
- **Detection** -- 17 pluggable detectors (one per VPN client) scan for client-specific issues: stale routes, kill switch rules, DNS leaks, orphaned interfaces, and more.
- **Fix Engine** -- Runs client-specific fix modules first (e.g. OpenVPN route cleanup, AnyConnect interface reset), then common fixes (DNS cache flush, DHCP renewal, default route restoration) once at the end.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + D` | Open Dashboard |
| `Cmd + F` | Fix Now |
| `Cmd + L` | View Logs |
| `Cmd + ,` | Preferences |
| `Cmd + Q` | Quit |

## Uninstall

### Homebrew

```bash
brew uninstall --cask vpn-fix
```

### Manual

```bash
# Remove the app
rm -rf /Applications/VPN\ Fix.app

# Remove the privileged helper
sudo launchctl unload /Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist
sudo rm /Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist
sudo rm /Library/PrivilegedHelperTools/VPNFixHelper
sudo rm -rf /Library/PrivilegedHelperTools/VPNFixResources

# Remove logs
sudo rm -rf /var/log/VPNFix
rm -rf ~/Library/Logs/VPNFix

# Remove preferences
defaults delete com.miguel50flowers.VPNFix

# Remove Launch at Login agent (if enabled)
rm -f ~/Library/LaunchAgents/com.miguel50flowers.VPNFix.plist
```

## Troubleshooting

### Gatekeeper blocks the app

The app is currently ad-hoc signed (Apple Developer ID pending). On first launch, right-click the app and select **Open**, then confirm in the dialog. This only needs to be done once.

### Helper daemon not installed

If the menu bar shows a red dot next to "Helper", open **Preferences** and click **Reinstall Helper**. You will be prompted for your admin password.

### Fix not working

1. Open the **Dashboard** (`Cmd + D`) and run a **Scan** to see detected issues
2. Check **Network Diagnostics** at the bottom of the dashboard for DNS, gateway, and route details
3. Open the **Log Viewer** (`Cmd + L`) and set the log level to **All** for verbose output
4. Try the **Fix All** button from the dashboard toolbar

### Internet still not working after fix

```bash
# Check network routes
netstat -rn | head -20

# Check DNS configuration
scutil --dns | head -20

# Check for stale firewall rules
sudo pfctl -sr 2>/dev/null | head -10
```

### Helper daemon logs

```bash
cat /var/log/VPNFix/vpn-monitor.log
```

## Build from Source

### Prerequisites

- Xcode 15+ (with command line tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [create-dmg](https://github.com/create-dmg/create-dmg): `brew install create-dmg` (optional, for DMG builds)

### Build

```bash
git clone https://github.com/miguel50flowers/openvpn-mac-fix.git
cd openvpn-mac-fix

# Generate Xcode project from project.yml
cd app && xcodegen generate && cd ..

# Build the app
make app

# Build DMG installer
make dmg

# Build .pkg installer
make pkg
```

### Test

```bash
xcodebuild test \
  -project app/VPNFix.xcodeproj \
  -scheme VPNFix \
  -configuration Debug
```

## Contributing

Contributions are welcome! Feel free to open issues and pull requests.

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) -- edit `app/project.yml` instead of modifying the `.xcodeproj` directly.

To add support for a new VPN client:
1. Create a detector in `app/VPNFixHelper/Detectors/`
2. Add a case to `VPNClientType` in `app/Shared/VPNClientType.swift`
3. Create a fix module in `app/VPNFixHelper/FixModules/` (if client-specific fixes are needed)
4. Register the detector in `app/VPNFixHelper/VPNDetector.swift`

<details>
<summary><strong>Legacy: Shell script installation (Phase 1)</strong></summary>

For users who prefer the standalone shell scripts without the native app:

### Copy scripts

```bash
cp scripts/fix-vpn-disconnect.sh ~/fix-vpn-disconnect.sh
cp scripts/vpn-monitor.sh ~/vpn-monitor.sh
chmod +x ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

Edit both files and replace `__USER_HOME__` with your home directory (e.g., `/Users/your_username`) and `__USERNAME__` with your username.

### Install LaunchDaemon

```bash
sed "s|__USER_HOME__|$HOME|g" scripts/com.vpnmonitor.plist > /tmp/com.vpnmonitor.plist

sudo cp /tmp/com.vpnmonitor.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.vpnmonitor.plist
sudo chmod 644 /Library/LaunchDaemons/com.vpnmonitor.plist
sudo launchctl load /Library/LaunchDaemons/com.vpnmonitor.plist
```

### Uninstall scripts

```bash
sudo launchctl unload /Library/LaunchDaemons/com.vpnmonitor.plist
sudo rm /Library/LaunchDaemons/com.vpnmonitor.plist
rm ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

Or use:

```bash
make install    # Install shell scripts + LaunchDaemon
make uninstall  # Remove everything
```

</details>

## License

This project is licensed under the [MIT License](LICENSE).
