from pathlib import Path

ENGINE = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
PROJECT = Path("project.mdklab.yml")
IDENTITY = Path("Sources/Core/AppIdentity.swift")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)


def replace_method(text: str, start_marker: str, end_marker: str, replacement: str, label: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"missing method start: {label}")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"missing method end: {label}")
    return text[:start] + replacement.rstrip() + "\n\n" + text[end:]


engine = ENGINE.read_text()

engine = replace_once(
    engine,
    '''    private var prematureEOFRecoveryActive = false
    private var abnormalMediaRecoveryLevel = 0
    private var nativeQuarantineActive = false
''',
    '''    private var prematureEOFRecoveryActive = false
    private var abnormalMediaRecoveryLevel = 0
    private var nativeQuarantineActive = false
    private let prepareWatchdogSeconds: TimeInterval = 3.0
    private let firstFrameWatchdogSeconds: TimeInterval = 4.0
    private let endConfirmationSeconds: TimeInterval = 1.0
    private var preparingGeneration: Int?
    private var preparedGeneration = -1
    private var endCandidateSince: TimeInterval?
    private var endCandidatePosition: Double = 0
    private var endCandidateFrameSerial: UInt64 = 0
''',
    "prepare guard properties",
)

surface_method = r'''    private func surfaceDidChange(_ size: CGSize) {
        DiagnosticsLogger.shared.playback("MDKSurface", "size=\(Int(size.width))x\(Int(size.height)) backend=CAMetalLayer mainNativeCall=false")
        let currentGeneration = generation
        guard preparedGeneration == currentGeneration, let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=surface-deferred prepared=\(preparedGeneration == currentGeneration)")
            return
        }
        let renderer = self.renderer
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            renderer.setSurfaceSize(size, player: player)
        }
    }'''
engine = replace_method(
    engine,
    "    private func surfaceDidChange(_ size: CGSize) {",
    "    private func requestPlayerState(",
    surface_method,
    "surfaceDidChange",
)

state_method = r'''    private func requestPlayerState(playing: Bool, expectedPlayer: swift_mdk.Player? = nil, generation expectedGeneration: Int? = nil) {
        guard let player = expectedPlayer ?? currentPlayerReference() else { return }
        let currentGeneration = expectedGeneration ?? generation
        guard preparedGeneration == currentGeneration else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=state-deferred requested=\(playing ? \"playing\" : \"paused\")")
            return
        }
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            player.state = playing ? .Playing : .Paused
        }
    }'''
engine = replace_method(
    engine,
    "    private func requestPlayerState(playing: Bool",
    "    private func startRenderWatchdog()",
    state_method,
    "requestPlayerState",
)

prepare_method = r'''    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopPlayerOnly()
        generation &+= 1
        let currentGeneration = generation
        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\(currentGeneration)", qos: .userInitiated)
        guard let newRenderer = PlayerMetalLayerRenderer(layer: view.metalLayer) else { return }
        renderer = newRenderer
        configureRenderer(newRenderer, generation: currentGeneration)
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        renderedFrameSerial = 0
        lastRenderedTimestamp = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        prematureEOFRecoveryActive = false
        hasRenderedValidFrame = false
        lastRenderedFrameAt = CACurrentMediaTime()
        lastNativeBuffering = false
        lastNativePosition = max(0, startPosition)
        lastNativeDuration = source.mediaSource.durationSeconds ?? 0
        lastNativeStatus = 0
        lastNativeBufferMs = 0
        lastNativeIsPlaying = false
        lastNativeEnded = false
        preparingGeneration = currentGeneration
        preparedGeneration = -1
        endCandidateSince = nil
        endCandidatePosition = max(0, startPosition)
        endCandidateFrameSerial = 0
        installMDKLoggingIfNeeded()
        configureMDKIOIfNeeded()
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=probation-start start=\(String(format: \"%.3f\", startPosition)) rendererBound=false statePoll=false")

        guard let sharedTransportSession else {
            startMDKPlayer(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "direct-http302")
            DiagnosticsLogger.shared.playback("MDKTransport", "mode=direct-http302 unifiedTransportAvailable=false nasMediaProxy=false")
            return
        }

        let server = TransportHTTPServer(session: sharedTransportSession, fileExtension: mediaFileExtension, stopSessionOnStop: false)
        transportHTTPServer = server
        DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost starting=true host=127.0.0.1 unifiedTransportActive=true nasMediaProxy=false")
        transportPrepareTask = Task { @MainActor [weak self, weak server] in
            guard let self, let server else { return }
            do {
                let localURL = try await server.start()
                guard !Task.isCancelled, currentGeneration == self.generation, self.transportHTTPServer === server else { server.stop(); return }
                self.transportPrepareTask = nil
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=true host=127.0.0.1 port=\(localURL.port ?? 0) unifiedTransportActive=true nasMediaProxy=false")
                self.startMDKPlayer(url: localURL, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "unified-localhost")
            } catch {
                guard !Task.isCancelled, currentGeneration == self.generation else { return }
                self.transportPrepareTask = nil
                if self.transportHTTPServer === server { self.transportHTTPServer = nil }
                server.stop()
                let message = "MDK UnifiedTransport 本地桥启动失败：\(error.localizedDescription)"
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=false error=\(error.localizedDescription) directFallback=false nasMediaProxy=false")
                self.onSnapshot?(PlayerSnapshot(position: max(0, startPosition), duration: self.source.mediaSource.durationSeconds ?? 0, isPlaying: false, isBuffering: false, errorMessage: message))
            }
        }
    }'''
