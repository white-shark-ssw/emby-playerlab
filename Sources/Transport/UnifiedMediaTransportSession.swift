import Foundation

/// One byte-source for every playback engine. AVPlayer consumes it through the local
/// Range server/resource loader; libmpv consumes it through mpv_stream_cb.
///
/// Invariants:
/// - Exactly two upstream slots are used for normal 115/CDN traffic.
/// - Warm sequential prefetch should survive ordinary seeks; foreground byte demand borrows the
///   other slot first so cancelling a seek does not repeatedly reset the warmed CDN connection.
/// - Sequential prefetch is anchored by real byte demand, never by time/file-size math.
/// - Internal demux metadata probes are served urgently but do not move playbackAnchor.
actor UnifiedMediaTransportSession: TransportDataSession {
    private enum ClaimRole: String {
        case sequential
        case urgentPlayback
        case metadata
        case startupMetadata
    }

    private struct SlotClaim {
        let range: Range<Int64>
        let role: ClaimRole
    }

    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private struct PlaybackDemandSample {
        let date: Date
        let offset: Int64
    }

    private struct LaneHealthState {
        var averageBps: Double = 0
        var samples = 0
        var slowStreak = 0
        var lastSampleAt = Date.distantPast
        var resetCooldownUntil = Date.distantPast
    }

    private struct LiveLaneState {
        var generation = 0
        var startedAt = Date.distantPast
        var lastChunkAt = Date.distantPast
        var sampleWindowStartedAt = Date.distantPast
        var sampleWindowStartedBytes: Int64 = 0
        var lastSampleAt = Date.distantPast
        var receivedBytes: Int64 = 0
        var recentBps: Double = 0
        var peakBps: Double = 0
        var lastHealthyBps: Double = 0
        var badSince = Date.distantPast
        var slowStreak = 0
        var rotationCount = 0
        var lastRotationAt = Date.distantPast
        var resetCooldownUntil = Date.distantPast
    }

    private var source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let resolver = RedirectResolver()
    private let client = RangeHTTPClient(maximumConnections: 2)
    private let blockBytes: Int64
    private let urgentBlockBytes: Int64 = 16 * 1_048_576
    private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576
    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let startupMetadataSegmentBytes: Int64 = 1 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
    private let initialSequentialBlockBytes: Int64 = 4 * 1_048_576
    private let largeFileInitialSequentialBlockBytes: Int64 = 1 * 1_048_576
    private let initialResumeMinimumHeadGuardBytes: Int64 = 1 * 1_048_576
    private let initialResumeMaximumHeadGuardBytes: Int64 = 32 * 1_048_576
    private let rollingCacheProtectedPrefixBytes: Int64 = 32 * 1_048_576
    private let rollingCacheMinimumRefillGapBytes: Int64 = 64 * 1_048_576
    private let rollingCacheMaximumRefillGapBytes: Int64 = 512 * 1_048_576
    private let rollingCacheEmergencyMaximumBytes: Int64 = 256 * 1_048_576
    private let rollingCacheTransientAllowanceBytes: Int64 = 128 * 1_048_576
    private let playbackDemandRetentionSeconds: TimeInterval = 6
    private let initialResumeHistoryGuardSeconds: TimeInterval = 12
    private let initialResumeHistoryDependencyMaxBytes: Int64 = 1 * 1_048_576
    private let startupMetadataSlowFirstChunkSeconds: TimeInterval = 1.5
    private let startupMetadataSlowFirstChunkBps: Double = 1 * 1_048_576
    private let laneHealthMinSampleBytes: Int64 = 8 * 1_048_576
    private let laneHealthPeerFloorBps: Double = 4 * 1_048_576
    private let laneHealthRelativeFloor: Double = 0.50
    private let laneHealthPeerFreshSeconds: TimeInterval = 20
    private let laneHealthResetCooldownSeconds: TimeInterval = 25
    private let liveLanePeerFloorBps: Double = 4 * 1_048_576
    private let liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576
    private let liveLaneWifiAbsoluteFloorBps: Double = 2.5 * 1_048_576
    private let liveLaneRelativeFloor: Double = 0.45
    private let liveLanePeakFloorBps: Double = 6 * 1_048_576
    private let liveLanePeakRelativeFloor: Double = 0.45
    private let liveLanePeakDropSeconds: TimeInterval = 1.0
    private let liveLaneRotationEscalationWindowSeconds: TimeInterval = 30
    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneProgressWatchdogIntervalSeconds: TimeInterval = 0.75
    private let liveLaneNoProgressPeerSeconds: TimeInterval = 1.25
    private let liveLaneNoProgressHardSeconds: TimeInterval = 2.75
    private let urgentFirstByteHedgeSeconds: TimeInterval = 0.65
    private let liveLaneSampleWindowSeconds: TimeInterval = 1.0
    private let liveLaneSampleMinimumBytes: Int64 = 1 * 1_048_576
    private let liveLaneResetCooldownSeconds: TimeInterval = 2
    private let startupTailDemandGraceSeconds: TimeInterval = 0.25
    private let stallBlockingDemandFreshSeconds: TimeInterval = 12
    private let strictFrontierReserveBytes: Int64 = Int64.max
    private let lookaheadSegments = 4
    private let createdAt = Date()

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var store: DownloadFirstSparseStore?
    private var rangeMap = PlaybackRangeMap()
    private var playbackAnchor: Int64 = 0
    private var cacheWindowCenter: Int64 = 0
    private var cacheRefillActive = true
    private var cacheEmergencyActive = false
    private var playbackAdvancing = true
    private var playbackStarving = false
    private var awaitingInitialResumeDemand = false
    private var initialResumeAnchorByte: Int64?
    private var initialResumeCandidateByte: Int64?
    private var initialResumeHistoryGuardUntil = Date.distantPast
    private var demandCoordinator = PlaybackDemandCoordinator()
    private var pendingUserSeekUntil = Date.distantPast
    private var pendingPlaybackUrgentRange: Range<Int64>?
    private var pendingMetadataRange: Range<Int64>?
    private var lastBlockingPlaybackDemand: Range<Int64>?
    private var lastBlockingPlaybackDemandAt = Date.distantPast
    private var playbackDemandSamples: [PlaybackDemandSample] = []
    private var sequentialWaveUpperBound: Int64 = 0
    private var sequentialWaveSegmentBytes: Int64 = 0
    private var startupMetadataPlanRange: Range<Int64>?
    private var startupMetadataQueue: [Range<Int64>] = []
    private var startupMetadataPlanCompleted = false
    private var startupTailDemandGraceUntil = Date.distantPast
    private var startupTailGraceResumeScheduled = false
    private var preferredBulkSlot = 0
    private var stopped = false

    private var slotTasks: [Int: Task<Void, Never>] = [:]
    private var slotClaims: [Int: SlotClaim] = [:]
    private var slotGenerations: [Int: Int] = [0: 0, 1: 0]
    private var secondaryEnabled = false
    private var secondaryFailureCount = 0
    private var secondaryCooldownUntil = Date.distantPast
    private var successfulPrimaryBlocks = 0
    private var laneHealth: [Int: LaneHealthState] = [0: LaneHealthState(), 1: LaneHealthState()]
    private var liveLaneState: [Int: LiveLaneState] = [0: LiveLaneState(), 1: LiveLaneState()]
    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
    private var liveLaneSourceRefreshPending: Set<Int> = []
    private var urgentReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var urgentHedgeRequested: Set<Int> = []
    private var urgentRaceResetPending: Set<Int> = []
    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var startupMetadataStartedAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataLastProgressAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataRetryRequested: Set<Int> = []

    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var lastMetricsLogAt = Date.distantPast

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 64 * 1_048_576)
    }

    func setPlaybackAdvancing(_ advancing: Bool) async {
        guard !stopped else { return }
        guard playbackAdvancing != advancing else { return }
        playbackAdvancing = advancing
        if !advancing { playbackStarving = false }
        DiagnosticsLogger.shared.playback("RollingCache", "playback advancing=\(advancing) center=\(cacheWindowCenter) refill=\(cacheRefillActive)")
        scheduleSlots(reason: advancing ? "playback-resumed" : "playback-paused-fill")
    }

    func prepareInitialPlayback(position: Double, duration: Double) {
        guard !stopped, position > 0.5 else { return }
        awaitingInitialResumeDemand = true
        initialResumeAnchorByte = nil
        initialResumeCandidateByte = nil
        initialResumeHistoryGuardUntil = .distantPast
        lastBlockingPlaybackDemand = nil
        lastBlockingPlaybackDemandAt = .distantPast
        demandCoordinator.reset()
        playbackDemandSamples.removeAll()
        resetSequentialWave()
        for slot in [0, 1] where slotClaims[slot]?.role == .sequential { cancelSlot(slot, reason: "initial-resume-await-real-demand") }
        DiagnosticsLogger.shared.playback(
            "Resume",
            "transport gate armed position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) byteGuess=disabled headGuard=adaptive"
        )
    }

    func confirmInitialResumePlayback() async {
        guard !stopped, awaitingInitialResumeDemand, let resource else { return }
        guard let candidate = initialResumeCandidateByte else {
            DiagnosticsLogger.shared.playback("Resume", "playback advanced but real-byte candidate unavailable action=keep-gate")
            return
        }
        let anchor = min(max(0, candidate), max(0, resource.contentLength - 1))
        let previous = playbackAnchor
        awaitingInitialResumeDemand = false
        playbackAnchor = anchor
        initialResumeAnchorByte = anchor
        initialResumeCandidateByte = nil
        initialResumeHistoryGuardUntil = Date().addingTimeInterval(initialResumeHistoryGuardSeconds)
        demandCoordinator.reset()
        playbackDemandSamples.removeAll()
        recordPlaybackDemand(offset: anchor)
        resetCacheWindowCenter(to: anchor, resource: resource, reason: "resume-playback-confirmed")
        for slot in [0, 1] {
            guard let active = slotClaims[slot], !active.range.contains(anchor) else { continue }
            if active.role == .urgentPlayback { cancelSlot(slot, reason: "resume-confirm-replace-urgent") }
            if active.role == .sequential { cancelSlot(slot, reason: "resume-confirm-reanchor-sequential") }
        }
        DiagnosticsLogger.shared.playback("Resume", "playback-confirmed anchor previous=\(previous) new=\(anchor) byteGuess=disabled action=release-bulk-gate")
        scheduleSlots(reason: "resume-playback-confirmed")
    }

    func resolve() async throws -> TransportResolvedResource {
        if let resource { return resource }
        if let resolveTask { return try await resolveTask.value }
        guard !stopped else { throw MediaTransportError.cancelled }

        let snapshot = source
        let resolver = resolver
        let task = Task<TransportResolvedResource, Error> { try await resolver.resolve(source: snapshot) }
        resolveTask = task
        do {
            let resolved = try await task.value
            resolveTask = nil
            guard resolved.supportsByteRanges else { throw MediaTransportError.rangeUnsupported(statusCode: 200) }
            resource = resolved
            if store == nil {
                let cacheKey = TransportCacheMaintenance.stableVideoCacheKey(for: source)
                if configuration.keepLastCache { TransportCacheMaintenance.preparePersistentVideoCache(cacheKey: cacheKey) }
                else { TransportCacheMaintenance.clearPersistentUnifiedVideoCaches() }
                let cache = try DownloadFirstSparseStore(
                    cacheKey: cacheKey,
                    contentLength: resolved.contentLength,
                    etag: resolved.etag,
                    lastModified: resolved.lastModified,
                    keepFiles: configuration.keepLastCache
                )
                store = cache
                for range in cache.cachedRanges { rangeMap.insertPlayback(range) }
            }
            DiagnosticsLogger.shared.log(
                "UnifiedTransport",
                "ready item=\(source.itemId) bytes=\(resolved.contentLength) slots=2 block=\(blockBytes) preloadWindow=\(preloadWindowBytes()) anchor=\(playbackAnchor) center=\(cacheWindowCenter) softMax=\(rollingSoftLimitBytes(window: preloadWindowBytes())) resumeGate=\(awaitingInitialResumeDemand) \(NetworkPathMonitor.shared.diagnosticSummary)"
            )
            scheduleSlots(reason: "resolved")
            return resolved
        } catch {
            resolveTask = nil
            throw error
        }
    }

    func noteDemand(range: Range<Int64>) async {
        guard !stopped, !range.isEmpty, let resolved = try? await resolve(), let store else { return }
        let normalized = clamp(range: range, contentLength: resolved.contentLength)
        guard !normalized.isEmpty else { return }
        if store.contains(normalized) {
            acceptRealDemand(normalized, resource: resolved, reason: "range-demand-cached")
            return
        }
        acceptRealDemand(normalized, resource: resolved, reason: "range-demand")
    }

    func prioritizeOffset(_ offset: Int64) async {
        guard !stopped, let resolved = try? await resolve() else { return }
        let clamped = min(max(0, offset), max(0, resolved.contentLength - 1))
        let probe = clamped..<min(resolved.contentLength, clamped + urgentBlockBytes)
        let preferredLength = isMetadataProbe(probe, resource: resolved) ? metadataUrgentBlockBytes : urgentBlockBytes
        let demand = clamped..<min(resolved.contentLength, clamped + preferredLength)
        acceptRealDemand(demand, resource: resolved, reason: "byte-offset")
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resolved = try await resolve()
        guard offset >= 0, offset < resolved.contentLength, let store else { return Data() }

        let requested = min(length, Int(resolved.contentLength - offset))
        let concreteRange = offset..<min(resolved.contentLength, offset + Int64(requested))
        acceptRealDemand(concreteRange, resource: resolved, reason: "concrete-read")
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }

        if available == 0 {
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let preferredLength = isMetadataProbe(probe, resource: resolved) ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            acceptRealDemand(offset..<demandEnd, resource: resolved, reason: "blocked-read")
        }

        do {
            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            refreshMetrics(resource: resolved)
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let metadata = isMetadataProbe(probe, resource: resolved)
            let preferredLength = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            DiagnosticsLogger.shared.log("UnifiedDemand", "timeout offset=\(offset) length=\(requested); force slot0")
            installUrgent(range: offset..<demandEnd, metadata: metadata, reason: "read-timeout")
            scheduleSlots(reason: "read-timeout")
            return try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)
        }
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped else { return }
        pendingUserSeekUntil = Date().addingTimeInterval(4)
        DiagnosticsLogger.shared.log(
            "UnifiedAnchor",
            "user-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) byteGuess=disabled awaitingRealDemand=true anchor=\(playbackAnchor)"
        )
    }

    func recoverStall(position: Double, duration: Double) async {
        guard !stopped else { return }
        let now = Date()
        if let demand = lastBlockingPlaybackDemand, now.timeIntervalSince(lastBlockingPlaybackDemandAt) <= stallBlockingDemandFreshSeconds, let resource {
            let previous = playbackAnchor
            playbackAnchor = demand.lowerBound
            demandCoordinator.reset()
            resetCacheWindowCenter(to: demand.lowerBound, resource: resource, reason: "stall-blocking-demand")
            let urgent = demand.lowerBound..<min(resource.contentLength, safeAdd(demand.lowerBound, urgentBlockBytes))
            if store?.contains(urgent) == true {
                DiagnosticsLogger.shared.log("UnifiedDemand", "stall position=\(String(format: "%.3f", position)) previousAnchor=\(previous) anchor=\(playbackAnchor) blocked=\(demand.lowerBound)-\(demand.upperBound) action=blocking-demand-already-cached")
            } else {
                installUrgent(range: urgent, metadata: false, reason: "stall-last-blocking-demand")
                DiagnosticsLogger.shared.log("UnifiedDemand", "stall position=\(String(format: "%.3f", position)) previousAnchor=\(previous) anchor=\(playbackAnchor) blocked=\(demand.lowerBound)-\(demand.upperBound) action=prioritize-blocking-demand")
            }
            for slot in [0, 1] {
                if let active = slotClaims[slot], active.role == .urgentPlayback, !active.range.contains(demand.lowerBound) { cancelSlot(slot, reason: "replace-stale-urgent") }
            }
        } else {
            DiagnosticsLogger.shared.log("UnifiedDemand", "stall position=\(String(format: "%.3f", position)) anchor=\(playbackAnchor) action=keep-anchor-await-blocked-read")
        }
        scheduleSlots(reason: "stall")
    }

    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() {
            if slotTasks.isEmpty, Date() > pendingUserSeekUntil || pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
                scheduleSlots(reason: "metrics-idle-repair")
            }
            refreshMetrics(resource: resolved)
        }
        return metricsValue
    }

    func cachedByteRanges() -> [Range<Int64>] {
        let resourceLength = resource?.contentLength ?? 0
        return rangeMap.snapshot(anchor: 0, resourceLength: resourceLength).playbackRanges
    }

    func quiesceConsumers() async {
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    func stop() async {
        guard !stopped else { return }
        stopped = true
        resolveTask?.cancel()
        resolveTask = nil
        for task in slotTasks.values { task.cancel() }
        slotTasks.removeAll()
        slotClaims.removeAll()
        rangeMap.clearDownloading(lane: "slot0")
        rangeMap.clearDownloading(lane: "slot1")
        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        client.invalidate()
        DiagnosticsLogger.shared.log("UnifiedTransport", "stopped item=\(source.itemId)")
    }

    private func acceptRealDemand(_ range: Range<Int64>, resource: TransportResolvedResource, reason: String) {
        guard !range.isEmpty, let store else { return }
        let concreteReason = reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"
        let startupTailMetadata = isStartupTailMetadata(range, resource: resource)
        let metadata = startupTailMetadata || (!concreteReason && isMetadataProbe(range, resource: resource))
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason && !metadata
        if awaitingInitialResumeDemand, concretePlaybackDemand, reason == "concrete-read" || reason == "blocked-read" { initialResumeCandidateByte = range.lowerBound }
        let cachedReadDistance = range.lowerBound >= playbackAnchor ? range.lowerBound - playbackAnchor : playbackAnchor - range.lowerBound
        let cachedSeekRead = pendingUserSeek && reason == "concrete-read" && store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 && cachedReadDistance >= max(8 * 1_048_576, blockBytes / 2)
        let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset" || cachedSeekRead
        let resumeHistoricalDependency: Bool = {
            guard concretePlaybackDemand, !pendingUserSeek, Date() <= initialResumeHistoryGuardUntil, let resumeAnchor = initialResumeAnchorByte else { return false }
            return range.upperBound + initialResumeHistoryDependencyMaxBytes < resumeAnchor
        }()
        let resumeHeadGuard = awaitingInitialResumeDemand ? initialResumeHeadGuardBytes(resourceLength: resource.contentLength) : 0
        let resumeBootstrapHead = awaitingInitialResumeDemand && concretePlaybackDemand && range.lowerBound < resumeHeadGuard
        if resumeBootstrapHead {
            let boundedUpper = min(resource.contentLength, min(range.upperBound, safeAdd(range.lowerBound, metadataUrgentBlockBytes)))
            let bounded = range.lowerBound..<max(range.lowerBound + 1, boundedUpper)
            DiagnosticsLogger.shared.playback(
                "Resume",
                "bootstrap head range=\(range.lowerBound)-\(range.upperBound) bounded=\(bounded.lowerBound)-\(bounded.upperBound) headGuard=\(resumeHeadGuard) reason=\(reason) action=urgent-only-keep-gate"
            )
            if !store.contains(bounded) { installUrgent(range: bounded, metadata: true, reason: "resume-bootstrap-head") }
            scheduleSlots(reason: "resume-bootstrap-head")
            return
        }
        if concretePlaybackDemand, reason == "blocked-read", !resumeHistoricalDependency, !playbackStarving {
            playbackStarving = true
            cacheRefillActive = true
            DiagnosticsLogger.shared.playback("PlaybackDemand", "starvation inferred blockedRange=\(range.lowerBound)-\(range.upperBound) center=\(cacheWindowCenter)")
        }
        var reanchored = false
        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=actual-demand") }
        if concretePlaybackDemand, !resumeHistoricalDependency { recordPlaybackDemand(offset: range.lowerBound) }
        if concretePlaybackDemand, authoritativeSeekDemand, !resumeHistoricalDependency {
            lastBlockingPlaybackDemand = range
            lastBlockingPlaybackDemandAt = Date()
        }

        if awaitingInitialResumeDemand, concretePlaybackDemand {
            let resumeHeadGuard = initialResumeHeadGuardBytes(resourceLength: resource.contentLength)
            let resumeAuthority = range.lowerBound >= resumeHeadGuard
            if resumeAuthority {
                awaitingInitialResumeDemand = false
                let previous = playbackAnchor
                playbackAnchor = range.lowerBound
                initialResumeAnchorByte = range.lowerBound
                initialResumeCandidateByte = nil
                initialResumeHistoryGuardUntil = Date().addingTimeInterval(initialResumeHistoryGuardSeconds)
                demandCoordinator.reset()
                playbackDemandSamples.removeAll()
                recordPlaybackDemand(offset: range.lowerBound)
                resetCacheWindowCenter(to: range.lowerBound, resource: resource, reason: "resume-real-demand")
                reanchored = true
                DiagnosticsLogger.shared.playback(
                    "Resume",
                    "real-demand anchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) headGuard=\(resumeHeadGuard)"
                )
                for slot in [0, 1] {
                    guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                    if active.role == .urgentPlayback { cancelSlot(slot, reason: "initial-resume-replace-bootstrap-urgent") }
                    if active.role == .sequential { cancelSlot(slot, reason: "initial-resume-reanchor-sequential") }
                }
            } else if authoritativeSeekDemand {
                DiagnosticsLogger.shared.playback(
                    "Resume",
                    "bootstrap demand range=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=urgent-only-await-resume-byte headGuard=\(resumeHeadGuard)"
                )
            }
        }

        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) awaitingConcreteRead=true anchor=\(playbackAnchor)"
            )
            return
        }
        if pendingUserSeek, concretePlaybackDemand, !authoritativeSeekDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek concrete-read deferred request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) awaitingBlockedRead=true anchor=\(playbackAnchor)"
            )
            return
        }

        if !concreteReason, !metadata {
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "hint-only request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=keep-bulk")
            scheduleSlots(reason: "hint-only")
            return
        }

        if pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand {
            pendingUserSeekUntil = .distantPast
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            initialResumeAnchorByte = nil
            initialResumeCandidateByte = nil
            initialResumeHistoryGuardUntil = .distantPast
            demandCoordinator.reset()
            playbackDemandSamples.removeAll()
            recordPlaybackDemand(offset: range.lowerBound)
            resetCacheWindowCenter(to: range.lowerBound, resource: resource, reason: "user-seek-real-demand")
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) authority=\(cachedSeekRead ? "cached-read" : "cache-miss")"
            )
            for slot in [0, 1] {
                guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                if active.role == .urgentPlayback { cancelSlot(slot, reason: "replace-stale-urgent") }
                if active.role == .sequential { cancelSlot(slot, reason: "seek-reanchor-sequential") }
            }
        }

        if resumeHistoricalDependency {
            if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), initialResumeHistoryDependencyMaxBytes)) > 0 { return }
            let upper = min(resource.contentLength, min(range.upperBound, safeAdd(range.lowerBound, initialResumeHistoryDependencyMaxBytes)))
            let bounded = range.lowerBound..<max(range.lowerBound + 1, upper)
            DiagnosticsLogger.shared.playback(
                "Resume",
                "historical dependency range=\(range.lowerBound)-\(range.upperBound) bounded=\(bounded.lowerBound)-\(bounded.upperBound) anchor=\(initialResumeAnchorByte ?? -1) reason=\(reason) action=urgent-only-no-backfill"
            )
            installUrgent(range: bounded, metadata: false, reason: "resume-historical-dependency")
            scheduleSlots(reason: "resume-historical-dependency")
            return
        }

        if concretePlaybackDemand, !reanchored, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil {
            switch demandCoordinator.observe(offset: range.lowerBound, activeCenter: cacheWindowCenter, nearDistance: blockBytes * 4, starving: playbackStarving) {
            case .nearHead:
                advanceCacheWindowCenterFromRecentDemand(resource: resource)
            case .holdCandidate(let samples):
                if samples == 1 { DiagnosticsLogger.shared.playback("PlaybackDemand", "candidate center=\(cacheWindowCenter) offset=\(range.lowerBound) starving=\(playbackStarving) reason=\(reason)") }
            case .promote(let offset, let promotionReason):
                let previous = cacheWindowCenter
                playbackAnchor = offset
                playbackDemandSamples.removeAll()
                recordPlaybackDemand(offset: offset)
                resetCacheWindowCenter(to: offset, resource: resource, reason: promotionReason)
                reanchored = true
                DiagnosticsLogger.shared.playback("PlaybackDemand", "promoted previous=\(previous) new=\(offset) reason=\(promotionReason) request=\(range.lowerBound)-\(range.upperBound)")
                for slot in [0, 1] {
                    guard let active = slotClaims[slot], !active.range.contains(offset) else { continue }
                    if active.role == .sequential || active.role == .urgentPlayback { cancelSlot(slot, reason: "active-head-promoted") }
                }
            }
        }

        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 {
            if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }
            return
        }

        if let activeEntry = slotClaims.first(where: { $0.value.role != .sequential && $0.value.range.contains(range.lowerBound) }) {
            let activeSlot = activeEntry.key
            let active = activeEntry.value
            if concretePlaybackDemand, active.role == .urgentPlayback {
                let ready = store.availableLength(from: active.range.lowerBound, maximumLength: Int64(active.range.count))
                let streamHead = min(active.range.upperBound, active.range.lowerBound + ready)
                let gap = max(0, range.lowerBound - streamHead)
                if gap > progressiveUrgentGapBytes {
                    DiagnosticsLogger.shared.log("UnifiedDemand", "foreground active-gap slot=\(activeSlot) request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) head=\(streamHead) gap=\(gap) action=parallel-urgent")
                    installUrgent(range: range, metadata: false, reason: "foreground-active-gap-\(reason)")
                    scheduleSlots(reason: "foreground-active-gap-\(reason)")
                    return
                }
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active foreground request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) role=\(active.role.rawValue) reason=\(reason)")
            return
        }

        if concretePlaybackDemand, let activeSequential = slotClaims.first(where: { $0.value.role == .sequential && $0.value.range.contains(range.lowerBound) }) {
            let slot = activeSequential.key
            let claim = activeSequential.value
            let ready = store.availableLength(from: claim.range.lowerBound, maximumLength: Int64(claim.range.count))
            let streamHead = min(claim.range.upperBound, claim.range.lowerBound + ready)
            let gap = max(0, range.lowerBound - streamHead)
            if gap <= progressiveUrgentGapBytes {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream slot=\(slot) request=\(range.lowerBound)-\(range.upperBound) claim=\(claim.range.lowerBound)-\(claim.range.upperBound) head=\(streamHead) gap=\(gap) reason=\(reason) action=wait-progressive-chunk")
                return
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "foreground gap slot=\(slot) request=\(range.lowerBound)-\(range.upperBound) claim=\(claim.range.lowerBound)-\(claim.range.upperBound) head=\(streamHead) gap=\(gap) action=parallel-urgent")
            installUrgent(range: range, metadata: false, reason: "foreground-gap-\(reason)")
            scheduleSlots(reason: "foreground-gap-\(reason)")
            return
        }

        installUrgent(range: range, metadata: metadata, reason: reason)
        scheduleSlots(reason: reason)
    }

    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {
        guard let resource else { return }
        let lower = max(0, range.lowerBound)
        let startupCriticalMetadata = metadata && isStartupTailMetadata(range, resource: resource)
        if startupCriticalMetadata {
            installStartupMetadataPlan(range: lower..<resource.contentLength, reason: reason)
            return
        }

        let blockLimit = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
        let requestedUpper = metadata ? max(range.upperBound, safeAdd(lower, blockLimit)) : min(range.upperBound, safeAdd(lower, blockLimit))
        let upper = min(resource.contentLength, max(lower + 1, requestedUpper))
        let candidate = lower..<upper
        if metadata {
            if let existing = pendingMetadataRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingMetadataRange = candidate
        } else {
            if let existing = pendingPlaybackUrgentRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingPlaybackUrgentRange = candidate
        }
        DiagnosticsLogger.shared.log("UnifiedDemand", "urgent range=\(candidate.lowerBound)-\(candidate.upperBound) metadata=\(metadata) reason=\(reason) protectedBulk=\(preferredBulkSlot)")

        if firstIdleForegroundSlot() != nil { return }
        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }
        if sequentialSlots.count == 2 {
            let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "foreground borrow slot=\(serviceSlot) preserveBulk=\(preferredBulkSlot) range=\(candidate.lowerBound)-\(candidate.upperBound)")
            cancelSlot(serviceSlot, reason: metadata ? "metadata-borrow-service-lane" : "foreground-borrow-service-lane")
        } else if sequentialSlots.count == 1 {
            let onlySequential = sequentialSlots[0]
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "second foreground head borrows bulk slot=\(onlySequential) range=\(candidate.lowerBound)-\(candidate.upperBound)")
            cancelSlot(onlySequential, reason: "second-foreground-head")
        }
    }

    private func installStartupMetadataPlan(range: Range<Int64>, reason: String) {
        guard let resource, let store, !range.isEmpty else { return }
        let lower = min(startupMetadataPlanRange?.lowerBound ?? range.lowerBound, range.lowerBound)
        let plan = max(0, lower)..<resource.contentLength
        startupMetadataPlanRange = plan
        startupMetadataPlanCompleted = false
        startupTailDemandGraceUntil = .distantPast

        let activeRanges = slotClaims.values.filter { $0.role == .startupMetadata }.map(\.range)
        var chunks: [Range<Int64>] = []
        var cursor = plan.lowerBound
        while cursor < plan.upperBound {
            let chunk = cursor..<min(plan.upperBound, safeAdd(cursor, startupMetadataSegmentBytes))
            if !store.contains(chunk), !activeRanges.contains(where: { $0.lowerBound == chunk.lowerBound && $0.upperBound == chunk.upperBound }) { chunks.append(chunk) }
            cursor = chunk.upperBound
        }
        startupMetadataQueue = chunks
        for slot in [0, 1] where slotClaims[slot]?.role == .sequential { cancelSlot(slot, reason: "startup-metadata-preempt") }
        DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan range=\(plan.lowerBound)-\(plan.upperBound) bytes=\(plan.count) segment=\(startupMetadataSegmentBytes) queued=\(startupMetadataQueue.count) reason=\(reason)")
    }

    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        if !startupMetadataQueue.isEmpty || slotClaims.values.contains(where: { $0.role == .startupMetadata }) {
            for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot) && !liveLaneSourceRefreshPending.contains(slot) {
                if slot == 1, Date() < secondaryCooldownUntil { continue }
                while !startupMetadataQueue.isEmpty {
                    let chunk = startupMetadataQueue.removeFirst()
                    if store.contains(chunk) { continue }
                    startSlot(slot, claim: SlotClaim(range: chunk, role: .startupMetadata), reason: "startup-metadata-\(reason)")
                    break
                }
            }
            refreshMetrics(resource: resource)
            return
        }

        if let urgent = pendingPlaybackUrgentRange, store.contains(urgent) {
            pendingPlaybackUrgentRange = nil
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "pending urgent satisfied range=\(urgent.lowerBound)-\(urgent.upperBound) action=drop-satisfied")
        }
        if let metadata = pendingMetadataRange, store.contains(metadata) {
            pendingMetadataRange = nil
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "pending metadata satisfied range=\(metadata.lowerBound)-\(metadata.upperBound) action=drop-satisfied")
        }

        if let urgent = pendingPlaybackUrgentRange, let slot = firstIdleForegroundSlot() {
            pendingPlaybackUrgentRange = nil
            startSlot(slot, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "foreground-\(reason)")
        }

        if let metadata = pendingMetadataRange, let slot = firstIdleForegroundSlot() {
            pendingMetadataRange = nil
            startSlot(slot, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\(reason)")
        }

        if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
            refreshMetrics(resource: resource)
            return
        }

        if startupMetadataPlanRange == nil, Date() < startupTailDemandGraceUntil {
            refreshMetrics(resource: resource)
            return
        }

        if awaitingInitialResumeDemand {
            refreshMetrics(resource: resource)
            return
        }

        if !secondaryEnabled {
            if slotTasks[0] == nil, !liveLaneResetPending.contains(0), !liveLaneSourceRefreshPending.contains(0), let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }
            refreshMetrics(resource: resource)
            return
        }

        let order = preferredBulkSlot == 0 ? [0, 1] : [1, 0]
        for slot in order where slotTasks[slot] == nil {
            if liveLaneResetPending.contains(slot) || liveLaneSourceRefreshPending.contains(slot) { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            if let range = nextSequentialClaim(resource: resource) { startSlot(slot, claim: SlotClaim(range: range, role: .sequential), reason: slot == preferredBulkSlot ? "bulk-\(reason)" : "service-preload-\(reason)") }
        }
        refreshMetrics(resource: resource)
    }

    private func firstIdleForegroundSlot() -> Int? {
        let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
        let order = [serviceSlot, preferredBulkSlot]
        for slot in order {
            guard slotTasks[slot] == nil, !liveLaneResetPending.contains(slot), !liveLaneSourceRefreshPending.contains(slot) else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            return slot
        }
        return nil
    }

    private func nextSequentialClaim(resource: TransportResolvedResource) -> Range<Int64>? {
        let window = preloadWindowBytes()
        guard window > 0, let store else { return nil }
        let center = min(max(0, cacheWindowCenter), max(0, resource.contentLength - 1))
        let forwardUpper = min(resource.contentLength, safeAdd(center, window))
        guard forwardUpper > center else { return nil }

        let forwardRange = center..<forwardUpper
        let forwardTarget = Int64(forwardRange.count)
        let forwardCached = rangeMap.playbackBytes(in: forwardRange)
        let forwardContiguous = rangeMap.contiguousLength(from: center, resourceLength: forwardUpper)
        let refillGap = min(rollingRefillGapBytes(window: window), forwardTarget)
        let lowWater = max(0, forwardTarget - refillGap)
        let emergencyThreshold = min(rollingEmergencyThresholdBytes(window: window), forwardTarget)
        let starvationRecovery = min(64 * 1_048_576, max(8 * 1_048_576, window / 16))
        if playbackStarving, forwardContiguous >= starvationRecovery {
            playbackStarving = false
            DiagnosticsLogger.shared.playback("PlaybackDemand", "starvation cleared center=\(center) contiguous=\(forwardContiguous) recovery=\(starvationRecovery)")
        }
        let emergencyNow = playbackStarving || (forwardContiguous < forwardTarget && forwardContiguous <= emergencyThreshold)

        if emergencyNow, !cacheEmergencyActive {
            cacheEmergencyActive = true
            DiagnosticsLogger.shared.playback("RollingCache", "emergency entered center=\(center) contiguous=\(forwardContiguous) threshold=\(emergencyThreshold) forwardCached=\(forwardCached)/\(forwardTarget)")
        } else if !emergencyNow, cacheEmergencyActive {
            cacheEmergencyActive = false
            DiagnosticsLogger.shared.playback("RollingCache", "emergency cleared center=\(center) contiguous=\(forwardContiguous) threshold=\(emergencyThreshold)")
        }

        if cacheRefillActive {
            if forwardCached >= forwardTarget {
                cacheRefillActive = false
                cacheEmergencyActive = false
                resetSequentialWave()
                prepareBidirectionalCacheCapacityIfNeeded(resource: resource, window: window, refillGap: 0)
                DiagnosticsLogger.shared.playback("RollingCache", "forward full center=\(center) cached=\(forwardCached) target=\(forwardTarget) action=stop-preload")
                return nil
            }
        } else if forwardCached <= lowWater || emergencyNow || playbackStarving {
            cacheRefillActive = true
            resetSequentialWave()
            DiagnosticsLogger.shared.playback("RollingCache", "refill begin center=\(center) cached=\(forwardCached) lowWater=\(lowWater) target=\(forwardTarget) contiguous=\(forwardContiguous) emergency=\(emergencyNow) starving=\(playbackStarving)")
        } else {
            prepareBidirectionalCacheCapacityIfNeeded(resource: resource, window: window, refillGap: 0)
            return nil
        }

        prepareBidirectionalCacheCapacityIfNeeded(resource: resource, window: window, refillGap: refillGap)
        let softLimit = rollingSoftLimitBytes(window: window)
        let hardLimit = safeAdd(softLimit, max(rollingCacheTransientAllowanceBytes, blockBytes * 2))
        if configuration.usesDiskCache, store.uniqueBytes >= hardLimit {
            DiagnosticsLogger.shared.playback("RollingCache", "preload paused hardLimit center=\(center) cached=\(store.uniqueBytes) soft=\(softLimit) hard=\(hardLimit)")
            return nil
        }

        let snapshot = rangeMap.snapshot(anchor: center, resourceLength: resource.contentLength)
        let firstPlaybackBlock = forwardCached == 0
        let largeIndexedMP4Startup = source.mediaSource.normalizedContainer == "mp4" && resource.contentLength >= 4 * 1_073_741_824
        let initialBytes = largeIndexedMP4Startup ? largeFileInitialSequentialBlockBytes : initialSequentialBlockBytes
        let segmentBytes = firstPlaybackBlock ? min(blockBytes, initialBytes) : blockBytes
        let contiguousBytes = max(0, snapshot.frontierByte - center)
        let strictFrontier = contiguousBytes < strictFrontierReserveBytes
        let claimUpper: Int64
        let claimLookahead: Int
        if strictFrontier {
            let relativeFrontier = max(0, snapshot.frontierByte - center)
            let waveBase = center + (relativeFrontier / segmentBytes) * segmentBytes
            if sequentialWaveSegmentBytes != segmentBytes || sequentialWaveUpperBound <= snapshot.frontierByte || sequentialWaveUpperBound <= center {
                sequentialWaveSegmentBytes = segmentBytes
                sequentialWaveUpperBound = min(forwardUpper, safeAdd(waveBase, segmentBytes * 2))
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "frontier wave start=\(snapshot.frontierByte) base=\(waveBase) upper=\(sequentialWaveUpperBound) segment=\(segmentBytes) contiguous=\(contiguousBytes) center=\(center) action=strict-two-segment")
            }
            claimUpper = min(forwardUpper, sequentialWaveUpperBound)
            claimLookahead = 2
        } else {
            resetSequentialWave()
            claimUpper = forwardUpper
            claimLookahead = lookaheadSegments
        }
        return rangeMap.nextClaim(from: center, resourceLength: claimUpper, segmentBytes: segmentBytes, workerLimit: 2, lookaheadSegments: claimLookahead)
    }

    private func resetSequentialWave() {
        sequentialWaveUpperBound = 0
        sequentialWaveSegmentBytes = 0
    }

    private func recordPlaybackDemand(offset: Int64) {
        guard offset >= 0 else { return }
        let now = Date()
        playbackDemandSamples.append(PlaybackDemandSample(date: now, offset: offset))
        let cutoff = now.addingTimeInterval(-playbackDemandRetentionSeconds)
        playbackDemandSamples.removeAll { $0.date < cutoff }
        if playbackDemandSamples.count > 64 { playbackDemandSamples.removeFirst(playbackDemandSamples.count - 64) }
    }

    private func prunePlaybackDemandSamples() {
        let cutoff = Date().addingTimeInterval(-playbackDemandRetentionSeconds)
        playbackDemandSamples.removeAll { $0.date < cutoff }
    }

    private func resetCacheWindowCenter(to offset: Int64, resource: TransportResolvedResource, reason: String) {
        let clamped = min(max(0, offset), max(0, resource.contentLength - 1))
        let previous = cacheWindowCenter
        cacheWindowCenter = clamped
        cacheRefillActive = true
        cacheEmergencyActive = false
        resetSequentialWave()
        DiagnosticsLogger.shared.playback("RollingCache", "center reset previous=\(previous) new=\(cacheWindowCenter) reason=\(reason)")
    }

    private func advanceCacheWindowCenterFromRecentDemand(resource: TransportResolvedResource) {
        guard playbackAdvancing, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil else { return }
        prunePlaybackDemandSamples()
        guard let recentFloor = playbackDemandSamples.map(\.offset).min() else { return }
        let candidate = min(max(0, recentFloor), max(0, resource.contentLength - 1))
        guard candidate > cacheWindowCenter else { return }
        let distance = candidate - cacheWindowCenter
        guard distance <= blockBytes * 4 else { return }
        let previous = cacheWindowCenter
        cacheWindowCenter = candidate
        playbackAnchor = candidate
        DiagnosticsLogger.shared.playback("RollingCache", "center advanced previous=\(previous) new=\(cacheWindowCenter) delta=\(distance)")
        scheduleSlots(reason: "window-center-advanced")
    }

    private func rollingRefillGapBytes(window: Int64) -> Int64 {
        min(rollingCacheMaximumRefillGapBytes, max(rollingCacheMinimumRefillGapBytes, window / 5))
    }

    private func rollingEmergencyThresholdBytes(window: Int64) -> Int64 {
        min(rollingCacheEmergencyMaximumBytes, max(16 * 1_048_576, window / 4))
    }

    private func rollingSoftLimitBytes(window: Int64) -> Int64 {
        safeAdd(window, window)
    }

    private func protectedRollingCacheRanges(resource: TransportResolvedResource) -> [Range<Int64>] {
        var protected = rangeMap.snapshot(anchor: cacheWindowCenter, resourceLength: resource.contentLength).metadataRanges
        protected.append(contentsOf: slotClaims.values.map(\.range))
        if let pendingPlaybackUrgentRange { protected.append(pendingPlaybackUrgentRange) }
        if let pendingMetadataRange { protected.append(pendingMetadataRange) }
        if let lastBlockingPlaybackDemand, Date().timeIntervalSince(lastBlockingPlaybackDemandAt) <= stallBlockingDemandFreshSeconds { protected.append(lastBlockingPlaybackDemand) }
        for sample in playbackDemandSamples {
            let lower = max(0, sample.offset - progressiveUrgentGapBytes)
            let upper = min(resource.contentLength, safeAdd(sample.offset, urgentBlockBytes))
            if upper > lower { protected.append(lower..<upper) }
        }
        return protected
    }

    private func prepareBidirectionalCacheCapacityIfNeeded(resource: TransportResolvedResource, window: Int64, refillGap: Int64) {
        guard configuration.ktvContinuousPreloadEnabled, configuration.usesDiskCache, window > 0, let store else { return }
        let center = min(max(0, cacheWindowCenter), max(0, resource.contentLength - 1))
        let retainedLower = max(0, center - window)
        let retainedUpper = min(resource.contentLength, safeAdd(center, window))
        guard retainedUpper > retainedLower else { return }

        let softLimit = rollingSoftLimitBytes(window: window)
        let targetBytes = max(window, softLimit - min(refillGap, window))
        guard store.uniqueBytes > targetBytes else { return }
        let evicted = store.evictCachedBytes(
            outside: retainedLower..<retainedUpper,
            targetBytes: targetBytes,
            protectedPrefixBytes: rollingCacheProtectedPrefixBytes,
            protectedRanges: protectedRollingCacheRanges(resource: resource)
        )
        for range in evicted { rangeMap.removePlayback(range) }
        guard !evicted.isEmpty else { return }
        let evictedBytes = evicted.reduce(Int64(0)) { $0 + Int64($1.count) }
        DiagnosticsLogger.shared.playback(
            "RollingCache",
            "capacityWindow=\(window) softMax=\(softLimit) center=\(center) retained=\(retainedLower)-\(retainedUpper) target=\(targetBytes) evicted=\(evictedBytes) cachedNow=\(store.uniqueBytes)"
        )
    }

    private func startSlot(_ slot: Int, claim: SlotClaim, reason: String) {
        guard slotTasks[slot] == nil, !claim.range.isEmpty else { return }
        let generation = (slotGenerations[slot] ?? 0) + 1
        slotGenerations[slot] = generation
        slotClaims[slot] = claim
        if claim.role == .sequential {
            var live = liveLaneState[slot] ?? LiveLaneState()
            let now = Date()
            live.generation = generation
            live.startedAt = now
            live.lastChunkAt = now
            live.sampleWindowStartedAt = now
            live.sampleWindowStartedBytes = 0
            live.lastSampleAt = .distantPast
            live.receivedBytes = 0
            live.recentBps = 0
            live.badSince = .distantPast
            live.slowStreak = 0
            liveLaneState[slot] = live
            armFirstByteWatchdog(slot: slot, generation: generation)
            armSequentialProgressWatchdog(slot: slot, generation: generation)
        } else if claim.role == .urgentPlayback {
            urgentReceivedBytes[slot] = 0
            urgentHedgeRequested.remove(slot)
            armUrgentFirstByteHedge(slot: slot, generation: generation)
        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
            startupMetadataStartedAt[slot] = Date()
            armStartupMetadataStragglerWatchdog(slot: slot, generation: generation)
        }
        rangeMap.setDownloading(claim.range, lane: "slot\(slot)")
        metricsValue.activeRequestCount = slotTasks.count + 1
        metricsValue.networkRequestCount += 1
        DiagnosticsLogger.shared.log(
            "UnifiedSlot",
            "slot=\(slot) start role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) reason=\(reason) anchor=\(playbackAnchor)"
        )

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performFetch(slot: slot, generation: generation, claim: claim)
        }
        slotTasks[slot] = task
    }

    private func performFetch(slot: Int, generation: Int, claim: SlotClaim) async {
        guard !stopped, var resolved = resource, let store else {
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: nil, error: MediaTransportError.cancelled)
            return
        }
        var receivedForClaim: Int64 = 0
        do {
            let started = Date()
            if claim.role == .sequential {
                while receivedForClaim < Int64(claim.range.count) {
                    try Task.checkCancellation()
                    let remaining = (claim.range.lowerBound + receivedForClaim)..<claim.range.upperBound
                    let attemptStarted = Date()
                    var attemptReceived: Int64 = 0
                    do {
                        for try await chunk in client.stream(resource: resolved, range: remaining, worker: slot) {
                            try Task.checkCancellation()
                            let writeOffset = claim.range.lowerBound + receivedForClaim
                            try store.write(chunk, at: writeOffset)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            recordNetworkBytes(Int64(chunk.count))
                            rangeMap.insertPlayback(writeOffset..<min(claim.range.upperBound, writeOffset + Int64(chunk.count)))
                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) first-chunk role=sequential range=\(remaining.lowerBound)-\(remaining.upperBound) bytes=\(chunk.count) ms=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(Double(chunk.count) / firstChunkSeconds))")
                            }
                            observeSequentialChunk(slot: slot, generation: generation, bytes: Int64(chunk.count))
                            try Task.checkCancellation()
                            refreshMetrics(resource: resolved)
                        }
                    } catch MediaTransportError.expiredURL {
                        DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\(slot) refreshing expired 115 URL")
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    break
                }
                let elapsed = max(Date().timeIntervalSince(started), 0.001)
                let bps = Double(receivedForClaim) / elapsed
                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) finish role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) bytes=\(receivedForClaim) speedBps=\(Int(bps)) progressive=true longRange=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil, completedSequentialBps: bps)
            } else {
                var slowStartupRefreshUsed = false
                while receivedForClaim < Int64(claim.range.count) {
                    let remaining = (claim.range.lowerBound + receivedForClaim)..<claim.range.upperBound
                    let attemptStarted = Date()
                    var attemptReceived: Int64 = 0
                    var restartAfterSlowStartup = false
                    do {
                        for try await chunk in client.stream(resource: resolved, range: remaining, worker: slot) {
                            try Task.checkCancellation()
                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            if claim.role == .urgentPlayback { urgentReceivedBytes[slot] = receivedForClaim }
                            if claim.role == .startupMetadata {
                                startupMetadataReceivedBytes[slot] = receivedForClaim
                                startupMetadataLastProgressAt[slot] = Date()
                            }
                            recordNetworkBytes(Int64(chunk.count))
                            let writtenLower = claim.range.lowerBound + receivedForClaim - Int64(chunk.count)
                            let written = writtenLower..<min(claim.range.upperBound, writtenLower + Int64(chunk.count))
                            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }
                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                let firstChunkBps = Double(chunk.count) / firstChunkSeconds
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) first-chunk role=\(claim.role.rawValue) range=\(remaining.lowerBound)-\(remaining.upperBound) bytes=\(chunk.count) ms=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(firstChunkBps))")
                                if claim.role == .urgentPlayback { resolveUrgentRaceWinner(slot: slot, generation: generation, claim: claim) }
                                if claim.role == .metadata, !slowStartupRefreshUsed, Date().timeIntervalSince(createdAt) < 35, firstChunkSeconds >= startupMetadataSlowFirstChunkSeconds, firstChunkBps < startupMetadataSlowFirstChunkBps {
                                    slowStartupRefreshUsed = true
                                    restartAfterSlowStartup = true
                                    DiagnosticsLogger.shared.log("UnifiedRecovery", "slow-start metadata firstChunkMs=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(firstChunkBps)) received=\(receivedForClaim) action=refresh-115-source-and-resume")
                                    break
                                }
                            }
                            refreshMetrics(resource: resolved)
                        }
                    } catch MediaTransportError.expiredURL {
                        DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\(slot) refreshing expired 115 URL")
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    if restartAfterSlowStartup {
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    break
                }
                let elapsed = max(Date().timeIntervalSince(started), 0.001)
                let bps = Double(receivedForClaim) / elapsed
                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) finish role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) bytes=\(receivedForClaim) speedBps=\(Int(bps)) streamed=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil)
            }
        } catch is CancellationError {
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: MediaTransportError.cancelled)
        } catch {
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: error)
        }
    }

    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?, completedSequentialBps: Double? = nil) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\(slot)")

        let startupRetry = startupMetadataRetryRequested.remove(slot) != nil
        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        let refreshSource = liveLaneSourceRefreshPending.contains(slot)
        let urgentRaceReset = urgentRaceResetPending.remove(slot) != nil
        urgentReceivedBytes[slot] = 0
        urgentHedgeRequested.remove(slot)
        if urgentRaceReset {
            let reset = client.resetStreamLane(worker: slot, reason: "urgent-race-loser")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            laneHealth[slot] = LaneHealthState()
            DiagnosticsLogger.shared.log("UnifiedHedge", "slot=\(slot) action=reset-race-loser success=\(reset) pending=\(!reset)")
        } else if startupRetry {
            startupMetadataQueue.insert(claim.range, at: 0)
            let reset = client.resetStreamLane(worker: slot, reason: "startup-metadata-straggler")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\(slot) action=straggler-reset range=\(claim.range.lowerBound)-\(claim.range.upperBound) success=\(reset)")
        } else if liveRotation {
            let reset = client.resetStreamLane(worker: slot, reason: "live-lane-rotation")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            var live = liveLaneState[slot] ?? LiveLaneState()
            live.badSince = .distantPast
            if refreshSource {
                live.peakBps = 0
                live.lastHealthyBps = 0
                live.rotationCount = 0
                live.lastRotationAt = .distantPast
            }
            liveLaneState[slot] = live
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-after-cancel success=\(reset) pending=\(!reset) sourceRefresh=\(refreshSource)")
            laneHealth[slot] = LaneHealthState()
            if refreshSource { Task { [weak self] in await self?.refreshResolvedSourceAfterLaneRotation(slot: slot) } }
        } else if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if claim.role == .startupMetadata, error == nil, let plan = startupMetadataPlanRange, startupMetadataQueue.isEmpty, !slotClaims.values.contains(where: { $0.role == .startupMetadata }), store?.contains(plan) == true {
            startupMetadataPlanCompleted = true
            DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan complete range=\(plan.lowerBound)-\(plan.upperBound) bytes=\(plan.count)")
        }

        if let downloadedBytes, downloadedBytes > 0 {
            let written = claim.range.lowerBound..<min(claim.range.upperBound, claim.range.lowerBound + downloadedBytes)
            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) }
            else { rangeMap.insertPlayback(written) }
            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
                if claim.range.lowerBound == 0, Int64(claim.range.count) <= largeFileInitialSequentialBlockBytes, source.mediaSource.normalizedContainer == "mp4", (resource?.contentLength ?? 0) >= 4 * 1_073_741_824 {
                    startupTailDemandGraceUntil = Date().addingTimeInterval(startupTailDemandGraceSeconds)
                    DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\(claim.range.lowerBound)-\(claim.range.upperBound) action=await-actual-tail-demand graceMs=\(Int(startupTailDemandGraceSeconds * 1000))")
                    armStartupTailGraceResume()
                }
            }
            if (claim.role == .metadata || claim.role == .startupMetadata), downloadedBytes >= Int64(claim.range.count), !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after critical metadata")
            }
            if slot == 0, claim.role == .urgentPlayback, downloadedBytes >= Int64(claim.range.count), pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[1]?.role != .metadata, !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after urgent playback settled")
            }
            if slot == 1 { secondaryFailureCount = 0 }
        }

        if let error, !isCancellation(error) {
            if claim.role == .startupMetadata { startupMetadataQueue.insert(claim.range, at: 0) }
            else if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }
            metricsValue.rangeFailureCount += 1
            DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) failed role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) error=\(error.localizedDescription)")
            if slot == 1 {
                secondaryFailureCount += 1
                let delay = min(30.0, 4.0 * Double(max(1, secondaryFailureCount)))
                secondaryCooldownUntil = Date().addingTimeInterval(delay)
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await self?.resumeAfterSecondaryCooldown()
                }
            }
        }

        if let resource { refreshMetrics(resource: resource) }
        scheduleSlots(reason: "slot-finished")
    }

    private func refreshResolvedSourceAfterLaneRotation(slot: Int) async {
        guard !stopped else { return }
        let snapshot = source
        do {
            let refreshed = try await resolver.resolve(source: snapshot)
            guard refreshed.supportsByteRanges else { throw MediaTransportError.rangeUnsupported(statusCode: 200) }
            resource = refreshed
            liveLaneSourceRefreshPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=refresh-115-source-success bytes=\(refreshed.contentLength)")
            scheduleSlots(reason: "live-lane-source-refreshed")
        } catch {
            liveLaneSourceRefreshPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=refresh-115-source-failed error=\(error.localizedDescription)")
            scheduleSlots(reason: "live-lane-source-refresh-failed")
        }
    }

    private func armStartupMetadataStragglerWatchdog(slot: Int, generation: Int) {
        let delay = liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkStartupMetadataStraggler(slot: slot, generation: generation)
        }
    }

    private func checkStartupMetadataStraggler(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .startupMetadata, startupMetadataReceivedBytes[slot, default: 0] == 0, !startupMetadataRetryRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let startedAt = startupMetadataStartedAt[slot, default: .distantPast]
        let peerProgressAt = startupMetadataLastProgressAt[peerSlot, default: .distantPast]
        guard peerProgressAt > startedAt else { return }
        startupMetadataRetryRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\(slot) action=straggler-cancel peer=\(peerSlot) peerProgressMsAgo=\(Int(Date().timeIntervalSince(peerProgressAt) * 1000)) range=\(slotClaims[slot]?.range.description ?? "none")")
        cancelSlot(slot, reason: "startup-metadata-straggler")
    }

    private func armStartupTailGraceResume() {
        guard !startupTailGraceResumeScheduled else { return }
        startupTailGraceResumeScheduled = true
        let delay = startupTailDemandGraceSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.resumeAfterStartupTailGrace()
        }
    }

    private func resumeAfterStartupTailGrace() {
        startupTailGraceResumeScheduled = false
        guard !stopped, startupMetadataPlanRange == nil, Date() >= startupTailDemandGraceUntil else { return }
        scheduleSlots(reason: "startup-tail-grace-ended")
    }

    private func armLiveLaneResetRetry(slot: Int, attempt: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await self?.retryLiveLaneReset(slot: slot, attempt: attempt)
        }
    }

    private func retryLiveLaneReset(slot: Int, attempt: Int) {
        guard liveLaneResetPending.contains(slot), !stopped else { return }
        if client.resetStreamLane(worker: slot, reason: "live-lane-retry-\(attempt)") {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-retry success=true attempt=\(attempt)")
            scheduleSlots(reason: "live-lane-reset-ready")
            return
        }
        if attempt < 10 { armLiveLaneResetRetry(slot: slot, attempt: attempt + 1) }
        else {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-retry give-up attempt=\(attempt)")
            scheduleSlots(reason: "live-lane-reset-give-up")
        }
    }

    private func armUrgentFirstByteHedge(slot: Int, generation: Int) {
        Task { [weak self] in
            let delay = self?.urgentFirstByteHedgeSeconds ?? 0.65
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkUrgentFirstByteHedge(slot: slot, generation: generation)
        }
    }

    private func checkUrgentFirstByteHedge(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, let claim = slotClaims[slot], claim.role == .urgentPlayback, urgentReceivedBytes[slot, default: 0] == 0, !urgentHedgeRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard let peerClaim = slotClaims[peerSlot], peerClaim.role == .sequential, !liveLaneResetPending.contains(peerSlot), !liveLaneSourceRefreshPending.contains(peerSlot) else { return }
        urgentHedgeRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedHedge", "slot=\(slot) peer=\(peerSlot) action=hedge-urgent-first-byte afterMs=\(Int(urgentFirstByteHedgeSeconds * 1000)) range=\(claim.range.lowerBound)-\(claim.range.upperBound) peerRange=\(peerClaim.range.lowerBound)-\(peerClaim.range.upperBound)")
        installUrgent(range: claim.range, metadata: false, reason: "urgent-first-byte-hedge")
        scheduleSlots(reason: "urgent-first-byte-hedge")
    }

    private func resolveUrgentRaceWinner(slot: Int, generation: Int, claim: SlotClaim) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .urgentPlayback else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard let peerClaim = slotClaims[peerSlot], peerClaim.role == .urgentPlayback, peerClaim.range == claim.range else { return }
        urgentRaceResetPending.insert(peerSlot)
        DiagnosticsLogger.shared.log("UnifiedHedge", "winner=\(slot) loser=\(peerSlot) action=urgent-race-won range=\(claim.range.lowerBound)-\(claim.range.upperBound)")
        cancelSlot(peerSlot, reason: "urgent-race-lost")
    }

    private func armSequentialProgressWatchdog(slot: Int, generation: Int) {
        Task { [weak self] in
            let delay = self?.liveLaneProgressWatchdogIntervalSeconds ?? 0.75
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkSequentialProgressWatchdog(slot: slot, generation: generation)
        }
    }

    private func checkSequentialProgressWatchdog(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, !liveLaneRotationRequested.contains(slot) else { return }
        let now = Date()
        if live.receivedBytes > 0 {
            let stalledSeconds = now.timeIntervalSince(live.lastChunkAt)
            let peerSlot = slot == 0 ? 1 : 0
            let peerLive = liveLaneState[peerSlot]
            let peerCompleted = laneHealth[peerSlot]
            let peerFresh = peerLive.map { $0.recentBps > 0 && now.timeIntervalSince($0.lastSampleAt) <= 2.5 } ?? false
            let peerBps = peerFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
            if stalledSeconds >= liveLaneNoProgressPeerSeconds, peerBps >= 2 * 1_048_576 {
                DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=midstream-no-progress stalledMs=\(Int(stalledSeconds * 1000)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
                requestLiveLaneRotation(slot: slot, generation: generation, reason: "midstream-no-progress-peer-fast", observedBps: live.recentBps, peerBps: peerBps)
                return
            }
            if stalledSeconds >= liveLaneNoProgressHardSeconds {
                DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=midstream-hard-timeout stalledMs=\(Int(stalledSeconds * 1000)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
                requestLiveLaneRotation(slot: slot, generation: generation, reason: "midstream-no-progress-hard", observedBps: live.recentBps, peerBps: peerBps)
                return
            }
        }
        armSequentialProgressWatchdog(slot: slot, generation: generation)
    }

    private func armFirstByteWatchdog(slot: Int, generation: Int) {
        let peerDelay = liveLaneFirstBytePeerTimeoutSeconds
        let hardDelay = liveLaneFirstByteHardTimeoutSeconds - liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(peerDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: false)
            try? await Task.sleep(nanoseconds: UInt64(hardDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: true)
        }
    }

    private func checkFirstByteWatchdog(slot: Int, generation: Int, hard: Bool) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, live.receivedBytes == 0 else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let now = Date()
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps: Double
        if let peerLive, peerLiveFresh {
            let elapsed = max(now.timeIntervalSince(peerLive.startedAt), 0.001)
            peerBps = peerLive.recentBps > 0 ? peerLive.recentBps : Double(peerLive.receivedBytes) / elapsed
        } else {
            peerBps = peerCompleted?.averageBps ?? 0
        }
        guard hard || peerBps >= 2 * 1_048_576 else { return }
        requestLiveLaneRotation(slot: slot, generation: generation, reason: hard ? "first-byte-hard-timeout" : "first-byte-peer-fast", observedBps: 0, peerBps: peerBps)
    }

    private func observeSequentialChunk(slot: Int, generation: Int, bytes: Int64) {
        guard bytes > 0, slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential else { return }
        let now = Date()
        var live = liveLaneState[slot] ?? LiveLaneState()
        guard live.generation == generation else { return }
        live.lastChunkAt = now
        live.receivedBytes += bytes
        let sampleSeconds = now.timeIntervalSince(live.sampleWindowStartedAt)
        let sampleBytes = live.receivedBytes - live.sampleWindowStartedBytes
        guard sampleSeconds >= liveLaneSampleWindowSeconds, sampleBytes >= liveLaneSampleMinimumBytes else {
            liveLaneState[slot] = live
            return
        }
        let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)
        live.sampleWindowStartedAt = now
        live.sampleWindowStartedBytes = live.receivedBytes
        live.lastSampleAt = now
        live.recentBps = live.recentBps == 0 ? windowBps : live.recentBps * 0.60 + windowBps * 0.40
        live.peakBps = max(windowBps, live.peakBps * 0.92)
        if windowBps >= max(liveLanePeerFloorBps, live.peakBps * 0.55) { live.lastHealthyBps = max(windowBps, live.lastHealthyBps * 0.80) }

        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerLiveFresh = peerLive.map { $0.recentBps > 0 && now.timeIntervalSince($0.lastSampleAt) <= 2.5 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : 0
        let relativeSlow = peerLiveFresh && peerBps >= liveLanePeerFloorBps && live.recentBps < peerBps * liveLaneRelativeFloor
        let absoluteFloorBps = NetworkPathMonitor.shared.isCellular ? liveLaneAbsoluteFloorBps : liveLaneWifiAbsoluteFloorBps
        let absoluteSlow = now.timeIntervalSince(live.startedAt) >= 3.0 && live.receivedBytes >= 4 * 1_048_576 && live.recentBps < absoluteFloorBps
        let peakRelativeSlow = live.peakBps >= liveLanePeakFloorBps && windowBps < live.peakBps * liveLanePeakRelativeFloor
        if peakRelativeSlow { if live.badSince == .distantPast { live.badSince = now } }
        else { live.badSince = .distantPast }
        let peakDropSeconds = live.badSince == .distantPast ? 0 : now.timeIntervalSince(live.badSince)
        let sustainedPeakDrop = peakRelativeSlow && peakDropSeconds >= liveLanePeakDropSeconds
        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(absoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
        liveLaneState[slot] = live
        let peakRatio = live.peakBps > 0 ? windowBps / live.peakBps : 1
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) windowMs=\(Int(sampleSeconds * 1000)) windowBytes=\(sampleBytes) sampleBps=\(Int(windowBps)) avgBps=\(Int(live.recentBps)) peakBps=\(Int(live.peakBps)) healthyBps=\(Int(live.lastHealthyBps)) peakRatio=\(String(format: "%.2f", peakRatio)) badMs=\(Int(peakDropSeconds * 1000)) peerBps=\(Int(peerBps)) slowStreak=\(live.slowStreak)")

        if sustainedPeakDrop { requestLiveLaneRotation(slot: slot, generation: generation, reason: "peak-collapse", observedBps: windowBps, peerBps: peerBps) }
        else if live.slowStreak >= 2 { requestLiveLaneRotation(slot: slot, generation: generation, reason: relativeSlow ? "rolling-relative-slow" : "rolling-absolute-slow", observedBps: live.recentBps, peerBps: peerBps) }
    }

    private func requestLiveLaneRotation(slot: Int, generation: Int, reason: String, observedBps: Double, peerBps: Double) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, !liveLaneRotationRequested.contains(slot) else { return }
        var live = liveLaneState[slot] ?? LiveLaneState()
        let now = Date()
        guard now >= live.resetCooldownUntil else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard !liveLaneRotationRequested.contains(peerSlot), !liveLaneResetPending.contains(peerSlot), !liveLaneSourceRefreshPending.contains(peerSlot) else { return }
        if now.timeIntervalSince(live.lastRotationAt) > liveLaneRotationEscalationWindowSeconds { live.rotationCount = 0 }
        live.rotationCount += 1
        live.lastRotationAt = now
        live.resetCooldownUntil = now.addingTimeInterval(liveLaneResetCooldownSeconds)
        let refreshSource = live.rotationCount >= 2
        if refreshSource { liveLaneSourceRefreshPending.insert(slot) }
        liveLaneState[slot] = live
        liveLaneRotationRequested.insert(slot)
        if preferredBulkSlot == slot { preferredBulkSlot = slot == 0 ? 1 : 0 }
        let stage = refreshSource ? "refresh-302" : "reset-session"
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=rotate-live-lane stage=\(stage) rotation=\(live.rotationCount) reason=\(reason) observedBps=\(Int(observedBps)) peakBps=\(Int(live.peakBps)) healthyBps=\(Int(live.lastHealthyBps)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
        cancelSlot(slot, reason: "live-lane-rotation-\(stage)")
    }

    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {
        guard bytes >= laneHealthMinSampleBytes, bps > 0 else { return }
        let now = Date()
        let peerSlot = slot == 0 ? 1 : 0
        var current = laneHealth[slot] ?? LaneHealthState()
        let peer = laneHealth[peerSlot] ?? LaneHealthState()
        let peerIsFresh = peer.samples > 0 && now.timeIntervalSince(peer.lastSampleAt) <= laneHealthPeerFreshSeconds

        current.averageBps = current.samples == 0 ? bps : current.averageBps * 0.65 + bps * 0.35
        current.samples += 1
        current.lastSampleAt = now
        current.slowStreak = 0
        laneHealth[slot] = current

        if peerIsFresh {
            if current.averageBps >= peer.averageBps * 1.20, preferredBulkSlot != slot {
                preferredBulkSlot = slot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\(slot) avgBps=\(Int(current.averageBps)) peerAvgBps=\(Int(peer.averageBps))")
            } else if peer.averageBps >= current.averageBps * 1.20, preferredBulkSlot == slot {
                preferredBulkSlot = peerSlot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\(peerSlot) avgBps=\(Int(peer.averageBps)) peerAvgBps=\(Int(current.averageBps))")
            }
        }

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\(slot) sampleBps=\(Int(bps)) avgBps=\(Int(current.averageBps)) peer=\(peerSlot) peerAvgBps=\(Int(peer.averageBps)) peerFresh=\(peerIsFresh) action=advisory-only protectedBulk=\(preferredBulkSlot)")
    }

    private func resumeAfterSecondaryCooldown() {
        guard !stopped else { return }
        scheduleSlots(reason: "secondary-cooldown-ended")
    }

    private func cancelSlot(_ slot: Int, reason: String) {
        guard let task = slotTasks[slot] else { return }
        DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) cancel reason=\(reason) claim=\(slotClaims[slot]?.range.description ?? "none")")
        task.cancel()
    }

    private func recordNetworkBytes(_ bytes: Int64) {
        guard bytes > 0 else { return }
        metricsValue.bytesDownloaded += bytes
        speedSamples.append(SpeedSample(date: Date(), bytes: bytes))
        pruneSpeedSamples()
    }

    private func refreshMetrics(resource: TransportResolvedResource) {
        guard let store else { return }
        let center = min(max(0, cacheWindowCenter), max(0, resource.contentLength - 1))
        let map = rangeMap.snapshot(anchor: center, resourceLength: resource.contentLength)
        metricsValue.resourceBytes = resource.contentLength
        metricsValue.cacheBytes = store.uniqueBytes
        metricsValue.diskCacheBytes = store.uniqueBytes
        metricsValue.contiguousCacheBytes = map.frontierByte > center ? map.frontierByte - center : 0
        metricsValue.metadataCacheBytes = map.metadataBytes
        metricsValue.sparsePlaybackCacheBytes = map.playbackBytes
        metricsValue.cacheHoleCount = map.holeCount
        metricsValue.schedulerAnchorByte = center
        metricsValue.schedulerFrontierByte = map.frontierByte
        metricsValue.activeRequestCount = slotTasks.count
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        pruneSpeedSamples()
        let speedWindow = max(1, Date().timeIntervalSince(speedSamples.first?.date ?? Date()))
        metricsValue.currentDownloadBytesPerSecond = speedSamples.isEmpty ? 0 : Double(speedSamples.reduce(Int64(0)) { $0 + $1.bytes }) / speedWindow

        if Date().timeIntervalSince(lastMetricsLogAt) >= 2 {
            lastMetricsLogAt = Date()
            let slot0 = slotClaims[0]?.range.description ?? "idle"
            let slot1 = slotClaims[1]?.range.description ?? "idle"
            let window = preloadWindowBytes()
            let forwardUpper = min(resource.contentLength, safeAdd(center, window))
            let backwardLower = max(0, center - window)
            let forwardCached = forwardUpper > center ? rangeMap.playbackBytes(in: center..<forwardUpper) : 0
            let backwardCached = center > backwardLower ? rangeMap.playbackBytes(in: backwardLower..<center) : 0
            DiagnosticsLogger.shared.log(
                "UnifiedMap",
                "anchor=\(playbackAnchor) center=\(center) frontier=\(map.frontierByte) contiguous=\(metricsValue.contiguousCacheBytes) forwardCached=\(forwardCached) backwardCached=\(backwardCached) window=\(window) cached=\(metricsValue.cacheBytes) metadata=\(map.metadataBytes) holes=\(map.holeCount) refill=\(cacheRefillActive) emergency=\(cacheEmergencyActive) starving=\(playbackStarving) advancing=\(playbackAdvancing) slot0=\(slot0) slot1=\(slot1) networkBps=\(Int(metricsValue.currentDownloadBytesPerSecond)) resumeGate=\(awaitingInitialResumeDemand)"
            )
        }
    }

    private func pruneSpeedSamples() {
        let cutoff = Date().addingTimeInterval(-6)
        speedSamples.removeAll { $0.date < cutoff }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let transportError = error as? MediaTransportError, case .cancelled = transportError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func initialResumeHeadGuardBytes(resourceLength: Int64) -> Int64 {
        guard resourceLength > 0 else { return initialResumeMaximumHeadGuardBytes }
        let proportional = max(initialResumeMinimumHeadGuardBytes, resourceLength / 100)
        return min(initialResumeMaximumHeadGuardBytes, proportional)
    }

    private func preloadWindowBytes() -> Int64 {
        if NetworkPathMonitor.shared.isCellular { return max(0, configuration.cellularPreloadBytes) }
        return max(0, configuration.wifiPreloadBytes)
    }

    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        if let plan = startupMetadataPlanRange, range.upperBound > plan.lowerBound, range.lowerBound < plan.upperBound { return true }
        guard Date().timeIntervalSince(createdAt) < 35 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
    }

    private func isMetadataProbe(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty else { return false }
        let nearTail = resource.contentLength > 64 * 1_048_576 && range.lowerBound >= resource.contentLength - 64 * 1_048_576
        let tinyProbe = range.count <= 64 * 1024 && range.lowerBound > max(8 * 1_048_576, cacheWindowCenter + 2 * blockBytes)
        return nearTail || tinyProbe
    }

    private func clamp(range: Range<Int64>, contentLength: Int64) -> Range<Int64> {
        let lower = min(max(0, range.lowerBound), contentLength)
        let upper = min(max(lower, range.upperBound), contentLength)
        return lower..<upper
    }

    private func alignDown(_ value: Int64, alignment: Int64) -> Int64 {
        guard alignment > 0 else { return value }
        return max(0, (value / alignment) * alignment)
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        if rhs > 0, lhs > Int64.max - rhs { return Int64.max }
        return lhs + rhs
    }
}
