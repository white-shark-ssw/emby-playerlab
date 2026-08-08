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

replace_once(
'''    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
''',
'''    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var startupMetadataRetryRequested: Set<Int> = []
''')

replace_once(
'''        if claim.role == .sequential {
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
''',
'''        if claim.role == .sequential {
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
        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
            armStartupMetadataStragglerWatchdog(slot: slot, generation: generation)
        }
''')

replace_once(
'''                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            recordNetworkBytes(Int64(chunk.count))
                            let writtenLower = claim.range.lowerBound + receivedForClaim - Int64(chunk.count)
''',
'''                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            if claim.role == .startupMetadata { startupMetadataReceivedBytes[slot] = receivedForClaim }
                            recordNetworkBytes(Int64(chunk.count))
                            let writtenLower = claim.range.lowerBound + receivedForClaim - Int64(chunk.count)
''')

replace_once(
'''        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        if liveRotation {
''',
'''        let startupRetry = startupMetadataRetryRequested.remove(slot) != nil
        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        if startupRetry {
            startupMetadataQueue.insert(claim.range, at: 0)
            let reset = client.resetStreamLane(worker: slot, reason: "startup-metadata-straggler")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\\(slot) action=straggler-reset range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) success=\\(reset)")
        } else if liveRotation {
''')

watchdog_marker = '''    private func armStartupTailGraceResume() {
'''
watchdog_helpers = '''    private func armStartupMetadataStragglerWatchdog(slot: Int, generation: Int) {
        let delay = liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkStartupMetadataStraggler(slot: slot, generation: generation)
        }
    }

    private func checkStartupMetadataStraggler(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .startupMetadata, startupMetadataReceivedBytes[slot, default: 0] == 0, !startupMetadataRetryRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard slotClaims[peerSlot]?.role == .startupMetadata, startupMetadataReceivedBytes[peerSlot, default: 0] > 0 else { return }
        startupMetadataRetryRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\\(slot) action=straggler-cancel peer=\\(peerSlot) range=\\(slotClaims[slot]?.range.description ?? \"none\")")
        cancelSlot(slot, reason: "startup-metadata-straggler")
    }

'''
replace_once(watchdog_marker, watchdog_helpers + watchdog_marker)

for required in [
    "!liveLaneResetPending.contains(0)",
    "if slot == 1, Date() < secondaryCooldownUntil { continue }",
    "let peerDelay = liveLaneFirstBytePeerTimeoutSeconds",
    "let delay = startupTailDemandGraceSeconds",
    "(resource?.contentLength ?? 0) >= 4 * 1_073_741_824",
    "if attempt < 10",
    "startupMetadataRetryRequested",
    "armStartupMetadataStragglerWatchdog",
    "action=straggler-cancel",
    "action=straggler-reset",
]:
    if required not in text:
        raise SystemExit(f"review fix missing: {required}")

path.write_text(text)
print("Applied v0.12.1 self-review fixes and startup metadata straggler recovery")
