#!/bin/bash
# fix-vpn-disconnect.sh — Restaura conectividad de red tras desconectar OpenVPN
# Uso: sudo __USER_HOME__/fix-vpn-disconnect.sh

set -euo pipefail

LOG="/tmp/vpn-monitor.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [fix] $*" | tee -a "$LOG"; }

log "Iniciando recuperacion de red..."

# 1. Eliminar rutas residuales del VPN (0/1 y 128.0/1 via utun)
for route in "0/1" "128.0/1"; do
    if netstat -rn | grep -q "^${route}.*utun"; then
        gw=$(netstat -rn | grep "^${route}.*utun" | awk '{print $2}')
        iface=$(netstat -rn | grep "^${route}.*utun" | awk '{print $NF}')
        route -n delete -net "$route" "$gw" 2>/dev/null && log "Ruta eliminada: $route via $gw ($iface)" || true
    fi
done

# 2. Flush DNS
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
log "DNS cache limpiado"

# 3. Detectar todas las interfaces de red activas (excluyendo lo0 y utun)
ACTIVE_IFACES=$(ifconfig -lu 2>/dev/null | tr ' ' '\n' | grep -v -E '^(lo|utun|awdl|llw|anpi|bridge|ap|ipsec|gif|stf|XHC)' | sort -u)

# 4. Renovar DHCP en cada interfaz activa
for iface in $ACTIVE_IFACES; do
    # Verificar que la interfaz tiene una IP asignada
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
        SERVICE_NAME=$(networksetup -listallhardwareports 2>/dev/null | grep -B1 "Device: $iface" | head -1 | sed 's/Hardware Port: //')
        if [ -n "$SERVICE_NAME" ]; then
            networksetup -setdhcp "$SERVICE_NAME" 2>/dev/null && log "DHCP renovado en: $SERVICE_NAME ($iface)" || true
        fi
    fi
done

# 5. Restaurar ruta default al gateway local (si no existe)
if ! netstat -rn | grep -q "^default.*en"; then
    # Buscar gateway del primer adaptador con IP
    for iface in $ACTIVE_IFACES; do
        GW=$(ipconfig getpacket "$iface" 2>/dev/null | grep "router" | awk '{print $NF}' | head -1)
        if [ -n "$GW" ]; then
            route -n add default "$GW" 2>/dev/null && log "Ruta default restaurada: $GW via $iface" || true
            break
        fi
    done
fi

log "Recuperacion de red completada"

# 6. Notificacion macOS (ejecutar como el usuario GUI, no como root)
CONSOLE_USER=$(stat -f '%Su' /dev/console 2>/dev/null || echo "__USERNAME__")
CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "501")
launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" osascript -e 'display notification "Red restaurada correctamente" with title "VPN Monitor" subtitle "VPN desconectada - Red restaurada"' 2>/dev/null || true
