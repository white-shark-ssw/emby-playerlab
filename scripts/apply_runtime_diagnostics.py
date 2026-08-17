from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


# Keep a larger real-device diagnostic window.
path = Path("Sources/Diagnostics/DiagnosticsLogger.swift")
text = path.read_text()
text = replace_once(text, "    private let maximumPersistentBytes: UInt64 = 8 * 1024 * 1024\n", "    private let maximumPersistentBytes: UInt64 = 32 * 1024 * 1024\n", "DiagnosticsLogger maximumPersistentBytes")
text = replace_once(text, "            if self.entries.count > 10_000 {\n                self.entries.removeFirst(self.entries.count - 10_000)\n            }\n", "            if self.entries.count > 40_000 {\n                self.entries.removeFirst(self.entries.count - 40_000)\n            }\n", "DiagnosticsLogger in-memory entries")
text = replace_once(text, '        log("Lifecycle", "logger initialized bundle=\\(AppIdentity.version) source=\\(AppIdentity.sourceVersion)")\n', '        log("Lifecycle", "logger initialized bundle=\\(AppIdentity.version) source=\\(AppIdentity.sourceVersion)")\n        log("DiagnosticsProfile", "layout-safe-area + transport-race trace v2")\n', "DiagnosticsLogger profile marker")
path.write_text(text)


# Log the actual UIKit ownership chain. Uses only APIs available before iOS 15.
Path("Sources/Diagnostics/LayoutDiagnostics.swift").write_text(r'''import Foundation
import UIKit

enum LayoutDiagnostics {
    private static let lock = NSLock()
    private static var lastSignature = ""
    private static var lastLoggedAt = Date.distantPast

    static func log(bridge: UIViewController, phase: String, force: Bool = false) {
        guard let window = bridge.viewIfLoaded?.window else {
            DiagnosticsLogger.shared.log("LayoutTrace", "phase=\(phase) window=nil bridge=\(type(of: bridge))")
            return
        }

        let navigationController = bridge.navigationController
        let top = navigationController?.topViewController
        let root = window.rootViewController
        var chain: [String] = []
        var current: UIViewController? = bridge
        var depth = 0
        while let controller = current, depth < 10 {
            let view = controller.viewIfLoaded
            let frame = view.map { NSStringFromCGRect($0.frame) } ?? "nil"
            let bounds = view.map { NSStringFromCGRect($0.bounds) } ?? "nil"
            let safe = view.map { NSStringFromUIEdgeInsets($0.safeAreaInsets) } ?? "nil"
            chain.append("\(depth):\(type(of: controller)) frame=\(frame) bounds=\(bounds) safe=\(safe) add=\(NSStringFromUIEdgeInsets(controller.additionalSafeAreaInsets))")
            current = controller.parent
            depth += 1
        }

        let windowText = "bounds=\(NSStringFromCGRect(window.bounds)) safe=\(NSStringFromUIEdgeInsets(window.safeAreaInsets))"
        let navText: String
        if let navigationController = navigationController {
            navText = "type=\(type(of: navigationController)) frame=\(NSStringFromCGRect(navigationController.view.frame)) bounds=\(NSStringFromCGRect(navigationController.view.bounds)) safe=\(NSStringFromUIEdgeInsets(navigationController.view.safeAreaInsets)) add=\(NSStringFromUIEdgeInsets(navigationController.additionalSafeAreaInsets))"
        } else {
            navText = "nil"
        }
        let topText: String
        if let top = top, let view = top.viewIfLoaded {
            topText = "type=\(type(of: top)) frame=\(NSStringFromCGRect(view.frame)) bounds=\(NSStringFromCGRect(view.bounds)) safe=\(NSStringFromUIEdgeInsets(view.safeAreaInsets)) add=\(NSStringFromUIEdgeInsets(top.additionalSafeAreaInsets))"
        } else {
            topText = "nil"
        }
        let signature = "window={\(windowText)} nav={\(navText)} top={\(topText)} chain=[\(chain.joined(separator: " > "))]"

        let now = Date()
        lock.lock()
        let shouldLog = force || signature != lastSignature || now.timeIntervalSince(lastLoggedAt) >= 1.5
        if shouldLog {
            lastSignature = signature
            lastLoggedAt = now
        }
        lock.unlock()
        guard shouldLog else { return }

        DiagnosticsLogger.shared.log("LayoutTrace", "phase=\(phase) root=\(root.map { String(describing: type(of: $0)) } ?? "nil") \(signature)")
    }
}
''')


