from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"anchor missing: {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


# 1) Raw demux byte reads are dependencies only. Playback clock progress is the authority gate.
Path("Sources/Transport/PlaybackDemandCoordinator.swift").write_text(r'''import Foundation

/// Separates demux byte dependencies from the authoritative rolling-cache playback head.
///
/// Engines/demuxers may jump between audio/video/index byte regions at high frequency. Those reads
/// must be served urgently, but they do not move the rolling cache by themselves. The cache head is
/// allowed to advance only when the engine's media clock is also making forward playback progress.
/// No time-to-byte ratio is used: media time is only an authority gate, while byte locations always
/// come from real reads.
struct PlaybackDemandCoordinator {
    enum Decision: Equatable {
        case hold
        case advance(offset: Int64)
        case promote(offset: Int64, reason: String)
    }

    private struct DependencySample {
        let date: Date
        let offset: Int64
    }

    private struct FarCandidate {
        var offset: Int64
        var confirmations: Int
        var lastAt: Date
    }

    private var dependencies: [DependencySample] = []
    private var lastPlaybackPosition: Double?
    private var farCandidate: FarCandidate?
    private let dependencyRetentionSeconds: TimeInterval = 1.5
    private let maximumDependencySamples = 256

    mutating func reset() {
        dependencies.removeAll(keepingCapacity: true)
        lastPlaybackPosition = nil
        farCandidate = nil
    }

    mutating func observeDependency(offset: Int64, now: Date = Date()) {
        guard offset >= 0 else { return }
        dependencies.append(DependencySample(date: now, offset: offset))
        prune(now: now)
        if dependencies.count > maximumDependencySamples { dependencies.removeFirst(dependencies.count - maximumDependencySamples) }
    }

    mutating func confirmPlaybackProgress(position: Double, isBuffering: Bool, activeCenter: Int64, nearDistance: Int64, now: Date = Date()) -> Decision {
        guard position.isFinite, position >= 0 else { return .hold }
        prune(now: now)

        guard let previousPosition = lastPlaybackPosition else {
            lastPlaybackPosition = position
            return .hold
        }
        if position < previousPosition - 0.35 {
            lastPlaybackPosition = position
            farCandidate = nil
            return .hold
        }
        guard !isBuffering, position - previousPosition >= 0.10 else { return .hold }
        lastPlaybackPosition = position

        guard let candidate = dependencies.map(\.offset).min(), candidate > activeCenter else {
            farCandidate = nil
            return .hold
        }

        let distance = candidate - activeCenter
        let nearLimit = max(8 * 1_048_576, nearDistance)
        if distance <= nearLimit {
            farCandidate = nil
            return .advance(offset: candidate)
        }

        let clusterTolerance = max(1 * 1_048_576, nearLimit / 2)
        if var current = farCandidate,
           now.timeIntervalSince(current.lastAt) <= 1.5,
           abs(candidate - current.offset) <= clusterTolerance {
            current.offset = min(current.offset, candidate)
            current.confirmations += 1
            current.lastAt = now
            farCandidate = current
        } else {
            farCandidate = FarCandidate(offset: candidate, confirmations: 1, lastAt: now)
        }

        guard let confirmed = farCandidate, confirmed.confirmations >= 3 else { return .hold }
        farCandidate = nil
        return .promote(offset: confirmed.offset, reason: "engine-clock-confirmed-byte-demand")
    }

    private mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-dependencyRetentionSeconds)
        dependencies.removeAll { $0.date < cutoff }
    }
}
''')

# 2) Transport protocol receives engine-clock progress separately from byte reads.
replace_once(
    "Sources/Transport/TransportDataSession.swift",
    "    func confirmConcretePlaybackByte(_ offset: Int64) async\n    func recoverStall(position: Double, duration: Double) async\n",
    "    func confirmConcretePlaybackByte(_ offset: Int64) async\n    func reportPlaybackProgress(position: Double, isBuffering: Bool) async\n    func recoverStall(position: Double, duration: Double) async\n",
)
replace_once(
    "Sources/Transport/TransportDataSession.swift",
    "    func confirmConcretePlaybackByte(_ offset: Int64) async {}\n    func recoverStall(position: Double, duration: Double) async {}\n",
    "    func confirmConcretePlaybackByte(_ offset: Int64) async {}\n    func reportPlaybackProgress(position: Double, isBuffering: Bool) async {}\n    func recoverStall(position: Double, duration: Double) async {}\n",
)

