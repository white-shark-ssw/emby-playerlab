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

# Build118 identity. Build117 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.50"', 'sourceVersion = "0.13.51"')

# Build117 device logs proved the rendered frame timestamp is already the correct new-frame
# position, while lastNativePosition can still be one polling interval (and sometimes one full
# +/-10s step) behind. Returning that stale clock as SeekResult.actualPosition made the UI seek
# anchor jump backward before the next snapshot moved forward again. Use the verified rendered
# timestamp as the completion position instead; keep snapshot.position as the playback authority.
replace_once(
    engine_path,
    '        onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: playerPosition ?? pending.callbackPosition, bufferHit: callbackLatency < 150, completionLatencyMs: totalLatency, measurement: "MDK first rendered frame after latest seek callback"))\n',
    '        onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: renderResult, bufferHit: callbackLatency < 150, completionLatencyMs: totalLatency, measurement: "MDK first rendered frame after latest seek callback; actual=render-timestamp"))\n',
)

# Build105's 200ms temporary seek buffer is useful for stability, but Build117 logs show rapid
# +/-10s input commonly arrives every 100-150ms. Audio frames are decoded after each seek, yet
# another seek resets A/V output before a 200ms resume threshold can settle. Keep 200ms for
# absolute/accurate scrubs and lower only relative Fast seeks to 50ms. Normal playback still
# restores the existing 1000ms minimum once the seek transaction is finished.
replace_once(
    engine_path,
    '    private let seekBufferMinMs: Int64 = 200\n',
    '    private let seekBufferMinMs: Int64 = 200\n    private let relativeSeekBufferMinMs: Int64 = 50\n',
)
replace_once(
    engine_path,
    '''            player.setBufferRange(msMin: self.seekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)\n            DiagnosticsLogger.shared.playback("MDKSeekBuffer", "id=\\(dispatchedIntent.id) phase=low-latency minMs=\\(self.seekBufferMinMs) normalMinMs=\\(self.normalBufferMinMs)")\n''',
    '''            let activeSeekBufferMinMs: Int64\n            switch dispatchedIntent.direction {\n            case .forward, .backward: activeSeekBufferMinMs = self.relativeSeekBufferMinMs\n            case .absolute: activeSeekBufferMinMs = self.seekBufferMinMs\n            }\n            player.setBufferRange(msMin: activeSeekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)\n            DiagnosticsLogger.shared.playback("MDKSeekBuffer", "id=\\(dispatchedIntent.id) phase=low-latency minMs=\\(activeSeekBufferMinMs) relativeMinMs=\\(self.relativeSeekBufferMinMs) accurateMinMs=\\(self.seekBufferMinMs) normalMinMs=\\(self.normalBufferMinMs) direction=\\(String(describing: dispatchedIntent.direction))")\n''',
)

# Build117 used a linear 0.30 scale. That leaves only 9% of the original area, which matches the
# device impression of roughly 10%. sqrt(0.30) ~= 0.548, so 0.55 makes the visible HUD area about
# 30% of the original while remaining much less obstructive than the original full-size badge.
replace_once(
    screen_path,
    '                if let feedback = controller.seekFeedback { feedbackView(feedback).scaleEffect(0.30) }\n',
    '                if let feedback = controller.seekFeedback { feedbackView(feedback).scaleEffect(0.55) }\n',
)

# Replace the opaque black capsule with real SwiftUI material. Material is available on iOS 15,
# so this does not raise OnePlayer's deployment target.
replace_once(
    screen_path,
    '''            .padding(.horizontal, 24)\n            .padding(.vertical, 15)\n            .background(Color.black.opacity(0.62))\n            .foregroundColor(.white)\n            .clipShape(Capsule())\n''',
    '''            .padding(.horizontal, 24)\n            .padding(.vertical, 15)\n            .background(.ultraThinMaterial)\n            .foregroundColor(.white)\n            .clipShape(Capsule())\n''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
screen = Path(screen_path).read_text()
assert 'actualPosition: renderResult' in engine
assert 'actual=render-timestamp' in engine
assert 'actualPosition: playerPosition ?? pending.callbackPosition' not in engine
assert 'private let relativeSeekBufferMinMs: Int64 = 50' in engine
assert 'case .forward, .backward: activeSeekBufferMinMs = self.relativeSeekBufferMinMs' in engine
assert 'case .absolute: activeSeekBufferMinMs = self.seekBufferMinMs' in engine
assert 'relativeMinMs=\\(self.relativeSeekBufferMinMs)' in engine
assert 'guard activeNativeSeek == nil, pendingSeekResume == nil else { return }' in engine
assert 'let expectedLanding = pending.callbackPosition ?? pending.target' in engine
assert 'relative-fast-only' in engine
assert 'absolute-accurate' in engine
assert 'feedbackView(feedback).scaleEffect(0.55)' in screen
assert 'feedbackView(feedback).scaleEffect(0.30)' not in screen
assert '.background(.ultraThinMaterial)' in screen
assert 'sourceVersion = "0.13.51"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build118 seek render-position + relative audio resume + HUD material fix materialized")
