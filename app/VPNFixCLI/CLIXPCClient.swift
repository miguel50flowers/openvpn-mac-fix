import Foundation

/// Minimal XPC client for the CLI tool — connects to the privileged helper daemon.
final class CLIXPCClient {
    private var connection: NSXPCConnection?

    func connect() {
        let conn = NSXPCConnection(machServiceName: XPCConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: VPNHelperProtocol.self)
        conn.resume()
        connection = conn
    }

    private func proxy() -> VPNHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { error in
            fputs("XPC error: \(error.localizedDescription)\n", stderr)
        } as? VPNHelperProtocol
    }

    func detectAllVPNClients() -> [VPNClientStatus] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [VPNClientStatus] = []

        proxy()?.detectAllVPNClients { json in
            if let data = json.data(using: .utf8),
               let statuses = try? JSONDecoder().decode([VPNClientStatus].self, from: data) {
                result = statuses
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }

    func getNetworkDiagnostics() -> NetworkDiagnostics? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: NetworkDiagnostics?

        proxy()?.getNetworkDiagnostics { json in
            if let data = json.data(using: .utf8) {
                result = try? JSONDecoder().decode(NetworkDiagnostics.self, from: data)
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }

    func runFixAll() -> (success: Bool, message: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var message = ""

        proxy()?.runFixAll { s, m in
            success = s
            message = m
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)
        return (success, message)
    }

    func runFixForClient(_ clientType: String) -> (success: Bool, message: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var message = ""

        proxy()?.runFixForClient(clientType) { s, m in
            success = s
            message = m
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)
        return (success, message)
    }

    func getVersion() -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var version = "Unknown"

        proxy()?.getVersion { v in
            version = v
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 5)
        return version
    }
}
