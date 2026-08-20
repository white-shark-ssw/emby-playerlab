from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, got {count}\n--- needle ---\n{old}")
    p.write_text(text.replace(old, new, 1))


# Diagnostic identity: monotonic from 0.13.33 Build100.
replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.30"\n    CURRENT_PROJECT_VERSION: "97"', 'MARKETING_VERSION: "0.13.34"\n    CURRENT_PROJECT_VERSION: "101"')
replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.30"\n        CURRENT_PROJECT_VERSION: "97"', 'MARKETING_VERSION: "0.13.34"\n        CURRENT_PROJECT_VERSION: "101"')
replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.13.30"', 'static let sourceVersion = "0.13.34"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.30"', '?? "0.13.34"')

# TransportDataSession: expose a diagnostic-only complete local file acquisition point.
replace_once(
    "Sources/Transport/TransportDataSession.swift",
    "    func confirmInitialResumePlayback() async\n    func metrics() async -> TransportMetricsSnapshot\n",
    "    func confirmInitialResumePlayback() async\n    func acquireCompleteLocalFileURL() async -> URL?\n    func metrics() async -> TransportMetricsSnapshot\n",
)
replace_once(
    "Sources/Transport/TransportDataSession.swift",
    "    func confirmInitialResumePlayback() async {}\n}\n",
    "    func confirmInitialResumePlayback() async {}\n    func acquireCompleteLocalFileURL() async -> URL? { nil }\n}\n",
)

# Sparse store: only expose the physical cache file after every byte is present.
replace_once(
    "Sources/Transport/DownloadFirstSparseStore.swift",
    "    func close(removeFiles: Bool) {\n",
    "    func completeFileURLIfAvailable() -> URL? {\n        condition.lock()\n        defer { condition.unlock() }\n        guard !closed, fileDescriptor >= 0, contentLength > 0, rangeSet.contains(0..<contentLength) else { return nil }\n        return mediaURL\n    }\n\n    func close(removeFiles: Bool) {\n",
)

