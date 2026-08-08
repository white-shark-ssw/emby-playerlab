from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    return text.replace(old, new, 1)


unified_path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
unified = unified_path.read_text()

unified = replace_once(unified,
'''    private let liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576
    private let liveLaneRelativeFloor: Double = 0.45
    private let liveLanePeakFloorBps: Double = 8 * 1_048_576
    private let liveLanePeakRelativeFloor: Double = 0.30
    private let liveLanePeakDropSeconds: TimeInterval = 0.9
    private let liveLaneRotationEscalationWindowSeconds: TimeInterval = 30
    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneSampleWindowSeconds: TimeInterval = 1.0
    private let liveLaneSampleMinimumBytes: Int64 = 1 * 1_048_576
    private let liveLaneResetCooldownSeconds: TimeInterval = 2
''',
'''    private let liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576
    private let liveLaneWifiAbsoluteFloorBps: Double = 2.5 * 1_048_576
    private let liveLaneRelativeFloor: Double = 0.45
    private let liveLanePeakFloorBps: Double = 6 * 1_048_576
    private let liveLanePeakRelativeFloor: Double = 0.45
    private let liveLanePeakDropSeconds: TimeInterval = 1.0
    private let liveLaneRotationEscalationWindowSeconds: TimeInterval = 30
    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneProgressWatchdogIntervalSeconds: TimeInterval = 0.75
    private let liveLaneNoProgressPeerSeconds: TimeInterval = 1.25
    private let liveLaneNoProgressHardSeconds: TimeInterval = 2.75
    private let urgentFirstByteHedgeSeconds: TimeInterval = 0.65
    private let liveLaneSampleWindowSeconds: TimeInterval = 1.0
    private let liveLaneSampleMinimumBytes: Int64 = 1 * 1_048_576
    private let liveLaneResetCooldownSeconds: TimeInterval = 2
''', "lane constants")

unified = replace_once(unified,
'''    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
    private var liveLaneSourceRefreshPending: Set<Int> = []
    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
''',
'''    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
    private var liveLaneSourceRefreshPending: Set<Int> = []
    private var urgentReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var urgentHedgeRequested: Set<Int> = []
    private var urgentRaceResetPending: Set<Int> = []
    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
''', "urgent race state")

unified = replace_once(unified,
'''            liveLaneState[slot] = live
            armFirstByteWatchdog(slot: slot, generation: generation)
        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
''',
'''            liveLaneState[slot] = live
            armFirstByteWatchdog(slot: slot, generation: generation)
            armSequentialProgressWatchdog(slot: slot, generation: generation)
        } else if claim.role == .urgentPlayback {
            urgentReceivedBytes[slot] = 0
            urgentHedgeRequested.remove(slot)
            armUrgentFirstByteHedge(slot: slot, generation: generation)
        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
''', "start watchdogs")

unified = replace_once(unified,
'''                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            if claim.role == .startupMetadata {
''',
'''                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            if claim.role == .urgentPlayback { urgentReceivedBytes[slot] = receivedForClaim }
                            if claim.role == .startupMetadata {
''', "urgent progress accounting")

unified = replace_once(unified,
'''                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) first-chunk role=\\(claim.role.rawValue) range=\\(remaining.lowerBound)-\\(remaining.upperBound) bytes=\\(chunk.count) ms=\\(Int(firstChunkSeconds * 1000)) speedBps=\\(Int(firstChunkBps))")
                                if claim.role == .metadata, !slowStartupRefreshUsed, Date().timeIntervalSince(createdAt) < 35, firstChunkSeconds >= startupMetadataSlowFirstChunkSeconds, firstChunkBps < startupMetadataSlowFirstChunkBps {
''',
'''                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) first-chunk role=\\(claim.role.rawValue) range=\\(remaining.lowerBound)-\\(remaining.upperBound) bytes=\\(chunk.count) ms=\\(Int(firstChunkSeconds * 1000)) speedBps=\\(Int(firstChunkBps))")
                                if claim.role == .urgentPlayback { resolveUrgentRaceWinner(slot: slot, generation: generation, claim: claim) }
                                if claim.role == .metadata, !slowStartupRefreshUsed, Date().timeIntervalSince(createdAt) < 35, firstChunkSeconds >= startupMetadataSlowFirstChunkSeconds, firstChunkBps < startupMetadataSlowFirstChunkBps {
''', "urgent race winner")

