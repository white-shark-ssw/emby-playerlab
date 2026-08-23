import Foundation

final class PlaybackClickResolveRegistry: @unchecked Sendable {
    static let shared = PlaybackClickResolveRegistry()

    private struct Entry {
        let createdAt: Date
        let task: Task<TransportResolvedResource, Error>
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval = 10

    private init() {}

    func arm(source: ResolvedPlaybackSource) {
        let key = Self.key(for: source)
        lock.lock()
        purgeExpiredLocked(now: Date())
        if entries[key] != nil {
            lock.unlock()
            return
        }
        let task = Task(priority: .userInitiated) { try await RedirectResolver().resolveNetwork(source: source) }
        entries[key] = Entry(createdAt: Date(), task: task)
        lock.unlock()
        DiagnosticsLogger.shared.playback("StartupFastPath", "click transport resolve armed item=\(source.itemId) range=0-0")
    }

    func task(for source: ResolvedPlaybackSource) -> Task<TransportResolvedResource, Error>? {
        lock.lock()
        defer { lock.unlock() }
        purgeExpiredLocked(now: Date())
        return entries[Self.key(for: source)]?.task
    }

    func discard(source: ResolvedPlaybackSource) {
        lock.lock()
        entries.removeValue(forKey: Self.key(for: source))
        lock.unlock()
    }

    private func purgeExpiredLocked(now: Date) {
        entries = entries.filter { now.timeIntervalSince($0.value.createdAt) <= ttl }
    }

    private static func key(for source: ResolvedPlaybackSource) -> String {
        "\(source.itemId)|\(source.mediaSource.id)|\(source.url.absoluteString)"
    }
}
