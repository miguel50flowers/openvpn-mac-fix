import Foundation

/// Entry point for the privileged helper daemon.
/// Runs as root via launchd, listens for XPC connections from the main app.

let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: XPCConstants.machServiceName)
listener.delegate = delegate
listener.resume()

HelperLogger.shared.info("[VPNFixHelper] Helper daemon started, listening on \(XPCConstants.machServiceName)")

// Keep the run loop alive
RunLoop.current.run()
