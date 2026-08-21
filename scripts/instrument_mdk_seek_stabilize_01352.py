from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"missing start marker in {path}: {start!r}")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"missing end marker in {path}: {end!r}")
    p.write_text(text[:i] + new + text[j:])


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
controller_path = "Sources/Player/PlayerController.swift"
slider_path = "Sources/UI/BufferedTimelineSlider.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build119 is a stabilization pass, not another Seek-performance experiment.
replace_once(identity_path, 'sourceVersion = "0.13.51"', 'sourceVersion = "0.13.52"')

# 1) Native MDK Seek ownership: single-flight latest-wins.
replace_between(
    engine_path,
    "    func seek(to targetSeconds: Double, direction: SeekDirection) {\n",
    "    private var nativeSeekOutstandingCount:",
    '''    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player = currentPlayerReference() else { return }
        let target = max(0, targetSeconds)
        guard preparedGeneration == generation else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(generation) phase=seek-deferred target=\\(String(format: \"%.3f\", target))")
            return
        }
        let duration = max(source.mediaSource.durationSeconds ?? 0, lastNativeDuration)
        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        let previousUserSeekAt = lastUserSeekRequestedAt
        let fastPreview: Bool
        switch direction {
        case .forward, .backward: fastPreview = true
        case .absolute: fastPreview = false
        }
        lastUserSeekRequestedAt = requestedAt
        seekGeneration &+= 1
        let seekID = seekGeneration
        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        intent.fastPreview = fastPreview
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=\\(fastPreview ? \"relative-fast-only\" : \"absolute-accurate\") previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) nativePolicy=single-flight-latest-wins")

        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) active=\\(activeNativeSeek.id) replacedQueued=\\(replaced.map { String($0) } ?? \"none\") action=queue-latest-single-flight")
            return
        }
        dispatchNativeSeek(intent, player: player)
    }

'''
)

# Build118's 50ms experiment did not restore audible output. Return to 200ms.
replace_once(engine_path, "    private let relativeSeekBufferMinMs: Int64 = 50\n", "")
replace_once(
    engine_path,
    '''            let activeSeekBufferMinMs: Int64
            switch dispatchedIntent.direction {
            case .forward, .backward: activeSeekBufferMinMs = self.relativeSeekBufferMinMs
            case .absolute: activeSeekBufferMinMs = self.seekBufferMinMs
            }
            player.setBufferRange(msMin: activeSeekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)
            DiagnosticsLogger.shared.playback("MDKSeekBuffer", "id=\\(dispatchedIntent.id) phase=low-latency minMs=\\(activeSeekBufferMinMs) relativeMinMs=\\(self.relativeSeekBufferMinMs) accurateMinMs=\\(self.seekBufferMinMs) normalMinMs=\\(self.normalBufferMinMs) direction=\\(String(describing: dispatchedIntent.direction))")
''',
    '''            player.setBufferRange(msMin: self.seekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)
            DiagnosticsLogger.shared.playback("MDKSeekBuffer", "id=\\(dispatchedIntent.id) phase=seek-baseline minMs=\\(self.seekBufferMinMs) normalMinMs=\\(self.normalBufferMinMs) direction=\\(String(describing: dispatchedIntent.direction))")
'''
)

# 2) One watchdog owner per Seek phase. Soft checks are diagnostic only.
replace_between(
    engine_path,
    "    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {\n",
    "    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n",
    '''    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {
        guard let nativeStartedAt = intent.nativeStartedAt, let startFrameSerial = intent.nativeStartFrameSerial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            let renderProgress = self.renderedFrameSerial > startFrameSerial
            DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedNativeMs=\\(String(format: \"%.1f\", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) renderProgress=\\(renderProgress) frameSerial=\\(self.renderedFrameSerial)/\\(startFrameSerial) action=diagnostic-only")
            if let session = self.sharedTransportSession {
                Task {
                    let metrics = await session.metrics()
                    DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\\(intent.id) transport anchor=\\(metrics.schedulerAnchorByte) frontier=\\(metrics.schedulerFrontierByte) cacheBytes=\\(metrics.cacheBytes) active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) action=diagnostic-only")
                }
            }
        }
    }

'''
)

