from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"{label}: anchor not found")
    return text.replace(old, new, 1)


controller = Path("Sources/Player/PlayerController.swift")
text = controller.read_text()
text = replace_once(
    text,
    "    private var preferredForwardBuffer: Double = 90\n    private var initialPlaybackTask: Task<Void, Never>?\n",
    "    private var preferredForwardBuffer: Double = 90\n    private var startupResumeTask: Task<Double, Never>?\n    private var startupTransportPrewarmTask: Task<Void, Never>?\n    private var initialPlaybackTask: Task<Void, Never>?\n",
    "PlayerController startup task properties",
)
old_start = '''    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        started = true
        self.preferredForwardBuffer = preferredForwardBuffer > 0 ? preferredForwardBuffer : 90
        configureAudioSession()
        userWantsPlayback = true
        initialPlaybackTask?.cancel()
        initialPlaybackTask = Task { [weak self] in
            guard let self else { return }
            let startPosition = await self.resolveInitialPlaybackPosition()
            guard !Task.isCancelled, self.started else { return }
            if startPosition > 0.5, let session = self.transportContext?.session {
                await session.prepareInitialPlayback(position: startPosition, duration: self.source.mediaSource.durationSeconds ?? 0)
                guard !Task.isCancelled, self.started else { return }
            }
            self.initialPlaybackTask = nil
            self.startEngine(at: startPosition)
        }
    }
'''
new_start = '''    func prewarmStartup() {
        guard !started else { return }
        if startupResumeTask == nil {
            startupResumeTask = Task { [weak self] in
                guard let self else { return 0 }
                let began = CACurrentMediaTime()
                DiagnosticsLogger.shared.playback("StartupFastPath", "resume lookup begin item=\\(self.source.itemId)")
                let position = await self.resolveInitialPlaybackPosition()
                DiagnosticsLogger.shared.playback("StartupFastPath", "resume lookup ready item=\\(self.source.itemId) position=\\(String(format: \"%.3f\", position)) ms=\\(Int((CACurrentMediaTime() - began) * 1000))")
                return position
            }
        }
        if startupTransportPrewarmTask == nil, let session = transportContext?.session {
            startupTransportPrewarmTask = Task { [weak self] in
                guard let self else { return }
                let began = CACurrentMediaTime()
                DiagnosticsLogger.shared.playback("StartupFastPath", "transport resolve begin item=\\(self.source.itemId)")
                let ready = await session.prewarmStartupResolve()
                guard !Task.isCancelled else { return }
                DiagnosticsLogger.shared.playback("StartupFastPath", "transport resolve ready item=\\(self.source.itemId) success=\\(ready) ms=\\(Int((CACurrentMediaTime() - began) * 1000))")
            }
        }
    }

    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        prewarmStartup()
        started = true
        self.preferredForwardBuffer = preferredForwardBuffer > 0 ? preferredForwardBuffer : 90
        configureAudioSession()
        userWantsPlayback = true
        initialPlaybackTask?.cancel()
        initialPlaybackTask = Task { [weak self] in
            guard let self else { return }
            let startPosition: Double
            if let resumeTask = self.startupResumeTask { startPosition = await resumeTask.value }
            else { startPosition = await self.resolveInitialPlaybackPosition() }
            guard !Task.isCancelled, self.started else { return }
            let duration = self.source.mediaSource.durationSeconds ?? 0
            if let session = self.transportContext?.session {
                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)
                guard !Task.isCancelled, self.started else { return }
            }
            self.initialPlaybackTask = nil
            DiagnosticsLogger.shared.playback("StartupFastPath", "engine activation item=\\(self.source.itemId) position=\\(String(format: \"%.3f\", startPosition)) transportResolveStarted=\\(self.startupTransportPrewarmTask != nil)")
            self.startEngine(at: startPosition)
        }
    }
'''
text = replace_once(text, old_start, new_start, "PlayerController start/prewarm block")
text = replace_once(
    text,
    "        initialPlaybackTask?.cancel()\n        initialPlaybackTask = nil\n",
    "        startupResumeTask?.cancel()\n        startupResumeTask = nil\n        startupTransportPrewarmTask?.cancel()\n        startupTransportPrewarmTask = nil\n        initialPlaybackTask?.cancel()\n        initialPlaybackTask = nil\n",
    "PlayerController stop startup task cleanup",
)
controller.write_text(text)