engine = replace_method(engine, "    func prepare(url: URL", "    func play() {", prepare_method, "prepare")

engine = replace_once(
    engine,
    '''        guard let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\\(String(format: \"%.2f\", clamped)) state=pending-player")
            return
        }
        let currentPlayerGeneration = generation
''',
    '''        guard let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\\(String(format: \"%.2f\", clamped)) state=pending-player")
            return
        }
        let currentPlayerGeneration = generation
        guard preparedGeneration == currentPlayerGeneration else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentPlayerGeneration) phase=rate-deferred requested=\\(String(format: \"%.2f\", clamped))")
            return
        }
''',
    "rate probation gate",
)

engine = replace_once(
    engine,
    '''    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player = currentPlayerReference() else { return }
        let target = max(0, targetSeconds)
''',
    '''    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player = currentPlayerReference() else { return }
        let target = max(0, targetSeconds)
        guard preparedGeneration == generation else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(generation) phase=seek-deferred target=\\(String(format: \"%.3f\", target))")
            return
        }
''',
    "seek probation gate",
)

helpers_and_start = r'''    private func quarantineCurrentGeneration(reason: String, position: Double, failedGeneration: Int, message: String) {
        guard failedGeneration == generation, let oldPlayer = currentPlayerReference() else { return }
        let oldRenderer = renderer
        preparingGeneration = nil
        preparedGeneration = -1
        endCandidateSince = nil
        stateTimer?.cancel()
        stateTimer = nil
        renderWatchdogTimer?.invalidate()
        renderWatchdogTimer = nil
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        let server = transportHTTPServer
        transportHTTPServer = nil
        server?.stop()
        seekGeneration &+= 1
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        hasRenderedValidFrame = false
        oldRenderer.detach()
        guard takePlayer() === oldPlayer else { return }
        generation &+= 1
        rateGeneration &+= 1
        nativeQuarantineActive = false
        MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(failedGeneration) phase=quarantine reason=\(reason) position=\(String(format: \"%.3f\", position)) action=switch-mpv skipNativeStop=true")
        onSnapshot?(PlayerSnapshot(position: max(0, position), duration: max(lastNativeDuration, source.mediaSource.durationSeconds ?? 0), isPlaying: false, isBuffering: false, errorMessage: message))
    }

    private func activatePreparedPlayer(_ player: swift_mdk.Player, renderer: PlayerMetalLayerRenderer, surfaceSize: CGSize, generation currentGeneration: Int, preparedAtMs: Int64, requestedStart: Double, compatLevel: Int, decoderList: [String], transportMode: String, prepareStartedAt: TimeInterval) {
        guard preparingGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration) else { return }
        preparingGeneration = nil
        preparedGeneration = currentGeneration
        endCandidateSince = nil
        let elapsedMs = (CACurrentMediaTime() - prepareStartedAt) * 1_000
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=prepared-activate callbackMs=\(String(format: \"%.1f\", elapsedMs)) preparedAtMs=\(preparedAtMs) rendererBound=false statePoll=false")
        let queue = nativeControlQueue
        queue.async { [weak self, weak player, weak renderer] in
            guard let self, let player, let renderer, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.playbackRate = Float(self.playbackRate)
            if self.shouldPlay { player.state = .Playing }
            DispatchQueue.main.async { [weak self, weak player, weak renderer] in
                guard let self, let player, let renderer, self.renderer === renderer, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
                self.startStateTimer(player: player, generation: currentGeneration, queue: self.nativeControlQueue)
                self.startRenderWatchdog()
                self.scheduleFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: requestedStart)
                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: \"%.3f\", requestedStart)) sourceFPS=\(self.sourceFrameRateText) compatLevel=\(compatLevel) videoDecoders=\(decoderList.joined(separator: \",\")) transport=\(transportMode) probation=passed rendererBound=true statePoll=true")
            }
        }
    }

    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            let elapsedMs = (CACurrentMediaTime() - startedAt) * 1_000
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=prepare-timeout elapsedMs=\(String(format: \"%.1f\", elapsedMs)) start=\(String(format: \"%.3f\", startPosition)) mainResponsive=true")
            self.quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")
        }
    }

    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {
        let startSerial = renderedFrameSerial
        DispatchQueue.main.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration), self.shouldPlay else { return }
            guard !self.hasRenderedValidFrame, self.renderedFrameSerial <= startSerial else { return }
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=first-frame-timeout elapsedMs=\(Int(self.firstFrameWatchdogSeconds * 1_000)) position=\(String(format: \"%.3f\", self.lastNativePosition)) mainResponsive=true")
            self.quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, self.lastNativePosition), failedGeneration: currentGeneration, message: "MDK native first frame timeout")
        }
    }

    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {
        guard currentGeneration == generation else { return }
        let player = swift_mdk.Player()
        installPlayer(player)
        let renderer = self.renderer
        let queue = nativeControlQueue
        let surfaceSize = view.currentPixelSize
        let prepareStartedAt = CACurrentMediaTime()
        schedulePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: prepareStartedAt)
        queue.async { [weak self, weak player, weak renderer] in
            guard let self, let player, let renderer, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            let compatLevel = self.abnormalMediaRecoveryLevel
            let decoderList = compatLevel >= 2 ? ["FFmpeg", "VT"] : ["VT", "FFmpeg"]
            player.videoDecoders = decoderList
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            player.setProperty(name: "keep_open", value: "1")
            if compatLevel >= 2 {
                player.setProperty(name: "avformat.err_detect", value: "ignore_err")
                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")
            }
            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")
            DiagnosticsLogger.shared.playback("MDKCompat", "generation=\(currentGeneration) level=\(compatLevel) profile=\(compatProfile) videoDecoders=\(decoderList.joined(separator: \",\")) avformatTolerance=\(compatLevel >= 2 ? \"ignore_err+discardcorrupt\" : \"off\") globalDemuxTolerance=off")
            player.media = url.absoluteString
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=prepare-dispatch start=\(String(format: \"%.3f\", startPosition)) rendererBound=false statePoll=false nativeQueue=isolated")
            player.prepare(from: self.milliseconds(startPosition), complete: { [weak self, weak player, weak renderer] preparedAtMs, boost in
                boost = true
                guard let self, let player, let renderer else { return false }
                DispatchQueue.main.async { [weak self, weak player, weak renderer] in
                    guard let self, let player, let renderer else { return }
                    self.activatePreparedPlayer(player, renderer: renderer, surfaceSize: surfaceSize, generation: currentGeneration, preparedAtMs: preparedAtMs, requestedStart: startPosition, compatLevel: compatLevel, decoderList: decoderList, transportMode: transportMode, prepareStartedAt: prepareStartedAt)
                }
                return true
            })
            DiagnosticsLogger.shared.playback("MDK", "prepare item=\(self.source.itemId) version=\(swift_mdk.version()) transport=\(transportMode) localHost=\(url.host == \"127.0.0.1\") sharedTransport=\(self.sharedTransportSession != nil ? \"active\" : \"unavailable\") headers=\(headers.keys.sorted().joined(separator: \",\")) rate=\(String(format: \"%.2f\", self.playbackRate)) nativeQueue=isolated probation=true")
        }
    }'''