replace_between(
    engine_path,
    "    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n",
    "    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {\n",
    '''    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {
        guard let nativeStartedAt = intent.nativeStartedAt else { return }
        let delay = hard ? activeNativeSeekHardWatchdogSeconds - activeNativeSeekWatchdogSeconds : activeNativeSeekWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            let now = Date().timeIntervalSince1970
            let startFrameSerial = intent.nativeStartFrameSerial ?? self.renderedFrameSerial
            let renderProgress = self.renderedFrameSerial > startFrameSerial
            let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)
            let rawBuffering = self.lastNativeBuffering
            let bufferMs = self.lastNativeBufferMs

            if !hard {
                DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedNativeMs=\\(String(format: \"%.1f\", (now - nativeStartedAt) * 1_000)) renderProgress=\\(renderProgress) position=\\(String(format: \"%.3f\", self.lastNativePosition)) bufferMs=\\(bufferMs) rawBuffering=\\(rawBuffering) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=diagnostic-only-soft")
                self.scheduleActiveNativeSeekWatchdog(player: player, intent: intent, hard: true)
                return
            }

            if renderProgress {
                self.activeNativeSeek = nil
                if let pending = self.pendingSeekResume, pending.id == intent.id, let rendered = self.lastRenderedTimestamp {
                    let totalLatency = (now - pending.requestedAt) * 1_000
                    self.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: rendered, bufferHit: false, completionLatencyMs: totalLatency, measurement: "MDK rendered progress retired late native callback"))
                    self.pendingSeekResume = nil
                }
                DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedNativeMs=\\(String(format: \"%.1f\", (now - nativeStartedAt) * 1_000)) renderProgress=true latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=retire-late-callback-keep-mdk")
                self.dispatchQueuedSeekIfNeeded(player: player)
                return
            }

            DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedNativeMs=\\(String(format: \"%.1f\", (now - nativeStartedAt) * 1_000)) renderProgress=false position=\\(String(format: \"%.3f\", self.lastNativePosition)) bufferMs=\\(bufferMs) rawBuffering=\\(rawBuffering) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=recover-hard-no-render-progress")
            self.recoverWedgedSeek(reason: "active-native-hard-no-render-progress", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration)
        }
    }

'''
)

replace_between(
    engine_path,
    "    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {\n",
    "    private func latestDesiredTarget(fallback: Double) -> Double {\n",
    '''    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {
        let delay = hard ? seekFrameHardWatchdogSeconds - seekFrameWatchdogSeconds : seekFrameWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID, let callbackAt = pending.callbackAt else { return }
            let now = Date().timeIntervalSince1970
            let expectedLanding = pending.callbackPosition ?? pending.target
            let rendered = self.lastRenderedTimestamp
            let validRenderedLanding = rendered.map { abs($0 - expectedLanding) <= 1.0 } ?? false
            let callbackSerial = pending.callbackFrameSerial ?? self.renderedFrameSerial
            let frameProgress = self.renderedFrameSerial > callbackSerial

            if validRenderedLanding, let rendered {
                self.pendingSeekResume = nil
                let totalLatency = (now - pending.requestedAt) * 1_000
                self.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: rendered, bufferHit: (callbackAt - pending.requestedAt) * 1_000 < 150, completionLatencyMs: totalLatency, measurement: "MDK watchdog observed valid rendered landing"))
                DiagnosticsLogger.shared.playback("MDKSeekFrameWatchdog", "id=\\(seekID) target=\\(String(format: \"%.3f\", pending.target)) callbackLanding=\\(String(format: \"%.3f\", expectedLanding)) rendered=\\(String(format: \"%.3f\", rendered)) frameProgress=\\(frameProgress) action=retire-valid-render-keep-mdk")
                return
            }

            if !hard {
                DiagnosticsLogger.shared.playback("MDKSeekFrameWatchdog", "id=\\(seekID) target=\\(String(format: \"%.3f\", pending.target)) callbackLanding=\\(String(format: \"%.3f\", expectedLanding)) rendered=\\(rendered.map { String(format: \"%.3f\", $0) } ?? \"none\") frameProgress=\\(frameProgress) action=diagnostic-only-soft")
                self.scheduleSeekFrameWatchdog(player: player, seekID: seekID, playerGeneration: playerGeneration, hard: true)
                return
            }

            let recoveryTarget = self.latestDesiredTarget(fallback: pending.target)
            DiagnosticsLogger.shared.playback("MDKSeekFrameWatchdog", "id=\\(seekID) target=\\(String(format: \"%.3f\", pending.target)) callbackLanding=\\(String(format: \"%.3f\", expectedLanding)) rendered=\\(rendered.map { String(format: \"%.3f\", $0) } ?? \"none\") frameProgress=\\(frameProgress) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=recover-hard-no-valid-landing")
            self.recoverWedgedSeek(reason: "callback-without-valid-frame-hard", fallbackTarget: recoveryTarget, playerGeneration: playerGeneration)
        }
    }

'''
)

