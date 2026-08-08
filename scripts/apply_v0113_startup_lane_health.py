from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{path}: target not found")
    p.write_text(text.replace(old, new, 1))


def require_count(path: str, needle: str, expected: int) -> None:
    count = Path(path).read_text().count(needle)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} x {needle!r}, got {count}")


unified = "Sources/Transport/UnifiedMediaTransportSession.swift"
http = "Sources/Transport/RangeHTTPClient.swift"
controller = "Sources/Player/PlayerController.swift"

# --- RangeHTTPClient: allow one idle persistent lane to be discarded without touching the peer. ---
replace_once(http,
'''    func stream(resource: TransportResolvedResource, range: Range<Int64>, worker: Int) -> AsyncThrowingStream<Data, Error> {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].makeStream(resource: resource, range: range, lane: .preload(worker: worker))
    }

    private func makeRequest(resource: TransportResolvedResource, range: Range<Int64>) -> URLRequest {
''',
'''    func stream(resource: TransportResolvedResource, range: Range<Int64>, worker: Int) -> AsyncThrowingStream<Data, Error> {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].makeStream(resource: resource, range: range, lane: .preload(worker: worker))
    }

    @discardableResult
    func resetStreamLane(worker: Int, reason: String) -> Bool {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].resetIfIdle(reason: reason)
    }

    private func makeRequest(resource: TransportResolvedResource, range: Range<Int64>) -> URLRequest {
''')

replace_once(http,
'''    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()
''',
'''    private lazy var session: URLSession = makeSession()
''')

replace_once(http,
'''    init(index: Int) {
        self.index = index
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.qualityOfService = .userInitiated
        delegateQueue.name = "com.embyplayerlab.transport-v3.lane-\\(index)"
        super.init()
    }

    func makeStream(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) -> AsyncThrowingStream<Data, Error> {
''',
'''    init(index: Int) {
        self.index = index
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.qualityOfService = .userInitiated
        delegateQueue.name = "com.embyplayerlab.transport-v3.lane-\\(index)"
        super.init()
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }

    func makeStream(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) -> AsyncThrowingStream<Data, Error> {
''')

replace_once(http,
'''    func invalidate() {
        lock.lock()
        guard !invalidated else { lock.unlock(); return }
''',
'''    func resetIfIdle(reason: String) -> Bool {
        lock.lock()
        guard !invalidated, states.isEmpty else { lock.unlock(); return false }
        let previous = session
        session = makeSession()
        lock.unlock()
        previous.invalidateAndCancel()
        DiagnosticsLogger.shared.log("TransportV3Health", "lane=\\(index) action=reset-idle-session reason=\\(reason)")
        return true
    }

    func invalidate() {
        lock.lock()
        guard !invalidated else { lock.unlock(); return }
''')

# --- Unified scheduler: correct startup-tail classification and add conservative lane health. ---
replace_once(unified,
'''    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private var source: ResolvedPlaybackSource
''',
'''    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private struct LaneHealthState {
        var averageBps: Double = 0
        var samples = 0
        var slowStreak = 0
        var lastSampleAt = Date.distantPast
        var resetCooldownUntil = Date.distantPast
    }

    private var source: ResolvedPlaybackSource
''')

replace_once(unified,
'''    private let startupMetadataSlowFirstChunkSeconds: TimeInterval = 1.5
    private let startupMetadataSlowFirstChunkBps: Double = 1 * 1_048_576
    private let lookaheadSegments = 4
''',
'''    private let startupMetadataSlowFirstChunkSeconds: TimeInterval = 1.5
    private let startupMetadataSlowFirstChunkBps: Double = 1 * 1_048_576
    private let laneHealthMinSampleBytes: Int64 = 8 * 1_048_576
    private let laneHealthPeerFloorBps: Double = 4 * 1_048_576
    private let laneHealthRelativeFloor: Double = 0.50
    private let laneHealthPeerFreshSeconds: TimeInterval = 20
    private let laneHealthResetCooldownSeconds: TimeInterval = 25
    private let lookaheadSegments = 4
''')

