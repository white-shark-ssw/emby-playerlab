from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, count))


def replace_between(path: str, start: str, end: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    if replacement in text:
        return
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"Start marker not found in {path}")
    b = text.find(end, a + len(start))
    if b < 0:
        raise SystemExit(f"End marker not found in {path}")
    p.write_text(text[:a] + replacement + text[b:])


# MPV: roll back the v0.9.4 EDR hook. Keep the pre-existing 1x1 drawable guard.
mpv = Path("Sources/Player/MPVPlayerEngine.swift")
text = mpv.read_text()
edr_start = "    // MPVKit's own iOS Metal layer marshals EDR changes to the main thread."
edr_end = "}\n\n#if canImport(Libmpv)"
if edr_start in text:
    a = text.index(edr_start)
    b = text.index(edr_end, a)
    text = text[:a] + text[b:]
text = text.replace('        if #available(iOS 16.0, *) { displayLayer.wantsExtendedDynamicRangeContent = true }\n', '')
mpv.write_text(text)

# MPV surface: no CALayer delegate handoff is needed for frame/bounds layout.
replace("Sources/UI/MPVPlayerSurface.swift", '''        if displayLayer !== layer {
            if displayLayer?.delegate === self { displayLayer?.delegate = nil }
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            layer.delegate = self
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer delegate=MPVSurfaceUIView")
        }
''', '''        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer")
        }
''')
replace("Sources/UI/MPVPlayerSurface.swift", '''    func detach() {
        if displayLayer?.delegate === self { displayLayer?.delegate = nil }
        displayLayer?.removeFromSuperlayer()
''', '''    func detach() {
        displayLayer?.removeFromSuperlayer()
''')

# Timeline: hide the visible thumb but preserve the full DragGesture/contentShape hit target.
replace("Sources/UI/BufferedTimelineSlider.swift", '''
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 1)
                    .offset(x: thumbOffset(totalWidth: width))
''', "\n")
replace("Sources/UI/BufferedTimelineSlider.swift", '''
    private func thumbOffset(totalWidth: CGFloat) -> CGFloat {
        let thumbWidth: CGFloat = 16
        return min(max(0, totalWidth * fraction(for: value) - thumbWidth / 2), max(0, totalWidth - thumbWidth))
    }
''', "\n")

# Unified transport: sequential throughput may use 32/64 MiB; urgent remains 16 MiB.
replace("Sources/Transport/UnifiedMediaTransportSession.swift", "        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 16 * 1_048_576)\n", "        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 64 * 1_048_576)\n")
replace("Sources/Transport/UnifiedMediaTransportSession.swift", '''        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
        metricsValue.activeRequestCount = slotTasks.count + 1
''', '''        rangeMap.setDownloading(claim.range, lane: "slot\\(slot)")
        if slot == 0, claim.role == .urgentPlayback, !secondaryEnabled {
            secondaryEnabled = true
            DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled alongside urgent playback")
        }
        metricsValue.activeRequestCount = slotTasks.count + 1
''')

seq_start = "            if claim.role == .sequential {\n"
seq_end = "            } else {\n                var slowStartupRefreshUsed = false\n"
seq_new = '''            if claim.role == .sequential {
                // Keep one long Range request alive for throughput while every received chunk is
                // committed to ByteStore immediately. This preserves progressive visibility without
                // paying a fresh HTTP Range request every 4 MiB.
                while receivedForClaim < Int64(claim.range.count) {
                    try Task.checkCancellation()
                    let remaining = (claim.range.lowerBound + receivedForClaim)..<claim.range.upperBound
                    let attemptStarted = Date()
                    var attemptReceived: Int64 = 0
                    do {
                        for try await chunk in client.stream(resource: resolved, range: remaining, worker: slot) {
                            try Task.checkCancellation()
                            let writeOffset = claim.range.lowerBound + receivedForClaim
                            try store.write(chunk, at: writeOffset)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            rangeMap.insertPlayback(writeOffset..<min(claim.range.upperBound, writeOffset + Int64(chunk.count)))
                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) first-chunk role=sequential range=\\(remaining.lowerBound)-\\(remaining.upperBound) bytes=\\(chunk.count) ms=\\(Int(firstChunkSeconds * 1000)) speedBps=\\(Int(Double(chunk.count) / firstChunkSeconds))")
                            }
                            refreshMetrics(resource: resolved)
                        }
                    } catch MediaTransportError.expiredURL {
                        DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\\(slot) refreshing expired 115 URL")
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    break
                }
                let elapsed = max(Date().timeIntervalSince(started), 0.001)
                let bps = Double(receivedForClaim) / elapsed
                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\\(slot) finish role=\\(claim.role.rawValue) range=\\(claim.range.lowerBound)-\\(claim.range.upperBound) bytes=\\(receivedForClaim) speedBps=\\(Int(bps)) progressive=true longRange=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil)
            } else {
                var slowStartupRefreshUsed = false
'''
replace_between("Sources/Transport/UnifiedMediaTransportSession.swift", seq_start, seq_end, seq_new)