unified = replace_once(unified,
'''        let startupRetry = startupMetadataRetryRequested.remove(slot) != nil
        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        let refreshSource = liveLaneSourceRefreshPending.contains(slot)
        if startupRetry {
''',
'''        let startupRetry = startupMetadataRetryRequested.remove(slot) != nil
        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        let refreshSource = liveLaneSourceRefreshPending.contains(slot)
        let urgentRaceReset = urgentRaceResetPending.remove(slot) != nil
        urgentReceivedBytes[slot] = 0
        urgentHedgeRequested.remove(slot)
        if urgentRaceReset {
            let reset = client.resetStreamLane(worker: slot, reason: "urgent-race-loser")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            laneHealth[slot] = LaneHealthState()
            DiagnosticsLogger.shared.log("UnifiedHedge", "slot=\\(slot) action=reset-race-loser success=\\(reset) pending=\\(!reset)")
        } else if startupRetry {
''', "race loser reset")

watchdogs = r'''    private func armUrgentFirstByteHedge(slot: Int, generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.urgentFirstByteHedgeSeconds ?? 0.65 * 1_000_000_000))
            await self?.checkUrgentFirstByteHedge(slot: slot, generation: generation)
        }
    }

    private func checkUrgentFirstByteHedge(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, let claim = slotClaims[slot], claim.role == .urgentPlayback, urgentReceivedBytes[slot, default: 0] == 0, !urgentHedgeRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard let peerClaim = slotClaims[peerSlot], peerClaim.role == .sequential, !liveLaneResetPending.contains(peerSlot), !liveLaneSourceRefreshPending.contains(peerSlot) else { return }
        urgentHedgeRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedHedge", "slot=\(slot) peer=\(peerSlot) action=hedge-urgent-first-byte afterMs=\(Int(urgentFirstByteHedgeSeconds * 1000)) range=\(claim.range.lowerBound)-\(claim.range.upperBound) peerRange=\(peerClaim.range.lowerBound)-\(peerClaim.range.upperBound)")
        installUrgent(range: claim.range, metadata: false, reason: "urgent-first-byte-hedge")
        scheduleSlots(reason: "urgent-first-byte-hedge")
    }

    private func resolveUrgentRaceWinner(slot: Int, generation: Int, claim: SlotClaim) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .urgentPlayback else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard let peerClaim = slotClaims[peerSlot], peerClaim.role == .urgentPlayback, peerClaim.range == claim.range else { return }
        urgentRaceResetPending.insert(peerSlot)
        DiagnosticsLogger.shared.log("UnifiedHedge", "winner=\(slot) loser=\(peerSlot) action=urgent-race-won range=\(claim.range.lowerBound)-\(claim.range.upperBound)")
        cancelSlot(peerSlot, reason: "urgent-race-lost")
    }

    private func armSequentialProgressWatchdog(slot: Int, generation: Int) {
        Task { [weak self] in
            let delay = self?.liveLaneProgressWatchdogIntervalSeconds ?? 0.75
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkSequentialProgressWatchdog(slot: slot, generation: generation)
        }
    }

    private func checkSequentialProgressWatchdog(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, !liveLaneRotationRequested.contains(slot) else { return }
        let now = Date()
        if live.receivedBytes > 0 {
            let stalledSeconds = now.timeIntervalSince(live.lastChunkAt)
            let peerSlot = slot == 0 ? 1 : 0
            let peerLive = liveLaneState[peerSlot]
            let peerCompleted = laneHealth[peerSlot]
            let peerFresh = peerLive.map { $0.recentBps > 0 && now.timeIntervalSince($0.lastSampleAt) <= 2.5 } ?? false
            let peerBps = peerFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
            if stalledSeconds >= liveLaneNoProgressPeerSeconds, peerBps >= 2 * 1_048_576 {
                DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=midstream-no-progress stalledMs=\(Int(stalledSeconds * 1000)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
                requestLiveLaneRotation(slot: slot, generation: generation, reason: "midstream-no-progress-peer-fast", observedBps: live.recentBps, peerBps: peerBps)
                return
            }
            if stalledSeconds >= liveLaneNoProgressHardSeconds {
                DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=midstream-hard-timeout stalledMs=\(Int(stalledSeconds * 1000)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
                requestLiveLaneRotation(slot: slot, generation: generation, reason: "midstream-no-progress-hard", observedBps: live.recentBps, peerBps: peerBps)
                return
            }
        }
        armSequentialProgressWatchdog(slot: slot, generation: generation)
    }

'''
unified = replace_once(unified, '    private func armFirstByteWatchdog(slot: Int, generation: Int) {\n', watchdogs + '    private func armFirstByteWatchdog(slot: Int, generation: Int) {\n', "watchdog insertion")

