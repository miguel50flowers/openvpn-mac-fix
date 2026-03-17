#!/bin/bash
# install.sh — Instala VPN Monitor para macOS
# Uso: ./install.sh (pedirá sudo cuando sea necesario)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$HOME"
USERNAME="$(whoami)"
DAEMON_LABEL="com.vpnmonitor"
PLIST_DEST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"

echo "=== OpenVPN Mac Fix - Instalador ==="
echo "Usuario: $USERNAME"
echo "Home:    $USER_HOME"
echo ""

# 1. Copiar scripts reemplazando placeholders
echo "[1/3] Copiando scripts..."
for script in fix-vpn-disconnect.sh vpn-monitor.sh; do
    sed -e "s|__USER_HOME__|${USER_HOME}|g" \
        -e "s|__USERNAME__|${USERNAME}|g" \
        "$SCRIPT_DIR/scripts/$script" > "$USER_HOME/$script"
    chmod +x "$USER_HOME/$script"
    echo "  ✓ $USER_HOME/$script"
done

# 2. Generar e instalar LaunchDaemon
echo "[2/3] Instalando LaunchDaemon..."
PLIST_TMP="/tmp/${DAEMON_LABEL}.plist"
sed "s|__USER_HOME__|${USER_HOME}|g" "$SCRIPT_DIR/scripts/com.vpnmonitor.plist" > "$PLIST_TMP"

# Descargar daemon previo si existe
sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true

sudo cp "$PLIST_TMP" "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
sudo launchctl load "$PLIST_DEST"
rm -f "$PLIST_TMP"
echo "  ✓ LaunchDaemon instalado y cargado"

# 3. Recordatorio de notificaciones
echo "[3/3] Configuración de notificaciones"
echo ""
echo "=== INSTALACIÓN COMPLETADA ==="
echo ""
echo "⚠  PASO MANUAL REQUERIDO:"
echo "   Para recibir notificaciones del monitor VPN:"
echo "   1. Abre System Settings → Notifications"
echo "   2. Busca 'Script Editor'"
echo "   3. Cambia el estilo de notificación a 'Alerts'"
echo ""
echo "Verifica que funciona:"
echo "   sudo launchctl list | grep vpnmonitor"
echo "   cat /tmp/vpn-monitor.log"
echo ""
