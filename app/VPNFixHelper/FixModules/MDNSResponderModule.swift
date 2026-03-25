import Foundation

/// Full mDNSResponder restart — fixes Bonjour, AirDrop, and .local resolution issues.
final class MDNSResponderModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[mDNS] Restarting mDNSResponder")

        let result = DetectionUtilities.runCommandWithStatus("/usr/bin/killall", arguments: ["mDNSResponder"])
        if result.succeeded || result.exitCode == 1 { // exit 1 = no matching process (already dead)
            HelperLogger.shared.info("[mDNS] mDNSResponder restarted (launchd will respawn)")
            completion(true, "mDNSResponder restarted")
        } else {
            HelperLogger.shared.error("[mDNS] Failed to restart mDNSResponder (exit \(result.exitCode))")
            completion(false, "Failed to restart mDNSResponder")
        }
    }
}
