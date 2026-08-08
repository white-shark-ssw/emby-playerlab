from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"{path}: target not found")
    p.write_text(text.replace(old, new, 1))


path = "Sources/Transport/UnifiedMediaTransportSession.swift"

replace_once(path,
'''            if let active = slotClaims[0], active.role == .urgentPlayback, !active.range.contains(demand.lowerBound) { cancelSlot(0, reason: "replace-stale-urgent") }
''',
'''            for slot in [0, 1] {
                if let active = slotClaims[slot], active.role == .urgentPlayback, !active.range.contains(demand.lowerBound) { cancelSlot(slot, reason: "replace-stale-urgent") }
            }
''')

replace_once(path,
'''            if let active = slotClaims[0], active.role == .urgentPlayback, !active.range.contains(range.lowerBound) { cancelSlot(0, reason: "replace-stale-urgent") }
''',
'''            for slot in [0, 1] {
                if let active = slotClaims[slot], active.role == .urgentPlayback, !active.range.contains(range.lowerBound) { cancelSlot(slot, reason: "replace-stale-urgent") }
            }
''')

old = '''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, Date().timeIntervalSince(createdAt) < 35, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
    }
'''
new = '''    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        if let warmup = startupTailWarmupRange, !startupTailWarmupCompleted, range.upperBound > warmup.lowerBound, range.lowerBound < warmup.upperBound { return true }
        guard Date().timeIntervalSince(createdAt) < 35 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
    }
'''
replace_once(path, old, new)

print("v0.12.0 Scheduler v2 refinements applied")
