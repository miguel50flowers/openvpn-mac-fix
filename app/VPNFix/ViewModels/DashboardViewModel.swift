import SwiftUI

/// Drives the Dashboard window — manages multi-VPN client state and diagnostics.
final class DashboardViewModel: ObservableObject {
    @Published var clients: [VPNClientStatus] = []
    @Published var diagnostics: NetworkDiagnostics?
    @Published var isScanning: Bool = false
    @Published var isFixingAll: Bool = false
    @Published var fixingClients: Set<String> = [] // VPNClientType rawValues
    @Published var lastScanTime: Date?

    private let xpcClient = XPCClient.shared
    private var scanTimer: Timer?

    init() {
        AppLogger.shared.debug("DashboardViewModel initialized")
        setupXPCCallbacks()
        scan()
        startPeriodicScan()
    }

    deinit {
        scanTimer?.invalidate()
    }

    // MARK: - Public

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        AppLogger.shared.debug("Dashboard: starting scan")

        xpcClient.detectAllVPNClients { [weak self] json in
            DispatchQueue.main.async {
                self?.parseClients(json)
                self?.isScanning = false
                self?.lastScanTime = Date()
            }
        }

        xpcClient.getNetworkDiagnostics { [weak self] json in
            DispatchQueue.main.async {
                self?.parseDiagnostics(json)
            }
        }
    }

    func fixClient(_ type: VPNClientType) {
        guard !fixingClients.contains(type.rawValue) else { return }
        fixingClients.insert(type.rawValue)
        AppLogger.shared.info("Dashboard: fixing \(type.displayName)")

        xpcClient.runFixForClient(type.rawValue) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.fixingClients.remove(type.rawValue)
                AppLogger.shared.info("Dashboard: fix \(type.displayName) result: \(success), \(message)")
                if success {
                    NotificationService.shared.postFixApplied(client: type.displayName, message: message)
                }
                self?.scan()
            }
        }
    }

    func fixAll() {
        guard !isFixingAll else { return }
        isFixingAll = true
        AppLogger.shared.info("Dashboard: fixing all")

        xpcClient.runFixAll { [weak self] success, message in
            DispatchQueue.main.async {
                self?.isFixingAll = false
                AppLogger.shared.info("Dashboard: fix all result: \(success), \(message)")

                let fixedCount = self?.clients.filter { $0.hasIssues }.count ?? 0
                NotificationService.shared.postFixAllCompleted(
                    fixedCount: success ? fixedCount : 0,
                    failedCount: success ? 0 : fixedCount
                )
                self?.scan()
            }
        }
    }

    // MARK: - Private

    private func setupXPCCallbacks() {
        xpcClient.onClientsChanged = { [weak self] json in
            DispatchQueue.main.async {
                self?.parseClients(json)
            }
        }
    }

    private func startPeriodicScan() {
        let interval = TimeInterval(AppPreferences.shared.scanInterval)
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    private func parseClients(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        do {
            clients = try JSONDecoder().decode([VPNClientStatus].self, from: data)
        } catch {
            AppLogger.shared.error("Dashboard: failed to decode clients: \(error.localizedDescription)")
        }
    }

    private func parseDiagnostics(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        do {
            diagnostics = try JSONDecoder().decode(NetworkDiagnostics.self, from: data)
        } catch {
            AppLogger.shared.error("Dashboard: failed to decode diagnostics: \(error.localizedDescription)")
        }
    }

    var totalIssueCount: Int {
        clients.reduce(0) { $0 + $1.issueCount }
    }

    var activeVPNCount: Int {
        clients.filter { $0.connectionState == .connected }.count
    }

    var overallHealth: OverallHealth {
        if totalIssueCount > 0 { return .issues }
        if activeVPNCount > 0 { return .vpnActive }
        return .healthy
    }

    enum OverallHealth {
        case healthy, vpnActive, issues

        var color: Color {
            switch self {
            case .healthy: return .green
            case .vpnActive: return .blue
            case .issues: return .red
            }
        }

        var label: String {
            switch self {
            case .healthy: return "Network Healthy"
            case .vpnActive: return "VPN Active"
            case .issues: return "Issues Detected"
            }
        }

        var sfSymbol: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .vpnActive: return "shield.lefthalf.filled"
            case .issues: return "exclamationmark.triangle.fill"
            }
        }
    }
}
