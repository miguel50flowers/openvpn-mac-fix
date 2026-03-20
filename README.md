<p align="center">
  <img src=".github/assets/icon.png" width="128" height="128" alt="VPN Fix">
</p>
<h3 align="center">VPN Fix</h3>
<p align="center">
  Automatic fix for internet loss after disconnecting OpenVPN on macOS.
</p>
<p align="center">
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest"><img src="https://img.shields.io/github/v/release/miguel50flowers/openvpn-mac-fix?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/miguel50flowers/openvpn-mac-fix?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+">
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/miguel50flowers/openvpn-mac-fix/release.yml?style=flat-square" alt="Build"></a>
  <a href="https://github.com/miguel50flowers/openvpn-mac-fix/releases"><img src="https://img.shields.io/github/downloads/miguel50flowers/openvpn-mac-fix/total?style=flat-square" alt="Downloads"></a>
</p>

---

## The Problem

When disconnecting OpenVPN Connect on macOS, the system loses internet connectivity. This happens because:

1. OpenVPN creates network routes (`0/1` and `128.0/1`) that redirect all traffic through the VPN tunnel
2. On disconnect, these routes **are not properly removed**
3. The default route to the local gateway disappears
4. DNS is left pointing to VPN servers that are no longer reachable

## Features

- **Menu bar app** — Lives in your menu bar, always ready
- **Automatic fix** — Detects VPN disconnection and restores connectivity instantly
- **Notifications** — Get alerts when the fix is applied
- **Log viewer** — Built-in log viewer to see what happened
- **Auto-update** — Sparkle-powered updates, always stay current
- **Universal binary** — Runs natively on Apple Silicon and Intel

## Installation

### Option 1: DMG (recommended)

Download the latest `.dmg` from [Releases](https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest), open it, and drag **VPN Fix** to your Applications folder.

### Option 2: Homebrew

```bash
brew tap miguel50flowers/openvpn-mac-fix
brew install openvpn-mac-fix
cd $(brew --prefix)/Cellar/openvpn-mac-fix/*/libexec && sudo ./install.sh
```

### Option 3: .pkg Installer

Download the latest `.pkg` from [Releases](https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest) and double-click to install. Or from the terminal:

```bash
sudo installer -pkg openvpn-mac-fix-3.0.4.pkg -target /
```

### Option 4: Git clone

```bash
git clone https://github.com/miguel50flowers/openvpn-mac-fix.git
cd openvpn-mac-fix
make install
```

The installer automatically:
- Copies scripts to your home directory (`~/`)
- Installs and loads the LaunchDaemon

## Build from Source

```bash
make app    # Build VPN Fix.app
make dmg    # Build .dmg installer (includes app build)
make pkg    # Build .pkg installer
```

## Manual Installation

### 1. Copy scripts

```bash
cp scripts/fix-vpn-disconnect.sh ~/fix-vpn-disconnect.sh
cp scripts/vpn-monitor.sh ~/vpn-monitor.sh
chmod +x ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

Edit both files and replace `__USER_HOME__` with your home directory (e.g., `/Users/your_username`) and `__USERNAME__` with your username.

### 2. Install LaunchDaemon

```bash
# Edit the plist replacing __USER_HOME__
sed "s|__USER_HOME__|$HOME|g" scripts/com.vpnmonitor.plist > /tmp/com.vpnmonitor.plist

sudo cp /tmp/com.vpnmonitor.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.vpnmonitor.plist
sudo chmod 644 /Library/LaunchDaemons/com.vpnmonitor.plist
sudo launchctl load /Library/LaunchDaemons/com.vpnmonitor.plist
```

## Requirements

- macOS 13+ (Ventura or later)
- OpenVPN Connect installed
- `sudo` access (for legacy shell script installation)

## Configure Notifications

To receive alerts when the monitor detects connection/disconnection:

1. Open **System Settings** → **Notifications**
2. Find **Script Editor**
3. Set notification style to **Alerts**

## Verification

```bash
# Check that the daemon is loaded
sudo launchctl list | grep vpnmonitor

# View monitor logs
cat /tmp/vpn-monitor.log

# Manually test the fix (requires sudo)
sudo ~/fix-vpn-disconnect.sh
```

## Uninstall

```bash
cd openvpn-mac-fix
make uninstall
```

Or manually:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.vpnmonitor.plist
sudo rm /Library/LaunchDaemons/com.vpnmonitor.plist
rm ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

## Troubleshooting

### Monitor doesn't trigger
```bash
# Check if the daemon is loaded
sudo launchctl list | grep vpnmonitor

# If not listed, reload it
sudo launchctl load /Library/LaunchDaemons/com.vpnmonitor.plist
```

### Not receiving notifications
- Verify that **Script Editor** has **Alerts** notification style in System Settings
- Check the logs: `cat /tmp/vpn-monitor.log`

### Internet still not working after the fix
```bash
# Run manually with logs
sudo ~/fix-vpn-disconnect.sh

# Check network routes
netstat -rn | head -20

# Check DNS
scutil --dns | head -20
```

### Permissions
If you see permission errors, make sure the scripts are executable:
```bash
chmod +x ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

## How It Works

- **`vpn-monitor.sh`** — A monitor that triggers automatically when it detects network configuration changes (via launchd `WatchPaths`). Detects VPN disconnection and runs the recovery script.
- **`fix-vpn-disconnect.sh`** — Restores connectivity: removes residual VPN routes, flushes DNS, renews DHCP, and restores the default route.
- **LaunchDaemon** — Keeps the monitor running in the background, watching for changes in `/var/run/resolv.conf` and `/etc/resolv.conf`.

## Contributing

Contributions are welcome! Feel free to open issues and pull requests.

## License

This project is licensed under the [MIT License](LICENSE).
