from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"{path}: target not found")
    p.write_text(text.replace(old, new, 1))


unified = "Sources/Transport/UnifiedMediaTransportSession.swift"

replace_once(unified,
'''/// - Exactly two upstream slots are used for normal 115/CDN traffic.
/// - Slot 0 owns urgent playback; Slot 1 yields background bandwidth immediately when playback
///   becomes urgent, and may temporarily serve critical metadata while Slot 0 is busy.
/// - Sequential prefetch is anchored by real byte demand, never by time/file-size math.
''',
'''/// - Exactly two upstream slots are used for normal 115/CDN traffic.
/// - Warm sequential prefetch should survive ordinary seeks; foreground byte demand borrows the
///   other slot first so cancelling a seek does not repeatedly reset the warmed CDN connection.
/// - Sequential prefetch is anchored by real byte demand, never by time/file-size math.
''')

replace_once(unified,
'''    private let urgentBlockBytes: Int64 = 16 * 1_048_576
    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
''',
'''    private let urgentBlockBytes: Int64 = 16 * 1_048_576
    private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576
    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
''')

replace_once(unified,
'''            installUrgent(range: urgent, metadata: false, reason: "stall-last-concrete-demand")
            if let active = slotClaims[0], !active.range.contains(demand.lowerBound) { cancelSlot(0, reason: "stall-current-demand") }
''',
'''            installUrgent(range: urgent, metadata: false, reason: "stall-last-concrete-demand")
            if let active = slotClaims[0], active.role == .urgentPlayback, !active.range.contains(demand.lowerBound) { cancelSlot(0, reason: "replace-stale-urgent") }
''')

replace_once(unified,
'''            if let active = slotClaims[0], !active.range.contains(range.lowerBound) { cancelSlot(0, reason: "real-seek-demand") }
''',
'''            if let active = slotClaims[0], active.role == .urgentPlayback, !active.range.contains(range.lowerBound) { cancelSlot(0, reason: "replace-stale-urgent") }
''')

replace_once(unified,
'''        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 {
            if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }
            return
        }
        // Transport v3 exposes every received MiB immediately. If the requested byte already belongs
        // to Slot 0's active sequential stream, keep that warmed task alive and wait for its progressive
        // chunk instead of cancelling/reopening the same CDN connection as an urgent Range.
        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) {
            if concretePlaybackDemand, slot0.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) reason=\\(reason) action=wait-progressive-chunk")
            }
            return
        }
        if metadata, let slot1 = slotClaims[1], slot1.role == .metadata, slot1.range.contains(range.lowerBound) { return }
        if !metadata, let slot1 = slotClaims[1], slot1.role == .urgentPlayback, slot1.range.contains(range.lowerBound) { return }
        installUrgent(range: range, metadata: metadata, reason: reason)
        scheduleSlots(reason: reason)
''',
'''        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 {
            if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }
            return
        }

        // A non-sequential claim already starting at this byte is foreground work. Let that request
        // finish rather than opening a duplicate Range for the same demux dependency.
        if let active = slotClaims.values.first(where: { $0.role != .sequential && $0.range.contains(range.lowerBound) }) {
            DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active foreground request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(active.range.lowerBound)-\\(active.range.upperBound) role=\\(active.role.rawValue) reason=\\(reason)")
            return
        }

        // Being inside a 32 MiB sequential claim does not mean the requested byte has arrived. This
        // was the 63360/194s regression: the read was ~10 MiB ahead of Slot 0's actual download head.
        // Wait only when the progressive stream is genuinely close; otherwise preserve the warmed
        // sequential request and borrow Slot 1 for an exact urgent Range.
        if concretePlaybackDemand, let slot0 = slotClaims[0], slot0.role == .sequential, slot0.range.contains(range.lowerBound) {
            let ready = store.availableLength(from: slot0.range.lowerBound, maximumLength: Int64(slot0.range.count))
            let streamHead = min(slot0.range.upperBound, slot0.range.lowerBound + ready)
            let gap = max(0, range.lowerBound - streamHead)
            if gap <= progressiveUrgentGapBytes {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) head=\\(streamHead) gap=\\(gap) reason=\\(reason) action=wait-progressive-chunk")
                return
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "foreground gap request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) head=\\(streamHead) gap=\\(gap) action=parallel-urgent")
            installUrgent(range: range, metadata: false, reason: "foreground-gap-\\(reason)")
            scheduleSlots(reason: "foreground-gap-\\(reason)")
            return
        }

        installUrgent(range: range, metadata: metadata, reason: reason)
        scheduleSlots(reason: reason)
''')