# 3) Transport health carries recent network failure age so EOF is jointly judged by engine+transport.
replace_once(
    "Sources/Transport/TransportTypes.swift",
    "    var rangeFailureCount: Int = 0\n    var activeRequestCount: Int = 0\n",
    "    var rangeFailureCount: Int = 0\n    var recentNetworkFailureAgeSeconds: Double = .infinity\n    var activeRequestCount: Int = 0\n",
)

# 4) UnifiedTransport: raw reads feed dependency observations, not rolling-center movement.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "    private var playbackDemandSamples: [PlaybackDemandSample] = []\n    private var sequentialWaveUpperBound: Int64 = 0\n",
    "    private var playbackDemandSamples: [PlaybackDemandSample] = []\n    private var lastNetworkFailureAt = Date.distantPast\n    private var sequentialWaveUpperBound: Int64 = 0\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "        pendingUserSeekPosition = max(0, position)\n        pendingUserSeekDuration = max(0, duration)\n",
    "        pendingUserSeekPosition = max(0, position)\n        pendingUserSeekDuration = max(0, duration)\n        demandCoordinator.reset()\n",
)

# Observe dependency once per actual read path; center authority is handled by reportPlaybackProgress().
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "        let concretePlaybackDemand = concreteReason && !metadata\n        if awaitingInitialResumeDemand, concretePlaybackDemand, reason == \"concrete-read\" || reason == \"blocked-read\" { initialResumeCandidateByte = range.lowerBound }\n",
    "        let concretePlaybackDemand = concreteReason && !metadata\n        if concretePlaybackDemand { demandCoordinator.observeDependency(offset: range.lowerBound) }\n        if awaitingInitialResumeDemand, concretePlaybackDemand, reason == \"concrete-read\" || reason == \"blocked-read\" { initialResumeCandidateByte = range.lowerBound }\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "        if concretePlaybackDemand, !resumeHistoricalDependency { recordPlaybackDemand(offset: range.lowerBound) }\n",
    "",
)

# Remove raw-read-driven center promotion entirely.
old_raw_promotion = r'''        if concretePlaybackDemand, !reanchored, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil {
            switch demandCoordinator.observe(offset: range.lowerBound, activeCenter: cacheWindowCenter, nearDistance: blockBytes * 4, starving: playbackStarving) {
            case .nearHead:
                advanceCacheWindowCenterFromRecentDemand(resource: resource)
            case .holdCandidate(let samples):
                if samples == 1 {
                    DiagnosticsLogger.shared.playback("PlaybackDemand", "candidate center=\(cacheWindowCenter) offset=\(range.lowerBound) starving=\(playbackStarving) reason=\(reason)")
                }
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

'''
replace_once("Sources/Transport/UnifiedMediaTransportSession.swift", old_raw_promotion, "")

# Add engine-clock authority method before recoverStall.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "    func recoverStall(position: Double, duration: Double) async {\n",
    r'''    func reportPlaybackProgress(position: Double, isBuffering: Bool) async {
        guard !stopped, let resource, !awaitingInitialResumeDemand, Date() > pendingUserSeekUntil else { return }
        switch demandCoordinator.confirmPlaybackProgress(position: position, isBuffering: isBuffering, activeCenter: cacheWindowCenter, nearDistance: blockBytes * 4) {
        case .hold:
            return
        case .advance(let offset):
            let clamped = min(max(0, offset), max(0, resource.contentLength - 1))
            guard clamped > cacheWindowCenter else { return }
            let previous = cacheWindowCenter
            cacheWindowCenter = clamped
            playbackAnchor = clamped
            cacheRefillActive = true
            recordPlaybackDemand(offset: clamped)
            DiagnosticsLogger.shared.playback("PlaybackByteAuthority", "action=advance previous=\(previous) new=\(clamped) mediaPosition=\(String(format: "%.3f", position)) source=engine-clock+real-byte")
            scheduleSlots(reason: "playback-byte-authority-advance")
        case .promote(let offset, let reason):
            let clamped = min(max(0, offset), max(0, resource.contentLength - 1))
            let previous = cacheWindowCenter
            playbackAnchor = clamped
            playbackDemandSamples.removeAll()
            recordPlaybackDemand(offset: clamped)
            resetCacheWindowCenter(to: clamped, resource: resource, reason: reason)
            DiagnosticsLogger.shared.playback("PlaybackByteAuthority", "action=promote previous=\(previous) new=\(clamped) mediaPosition=\(String(format: "%.3f", position)) reason=\(reason)")
            for slot in [0, 1] {
                guard let active = slotClaims[slot], !active.range.contains(clamped) else { continue }
                if active.role == .sequential || active.role == .urgentPlayback { cancelSlot(slot, reason: "clock-authority-promoted") }
            }
            scheduleSlots(reason: "playback-byte-authority-promote")
        }
    }

    func recoverStall(position: Double, duration: Double) async {
''',
)

