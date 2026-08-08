from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"{path}: target not found")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    a = text.find(start)
    if a < 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f"{path}: start marker not found: {start}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"{path}: end marker not found: {end}")
    p.write_text(text[:a] + replacement + text[b:])


unified = "Sources/Transport/UnifiedMediaTransportSession.swift"

replace_once(unified,
'''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
''',
'''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let startupTailWarmupBytes: Int64 = 16 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
''')

replace_once(unified,
'''    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
    private var stopped = false
''',
'''    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
    private var startupTailWarmupRange: Range<Int64>?
    private var startupTailWarmupQueued = false
    private var startupTailWarmupCompleted = false
    private var preferredBulkSlot = 0
    private var stopped = false
''')

replace_once(unified,
'''                for range in cache.cachedRanges { rangeMap.insertPlayback(range) }
            }
            DiagnosticsLogger.shared.log(
''',
'''                for range in cache.cachedRanges { rangeMap.insertPlayback(range) }
            }
            configureStartupWarmupIfNeeded(resource: resolved)
            DiagnosticsLogger.shared.log(
''')

replace_once(unified,
'''        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteRead=true anchor=\\(playbackAnchor)"
            )
            return
        }

        if pendingUserSeek, !metadata, concretePlaybackDemand {
''',
'''        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteRead=true anchor=\\(playbackAnchor)"
            )
            return
        }

        // AVPlayer range announcements are speculative. They must never preempt a healthy bulk
        // connection merely because the demuxer considered a region. Concrete read()/byte-offset
        // demand remains authoritative; metadata hints are retained because tail indexes are startup-critical.
        if !concreteReason, !metadata {
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "hint-only request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=keep-bulk")
            scheduleSlots(reason: "hint-only")
            return
        }

        if pendingUserSeek, !metadata, concretePlaybackDemand {
''')

new_install = '''    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {
        guard let resource else { return }
        let lower = max(0, range.lowerBound)
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

        let startupCriticalMetadata = metadata && isStartupTailMetadata(candidate, resource: resource)
        if startupCriticalMetadata {
            // Large-MP4 startup is special: finish the tiny head warmup on Slot 0, then use that same
            // persistent connection for the tail index while Slot 1 begins ordinary sequential preload.
            // Do not destroy the 1 MiB head request just because libmpv asked for EOF a few ms early.
            if let primary = slotClaims[0], primary.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedStartup", "tail waiting for warm primary range=\\(candidate.lowerBound)-\\(candidate.upperBound) headClaim=\\(primary.range.lowerBound)-\\(primary.range.upperBound)")
            }
            return
        }

        if firstIdleForegroundSlot() != nil { return }
        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }
        if sequentialSlots.count == 2 {
            let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "foreground borrow slot=\\(serviceSlot) preserveBulk=\\(preferredBulkSlot) range=\\(candidate.lowerBound)-\\(candidate.upperBound)")
            cancelSlot(serviceSlot, reason: metadata ? "metadata-borrow-service-lane" : "foreground-borrow-service-lane")
        } else if sequentialSlots.count == 1 {
            // The other slot is already occupied by a real foreground dependency. A second real read
            // head is allowed to borrow the remaining sequential lane; this is the poorly-interleaved
            // MP4 case where playback correctness outranks bulk throughput.
            let onlySequential = sequentialSlots[0]
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "second foreground head borrows bulk slot=\\(onlySequential) range=\\(candidate.lowerBound)-\\(candidate.upperBound)")
            cancelSlot(onlySequential, reason: "second-foreground-head")
        }
    }

'''
replace_between(unified, "    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {", "    private func scheduleSlots(reason: String) {", new_install)

new_schedule = '''    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        // Proactive large-MP4 tail warmup always uses Slot 0 after its tiny head request has completed.
        // Slot 1 may keep filling the head concurrently, so 152901 no longer downloads 100+ MiB while
        // libmpv is still blocked on a slow, late-discovered moov/sample-table read.
        if let metadata = pendingMetadataRange, isStartupTailMetadata(metadata, resource: resource), !store.contains(metadata), slotTasks[0] == nil {
            pendingMetadataRange = nil
            startSlot(0, claim: SlotClaim(range: metadata, role: .metadata), reason: "startup-tail-\\(reason)")
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

        // Before the first stable head block, keep startup deliberately single-lane. Afterwards both
        // slots are allowed to preload whenever they are not serving real foreground work. The faster
        // lane is filled first and becomes the protected bulk lane during future foreground bursts.
        if !secondaryEnabled {
            if slotTasks[0] == nil, let range = nextSequentialClaim(resource: resource) {
                startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason)
            }
            refreshMetrics(resource: resource)
            return
        }

        let order = preferredBulkSlot == 0 ? [0, 1] : [1, 0]
        for slot in order where slotTasks[slot] == nil {
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            if let range = nextSequentialClaim(resource: resource) {
                startSlot(slot, claim: SlotClaim(range: range, role: .sequential), reason: slot == preferredBulkSlot ? "bulk-\\(reason)" : "service-preload-\\(reason)")
            }
        }
        refreshMetrics(resource: resource)
    }

    private func firstIdleForegroundSlot() -> Int? {
        let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
        let order = [serviceSlot, preferredBulkSlot]
        for slot in order {
            guard slotTasks[slot] == nil else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            return slot
        }
        return nil
    }

'''
replace_between(unified, "    private func scheduleSlots(reason: String) {", "    private func nextSequentialClaim(resource: TransportResolvedResource) -> Range<Int64>? {", new_schedule)

