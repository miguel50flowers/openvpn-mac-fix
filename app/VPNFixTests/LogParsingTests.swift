import XCTest

final class LogParsingTests: XCTestCase {

    // MARK: - Log Line Parsing

    func testParseStandardLogLine() {
        let raw = "2026-03-17 10:30:45 [INFO] VPN connection detected"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.timestamp, "2026-03-17 10:30:45")
        XCTAssertEqual(result.level, "INFO")
        XCTAssertEqual(result.message, "VPN connection detected")
    }

    func testParseDebugLogLine() {
        let raw = "2026-03-17 10:30:45 [DEBUG] [VPNFixHelper] getVPNState requested"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.timestamp, "2026-03-17 10:30:45")
        XCTAssertEqual(result.level, "DEBUG")
        XCTAssertEqual(result.message, "[VPNFixHelper] getVPNState requested")
    }

    func testParseErrorLogLine() {
        let raw = "2026-03-17 10:30:45 [ERROR] Failed to connect: timeout"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.level, "ERROR")
        XCTAssertEqual(result.message, "Failed to connect: timeout")
    }

    func testParseWarnLogLine() {
        let raw = "2026-03-17 10:30:45 [WARN] Helper version mismatch"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.level, "WARN")
    }

    func testParseAppTaggedLogLine() {
        let raw = "2026-03-17 10:30:45 [INFO] [App] Dashboard refreshed"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.level, "INFO")
        XCTAssertEqual(result.message, "[App] Dashboard refreshed")
    }

    func testParseMalformedLine() {
        let raw = "This is not a log line"
        let result = parseLogLine(raw)

        XCTAssertNil(result.timestamp)
        XCTAssertNil(result.level)
        XCTAssertEqual(result.message, raw)
    }

    func testParseEmptyBrackets() {
        let raw = "2026-03-17 10:30:45 [] empty level"
        let result = parseLogLine(raw)

        XCTAssertEqual(result.timestamp, "2026-03-17 10:30:45")
        XCTAssertEqual(result.level, "")
        XCTAssertEqual(result.message, "empty level")
    }

    // MARK: - Level Priority

    func testLevelPriorityOrdering() {
        XCTAssertTrue(levelPriority("DEBUG") < levelPriority("INFO"))
        XCTAssertTrue(levelPriority("INFO") < levelPriority("WARN"))
        XCTAssertTrue(levelPriority("WARN") < levelPriority("ERROR"))
    }

    func testLevelPriorityCaseInsensitive() {
        XCTAssertEqual(levelPriority("debug"), levelPriority("DEBUG"))
        XCTAssertEqual(levelPriority("info"), levelPriority("INFO"))
        XCTAssertEqual(levelPriority("warn"), levelPriority("WARN"))
        XCTAssertEqual(levelPriority("error"), levelPriority("ERROR"))
    }

    func testLevelPriorityWarningAlias() {
        XCTAssertEqual(levelPriority("WARNING"), levelPriority("WARN"))
    }

    func testLevelPriorityUnknown() {
        XCTAssertEqual(levelPriority("UNKNOWN"), 0)
        XCTAssertEqual(levelPriority(""), 0)
    }

    // MARK: - Helpers (extracted from LogViewModel for testability)

    private struct ParsedLogLine {
        let timestamp: String?
        let level: String?
        let message: String
    }

    private func parseLogLine(_ raw: String) -> ParsedLogLine {
        let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+\[([^\]]*)\]\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) else {
            return ParsedLogLine(timestamp: nil, level: nil, message: raw)
        }

        let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
            guard let range = Range(match.range(at: index), in: raw) else { return nil }
            return String(raw[range])
        }

        if groups.count >= 3 {
            return ParsedLogLine(timestamp: groups[0], level: groups[1], message: groups[2])
        }
        return ParsedLogLine(timestamp: nil, level: nil, message: raw)
    }

    private func levelPriority(_ level: String) -> Int {
        switch level.uppercased() {
        case "DEBUG": return 0
        case "INFO":  return 1
        case "WARN", "WARNING": return 2
        case "ERROR": return 3
        default: return 0
        }
    }
}