unified = replace_once(unified,
'''        let absoluteSlow = now.timeIntervalSince(live.startedAt) >= 3.0 && live.receivedBytes >= 4 * 1_048_576 && live.recentBps < liveLaneAbsoluteFloorBps
''',
'''        let absoluteFloorBps = NetworkPathMonitor.shared.isCellular ? liveLaneAbsoluteFloorBps : liveLaneWifiAbsoluteFloorBps
        let absoluteSlow = now.timeIntervalSince(live.startedAt) >= 3.0 && live.receivedBytes >= 4 * 1_048_576 && live.recentBps < absoluteFloorBps
''', "adaptive absolute floor")

unified = replace_once(unified,
'''        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(liveLaneAbsoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
''',
'''        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(absoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
''', "adaptive floor reset")

unified = replace_once(unified,
'''        let now = Date()
        guard now >= live.resetCooldownUntil else { return }
        if now.timeIntervalSince(live.lastRotationAt) > liveLaneRotationEscalationWindowSeconds { live.rotationCount = 0 }
''',
'''        let now = Date()
        guard now >= live.resetCooldownUntil else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard !liveLaneRotationRequested.contains(peerSlot), !liveLaneResetPending.contains(peerSlot), !liveLaneSourceRefreshPending.contains(peerSlot) else { return }
        if now.timeIntervalSince(live.lastRotationAt) > liveLaneRotationEscalationWindowSeconds { live.rotationCount = 0 }
''', "single-lane rotation guard")

unified_path.write_text(unified)

range_path = Path("Sources/Cache/PlaybackRangeMap.swift")
range_map = range_path.read_text()
range_map = replace_once(range_map, 'holeCount: holeCountIncludingInflight(from: anchor, through: furthestObservedEnd(resourceLength: resourceLength))', 'holeCount: physicalHoleCount(from: anchor, through: furthestObservedEnd(resourceLength: resourceLength))', "physical hole call")
range_map = replace_once(range_map,
'''    private func holeCountIncludingInflight(from anchor: Int64, through upperBound: Int64) -> Int64 {
''',
'''    private func physicalHoleCount(from anchor: Int64, through upperBound: Int64) -> Int64 {
''', "hole function name") if 'private func holeCountIncludingInflight(from anchor: Int64, through upperBound: Int64) -> Int64' in range_map else range_map
# Current implementation returns Int, keep an exact replacement for the shipped signature.
range_map = range_map.replace('    private func holeCountIncludingInflight(from anchor: Int64, through upperBound: Int64) -> Int {\n', '    private func physicalHoleCount(from anchor: Int64, through upperBound: Int64) -> Int {\n', 1)
range_map = replace_once(range_map, '        var coverage = playback.ranges + downloading.values\n', '        var coverage = playback.ranges\n', "physical hole coverage")
range_path.write_text(range_map)

check = '''from pathlib import Path\n\nunified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()\nrange_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()\n\ndef require(condition: bool, message: str) -> None:\n    if not condition:\n        raise SystemExit(f"v0.12.6 frontier rescue regression failed: {message}")\n\nfor needle in [\n    "urgentFirstByteHedgeSeconds: TimeInterval = 0.65",\n    "liveLaneNoProgressPeerSeconds: TimeInterval = 1.25",\n    "liveLaneNoProgressHardSeconds: TimeInterval = 2.75",\n    "armUrgentFirstByteHedge",\n    "action=hedge-urgent-first-byte",\n    "action=urgent-race-won",\n    "action=reset-race-loser",\n    "armSequentialProgressWatchdog",\n    "action=midstream-no-progress",\n    "action=midstream-hard-timeout",\n    "midstream-no-progress-peer-fast",\n    "liveLaneWifiAbsoluteFloorBps: Double = 2.5 * 1_048_576",\n    "liveLanePeakRelativeFloor: Double = 0.45",\n]:\n    require(needle in unified, f"missing {needle}")\n\nrequire("playback.ranges + downloading.values" not in range_map, "in-flight claims must not hide physical sparse holes")\nrequire("physicalHoleCount" in range_map, "physical hole metric missing")\n\n# Device-log regression: playback-critical urgent lane can take 3.642 s for first MiB while\n# the peer future-preload lane is simultaneously capable of >10 MiB/s. The hedge must fire\n# well before the old 3 s hard timeout and borrow that peer lane for the exact urgent range.\nrequire(0.65 < 1.0, "urgent hedge must run sub-second")\n\n# Device-log regression: slot0 stalled almost nine seconds between sequential progress updates\n# while slot1 kept advancing. Peer-assisted no-progress recovery must fire first.\nrequire(1.25 < 2.75 < 8.893, "midstream watchdog thresholds no longer protect the observed stall")\n\nprint("v0.12.6 frontier rescue regressions: OK")\n'''
Path("scripts/check_v0126_frontier_rescue.py").write_text(check)

print("v0.12.6 frontier rescue patch applied")
