#!/bin/bash
# build-pkg.sh — Builds a macOS .pkg installer for openvpn-mac-fix
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(cat "$SCRIPT_DIR/VERSION")
BUILD_DIR="$SCRIPT_DIR/build"
PAYLOAD_DIR="$BUILD_DIR/payload/usr/local/share/openvpn-mac-fix"
SCRIPTS_DIR="$BUILD_DIR/scripts"
PKG_NAME="openvpn-mac-fix-${VERSION}.pkg"

echo "=== Building openvpn-mac-fix v${VERSION} .pkg ==="

# Clean previous pkg artifacts (preserve other build outputs like DMGs)
rm -rf "$BUILD_DIR/payload" "$BUILD_DIR/scripts" "$BUILD_DIR/$PKG_NAME"
mkdir -p "$PAYLOAD_DIR" "$SCRIPTS_DIR"

# Copy scripts into payload, replacing __VERSION__ but leaving user placeholders
for script in vpn-monitor.sh fix-vpn-disconnect.sh; do
    sed -e "s|__VERSION__|${VERSION}|g" \
        "$SCRIPT_DIR/scripts/$script" > "$PAYLOAD_DIR/$script"
    chmod +x "$PAYLOAD_DIR/$script"
done

# Copy plist into payload
cp "$SCRIPT_DIR/scripts/com.vpnmonitor.plist" "$PAYLOAD_DIR/com.vpnmonitor.plist"

# Copy VERSION file
cp "$SCRIPT_DIR/VERSION" "$PAYLOAD_DIR/VERSION"

# Copy pkg scripts (pre/postinstall)
cp "$SCRIPT_DIR/pkg/preinstall" "$SCRIPTS_DIR/preinstall"
cp "$SCRIPT_DIR/pkg/postinstall" "$SCRIPTS_DIR/postinstall"
chmod +x "$SCRIPTS_DIR/preinstall" "$SCRIPTS_DIR/postinstall"

# Build the .pkg
pkgbuild \
    --root "$BUILD_DIR/payload" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.vpnmonitor.pkg" \
    --version "$VERSION" \
    --install-location "/" \
    "$BUILD_DIR/$PKG_NAME"

echo ""
echo "=== Package built successfully ==="
echo "Output: $BUILD_DIR/$PKG_NAME"
echo ""
echo "Install with: sudo installer -pkg $BUILD_DIR/$PKG_NAME -target /"
