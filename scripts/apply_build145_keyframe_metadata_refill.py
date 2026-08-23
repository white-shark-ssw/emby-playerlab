from pathlib import Path

transport_path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
identity_path = Path("Sources/Core/AppIdentity.swift")
transport = transport_path.read_text()
identity = identity_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Build145 {label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


def replace_count(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"Build145 {label}: expected {expected} matches, got {count}")
    return text.replace(old, new)

# Version only; no deployment-target change.
if identity.count('"0.13.77"') != 2:
    raise SystemExit("Build145 AppIdentity: expected two 0.13.77 markers")
identity = identity.replace('"0.13.77"', '"0.13.78"')

transport = replace_once(
    transport,
    '''        case urgentPlayback\n        case metadata\n        case startupMetadata\n''',
    '''        case urgentPlayback\n        case metadata\n        case keyframeMetadata\n        case startupMetadata\n''',
    "claim role"
)

transport = replace_once(
    transport,
    '''    private struct SeekTraceContext {\n        let serial: Int\n        let target: Double\n        let startedAt: Date\n    }\n\n''',
    '''    private struct SeekTraceContext {\n        let serial: Int\n        let target: Double\n        let startedAt: Date\n    }\n\n    private struct KeyframeMetadataMissKey: Hashable {\n        let offset: Int64\n        let reason: String\n    }\n\n    private struct KeyframeMetadataMissState {\n        var lastLoggedAt: Date\n        var suppressedCount: Int\n    }\n\n''',
    "miss state types"
)

transport = replace_once(
    transport,
    '''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576\n    private let startupMetadataSegmentBytes: Int64 = 1 * 1_048_576\n''',
    '''    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576\n    private let keyframeMetadataRefillBytes: Int64 = 512 * 1024\n    private let maximumKeyframeMetadataRefillQueue = 16\n    private let keyframeMetadataMissLogIntervalSeconds: TimeInterval = 5\n    private let startupMetadataSegmentBytes: Int64 = 1 * 1_048_576\n''',
    "refill constants"
)

transport = replace_once(
    transport,
    '''    private var pendingPlaybackUrgentRange: Range<Int64>?\n    private var pendingMetadataRange: Range<Int64>?\n    private var lastBlockingPlaybackDemand: Range<Int64>?\n''',
    '''    private var pendingPlaybackUrgentRange: Range<Int64>?\n    private var pendingMetadataRange: Range<Int64>?\n    private var pendingKeyframeMetadataRanges: [Range<Int64>] = []\n    private var keyframeMetadataMissStates: [KeyframeMetadataMissKey: KeyframeMetadataMissState] = [:]\n    private var lastBlockingPlaybackDemand: Range<Int64>?\n''',
    "refill state"
)

old_cached_reader = '''    func readCachedMetadata(offset: Int64, length: Int) async -> Data? {\n        guard !stopped, length > 0, offset >= 0 else { return nil }\n        guard let resolved = resource, let store else {\n            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(length) result=miss reason=resource-not-ready mode=cache-only-no-network")\n            return nil\n        }\n        guard offset < resolved.contentLength else { return Data() }\n        let requested = min(length, Int(resolved.contentLength - offset))\n        guard requested > 0 else { return Data() }\n        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        guard available > 0 else {\n            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=0 result=miss mode=cache-only-no-network")\n            return nil\n        }\n        let count = min(requested, Int(available))\n        guard let data = try? await store.readWhenAvailable(offset: offset, maximumLength: count, timeout: 0), !data.isEmpty else {\n            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=\\(available) result=miss reason=store-read-unavailable mode=cache-only-no-network")\n            return nil\n        }\n        return data\n    }\n'''

new_cached_reader = '''    func readCachedMetadata(offset: Int64, length: Int) async -> Data? {\n        guard !stopped, length > 0, offset >= 0 else { return nil }\n        guard let resolved = resource, let store else {\n            logKeyframeMetadataMiss(offset: offset, requested: length, reason: "resource-not-ready", refillRange: nil)\n            return nil\n        }\n        guard offset < resolved.contentLength else { return Data() }\n        let requested = min(length, Int(resolved.contentLength - offset))\n        guard requested > 0 else { return Data() }\n        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        guard available > 0 else {\n            let refill = enqueueKeyframeMetadataRefill(offset: offset, requested: requested, resource: resolved)\n            logKeyframeMetadataMiss(offset: offset, requested: requested, reason: "not-cached", refillRange: refill)\n            return nil\n        }\n        let count = min(requested, Int(available))\n        guard let data = try? await store.readWhenAvailable(offset: offset, maximumLength: count, timeout: 0), !data.isEmpty else {\n            logKeyframeMetadataMiss(offset: offset, requested: requested, reason: "store-read-unavailable", refillRange: nil)\n            return nil\n        }\n        return data\n    }\n\n    @discardableResult\n    private func enqueueKeyframeMetadataRefill(offset: Int64, requested: Int, resource: TransportResolvedResource) -> Range<Int64>? {\n        guard !stopped, let store, requested > 0, offset >= 0, offset < resource.contentLength else { return nil }\n        let lower = min(max(0, offset), max(0, resource.contentLength - 1))\n        let upper = min(resource.contentLength, safeAdd(lower, max(Int64(requested), keyframeMetadataRefillBytes)))\n        guard upper > lower else { return nil }\n        let candidate = lower..<upper\n        if store.contains(candidate) { return candidate }\n        if let active = slotClaims.values.first(where: { $0.role == .keyframeMetadata && $0.range.contains(lower) }) { return active.range }\n        if let existing = pendingKeyframeMetadataRanges.first(where: { $0.contains(lower) && $0.upperBound >= candidate.upperBound }) { return existing }\n\n        var merged = candidate\n        pendingKeyframeMetadataRanges.removeAll { existing in\n            let overlapsOrTouches = existing.lowerBound <= merged.upperBound && merged.lowerBound <= existing.upperBound\n            guard overlapsOrTouches else { return false }\n            merged = min(existing.lowerBound, merged.lowerBound)..<max(existing.upperBound, merged.upperBound)\n            return true\n        }\n        pendingKeyframeMetadataRanges.append(merged)\n        if pendingKeyframeMetadataRanges.count > maximumKeyframeMetadataRefillQueue {\n            pendingKeyframeMetadataRanges.removeFirst(pendingKeyframeMetadataRanges.count - maximumKeyframeMetadataRefillQueue)\n        }\n        DiagnosticsLogger.shared.playback("KeyframeMetadataRefill", "action=queued range=\\(merged.lowerBound)-\\(merged.upperBound) bytes=\\(merged.count) queue=\\(pendingKeyframeMetadataRanges.count) priority=background-below-urgent source=keyframe-cache-miss")\n        scheduleSlots(reason: "keyframe-metadata-refill")\n        return merged\n    }\n\n    private func logKeyframeMetadataMiss(offset: Int64, requested: Int, reason: String, refillRange: Range<Int64>?) {\n        let key = KeyframeMetadataMissKey(offset: offset, reason: reason)\n        let now = Date()\n        if var state = keyframeMetadataMissStates[key] {\n            if now.timeIntervalSince(state.lastLoggedAt) < keyframeMetadataMissLogIntervalSeconds {\n                state.suppressedCount += 1\n                keyframeMetadataMissStates[key] = state\n                return\n            }\n            let suppressed = state.suppressedCount\n            state.lastLoggedAt = now\n            state.suppressedCount = 0\n            keyframeMetadataMissStates[key] = state\n            let refill = refillRange.map { "\\($0.lowerBound)-\\($0.upperBound)" } ?? "none"\n            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) result=miss reason=\\(reason) repeated=\\(suppressed) refill=\\(refill) mode=cache-read-deferred-unified-refill")\n            return\n        }\n        keyframeMetadataMissStates[key] = KeyframeMetadataMissState(lastLoggedAt: now, suppressedCount: 0)\n        let refill = refillRange.map { "\\($0.lowerBound)-\\($0.upperBound)" } ?? "none"\n        DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) result=miss reason=\\(reason) repeated=0 refill=\\(refill) mode=cache-read-deferred-unified-refill")\n    }\n\n    private func finishKeyframeMetadataRefillLog(range: Range<Int64>, result: String) {\n        var suppressed = 0\n        let keys = keyframeMetadataMissStates.keys.filter { range.contains($0.offset) }\n        for key in keys {\n            suppressed += keyframeMetadataMissStates[key]?.suppressedCount ?? 0\n            keyframeMetadataMissStates.removeValue(forKey: key)\n        }\n        DiagnosticsLogger.shared.playback("KeyframeMetadataRefill", "result=\\(result) range=\\(range.lowerBound)-\\(range.upperBound) bytes=\\(range.count) suppressedMisses=\\(suppressed) queue=\\(pendingKeyframeMetadataRanges.count)")\n    }\n'''
transport = replace_once(transport, old_cached_reader, new_cached_reader, "cached metadata reader")

secondary_guard = '''        if !secondaryEnabled {\n            if slotTasks[0] == nil, !liveLaneResetPending.contains(0), !liveLaneSourceRefreshPending.contains(0), let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }\n            refreshMetrics(resource: resource)\n            return\n        }\n'''
secondary_with_refill = secondary_guard + '''\n        if !pendingKeyframeMetadataRanges.isEmpty, !slotClaims.values.contains(where: { $0.role == .keyframeMetadata }), let slot = firstIdleForegroundSlot() {\n            while !pendingKeyframeMetadataRanges.isEmpty {\n                let range = pendingKeyframeMetadataRanges.removeFirst()\n                if store.contains(range) {\n                    finishKeyframeMetadataRefillLog(range: range, result: "already-cached")\n                    continue\n                }\n                startSlot(slot, claim: SlotClaim(range: range, role: .keyframeMetadata), reason: "keyframe-metadata-\\(reason)")\n                break\n            }\n        }\n'''
transport = replace_once(transport, secondary_guard, secondary_with_refill, "low-priority scheduler insertion")

transport = replace_once(
    transport,
    '''        if firstIdleForegroundSlot() != nil { return }\n        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }\n''',
    '''        if firstIdleForegroundSlot() != nil { return }\n        if let keyframeClaim = slotClaims.first(where: { $0.value.role == .keyframeMetadata }) {\n            if !pendingKeyframeMetadataRanges.contains(where: { $0.lowerBound == keyframeClaim.value.range.lowerBound && $0.upperBound == keyframeClaim.value.range.upperBound }) {\n                pendingKeyframeMetadataRanges.insert(keyframeClaim.value.range, at: 0)\n            }\n            cancelSlot(keyframeClaim.key, reason: "urgent-preempts-keyframe-metadata")\n            return\n        }\n        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }\n''',
    "urgent preemption"
)

transport = replace_once(
    transport,
    '''        for slot in [0, 1] where slotClaims[slot]?.role == .sequential { cancelSlot(slot, reason: "startup-metadata-preempt") }\n''',
    '''        for slot in [0, 1] where slotClaims[slot]?.role == .sequential || slotClaims[slot]?.role == .keyframeMetadata { cancelSlot(slot, reason: "startup-metadata-preempt") }\n''',
    "startup metadata preemption"
)

transport = replace_count(
    transport,
    '''if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }''',
    '''if claim.role == .metadata || claim.role == .startupMetadata || claim.role == .keyframeMetadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }''',
    1,
    "streamed metadata classification"
)

transport = replace_count(
    transport,
    '''            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) }\n            else { rangeMap.insertPlayback(written) }''',
    '''            if claim.role == .metadata || claim.role == .startupMetadata || claim.role == .keyframeMetadata { rangeMap.insertMetadata(written) }\n            else { rangeMap.insertPlayback(written) }''',
    1,
    "completed metadata classification"
)

transport = replace_once(
    transport,
    '''        if let error, !isCancellation(error) {\n''',
    '''        if claim.role == .keyframeMetadata {\n            let refillResult: String\n            if error == nil, (downloadedBytes ?? 0) >= Int64(claim.range.count) { refillResult = "completed" }\n            else if let error, isCancellation(error) { refillResult = "preempted" }\n            else { refillResult = "failed-or-partial" }\n            finishKeyframeMetadataRefillLog(range: claim.range, result: refillResult)\n        }\n\n        if let error, !isCancellation(error) {\n''',
    "refill completion logging"
)

transport = replace_once(
    transport,
    '''        slotTasks.removeAll()\n        slotClaims.removeAll()\n        rangeMap.clearDownloading(lane: "slot0")\n''',
    '''        slotTasks.removeAll()\n        slotClaims.removeAll()\n        pendingKeyframeMetadataRanges.removeAll(keepingCapacity: false)\n        keyframeMetadataMissStates.removeAll(keepingCapacity: false)\n        rangeMap.clearDownloading(lane: "slot0")\n''',
    "stop cleanup"
)

transport_path.write_text(transport)
identity_path.write_text(identity)
print("Build145 keyframe metadata refill patch applied")
