from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"target not found: {old[:120]!r}")
    text = text.replace(old, new, 1)


def replace_between(start: str, end: str, replacement: str) -> None:
    global text
    a = text.find(start)
    if a < 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f"start not found: {start}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"end not found: {end}")
    text = text[:a] + replacement + text[b:]


replace_once(
'''    private enum ClaimRole: String {
        case sequential
        case urgentPlayback
        case metadata
    }
''',
'''    private enum ClaimRole: String {
        case sequential
        case urgentPlayback
        case metadata
        case startupMetadata
    }
''')

replace_once(
'''    private struct LaneHealthState {
        var averageBps: Double = 0
        var samples = 0
        var slowStreak = 0
        var lastSampleAt = Date.distantPast
        var resetCooldownUntil = Date.distantPast
    }
''',
'''    private struct LaneHealthState {
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
        var receivedBytes: Int64 = 0
        var recentBps: Double = 0
        var slowStreak = 0
        var resetCooldownUntil = Date.distantPast
    }
''')

replace_once(
'''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let startupTailWarmupBytes: Int64 = 16 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
''',
'''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let startupMetadataSegmentBytes: Int64 = 1 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
''')

replace_once(
'''    private let laneHealthResetCooldownSeconds: TimeInterval = 25
    private let lookaheadSegments = 4
''',
'''    private let laneHealthResetCooldownSeconds: TimeInterval = 25
    private let liveLanePeerFloorBps: Double = 4 * 1_048_576
    private let liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576
    private let liveLaneRelativeFloor: Double = 0.45
    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
    private let lookaheadSegments = 4
''')

replace_once(
'''    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
    private var startupTailWarmupRange: Range<Int64>?
    private var startupTailWarmupQueued = false
    private var startupTailWarmupCompleted = false
    private var preferredBulkSlot = 0
''',
'''    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
    private var startupMetadataPlanRange: Range<Int64>?
    private var startupMetadataQueue: [Range<Int64>] = []
    private var startupMetadataPlanCompleted = false
    private var preferredBulkSlot = 0
''')

replace_once(
'''    private var laneHealth: [Int: LaneHealthState] = [0: LaneHealthState(), 1: LaneHealthState()]

    private var metricsValue = TransportMetricsSnapshot()
''',
'''    private var laneHealth: [Int: LaneHealthState] = [0: LaneHealthState(), 1: LaneHealthState()]
    private var liveLaneState: [Int: LiveLaneState] = [0: LiveLaneState(), 1: LiveLaneState()]
    private var liveLaneRotationRequested: Set<Int> = []

    private var metricsValue = TransportMetricsSnapshot()
''')

replace_once('''            configureStartupWarmupIfNeeded(resource: resolved)\n''', '')
replace_once('''        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=primary-lane") }\n''', '''        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=actual-demand") }\n''')

new_install = '''    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {
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
        DiagnosticsLogger.shared.log("UnifiedDemand", "urgent range=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata) reason=\\(reason) protectedBulk=\\(preferredBulkSlot)")

        if firstIdleForegroundSlot() != nil { return }
        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }
        if sequentialSlots.count == 2 {
            let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "foreground borrow slot=\\(serviceSlot) preserveBulk=\\(preferredBulkSlot) range=\\(candidate.lowerBound)-\\(candidate.upperBound)")
            cancelSlot(serviceSlot, reason: metadata ? "metadata-borrow-service-lane" : "foreground-borrow-service-lane")
        } else if sequentialSlots.count == 1 {
            let onlySequential = sequentialSlots[0]
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "second foreground head borrows bulk slot=\\(onlySequential) range=\\(candidate.lowerBound)-\\(candidate.upperBound)")
            cancelSlot(onlySequential, reason: "second-foreground-head")
        }
    }

    private func installStartupMetadataPlan(range: Range<Int64>, reason: String) {
        guard let resource, let store, !range.isEmpty else { return }
        let lower = min(startupMetadataPlanRange?.lowerBound ?? range.lowerBound, range.lowerBound)
        let plan = max(0, lower)..<resource.contentLength
        startupMetadataPlanRange = plan
        startupMetadataPlanCompleted = false

        let activeRanges = slotClaims.values.filter { $0.role == .startupMetadata }.map(\\.range)
        var chunks: [Range<Int64>] = []
        var cursor = plan.lowerBound
        while cursor < plan.upperBound {
            let chunk = cursor..<min(plan.upperBound, safeAdd(cursor, startupMetadataSegmentBytes))
            if !store.contains(chunk), !activeRanges.contains(where: { $0.lowerBound == chunk.lowerBound && $0.upperBound == chunk.upperBound }) { chunks.append(chunk) }
            cursor = chunk.upperBound
        }
        startupMetadataQueue = chunks
        for slot in [0, 1] where slotClaims[slot]?.role == .sequential { cancelSlot(slot, reason: "startup-metadata-preempt") }
        DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan range=\\(plan.lowerBound)-\\(plan.upperBound) bytes=\\(plan.count) segment=\\(startupMetadataSegmentBytes) queued=\\(startupMetadataQueue.count) reason=\\(reason)")
    }

'''
replace_between('    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {', '    private func scheduleSlots(reason: String) {', new_install)

