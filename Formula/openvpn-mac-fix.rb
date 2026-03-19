class OpenvpnMacFix < Formula
  desc "Automatic fix for internet loss after disconnecting OpenVPN on macOS"
  homepage "https://github.com/miguel50flowers/openvpn-mac-fix"
  url "https://github.com/miguel50flowers/openvpn-mac-fix/archive/refs/tags/v2.0.7.tar.gz"
  sha256 ""
  license "MIT"

  depends_on :macos

  def install
    libexec.install "scripts/vpn-monitor.sh"
    libexec.install "scripts/fix-vpn-disconnect.sh"
    libexec.install "scripts/com.vpnmonitor.plist"
    libexec.install "install.sh"
    libexec.install "uninstall.sh"
    libexec.install "VERSION"
  end

  def caveats
    <<~EOS
      To complete installation, run:
        cd #{libexec} && sudo ./install.sh

      This will install the LaunchDaemon and scripts to your home directory.

      To uninstall:
        cd #{libexec} && sudo ./uninstall.sh
    EOS
  end
end
