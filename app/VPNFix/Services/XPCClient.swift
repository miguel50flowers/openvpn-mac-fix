import Foundation

/// Manages XPC connection to the privileged helper daemon.
final class XPCClient {
    static let shared = XPCClient()

    var onStateChanged: ((String) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    private var connection: NSXPCConnection?
    private let queue = DispatchQueue(label: "com.vpnfix.xpc-client")

    private init() {}

    // MARK: - Public API

    func getVPNState(reply: @escaping (String) -> Void) {
        AppLogger.shared.debug("XPC: getVPNState requested")
        proxy { helper in
            helper.getVPNState(reply: reply)
        } errorHandler: {
            reply(VPNState.unknown.rawValue)
        }
    }

    func runFix(reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: runFix requested")
        proxy { helper in
            helper.runFix(reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func installWatcher(reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: installWatcher requested")
        proxy { helper in
            helper.installWatcher(reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func uninstallWatcher(reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: uninstallWatcher requested")
        proxy { helper in
            helper.uninstallWatcher(reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func getVersion(reply: @escaping (String) -> Void) {
        AppLogger.shared.debug("XPC: getVersion requested")
        proxy { helper in
            helper.getVersion(reply: reply)
        } errorHandler: {
            reply("Unknown")
        }
    }

    func removePhase1Artifacts(reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: removePhase1Artifacts requested")
        proxy { helper in
            helper.removePhase1Artifacts(reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func ensureLogFilePermissions(reply: @escaping (Bool) -> Void) {
        AppLogger.shared.debug("XPC: ensureLogFilePermissions requested")
        proxy { helper in
            helper.ensureLogFilePermissions(reply: reply)
        } errorHandler: {
            reply(false)
        }
    }

    // MARK: - Connection Management

    private func proxy(work: @escaping (VPNHelperProtocol) -> Void, errorHandler: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let conn = self.getOrCreateConnection()
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                AppLogger.shared.error("XPC proxy error: \(error.localizedDescription)")
                self.onConnectionStateChanged?(false)
                errorHandler()
            }
            guard let helper = proxy as? VPNHelperProtocol else {
                AppLogger.shared.error("XPC: failed to obtain helper proxy")
                errorHandler()
                return
            }
            work(helper)
        }
    }

    private func getOrCreateConnection() -> NSXPCConnection {
        if let existing = connection {
            AppLogger.shared.debug("XPC: reusing existing connection")
            return existing
        }

        AppLogger.shared.debug("XPC: creating new connection to \(XPCConstants.machServiceName)")
        let conn = NSXPCConnection(machServiceName: XPCConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: VPNHelperProtocol.self)

        // Set up the app's exported interface so the helper can push state changes
        conn.exportedInterface = NSXPCInterface(with: VPNAppProtocol.self)
        conn.exportedObject = XPCAppHandler(client: self)

        conn.interruptionHandler = { [weak self] in
            AppLogger.shared.warn("XPC connection interrupted")
            self?.onConnectionStateChanged?(false)
        }

        conn.invalidationHandler = { [weak self] in
            AppLogger.shared.warn("XPC connection invalidated")
            self?.connection = nil
            self?.onConnectionStateChanged?(false)
        }

        conn.resume()
        connection = conn
        AppLogger.shared.debug("XPC: connection created and resumed")
        onConnectionStateChanged?(true)
        return conn
    }
}

// MARK: - App-side XPC handler (receives push from helper)

private final class XPCAppHandler: NSObject, VPNAppProtocol {
    weak var client: XPCClient?

    init(client: XPCClient) {
        self.client = client
    }

    func stateChanged(_ state: String) {
        AppLogger.shared.debug("XPC: received state push from helper: \(state)")
        client?.onStateChanged?(state)
    }

    func fixCompleted(_ success: Bool, message: String) {
        AppLogger.shared.info("Fix completed: success=\(success), message=\(message)")
    }
}
