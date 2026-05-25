#!/bin/bash
# fix-vpn-disconnect.sh — Restores network connectivity after OpenVPN disconnect
# Usage: sudo __USER_HOME__/fix-vpn-disconnect.sh

# NOTE: deliberately NOT using `set -e`. This is a recovery script — if one step fails we must
# still reach the default-route restoration below, never abort half-way and leave the machine
# offline. Individual commands are guarded with `|| true`; `-u`/pipefail stay on for safety.
set -uo pipefail

VERSION="__VERSION__"

LOG="/var/log/VPNFix/vpn-monitor.log"
LOG_LEVEL="${VPN_MONITOR_LOG_LEVEL:-INFO}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [FIX] $*" | tee -a "$LOG"; }
debug() { [ "$LOG_LEVEL" = "DEBUG" ] && echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" | tee -a "$LOG"; }

log "Starting network recovery (v${VERSION})..."

# 1. Remove residual VPN routes (only if no active VPN tunnel process is running)
# Only check tunnel-specific processes, NOT background daemons (fct_launcher, vpnagentd, etc.)
VPN_PROCS="openvpn|wireguard-go|pia-wireguard-go"
if pgrep -x "$VPN_PROCS" > /dev/null 2>&1; then
    log "VPN process still running — skipping route removal (routes are intentional)"
else
    for route in "0/1" "128.0/1"; do
        debug "Checking route: $route"
        if netstat -rn | grep -q "^${route}.*utun"; then
            gw=$(netstat -rn | grep "^${route}.*utun" | awk '{print $2}')
            iface=$(netstat -rn | grep "^${route}.*utun" | awk '{print $NF}')
            route -n delete -net "$route" "$gw" 2>/dev/null && log "Route removed: $route via $gw ($iface)" || true
        fi
    done
fi

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

# 5. Restore default route to local gateway — SAFETY-CRITICAL step.
# Try EVERY active interface (not just the first), parse the gateway cleanly (avoid the brace-
# wrapped form ipconfig sometimes prints), VERIFY the route actually installed, and only stop once
# a physical default route is present. Never stop early on a single failure, never leave offline.
has_physical_default() {
    netstat -rn 2>/dev/null | grep -E '^default' | grep -Eq '(en|bridge)[0-9]'
}

if has_physical_default; then
    debug "Physical default route already present — leaving routing untouched"
else
    log "No physical default route — attempting restore across active interfaces"
    for iface in $ACTIVE_IFACES; do
        # Only interfaces that actually have an IPv4 address can carry a default route.
        ifconfig "$iface" 2>/dev/null | grep -q "inet " || continue
        # Prefer the DHCP router option (returns a bare IP); fall back to parsing the packet.
        GW=$(ipconfig getoption "$iface" router 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        [ -n "$GW" ] || GW=$(ipconfig getpacket "$iface" 2>/dev/null | grep -i "router" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        [ -n "$GW" ] || continue
        route -n add default "$GW" 2>/dev/null || route -n change default "$GW" 2>/dev/null || true
        if has_physical_default; then
            log "Default route restored: $GW via $iface"
            break
        fi
        debug "Route via $iface ($GW) did not take — trying next interface"
    done
    if ! has_physical_default; then
        log "WARNING: could not restore a physical default route — manual check may be needed"
    fi
fi

log "Network recovery completed"

# 6. macOS notification (run as GUI user, not root)
CONSOLE_USER=$(stat -f '%Su' /dev/console 2>/dev/null || echo "__USERNAME__")
CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "501")
launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" osascript -e 'display notification "Network restored successfully" with title "VPN Monitor" subtitle "VPN disconnected - Network restored"' 2>/dev/null || true
