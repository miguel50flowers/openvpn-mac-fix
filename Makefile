.PHONY: install uninstall status logs test version pkg app dmg clean release

VERSION := $(shell cat VERSION)
XCODE_PROJECT := app/VPNFix.xcodeproj
BUILD_DIR := build

version:
	@cat VERSION

install:
	@chmod +x install.sh
	@./install.sh

uninstall:
	@chmod +x uninstall.sh
	@./uninstall.sh

status:
	@echo "=== LaunchDaemon (Phase 1) ==="
	@sudo launchctl list | grep vpnmonitor || echo "Not loaded"
	@echo ""
	@echo "=== LaunchDaemon (Phase 2) ==="
	@sudo launchctl list | grep VPNFix || echo "Not loaded"
	@echo ""
	@echo "=== Scripts ==="
	@ls -la ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh 2>/dev/null || echo "Not installed"
	@echo ""
	@echo "=== Plist ==="
	@ls -la /Library/LaunchDaemons/com.vpnmonitor.plist 2>/dev/null || echo "Phase 1 not installed"
	@ls -la /Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist 2>/dev/null || echo "Phase 2 not installed"

logs:
	@echo "=== Current log ==="
	@cat /tmp/vpn-monitor.log 2>/dev/null || echo "No logs yet"
	@for f in /tmp/vpn-monitor.log.*; do \
		if [ -f "$$f" ]; then \
			echo ""; \
			echo "=== $$f ==="; \
			cat "$$f"; \
		fi; \
	done 2>/dev/null; true

test:
	@echo "Running fix manually..."
	@sudo ~/fix-vpn-disconnect.sh

pkg:
	@chmod +x build-pkg.sh
	@./build-pkg.sh

app:
	@echo "=== Building VPN Fix.app v$(VERSION) ==="
	xcodebuild build \
		-project "$(XCODE_PROJECT)" \
		-scheme VPNFix \
		-configuration Release \
		-derivedDataPath "$(BUILD_DIR)/DerivedData" \
		MARKETING_VERSION="$(VERSION)" \
		CURRENT_PROJECT_VERSION="$$(git rev-list --count HEAD)" \
		ARCHS="arm64 x86_64" \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGN_STYLE=Manual
	@echo ""
	@echo "=== Build complete ==="
	@echo "App: $(BUILD_DIR)/DerivedData/Build/Products/Release/VPN Fix.app"

dmg: app
	@echo "=== Building DMG ==="
	@chmod +x build-dmg.sh
	./build-dmg.sh --app-path "$(BUILD_DIR)/DerivedData/Build/Products/Release/VPN Fix.app"

release:
ifndef v
	$(error Usage: make release v=2.0.0)
endif
	@echo "=== Release v$(v) ==="
	@echo "$(v)" > VERSION
	@sed -i '' 's|openvpn-mac-fix-[0-9]*\.[0-9]*\.[0-9]*\.pkg|openvpn-mac-fix-$(v).pkg|g' README.md
	@sed -i '' 's|/tags/v[0-9]*\.[0-9]*\.[0-9]*\.tar\.gz|/tags/v$(v).tar.gz|g' Formula/openvpn-mac-fix.rb
	@sed -i '' 's|<title>Version [0-9]*\.[0-9]*\.[0-9]*</title>|<title>Version $(v)</title>|g' appcast.xml
	@sed -i '' 's|<sparkle:shortVersionString>[0-9]*\.[0-9]*\.[0-9]*</sparkle:shortVersionString>|<sparkle:shortVersionString>$(v)</sparkle:shortVersionString>|g' appcast.xml
	@sed -i '' 's|/v[0-9]*\.[0-9]*\.[0-9]*/VPNFix-[0-9]*\.[0-9]*\.[0-9]*\.dmg|/v$(v)/VPNFix-$(v).dmg|g' appcast.xml
	@sed -i '' 's|<sparkle:version>[^<]*</sparkle:version>|<sparkle:version>__BUILD_NUMBER__</sparkle:version>|g' appcast.xml
	@sed -i '' 's|sparkle:edSignature="[^"]*"|sparkle:edSignature="__ED_SIGNATURE__"|g' appcast.xml
	@sed -i '' 's|length="[^"]*"|length="__DMG_LENGTH__"|g' appcast.xml
	@echo "Version updated to $(v)"
	@echo ""
	@git add VERSION README.md Formula/openvpn-mac-fix.rb appcast.xml
	@git diff --cached --quiet || git commit -m "Bump version to $(v)"
	@git tag "v$(v)"
	@echo ""
	@echo "Pushing to origin..."
	@git push origin main --tags
	@echo ""
	@echo "=== Release v$(v) pushed — CI workflow triggered ==="

clean:
	rm -rf $(BUILD_DIR)/DerivedData
	rm -rf $(BUILD_DIR)/dmg
	rm -f $(BUILD_DIR)/VPNFix-*.dmg
