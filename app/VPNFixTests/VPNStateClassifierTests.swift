import XCTest

/// Tests for the pure VPN-state classification ported out of `VPNDetector.currentState()`.
/// Uses captured `netstat -rn` fixtures so detection patterns are documented and locked
/// down without needing a live routing table.
final class VPNStateClassifierTests: XCTestCase {

    func testOpenVPNSplitRoutesAreConnected() {
        let netstat = """
        Routing tables

        Internet:
        Destination        Gateway            Flags        Netif Expire
        default            192.168.1.1        UGScg          en0
        0/1                10.8.0.1           UGScg        utun4
        128.0/1            10.8.0.1           UGScg        utun4
        10.8.0.1           10.8.0.5           UH           utun4
        """
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .connected)
    }

    func testCleanRoutingTableWithBenignUtunIsDisconnected() {
        // A system utun (e.g. utun0 for fe80::) must NOT be mistaken for an active VPN.
        let netstat = """
        Routing tables

        Internet:
        Destination        Gateway            Flags        Netif Expire
        default            192.168.1.1        UGScg          en0
        127                127.0.0.1          UCS            lo0
        192.168.1.0/24     link#11            UCS            en0
        fe80::/64          link#15            UCI          utun0
        """
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .disconnected)
    }

    func testPartialOpenVPNRoutesAreNotConnected() {
        // Only 0/1 present (no 128.0/1): the split-tunnel pattern is incomplete.
        let netstat = """
        default            192.168.1.1        UGScg          en0
        0/1                10.8.0.1           UGScg        utun4
        """
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .disconnected)
    }

    func testWireGuardDefaultViaUtunIsConnected() {
        let netstat = "default            10.96.0.1          UGScg        utun3"
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .connected)
    }

    func testPPP0IsConnected() {
        let netstat = "default            10.0.8.1           UGSc         ppp0"
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .connected)
    }

    func testGlobalProtectGpd0IsConnected() {
        let netstat = "default            10.20.0.1          UGSc         gpd0"
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .connected)
    }

    func testIpsecInterfaceIsConnected() {
        let netstat = "default            10.1.2.3           UGSc        ipsec0"
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: netstat), .connected)
    }

    func testEmptyOutputIsDisconnected() {
        XCTAssertEqual(VPNStateClassifier.classify(netstatOutput: ""), .disconnected)
    }
}
