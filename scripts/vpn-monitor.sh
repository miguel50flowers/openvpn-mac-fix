#!/bin/bash
# vpn-monitor.sh — Detecta desconexion de VPN y ejecuta recuperacion
# Se ejecuta puntualmente (via WatchPaths en launchd), no en loop

STATE_FILE="/tmp/vpn-was-connected"
LOG="/tmp/vpn-monitor.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [monitor] $*" >> "$LOG"; }

# Verificar si hay alguna interfaz utun activa con IP (VPN conectada)
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
    # VPN esta conectada — notificar solo si es conexion nueva
    if [ ! -f "$STATE_FILE" ] || [ "$(cat "$STATE_FILE" 2>/dev/null)" != "connected" ]; then
        notify "Conectado al tunel VPN" "VPN conectada"
    fi
    echo "connected" > "$STATE_FILE"
    log "VPN detectada activa, estado guardado"
else
    # VPN no esta activa — verificar si antes lo estaba
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "connected" ]; then
        log "VPN desconectada detectada, ejecutando recuperacion..."
        rm -f "$STATE_FILE"
        /bin/bash __USER_HOME__/fix-vpn-disconnect.sh 2>&1 | tee -a "$LOG"
    fi
fi
