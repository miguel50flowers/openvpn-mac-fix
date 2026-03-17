#!/bin/bash
# uninstall.sh — Desinstala VPN Monitor
# Uso: ./uninstall.sh

set -euo pipefail

DAEMON_LABEL="com.vpnmonitor"
PLIST_PATH="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
USER_HOME="$HOME"

echo "=== OpenVPN Mac Fix - Desinstalador ==="
echo ""

# 1. Descargar LaunchDaemon
echo "[1/3] Descargando LaunchDaemon..."
if [ -f "$PLIST_PATH" ]; then
    sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
    sudo rm -f "$PLIST_PATH"
    echo "  ✓ LaunchDaemon removido"
else
    echo "  - LaunchDaemon no encontrado (omitido)"
fi

# 2. Eliminar scripts del home
echo "[2/3] Eliminando scripts..."
for script in fix-vpn-disconnect.sh vpn-monitor.sh; do
    if [ -f "$USER_HOME/$script" ]; then
        rm -f "$USER_HOME/$script"
        echo "  ✓ $USER_HOME/$script eliminado"
    else
        echo "  - $USER_HOME/$script no encontrado (omitido)"
    fi
done

# 3. Limpiar archivos temporales
echo "[3/3] Limpiando archivos temporales..."
rm -f /tmp/vpn-was-connected
rm -f /tmp/vpn-monitor.log
echo "  ✓ Archivos temporales eliminados"

echo ""
echo "=== DESINSTALACIÓN COMPLETADA ==="
echo ""
