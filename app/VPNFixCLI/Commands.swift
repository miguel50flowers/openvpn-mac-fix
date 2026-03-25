import Foundation

enum Commands {

    static func status(client: CLIXPCClient) {
        let statuses = client.detectAllVPNClients()
        if statuses.isEmpty {
            print("No VPN clients detected.")
            return
        }

        print(String(format: "%-25s %-15s %-10s %s", "CLIENT", "STATE", "RUNNING", "ISSUES"))
        print(String(repeating: "-", count: 70))

        for s in statuses {
            let issues = s.issueCount > 0 ? "\(s.issueCount) issue\(s.issueCount == 1 ? "" : "s")" : "None"
            print(String(format: "%-25s %-15s %-10s %s",
                         (s.clientType.displayName as NSString).utf8String ?? "",
                         (s.connectionState.label as NSString).utf8String ?? "",
                         s.running ? "Yes" : "No",
                         (issues as NSString).utf8String ?? ""))
        }
    }

    static func diagnose(client: CLIXPCClient) {
        guard let diag = client.getNetworkDiagnostics() else {
            fputs("Failed to get network diagnostics.\n", stderr)
            return
        }

        print("Network Diagnostics")
        print(String(repeating: "=", count: 40))
        print("DNS Servers:    \(diag.dnsServers.joined(separator: ", "))")
        print("Gateway:        \(diag.defaultGateway ?? "None")")
        print("Public IP:      \(diag.publicIP ?? "Unknown")")
        print("PF Rules:       \(diag.pfRulesActive ? "Active" : "None")")
        print("Proxy:          \(diag.proxyConfigured ? "Configured" : "None")")
        print("")
        print("Active Interfaces:")
        for iface in diag.activeInterfaces {
            print("  \(iface.name)\t\(iface.address ?? "no address")\t\(iface.isUp ? "UP" : "DOWN")")
        }
    }

    static func fixAll(client: CLIXPCClient) {
        print("Running fixes for all detected issues...")
        let result = client.runFixAll()
        if result.success {
            print("Fix completed successfully.")
        } else {
            print("Fix failed: \(result.message)")
        }
    }

    static func fixClient(_ type: String, client: CLIXPCClient) {
        guard VPNClientType(rawValue: type) != nil else {
            fputs("Unknown VPN client type: \(type)\n", stderr)
            fputs("Use 'vpnfix status' to see detected clients.\n", stderr)
            return
        }

        print("Running fix for \(type)...")
        let result = client.runFixForClient(type)
        if result.success {
            print("Fix completed successfully.")
        } else {
            print("Fix failed: \(result.message)")
        }
    }

    static func version(client: CLIXPCClient) {
        let v = client.getVersion()
        print("vpnfix CLI — helper version \(v)")
    }

    static func help() {
        print("""
        vpnfix — VPN Fix CLI companion

        Usage:
          vpnfix status              Show detected VPN clients and their status
          vpnfix diagnose            Show network diagnostics (DNS, gateway, interfaces)
          vpnfix fix --all           Fix all detected issues across all VPN clients
          vpnfix fix <vpntype>       Fix issues for a specific VPN client
          vpnfix version             Show helper daemon version
          vpnfix help                Show this help message

        The CLI communicates with the VPN Fix helper daemon via XPC.
        The helper must be installed (via the VPN Fix app) for commands to work.
        """)
    }
}
