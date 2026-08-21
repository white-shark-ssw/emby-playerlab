from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing strict-trace anchor in {path}: {old[:220]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    i = text.find(start)
    j = text.find(end, i + len(start)) if i >= 0 else -1
    if i < 0 or j < 0:
        raise SystemExit(f"missing strict-trace block in {path}: {start!r} -> {end!r}")
    p.write_text(text[:i] + replacement + text[j:])


# Version only; no Seek behavior changes.
identity = Path("Sources/Core/AppIdentity.swift")
text = identity.read_text().replace('sourceVersion = "0.13.55"', 'sourceVersion = "0.13.56"').replace('?? "0.13.55"', '?? "0.13.56"')
identity.write_text(text)

# Lock-protected starvation truth is readable by UI without polling the transport actor.
context_path = "Sources/Transport/PlaybackTransportContext.swift"
Path(context_path).write_text('''import Foundation

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
''')

transport_path = "Sources/Transport/UnifiedMediaTransportSession.swift"
replace_once(
    transport_path,
    '''    private struct PlaybackDemandSample {
        let date: Date
        let offset: Int64
    }
''',
    '''    private struct PlaybackDemandSample {
        let date: Date
        let offset: Int64
    }

    private struct SeekTraceContext {
        let serial: Int
        let target: Double
        let startedAt: Date
    }
''',
)
replace_once(
    transport_path,
    '''    private let client = RangeHTTPClient(maximumConnections: 2)
    private let blockBytes: Int64
''',
    '''    private let client = RangeHTTPClient(maximumConnections: 2)
    private let starvationState: PlaybackTransportStarvationState
    private let blockBytes: Int64
''',
)
replace_once(
    transport_path,
    '''    private var pendingUserSeekUntil = Date.distantPast
    private var pendingUserSeekPosition: Double?
    private var pendingUserSeekDuration: Double?
''',
    '''    private var pendingUserSeekUntil = Date.distantPast
    private var pendingUserSeekPosition: Double?
    private var pendingUserSeekDuration: Double?
    private var seekTraceSerial = 0
    private var seekTraceReadSerial = 0
    private var activeSeekTrace: SeekTraceContext?
    private let seekTraceRetentionSeconds: TimeInterval = 5
''',
)
replace_once(
    transport_path,
    '''    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 64 * 1_048_576)
    }
''',
    '''    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration, starvationState: PlaybackTransportStarvationState = PlaybackTransportStarvationState()) {
        self.source = source
        self.configuration = configuration
        self.starvationState = starvationState
        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 64 * 1_048_576)
    }
''',
)

replace_between(
    transport_path,
    "    func read(offset: Int64, length: Int) async throws -> Data {\n",
    "\n    func prioritizeSeek(position: Double, duration: Double) async {\n",
    '''    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resolved = try await resolve()
        guard offset >= 0, offset < resolved.contentLength, let store else { return Data() }

        let readStartedAt = Date()
        let trace: SeekTraceContext? = {
            guard let activeSeekTrace, readStartedAt.timeIntervalSince(activeSeekTrace.startedAt) <= seekTraceRetentionSeconds else { return nil }
            return activeSeekTrace
        }()
        let traceReadID: Int?
        if trace != nil {
            seekTraceReadSerial += 1
            traceReadID = seekTraceReadSerial
        } else {
            traceReadID = nil
        }

        let requested = min(length, Int(resolved.contentLength - offset))
        let concreteRange = offset..<min(resolved.contentLength, offset + Int64(requested))
        let concreteTailMetadata = isConcreteTailMetadataRead(concreteRange, resource: resolved)
        if concreteTailMetadata {
            DiagnosticsLogger.shared.playback("UnifiedMetadata", "concrete-tail range=\(concreteRange.lowerBound)-\(concreteRange.upperBound) bytes=\(concreteRange.count) center=\(cacheWindowCenter) pendingSeek=\(Date() <= pendingUserSeekUntil) action=metadata-no-anchor")
        }
        acceptRealDemand(concreteRange, resource: resolved, reason: concreteTailMetadata ? "concrete-tail-metadata" : "concrete-read")
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        let cacheClass = available >= Int64(requested) ? "full" : (available > 0 ? "partial" : "miss")
        if let trace, let traceReadID {
            let ageMs = readStartedAt.timeIntervalSince(trace.startedAt) * 1_000
            DiagnosticsLogger.shared.playback("SeekTransportRead", "phase=begin trace=\(trace.serial) read=\(traceReadID) target=\(String(format: "%.3f", trace.target)) range=\(concreteRange.lowerBound)-\(concreteRange.upperBound) requested=\(requested) available=\(available) cache=\(cacheClass) metadata=\(concreteTailMetadata) ageMs=\(String(format: "%.1f", ageMs))")
        }

        let blockedRead = available == 0
        if blockedRead { starvationState.beginBlockedRead() }
        defer { if blockedRead { starvationState.endBlockedRead() } }

        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }

        if available == 0 {
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let metadata = concreteTailMetadata || isMetadataProbe(probe, resource: resolved)
            let preferredLength = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            acceptRealDemand(offset..<demandEnd, resource: resolved, reason: metadata ? "blocked-tail-metadata" : "blocked-read")
        }

        do {
            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            refreshMetrics(resource: resolved)
            if let trace, let traceReadID {
                DiagnosticsLogger.shared.playback("SeekTransportRead", "phase=end trace=\(trace.serial) read=\(traceReadID) target=\(String(format: "%.3f", trace.target)) cache=\(cacheClass) blocked=\(blockedRead) returned=\(data.count) waitMs=\(String(format: "%.1f", Date().timeIntervalSince(readStartedAt) * 1_000))")
            }
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let metadata = concreteTailMetadata || isMetadataProbe(probe, resource: resolved)
            let preferredLength = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            DiagnosticsLogger.shared.playback("UnifiedDemand", "timeout offset=\(offset) length=\(requested) metadata=\(metadata); force slot0")
            installUrgent(range: offset..<demandEnd, metadata: metadata, reason: metadata ? "metadata-read-timeout" : "read-timeout")
            scheduleSlots(reason: "read-timeout")
            let retryData = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)
            if let trace, let traceReadID {
                DiagnosticsLogger.shared.playback("SeekTransportRead", "phase=retry-end trace=\(trace.serial) read=\(traceReadID) target=\(String(format: "%.3f", trace.target)) cache=\(cacheClass) blocked=\(blockedRead) returned=\(retryData.count) waitMs=\(String(format: "%.1f", Date().timeIntervalSince(readStartedAt) * 1_000))")
            }
            return retryData
        }
    }
''',
)
replace_once(
    transport_path,
    '''    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped else { return }
        pendingUserSeekUntil = Date().addingTimeInterval(4)
        pendingUserSeekPosition = max(0, position)
        pendingUserSeekDuration = max(0, duration)
        demandCoordinator.reset()
        DiagnosticsLogger.shared.playback(
            "UnifiedAnchor",
            "user-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) byteGuess=disabled awaitingRealDemand=true anchor=\(playbackAnchor)"
        )
    }
''',
    '''    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped else { return }
        let now = Date()
        seekTraceSerial += 1
        seekTraceReadSerial = 0
        activeSeekTrace = SeekTraceContext(serial: seekTraceSerial, target: max(0, position), startedAt: now)
        pendingUserSeekUntil = now.addingTimeInterval(4)
        pendingUserSeekPosition = max(0, position)
        pendingUserSeekDuration = max(0, duration)
        demandCoordinator.reset()
        DiagnosticsLogger.shared.playback("SeekTransportTrace", "phase=actor-enter trace=\(seekTraceSerial) target=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) anchor=\(playbackAnchor)")
        DiagnosticsLogger.shared.playback(
            "UnifiedAnchor",
            "user-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) byteGuess=disabled awaitingRealDemand=true anchor=\(playbackAnchor)"
        )
    }
''',
)
replace_once(
    transport_path,
    '''        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        client.invalidate()
''',
    '''        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        starvationState.reset()
        activeSeekTrace = nil
        client.invalidate()
''',
)

# Measure the existing transport hint await without changing ordering or Seek flags.
engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(
    engine_path,
    '''        if let session = sharedTransportSession {
            DiagnosticsLogger.shared.playback("MDKSeekHTTP", "id=\(intent.id) action=preserve-existing-stream-before-native-seek")
            Task { @MainActor [weak self, weak player] in
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
                guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }
''',
    '''        if let session = sharedTransportSession {
            DiagnosticsLogger.shared.playback("MDKSeekHTTP", "id=\(intent.id) action=preserve-existing-stream-before-native-seek")
            Task { @MainActor [weak self, weak player] in
                let priorityStartedAt = Date().timeIntervalSince1970
                DiagnosticsLogger.shared.playback("MDKSeekTransportGate", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=begin")
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
                let priorityMs = (Date().timeIntervalSince1970 - priorityStartedAt) * 1_000
                DiagnosticsLogger.shared.playback("MDKSeekTransportGate", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=end waitMs=\(String(format: "%.1f", priorityMs))")
                guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }
''',
)

controller_path = "Sources/Player/PlayerController.swift"
replace_once(
    controller_path,
    '''    @Published private(set) var bufferState = PlaybackBufferState()

    @Published private(set) var source: ResolvedPlaybackSource
''',
    '''    @Published private(set) var bufferState = PlaybackBufferState()
    @Published private(set) var networkBufferingVisible = false

    @Published private(set) var source: ResolvedPlaybackSource
''',
)
replace_once(
    controller_path,
    '''        transportCacheRanges = []
        bufferState = PlaybackBufferState()
        engineSwitchTask?.cancel()
''',
    '''        transportCacheRanges = []
        bufferState = PlaybackBufferState()
        networkBufferingVisible = false
        engineSwitchTask?.cancel()
''',
)
replace_once(
    controller_path,
    '''                let wasEnd = self.snapshot.didReachEnd
                self.snapshot = value
                self.prematureEOFRecovery.observe(snapshot: value)
''',
    '''                let wasEnd = self.snapshot.didReachEnd
                self.snapshot = value
                self.networkBufferingVisible = value.isBuffering && (self.transportContext?.starvationState.isStarving ?? false)
                self.prematureEOFRecovery.observe(snapshot: value)
''',
)
replace_once(
    controller_path,
    '''        transportSummary = nil
        startupFallbackTask?.cancel()
''',
    '''        transportSummary = nil
        networkBufferingVisible = false
        startupFallbackTask?.cancel()
''',
)

screen_path = "Sources/UI/PlayerScreen.swift"
replace_once(screen_path, '                if let feedback = controller.seekFeedback { feedbackView(feedback).scaleEffect(0.55) }\n', '')
replace_once(
    screen_path,
    '''                controls
                centerPlaybackControls

                if controller.snapshot.isBuffering { bufferingIndicator }
''',
    '''                controls
                centerPlaybackControls

                if let feedback = controller.seekFeedback {
                    VStack {
                        Spacer()
                        feedbackView(feedback).scaleEffect(0.55).padding(.bottom, 96)
                    }
                    .allowsHitTesting(false)
                    .zIndex(12)
                }

                if controller.networkBufferingVisible { bufferingIndicator }
''',
)
replace_once(screen_path, '            while !Task.isCancelled && controller.snapshot.isBuffering {\n', '            while !Task.isCancelled && controller.networkBufferingVisible {\n')

# Freeze the clarified buffering semantics in project documentation.
contract_path = "docs/architecture/PLAYBACK_UI_CONTRACT.md"
contract = Path(contract_path).read_text()
start = contract.index("## Buffering download indicator")
end = contract.index("## Volume tick haptic")
contract = contract[:start] + '''## Buffering download indicator

The center buffering/download-speed indicator represents real network starvation, not the playback engine's internal buffering state by itself.

The normal rule is:

- Engine `isBuffering` is necessary but not sufficient.
- `PlaybackTransportStarvationState` must also report an active concrete blocked byte read.
- Only `engine buffering && transport starvation` may show the buffering/download-speed popup.
- MDK demux, keyframe positioning, decoder flush and A/V resynchronization must not show a network-download popup when required bytes are already locally available.
- MDK user Seek may still hide raw internal buffering during the first 500ms as flicker suppression, but the 500ms window is not the truth classifier.
- A blocked UnifiedTransport read starts starvation when zero requested bytes are locally available and ends starvation as soon as that read is satisfied or exits.

Startup buffering follows the same truth rule: the popup means a concrete transport read is actually waiting for bytes.

''' + contract[end:]
Path(contract_path).write_text(contract)

# Static invariants: diagnostics only, no Seek parameter experiment in Build123.
engine = Path(engine_path).read_text()
transport = Path(transport_path).read_text()
controller = Path(controller_path).read_text()
screen = Path(screen_path).read_text()
context = Path(context_path).read_text()
identity_text = identity.read_text()
assert 'sourceVersion = "0.13.56"' in identity_text
assert 'private let relativeSeekBufferMinMs: Int64 = 50' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'private let normalBufferMinMs: Int64 = 1_000' in engine
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .Default : .FromStart' in engine
assert 'MDKSeekTransportGate' in engine
assert 'SeekTransportRead' in transport
assert 'SeekTransportTrace' in transport
assert 'starvationState.beginBlockedRead()' in transport
assert 'starvationState.endBlockedRead()' in transport
assert 'networkBufferingVisible = value.isBuffering &&' in controller
assert 'if controller.networkBufferingVisible { bufferingIndicator }' in screen
assert 'controller.snapshot.isBuffering { bufferingIndicator }' not in screen
assert 'padding(.bottom, 96)' in screen
assert 'cacheByteRanges: controller.transportCacheRanges' in screen
assert 'PlaybackTransportStarvationState' in context
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path("project.mdklab.yml").read_text()
print("strict seek trace 0.13.56 migration applied")