replace_once(unified,
'''        if let secondary = slotClaims[1], secondary.role == .sequential {
            cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")
        }
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            let secondaryCanTakePlayback = !metadata && Date() >= secondaryCooldownUntil && (slotTasks[1] == nil || slotClaims[1]?.role == .sequential)
            if secondaryCanTakePlayback {
                DiagnosticsLogger.shared.log("UnifiedDemand", "preserve slot0 sequential for parallel urgent request=\\(candidate.lowerBound)-\\(candidate.upperBound)")
            } else {
                cancelSlot(0, reason: "urgent-demand")
            }
        }
''',
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
''')

replace_once(unified,
'''        if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent), Date() >= secondaryCooldownUntil, slotTasks[1] == nil, slotTasks[0] != nil, slotClaims[0]?.range.contains(urgent.lowerBound) != true {
            pendingPlaybackUrgentRange = nil
            startSlot(1, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "parallel-urgent-\\(reason)")
        }
''',
'''        if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent), Date() >= secondaryCooldownUntil, slotTasks[1] == nil, slotTasks[0] != nil,
           !(slotClaims[0]?.role == .urgentPlayback && slotClaims[0]?.range.contains(urgent.lowerBound) == true) {
            pendingPlaybackUrgentRange = nil
            startSlot(1, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "parallel-urgent-\\(reason)")
        }
''')

replace_once(unified,
'''        if let metadata = pendingMetadataRange, Int64(metadata.count) <= secondaryMetadataMaxBytes, !store.contains(metadata), Date() >= secondaryCooldownUntil, slotClaims[0]?.role == .urgentPlayback, slotTasks[1] == nil {
            pendingMetadataRange = nil
            startSlot(1, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }
''',
'''        if let metadata = pendingMetadataRange, Int64(metadata.count) <= secondaryMetadataMaxBytes, !store.contains(metadata), Date() >= secondaryCooldownUntil, slotTasks[0] != nil, slotTasks[1] == nil, slotClaims[0]?.range.contains(metadata.lowerBound) != true {
            pendingMetadataRange = nil
            startSlot(1, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }
''')

replace_once(unified,
'''                            try store.write(chunk, at: writeOffset)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            rangeMap.insertPlayback(writeOffset..<min(claim.range.upperBound, writeOffset + Int64(chunk.count)))
''',
'''                            try store.write(chunk, at: writeOffset)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            recordNetworkBytes(Int64(chunk.count))
                            rangeMap.insertPlayback(writeOffset..<min(claim.range.upperBound, writeOffset + Int64(chunk.count)))
''')

replace_once(unified,
'''                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
''',
'''                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            recordNetworkBytes(Int64(chunk.count))
''')

replace_once(unified,
'''            metricsValue.bytesDownloaded += downloadedBytes
            speedSamples.append(SpeedSample(date: Date(), bytes: downloadedBytes))
            pruneSpeedSamples()

''',
'''            // Network bytes/speed are recorded per received chunk so long 32 MiB requests do not
            // display as zero throughput until the entire Range finishes.

''')

replace_once(unified,
'''    private func refreshMetrics(resource: TransportResolvedResource) {
        guard let store else { return }
        let map = rangeMap.snapshot(anchor: playbackAnchor, resourceLength: resource.contentLength)
        metricsValue.cacheBytes = store.uniqueBytes
''',
'''    private func recordNetworkBytes(_ bytes: Int64) {
        guard bytes > 0 else { return }
        metricsValue.bytesDownloaded += bytes
        speedSamples.append(SpeedSample(date: Date(), bytes: bytes))
        pruneSpeedSamples()
    }

    private func refreshMetrics(resource: TransportResolvedResource) {
        guard let store else { return }
        let map = rangeMap.snapshot(anchor: playbackAnchor, resourceLength: resource.contentLength)
        metricsValue.resourceBytes = resource.contentLength
        metricsValue.cacheBytes = store.uniqueBytes
''')

transport_types = "Sources/Transport/TransportTypes.swift"
replace_once(transport_types,
'''    var activeRequestCount: Int = 0
    var cacheBytes: Int64 = 0
''',
'''    var activeRequestCount: Int = 0
    var resourceBytes: Int64 = 0
    var cacheBytes: Int64 = 0
''')

controller = "Sources/Player/PlayerController.swift"
replace_once(controller,
'''    private func startTransportMetricsPolling() {
''',
'''    private func promoteFullCacheRangeIfNeeded(_ metrics: TransportMetricsSnapshot) {
        guard metrics.resourceBytes > 0, metrics.cacheHoleCount == 0, metrics.cacheBytes >= metrics.resourceBytes else { return }
        let duration = effectiveDuration
        guard duration > 0 else { return }
        let fullRange = 0...duration
        guard verifiedBufferedRanges != [fullRange] else { return }
        verifiedBufferedRanges = [fullRange]
        DiagnosticsLogger.shared.log("BufferHistory", "transport cache complete bytes=\\(metrics.cacheBytes)/\\(metrics.resourceBytes) action=promote-full-duration duration=\\(String(format: \"%.3f\", duration))")
    }

    private func startTransportMetricsPolling() {
''')

replace_once(controller,
'''                if let metrics = await engine.transportMetrics(), self.engine === engine {
                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
''',
'''                if let metrics = await engine.transportMetrics(), self.engine === engine {
                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
                    self.promoteFullCacheRangeIfNeeded(metrics)
''')

print("v0.11.2 transport stability patch applied")
