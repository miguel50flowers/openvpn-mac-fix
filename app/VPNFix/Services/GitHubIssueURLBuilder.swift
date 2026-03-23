import Foundation

enum GitHubIssueURLBuilder {

    private static let repoURL = "https://github.com/miguel50flowers/openvpn-mac-fix"
    private static let maxURLLength = 7500

    static func feedbackURL(systemInfo: SystemInfo) -> URL {
        let body = """
        <!-- Describe your feedback below -->



        <details>
        <summary>Device Information</summary>

        \(systemInfo.formattedMarkdown())

        </details>
        """

        return buildURL(title: "[Feedback]: ", labels: "feedback", body: body)
    }

    static func bugReportURL(systemInfo: SystemInfo, recentLogs: String) -> URL {
        let body = """
        <!-- Describe the bug below -->



        **Steps to reproduce:**
        1.
        2.
        3.

        <details>
        <summary>Device Information</summary>

        \(systemInfo.formattedMarkdown())

        </details>

        <details>
        <summary>Recent Logs</summary>

        ```
        \(recentLogs)
        ```

        </details>
        """

        return buildURL(title: "[Bug]: ", labels: "bug", body: body)
    }

    // MARK: - Private

    private static func buildURL(title: String, labels: String, body: String) -> URL {
        var components = URLComponents(string: "\(repoURL)/issues/new")!
        let encodedBody = truncateIfNeeded(body)

        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "labels", value: labels),
            URLQueryItem(name: "body", value: encodedBody)
        ]

        return components.url ?? URL(string: repoURL)!
    }

    private static func truncateIfNeeded(_ body: String) -> String {
        // Check if the full body fits within URL limits
        let testComponents = URLComponents(string: "\(repoURL)/issues/new")!
        let encoded = URLQueryItem(name: "body", value: body)
            .value?
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if encoded.count + 200 <= maxURLLength {
            return body
        }

        // Truncate logs section to fit
        let lines = body.components(separatedBy: "\n")
        let logStartMarker = "```"
        var logStartIndex: Int?
        var logEndIndex: Int?

        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == logStartMarker {
                if logStartIndex == nil {
                    logStartIndex = i
                } else {
                    logEndIndex = i
                }
            }
        }

        guard let start = logStartIndex, let end = logEndIndex, end > start + 1 else {
            // No log block found, just truncate the entire body
            let maxChars = maxURLLength / 2
            return String(body.prefix(maxChars)) + "\n\n[Content truncated to fit URL length]"
        }

        // Keep last 15 log lines
        let logLines = Array(lines[(start + 1)..<end])
        let kept = logLines.suffix(15)
        var truncated = Array(lines[0...start])
        truncated.append("[... \(logLines.count - kept.count) earlier lines truncated]")
        truncated.append(contentsOf: kept)
        truncated.append(contentsOf: lines[end...])

        return truncated.joined(separator: "\n")
    }
}