# Trace the current safe-area bridge before and after UIKit layout.
path = Path("Sources/UI/ImmersiveUIComponents.swift")
text = path.read_text()
text = replace_once(text, '''    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        safeAreaCoordinator?.apply(from: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        safeAreaCoordinator?.apply(from: self)
    }
''', '''    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        safeAreaCoordinator?.apply(from: self)
        LayoutDiagnostics.log(bridge: self, phase: "didAppear-after-apply", force: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        safeAreaCoordinator?.apply(from: self)
        LayoutDiagnostics.log(bridge: self, phase: "layout-after-apply")
    }
''', "ImmersiveBottomSafeAreaViewController callbacks")
text = replace_once(text, '''            guard appliedInsets == nil else { return }
            let bottomInset = navigationController.view.safeAreaInsets.bottom
            guard bottomInset > 0.5 else { return }

            var desired = originalInsets ?? navigationController.additionalSafeAreaInsets
''', '''            guard appliedInsets == nil else { return }
            LayoutDiagnostics.log(bridge: bridge, phase: "safe-area-apply-before", force: true)
            let bottomInset = navigationController.view.safeAreaInsets.bottom
            guard bottomInset > 0.5 else {
                LayoutDiagnostics.log(bridge: bridge, phase: "safe-area-apply-no-bottom-inset", force: true)
                return
            }

            var desired = originalInsets ?? navigationController.additionalSafeAreaInsets
''', "Immersive safe-area before")
text = replace_once(text, '''            navigationController.view.setNeedsLayout()
            navigationController.view.layoutIfNeeded()
        }

        func restore() {
''', '''            navigationController.view.setNeedsLayout()
            navigationController.view.layoutIfNeeded()
            LayoutDiagnostics.log(bridge: bridge, phase: "safe-area-apply-after", force: true)
        }

        func restore() {
''', "Immersive safe-area after")
path.write_text(text)


