cask "vpn-fix" do
  version :latest
  sha256 :no_check

  url "https://github.com/miguel50flowers/openvpn-mac-fix/releases/latest/download/VPNFix-#{version}.dmg"
  name "VPN Fix"
  desc "macOS menu bar app that fixes internet connectivity after OpenVPN disconnects"
  homepage "https://github.com/miguel50flowers/openvpn-mac-fix"

  depends_on macos: ">= :ventura"

  app "VPN Fix.app"

  uninstall launchctl: "com.miguel50flowers.VPNFix.helper",
            quit:      "com.miguel50flowers.VPNFix"

  zap trash: [
    "~/Library/Preferences/com.miguel50flowers.VPNFix.plist",
    "~/Library/Caches/com.miguel50flowers.VPNFix",
    "/Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist",
  ]
end
