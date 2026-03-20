import Foundation

/// Protocol for app → helper communication (privileged operations).
@objc protocol VPNHelperProtocol {
    /// Returns the current VPN state as a VPNState raw value string.
    func getVPNState(reply: @escaping (String) -> Void)

    /// Runs the VPN fix script. Returns (success, message).
    func runFix(reply: @escaping (Bool, String) -> Void)

    /// Starts monitoring resolv.conf for changes.
    func installWatcher(reply: @escaping (Bool, String) -> Void)

    /// Stops monitoring resolv.conf.
    func uninstallWatcher(reply: @escaping (Bool, String) -> Void)

    /// Returns the helper version string.
    func getVersion(reply: @escaping (String) -> Void)

    /// Removes Phase 1 installation artifacts (old daemon, scripts).
    func removePhase1Artifacts(reply: @escaping (Bool, String) -> Void)
}

/// Protocol for helper → app communication (state updates).
@objc protocol VPNAppProtocol {
    /// Called when VPN state changes.
    func stateChanged(_ state: String)

    /// Called when a fix operation completes.
    func fixCompleted(_ success: Bool, message: String)
}

/// Shared constants for XPC communication.
enum XPCConstants {
    static let machServiceName = "com.miguel50flowers.VPNFix.helper"
    static let helperBundleID = "com.miguel50flowers.VPNFix.helper"
    static let appBundleID = "com.miguel50flowers.VPNFix"
}