# 3) Capture audible audio recovery markers instead of treating decoded audio as audible.
replace_once(engine_path, "        swift_mdk.logLevel = .Info\n", "        swift_mdk.logLevel = .Debug\n")
replace_once(
    engine_path,
    '''            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")
''',
    '''            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if level.rawValue >= 4 {
                let lower = trimmed.lowercased()
                let keepAudioDebug = lower.contains("seek end audio frame") || lower.contains("1st audio frame") || lower.contains("sync_ao_") || lower.contains("audiorender") || lower.contains("audioqueue")
                guard keepAudioDebug else { return }
            }
            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")
'''
)

# 4) UI presentation state is separate from playback snapshot state.
replace_once(
    controller_path,
    "    private var pendingSeekDirection: SeekDirection?\n",
    '''    private var pendingSeekDirection: SeekDirection?
    private struct SeekDisplayAnchor {
        let target: Double
        let direction: SeekDirection
        var landing: Double?
    }
    private var seekDisplayAnchor: SeekDisplayAnchor?
'''
)

replace_between(
    controller_path,
    "    func seek(by offset: Double) {\n",
    "    func beginScrubbing() {\n",
    '''    func seek(by offset: Double) {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        let base = pendingSeekTarget ?? seekDisplayAnchor?.landing ?? seekDisplayAnchor?.target ?? snapshot.position
        let target = clampPosition(base + offset)
        let direction: SeekDirection = offset >= 0 ? .forward : .backward
        pendingSeekTarget = target
        pendingSeekDirection = direction
        seekDisplayAnchor = SeekDisplayAnchor(target: target, direction: direction, landing: nil)
        displayedPosition = target
        suppressStallWatchdog(for: 3)
        DiagnosticsLogger.shared.log("SeekAnchor", "offset=\\(offset) base=\\(base) target=\\(target) enginePosition=\\(snapshot.position) presentation=target-held")
        engine.seek(to: target, direction: direction)
        #if MDK_LAB
        if engineKind == .ksAVIO { scheduleSeekAnchorRelease(expectedTarget: target) }
        #endif
        showSeekFeedback(offset: offset)
        scheduleSeekReport(position: pendingSeekTarget ?? target)
    }

'''
)

replace_between(
    controller_path,
    "    func beginScrubbing() {\n",
    "    func updateScrubbing(to value: Double)",
    '''    func beginScrubbing() {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekDisplayAnchor = nil
        userIsScrubbing = true
        screenScrubStartPosition = nil
    }

'''
)

replace_once(
    controller_path,
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        userIsScrubbing = true
        let start = snapshot.position
''',
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekDisplayAnchor = nil
        userIsScrubbing = true
        let start = snapshot.position
'''
)

