from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

helper = '''    private func configureStartupWarmupIfNeeded(resource: TransportResolvedResource) {
        guard startupTailWarmupRange == nil, !startupTailWarmupCompleted else { return }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return }
        let tailBytes = min(startupTailWarmupBytes, resource.contentLength)
        let tail = max(0, resource.contentLength - tailBytes)..<resource.contentLength
        startupTailWarmupRange = tail
        DiagnosticsLogger.shared.log("UnifiedStartup", "large-mp4 warmup planned head=\\(largeFileInitialSequentialBlockBytes) tail=\\(tail.lowerBound)-\\(tail.upperBound) tailBytes=\\(tail.count)")
    }

'''
if helper not in text:
    raise SystemExit("startup warmup helper missing")
while helper + helper in text:
    text = text.replace(helper + helper, helper)

old = '''        if concretePlaybackDemand, let slot0 = slotClaims[0], slot0.role == .sequential, slot0.range.contains(range.lowerBound) {
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
'''
new = '''        if concretePlaybackDemand, let activeSequential = slotClaims.first(where: { $0.value.role == .sequential && $0.value.range.contains(range.lowerBound) }) {
            let slot = activeSequential.key
            let claim = activeSequential.value
            let ready = store.availableLength(from: claim.range.lowerBound, maximumLength: Int64(claim.range.count))
            let streamHead = min(claim.range.upperBound, claim.range.lowerBound + ready)
            let gap = max(0, range.lowerBound - streamHead)
            if gap <= progressiveUrgentGapBytes {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream slot=\\(slot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(claim.range.lowerBound)-\\(claim.range.upperBound) head=\\(streamHead) gap=\\(gap) reason=\\(reason) action=wait-progressive-chunk")
                return
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "foreground gap slot=\\(slot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(claim.range.lowerBound)-\\(claim.range.upperBound) head=\\(streamHead) gap=\\(gap) action=parallel-urgent")
            installUrgent(range: range, metadata: false, reason: "foreground-gap-\\(reason)")
            scheduleSlots(reason: "foreground-gap-\\(reason)")
            return
        }
'''
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("dynamic sequential-gap target missing")

path.write_text(text)
print(f"Scheduler v2 cleanup complete helperCount={text.count('private func configureStartupWarmupIfNeeded')}")
