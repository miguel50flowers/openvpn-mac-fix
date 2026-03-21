import SwiftUI

/// Drives the Dashboard window — manages multi-VPN client state and diagnostics.
@MainActor
final class DashboardViewModel: ObservableObject {
    enum ViewState {
        case loading
        case loaded
        case error(String)
        case empty
    }

    @Published var viewState: ViewState = .loading
    @Published var clients: [VPNClientStatus] = []
    @Published var diagnostics: NetworkDiagnostics?
    @Published var isScanning: Bool = false
    @Published var isFixingAll: Bool = false
    @Published var fixingClients: Set<String> = [] // VPNClientType rawValues
    @Published var lastScanTime: Date?
    @Published var showDismissed: Bool = false
    @Published var fixResults: [String: (success: Bool, message: String)] = [:] // keyed by VPNClientType rawValue

    private let xpcClient: XPCClientProtocol
    private let notificationService: NotificationServiceProtocol
    private var scanTimer: Timer?

    init(xpcClient: XPCClientProtocol = XPCClient.shared, notificationService: NotificationServiceProtocol = NotificationService.shared) {
        self.xpcClient = xpcClient
        self.notificationService = notificationService
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

        xpcClient.detectAllVPNClientsTyped { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statuses):
                    self?.clients = statuses
                    self?.viewState = statuses.isEmpty ? .empty : .loaded
                case .failure(let error):
                    AppLogger.shared.error("Dashboard: detection failed: \(error)")
                    if self?.clients.isEmpty == true {
                        self?.viewState = .error("Failed to connect to helper daemon")
                    }
                }
                self?.isScanning = false
                self?.lastScanTime = Date()
            }
        }

        xpcClient.getNetworkDiagnosticsTyped { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let diag) = result {
                    self?.diagnostics = diag
                }
            }
        }
    }

    func fixClient(_ type: VPNClientType) {
        guard !fixingClients.contains(type.rawValue) else { return }
        fixingClients.insert(type.rawValue)
        fixResults.removeValue(forKey: type.rawValue)
        AppLogger.shared.info("Dashboard: fixing \(type.displayName)")

        xpcClient.runFixForClientTyped(type.rawValue) { [weak self] result in
            DispatchQueue.main.async {
                AppLogger.shared.info("Dashboard: fix \(type.displayName) result: \(result.isSuccess), \(result.message)")
                if result.isSuccess {
                    self?.notificationService.postFixApplied(client: type.displayName, message: result.message)
                }
                self?.fixResults[type.rawValue] = (result.isSuccess, result.message)
                // Keep spinner until rescan completes
                self?.scanAfterFix(type)
            }
        }
    }

    private func scanAfterFix(_ fixedType: VPNClientType) {
        isScanning = true
        xpcClient.detectAllVPNClientsTyped { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let statuses) = result {
                    self?.clients = statuses
                }
                self?.fixingClients.remove(fixedType.rawValue)
                self?.isScanning = false
                self?.lastScanTime = Date()
                // Auto-clear fix result after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.fixResults.removeValue(forKey: fixedType.rawValue)
                }
            }
        }
        xpcClient.getNetworkDiagnosticsTyped { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let diag) = result {
                    self?.diagnostics = diag
                }
            }
        }
    }

    func fixAll() {
        guard !isFixingAll else { return }
        isFixingAll = true
        AppLogger.shared.info("Dashboard: fixing all")

        xpcClient.runFixAllTyped { [weak self] result in
            DispatchQueue.main.async {
                self?.isFixingAll = false
                AppLogger.shared.info("Dashboard: fix all result: \(result.isSuccess), \(result.message)")

                let fixedCount = self?.clients.filter { $0.hasIssues }.count ?? 0
                self?.notificationService.postFixAllCompleted(
                    fixedCount: result.isSuccess ? fixedCount : 0,
                    failedCount: result.isSuccess ? 0 : fixedCount
                )
                self?.scan()
            }
        }
    }

    // MARK: - Private

    private func setupXPCCallbacks() {
        xpcClient.onClientsChanged = { [weak self] json in
            guard let data = json.data(using: .utf8),
                  let statuses = try? JSONDecoder().decode([VPNClientStatus].self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                self?.clients = statuses
            }
        }
    }

    private func startPeriodicScan() {
        let interval = TimeInterval(AppPreferences.shared.scanInterval)
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func dismissIssue(type: VPNIssue.IssueType, client: VPNClientType) {
        AppPreferences.shared.dismissIssue(type: type.rawValue, client: client.rawValue)
        objectWillChange.send()
    }

    func undismissAll() {
        AppPreferences.shared.undismissAll()
        objectWillChange.send()
    }

    func activeIssues(for client: VPNClientStatus) -> [VPNIssue] {
        client.detectedIssues.filter { issue in
            !AppPreferences.shared.isIssueDismissed(type: issue.type.rawValue, client: client.clientType.rawValue)
        }
    }

    func dismissedIssueCount(for client: VPNClientStatus) -> Int {
        client.detectedIssues.count - activeIssues(for: client).count
    }

    var hasDismissedIssues: Bool {
        clients.contains { dismissedIssueCount(for: $0) > 0 }
    }

    var totalIssueCount: Int {
        clients.reduce(0) { $0 + activeIssues(for: $1).count }
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