replace_once(
    controller_path,
    "        let resumePosition = clampPosition(pendingSeekTarget ?? snapshot.position)\n",
    "        let resumePosition = clampPosition(pendingSeekTarget ?? seekDisplayAnchor?.landing ?? seekDisplayAnchor?.target ?? snapshot.position)\n"
)
replace_once(
    controller_path,
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekAnchorReleaseTask?.cancel()
''',
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekDisplayAnchor = nil
        seekAnchorReleaseTask?.cancel()
'''
)
replace_once(
    controller_path,
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        screenScrubStartPosition = nil
        DiagnosticsLogger.shared.log("Lifecycle", "player close detached")
''',
    '''        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekDisplayAnchor = nil
        screenScrubStartPosition = nil
        DiagnosticsLogger.shared.log("Lifecycle", "player close detached")
'''
)

replace_between(
    controller_path,
    "                if self.snapshotCanCompleteSeekAnchor, !self.userIsScrubbing, let pending = self.pendingSeekTarget, self.hasReachedPendingTarget(actual: value.position, target: pending) {\n",
    "                if let error = value.errorMessage",
    '''                if self.snapshotCanCompleteSeekAnchor, !self.userIsScrubbing, let pending = self.pendingSeekTarget, self.hasReachedPendingTarget(actual: value.position, target: pending) {
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    if var anchor = self.seekDisplayAnchor {
                        anchor.landing = value.position
                        self.seekDisplayAnchor = anchor
                    }
                    DiagnosticsLogger.shared.log("SeekAnchor", "reached target=\\(pending) actual=\\(value.position) source=snapshot")
                }

                if !self.userIsScrubbing {
                    if let anchor = self.seekDisplayAnchor {
                        if self.hasReachedSeekDisplayAnchor(actual: value.position, anchor: anchor) {
                            self.seekDisplayAnchor = nil
                            self.displayedPosition = value.position
                            DiagnosticsLogger.shared.log("SeekPresentation", "target=\\(anchor.target) landing=\\(anchor.landing ?? anchor.target) snapshot=\\(value.position) action=release-to-snapshot")
                        } else {
                            self.displayedPosition = anchor.landing ?? anchor.target
                        }
                    } else if self.pendingSeekTarget == nil {
                        self.displayedPosition = value.position
                    }
                }

'''
)

replace_between(
    controller_path,
    "                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {\n",
    "                let actualText =",
    '''                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    let direction = self.pendingSeekDirection ?? self.seekDisplayAnchor?.direction ?? .absolute
                    let landing = result.actualPosition ?? pending
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    var anchor = self.seekDisplayAnchor ?? SeekDisplayAnchor(target: pending, direction: direction, landing: nil)
                    anchor.landing = landing
                    self.seekDisplayAnchor = anchor
                    self.displayedPosition = landing
                    self.suppressStallWatchdog(for: 2.5)
                    DiagnosticsLogger.shared.log("SeekAnchor", "completed target=\\(pending) actual=\\(landing) presentation=hold-until-snapshot-catches")
                }
'''
)

replace_between(
    controller_path,
    "    private func commitScrubbedPosition() {\n",
    "    private func scheduleSeekAnchorRelease(expectedTarget: Double) {\n",
    '''    private func commitScrubbedPosition() {
        userIsScrubbing = false
        let target = clampPosition(displayedPosition)
        pendingSeekTarget = target
        pendingSeekDirection = .absolute
        seekDisplayAnchor = SeekDisplayAnchor(target: target, direction: .absolute, landing: nil)
        suppressStallWatchdog(for: 3)
        engine.seek(to: target, direction: .absolute)
        #if MDK_LAB
        if engineKind == .ksAVIO { scheduleSeekAnchorRelease(expectedTarget: target) }
        #endif
        Task { await client.reportProgress(source: source, position: target, paused: !snapshot.isPlaying, eventName: "TimeUpdate") }
    }

'''
)

replace_between(
    controller_path,
    "    private func scheduleSeekAnchorRelease(expectedTarget: Double) {\n",
    "\n\n    private var snapshotCanCompleteSeekAnchor:",
    '''    private func scheduleSeekAnchorRelease(expectedTarget: Double) {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled, let pending = self.pendingSeekTarget, abs(pending - expectedTarget) < 0.01 else { return }
            self.pendingSeekTarget = nil
            self.pendingSeekDirection = nil
            if var anchor = self.seekDisplayAnchor, abs(anchor.target - expectedTarget) < 0.01 {
                if anchor.landing == nil { anchor.landing = expectedTarget }
                self.seekDisplayAnchor = anchor
                self.displayedPosition = anchor.landing ?? anchor.target
            }
            DiagnosticsLogger.shared.log("SeekAnchor", "timeout target=\\(expectedTarget) snapshot=\\(self.snapshot.position) action=release-intent-hold-presentation")
        }
    }
