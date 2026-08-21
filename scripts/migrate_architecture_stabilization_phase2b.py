from pathlib import Path
import runpy


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing phase2b anchor in {path}: {old[:240]!r}")
    p.write_text(text.replace(old, new, 1))


# Repair the one stale Phase2 migration anchor against the flattened Build120 source,
# then execute the existing migration. This driver is one-time scaffolding and is deleted
# after the resulting Swift source is committed.
phase2 = Path("scripts/migrate_flat_health_coordinator_phase2.py")
phase2_text = phase2.read_text()
old_stanza = """replace_once(
    engine_path,
    '''        pendingSeekResume = nil
        seekBufferingGraceStartedAt = nil
''',
    '''        healthCoordinator.completeSeek(generation: generation, seekID: pending.id)
        pendingSeekResume = nil
        seekBufferingGraceStartedAt = nil
''',
)
"""
new_stanza = """replace_once(
    engine_path,
    '''        pendingSeekResume = nil
    }

    private func applyHTTPHeaders(_ headers: [String: String], to player: swift_mdk.Player) {
''',
    '''        healthCoordinator.completeSeek(generation: generation, seekID: pending.id)
        pendingSeekResume = nil
    }

    private func applyHTTPHeaders(_ headers: [String: String], to player: swift_mdk.Player) {
''',
)
"""
if old_stanza not in phase2_text:
    raise SystemExit("missing stale phase2 rendered-frame anchor")
phase2.write_text(phase2_text.replace(old_stanza, new_stanza, 1))
runpy.run_path(str(phase2), run_name="__main__")

# Health policy: playing/Seek fallback is based on lack of relevant progress, never wall-clock alone.
health = Path("MDKLab/App/MDKPlaybackHealthCoordinator.swift")
health_text = health.read_text()
health_text = health_text.replace('            if wall >= 12 { return .fail(reason: "native-seek-absolute-limit") }\n', '')
health_text = health_text.replace('            if wall >= 10 { return .fail(reason: "seek-frame-absolute-limit") }\n', '')
health.write_text(health_text)

# Buffer-state ownership: an empty non-buffering MDK sample means the current measurement is temporarily
# unavailable, not necessarily that previously confirmed playable bytes vanished. Retain only the old
# window that still covers the current playback clock; never carry an old window across a Seek.
controller_path = "Sources/Player/PlayerController.swift"
replace_once(
    controller_path,
    '''    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        bufferState = PlaybackBufferState(
            livePlayableRanges: value.bufferedRanges,
            verifiedHistoryRanges: verifiedBufferedRanges,
            isBuffering: value.isBuffering,
            waitingReason: value.waitingReason
        )
    }
''',
    '''    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        let livePlayableRanges: [ClosedRange<Double>]
        if !value.bufferedRanges.isEmpty {
            livePlayableRanges = value.bufferedRanges
        } else if !value.isBuffering {
            livePlayableRanges = bufferState.livePlayableRanges.filter { $0.lowerBound <= value.position + 0.05 && $0.upperBound >= value.position - 0.05 }
        } else {
            livePlayableRanges = []
        }
        bufferState = PlaybackBufferState(
            livePlayableRanges: livePlayableRanges,
            verifiedHistoryRanges: verifiedBufferedRanges,
            isBuffering: value.isBuffering,
            waitingReason: value.waitingReason
        )
    }
''',
)

# One timeline control, two visible semantics only: confirmed playable window + played progress.
# Transport byte cache remains available in controller diagnostics but is intentionally not a timeline layer.
slider_path = "Sources/UI/BufferedTimelineSlider.swift"
slider = Path(slider_path).read_text()
slider = slider.replace('    /// Current UnifiedTransport playback-byte cache ranges normalized to the media file\'s 0...1 byte space.\n    /// Byte cache is a secondary visual layer. The engine-confirmed livePlayableRanges below\n    /// are the real media-time playable window.\n    let cacheByteRanges: [ClosedRange<Double>]\n', '')
slider = slider.replace('    init(value: Binding<Double>, range: ClosedRange<Double>, bufferState: PlaybackBufferState, cacheByteRanges: [ClosedRange<Double>] = [], onEditingChanged: @escaping (Bool) -> Void) {\n        self._value = value\n        self.range = range\n        self.bufferState = bufferState\n        self.cacheByteRanges = cacheByteRanges\n        self.onEditingChanged = onEditingChanged\n    }\n', '    init(value: Binding<Double>, range: ClosedRange<Double>, bufferState: PlaybackBufferState, onEditingChanged: @escaping (Bool) -> Void) {\n        self._value = value\n        self.range = range\n        self.bufferState = bufferState\n        self.onEditingChanged = onEditingChanged\n    }\n')
cache_block = '''                ForEach(Array(normalizedCacheRanges.enumerated()), id: \\.offset) { _, cached in
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: max(1, width * CGFloat(cached.upperBound - cached.lowerBound)), height: trackHeight)
                        .offset(x: width * CGFloat(cached.lowerBound))
                }

'''
if cache_block not in slider:
    raise SystemExit("missing cache timeline layer")
slider = slider.replace(cache_block, '', 1)
slider = slider.replace('.fill(Color.white.opacity(0.92))', '.fill(Color.white.opacity(0.48))')
slider = slider.replace('.frame(width: max(1, width * CGFloat(playable.upperBound - playable.lowerBound)), height: trackHeight)', '.frame(width: max(2, width * CGFloat(playable.upperBound - playable.lowerBound)), height: trackHeight)')
start = slider.find('    private var normalizedCacheRanges: [ClosedRange<Double>] {')
if start < 0:
    raise SystemExit("missing normalizedCacheRanges")
end = slider.find('    private var accessibilityValue: String {', start)
if end < 0:
    raise SystemExit("missing accessibilityValue after normalizedCacheRanges")
slider = slider[:start] + slider[end:]
Path(slider_path).write_text(slider)

screen_path = "Sources/UI/PlayerScreen.swift"
replace_once(screen_path, '                    bufferState: controller.bufferState,\n                    cacheByteRanges: controller.transportCacheRanges,\n', '                    bufferState: controller.bufferState,\n')

engine_text = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift").read_text()
controller_text = Path(controller_path).read_text()
slider_text = Path(slider_path).read_text()
screen_text = Path(screen_path).read_text()
health_text = health.read_text()

assert "private let healthCoordinator = MDKPlaybackHealthCoordinator()" in engine_text
assert "authority=health-coordinator" in engine_text
assert engine_text.count("quarantineCurrentGeneration(") == 2
assert "MDKSeekPreempt" not in engine_text
assert "native-seek-absolute-limit" not in health_text
assert "seek-frame-absolute-limit" not in health_text
assert "cacheByteRanges" not in slider_text
assert "normalizedCacheRanges" not in slider_text
assert "Color.white.opacity(0.48)" in slider_text
assert "cacheByteRanges: controller.transportCacheRanges" not in screen_text
assert "livePlayableRanges = bufferState.livePlayableRanges.filter" in controller_text
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path("project.mdklab.yml").read_text()
print("architecture stabilization phase2b applied")
