import Foundation

/// Typed result for fix operations, replacing raw (Bool, String) tuples.
enum FixResult: Sendable {
    case success(message: String)
    case failure(message: String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .success(let msg), .failure(let msg): return msg
        }
    }

    init(success: Bool, message: String) {
        self = success ? .success(message: message) : .failure(message: message)
    }
}

/// Errors that can occur during XPC communication.
enum XPCError: Error, Sendable {
    case connectionFailed
    case decodingFailed(String)
    case helperError(String)
}