# Old raw-demand center advancement is no longer a valid authority path.
old_advance = r'''    private func advanceCacheWindowCenterFromRecentDemand(resource: TransportResolvedResource) {
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

'''
replace_once("Sources/Transport/UnifiedMediaTransportSession.swift", old_advance, "")

# Record real upstream failure time for EOF health arbitration.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "            metricsValue.rangeFailureCount += 1\n            DiagnosticsLogger.shared.log(\n",
    "            metricsValue.rangeFailureCount += 1\n            lastNetworkFailureAt = Date()\n            DiagnosticsLogger.shared.log(\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "        metricsValue.activeRequestCount = slotTasks.count\n        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)\n",
    "        metricsValue.activeRequestCount = slotTasks.count\n        metricsValue.recentNetworkFailureAgeSeconds = lastNetworkFailureAt == .distantPast ? .infinity : max(0, Date().timeIntervalSince(lastNetworkFailureAt))\n        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)\n",
)

# 5) PlayerController reports real media-clock progress to UnifiedTransport at low frequency.
replace_once(
    "Sources/Player/PlayerController.swift",
    "    private var initialResumePlaybackBaseline: Double?\n",
    "    private var initialResumePlaybackBaseline: Double?\n    private var lastTransportPlaybackReportPosition: Double = -1\n    private var lastTransportPlaybackReportAt = Date.distantPast\n",
)
replace_once(
    "Sources/Player/PlayerController.swift",
    "                self.logBufferTimelineIfNeeded(value)\n",
    "                self.logBufferTimelineIfNeeded(value)\n                self.reportPlaybackClockToTransportIfNeeded(value)\n",
)
# Insert helper before initial resume confirmation.
replace_once(
    "Sources/Player/PlayerController.swift",
    "    private func confirmInitialResumePlaybackIfNeeded(_ value: PlayerSnapshot) {\n",
    r'''    private func reportPlaybackClockToTransportIfNeeded(_ value: PlayerSnapshot) {
        guard let session = transportContext?.session, value.position.isFinite else { return }
        let now = Date()
        let positionMoved = abs(value.position - lastTransportPlaybackReportPosition) >= 0.10
        let heartbeatDue = now.timeIntervalSince(lastTransportPlaybackReportAt) >= 0.50
        guard positionMoved || heartbeatDue else { return }
        lastTransportPlaybackReportPosition = value.position
        lastTransportPlaybackReportAt = now
        Task { await session.reportPlaybackProgress(position: value.position, isBuffering: value.isBuffering) }
    }

    private func confirmInitialResumePlaybackIfNeeded(_ value: PlayerSnapshot) {
''',
)
replace_once(
    "Sources/Player/PlayerController.swift",
    "        initialResumePlaybackBaseline = nil\n        let shouldReportStop = playbackSessionStarted\n",
    "        initialResumePlaybackBaseline = nil\n        lastTransportPlaybackReportPosition = -1\n        lastTransportPlaybackReportAt = .distantPast\n        let shouldReportStop = playbackSessionStarted\n",
)

# EOF now asks orchestrator to arbitrate with transport state.
replace_once(
    "Sources/Player/PlayerController.swift",
    "        switch orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason) {\n",
    "        switch orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason, snapshot: snapshot, metrics: lastTransportMetrics) {\n",
)

# 6) EOF acceptance gate: weak/recently-failed transport recovers in-place instead of rebuilding MDK.
replace_once(
    "Sources/Player/PlaybackOrchestrator.swift",
    r'''    func actionForPrematureEOF(kind: PlayerEngineKind, reason: String) -> PlaybackRecoveryAction {
        .reloadCurrent(reason: "疑似提前结束：\(reason)；保持当前引擎恢复")
    }
''',
    r'''    func actionForPrematureEOF(kind: PlayerEngineKind, reason: String, snapshot: PlayerSnapshot, metrics: TransportMetricsSnapshot?) -> PlaybackRecoveryAction {
        let duration = max(snapshot.duration, source.mediaSource.durationSeconds ?? 0)
        let farFromEnd = duration > 0 && snapshot.position + max(3, duration * 0.005) < duration
        let health = assessTransport(metrics: metrics)
        let recentFailure = (metrics?.recentNetworkFailureAgeSeconds ?? .infinity) <= 8
        let belowMediaRate = (metrics?.currentDownloadBytesPerSecond ?? 0) > 0 && (metrics?.currentDownloadBytesPerSecond ?? 0) < health.mediaBytesPerSecond * 1.10
        let transportStarved = snapshot.isBuffering || recentFailure || belowMediaRate || !health.transportHealthy
        DiagnosticsLogger.shared.playback("Orchestrator", "prematureEOF engine=\(kind.title) farFromEnd=\(farFromEnd) transportStarved=\(transportStarved) recentFailure=\(recentFailure) failureAge=\(String(format: "%.2f", metrics?.recentNetworkFailureAgeSeconds ?? .infinity)) networkBps=\(Int(metrics?.currentDownloadBytesPerSecond ?? 0)) mediaBps=\(Int(health.mediaBytesPerSecond)) reason=\(reason)")
        if farFromEnd && transportStarved {
            return .recoverTransport(message: "网络/缓存供给不足时出现提前 EOF，保持当前引擎并恢复当前位置数据，不重建播放器")
        }
        return .reloadCurrent(reason: "疑似提前结束：\(reason)；传输未显示饥饿，受控重载当前引擎")
    }
''',
)