screen = Path("Sources/UI/PlayerScreen.swift")
text = screen.read_text()
text = replace_once(
    text,
    "            displayRefreshMonitor.start()\n            AppOrientationCoordinator.shared.beginPlayerPresentation(source: controller.source)\n",
    "            displayRefreshMonitor.start()\n            controller.prewarmStartup()\n            AppOrientationCoordinator.shared.beginPlayerPresentation(source: controller.source)\n",
    "PlayerScreen prewarm before orientation",
)
screen.write_text(text)


transport = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = transport.read_text()
text = replace_once(
    text,
    "    private var awaitingInitialResumeDemand = false\n    private var initialResumeAnchorByte: Int64?\n",
    "    private var awaitingInitialResumeDemand = false\n    private var startupResolveOnlyHold = false\n    private var startupPrewarmReleased = false\n    private var initialResumeAnchorByte: Int64?\n",
    "UnifiedTransport startup hold properties",
)
text = replace_once(
    text,
    "    func prepareInitialPlayback(position: Double, duration: Double) {\n",
    '''    func prewarmStartupResolve() async -> Bool {
        guard !stopped else { return false }
        if !startupPrewarmReleased { startupResolveOnlyHold = true }
        do {
            _ = try await resolve()
            return true
        } catch {
            DiagnosticsLogger.shared.playback("StartupFastPath", "transport resolve failed error=\\(error.localizedDescription)")
            return false
        }
    }

    func releaseStartupPrewarm(initialPosition: Double, duration: Double) {
        guard !stopped else { return }
        startupPrewarmReleased = true
        if initialPosition > 0.5 { prepareInitialPlayback(position: initialPosition, duration: duration) }
        let wasHeld = startupResolveOnlyHold
        startupResolveOnlyHold = false
        DiagnosticsLogger.shared.playback("StartupFastPath", "transport scheduler release resume=\\(initialPosition > 0.5) wasHeld=\\(wasHeld) resolved=\\(resource != nil)")
        if resource != nil { scheduleSlots(reason: "startup-fast-path-release") }
    }

    func prepareInitialPlayback(position: Double, duration: Double) {
''',
    "UnifiedTransport startup prewarm methods",
)
text = replace_once(
    text,
    "    private func scheduleSlots(reason: String) {\n        guard !stopped, let resource, let store else { return }\n\n",
    '''    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }
        if startupResolveOnlyHold {
            refreshMetrics(resource: resource)
            return
        }

''',
    "UnifiedTransport scheduler startup hold",
)
old_metadata = '''        if metadata {
            if let existing = pendingMetadataRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingMetadataRange = candidate
        } else {
'''
new_metadata = '''        if metadata {
            if let active = slotClaims.values.first(where: { ($0.role == .metadata || $0.role == .startupMetadata) && $0.range.contains(lower) }) {
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "metadata reuse active range=\\(active.range.lowerBound)-\\(active.range.upperBound) request=\\(candidate.lowerBound)-\\(candidate.upperBound) reason=\\(reason) action=no-duplicate-lane")
                return
            }
            if let existing = pendingMetadataRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingMetadataRange = candidate
        } else {
'''
text = replace_once(text, old_metadata, new_metadata, "UnifiedTransport active metadata dedupe")
transport.write_text(text)


project = Path("project.mdklab.yml")
text = project.read_text()
text = text.replace("# OnePlayer 0.13.12 renders engine-live and session-verified media-time buffer ranges on one truthful timeline.", "# OnePlayer 0.13.14 overlaps startup orientation with resume lookup and transport resolve while preserving the frozen transport-cache timeline.")
text = text.replace('MARKETING_VERSION: "0.13.13"', 'MARKETING_VERSION: "0.13.14"')
text = text.replace('CURRENT_PROJECT_VERSION: "80"', 'CURRENT_PROJECT_VERSION: "81"')
project.write_text(text)

print("OnePlayer 0.13.14 startup fast path materialized")