'''
)

replace_once(
    controller_path,
    '''    private func hasReachedPendingTarget(actual: Double, target: Double) -> Bool {
        switch pendingSeekDirection {
        case .forward: return actual >= target - 0.25
        case .backward: return actual <= target + 0.25
        case .absolute: return abs(actual - target) <= 0.40
        case .none: return false
        }
    }

''',
    '''    private func hasReachedPendingTarget(actual: Double, target: Double) -> Bool {
        switch pendingSeekDirection {
        case .forward: return actual >= target - 0.25
        case .backward: return actual <= target + 0.25
        case .absolute: return abs(actual - target) <= 0.40
        case .none: return false
        }
    }

    private func hasReachedSeekDisplayAnchor(actual: Double, anchor: SeekDisplayAnchor) -> Bool {
        let expected = anchor.landing ?? anchor.target
        switch anchor.direction {
        case .forward: return actual >= expected - 0.25
        case .backward: return actual <= expected + 0.25
        case .absolute: return abs(actual - expected) <= 0.40
        }
    }

'''
)

# 5) True playable window gets its own visible band instead of sharing the main white track.
replace_between(
    slider_path,
    "    var body: some View {\n",
    "    private var normalizedLivePlayableRanges:",
    '''    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let progressTrackHeight: CGFloat = 6
            let liveTrackHeight: CGFloat = 3

            VStack(spacing: 3) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.20)).frame(height: progressTrackHeight)

                    ForEach(Array(normalizedCacheRanges.enumerated()), id: \\.offset) { _, cached in
                        Rectangle()
                            .fill(Color.white.opacity(0.30))
                            .frame(width: max(1, width * CGFloat(cached.upperBound - cached.lowerBound)), height: progressTrackHeight)
                            .offset(x: width * CGFloat(cached.lowerBound))
                    }

                    Rectangle().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: progressTrackHeight)
                }
                .frame(width: width, height: progressTrackHeight)
                .clipShape(Capsule())

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: liveTrackHeight)

                    ForEach(Array(normalizedLivePlayableRanges.enumerated()), id: \\.offset) { _, playable in
                        Rectangle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: max(2, width * CGFloat(playable.upperBound - playable.lowerBound)), height: liveTrackHeight)
                            .offset(x: width * CGFloat(playable.lowerBound))
                    }
                }
                .frame(width: width, height: liveTrackHeight)
                .clipShape(Capsule())
            }
            .frame(width: width, height: max(geometry.size.height, 32), alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isEditing {
                            isEditing = true
                            onEditingChanged(true)
                        }
                        value = valueForLocation(gesture.location.x, totalWidth: width)
                    }
                    .onEnded { gesture in
                        value = valueForLocation(gesture.location.x, totalWidth: width)
                        isEditing = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("播放进度")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = max((range.upperBound - range.lowerBound) / 100, 1)
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
            onEditingChanged(false)
        }
    }

'''
)

engine = Path(engine_path).read_text()
controller = Path(controller_path).read_text()
slider = Path(slider_path).read_text()
identity = Path(identity_path).read_text()

assert "action=queue-latest-single-flight" in engine
assert "MDKSeekPreempt" not in engine
assert "nativePolicy=single-flight-latest-wins" in engine
assert "private let relativeSeekBufferMinMs" not in engine
assert "phase=seek-baseline" in engine
assert "action=diagnostic-only-soft" in engine
assert "action=retire-late-callback-keep-mdk" in engine
assert "action=recover-hard-no-render-progress" in engine
assert "action=recover-hard-no-valid-landing" in engine
assert "swift_mdk.logLevel = .Debug" in engine
assert 'lower.contains("1st audio frame")' in engine
assert "SeekDisplayAnchor" in controller
assert "presentation=hold-until-snapshot-catches" in controller
assert "action=release-to-snapshot" in controller
assert "release-intent-hold-presentation" in controller
assert "liveTrackHeight: CGFloat = 3" in slider
assert "Color.white.opacity(0.92)" in slider
assert 'sourceVersion = "0.13.52"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()

print("Build119 MDK Seek stabilization state machine materialized")