engine = replace_method(
    engine,
    "    private func startMDKPlayer(",
    "    private func attachCallbacks(",
    helpers_and_start,
    "startMDKPlayer",
)

engine = replace_once(
    engine,
    '''        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing && !ended
''',
    '''        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing
''',
    "poll raw end state",
)

old_state_block = '''        lastNativePosition = position
        lastNativeDuration = duration
        lastNativeBuffering = rawBuffering
        lastNativeStatus = status
        lastNativeBufferMs = bufferMs
        lastNativeIsPlaying = isPlaying
        lastNativeEnded = ended

        if ended, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
'''
new_state_block = '''        lastNativePosition = position
        lastNativeDuration = duration
        lastNativeBuffering = rawBuffering
        lastNativeStatus = status
        lastNativeBufferMs = bufferMs

        let farFromEnd = duration > 0 && position + max(3, duration * 0.005) < duration
        var confirmedEnd = false
        if ended, farFromEnd {
            let seekActive = activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil
            if seekActive || rawBuffering {
                endCandidateSince = nil
            } else if let candidateSince = endCandidateSince {
                let progressed = position > endCandidatePosition + 0.08 || renderedFrameSerial > endCandidateFrameSerial
                if progressed {
                    endCandidateSince = now
                    endCandidatePosition = position
                    endCandidateFrameSerial = renderedFrameSerial
                } else if now - candidateSince >= endConfirmationSeconds {
                    confirmedEnd = true
                    DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=confirmed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) elapsedMs=\\(Int((now - candidateSince) * 1_000)) frameSerial=\\(renderedFrameSerial)")
                }
            } else {
                endCandidateSince = now
                endCandidatePosition = position
                endCandidateFrameSerial = renderedFrameSerial
                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=armed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) rawStatus=0x\\(String(status, radix: 16))")
            }
        } else if ended {
            confirmedEnd = true
            endCandidateSince = nil
        } else {
            if endCandidateSince != nil {
                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=cancelled position=\\(String(format: \"%.3f\", position)) reason=raw-end-cleared")
            }
            endCandidateSince = nil
        }
        lastNativeIsPlaying = isPlaying && !confirmedEnd
        lastNativeEnded = confirmedEnd

        if confirmedEnd, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
'''
engine = replace_once(engine, old_state_block, new_state_block, "confirmed end state block")

