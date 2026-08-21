from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"
screen_path = "Sources/UI/PlayerScreen.swift"
slider_path = "Sources/UI/BufferedTimelineSlider.swift"
haptics_path = "Sources/UI/PlaybackVolumeTickHaptics.swift"

replace_once(identity_path, 'sourceVersion = "0.13.49"', 'sourceVersion = "0.13.50"')

replace_once(
    engine_path,
    '''        guard shouldPlay, preparedGeneration == currentGeneration, !lastNativeBuffering else { return }\n        let health = nativeRenderHealth()\n''',
    '''        guard shouldPlay, preparedGeneration == currentGeneration, !lastNativeBuffering else { return }\n        guard activeNativeSeek == nil, pendingSeekResume == nil else { return }\n        let health = nativeRenderHealth()\n''',
)

replace_once(
    screen_path,
    '                if let feedback = controller.seekFeedback { feedbackView(feedback) }\n',
    '                if let feedback = controller.seekFeedback { feedbackView(feedback).scaleEffect(0.30) }\n',
)

replace_once(
    slider_path,
    '''    /// Current UnifiedTransport playback-byte cache ranges normalized to the media file's 0...1 byte space.\n    /// These ranges are the only visible buffer source. They grow when bytes are downloaded and disappear\n    /// when RollingCache actually evicts those bytes.\n''',
    '''    /// Current UnifiedTransport playback-byte cache ranges normalized to the media file's 0...1 byte space.\n    /// Byte cache is a secondary visual layer. The engine-confirmed livePlayableRanges below\n    /// are the real media-time playable window.\n''',
)
replace_once(
    slider_path,
    '''                ForEach(Array(normalizedCacheRanges.enumerated()), id: \\.offset) { _, cached in\n                    Rectangle()\n                        .fill(Color.white.opacity(0.68))\n                        .frame(width: max(1, width * CGFloat(cached.upperBound - cached.lowerBound)), height: trackHeight)\n                        .offset(x: width * CGFloat(cached.lowerBound))\n                }\n\n                Rectangle().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: trackHeight)\n''',
    '''                ForEach(Array(normalizedCacheRanges.enumerated()), id: \\.offset) { _, cached in\n                    Rectangle()\n                        .fill(Color.white.opacity(0.32))\n                        .frame(width: max(1, width * CGFloat(cached.upperBound - cached.lowerBound)), height: trackHeight)\n                        .offset(x: width * CGFloat(cached.lowerBound))\n                }\n\n                ForEach(Array(normalizedLivePlayableRanges.enumerated()), id: \\.offset) { _, playable in\n                    Rectangle()\n                        .fill(Color.white.opacity(0.78))\n                        .frame(width: max(1, width * CGFloat(playable.upperBound - playable.lowerBound)), height: trackHeight)\n                        .offset(x: width * CGFloat(playable.lowerBound))\n                }\n\n                Rectangle().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: trackHeight)\n''',
)
replace_once(
    slider_path,
    '''    private var normalizedCacheRanges: [ClosedRange<Double>] {\n''',
    '''    private var normalizedLivePlayableRanges: [ClosedRange<Double>] {\n        let duration = range.upperBound - range.lowerBound\n        guard duration > 0 else { return [] }\n        return bufferState.livePlayableRanges.compactMap { item in\n            let lower = min(1, max(0, (item.lowerBound - range.lowerBound) / duration))\n            let upper = min(1, max(0, (item.upperBound - range.lowerBound) / duration))\n            return upper > lower ? lower...upper : nil\n        }\n    }\n\n    private var normalizedCacheRanges: [ClosedRange<Double>] {\n''',
)

# Build105 is the actual materialized baseline: intensity 0.3744 and 10ms duration.
# User requested 6ms duration and +10% intensity from the current build.
replace_once(haptics_path, '                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3744),\n', '                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.41184),\n')
replace_once(haptics_path, '                duration: 0.010\n', '                duration: 0.006\n')

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
screen = Path(screen_path).read_text()
slider = Path(slider_path).read_text()
haptics = Path(haptics_path).read_text()
assert 'guard activeNativeSeek == nil, pendingSeekResume == nil else { return }' in engine
assert 'let expectedLanding = pending.callbackPosition ?? pending.target' in engine
assert 'relative-fast-only' in engine
assert 'absolute-accurate' in engine
assert 'feedbackView(feedback).scaleEffect(0.30)' in screen
assert 'normalizedLivePlayableRanges' in slider
assert 'bufferState.livePlayableRanges.compactMap' in slider
assert 'Color.white.opacity(0.32)' in slider
assert 'Color.white.opacity(0.78)' in slider
assert '.hapticIntensity, value: 0.41184' in haptics
assert 'duration: 0.006' in haptics
assert 'sourceVersion = "0.13.50"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build117 seek watchdog arbitration + real buffer window + feedback UI materialized")