# Unified transport: when the sparse file is truly complete, pin it and stop scheduling/eviction.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "    private var preferredBulkSlot = 0\n    private var stopped = false\n",
    "    private var preferredBulkSlot = 0\n    private var localFileConsumerPinned = false\n    private var stopped = false\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "    func metrics() async -> TransportMetricsSnapshot {\n",
    "    func acquireCompleteLocalFileURL() async -> URL? {\n        guard !stopped, let resolved = try? await resolve(), let store else { return nil }\n        let complete = resolved.contentLength > 0 && store.uniqueBytes >= resolved.contentLength && store.contains(0..<resolved.contentLength)\n        guard complete, let url = store.completeFileURLIfAvailable() else {\n            DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=cache-file-acquire ready=false cached=\\(store.uniqueBytes) total=\\(resolved.contentLength) action=keep-unified-localhost\")\n            return nil\n        }\n        localFileConsumerPinned = true\n        cacheRefillActive = false\n        cacheEmergencyActive = false\n        pendingPlaybackUrgentRange = nil\n        pendingMetadataRange = nil\n        for slot in [0, 1] where slotTasks[slot] != nil { cancelSlot(slot, reason: \"mdk-complete-cache-file-ab\") }\n        refreshMetrics(resource: resolved)\n        DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=cache-file-acquire ready=true cached=\\(store.uniqueBytes) total=\\(resolved.contentLength) holes=0 pinned=true file=\\(url.lastPathComponent)\")\n        return url\n    }\n\n    func metrics() async -> TransportMetricsSnapshot {\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "    private func scheduleSlots(reason: String) {\n        guard !stopped, let resource, let store else { return }\n        if startupResolveOnlyHold {\n",
    "    private func scheduleSlots(reason: String) {\n        guard !stopped, let resource, let store else { return }\n        if localFileConsumerPinned {\n            refreshMetrics(resource: resource)\n            return\n        }\n        if startupResolveOnlyHold {\n",
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    "        guard configuration.ktvContinuousPreloadEnabled, configuration.usesDiskCache, window > 0, let store else { return }\n",
    "        guard !localFileConsumerPinned, configuration.ktvContinuousPreloadEnabled, configuration.usesDiskCache, window > 0, let store else { return }\n",
)

# MDK adapter: if confirmed premature EOF occurs while the entire source is already cached,
# quarantine that HTTP-backed MDK instance and re-prepare the SAME adapter/renderer pipeline from
# the SAME physical cache file via file://. Only the input protocol changes.
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "    private var abnormalMediaRecoveryLevel = 0\n    private var nativeQuarantineActive = false\n",
    "    private var abnormalMediaRecoveryLevel = 0\n    private var nativeQuarantineActive = false\n    private var completeCacheABProbePending = false\n    private var completeCacheABActive = false\n    private var completeCacheABStartPosition: Double?\n    private var completeCacheABVerdictLogged = false\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        let message = \"MDK native isolation render timeout\"\n        DiagnosticsLogger.shared.playback(\"MDKNativeIsolation\", \"operation=render timeoutMs=\\(Int(age * 1_000)) generation=\\(currentGeneration) watchdogQueue=independent renderBridge=offscreen-texture action=quarantine-engine-switch-mpv\")\n",
    "        let message = \"MDK native isolation render timeout\"\n        if completeCacheABActive { DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"verdict=file-input-failed reason=render-timeout position=\\(String(format: \"%.3f\", lastNativePosition)) start=\\(String(format: \"%.3f\", completeCacheABStartPosition ?? -1))\") }\n        DiagnosticsLogger.shared.playback(\"MDKNativeIsolation\", \"operation=render timeoutMs=\\(Int(age * 1_000)) generation=\\(currentGeneration) watchdogQueue=independent renderBridge=offscreen-texture action=quarantine-engine-switch-mpv\")\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        self.preferredForwardBuffer = preferredForwardBuffer\n        lastURL = url\n        lastHeaders = headers\n",
    "        self.preferredForwardBuffer = preferredForwardBuffer\n        lastURL = url\n        lastHeaders = headers\n        if !url.isFileURL {\n            completeCacheABProbePending = false\n            completeCacheABActive = false\n            completeCacheABStartPosition = nil\n            completeCacheABVerdictLogged = false\n        }\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        guard let sharedTransportSession else {\n            startMDKPlayer(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: \"direct-http302\")\n            DiagnosticsLogger.shared.playback(\"MDKTransport\", \"mode=direct-http302 unifiedTransportAvailable=false nasMediaProxy=false\")\n            return\n        }\n",
    "        if url.isFileURL {\n            let mode = completeCacheABActive ? \"complete-cache-file-ab\" : \"direct-file\"\n            DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=prepare-file mode=\\(mode) generation=\\(currentGeneration) start=\\(String(format: \"%.3f\", startPosition)) sameAdapter=true sameRenderer=true sharedTransportRetained=\\(sharedTransportSession != nil)\")\n            startMDKPlayer(url: url, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: mode)\n            return\n        }\n\n        guard let sharedTransportSession else {\n            startMDKPlayer(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: \"direct-http302\")\n            DiagnosticsLogger.shared.playback(\"MDKTransport\", \"mode=direct-http302 unifiedTransportAvailable=false nasMediaProxy=false\")\n            return\n        }\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        if prematureEnd, shouldPlay {\n            let message = \"MDK session unsafe premature EOF\"\n            DiagnosticsLogger.shared.playback(\"MDKCompat\", \"position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) action=quarantine-session-switch-mpv sameProcessMDKRebuild=false unifiedTransport=\\(sharedTransportSession != nil)\")\n            quarantineCurrentGeneration(reason: \"confirmed-premature-eof\", position: position, failedGeneration: generation, message: message)\n            return\n        }\n",
    "        if prematureEnd, shouldPlay {\n            if completeCacheABActive {\n                DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"verdict=file-input-failed reason=confirmed-premature-eof position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) start=\\(String(format: \"%.3f\", completeCacheABStartPosition ?? -1))\")\n                let message = \"MDK complete-cache file input also failed\"\n                quarantineCurrentGeneration(reason: \"complete-cache-file-premature-eof\", position: position, failedGeneration: generation, message: message)\n                return\n            }\n            if sharedTransportSession != nil {\n                attemptCompleteCacheFileAB(position: position, duration: duration, status: status)\n                return\n            }\n            let message = \"MDK session unsafe premature EOF\"\n            DiagnosticsLogger.shared.playback(\"MDKCompat\", \"position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) action=quarantine-session-switch-mpv sameProcessMDKRebuild=false unifiedTransport=\\(sharedTransportSession != nil)\")\n            quarantineCurrentGeneration(reason: \"confirmed-premature-eof\", position: position, failedGeneration: generation, message: message)\n            return\n        }\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "    func transportMetrics() async -> TransportMetricsSnapshot? {\n",
    "    private func attemptCompleteCacheFileAB(position: Double, duration: Double, status: Int32) {\n        guard !completeCacheABActive, !completeCacheABProbePending, let session = sharedTransportSession else { return }\n        completeCacheABProbePending = true\n        let expectedGeneration = generation\n        DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=probe reason=confirmed-premature-eof position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) inputA=unified-localhost inputB=file sameBytesRequired=true\")\n        Task { [weak self] in\n            let localURL = await session.acquireCompleteLocalFileURL()\n            DispatchQueue.main.async { [weak self] in\n                guard let self, self.generation == expectedGeneration else { return }\n                self.completeCacheABProbePending = false\n                guard let localURL else {\n                    DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=probe ready=false position=\\(String(format: \"%.3f\", position)) action=fallback-mpv\")\n                    self.quarantineCurrentGeneration(reason: \"premature-eof-cache-incomplete\", position: position, failedGeneration: expectedGeneration, message: \"MDK session unsafe premature EOF\")\n                    return\n                }\n                self.completeCacheABActive = true\n                self.completeCacheABStartPosition = position\n                self.completeCacheABVerdictLogged = false\n                self.nativeQuarantineActive = true\n                let restart = max(0, position - 0.250)\n                DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"phase=switch inputA=unified-localhost inputB=file cachedComplete=true generation=\\(expectedGeneration) restart=\\(String(format: \"%.3f\", restart)) sameAdapter=true sameRendererPipeline=true decoderOrder=unchanged action=quarantine-http-player-reprepare-file\")\n                self.prepare(url: localURL, headers: [:], preferredForwardBuffer: self.preferredForwardBuffer, startPosition: restart)\n            }\n        }\n    }\n\n    func transportMetrics() async -> TransportMetricsSnapshot? {\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        lastNativePosition = position\n        lastNativeDuration = duration\n",
    "        lastNativePosition = position\n        lastNativeDuration = duration\n        if completeCacheABActive, !completeCacheABVerdictLogged, let start = completeCacheABStartPosition, !ended, position >= start + 10 {\n            completeCacheABVerdictLogged = true\n            DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"verdict=file-input-progressed position=\\(String(format: \"%.3f\", position)) start=\\(String(format: \"%.3f\", start)) advanced=\\(String(format: \"%.3f\", position - start)) rawStatus=0x\\(String(status, radix: 16)) action=http-vs-file-difference-confirmed-if-online-failed-at-start\")\n        }\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        prematureEOFRecoveryActive = false\n        abnormalMediaRecoveryLevel = 0\n        stopPlayerOnly()\n",
    "        prematureEOFRecoveryActive = false\n        abnormalMediaRecoveryLevel = 0\n        completeCacheABProbePending = false\n        completeCacheABActive = false\n        completeCacheABStartPosition = nil\n        completeCacheABVerdictLogged = false\n        stopPlayerOnly()\n",
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "        DiagnosticsLogger.shared.playback(\"MDKPrepareGuard\", \"generation=\\(failedGeneration) phase=quarantine reason=\\(reason) position=\\(String(format: \"%.3f\", position)) action=switch-mpv skipNativeStop=true\")\n",
    "        if completeCacheABActive { DiagnosticsLogger.shared.playback(\"MDKInputAB\", \"verdict=file-input-failed reason=\\(reason) position=\\(String(format: \"%.3f\", position)) start=\\(String(format: \"%.3f\", completeCacheABStartPosition ?? -1)) action=switch-mpv\") }\n        DiagnosticsLogger.shared.playback(\"MDKPrepareGuard\", \"generation=\\(failedGeneration) phase=quarantine reason=\\(reason) position=\\(String(format: \"%.3f\", position)) action=switch-mpv skipNativeStop=true\")\n",
)

print("Injected MDK complete-cache localhost-vs-file A/B diagnostic experiment")