replace_once(unified,
'''        if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if let downloadedBytes, downloadedBytes > 0 {
''',
'''        if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if claim.role == .metadata, let warmup = startupTailWarmupRange, store?.contains(warmup) == true {
            startupTailWarmupCompleted = true
            startupTailWarmupQueued = true
            DiagnosticsLogger.shared.log("UnifiedStartup", "tail warmup complete range=\\(warmup.lowerBound)-\\(warmup.upperBound) bytes=\\(warmup.count)")
        }

        if let downloadedBytes, downloadedBytes > 0 {
''')

replace_once(unified,
'''            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
            }
''',
'''            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
                if let warmup = startupTailWarmupRange, !startupTailWarmupQueued, !startupTailWarmupCompleted, store?.contains(warmup) != true {
                    startupTailWarmupQueued = true
                    pendingMetadataRange = warmup
                    DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) action=queue-tail range=\\(warmup.lowerBound)-\\(warmup.upperBound)")
                }
            }
''')

replace_once(unified,
'''        laneHealth[slot] = current

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) sampleBps=\\(Int(bps)) avgBps=\\(Int(current.averageBps)) peer=\\(peerSlot) peerAvgBps=\\(Int(peer.averageBps)) peerFresh=\\(peerIsFresh) slowStreak=\\(current.slowStreak)")
        guard current.slowStreak >= 2, now >= current.resetCooldownUntil else { return }
''',
'''        laneHealth[slot] = current

        if peerIsFresh {
            if current.averageBps >= peer.averageBps * 1.20, preferredBulkSlot != slot {
                preferredBulkSlot = slot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\\(slot) avgBps=\\(Int(current.averageBps)) peerAvgBps=\\(Int(peer.averageBps))")
            } else if peer.averageBps >= current.averageBps * 1.20, preferredBulkSlot == slot {
                preferredBulkSlot = peerSlot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\\(peerSlot) avgBps=\\(Int(peer.averageBps)) peerAvgBps=\\(Int(current.averageBps))")
            }
        }

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) sampleBps=\\(Int(bps)) avgBps=\\(Int(current.averageBps)) peer=\\(peerSlot) peerAvgBps=\\(Int(peer.averageBps)) peerFresh=\\(peerIsFresh) slowStreak=\\(current.slowStreak) protectedBulk=\\(preferredBulkSlot)")
        guard current.slowStreak >= 2, now >= current.resetCooldownUntil else { return }
''')

replace_once(unified,
'''        laneHealth[slot] = reset
        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) action=rotate-slow-lane reason=\\(reason) cooldown=\\(Int(laneHealthResetCooldownSeconds))s")
''',
'''        laneHealth[slot] = reset
        if preferredBulkSlot == slot {
            preferredBulkSlot = peerSlot
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk failover slot=\\(peerSlot) reason=slow-lane-rotation")
        }
        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) action=rotate-slow-lane reason=\\(reason) cooldown=\\(Int(laneHealthResetCooldownSeconds))s")
''')

insert_helpers = '''    private func configureStartupWarmupIfNeeded(resource: TransportResolvedResource) {
        guard startupTailWarmupRange == nil, !startupTailWarmupCompleted else { return }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return }
        let tailBytes = min(startupTailWarmupBytes, resource.contentLength)
        let tail = max(0, resource.contentLength - tailBytes)..<resource.contentLength
        startupTailWarmupRange = tail
        DiagnosticsLogger.shared.log("UnifiedStartup", "large-mp4 warmup planned head=\\(largeFileInitialSequentialBlockBytes) tail=\\(tail.lowerBound)-\\(tail.upperBound) tailBytes=\\(tail.count)")
    }

'''
replace_once(unified,
'''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
''',
insert_helpers + '''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
''')

# MPV persistent buffer history: a valid demuxer-cache-duration remains useful while MPV reports
# a transient buffering state. Require real time-pos progression instead of dropping the range.
controller = "Sources/Player/PlayerController.swift"
replace_once(controller,
'''        if engineKind == .mpv {
            guard !value.isBuffering else { return }
            if let previous = lastVerifiedMPVPosition {
''',
'''        if engineKind == .mpv {
            guard value.bufferedRanges.contains(where: { $0.lowerBound <= value.position + 0.05 && $0.upperBound > value.position + 0.25 }) else { return }
            if let previous = lastVerifiedMPVPosition {
''')

print("v0.12.0 Scheduler v2 core patch applied")
