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
echo "[1/5] Copiando scripts..."
for script in fix-vpn-disconnect.sh vpn-monitor.sh; do
    sed -e "s|__USER_HOME__|${USER_HOME}|g" \
        -e "s|__USERNAME__|${USERNAME}|g" \
        "$SCRIPT_DIR/scripts/$script" > "$USER_HOME/$script"
    chmod +x "$USER_HOME/$script"
    echo "  ✓ $USER_HOME/$script"
done

# 2. Generar e instalar LaunchDaemon
echo "[2/5] Instalando LaunchDaemon..."
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

# 3. Configurar OpenVPN Connect (si existe)
echo "[3/5] Configurando OpenVPN Connect..."
OVPN_CONFIG="$USER_HOME/Library/Application Support/OpenVPN Connect/config.json"
if [ -f "$OVPN_CONFIG" ]; then
    # Backup
    cp "$OVPN_CONFIG" "${OVPN_CONFIG}.backup"

    # Usar python3 (viene con macOS) para modificar JSON
    python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    config = json.load(f)
config['tun_persist'] = True
config['allow_lan_access'] = True
with open(sys.argv[1], 'w') as f:
    json.dump(config, f, indent=2)
print('  ✓ tun_persist y allow_lan_access activados')
" "$OVPN_CONFIG" 2>/dev/null || echo "  ⚠ No se pudo modificar config.json (modifícalo manualmente)"
else
    echo "  - OpenVPN Connect config no encontrado (omitido)"
fi

# 4. Buscar y limpiar block-outside-dns en perfiles .ovpn
echo "[4/5] Buscando perfiles .ovpn con block-outside-dns..."
OVPN_FOUND=0
while IFS= read -r -d '' ovpn_file; do
    if grep -q "block-outside-dns" "$ovpn_file"; then
        sed -i '' '/block-outside-dns/d' "$ovpn_file"
        echo "  ✓ Removido block-outside-dns de: $ovpn_file"
        OVPN_FOUND=$((OVPN_FOUND + 1))
    fi
done < <(find "$USER_HOME/Library/Application Support/OpenVPN Connect" "$USER_HOME/Documents" -name "*.ovpn" -print0 2>/dev/null || true)
if [ "$OVPN_FOUND" -eq 0 ]; then
    echo "  - No se encontraron perfiles con block-outside-dns"
fi

# 5. Recordatorio de notificaciones
echo "[5/5] Configuración de notificaciones"
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