# Expose real URLSession lane occupancy, not just actor-level slot claims.
path = Path("Sources/Transport/RangeHTTPClient.swift")
text = path.read_text()
text = replace_once(text, '''    @discardableResult
    func resetStreamLane(worker: Int, reason: String) -> Bool {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].resetIfIdle(reason: reason)
    }
''', '''    @discardableResult
    func resetStreamLane(worker: Int, reason: String) -> Bool {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].resetIfIdle(reason: reason)
    }

    func diagnosticLaneSummary(worker: Int) -> String {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].diagnosticSummary()
    }
''', "RangeHTTPClient diagnostic API")
text = replace_once(text, '''    func resetIfIdle(reason: String) -> Bool {
        lock.lock()
        guard !invalidated, states.isEmpty else { lock.unlock(); return false }
        let previous = session
        session = makeSession()
        lock.unlock()
        previous.invalidateAndCancel()
        DiagnosticsLogger.shared.log("TransportV3Health", "lane=\(index) action=reset-idle-session reason=\(reason)")
        return true
    }
''', '''    func resetIfIdle(reason: String) -> Bool {
        lock.lock()
        let blockedSummary = states.map { taskIdentifier, state in
            "task=\(taskIdentifier):\(state.range.lowerBound)-\(state.range.upperBound):recv=\(state.receivedBytes):accepted=\(state.acceptedResponse):pending=\(state.pending.count - state.pendingReadOffset)"
        }.sorted().joined(separator: ",")
        guard !invalidated, states.isEmpty else {
            let invalidatedValue = invalidated
            let stateCount = states.count
            lock.unlock()
            DiagnosticsLogger.shared.log("TransportV3Health", "lane=\(index) action=reset-blocked reason=\(reason) invalidated=\(invalidatedValue) states=\(stateCount) details=[\(blockedSummary)]")
            return false
        }
        let previous = session
        session = makeSession()
        lock.unlock()
        previous.invalidateAndCancel()
        DiagnosticsLogger.shared.log("TransportV3Health", "lane=\(index) action=reset-idle-session reason=\(reason)")
        return true
    }

    func diagnosticSummary() -> String {
        lock.lock()
        let invalidatedValue = invalidated
        let summary = states.map { taskIdentifier, state in
            "task=\(taskIdentifier):\(state.range.lowerBound)-\(state.range.upperBound):recv=\(state.receivedBytes):accepted=\(state.acceptedResponse):pending=\(state.pending.count - state.pendingReadOffset)"
        }.sorted().joined(separator: ",")
        let stateCount = states.count
        lock.unlock()
        return "lane=\(index) invalidated=\(invalidatedValue) states=\(stateCount) [\(summary)]"
    }
''', "PersistentRangeStreamLane reset diagnostics")
text = replace_once(text, '''        lock.lock()
        guard let state = states.removeValue(forKey: task.taskIdentifier) else { lock.unlock(); return }
        let terminal = state.terminalError
''', '''        lock.lock()
        guard let state = states.removeValue(forKey: task.taskIdentifier) else {
            lock.unlock()
            DiagnosticsLogger.shared.log("TransportV3Race", "lane=\(index) task=\(task.taskIdentifier) completion-without-state error=\(error?.localizedDescription ?? "none")")
            return
        }
        let terminal = state.terminalError
''', "PersistentRangeStreamLane completion race")
text = replace_once(text, '''    private func cancel(taskIdentifier: Int, task: URLSessionTask?) {
        lock.lock()
        guard let state = states.removeValue(forKey: taskIdentifier) else { lock.unlock(); return }
        lock.unlock()
        task?.cancel()
        state.continuation.finish(throwing: MediaTransportError.cancelled)
        DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) task=\(taskIdentifier) cancelled taskOnly=true sessionKept=true")
    }
''', '''    private func cancel(taskIdentifier: Int, task: URLSessionTask?) {
        lock.lock()
        guard let state = states.removeValue(forKey: taskIdentifier) else {
            lock.unlock()
            DiagnosticsLogger.shared.log("TransportV3Race", "lane=\(index) task=\(taskIdentifier) cancel-without-state")
            return
        }
        let received = state.receivedBytes
        let accepted = state.acceptedResponse
        lock.unlock()
        task?.cancel()
        state.continuation.finish(throwing: MediaTransportError.cancelled)
        DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) task=\(taskIdentifier) cancelled taskOnly=true sessionKept=true received=\(received) accepted=\(accepted)")
    }
''', "PersistentRangeStreamLane cancel race")
path.write_text(text)


