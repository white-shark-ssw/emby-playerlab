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
'''    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var startupMetadataRetryRequested: Set<Int> = []
''',
'''    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var startupMetadataStartedAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataLastProgressAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataRetryRequested: Set<Int> = []
''')

replace_once(
'''        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
            armStartupMetadataStragglerWatchdog(slot: slot, generation: generation)
        }
''',
'''        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
            startupMetadataStartedAt[slot] = Date()
            armStartupMetadataStragglerWatchdog(slot: slot, generation: generation)
        }
''')

replace_once(
'''                            if claim.role == .startupMetadata { startupMetadataReceivedBytes[slot] = receivedForClaim }
''',
'''                            if claim.role == .startupMetadata {
                                startupMetadataReceivedBytes[slot] = receivedForClaim
                                startupMetadataLastProgressAt[slot] = Date()
                            }
''')

old_check = '''    private func checkStartupMetadataStraggler(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .startupMetadata, startupMetadataReceivedBytes[slot, default: 0] == 0, !startupMetadataRetryRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        guard slotClaims[peerSlot]?.role == .startupMetadata, startupMetadataReceivedBytes[peerSlot, default: 0] > 0 else { return }
        startupMetadataRetryRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\\(slot) action=straggler-cancel peer=\\(peerSlot) range=\\(slotClaims[slot]?.range.description ?? \"none\")")
        cancelSlot(slot, reason: "startup-metadata-straggler")
    }
'''
new_check = '''    private func checkStartupMetadataStraggler(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .startupMetadata, startupMetadataReceivedBytes[slot, default: 0] == 0, !startupMetadataRetryRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let startedAt = startupMetadataStartedAt[slot, default: .distantPast]
        let peerProgressAt = startupMetadataLastProgressAt[peerSlot, default: .distantPast]
        guard peerProgressAt > startedAt else { return }
        startupMetadataRetryRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\\(slot) action=straggler-cancel peer=\\(peerSlot) peerProgressMsAgo=\\(Int(Date().timeIntervalSince(peerProgressAt) * 1000)) range=\\(slotClaims[slot]?.range.description ?? \"none\")")
        cancelSlot(slot, reason: "startup-metadata-straggler")
    }
'''
replace_once(old_check, new_check)

for required in ["startupMetadataStartedAt", "startupMetadataLastProgressAt", "peerProgressAt > startedAt", "peerProgressMsAgo="]:
    if required not in text:
        raise SystemExit(f"timestamp straggler fix missing: {required}")

path.write_text(text)
print("Applied progress-timestamp startup straggler refinement")
