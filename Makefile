.PHONY: install uninstall status logs test

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
	@cat /tmp/vpn-monitor.log 2>/dev/null || echo "No logs yet"

test:
	@echo "Running fix manually..."
	@sudo ~/fix-vpn-disconnect.sh
