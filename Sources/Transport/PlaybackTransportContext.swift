import Foundation

final class PlaybackTransportContext: @unchecked Sendable {
    let session: UnifiedMediaTransportSession

    private let lock = NSLock()
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        session = UnifiedMediaTransportSession(source: source, configuration: configuration)
    }

    func quiesceConsumers() async { await session.quiesceConsumers() }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        lock.unlock()
        Task { [session] in await session.stop() }
    }
}
