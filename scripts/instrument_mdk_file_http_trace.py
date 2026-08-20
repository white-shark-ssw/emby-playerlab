from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


# Diagnostic identity. Keep the actual deployment target at iOS 15.0.
for _ in range(2):
    replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.32"', 'MARKETING_VERSION: "0.13.34"')
    replace_once("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "99"', 'CURRENT_PROJECT_VERSION: "101"')
replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.13.32"', 'static let sourceVersion = "0.13.34"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.32"', '?? "0.13.34"')

# Preserve the Build100 byte-level online diagnostics so an MDK HTTP failure can be
# correlated with exact UnifiedTransport reads and upstream Range semantics.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        metricsValue.bytesServed += Int64(requested)\n''',
    '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=request offset=\\(offset) requested=\\(requested) available=\\(available) total=\\(resolved.contentLength) tailMetadata=\\(concreteTailMetadata) pendingSeek=\\(Date() <= pendingUserSeekUntil) anchor=\\(playbackAnchor) center=\\(cacheWindowCenter)")\n        metricsValue.bytesServed += Int64(requested)\n'''
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)\n            refreshMetrics(resource: resolved)\n            return data\n''',
    '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)\n            refreshMetrics(resource: resolved)\n            let next = offset + Int64(data.count)\n            DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=return offset=\\(offset) requested=\\(requested) returned=\\(data.count) next=\\(next) total=\\(resolved.contentLength) short=\\(data.count < requested) eof=\\(next >= resolved.contentLength)")\n            return data\n'''
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''            return try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)\n''',
    '''            let retryData = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)\n            let retryNext = offset + Int64(retryData.count)\n            DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=retry-return offset=\\(offset) requested=\\(requested) returned=\\(retryData.count) next=\\(retryNext) total=\\(resolved.contentLength) short=\\(retryData.count < requested) eof=\\(retryNext >= resolved.contentLength)")\n            return retryData\n'''
)
replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''        guard http.statusCode == 206 else { throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode) }\n\n        let expected = Int(range.upperBound - range.lowerBound)\n        guard data.count == expected else { throw MediaTransportError.shortRead(expected: expected, actual: data.count) }\n''',
    '''        guard http.statusCode == 206 else {\n            DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) end=\\(range.upperBound - 1) status=\\(http.statusCode) contentRange=\\(http.value(forHTTPHeaderField: \"Content-Range\") ?? \"nil\") contentLength=\\(http.value(forHTTPHeaderField: \"Content-Length\") ?? \"nil\") actual=\\(data.count) action=reject-non206")\n            throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode)\n        }\n\n        let expected = Int(range.upperBound - range.lowerBound)\n        DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) end=\\(range.upperBound - 1) status=206 expected=\\(expected) actual=\\(data.count) contentRange=\\(http.value(forHTTPHeaderField: \"Content-Range\") ?? \"nil\") contentLength=\\(http.value(forHTTPHeaderField: \"Content-Length\") ?? \"nil\") redirects=\\(delegate.redirects.count)")\n        guard data.count == expected else {\n            DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) expected=\\(expected) actual=\\(data.count) action=short-read-error")\n            throw MediaTransportError.shortRead(expected: expected, actual: data.count)\n        }\n'''
)

