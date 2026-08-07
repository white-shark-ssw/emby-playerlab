from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, count))


path = "Sources/Transport/UnifiedMediaTransportSession.swift"

replace(path, """    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let initialSequentialBlockBytes: Int64 = 4 * 1_048_576
""", """    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
    private let initialSequentialBlockBytes: Int64 = 4 * 1_048_576
""")

replace(path, """    private var pendingUserSeekUntil = Date.distantPast
    private var pendingUrgentRange: Range<Int64>?
    private var pendingUrgentIsMetadata = false
    private var lastConcretePlaybackDemand: Range<Int64>?
""", """    private var pendingUserSeekUntil = Date.distantPast
    private var pendingPlaybackUrgentRange: Range<Int64>?
    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
""")

replace(path, """        let candidate = lower..<upper
        if let existing = pendingUrgentRange, existing.contains(lower), existing.upperBound >= upper { return }
        pendingUrgentRange = candidate
        pendingUrgentIsMetadata = metadata
        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "urgent range=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata) reason=\\(reason) slot0Only=\\(!metadata)"
        )
""", """        let candidate = lower..<upper
        if metadata {
            if let existing = pendingMetadataRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingMetadataRange = candidate
        } else {
            if let existing = pendingPlaybackUrgentRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingPlaybackUrgentRange = candidate
        }
        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "urgent range=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata) reason=\\(reason) slot0Only=\\(!metadata)"
        )
""")

replace(path, """    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        // If Slot 0 is already serving urgent playback, a pending metadata probe is equally
        // startup-critical and may use Slot 1. Background sequential traffic must yield first.
        if let urgent = pendingUrgentRange, pendingUrgentIsMetadata, !store.contains(urgent), slotClaims[0]?.role == .urgentPlayback, slotTasks[1] == nil {
            pendingUrgentRange = nil
            pendingUrgentIsMetadata = false
            startSlot(1, claim: SlotClaim(range: urgent, role: .metadata), reason: "metadata-\\(reason)")
        }

        if slotTasks[0] == nil {
            if let urgent = pendingUrgentRange, !store.contains(urgent) {
                let role: ClaimRole = pendingUrgentIsMetadata ? .metadata : .urgentPlayback
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                startSlot(0, claim: SlotClaim(range: urgent, role: role), reason: reason)
            } else {
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                // Do not spend the other connection on background data while critical metadata
                // is still in flight on Slot 1.
                if slotClaims[1]?.role != .metadata, let range = nextSequentialClaim(resource: resource) {
                    startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason)
                }
            }
        }

        // Slot 1 is background-only outside the explicit metadata path above. Any urgent/metadata
        // work on Slot 0 or any queued critical range suppresses sequential restart, including the
        // finishSlot -> scheduleSlots path after cancellation.
        guard secondaryEnabled, Date() >= secondaryCooldownUntil, slotTasks[1] == nil, pendingUrgentRange == nil, slotClaims[0]?.role == .sequential else {
            refreshMetrics(resource: resource)
            return
        }
        if let range = nextSequentialClaim(resource: resource) {
            startSlot(1, claim: SlotClaim(range: range, role: .sequential), reason: "secondary-\\(reason)")
        }
        refreshMetrics(resource: resource)
    }
""", """    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        // A tiny metadata probe (typical MP4/MKV tail index) may use Slot 1 while Slot 0 is
        // already serving urgent playback. Larger metadata stays on Slot 0 because worker 1 can
        // have a much slower cold-start on some 115 CDN paths.
        if let metadata = pendingMetadataRange, Int64(metadata.count) <= secondaryMetadataMaxBytes, !store.contains(metadata), slotClaims[0]?.role == .urgentPlayback, slotTasks[1] == nil {
            pendingMetadataRange = nil
            startSlot(1, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }

        if slotTasks[0] == nil {
            if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent) {
                pendingPlaybackUrgentRange = nil
                startSlot(0, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: reason)
            } else if let metadata = pendingMetadataRange, !store.contains(metadata) {
                pendingMetadataRange = nil
                startSlot(0, claim: SlotClaim(range: metadata, role: .metadata), reason: reason)
            } else {
                pendingPlaybackUrgentRange = nil
                if pendingMetadataRange.map({ store.contains($0) }) == true { pendingMetadataRange = nil }
                // Do not spend the other connection on background data while critical metadata
                // is still in flight on Slot 1.
                if slotClaims[1]?.role != .metadata, let range = nextSequentialClaim(resource: resource) {
                    startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason)
                }
            }
        }

        // Slot 1 is background-only outside the explicit tiny-metadata path above. Any queued
        // critical demand or non-sequential work on Slot 0 suppresses sequential restart, including
        // the finishSlot -> scheduleSlots path after cancellation.
        guard secondaryEnabled, Date() >= secondaryCooldownUntil, slotTasks[1] == nil, pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[0]?.role == .sequential else {
            refreshMetrics(resource: resource)
            return
        }
        if let range = nextSequentialClaim(resource: resource) {
            startSlot(1, claim: SlotClaim(range: range, role: .sequential), reason: "secondary-\\(reason)")
        }
        refreshMetrics(resource: resource)
    }
""")

replace(path, """            if slot == 0, claim.role == .urgentPlayback, downloadedBytes >= Int64(claim.range.count), pendingUrgentRange == nil, slotClaims[1]?.role != .metadata, !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after urgent playback settled")
            }
""", """            if slot == 0, claim.role == .urgentPlayback, downloadedBytes >= Int64(claim.range.count), pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[1]?.role != .metadata, !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after urgent playback settled")
            }
""")

replace(path, """        if let error, !isCancellation(error) {
            metricsValue.rangeFailureCount += 1
""", """        if let error, !isCancellation(error) {
            if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            metricsValue.rangeFailureCount += 1
""")

replace(path, """        // A concrete playback read must never wait for an entire background sequential block.
        // If slot 0 owns the requested byte as a sequential claim, promote that same byte range
        // to the streaming urgent lane so the first 1 MiB becomes visible immediately. Slot 1
        // remains available for background throughput and may overlap safely in the sparse store.
""", """        // A concrete playback read must never wait for an entire background sequential block.
        // If Slot 0 owns the requested byte as a sequential claim, promote that same byte range
        // to the streaming urgent lane so the first 1 MiB becomes visible immediately. Any active
        // Slot 1 background claim yields instead of overlapping the urgent playback range.
""")