# 7) Aggregate high-rate localhost diagnostics so enabling logs cannot amplify a demux churn incident.
replace_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "    private var lastLoggedRequestStart: Int64?\n    private var lastLoggedRequestAt = Date.distantPast\n",
    "    private var httpActivityRequests = 0\n    private var httpActivityCancels = 0\n    private var httpActivityLastStart: Int64?\n    private var httpActivityWindowStartedAt = Date.distantPast\n",
)
replace_once(
    "Sources/Transport/TransportHTTPServer.swift",
    r'''            let logRequest = shouldLogRequest(method: request.method, range: responseRange)
            if logRequest {
                DiagnosticsLogger.shared.log(
                    "TransportHTTP",
                    "server=\(logID) request method=\(request.method) status=\(status) start=\(responseRange.lowerBound) length=\(responseRange.length)"
                )
            }
''',
    r'''            let logRequest = recordHTTPActivity(requestStart: responseRange.lowerBound, cancelled: false)
            if logRequest {
                DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary())
            }
''',
)
replace_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "        } catch is CancellationError {\n            DiagnosticsLogger.shared.log(\"TransportHTTP\", \"server=\\(logID) response cancelled\")\n",
    "        } catch is CancellationError {\n            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback(\"TransportHTTPActivity\", activitySummary()) }\n",
)
old_should_log = r'''    private func shouldLogRequest(method: String, range: ByteRange) -> Bool {
        if method == "HEAD" || range.length <= 2 { return true }

        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        let movedEnough: Bool
        if let lastLoggedRequestStart {
            movedEnough = abs(range.lowerBound - lastLoggedRequestStart) >= 8 * 1_048_576
        } else {
            movedEnough = true
        }
        let timedOut = now.timeIntervalSince(lastLoggedRequestAt) >= 5
        guard movedEnough || timedOut else { return false }
        lastLoggedRequestStart = range.lowerBound
        lastLoggedRequestAt = now
        return true
    }

'''
new_should_log = r'''    private func recordHTTPActivity(requestStart: Int64?, cancelled: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if httpActivityWindowStartedAt == .distantPast { httpActivityWindowStartedAt = now }
        if requestStart != nil { httpActivityRequests += 1 }
        if cancelled { httpActivityCancels += 1 }
        if let requestStart { httpActivityLastStart = requestStart }
        return now.timeIntervalSince(httpActivityWindowStartedAt) >= 1
    }

    private func activitySummary() -> String {
        lock.lock()
        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(httpActivityWindowStartedAt))
        let requests = httpActivityRequests
        let cancels = httpActivityCancels
        let lastStart = httpActivityLastStart ?? -1
        let active = connections.count
        httpActivityRequests = 0
        httpActivityCancels = 0
        httpActivityWindowStartedAt = now
        lock.unlock()
        return "server=\(logID) windowMs=\(Int(elapsed * 1000)) requests=\(requests) cancels=\(cancels) requestRate=\(String(format: "%.1f", Double(requests) / elapsed))/s active=\(active) lastStart=\(lastStart)"
    }

'''
replace_once("Sources/Transport/TransportHTTPServer.swift", old_should_log, new_should_log)

# 8) Version only; deployment target remains iOS 15.0.
for path in ["project.mdklab.yml"]:
    p = Path(path)
    text = p.read_text()
    text = text.replace('MARKETING_VERSION: "0.13.15"', 'MARKETING_VERSION: "0.13.16"')
    text = text.replace('CURRENT_PROJECT_VERSION: "82"', 'CURRENT_PROJECT_VERSION: "83"')
    p.write_text(text)

print("Build83 playback-byte-authority source materialized")
