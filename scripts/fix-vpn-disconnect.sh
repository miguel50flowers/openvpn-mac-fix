#!/bin/bash
# fix-vpn-disconnect.sh — Restores network connectivity after OpenVPN disconnect
# Usage: sudo __USER_HOME__/fix-vpn-disconnect.sh

set -euo pipefail

VERSION="__VERSION__"

LOG="/tmp/vpn-monitor.log"
LOG_LEVEL="${VPN_MONITOR_LOG_LEVEL:-INFO}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [fix] $*" | tee -a "$LOG"; }
debug() { [ "$LOG_LEVEL" = "DEBUG" ] && log "[DEBUG] $*"; }

log "Starting network recovery (v${VERSION})..."

# 1. Remove residual VPN routes (0/1 and 128.0/1 via utun)
for route in "0/1" "128.0/1"; do
    debug "Checking route: $route"
    if netstat -rn | grep -q "^${route}.*utun"; then
        gw=$(netstat -rn | grep "^${route}.*utun" | awk '{print $2}')
        iface=$(netstat -rn | grep "^${route}.*utun" | awk '{print $NF}')
        route -n delete -net "$route" "$gw" 2>/dev/null && log "Route removed: $route via $gw ($iface)" || true
    fi
done

# 2. Flush DNS
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
log "DNS cache flushed"

# 3. Detect all active network interfaces (excluding lo0 and utun)
ACTIVE_IFACES=$(ifconfig -lu 2>/dev/null | tr ' ' '\n' | grep -v -E '^(lo|utun|awdl|llw|anpi|bridge|ap|ipsec|gif|stf|XHC)' | sort -u)
debug "Active interfaces: $ACTIVE_IFACES"

# 4. Renew DHCP on each active interface
for iface in $ACTIVE_IFACES; do
    debug "Checking interface: $iface"
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
        SERVICE_NAME=$(networksetup -listallhardwareports 2>/dev/null | grep -B1 "Device: $iface" | head -1 | sed 's/Hardware Port: //')
        if [ -n "$SERVICE_NAME" ]; then
            networksetup -setdhcp "$SERVICE_NAME" 2>/dev/null && log "DHCP renewed on: $SERVICE_NAME ($iface)" || true
        fi
    fi
done

# 5. Restore default route to local gateway (if missing)
if ! netstat -rn | grep -q "^default.*en"; then
    for iface in $ACTIVE_IFACES; do
        GW=$(ipconfig getpacket "$iface" 2>/dev/null | grep "router" | awk '{print $NF}' | head -1)
        if [ -n "$GW" ]; then
            route -n add default "$GW" 2>/dev/null && log "Default route restored: $GW via $iface" || true
            break
        fi
    done
fi

log "Network recovery completed"

# 6. macOS notification (run as GUI user, not root)
CONSOLE_USER=$(stat -f '%Su' /dev/console 2>/dev/null || echo "__USERNAME__")
CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "501")
launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" osascript -e 'display notification "Network restored successfully" with title "VPN Monitor" subtitle "VPN disconnected - Network restored"' 2>/dev/null || true
