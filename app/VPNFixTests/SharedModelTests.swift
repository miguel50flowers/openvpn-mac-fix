import XCTest

final class SharedModelTests: XCTestCase {

    // MARK: - VPNClientType

    func testAllClientTypesHaveDisplayName() {
        for clientType in VPNClientType.allCases {
            XCTAssertFalse(clientType.displayName.isEmpty, "\(clientType) has empty displayName")
        }
    }

    func testAllClientTypesHaveCategory() {
        for clientType in VPNClientType.allCases {
            // Just ensure it doesn't crash
            _ = clientType.category
            _ = clientType.sfSymbol
        }
    }

    func testEnterpriseClientsClassifiedCorrectly() {
        let enterpriseClients: [VPNClientType] = [.ciscoAnyConnect, .globalProtect, .pulseSecure, .zscaler, .fortiClient]
        for client in enterpriseClients {
            XCTAssertEqual(client.category, .enterprise, "\(client) should be enterprise")
        }
    }

    func testConsumerClientsClassifiedCorrectly() {
        let consumerClients: [VPNClientType] = [.openVPN, .wireGuard, .nordVPN, .expressVPN, .surfshark]
        for client in consumerClients {
            XCTAssertEqual(client.category, .consumer, "\(client) should be consumer")
        }
    }

    func testVPNClientTypeCodableRoundTrip() throws {
        for clientType in VPNClientType.allCases {
            let data = try JSONEncoder().encode(clientType)
            let decoded = try JSONDecoder().decode(VPNClientType.self, from: data)
            XCTAssertEqual(decoded, clientType)
        }
    }

    // MARK: - VPNState

