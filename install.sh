#!/bin/bash
# install.sh — Installs VPN Monitor for macOS
# Usage: ./install.sh (will prompt for sudo when needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")
USER_HOME="$HOME"
USERNAME="$(whoami)"
DAEMON_LABEL="com.vpnmonitor"
PLIST_DEST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"

echo "=== OpenVPN Mac Fix v${VERSION} - Installer ==="
echo "User: $USERNAME"
echo "Home: $USER_HOME"
echo ""

# 1. Copy scripts replacing placeholders
echo "[1/3] Copying scripts..."
for script in fix-vpn-disconnect.sh vpn-monitor.sh; do
    sed -e "s|__USER_HOME__|${USER_HOME}|g" \
        -e "s|__USERNAME__|${USERNAME}|g" \
        -e "s|__VERSION__|${VERSION}|g" \
        "$SCRIPT_DIR/scripts/$script" > "$USER_HOME/$script"
    chmod +x "$USER_HOME/$script"
    echo "  ✓ $USER_HOME/$script"
done

# 2. Generate and install LaunchDaemon
echo "[2/3] Installing LaunchDaemon..."
PLIST_TMP="/tmp/${DAEMON_LABEL}.plist"
sed "s|__USER_HOME__|${USER_HOME}|g" "$SCRIPT_DIR/scripts/com.vpnmonitor.plist" > "$PLIST_TMP"

# Unload previous daemon if exists
sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true

sudo cp "$PLIST_TMP" "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
sudo launchctl load "$PLIST_DEST"
rm -f "$PLIST_TMP"
echo "  ✓ LaunchDaemon installed and loaded"

# 3. Notification reminder
echo "[3/3] Notification setup"
echo ""
echo "=== INSTALLATION COMPLETE ==="
echo ""
echo "⚠  MANUAL STEP REQUIRED:"
echo "   To receive VPN monitor notifications:"
echo "   1. Open System Settings → Notifications"
echo "   2. Find 'Script Editor'"
echo "   3. Set notification style to 'Alerts'"
echo ""
echo "Verify it works:"
echo "   sudo launchctl list | grep vpnmonitor"
echo "   cat /tmp/vpn-monitor.log"
echo ""
