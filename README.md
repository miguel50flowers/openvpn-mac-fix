# OpenVPN Mac Fix

Solución automática para el problema de **pérdida de internet al desconectar OpenVPN** en macOS.

## El problema

Al desconectar OpenVPN Connect en macOS, el sistema pierde conectividad a internet. Esto ocurre porque:

1. OpenVPN crea rutas de red (`0/1` y `128.0/1`) que redirigen todo el tráfico por el túnel VPN
2. Al desconectar, estas rutas **no se eliminan correctamente**
3. La ruta default al gateway local desaparece
4. El DNS queda apuntando a servidores del VPN que ya no son accesibles

## Cómo funciona esta solución

- **`vpn-monitor.sh`** — Un monitor que se activa automáticamente cuando detecta cambios en la configuración de red (via `WatchPaths` de launchd). Detecta si la VPN se desconectó y ejecuta la recuperación.
- **`fix-vpn-disconnect.sh`** — Script que restaura la conectividad: elimina rutas residuales del VPN, limpia DNS, renueva DHCP y restaura la ruta default.
- **LaunchDaemon** — Mantiene el monitor activo en segundo plano observando cambios en `/var/run/resolv.conf` y `/etc/resolv.conf`.

## Requisitos

- macOS 12+ (Monterey o superior)
- OpenVPN Connect instalado
- Acceso `sudo`

## Instalación rápida

```bash
git clone https://github.com/miguel50flowers/openvpn-mac-fix.git
cd openvpn-mac-fix
chmod +x install.sh
./install.sh
```

El instalador automáticamente:
- Copia los scripts a tu directorio home (`~/`)
- Instala y carga el LaunchDaemon
- Configura OpenVPN Connect (`tun_persist`, `allow_lan_access`) si está instalado
- Elimina `block-outside-dns` de perfiles `.ovpn`

## Instalación manual

### 1. Copiar scripts

```bash
cp scripts/fix-vpn-disconnect.sh ~/fix-vpn-disconnect.sh
cp scripts/vpn-monitor.sh ~/vpn-monitor.sh
chmod +x ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

Edita ambos archivos y reemplaza `__USER_HOME__` con tu directorio home (ej: `/Users/tu_usuario`) y `__USERNAME__` con tu nombre de usuario.

### 2. Instalar LaunchDaemon

```bash
# Editar el plist reemplazando __USER_HOME__
sed "s|__USER_HOME__|$HOME|g" scripts/com.vpnmonitor.plist > /tmp/com.vpnmonitor.plist

sudo cp /tmp/com.vpnmonitor.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.vpnmonitor.plist
sudo chmod 644 /Library/LaunchDaemons/com.vpnmonitor.plist
sudo launchctl load /Library/LaunchDaemons/com.vpnmonitor.plist
```

### 3. Configurar OpenVPN Connect

Edita `~/Library/Application Support/OpenVPN Connect/config.json` y asegúrate de tener:

```json
{
  "tun_persist": true,
  "allow_lan_access": true
}
```

### 4. Eliminar block-outside-dns

Si tus perfiles `.ovpn` contienen la línea `block-outside-dns`, elimínala. Esta directiva es para Windows y causa problemas en macOS.

## Configurar notificaciones

Para recibir alertas cuando el monitor detecta conexión/desconexión:

1. Abre **System Settings** → **Notifications**
2. Busca **Script Editor**
3. Cambia el estilo de notificación a **Alerts**

## Verificación

```bash
# Verificar que el daemon está cargado
sudo launchctl list | grep vpnmonitor

# Ver logs del monitor
cat /tmp/vpn-monitor.log

# Probar manualmente el fix (con sudo)
sudo ~/fix-vpn-disconnect.sh
```

## Desinstalación

```bash
cd openvpn-mac-fix
chmod +x uninstall.sh
./uninstall.sh
```

O manualmente:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.vpnmonitor.plist
sudo rm /Library/LaunchDaemons/com.vpnmonitor.plist
rm ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

## Troubleshooting

### El monitor no se activa
```bash
# Verificar que el daemon está cargado
sudo launchctl list | grep vpnmonitor

# Si no aparece, recargarlo
sudo launchctl load /Library/LaunchDaemons/com.vpnmonitor.plist
```

### No recibo notificaciones
- Verifica que **Script Editor** tiene notificaciones tipo **Alerts** en System Settings
- Verifica los logs: `cat /tmp/vpn-monitor.log`

### Internet sigue sin funcionar después del fix
```bash
# Ejecutar manualmente con logs
sudo ~/fix-vpn-disconnect.sh

# Verificar rutas de red
netstat -rn | head -20

# Verificar DNS
scutil --dns | head -20
```

### Permisos
Si ves errores de permisos, asegúrate de que los scripts son ejecutables:
```bash
chmod +x ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh
```

## Licencia

MIT