# Formal online MDK path: add one compact trace session that can be aligned with
# the local file trace by media position, MDK status and render progress.
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''    private var endCandidateFrameSerial: UInt64 = 0\n\n    var playerView: UIView? { view }\n''',
    '''    private var endCandidateFrameSerial: UInt64 = 0\n    private var inputTraceSession = "unassigned"\n    private var inputTraceSource = "unknown"\n    private var inputTraceLastSecond = -1\n    private var inputTraceDidLogConfirmedEnd = false\n\n    var playerView: UIView? { view }\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''        generation &+= 1\n        let currentGeneration = generation\n        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\\(currentGeneration)", qos: .userInitiated)\n''',
    '''        generation &+= 1\n        let currentGeneration = generation\n        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()\n        inputTraceSource = sharedTransportSession != nil ? "http-unified-localhost" : (url.isFileURL ? "file" : "http-direct")\n        inputTraceLastSecond = -1\n        inputTraceDidLogConfirmedEnd = false\n        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=open generation=\\(currentGeneration) start=\\(String(format: \"%.3f\", startPosition)) scheme=\\(url.scheme ?? \"nil\") bytes=\\(source.mediaSource.size ?? 0)")\n        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\\(currentGeneration)", qos: .userInitiated)\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''                DiagnosticsLogger.shared.playback("MDKStatus", "raw=0x\\(String(status.rawValue, radix: 16)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) nativeCallbackMainRead=false")\n                if self.shouldPlay, self.isPrepared(status.rawValue) { self.requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }\n''',
    '''                DiagnosticsLogger.shared.playback("MDKStatus", "raw=0x\\(String(status.rawValue, radix: 16)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) nativeCallbackMainRead=false")\n                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(self.inputTraceSession) source=\\(self.inputTraceSource) event=status position=\\(String(format: \"%.3f\", self.lastNativePosition)) raw=0x\\(String(status.rawValue, radix: 16)) frameSerial=\\(self.renderedFrameSerial)")\n                if self.shouldPlay, self.isPrepared(status.rawValue) { self.requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''        lastNativeBufferMs = bufferMs\n\n        let farFromEnd = duration > 0 && position + max(3, duration * 0.005) < duration\n''',
    '''        lastNativeBufferMs = bufferMs\n        let traceSecond = Int(max(0, position).rounded(.down))\n        if traceSecond != inputTraceLastSecond {\n            inputTraceLastSecond = traceSecond\n            DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=progress position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) raw=0x\\(String(status, radix: 16)) playing=\\(isPlaying) buffering=\\(rawBuffering) bufferMs=\\(bufferMs) frameSerial=\\(renderedFrameSerial) renderValue=\\(lastRenderedTimestamp.map { String(format: \"%.6f\", $0) } ?? \"nil\")")\n        }\n\n        let farFromEnd = duration > 0 && position + max(3, duration * 0.005) < duration\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''                    confirmedEnd = true\n                    DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=confirmed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) elapsedMs=\\(Int((now - candidateSince) * 1_000)) frameSerial=\\(renderedFrameSerial)")\n''',
    '''                    confirmedEnd = true\n                    DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=confirmed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) elapsedMs=\\(Int((now - candidateSince) * 1_000)) frameSerial=\\(renderedFrameSerial)")\n                    if !inputTraceDidLogConfirmedEnd { inputTraceDidLogConfirmedEnd = true; DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=eof-confirmed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) raw=0x\\(String(status, radix: 16)) frameSerial=\\(renderedFrameSerial) renderValue=\\(lastRenderedTimestamp.map { String(format: \"%.6f\", $0) } ?? \"nil\")") }\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=armed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) rawStatus=0x\\(String(status, radix: 16))")\n''',
    '''                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=armed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) rawStatus=0x\\(String(status, radix: 16))")\n                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=eof-armed position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) raw=0x\\(String(status, radix: 16)) frameSerial=\\(renderedFrameSerial)")\n'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''        lastRenderedTimestamp = renderResult\n        renderedFrameSerial &+= 1\n        guard let pending = pendingSeekResume''',
    '''        lastRenderedTimestamp = renderResult\n        renderedFrameSerial &+= 1\n        if renderedFrameSerial == 1 || renderedFrameSerial % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=render frameSerial=\\(renderedFrameSerial) position=\\(String(format: \"%.3f\", lastNativePosition)) renderValue=\\(String(format: \"%.6f\", renderResult))") }\n        guard let pending = pendingSeekResume'''
)
replace_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    '''    private func stopPlayerOnly() {\n        preparingGeneration = nil\n''',
    '''    private func stopPlayerOnly() {\n        if inputTraceSession != "unassigned" { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=stop position=\\(String(format: \"%.3f\", lastNativePosition)) raw=0x\\(String(lastNativeStatus, radix: 16)) frameSerial=\\(renderedFrameSerial) renderValue=\\(lastRenderedTimestamp.map { String(format: \"%.6f\", $0) } ?? \"nil\")") }\n        preparingGeneration = nil\n'''
)

