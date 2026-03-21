import Foundation

/// Pushes state changes from the helper to the app via the XPC reverse channel.
final class StateNotifier {
    private let connection: NSXPCConnection
    private let vpnDetector: VPNDetector

    init(connection: NSXPCConnection, vpnDetector: VPNDetector) {
        self.connection = connection
        self.vpnDetector = vpnDetector
    }

    func notifyStateChange() {
        let state = vpnDetector.currentState()
        HelperLogger.shared.debug("[StateNotifier] Pushing state to app: \(state.rawValue)")
        let proxy = connection.remoteObjectProxy as? VPNAppProtocol
        proxy?.stateChanged(state.rawValue)
    }

    func notifyClientsChanged() {
        let statuses = vpnDetector.detectAll()
        do {
            let data = try JSONEncoder().encode(statuses)
            let json = String(data: data, encoding: .utf8) ?? "[]"
            let proxy = connection.remoteObjectProxy as? VPNAppProtocol
            proxy?.vpnClientsChanged(json)
        } catch {
            HelperLogger.shared.error("[StateNotifier] Failed to push client statuses: \(error.localizedDescription)")
        }
    }
}
