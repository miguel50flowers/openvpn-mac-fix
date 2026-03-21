#!/bin/bash
# vpn-monitor.sh — Detects VPN disconnection and triggers network recovery
# Runs on-demand (via WatchPaths in launchd), not in a loop

VERSION="__VERSION__"

STATE_FILE="/tmp/vpn-was-connected"
LOG="/var/log/VPNFix/vpn-monitor.log"
LOG_LEVEL="${VPN_MONITOR_LOG_LEVEL:-INFO}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [monitor] $*" >> "$LOG"; }
debug() { [ "$LOG_LEVEL" = "DEBUG" ] && log "[DEBUG] $*"; }

# Rotate log when it exceeds 1MB, keep max 3 old files
rotate_logs() {
    if [ -f "$LOG" ]; then
        local size
        size=$(stat -f%z "$LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            [ -f "${LOG}.2" ] && rm -f "${LOG}.3" && mv "${LOG}.2" "${LOG}.3"
            [ -f "${LOG}.1" ] && mv "${LOG}.1" "${LOG}.2"
            mv "$LOG" "${LOG}.1"
            log "Log rotated (previous log exceeded 1MB)"
        fi
    fi
}

rotate_logs

# Log version on first run (state file absent)
if [ ! -f "$STATE_FILE" ]; then
    log "vpn-monitor v${VERSION} started"
fi

# Check if any utun interface is active with an IP (VPN connected)
VPN_ACTIVE=false
for iface in $(ifconfig -lu 2>/dev/null | tr ' ' '\n' | grep '^utun'); do
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
        VPN_ACTIVE=true
        break
    fi
done

CONSOLE_USER=$(stat -f '%Su' /dev/console 2>/dev/null || echo "__USERNAME__")
CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "501")
notify() { launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" osascript -e "display notification \"$1\" with title \"VPN Monitor\" subtitle \"$2\"" 2>/dev/null || true; }

if $VPN_ACTIVE; then
    # VPN is connected — notify only on new connection
    if [ ! -f "$STATE_FILE" ] || [ "$(cat "$STATE_FILE" 2>/dev/null)" != "connected" ]; then
        notify "Connected to VPN tunnel" "VPN connected"
    fi
    echo "connected" > "$STATE_FILE"
    log "VPN detected active, state saved"
else
    # VPN is not active — check if it was previously connected
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "connected" ]; then
        log "VPN disconnection detected, running recovery..."
        rm -f "$STATE_FILE"
        /bin/bash __USER_HOME__/fix-vpn-disconnect.sh 2>&1 | tee -a "$LOG"
    fi
fi