# Local file MDK path. This engine intentionally stays visually unchanged; the
# trace measures media clock/status and render callback progress even if the
# experimental MTKView remains black.
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''    private var shouldPlay = false\n    private var firstFrameLogged = false\n''',
    '''    private var shouldPlay = false\n    private var firstFrameLogged = false\n    private var inputTraceSession = "unassigned"\n    private var inputTraceLastSecond = -1\n    private var inputTraceRenderCalls: UInt64 = 0\n    private var inputTraceLastRenderResult: Double?\n    private var inputTraceLastPosition: Double = 0\n    private var inputTraceLastStatus: Int32 = 0\n'''
)
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''        lastURL = url\n        firstFrameLogged = false\n        let player = swift_mdk.Player()\n''',
    '''        lastURL = url\n        firstFrameLogged = false\n        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()\n        inputTraceLastSecond = -1\n        inputTraceRenderCalls = 0\n        inputTraceLastRenderResult = nil\n        inputTraceLastPosition = max(0, startPosition)\n        inputTraceLastStatus = 0\n        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=file event=open start=\\(String(format: \"%.3f\", startPosition)) scheme=\\(url.scheme ?? \"nil\") name=\\(url.lastPathComponent)")\n        let player = swift_mdk.Player()\n'''
)
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''        player.setRenderCallback { [weak self] in\n            DispatchQueue.main.async { [weak self] in self?.playerView.setNeedsDisplay() }\n        }\n        player.media = url.absoluteString\n''',
    '''        player.setRenderCallback { [weak self] in\n            DispatchQueue.main.async { [weak self] in self?.playerView.setNeedsDisplay() }\n        }\n        player.onMediaStatusChanged { [weak self, weak player] status in\n            DispatchQueue.main.async { [weak self, weak player] in\n                guard let self, let player, self.player === player else { return }\n                self.inputTraceLastStatus = status.rawValue\n                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(self.inputTraceSession) source=file event=status position=\\(String(format: \"%.3f\", self.inputTraceLastPosition)) raw=0x\\(String(status.rawValue, radix: 16)) renderCalls=\\(self.inputTraceRenderCalls) renderValue=\\(self.inputTraceLastRenderResult.map { String(format: \"%.6f\", $0) } ?? \"nil\")")\n            }\n            return true\n        }\n        player.media = url.absoluteString\n'''
)
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''        let isPlaying = player.state == .Playing\n        let buffered = Double(max(0, player.buffered())) / 1_000\n''',
    '''        let isPlaying = player.state == .Playing\n        let status = player.mediaStatus.rawValue\n        inputTraceLastPosition = position\n        inputTraceLastStatus = status\n        let traceSecond = Int(max(0, position).rounded(.down))\n        if traceSecond != inputTraceLastSecond {\n            inputTraceLastSecond = traceSecond\n            DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=file event=progress position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) raw=0x\\(String(status, radix: 16)) playing=\\(isPlaying) bufferMs=\\(player.buffered()) renderCalls=\\(inputTraceRenderCalls) renderValue=\\(inputTraceLastRenderResult.map { String(format: \"%.6f\", $0) } ?? \"nil\")")\n        }\n        let buffered = Double(max(0, player.buffered())) / 1_000\n'''
)
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''        let result = player.renderVideo(vid: view)\n        if !firstFrameLogged {\n''',
    '''        let result = player.renderVideo(vid: view)\n        inputTraceRenderCalls &+= 1\n        inputTraceLastRenderResult = result\n        if inputTraceRenderCalls == 1 || inputTraceRenderCalls % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=file event=render renderCalls=\\(inputTraceRenderCalls) position=\\(String(format: \"%.3f\", inputTraceLastPosition)) renderValue=\\(String(format: \"%.6f\", result))") }\n        if !firstFrameLogged {\n'''
)
replace_once(
    "Sources/UI/LocalMDKDirectEngine.swift",
    '''    private func stopPlayerOnly() {\n        stateTimer?.invalidate()\n''',
    '''    private func stopPlayerOnly() {\n        if inputTraceSession != "unassigned" { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=file event=stop position=\\(String(format: \"%.3f\", inputTraceLastPosition)) raw=0x\\(String(inputTraceLastStatus, radix: 16)) renderCalls=\\(inputTraceRenderCalls) renderValue=\\(inputTraceLastRenderResult.map { String(format: \"%.6f\", $0) } ?? \"nil\")") }\n        stateTimer?.invalidate()\n'''
)

print("MDK file/http input trace instrumentation applied")
