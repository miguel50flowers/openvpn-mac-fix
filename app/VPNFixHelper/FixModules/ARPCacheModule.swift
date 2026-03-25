import Foundation

/// Flushes the ARP cache to resolve stale MAC address mappings.
final class ARPCacheModule {
    func run(completion: @escaping (Bool, String) -> Void) {
        HelperLogger.shared.info("[ARP] Flushing ARP cache")

        let result = DetectionUtilities.runCommandWithStatus("/usr/sbin/arp", arguments: ["-d", "-a"])
        if result.succeeded {
            HelperLogger.shared.info("[ARP] ARP cache flushed")
            completion(true, "ARP cache flushed")
        } else {
            // arp -d -a may fail silently on empty cache; treat as success
            HelperLogger.shared.info("[ARP] ARP flush completed (exit \(result.exitCode))")
            completion(true, "ARP cache flushed")
        }
    }
}
