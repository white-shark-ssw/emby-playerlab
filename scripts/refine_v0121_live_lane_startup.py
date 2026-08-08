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


text = text.replace('            configureStartupWarmupIfNeeded(resource: resolved)\n', '')

replace_once(
'''    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
    private let lookaheadSegments = 4
''',
'''    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
    private let startupTailDemandGraceSeconds: TimeInterval = 0.25
    private let lookaheadSegments = 4
''')

replace_once(
'''    private var startupMetadataPlanCompleted = false
    private var preferredBulkSlot = 0
''',
'''    private var startupMetadataPlanCompleted = false
    private var startupTailDemandGraceUntil = Date.distantPast
    private var startupTailGraceResumeScheduled = false
    private var preferredBulkSlot = 0
''')

replace_once(
'''    private var liveLaneState: [Int: LiveLaneState] = [0: LiveLaneState(), 1: LiveLaneState()]
    private var liveLaneRotationRequested: Set<Int> = []
''',
'''    private var liveLaneState: [Int: LiveLaneState] = [0: LiveLaneState(), 1: LiveLaneState()]
    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
''')

replace_once(
'''        if !startupMetadataQueue.isEmpty || slotClaims.values.contains(where: { $0.role == .startupMetadata }) {
            for slot in [0, 1] where slotTasks[slot] == nil {
''',
'''        if !startupMetadataQueue.isEmpty || slotClaims.values.contains(where: { $0.role == .startupMetadata }) {
            for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot) {
''')

replace_once(
'''        if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
            refreshMetrics(resource: resource)
            return
        }

        if !secondaryEnabled {
''',
'''        if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
            refreshMetrics(resource: resource)
            return
        }

        if startupMetadataPlanRange == nil, Date() < startupTailDemandGraceUntil {
            refreshMetrics(resource: resource)
            return
        }

        if !secondaryEnabled {
''')

replace_once(
'''        for slot in order where slotTasks[slot] == nil {
            if slot == 1, Date() < secondaryCooldownUntil { continue }
''',
'''        for slot in order where slotTasks[slot] == nil {
            if liveLaneResetPending.contains(slot) { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
''')

replace_once(
'''        for slot in order {
            guard slotTasks[slot] == nil else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
''',
'''        for slot in order {
            guard slotTasks[slot] == nil, !liveLaneResetPending.contains(slot) else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
''')

old_head = '''            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
                DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) action=await-actual-tail-demand")
            }
'''
new_head = '''            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
                if claim.range.lowerBound == 0, Int64(claim.range.count) <= largeFileInitialSequentialBlockBytes, source.mediaSource.normalizedContainer == "mp4", resource?.contentLength ?? 0 >= 4 * 1_073_741_824 {
                    startupTailDemandGraceUntil = Date().addingTimeInterval(startupTailDemandGraceSeconds)
                    DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) action=await-actual-tail-demand graceMs=\\(Int(startupTailDemandGraceSeconds * 1000))")
                    armStartupTailGraceResume()
                }
            }
'''
replace_once(old_head, new_head)

old_reset = '''        if liveRotation {
            let reset = client.resetStreamLane(worker: slot, reason: "live-lane-rotation")
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=reset-after-cancel success=\\(reset)")
            var health = LaneHealthState()
            health.resetCooldownUntil = Date().addingTimeInterval(liveLaneResetCooldownSeconds)
            laneHealth[slot] = health
        } else if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
'''
new_reset = '''        if liveRotation {
            let reset = client.resetStreamLane(worker: slot, reason: "live-lane-rotation")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=reset-after-cancel success=\\(reset) pending=\\(!reset)")
            var health = LaneHealthState()
            health.resetCooldownUntil = Date().addingTimeInterval(liveLaneResetCooldownSeconds)
            laneHealth[slot] = health
        } else if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
'''
replace_once(old_reset, new_reset)

helpers_marker = '''    private func armFirstByteWatchdog(slot: Int, generation: Int) {
'''
helpers = '''    private func armStartupTailGraceResume() {
        guard !startupTailGraceResumeScheduled else { return }
        startupTailGraceResumeScheduled = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(startupTailDemandGraceSeconds * 1_000_000_000))
            await self?.resumeAfterStartupTailGrace()
        }
    }

    private func resumeAfterStartupTailGrace() {
        startupTailGraceResumeScheduled = false
        guard !stopped, startupMetadataPlanRange == nil, Date() >= startupTailDemandGraceUntil else { return }
        scheduleSlots(reason: "startup-tail-grace-ended")
    }

    private func armLiveLaneResetRetry(slot: Int, attempt: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await self?.retryLiveLaneReset(slot: slot, attempt: attempt)
        }
    }

    private func retryLiveLaneReset(slot: Int, attempt: Int) {
        guard liveLaneResetPending.contains(slot), !stopped else { return }
        if client.resetStreamLane(worker: slot, reason: "live-lane-retry-\\(attempt)") {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=reset-retry success=true attempt=\\(attempt)")
            scheduleSlots(reason: "live-lane-reset-ready")
            return
        }
        if attempt < 5 {
            armLiveLaneResetRetry(slot: slot, attempt: attempt + 1)
        } else {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\\(slot) action=reset-retry give-up attempt=\\(attempt)")
            scheduleSlots(reason: "live-lane-reset-give-up")
        }
    }

'''
replace_once(helpers_marker, helpers + helpers_marker)

# If an actual startup-tail plan arrives during the grace window it owns both lanes immediately.
replace_once(
'''        startupMetadataPlanRange = plan
        startupMetadataPlanCompleted = false
''',
'''        startupMetadataPlanRange = plan
        startupMetadataPlanCompleted = false
        startupTailDemandGraceUntil = .distantPast
''')

# Final construction assertions.
if "configureStartupWarmupIfNeeded" in text:
    raise SystemExit("obsolete configureStartupWarmupIfNeeded call/helper remains")
if text.count("head warmup complete") != 1:
    raise SystemExit("head warmup diagnostic must be unique")
for required in ["startupTailDemandGraceSeconds", "liveLaneResetPending", "armLiveLaneResetRetry", "reset-retry", "graceMs="]:
    if required not in text:
        raise SystemExit(f"refinement missing {required}")

path.write_text(text)
print("Refined v0.12.1 startup grace and live-lane reset lifecycle")