    func testVPNStateCodableRoundTrip() throws {
        let states: [VPNState] = [.connected, .disconnected, .fixing, .unknown]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(VPNState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testVPNStateLabelsNotEmpty() {
        let states: [VPNState] = [.connected, .disconnected, .fixing, .unknown]
        for state in states {
            XCTAssertFalse(state.label.isEmpty)
            XCTAssertFalse(state.sfSymbol.isEmpty)
        }
    }

    // MARK: - VPNIssue

    func testVPNIssueCodableRoundTrip() throws {
        let issue = VPNIssue(type: .staleRoutes, severity: .high, description: "Test issue")
        let data = try JSONEncoder().encode(issue)
        let decoded = try JSONDecoder().decode(VPNIssue.self, from: data)

        XCTAssertEqual(decoded.type, issue.type)
        XCTAssertEqual(decoded.severity, issue.severity)
        XCTAssertEqual(decoded.description, issue.description)
        XCTAssertEqual(decoded.id, issue.id)
    }

    func testSeverityOrdering() {
        XCTAssertTrue(VPNIssue.Severity.critical < VPNIssue.Severity.high)
        XCTAssertTrue(VPNIssue.Severity.high < VPNIssue.Severity.medium)
        XCTAssertTrue(VPNIssue.Severity.medium < VPNIssue.Severity.low)
    }

    func testSeveritySorting() {
        let severities: [VPNIssue.Severity] = [.low, .critical, .medium, .high]
        let sorted = severities.sorted()
        XCTAssertEqual(sorted, [.critical, .high, .medium, .low])
    }

    func testAllIssueTypesHaveFixDescription() {
        let types: [VPNIssue.IssueType] = [
            .staleRoutes, .stalePfRules, .dnsLeak,
            .orphanedInterface, .staleProxy, .killSwitchActive, .daemonPersistence
        ]
        for type in types {
            XCTAssertFalse(type.fixDescription.isEmpty, "\(type) has empty fixDescription")
        }
    }

    // MARK: - VPNClientStatus

    func testVPNClientStatusCodableRoundTrip() throws {
        let issue = VPNIssue(type: .dnsLeak, severity: .medium, description: "DNS leak detected")
        let status = VPNClientStatus(
            clientType: .nordVPN,
            installed: true,
            running: true,
            connectionState: .connected,
            detectedIssues: [issue],
            interfaceName: "utun3",
            processName: "NordVPN",
            appPath: "/Applications/NordVPN.app"
        )

        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(VPNClientStatus.self, from: data)

        XCTAssertEqual(decoded.clientType, .nordVPN)
        XCTAssertEqual(decoded.installed, true)
        XCTAssertEqual(decoded.running, true)
        XCTAssertEqual(decoded.connectionState, .connected)
        XCTAssertEqual(decoded.detectedIssues.count, 1)
        XCTAssertEqual(decoded.interfaceName, "utun3")
        XCTAssertEqual(decoded.processName, "NordVPN")
    }

    func testVPNClientStatusId() {
        let status = VPNClientStatus(
            clientType: .wireGuard,
            installed: true,
            running: false,
            connectionState: .disconnected,
            detectedIssues: [],
            interfaceName: nil,
            processName: nil,
            appPath: nil
        )
        XCTAssertEqual(status.id, "wireGuard")
    }

    func testVPNClientStatusHasIssues() {
        let noIssues = VPNClientStatus(
            clientType: .openVPN, installed: true, running: false,
            connectionState: .disconnected, detectedIssues: [],
            interfaceName: nil, processName: nil, appPath: nil
        )
        XCTAssertFalse(noIssues.hasIssues)
        XCTAssertEqual(noIssues.issueCount, 0)
        XCTAssertNil(noIssues.highestSeverity)

        let withIssues = VPNClientStatus(
            clientType: .openVPN, installed: true, running: true,
            connectionState: .connected,
            detectedIssues: [
                VPNIssue(type: .staleRoutes, severity: .medium, description: "test"),
                VPNIssue(type: .dnsLeak, severity: .critical, description: "test"),
            ],
            interfaceName: "utun0", processName: "openvpn", appPath: nil
        )
        XCTAssertTrue(withIssues.hasIssues)
        XCTAssertEqual(withIssues.issueCount, 2)
        XCTAssertEqual(withIssues.highestSeverity, .critical)
    }

    // MARK: - NetworkDiagnostics

    func testNetworkDiagnosticsCodableRoundTrip() throws {
        let diag = NetworkDiagnostics(
            dnsServers: ["8.8.8.8", "1.1.1.1"],
            defaultGateway: "192.168.1.1",
            publicIP: "203.0.113.1",
            activeInterfaces: [
                NetworkInterface(name: "en0", address: "192.168.1.100", isUp: true),
                NetworkInterface(name: "utun0", address: "10.8.0.2", isUp: true),
            ],
            pfRulesActive: false,
            proxyConfigured: false,
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(diag)
        let decoded = try JSONDecoder().decode(NetworkDiagnostics.self, from: data)

        XCTAssertEqual(decoded.dnsServers, ["8.8.8.8", "1.1.1.1"])
        XCTAssertEqual(decoded.defaultGateway, "192.168.1.1")
        XCTAssertEqual(decoded.publicIP, "203.0.113.1")
        XCTAssertEqual(decoded.activeInterfaces.count, 2)
        XCTAssertEqual(decoded.pfRulesActive, false)
    }

    func testNetworkInterfaceIdentifiable() {
        let iface = NetworkInterface(name: "en0", address: "192.168.1.100", isUp: true)
        XCTAssertEqual(iface.id, "en0")
    }

    // MARK: - AggregateVPNState

    func testAggregateVPNStateLabels() {
        XCTAssertEqual(AggregateVPNState.allClear.label, "All Clear")
        XCTAssertEqual(AggregateVPNState.vpnActive(count: 1).label, "1 VPN Active")
        XCTAssertEqual(AggregateVPNState.vpnActive(count: 3).label, "3 VPNs Active")
        XCTAssertEqual(AggregateVPNState.issuesDetected(count: 1).label, "1 Issue Detected")
        XCTAssertEqual(AggregateVPNState.issuesDetected(count: 5).label, "5 Issues Detected")
        XCTAssertEqual(AggregateVPNState.fixing.label, "Fixing...")
        XCTAssertEqual(AggregateVPNState.unknown.label, "Scanning...")
    }

    func testAggregateVPNStateSFSymbols() {
        XCTAssertFalse(AggregateVPNState.allClear.sfSymbol.isEmpty)
        XCTAssertFalse(AggregateVPNState.vpnActive(count: 1).sfSymbol.isEmpty)
        XCTAssertFalse(AggregateVPNState.issuesDetected(count: 1).sfSymbol.isEmpty)
        XCTAssertFalse(AggregateVPNState.fixing.sfSymbol.isEmpty)
        XCTAssertFalse(AggregateVPNState.unknown.sfSymbol.isEmpty)
    }

    // MARK: - Batch JSON Encoding (simulates XPC payload)

    func testBatchVPNClientStatusJsonRoundTrip() throws {
        let statuses = [
            VPNClientStatus(
                clientType: .openVPN, installed: true, running: true,
                connectionState: .connected,
                detectedIssues: [VPNIssue(type: .staleRoutes, severity: .high, description: "stale")],
                interfaceName: "utun0", processName: "openvpn", appPath: nil
            ),
            VPNClientStatus(
                clientType: .nordVPN, installed: true, running: false,
                connectionState: .disconnected, detectedIssues: [],
                interfaceName: nil, processName: nil, appPath: "/Applications/NordVPN.app"
            ),
        ]

        // Simulate XPC: encode to JSON string, decode back
        let data = try JSONEncoder().encode(statuses)
        let jsonString = String(data: data, encoding: .utf8)!
        let backToData = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([VPNClientStatus].self, from: backToData)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].clientType, .openVPN)
        XCTAssertEqual(decoded[1].clientType, .nordVPN)
        XCTAssertEqual(decoded[0].detectedIssues.count, 1)
        XCTAssertEqual(decoded[1].detectedIssues.count, 0)
    }
}
