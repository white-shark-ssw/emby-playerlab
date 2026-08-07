from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, count))


path = "Sources/Transport/UnifiedMediaTransportSession.swift"

replace(path, "/// - Slot 0 may be repurposed for a real playback hole; slot 1 is never cancelled only\n///   because playback asks for a new range.\n", "/// - Slot 0 owns urgent playback; Slot 1 yields background bandwidth immediately when playback\n///   becomes urgent, and may temporarily serve critical metadata while Slot 0 is busy.\n")

replace(path, """        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) {
            if concretePlaybackDemand, slot0.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedDemand", "promote slot0 sequential->urgent request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) reason=\\(reason)")
                installUrgent(range: range, metadata: metadata, reason: "promote-\\(reason)")
                cancelSlot(0, reason: "promote-current-demand")
                scheduleSlots(reason: "promote-current-demand")
            }
            return
        }
        installUrgent(range: range, metadata: metadata, reason: reason)
""", """        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) {
            if concretePlaybackDemand, slot0.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedDemand", "promote slot0 sequential->urgent request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) reason=\\(reason)")
                installUrgent(range: range, metadata: metadata, reason: "promote-\\(reason)")
                cancelSlot(0, reason: "promote-current-demand")
                scheduleSlots(reason: "promote-current-demand")
            }
            return
        }
        if metadata, let slot1 = slotClaims[1], slot1.role == .metadata, slot1.range.contains(range.lowerBound) { return }
        installUrgent(range: range, metadata: metadata, reason: reason)
""")

replace(path, """        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "urgent range=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata) reason=\\(reason) slot0Only=true"
        )
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            cancelSlot(0, reason: "urgent-demand")
        }
""", """        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "urgent range=\\(candidate.lowerBound)-\\(candidate.upperBound) metadata=\\(metadata) reason=\\(reason) slot0Only=\\(!metadata)"
        )
        if let secondary = slotClaims[1], secondary.role == .sequential {
            cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")
        }
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            cancelSlot(0, reason: "urgent-demand")
        }
""")

replace(path, """    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }
        if slotTasks[0] == nil {
            if let urgent = pendingUrgentRange, !store.contains(urgent) {
                let role: ClaimRole = pendingUrgentIsMetadata ? .metadata : .urgentPlayback
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                startSlot(0, claim: SlotClaim(range: urgent, role: role), reason: reason)
            } else {
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                if let range = nextSequentialClaim(resource: resource) {
                    startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason)
                }
            }
        }

        guard secondaryEnabled, Date() >= secondaryCooldownUntil, slotTasks[1] == nil else {
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
""")

replace(path, """        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
        if slot == 0, claim.role == .urgentPlayback, !secondaryEnabled {
            secondaryEnabled = true
            DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled alongside urgent playback")
        }
        metricsValue.activeRequestCount = slotTasks.count + 1
""", """        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
        metricsValue.activeRequestCount = slotTasks.count + 1
""")

replace(path, """            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
            }
            if slot == 1 { secondaryFailureCount = 0 }
""", """            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
            }
            if claim.role == .metadata, downloadedBytes >= Int64(claim.range.count), !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after critical metadata")
            }
            if slot == 0, claim.role == .urgentPlayback, downloadedBytes >= Int64(claim.range.count), pendingUrgentRange == nil, slotClaims[1]?.role != .metadata, !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after urgent playback settled")
            }
            if slot == 1 { secondaryFailureCount = 0 }
""")

# v0.9.6 / Build 52 metadata.
replace("Sources/Core/AppIdentity.swift", '    static let sourceVersion = "0.9.5"\n', '    static let sourceVersion = "0.9.6"\n')
replace("Sources/Core/AppIdentity.swift", '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.5"\n', '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.6"\n')

p = Path("project.yml")
text = p.read_text()
p.write_text(text.replace('MARKETING_VERSION: "0.9.5"', 'MARKETING_VERSION: "0.9.6"').replace('CURRENT_PROJECT_VERSION: "51"', 'CURRENT_PROJECT_VERSION: "52"'))

replace("Config/Info.plist", '<key>CFBundleShortVersionString</key>\n\t<string>0.9.5</string>', '<key>CFBundleShortVersionString</key>\n\t<string>0.9.6</string>')
replace("Config/Info.plist", '<key>CFBundleVersion</key>\n\t<string>51</string>', '<key>CFBundleVersion</key>\n\t<string>52</string>')