# Trace blocked reads plus the exact scheduler gates when no foreground lane is available.
path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()
text = replace_once(text, '''    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var lastMetricsLogAt = Date.distantPast
''', '''    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var lastMetricsLogAt = Date.distantPast
    private var blockedReadSerial: UInt64 = 0
    private var lastDeadlockCandidateAt = Date.distantPast
''', "Unified scheduler diagnostic state")
text = replace_once(text, '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }

        if available == 0 {
''', '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }
        let blockedReadID: UInt64?
        let blockedReadStartedAt: Date
        if available == 0 {
            blockedReadSerial &+= 1
            blockedReadID = blockedReadSerial
            blockedReadStartedAt = Date()
            DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadSerial) begin offset=\(offset) length=\(requested) anchor=\(playbackAnchor)")
        } else {
            blockedReadID = nil
            blockedReadStartedAt = Date.distantPast
        }

        if available == 0 {
''', "Unified blocked read begin")
text = replace_once(text, '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            refreshMetrics(resource: resolved)
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
''', '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            if let blockedReadID = blockedReadID { DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadID) served-first bytes=\(data.count) ms=\(Int(Date().timeIntervalSince(blockedReadStartedAt) * 1000))") }
            refreshMetrics(resource: resolved)
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else {
                if let blockedReadID = blockedReadID { DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadID) store-error=\(error.localizedDescription) ms=\(Int(Date().timeIntervalSince(blockedReadStartedAt) * 1000))") }
                throw error
            }
            if let blockedReadID = blockedReadID { DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadID) first-timeout ms=\(Int(Date().timeIntervalSince(blockedReadStartedAt) * 1000))") }
''', "Unified blocked read first result")
text = replace_once(text, '''            installUrgent(range: offset..<demandEnd, metadata: metadata, reason: "read-timeout")
            scheduleSlots(reason: "read-timeout")
            return try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)
        }
    }
''', '''            installUrgent(range: offset..<demandEnd, metadata: metadata, reason: "read-timeout")
            scheduleSlots(reason: "read-timeout")
            do {
                let retryData = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)
                if let blockedReadID = blockedReadID { DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadID) retry-served bytes=\(retryData.count) ms=\(Int(Date().timeIntervalSince(blockedReadStartedAt) * 1000))") }
                return retryData
            } catch {
                if let blockedReadID = blockedReadID { DiagnosticsLogger.shared.log("UnifiedReadWait", "id=\(blockedReadID) retry-error=\(error.localizedDescription) ms=\(Int(Date().timeIntervalSince(blockedReadStartedAt) * 1000))") }
                throw error
            }
        }
    }
''', "Unified blocked read retry")
text = replace_once(text, '''    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() {
            if slotTasks.isEmpty, Date() > pendingUserSeekUntil || pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
                scheduleSlots(reason: "metrics-idle-repair")
            }
            refreshMetrics(resource: resolved)
        }
        return metricsValue
    }
''', '''    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() {
            if slotTasks.isEmpty {
                let now = Date()
                let urgent = pendingPlaybackUrgentRange.map { "\($0.lowerBound)-\($0.upperBound)" } ?? "none"
                let metadata = pendingMetadataRange.map { "\($0.lowerBound)-\($0.upperBound)" } ?? "none"
                let blocking = lastBlockingPlaybackDemand.map { "\($0.lowerBound)-\($0.upperBound)" } ?? "none"
                let blockingAgeMs = lastBlockingPlaybackDemandAt == .distantPast ? -1 : Int(now.timeIntervalSince(lastBlockingPlaybackDemandAt) * 1000)
                let lane0 = client.diagnosticLaneSummary(worker: 0)
                let lane1 = client.diagnosticLaneSummary(worker: 1)
                DiagnosticsLogger.shared.log("UnifiedSchedulerTrace", "reason=metrics-idle anchor=\(playbackAnchor) urgent=\(urgent) metadata=\(metadata) blocking=\(blocking) blockingAgeMs=\(blockingAgeMs) seekPending=\(now <= pendingUserSeekUntil) reset0=\(liveLaneResetPending.contains(0)) reset1=\(liveLaneResetPending.contains(1)) refresh0=\(liveLaneSourceRefreshPending.contains(0)) refresh1=\(liveLaneSourceRefreshPending.contains(1)) rotate0=\(liveLaneRotationRequested.contains(0)) rotate1=\(liveLaneRotationRequested.contains(1)) hedge0=\(urgentHedgeRequested.contains(0)) hedge1=\(urgentHedgeRequested.contains(1)) raceReset0=\(urgentRaceResetPending.contains(0)) raceReset1=\(urgentRaceResetPending.contains(1)) lane0={\(lane0)} lane1={\(lane1)}")
                let freshBlocking = lastBlockingPlaybackDemand != nil && blockingAgeMs >= 0 && blockingAgeMs <= Int(stallBlockingDemandFreshSeconds * 1000)
                let pendingForeground = pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil
                if (freshBlocking || pendingForeground), now.timeIntervalSince(lastDeadlockCandidateAt) >= 0.75 {
                    lastDeadlockCandidateAt = now
                    DiagnosticsLogger.shared.log("UnifiedDeadlockCandidate", "freshBlocking=\(freshBlocking) pendingForeground=\(pendingForeground) urgent=\(urgent) metadata=\(metadata) blocking=\(blocking) lane0={\(lane0)} lane1={\(lane1)}")
                }
            }
            if slotTasks.isEmpty, Date() > pendingUserSeekUntil || pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
                scheduleSlots(reason: "metrics-idle-repair")
            }
            refreshMetrics(resource: resolved)
        }
        return metricsValue
    }
''', "Unified metrics scheduler trace")
text = replace_once(text, '''    private func firstIdleForegroundSlot() -> Int? {
        let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
        let order = [serviceSlot, preferredBulkSlot]
        for slot in order {
            guard slotTasks[slot] == nil, !liveLaneResetPending.contains(slot), !liveLaneSourceRefreshPending.contains(slot) else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            return slot
        }
        return nil
    }
''', '''    private func firstIdleForegroundSlot() -> Int? {
        let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
        let order = [serviceSlot, preferredBulkSlot]
        for slot in order {
            guard slotTasks[slot] == nil, !liveLaneResetPending.contains(slot), !liveLaneSourceRefreshPending.contains(slot) else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            return slot
        }
        DiagnosticsLogger.shared.log("UnifiedSchedulerGate", "no-foreground-slot preferredBulk=\(preferredBulkSlot) slot0Task=\(slotTasks[0] != nil) slot1Task=\(slotTasks[1] != nil) reset0=\(liveLaneResetPending.contains(0)) reset1=\(liveLaneResetPending.contains(1)) refresh0=\(liveLaneSourceRefreshPending.contains(0)) refresh1=\(liveLaneSourceRefreshPending.contains(1)) secondaryCooldownMs=\(max(0, Int(secondaryCooldownUntil.timeIntervalSince(Date()) * 1000))) lane0={\(client.diagnosticLaneSummary(worker: 0))} lane1={\(client.diagnosticLaneSummary(worker: 1))}")
        return nil
    }
''', "Unified foreground scheduler gate")
path.write_text(text)


# Correlate PlayerController's watchdog with transport state.
path = Path("Sources/Player/PlayerController.swift")
text = path.read_text()
text = replace_once(text, '''    private func evaluatePlaybackStall() {
        guard Date() >= stallWatchdogSuppressedUntil,
''', '''    private func evaluatePlaybackStall() {
        if let pending = pendingSeekTarget, snapshot.isBuffering || snapshot.waitingReason != nil {
            DiagnosticsLogger.shared.log("StallTrace", "gate=pending-seek target=\(pending) engine=\(engineKind.title) position=\(snapshot.position) buffering=\(snapshot.isBuffering) waiting=\(snapshot.waitingReason ?? "none")")
        }
        guard Date() >= stallWatchdogSuppressedUntil,
''', "PlayerController pending seek trace")
text = replace_once(text, '''        DiagnosticsLogger.shared.log(
            "Stall",
            "engine=\(engineKind.title) recovery=\(stallRecoveryCount) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) duration=\(effectiveDuration) waiting=\(snapshot.waitingReason ?? "none")"
        )

        let action = orchestrator.actionForStall(
''', '''        DiagnosticsLogger.shared.log(
            "Stall",
            "engine=\(engineKind.title) recovery=\(stallRecoveryCount) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) duration=\(effectiveDuration) waiting=\(snapshot.waitingReason ?? "none")"
        )
        let traceMetrics = lastTransportMetrics
        DiagnosticsLogger.shared.log(
            "StallTrace",
            "gate=recovery engine=\(engineKind.title) playing=\(snapshot.isPlaying) buffering=\(snapshot.isBuffering) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) waiting=\(snapshot.waitingReason ?? "none") transportActive=\(traceMetrics?.activeRequestCount ?? -1) networkBps=\(Int(traceMetrics?.currentDownloadBytesPerSecond ?? -1)) anchor=\(traceMetrics?.schedulerAnchorByte ?? -1) frontier=\(traceMetrics?.schedulerFrontierByte ?? -1) holes=\(traceMetrics?.cacheHoleCount ?? -1) cache=\(traceMetrics?.cacheBytes ?? -1)"
        )

        let action = orchestrator.actionForStall(
''', "PlayerController recovery trace")
path.write_text(text)

print("Runtime diagnostics instrumentation applied.")
