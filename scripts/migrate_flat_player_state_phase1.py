from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing phase1 anchor in {path}: {old[:220]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"missing phase1 start in {path}: {start!r}")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"missing phase1 end in {path}: {end!r}")
    p.write_text(text[:i] + new + text[j:])


player_engine = "Sources/Player/PlayerEngine.swift"
mdk_engine = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
controller = "Sources/Player/PlayerController.swift"
slider = "Sources/UI/BufferedTimelineSlider.swift"

# Playback clock and rendered frame are different facts. Keep both in PlayerSnapshot.
replace_once(
    player_engine,
    "struct PlayerSnapshot: Equatable {\n    var position: Double = 0\n    var duration: Double = 0\n",
    "struct PlayerSnapshot: Equatable {\n    /// Engine playback clock. This is not proof that the frame is visible.\n    var position: Double = 0\n    /// Timestamp of the latest frame actually submitted to the renderer, when the engine can provide it.\n    var renderedPosition: Double? = nil\n    var duration: Double = 0\n",
)

# Build107 allowed overlapping native player.seek() calls. Restore strict native ownership:
# user intent stays latest-wins, but while one native seek owns the player only the last target is queued.
replace_once(
    mdk_engine,
    '''        let supersededNativeSeekID = activeNativeSeek?.id
        queuedLatestSeek = nil
        if let supersededNativeSeekID = supersededNativeSeekID {
            DiagnosticsLogger.shared.playback("MDKSeekPreempt", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) superseded=\\(supersededNativeSeekID) action=native-latest-wins")
        }
        dispatchNativeSeek(intent, player: player)
''',
    '''        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) active=\\(activeNativeSeek.id) replacedQueued=\\(replaced.map { String($0) } ?? \"none\") action=queue-latest-single-native")
            return
        }
        dispatchNativeSeek(intent, player: player)
''',
)

# Every MDK polling snapshot carries the renderer-backed visual position separately from player.position.
replace_once(
    mdk_engine,
    '''        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying && !confirmedEnd, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: confirmedEnd))
''',
    '''        onSnapshot?(PlayerSnapshot(position: position, renderedPosition: lastRenderedTimestamp, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying && !confirmedEnd, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: confirmedEnd))
''',
)

# Premature EOF during a native seek is a generation failure. Do not clear native ownership and
# continue in the same generation; quarantine the whole generation atomically.
replace_once(
    mdk_engine,
    '''        if confirmedEnd, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
            let recoveryTarget = latestDesiredTarget(fallback: position)
            activeNativeSeek = nil
            queuedLatestSeek = nil
            pendingSeekResume = nil
            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=in-place-reprepare-no-rebuild")
            recoverStall(position: recoveryTarget, duration: duration)
            return
        }
''',
    '''        if confirmedEnd, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
            let recoveryTarget = latestDesiredTarget(fallback: position)
            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=quarantine-generation")
            quarantineCurrentGeneration(reason: "premature-eof-during-seek", position: recoveryTarget, failedGeneration: generation, message: "MDK premature EOF during seek")
            return
        }
''',
)

# A fatal Seek recovery never pretends the native transaction finished. The only escape is whole-generation teardown.
replace_between(
    mdk_engine,
    "    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {\n",
    "    private func scheduleRateHealth(player: swift_mdk.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval) {\n",
    '''    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {
        guard playerGeneration == generation, player != nil else { return }
        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)
        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) generation=\\(playerGeneration) active=\\(activeNativeSeek?.id ?? -1) queued=\\(queuedLatestSeek?.id ?? -1) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=quarantine-generation sameProcessMDKRebuild=false")
        quarantineCurrentGeneration(reason: "seek-wedge-\\(reason)", position: recoveryTarget, failedGeneration: playerGeneration, message: "MDK session unsafe seek recovery")
    }

''',
)

# Controller presentation is based on the rendered frame for MDK. Playback/Emby/transport logic keeps using snapshot.position.
replace_once(
    controller,
    '''                } else if !self.userIsScrubbing, self.pendingSeekTarget == nil {
                    self.displayedPosition = value.position
                }
''',
    '''                } else if !self.userIsScrubbing, self.pendingSeekTarget == nil {
                    self.displayedPosition = self.presentationPosition(for: value)
                }
''',
)

replace_once(
    controller,
    '''        userIsScrubbing = true
        let start = snapshot.position
        screenScrubStartPosition = start
''',
    '''        userIsScrubbing = true
        let start = displayedPosition
        screenScrubStartPosition = start
''',
)

replace_once(
    controller,
    '''            self.pendingSeekTarget = nil
            self.pendingSeekDirection = nil
            self.displayedPosition = self.snapshot.position
            DiagnosticsLogger.shared.log("SeekAnchor", "timeout target=\\(expectedTarget) actual=\\(self.snapshot.position)")
''',
    '''            self.pendingSeekTarget = nil
            self.pendingSeekDirection = nil
            if let rendered = self.snapshot.renderedPosition { self.displayedPosition = rendered }
            DiagnosticsLogger.shared.log("SeekAnchor", "timeout target=\\(expectedTarget) clock=\\(self.snapshot.position) rendered=\\(self.snapshot.renderedPosition.map { String(format: \"%.3f\", $0) } ?? \"nil\") presentation=renderer-backed")
''',
)

replace_once(
    controller,
    '''    private var snapshotCanCompleteSeekAnchor: Bool {
''',
    '''    private func presentationPosition(for value: PlayerSnapshot) -> Double {
        #if MDK_LAB
        if engineKind == .ksAVIO, let rendered = value.renderedPosition { return rendered }
        #endif
        return value.position
    }

    private var snapshotCanCompleteSeekAnchor: Bool {
''',
)

# Keep one interactive timeline. Increase contrast inside that same 6pt capsule; never add another band.
replace_once(slider, ".fill(Color.white.opacity(0.32))", ".fill(Color.white.opacity(0.18))")
replace_once(slider, ".fill(Color.white.opacity(0.78))", ".fill(Color.white.opacity(0.92))")

pe = Path(player_engine).read_text()
me = Path(mdk_engine).read_text()
pc = Path(controller).read_text()
sl = Path(slider).read_text()

assert "var renderedPosition: Double? = nil" in pe
assert "renderedPosition: lastRenderedTimestamp" in me
assert "action=queue-latest-single-native" in me
assert "MDKSeekPreempt" not in me
assert "action=quarantine-generation" in me
assert "nativeUnresponsive" not in me
assert "presentationPosition(for: value)" in pc
assert "if let rendered = self.snapshot.renderedPosition" in pc
assert "return engineKind != .mpv && engineKind != .ksAVIO" in pc
assert "liveTrackHeight" not in sl
assert "Color.white.opacity(0.92)" in sl
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path("project.mdklab.yml").read_text()
print("flat player state phase1 migration applied")
