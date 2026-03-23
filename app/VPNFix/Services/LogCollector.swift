import Foundation

enum LogCollector {

    /// Returns the last `count` log lines from both app and helper logs, merged by timestamp.
    /// Public IP addresses are redacted for privacy.
    static func recentLines(count: Int = 30) -> String {
        var allLines: [(timestamp: String?, raw: String)] = []

        for path in logPaths() {
            guard let data = FileManager.default.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in lines {
                let ts = extractTimestamp(line)
                allLines.append((timestamp: ts, raw: line))
            }
        }

        // Sort by timestamp (entries without timestamp go to the end)
        allLines.sort { a, b in
            guard let ta = a.timestamp, let tb = b.timestamp else {
                return a.timestamp != nil
            }
            return ta < tb
        }

        let recent = allLines.suffix(count)
        let redacted = recent.map { redactPublicIPs($0.raw) }
        return redacted.joined(separator: "\n")
    }

    // MARK: - Private

    private static func logPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Logs/VPNFix/vpn-monitor.log",
            "/var/log/VPNFix/vpn-monitor.log"
        ]
    }

    /// Extract timestamp from log line format: "2026-03-17 10:30:45 [INFO] ..."
    private static func extractTimestamp(_ line: String) -> String? {
        let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    /// Redact public IPv4 addresses, keeping private ranges (10.x, 172.16-31.x, 192.168.x, 127.x).
    private static func redactPublicIPs(_ line: String) -> String {
        let ipPattern = #"\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b"#
        guard let regex = try? NSRegularExpression(pattern: ipPattern) else { return line }

        var result = line
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))

        // Process in reverse so ranges stay valid
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let r1 = Range(match.range(at: 1), in: result) else { continue }
            let octet1 = Int(result[r1]) ?? 0
            let octet2: Int
            if let r2 = Range(match.range(at: 2), in: result) {
                octet2 = Int(result[r2]) ?? 0
            } else {
                octet2 = 0
            }

            let isPrivate =
                octet1 == 10 ||
                octet1 == 127 ||
                (octet1 == 172 && (16...31).contains(octet2)) ||
                (octet1 == 192 && octet2 == 168)

            if !isPrivate {
                result.replaceSubrange(fullRange, with: "[REDACTED]")
            }
        }
        return result
    }
}
