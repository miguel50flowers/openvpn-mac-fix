#!/bin/bash
set -euo pipefail

# Build DMG installer for VPN Fix macOS app
# Usage: ./build-dmg.sh [--app-path /path/to/VPN\ Fix.app]

VERSION=$(cat VERSION)
APP_NAME="VPN Fix"
DMG_NAME="VPNFix-${VERSION}"
DMG_DIR="build/dmg"
DMG_OUTPUT="build/${DMG_NAME}.dmg"

# Default app path (from xcodebuild archive export)
APP_PATH="${1:-build/export/${APP_NAME}.app}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== Building DMG for ${APP_NAME} v${VERSION} ==="

# Verify app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at: ${APP_PATH}"
    echo "Build the app first with: make app"
    exit 1
fi

# Verify app version matches VERSION file
APP_VER=$(defaults read "$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")/Contents/Info" CFBundleShortVersionString)
if [ "$APP_VER" != "$VERSION" ]; then
    echo "Error: App version ($APP_VER) does not match VERSION file ($VERSION)"
    echo "Run 'make clean app' or just 'make dmg' (which now invalidates the cache)"
    exit 1
fi

# Clean previous build
rm -rf "$DMG_DIR"
rm -f "$DMG_OUTPUT"
mkdir -p "$DMG_DIR"

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for styled DMG..."

    CREATE_DMG_ARGS=(
        --volname "${APP_NAME}"
        --window-pos 200 120
        --window-size 600 400
        --icon-size 100
        --icon "${APP_NAME}.app" 150 200
        --app-drop-link 450 200
        --hide-extension "${APP_NAME}.app"
    )

    if [ -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ]; then
        CREATE_DMG_ARGS+=(--volicon "${APP_PATH}/Contents/Resources/AppIcon.icns")
    fi

    if [ -f "dmg-assets/background.png" ]; then
        CREATE_DMG_ARGS+=(--background "dmg-assets/background.png")
    fi

    create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_OUTPUT" "$APP_PATH" || {
        EXIT_CODE=$?
        # create-dmg returns 2 when it can't set the icon (non-fatal)
        if [ $EXIT_CODE -ne 2 ]; then
            echo "Error: create-dmg failed (exit $EXIT_CODE)"
            exit 1
        fi
    }
else
    echo "create-dmg not found, using basic hdiutil..."
    echo "  Install create-dmg for a styled DMG: brew install create-dmg"

    # Copy app to staging directory
    cp -R "$APP_PATH" "$DMG_DIR/"

    # Create Applications symlink
    ln -s /Applications "$DMG_DIR/Applications"

    # Create DMG
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_OUTPUT"
fi

# Clean up staging directory
rm -rf "$DMG_DIR"

echo ""
echo "=== DMG created: ${DMG_OUTPUT} ==="
echo "  Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
echo ""
echo "To install:"
echo "  1. Open ${DMG_NAME}.dmg"
echo "  2. Drag 'VPN Fix' to Applications"
echo "  3. Launch from Applications"
echo ""
echo "Note: Without code signing, right-click → Open on first launch."
