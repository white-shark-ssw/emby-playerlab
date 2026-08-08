from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

old = '''        } else if concretePlaybackDemand {
            let distance = range.lowerBound >= playbackAnchor ? range.lowerBound - playbackAnchor : playbackAnchor - range.lowerBound
            if distance > blockBytes * 4 {
                let previous = playbackAnchor
                playbackAnchor = range.lowerBound
                reanchored = true
                DiagnosticsLogger.shared.log("UnifiedAnchor", "blocked-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)")
                if let active = slotClaims[0], !active.range.contains(range.lowerBound) { cancelSlot(0, reason: "blocked-demand-reanchor") }
            }
        }
'''
new = '''        } else if concretePlaybackDemand {
            let distance = range.lowerBound >= playbackAnchor ? range.lowerBound - playbackAnchor : playbackAnchor - range.lowerBound
            if distance > blockBytes * 4 {
                // Poorly interleaved MP4 files may legitimately alternate between distant audio/video
                // byte regions. Do not reinterpret that second read head as another timeline seek and
                // cancel the first head. The scheduler can use Slot 1 for the parallel urgent demand.
                DiagnosticsLogger.shared.log("UnifiedAnchor", "parallel-read-head primary=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=keep-primary-anchor")
            }
        }
'''
if old not in text:
    raise SystemExit("parallel read-head target not found")
text = text.replace(old, new, 1)

old = '''        if metadata, let slot1 = slotClaims[1], slot1.role == .metadata, slot1.range.contains(range.lowerBound) { return }
        installUrgent(range: range, metadata: metadata, reason: reason)
'''
new = '''        if metadata, let slot1 = slotClaims[1], slot1.role == .metadata, slot1.range.contains(range.lowerBound) { return }
        if !metadata, let slot1 = slotClaims[1], slot1.role == .urgentPlayback, slot1.range.contains(range.lowerBound) { return }
        installUrgent(range: range, metadata: metadata, reason: reason)
'''
if old not in text:
    raise SystemExit("slot1 existing urgent target not found")
text = text.replace(old, new, 1)

old = '''        if let secondary = slotClaims[1], secondary.role == .sequential {
            cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")
        }
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            cancelSlot(0, reason: "urgent-demand")
        }
'''
new = '''        if let secondary = slotClaims[1], secondary.role == .sequential {
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
'''
if old not in text:
    raise SystemExit("urgent cancellation target not found")
text = text.replace(old, new, 1)

old = '''    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        // A tiny metadata probe (typical MP4/MKV tail index) may use Slot 1 while Slot 0 is
'''
new = '''    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        // A second real playback read head may be hundreds of MiB away in poorly interleaved MP4.
        // Serve it on Slot 1 while Slot 0 keeps the first playback head warm instead of cancelling
        // back and forth between audio/video byte regions.
        if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent), Date() >= secondaryCooldownUntil, slotTasks[1] == nil, slotTasks[0] != nil, slotClaims[0]?.range.contains(urgent.lowerBound) != true {
            pendingPlaybackUrgentRange = nil
            startSlot(1, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "parallel-urgent-\\(reason)")
        }

        // A tiny metadata probe (typical MP4/MKV tail index) may use Slot 1 while Slot 0 is
'''
if old not in text:
    raise SystemExit("parallel urgent schedule target not found")
text = text.replace(old, new, 1)

old = '''        if let error, !isCancellation(error) {
            if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            metricsValue.rangeFailureCount += 1
'''
new = '''        if let error, !isCancellation(error) {
            if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }
            metricsValue.rangeFailureCount += 1
'''
if old not in text:
    raise SystemExit("urgent retry target not found")
text = text.replace(old, new, 1)

path.write_text(text)
print("v0.11.1 parallel demux refinement applied")