# 32 MiB sequential background default.
replace("Sources/Transport/TransportSettings.swift", "            TransportSettingsKey.upstreamBlockSizeMB: 16,\n", "            TransportSettingsKey.upstreamBlockSizeMB: 32,\n")
replace("Sources/Transport/TransportSettings.swift", '''        let upstreamBlockMB = [4, 8, 16, 32, 64].contains(defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB))
            ? defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB)
            : 16
''', '''        let upstreamBlockMB = [4, 8, 16, 32, 64].contains(defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB))
            ? defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB)
            : 32
''')

# Crash breadcrumbs around MPV construction/prepare.
replace("Sources/Player/PlayerController.swift", '''        self.transportContext = transportContext
        self.engineKind = initialKind
        self.engine = PlayerController.makeEngine(kind: initialKind, source: source, client: client, transportContext: transportContext)
        bindEngine()
''', '''        self.transportContext = transportContext
        self.engineKind = initialKind
        if initialKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "engine create begin item=\\(source.itemId)") }
        self.engine = PlayerController.makeEngine(kind: initialKind, source: source, client: client, transportContext: transportContext)
        if initialKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "engine create finished item=\\(source.itemId)") }
        bindEngine()
''')
replace("Sources/Player/PlayerController.swift", '''        suppressStallWatchdog(for: engineKind == .mpv ? 12 : 6)
        engine.prepare(
''', '''        suppressStallWatchdog(for: engineKind == .mpv ? 12 : 6)
        if engineKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "prepare begin item=\\(source.itemId)") }
        engine.prepare(
''')
replace("Sources/Player/PlayerController.swift", '''            startPosition: 0
        )
        engine.play()
''', '''            startPosition: 0
        )
        if engineKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "prepare returned item=\\(source.itemId)") }
        engine.play()
''')

# v0.9.5 / Build 51 metadata.
replace("Sources/Core/AppIdentity.swift", '    static let sourceVersion = "0.9.4"\n', '    static let sourceVersion = "0.9.5"\n')
replace("Sources/Core/AppIdentity.swift", '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.4"\n', '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.5"\n')
p = Path("project.yml"); text = p.read_text(); p.write_text(text.replace('MARKETING_VERSION: "0.9.4"', 'MARKETING_VERSION: "0.9.5"').replace('CURRENT_PROJECT_VERSION: "50"', 'CURRENT_PROJECT_VERSION: "51"'))
replace("Config/Info.plist", '<key>CFBundleShortVersionString</key>\n\t<string>0.9.4</string>', '<key>CFBundleShortVersionString</key>\n\t<string>0.9.5</string>')
replace("Config/Info.plist", '<key>CFBundleVersion</key>\n\t<string>50</string>', '<key>CFBundleVersion</key>\n\t<string>51</string>')
replace(".github/workflows/build-unsigned-ipa.yml", 'IPA_NAME="EmbyPlayerLab-0.9.4-${GITHUB_SHA::7}-unsigned.ipa"', 'IPA_NAME="EmbyPlayerLab-0.9.5-${GITHUB_SHA::7}-unsigned.ipa"')