new_schedule = '''    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        if !startupMetadataQueue.isEmpty || slotClaims.values.contains(where: { $0.role == .startupMetadata }) {
            for slot in [0, 1] where slotTasks[slot] == nil {
                while !startupMetadataQueue.isEmpty {
                    let chunk = startupMetadataQueue.removeFirst()
                    if store.contains(chunk) { continue }
                    startSlot(slot, claim: SlotClaim(range: chunk, role: .startupMetadata), reason: "startup-metadata-\\(reason)")
                    break
                }
            }
            refreshMetrics(resource: resource)
            return
        }

        if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent), let slot = firstIdleForegroundSlot() {
            pendingPlaybackUrgentRange = nil
            startSlot(slot, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "foreground-\\(reason)")
        }

        if let metadata = pendingMetadataRange, !store.contains(metadata), let slot = firstIdleForegroundSlot() {
            pendingMetadataRange = nil
            startSlot(slot, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }

        if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
            refreshMetrics(resource: resource)
            return
        }

        if !secondaryEnabled {
            if slotTasks[0] == nil, let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }
            refreshMetrics(resource: resource)
            return
        }

        let order = preferredBulkSlot == 0 ? [0, 1] : [1, 0]
        for slot in order where slotTasks[slot] == nil {
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            if let range = nextSequentialClaim(resource: resource) { startSlot(slot, claim: SlotClaim(range: range, role: .sequential), reason: slot == preferredBulkSlot ? "bulk-\\(reason)" : "service-preload-\\(reason)") }
        }
        refreshMetrics(resource: resource)
    }

'''
replace_between('    private func scheduleSlots(reason: String) {', '    private func firstIdleForegroundSlot() -> Int? {', new_schedule)

replace_once(
'''        slotClaims[slot] = claim
        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
''',
'''        slotClaims[slot] = claim
        if claim.role == .sequential {
            var live = liveLaneState[slot] ?? LiveLaneState()
            let now = Date()
            live.generation = generation
            live.startedAt = now
            live.lastChunkAt = now
            live.receivedBytes = 0
            live.recentBps = 0
            live.slowStreak = 0
            liveLaneState[slot] = live
            armFirstByteWatchdog(slot: slot, generation: generation)
        }
        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
''')

replace_once(
'''                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) first-chunk role=sequential range=\\(remaining.lowerBound)-\\(remaining.upperBound) bytes=\\(chunk.count) ms=\\(Int(firstChunkSeconds * 1000)) speedBps=\\(Int(Double(chunk.count) / firstChunkSeconds))")
                            }
                            refreshMetrics(resource: resolved)
''',
'''                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) first-chunk role=sequential range=\\(remaining.lowerBound)-\\(remaining.upperBound) bytes=\\(chunk.count) ms=\\(Int(firstChunkSeconds * 1000)) speedBps=\\(Int(Double(chunk.count) / firstChunkSeconds))")
                            }
                            observeSequentialChunk(slot: slot, generation: generation, bytes: Int64(chunk.count))
                            try Task.checkCancellation()
                            refreshMetrics(resource: resolved)
''')

replace_once(
'''                            if claim.role == .metadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }
''',
'''                            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }
''')

new_finish_prefix = '''    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?, completedSequentialBps: Double? = nil) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\\(slot)")

        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        if liveRotation {
            let reset = client.resetStreamLane(worker: slot, reason: "live-lane-rotation")
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=reset-after-cancel success=\\(reset)")
            var health = LaneHealthState()
            health.resetCooldownUntil = Date().addingTimeInterval(liveLaneResetCooldownSeconds)
            laneHealth[slot] = health
        } else if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if claim.role == .startupMetadata, error == nil, let plan = startupMetadataPlanRange, startupMetadataQueue.isEmpty, !slotClaims.values.contains(where: { $0.role == .startupMetadata }), store?.contains(plan) == true {
            startupMetadataPlanCompleted = true
            DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan complete range=\\(plan.lowerBound)-\\(plan.upperBound) bytes=\\(plan.count)")
        }

'''
start = '    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?, completedSequentialBps: Double? = nil) {'
marker = '        if let downloadedBytes, downloadedBytes > 0 {'
a = text.find(start)
if a < 0: raise SystemExit('finish start missing')
m = text.find(marker, a)
if m < 0: raise SystemExit('finish marker missing')
text = text[:a] + new_finish_prefix + text[m:]

replace_once('''            if claim.role == .metadata { rangeMap.insertMetadata(written) }\n            else { rangeMap.insertPlayback(written) }\n''', '''            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) }\n            else { rangeMap.insertPlayback(written) }\n''')

replace_once(
'''                if let warmup = startupTailWarmupRange, !startupTailWarmupQueued, !startupTailWarmupCompleted, store?.contains(warmup) != true {
                    startupTailWarmupQueued = true
                    pendingMetadataRange = warmup
                    DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) action=queue-tail range=\\(warmup.lowerBound)-\\(warmup.upperBound)")
                }
''',
'''                DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) action=await-actual-tail-demand")
''')