replace_once(unified,
'''    private var successfulPrimaryBlocks = 0

    private var metricsValue = TransportMetricsSnapshot()
''',
'''    private var successfulPrimaryBlocks = 0
    private var laneHealth: [Int: LaneHealthState] = [0: LaneHealthState(), 1: LaneHealthState()]

    private var metricsValue = TransportMetricsSnapshot()
''')

replace_once(unified,
'''        let concreteReason = reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"
        // Size/distance metadata heuristics are valid only for speculative Range hints. Once the
        // player actually reads an offset it is a real demux dependency; poorly interleaved audio/video
        // tracks can legitimately issue tiny reads hundreds of MiB apart.
        let metadata = concreteReason ? false : isMetadataProbe(range, resource: resource)
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason
        var reanchored = false
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }
''',
'''        let concreteReason = reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"
        // Distant concrete reads are normally real playback dependencies (poorly interleaved A/V),
        // but a large MP4's first near-EOF seek is container metadata. Treating that moov/sample-table
        // read as playback made 152901 cache 100+ MiB from the head while file-loaded waited on a slow
        // ~10 MiB tail request. Limit this override to the startup window so a later user seek near EOF
        // remains ordinary playback demand.
        let startupTailMetadata = isStartupTailMetadata(range, resource: resource)
        let metadata = startupTailMetadata || (!concreteReason && isMetadataProbe(range, resource: resource))
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason && !metadata
        var reanchored = false
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }
        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=primary-lane") }
''')

replace_once(unified,
'''        let foregroundCanUseSlot1 = Date() >= secondaryCooldownUntil && (slotTasks[1] == nil || slotClaims[1]?.role == .sequential)
        if let secondary = slotClaims[1], secondary.role == .sequential {
            cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")
        }
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            if foregroundCanUseSlot1 {
                DiagnosticsLogger.shared.log("UnifiedDemand", "preserve slot0 sequential for foreground request=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata)")
            } else {
                cancelSlot(0, reason: "foreground-needs-second-slot")
            }
        }
''',
'''        let startupCriticalMetadata = metadata && isStartupTailMetadata(candidate, resource: resource)
        if startupCriticalMetadata {
            // Keep the secondary prefetch alive and reuse the already-warmed primary connection for
            // the startup tail index. In the 152901 regression Slot 0 was 16-21 MiB/s while the fresh
            // Slot 1 tail connection averaged ~1.1 MiB/s; file-loaded waited on the latter for 11s.
            if let primary = slotClaims[0], primary.role == .sequential { cancelSlot(0, reason: "startup-metadata-priority") }
            DiagnosticsLogger.shared.log("UnifiedStartup", "critical metadata queued on primary range=\\(candidate.lowerBound)-\\(candidate.upperBound) preserveSecondary=\\(slotClaims[1]?.role == .sequential)")
            return
        }

        let foregroundCanUseSlot1 = Date() >= secondaryCooldownUntil && (slotTasks[1] == nil || slotClaims[1]?.role == .sequential)
        if let secondary = slotClaims[1], secondary.role == .sequential {
            cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")
        }
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            if foregroundCanUseSlot1 {
                DiagnosticsLogger.shared.log("UnifiedDemand", "preserve slot0 sequential for foreground request=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata)")
            } else {
                cancelSlot(0, reason: "foreground-needs-second-slot")
            }
        }
''')

# Collapse the accidental v0.11.2 six-fold urgent/metadata speed accounting to exactly one call.
p = Path(unified)
text = p.read_text()
needle = '''                            recordNetworkBytes(Int64(chunk.count))
                            recordNetworkBytes(Int64(chunk.count))
                            recordNetworkBytes(Int64(chunk.count))
                            recordNetworkBytes(Int64(chunk.count))
                            recordNetworkBytes(Int64(chunk.count))
                            recordNetworkBytes(Int64(chunk.count))
'''
if needle in text:
    text = text.replace(needle, '                            recordNetworkBytes(Int64(chunk.count))\n', 1)
p.write_text(text)

replace_once(unified,
'''                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) finish role=\\(claim.role.rawValue) range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) bytes=\\(receivedForClaim) speedBps=\\(Int(bps)) progressive=true longRange=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil)
''',
'''                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) finish role=\\(claim.role.rawValue) range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) bytes=\\(receivedForClaim) speedBps=\\(Int(bps)) progressive=true longRange=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil, completedSequentialBps: bps)
''')

