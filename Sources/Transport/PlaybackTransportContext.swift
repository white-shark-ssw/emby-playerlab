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

final class PlaybackTransportSessionRegistry: @unchecked Sendable {
    static let shared = PlaybackTransportSessionRegistry()

    private final class WeakBox {
        weak var session: UnifiedMediaTransportSession?
        init(_ session: UnifiedMediaTransportSession) { self.session = session }
    }

    private let lock = NSLock()
    private var sessions: [String: WeakBox] = [:]

    private init() {}

    func register(itemId: String, session: UnifiedMediaTransportSession) {
        lock.lock(); sessions[itemId] = WeakBox(session); lock.unlock()
    }

    func session(itemId: String) -> UnifiedMediaTransportSession? {
        lock.lock(); defer { lock.unlock() }
        guard let session = sessions[itemId]?.session else { sessions[itemId] = nil; return nil }
        return session
    }

    func unregister(itemId: String, session: UnifiedMediaTransportSession) {
        lock.lock(); defer { lock.unlock() }
        if sessions[itemId]?.session === session { sessions[itemId] = nil }
    }
}

final class PlaybackTransportContext: @unchecked Sendable {
    let session: UnifiedMediaTransportSession
    let starvationState: PlaybackTransportStarvationState

    private let itemId: String
    private let lock = NSLock()
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        itemId = source.itemId
        let starvationState = PlaybackTransportStarvationState()
        self.starvationState = starvationState
        session = UnifiedMediaTransportSession(source: source, configuration: configuration, starvationState: starvationState)
        PlaybackTransportSessionRegistry.shared.register(itemId: itemId, session: session)
        _ = client
    }

    func quiesceConsumers() async { await session.quiesceConsumers() }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        lock.unlock()
        PlaybackTransportSessionRegistry.shared.unregister(itemId: itemId, session: session)
        starvationState.reset()
        Task { [session] in await session.stop() }
    }
}
