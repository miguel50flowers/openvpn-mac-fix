import Foundation

/// Protocol for XPC client operations, enabling dependency injection and testability.
protocol XPCClientProtocol: AnyObject {
    var onStateChanged: ((String) -> Void)? { get set }
    var onConnectionStateChanged: ((Bool) -> Void)? { get set }
    var onClientsChanged: ((String) -> Void)? { get set }

    func getVPNState(reply: @escaping (String) -> Void)
    func runFix(reply: @escaping (Bool, String) -> Void)
    func installWatcher(reply: @escaping (Bool, String) -> Void)
    func uninstallWatcher(reply: @escaping (Bool, String) -> Void)
    func getVersion(reply: @escaping (String) -> Void)
    func detectAllVPNClients(reply: @escaping (String) -> Void)
    func runFixForClient(_ clientType: String, reply: @escaping (Bool, String) -> Void)
    func runFixAll(reply: @escaping (Bool, String) -> Void)
    func getNetworkDiagnostics(reply: @escaping (String) -> Void)

    // Typed convenience API
    func detectAllVPNClientsTyped(reply: @escaping (Result<[VPNClientStatus], XPCError>) -> Void)
    func getNetworkDiagnosticsTyped(reply: @escaping (Result<NetworkDiagnostics, XPCError>) -> Void)
    func runFixTyped(reply: @escaping (FixResult) -> Void)
    func runFixForClientTyped(_ clientType: String, reply: @escaping (FixResult) -> Void)
    func runFixAllTyped(reply: @escaping (FixResult) -> Void)
}

/// Protocol for notification delivery, enabling testability.
protocol NotificationServiceProtocol {
    func postVPNConnected()
    func postVPNDisconnected()
    func postFixApplied(message: String)
    func postFixApplied(client: String, message: String)
    func postFixAllCompleted(fixedCount: Int, failedCount: Int)
}
