#!/bin/bash
# e2e-watch.sh — observe the VPN-Fix helper react to a REAL VPN connect/disconnect.
#
# The end-to-end path (helper running as root + a real VPN + the resolv.conf watcher)
# can't be driven from a unit test, so this gives an objective signal while you connect
# and disconnect a VPN by hand. Pair it with tests/e2e-openvpn-checklist.md.
#
# Modes:
#   tests/e2e-watch.sh                live, color-highlighted tail of the helper log
#   tests/e2e-watch.sh --wait 60      wait up to 60s for an auto-fix to trigger, then
#                                     exit 0 (PASS) or 1 (timeout). Disconnect the VPN
#                                     after starting it.
#
# The log is world-readable (0644), so no sudo is needed.

set -uo pipefail

LOG="/var/log/VPNFix/vpn-monitor.log"
# Lines that mark the auto-fix actually firing on a disconnect:
FIRE_RE="running fix|disconnection confirmed"
# Broader set of interesting lines to highlight while watching:
HILITE_RE="AutoFix|disconnection confirmed|running fix|Auto-fix result|\[FIX\]|Network recovery|resolv.conf"

if [ ! -f "$LOG" ]; then
    echo "Helper log not found at $LOG"
    echo "Install the app and enable monitoring first (the helper writes this log as root)."
    echo "Then connect a VPN and re-run this script."
    exit 2
fi

mode="watch"
wait_secs=60
if [ "${1:-}" = "--wait" ]; then
    mode="wait"
    wait_secs="${2:-60}"
fi

if [ "$mode" = "watch" ]; then
    echo "Watching $LOG  (Ctrl-C to stop)"
    echo "Connect, then DISCONNECT your VPN. A working auto-fix logs a line matching:"
    echo "    \"$FIRE_RE\""
    echo "----------------------------------------------------------------------"
    # Print every new line; color the interesting markers.
    exec tail -n 0 -F "$LOG" 2>/dev/null | grep --line-buffered -E --color=always "$HILITE_RE|$"
fi

# --wait mode: objective PASS/timeout.
echo "Waiting up to ${wait_secs}s for an auto-fix to trigger..."
echo "→ DISCONNECT your VPN now (after it was connected)."
TMP="$(mktemp)"
tail -n 0 -F "$LOG" >"$TMP" 2>/dev/null &
TAIL_PID=$!
trap 'kill "$TAIL_PID" 2>/dev/null; rm -f "$TMP"' EXIT

deadline=$(( $(date +%s) + wait_secs ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    if grep -qE "$FIRE_RE" "$TMP"; then
        echo ""
        echo "PASS: auto-fix triggered on disconnect:"
        grep -E "$FIRE_RE" "$TMP" | tail -3
        exit 0
    fi
    sleep 1
done

echo ""
echo "TIMEOUT: no auto-fix line seen in ${wait_secs}s."
echo "If the VPN really disconnected, check: helper installed & monitoring enabled,"
echo "and that the disconnect was a true connected→disconnected transition."
exit 1
