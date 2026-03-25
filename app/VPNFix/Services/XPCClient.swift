import Foundation

/// Manages XPC connection to the privileged helper daemon.
final class XPCClient: XPCClientProtocol {
    static let shared = XPCClient()

    var onStateChanged: ((String) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    var onClientsChanged: ((String) -> Void)?

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

    // MARK: - Phase 3: Multi-VPN Support

    func detectAllVPNClients(reply: @escaping (String) -> Void) {
        AppLogger.shared.debug("XPC: detectAllVPNClients requested")
        proxy { helper in
            helper.detectAllVPNClients(reply: reply)
        } errorHandler: {
            reply("[]")
        }
    }

    func runFixForClient(_ clientType: String, reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: runFixForClient requested for \(clientType)")
        proxy { helper in
            helper.runFixForClient(clientType, reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func runFixAll(reply: @escaping (Bool, String) -> Void) {
        AppLogger.shared.debug("XPC: runFixAll requested")
        proxy { helper in
            helper.runFixAll(reply: reply)
        } errorHandler: {
            reply(false, "Helper connection failed")
        }
    }

    func getNetworkDiagnostics(reply: @escaping (String) -> Void) {
        AppLogger.shared.debug("XPC: getNetworkDiagnostics requested")
        proxy { helper in
            helper.getNetworkDiagnostics(reply: reply)
        } errorHandler: {
            reply("{}")
        }
    }

    func setCustomVPNEntries(_ json: String, reply: @escaping (Bool) -> Void) {
        AppLogger.shared.debug("XPC: setCustomVPNEntries requested")
        proxy { helper in
            helper.setCustomVPNEntries(json, reply: reply)
        } errorHandler: {
            reply(false)
        }
    }

    // MARK: - Typed Convenience API

    /// Decodes VPN client statuses from JSON, returning a typed Result.
    func detectAllVPNClientsTyped(reply: @escaping (Result<[VPNClientStatus], XPCError>) -> Void) {
        detectAllVPNClients { json in
            guard let data = json.data(using: .utf8) else {
                reply(.failure(.decodingFailed("Invalid UTF-8 in response")))
                return
            }
            do {
                let statuses = try JSONDecoder().decode([VPNClientStatus].self, from: data)
                reply(.success(statuses))
            } catch {
                AppLogger.shared.error("Failed to decode VPN client statuses: \(error)")
                reply(.failure(.decodingFailed(error.localizedDescription)))
            }
        }
    }

    /// Decodes network diagnostics from JSON, returning a typed Result.
    func getNetworkDiagnosticsTyped(reply: @escaping (Result<NetworkDiagnostics, XPCError>) -> Void) {
        getNetworkDiagnostics { json in
            guard let data = json.data(using: .utf8) else {
                reply(.failure(.decodingFailed("Invalid UTF-8 in response")))
                return
            }
            do {
                let diagnostics = try JSONDecoder().decode(NetworkDiagnostics.self, from: data)
                reply(.success(diagnostics))
            } catch {
                AppLogger.shared.error("Failed to decode network diagnostics: \(error)")
                reply(.failure(.decodingFailed(error.localizedDescription)))
            }
        }
    }

    /// Wraps a (Bool, String) fix reply into a typed FixResult.
    func runFixTyped(reply: @escaping (FixResult) -> Void) {
        runFix { success, message in
            reply(FixResult(success: success, message: message))
        }
    }

    /// Wraps a per-client fix reply into a typed FixResult.
    func runFixForClientTyped(_ clientType: String, reply: @escaping (FixResult) -> Void) {
        runFixForClient(clientType) { success, message in
            reply(FixResult(success: success, message: message))
        }
    }

    /// Wraps a fix-all reply into a typed FixResult.
    func runFixAllTyped(reply: @escaping (FixResult) -> Void) {
        runFixAll { success, message in
            reply(FixResult(success: success, message: message))
        }
    }

    // MARK: - Connection Management

    private static let maxRetries = 3
    private static let retryDelays: [TimeInterval] = [1.0, 2.0, 4.0]

    private func proxy(work: @escaping (VPNHelperProtocol) -> Void, errorHandler: @escaping () -> Void) {
        proxyWithRetry(work: work, errorHandler: errorHandler, attempt: 0)
    }

    private func proxyWithRetry(work: @escaping (VPNHelperProtocol) -> Void, errorHandler: @escaping () -> Void, attempt: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            let conn = self.getOrCreateConnection()
            let proxy = conn.remoteObjectProxyWithErrorHandler { [weak self] error in
                AppLogger.shared.error("XPC proxy error (attempt \(attempt + 1)): \(error.localizedDescription)")
                self?.onConnectionStateChanged?(false)

                // Retry with exponential backoff if we haven't exhausted attempts
                if attempt < Self.maxRetries {
                    let delay = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
                    AppLogger.shared.info("XPC: retrying in \(delay)s (attempt \(attempt + 2)/\(Self.maxRetries + 1))...")
                    // Force new connection on retry
                    self?.queue.async { self?.connection = nil }
                    self?.queue.asyncAfter(deadline: .now() + delay) {
                        self?.proxyWithRetry(work: work, errorHandler: errorHandler, attempt: attempt + 1)
                    }
                } else {
                    AppLogger.shared.error("XPC: all \(Self.maxRetries + 1) attempts failed")
                    errorHandler()
                }
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

    func vpnClientsChanged(_ statusesJSON: String) {
        AppLogger.shared.debug("XPC: received clients push from helper")
        client?.onClientsChanged?(statusesJSON)
    }
}