replace_once(unified,
'''    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\\(slot)")

        if let downloadedBytes, downloadedBytes > 0 {
''',
'''    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?, completedSequentialBps: Double? = nil) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\\(slot)")

        if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if let downloadedBytes, downloadedBytes > 0 {
''')

replace_once(unified,
'''    private func resumeAfterSecondaryCooldown() {
        guard !stopped else { return }
        scheduleSlots(reason: "secondary-cooldown-ended")
    }
''',
'''    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {
        guard bytes >= laneHealthMinSampleBytes, bps > 0 else { return }
        let now = Date()
        let peerSlot = slot == 0 ? 1 : 0
        var current = laneHealth[slot] ?? LaneHealthState()
        let peer = laneHealth[peerSlot] ?? LaneHealthState()
        let peerIsFresh = peer.samples > 0 && now.timeIntervalSince(peer.lastSampleAt) <= laneHealthPeerFreshSeconds
        let clearlyWorse = peerIsFresh && peer.averageBps >= laneHealthPeerFloorBps && bps < peer.averageBps * laneHealthRelativeFloor

        current.averageBps = current.samples == 0 ? bps : current.averageBps * 0.65 + bps * 0.35
        current.samples += 1
        current.lastSampleAt = now
        if clearlyWorse { current.slowStreak += 1 }
        else if !peerIsFresh || bps >= peer.averageBps * 0.70 { current.slowStreak = 0 }
        laneHealth[slot] = current

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) sampleBps=\\(Int(bps)) avgBps=\\(Int(current.averageBps)) peer=\\(peerSlot) peerAvgBps=\\(Int(peer.averageBps)) peerFresh=\\(peerIsFresh) slowStreak=\\(current.slowStreak)")
        guard current.slowStreak >= 2, now >= current.resetCooldownUntil else { return }

        let reason = "sequential-bps-\\(Int(bps))-peer-\\(Int(peer.averageBps))"
        guard client.resetStreamLane(worker: slot, reason: reason) else { return }
        var reset = LaneHealthState()
        reset.resetCooldownUntil = now.addingTimeInterval(laneHealthResetCooldownSeconds)
        laneHealth[slot] = reset
        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) action=rotate-slow-lane reason=\\(reason) cooldown=\\(Int(laneHealthResetCooldownSeconds))s")
    }

    private func resumeAfterSecondaryCooldown() {
        guard !stopped else { return }
        scheduleSlots(reason: "secondary-cooldown-ended")
    }
''')

replace_once(unified,
'''    private func isMetadataProbe(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty else { return false }
        let nearTail = resource.contentLength > 64 * 1_048_576 && range.lowerBound >= resource.contentLength - 64 * 1_048_576
        let tinyProbe = range.count <= 64 * 1024 && range.lowerBound > max(8 * 1_048_576, playbackAnchor + 2 * blockBytes)
        return nearTail || tinyProbe
    }
''',
'''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, Date().timeIntervalSince(createdAt) < 35, playbackAnchor == 0 else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
    }

    private func isMetadataProbe(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty else { return false }
        let nearTail = resource.contentLength > 64 * 1_048_576 && range.lowerBound >= resource.contentLength - 64 * 1_048_576
        let tinyProbe = range.count <= 64 * 1024 && range.lowerBound > max(8 * 1_048_576, playbackAnchor + 2 * blockBytes)
        return nearTail || tinyProbe
    }
''')

# --- MPV timeline: advancing time-pos is stronger evidence than a flaky initial pause property event. ---
replace_once(controller,
'''        if engineKind == .mpv {
            guard value.isPlaying, !value.isBuffering else { return }
            if let previous = lastVerifiedMPVPosition {
''',
'''        if engineKind == .mpv {
            guard !value.isBuffering else { return }
            if let previous = lastVerifiedMPVPosition {
''')

# Mechanical guards: exactly one speed sample call in each fetch path (two total).
require_count(unified, "recordNetworkBytes(Int64(chunk.count))", 2)
require_count(controller, "guard !value.isBuffering else { return }", 1)

print("v0.11.3 startup/lane-health patch applied")
