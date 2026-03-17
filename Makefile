.PHONY: install uninstall status logs test version pkg

version:
	@cat VERSION

install:
	@chmod +x install.sh
	@./install.sh

uninstall:
	@chmod +x uninstall.sh
	@./uninstall.sh

status:
	@echo "=== LaunchDaemon ==="
	@sudo launchctl list | grep vpnmonitor || echo "Not loaded"
	@echo ""
	@echo "=== Scripts ==="
	@ls -la ~/fix-vpn-disconnect.sh ~/vpn-monitor.sh 2>/dev/null || echo "Not installed"
	@echo ""
	@echo "=== Plist ==="
	@ls -la /Library/LaunchDaemons/com.vpnmonitor.plist 2>/dev/null || echo "Not installed"

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
