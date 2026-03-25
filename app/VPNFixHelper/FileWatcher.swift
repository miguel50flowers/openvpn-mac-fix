import Foundation

/// Watches resolv.conf for changes using GCD DispatchSource.
/// Replaces the Phase 1 LaunchDaemon WatchPaths mechanism.
final class FileWatcher {
    private let watchPaths = ["/var/run/resolv.conf", "/etc/resolv.conf"]
    private var sources: [DispatchSourceFileSystemObject] = []
    private var retryTimer: DispatchSourceTimer?
    private var debounceWork: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 3.0
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.vpnfix.filewatcher")

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        for path in watchPaths {
            watchFile(at: path)
        }
        HelperLogger.shared.info("[VPNFixHelper] FileWatcher started for: \(watchPaths.joined(separator: ", "))")
    }

    func stop() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        retryTimer?.cancel()
        retryTimer = nil
        debounceWork?.cancel()
        debounceWork = nil
        HelperLogger.shared.info("[VPNFixHelper] FileWatcher stopped")
    }

    // MARK: - Private

    private func watchFile(at path: String) {
        let fd = open(path, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else {
            HelperLogger.shared.info("[VPNFixHelper] Cannot open \(path) for watching, will retry...")
            scheduleRetry(for: path)
            return
        }

        HelperLogger.shared.debug("[VPNFixHelper] Opened file descriptor \(fd) for \(path)")
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data

            var flagNames: [String] = []
            if flags.contains(.write) { flagNames.append("write") }
            if flags.contains(.delete) { flagNames.append("delete") }
            if flags.contains(.rename) { flagNames.append("rename") }
            if flags.contains(.attrib) { flagNames.append("attrib") }
            HelperLogger.shared.debug("[VPNFixHelper] File event on \(path): [\(flagNames.joined(separator: ", "))]")

            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced — re-create the watcher
                HelperLogger.shared.info("[VPNFixHelper] \(path) was replaced, re-watching...")
                source.cancel()
                self.sources.removeAll { $0 === source as AnyObject }

                // Delay before re-watching to let the new file settle
                self.queue.asyncAfter(deadline: .now() + 0.5) {
                    self.watchFile(at: path)
                }
            }

            // Debounce: coalesce rapid resolv.conf changes (e.g. during VPN connection)
            self.debounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.onChange()
            }
            self.debounceWork = work
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: work)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        sources.append(source)
    }

    private func scheduleRetry(for path: String) {
        HelperLogger.shared.debug("[VPNFixHelper] Scheduling retry for \(path) (every 5s)")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        timer.setEventHandler { [weak self] in
            if FileManager.default.fileExists(atPath: path) {
                HelperLogger.shared.debug("[VPNFixHelper] Retry succeeded: \(path) now exists")
                self?.retryTimer?.cancel()
                self?.retryTimer = nil
                self?.watchFile(at: path)
            }
        }
        timer.resume()
        retryTimer = timer
    }
}
