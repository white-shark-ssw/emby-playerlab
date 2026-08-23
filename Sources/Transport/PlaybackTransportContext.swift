import Foundation

final class PlaybackTransportStarvationState: @unchecked Sendable {
    private let lock = NSLock()
    private var activeBlockedReads = 0

    var isStarving: Bool {
        lock.lock()
        let value = activeBlockedReads > 0
        lock.unlock()
        return value
    }

    func beginBlockedRead() {
        lock.lock()
        activeBlockedReads += 1
        lock.unlock()
    }

    func endBlockedRead() {
        lock.lock()
        activeBlockedReads = max(0, activeBlockedReads - 1)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        activeBlockedReads = 0
        lock.unlock()
    }
}

final class PlaybackTransportContext: @unchecked Sendable {
    let session: UnifiedMediaTransportSession
    let starvationState: PlaybackTransportStarvationState

    private let lock = NSLock()
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        let starvationState = PlaybackTransportStarvationState()
        self.starvationState = starvationState
        let cacheKey = TransportCacheMaintenance.stableVideoCacheKey(for: source)
        StartupRangeBootstrapCache.shared.arm(cacheKey: cacheKey, maximumBytes: 1 * 1_048_576)
        DiagnosticsLogger.shared.playback("StartupBootstrap", "armed bytes=1048576 item=\(source.itemId)")
        session = UnifiedMediaTransportSession(source: source, configuration: configuration, starvationState: starvationState)
        _ = client
    }

    func quiesceConsumers() async { await session.quiesceConsumers() }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        lock.unlock()
        starvationState.reset()
        Task { [session] in await session.stop() }
    }
}