engine = replace_once(
    engine,
    '''        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))
''',
    '''        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying && !confirmedEnd, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: confirmedEnd))
''',
    "snapshot confirmed end",
)

engine = replace_once(
    engine,
    '''    private func stopPlayerOnly() {
        stateTimer?.cancel()
''',
    '''    private func stopPlayerOnly() {
        preparingGeneration = nil
        preparedGeneration = -1
        endCandidateSince = nil
        stateTimer?.cancel()
''',
    "stop probation reset",
)

start = engine.find("    private func startMDKPlayer(")
end = engine.find("    private func attachCallbacks(", start)
start_method = engine[start:end]
if "renderer.bind(player)" in start_method or "startStateTimer(" in start_method:
    raise SystemExit("prepare probation violated: renderer/state polling appears in startMDKPlayer")
if "player.prepare(" not in start_method:
    raise SystemExit("missing native prepare")
if 'didReachEnd: confirmedEnd' not in engine:
    raise SystemExit("confirmed EOF not materialized")
if 'phase=first-frame-timeout' not in engine or 'phase=prepare-timeout' not in engine:
    raise SystemExit("startup watchdogs not materialized")

ENGINE.write_text(engine)

project = PROJECT.read_text()
if project.count('MARKETING_VERSION: "0.13.25"') != 2 or project.count('CURRENT_PROJECT_VERSION: "92"') != 2:
    raise SystemExit("unexpected Build92 project version anchors")
project = project.replace('MARKETING_VERSION: "0.13.25"', 'MARKETING_VERSION: "0.13.26"')
project = project.replace('CURRENT_PROJECT_VERSION: "92"', 'CURRENT_PROJECT_VERSION: "93"')
PROJECT.write_text(project)

identity = IDENTITY.read_text()
identity = identity.replace('static let sourceVersion = "0.13.25"', 'static let sourceVersion = "0.13.26"')
identity = identity.replace('?? "0.13.25"', '?? "0.13.26"')
if 'static let sourceVersion = "0.13.26"' not in identity or '?? "0.13.26"' not in identity:
    raise SystemExit("AppIdentity version update failed")
IDENTITY.write_text(identity)

print("materialized OnePlayer 0.13.26 Build93 MDK prepare probation + first-frame guard + confirmed EOF")
