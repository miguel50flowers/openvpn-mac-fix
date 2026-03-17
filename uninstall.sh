#!/bin/bash
# uninstall.sh — Uninstalls VPN Monitor
# Usage: ./uninstall.sh

set -euo pipefail

DAEMON_LABEL="com.vpnmonitor"
PLIST_PATH="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
USER_HOME="$HOME"

echo "=== OpenVPN Mac Fix - Uninstaller ==="
echo ""

# 1. Unload LaunchDaemon
echo "[1/3] Unloading LaunchDaemon..."
if [ -f "$PLIST_PATH" ]; then
    sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
    sudo rm -f "$PLIST_PATH"
    echo "  ✓ LaunchDaemon removed"
else
    echo "  - LaunchDaemon not found (skipped)"
fi

# 2. Remove scripts from home
echo "[2/3] Removing scripts..."
for script in fix-vpn-disconnect.sh vpn-monitor.sh; do
    if [ -f "$USER_HOME/$script" ]; then
        rm -f "$USER_HOME/$script"
        echo "  ✓ $USER_HOME/$script removed"
    else
        echo "  - $USER_HOME/$script not found (skipped)"
    fi
done

# 3. Clean up temporary files
echo "[3/3] Cleaning up temporary files..."
rm -f /tmp/vpn-was-connected
rm -f /tmp/vpn-monitor.log
echo "  ✓ Temporary files removed"

echo ""
echo "=== UNINSTALLATION COMPLETE ==="
echo ""
