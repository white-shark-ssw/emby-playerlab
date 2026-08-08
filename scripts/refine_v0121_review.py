from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"target not found: {old[:140]!r}")
    text = text.replace(old, new, 1)

replace_once(
'''            for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot) {
                while !startupMetadataQueue.isEmpty {
''',
'''            for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot) {
                if slot == 1, Date() < secondaryCooldownUntil { continue }
                while !startupMetadataQueue.isEmpty {
''')

replace_once(
'''        if !secondaryEnabled {
            if slotTasks[0] == nil, let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }
''',
'''        if !secondaryEnabled {
            if slotTasks[0] == nil, !liveLaneResetPending.contains(0), let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }
''')

replace_once(
'''                if claim.range.lowerBound == 0, Int64(claim.range.count) <= largeFileInitialSequentialBlockBytes, source.mediaSource.normalizedContainer == "mp4", resource?.contentLength ?? 0 >= 4 * 1_073_741_824 {
''',
'''                if claim.range.lowerBound == 0, Int64(claim.range.count) <= largeFileInitialSequentialBlockBytes, source.mediaSource.normalizedContainer == "mp4", (resource?.contentLength ?? 0) >= 4 * 1_073_741_824 {
''')

replace_once(
'''    private func armStartupTailGraceResume() {
        guard !startupTailGraceResumeScheduled else { return }
        startupTailGraceResumeScheduled = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(startupTailDemandGraceSeconds * 1_000_000_000))
            await self?.resumeAfterStartupTailGrace()
        }
    }
''',
'''    private func armStartupTailGraceResume() {
        guard !startupTailGraceResumeScheduled else { return }
        startupTailGraceResumeScheduled = true
        let delay = startupTailDemandGraceSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.resumeAfterStartupTailGrace()
        }
    }
''')

replace_once(
'''    private func armFirstByteWatchdog(slot: Int, generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(liveLaneFirstBytePeerTimeoutSeconds * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: false)
            try? await Task.sleep(nanoseconds: UInt64((liveLaneFirstByteHardTimeoutSeconds - liveLaneFirstBytePeerTimeoutSeconds) * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: true)
        }
    }
''',
'''    private func armFirstByteWatchdog(slot: Int, generation: Int) {
        let peerDelay = liveLaneFirstBytePeerTimeoutSeconds
        let hardDelay = liveLaneFirstByteHardTimeoutSeconds - liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(peerDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: false)
            try? await Task.sleep(nanoseconds: UInt64(hardDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: true)
        }
    }
''')

replace_once('''        if attempt < 5 {\n''', '''        if attempt < 10 {\n''')

for required in [
    "!liveLaneResetPending.contains(0)",
    "if slot == 1, Date() < secondaryCooldownUntil { continue }",
    "let peerDelay = liveLaneFirstBytePeerTimeoutSeconds",
    "let delay = startupTailDemandGraceSeconds",
    "(resource?.contentLength ?? 0) >= 4 * 1_073_741_824",
    "if attempt < 10",
]:
    if required not in text:
        raise SystemExit(f"review fix missing: {required}")

path.write_text(text)
print("Applied v0.12.1 self-review fixes")