replace_once('''            if claim.role == .metadata, downloadedBytes >= Int64(claim.range.count), !secondaryEnabled {\n''', '''            if (claim.role == .metadata || claim.role == .startupMetadata), downloadedBytes >= Int64(claim.range.count), !secondaryEnabled {\n''')
replace_once('''                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after critical metadata")\n''', '''                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after critical metadata")\n''')

replace_once(
'''        if let error, !isCancellation(error) {
            if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }
''',
'''        if let error, !isCancellation(error) {
            if claim.role == .startupMetadata { startupMetadataQueue.insert(claim.range, at: 0) }
            else if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }
''')

helpers = '''    private func armFirstByteWatchdog(slot: Int, generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(liveLaneFirstBytePeerTimeoutSeconds * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: false)
            try? await Task.sleep(nanoseconds: UInt64((liveLaneFirstByteHardTimeoutSeconds - liveLaneFirstBytePeerTimeoutSeconds) * 1_000_000_000))
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
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
        guard hard || peerBps >= 2 * 1_048_576 else { return }
        requestLiveLaneRotation(slot: slot, generation: generation, reason: hard ? "first-byte-hard-timeout" : "first-byte-peer-fast", observedBps: 0, peerBps: peerBps)
    }

    private func observeSequentialChunk(slot: Int, generation: Int, bytes: Int64) {
        guard bytes > 0, slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential else { return }
        let now = Date()
        var live = liveLaneState[slot] ?? LiveLaneState()
        guard live.generation == generation else { return }
        let interval = max(now.timeIntervalSince(live.lastChunkAt), 0.001)
        let chunkBps = Double(bytes) / interval
        live.lastChunkAt = now
        live.receivedBytes += bytes
        live.recentBps = live.recentBps == 0 ? chunkBps : live.recentBps * 0.55 + chunkBps * 0.45

        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
        let relativeSlow = peerBps >= liveLanePeerFloorBps && live.recentBps < peerBps * liveLaneRelativeFloor
        let absoluteSlow = live.receivedBytes >= 2 * 1_048_576 && live.recentBps < liveLaneAbsoluteFloorBps
        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(liveLaneAbsoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
        liveLaneState[slot] = live

        if live.slowStreak >= 2 {
            requestLiveLaneRotation(slot: slot, generation: generation, reason: relativeSlow ? "rolling-relative-slow" : "rolling-absolute-slow", observedBps: live.recentBps, peerBps: peerBps)
        }
    }

    private func requestLiveLaneRotation(slot: Int, generation: Int, reason: String, observedBps: Double, peerBps: Double) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, !liveLaneRotationRequested.contains(slot) else { return }
        var live = liveLaneState[slot] ?? LiveLaneState()
        let now = Date()
        guard now >= live.resetCooldownUntil else { return }
        live.resetCooldownUntil = now.addingTimeInterval(liveLaneResetCooldownSeconds)
        liveLaneState[slot] = live
        liveLaneRotationRequested.insert(slot)
        if preferredBulkSlot == slot { preferredBulkSlot = slot == 0 ? 1 : 0 }
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=rotate-live-lane reason=\\(reason) observedBps=\\(Int(observedBps)) peerBps=\\(Int(peerBps)) received=\\(live.receivedBytes)")
        cancelSlot(slot, reason: "live-lane-rotation")
    }

'''
replace_once('''    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {\n''', helpers + '''    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {\n''')

old_helpers_start = '    private func configureStartupWarmupIfNeeded(resource: TransportResolvedResource) {'
new_startup_helpers = '''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        if let plan = startupMetadataPlanRange, range.upperBound > plan.lowerBound, range.lowerBound < plan.upperBound { return true }
        guard Date().timeIntervalSince(createdAt) < 35 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
    }

'''
replace_between(old_helpers_start, '    private func isMetadataProbe(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {', new_startup_helpers)

# Remove obsolete startup warmup completion block if still present after function replacement.
obsolete = '''        if claim.role == .metadata, let warmup = startupTailWarmupRange, store?.contains(warmup) == true {
            startupTailWarmupCompleted = true
            startupTailWarmupQueued = true
            DiagnosticsLogger.shared.log("UnifiedStartup", "tail warmup complete range=\\(warmup.lowerBound)-\\(warmup.upperBound) bytes=\\(warmup.count)")
        }

'''
text = text.replace(obsolete, '')

# Permanent sanity checks for construction script itself.
for forbidden in ["startupTailWarmupBytes", "startupTailWarmupRange", "startupTailWarmupQueued", "queue-tail"]:
    if forbidden in text:
        raise SystemExit(f"obsolete v0.12.0 startup strategy still present: {forbidden}")
for required in ["case startupMetadata", "actual-tail plan range=", "startupMetadataSegmentBytes", "rotate-live-lane", "first-byte-hard-timeout", "observeSequentialChunk"]:
    if required not in text:
        raise SystemExit(f"v0.12.1 core missing: {required}")

path.write_text(text)
print("Applied v0.12.1 live-lane/startup core")
