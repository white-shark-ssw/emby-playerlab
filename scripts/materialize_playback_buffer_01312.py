from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"{label}: anchor not found")
    return text.replace(old, new, 1)


engine_text = Path("Sources/Player/PlayerEngine.swift").read_text()
controller_text = Path("Sources/Player/PlayerController.swift").read_text()
slider_text = Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
project_text = Path("project.mdklab.yml").read_text()
if (
    "Engine-confirmed instantaneous playable media-time ranges" in engine_text
    and "prepareTimelineBufferForSeek" not in controller_text
    and "bufferState.verifiedHistoryRanges" in slider_text
    and "bufferState.livePlayableRanges" in slider_text
    and "timelineBufferedEnd" not in slider_text
    and 'MARKETING_VERSION: "0.13.12"' in project_text
    and 'CURRENT_PROJECT_VERSION: "79"' in project_text
):
    print("OnePlayer 0.13.12 multi-range playback buffer already materialized")
    raise SystemExit(0)


player_engine = Path("Sources/Player/PlayerEngine.swift")
text = engine_text
text = replace_once(
    text,
    '''struct PlaybackBufferState: Equatable {
    /// Engine-internal instantaneous playable ranges. These may shrink/re-anchor during Seek
    /// and are intentionally not rendered directly by the normal playback timeline.
    var livePlayableRanges: [ClosedRange<Double>] = []
    /// Session-persistent verified media-time ranges retained for diagnostics and timeline facts.
    var verifiedHistoryRanges: [ClosedRange<Double>] = []
    /// Stable media-time buffer endpoint for the normal single-track player UI.
    /// Playback progress is always rendered above this layer.
    var timelineBufferedEnd: Double = 0
    var isBuffering = false
    var waitingReason: String?
}
''',
    '''struct PlaybackBufferState: Equatable {
    /// Engine-confirmed instantaneous playable media-time ranges.
    var livePlayableRanges: [ClosedRange<Double>] = []
    /// Session-persistent media-time ranges that were actually verified playable by the engine.
    /// These are historical playback facts, not a byte-to-time projection of the disk cache.
    var verifiedHistoryRanges: [ClosedRange<Double>] = []
    var isBuffering = false
    var waitingReason: String?
}
''',
    "PlaybackBufferState multi-range model",
)
player_engine.write_text(text)


controller = Path("Sources/Player/PlayerController.swift")
text = controller_text
text = text.replace('    private var timelineBufferedRange: ClosedRange<Double>?\n', '')
text = text.replace('        timelineBufferedRange = nil\n        bufferState = PlaybackBufferState()\n', '        bufferState = PlaybackBufferState()\n')
text = text.replace('        prepareTimelineBufferForSeek(target, reason: offset >= 0 ? "double-tap-forward" : "double-tap-backward")\n', '')
text = text.replace('        prepareTimelineBufferForSeek(target, reason: "scrub")\n', '')

start = text.find('    private func updatePlaybackBufferState(from value: PlayerSnapshot) {')
end = text.find('    private func updateVerifiedBufferedRanges(from value: PlayerSnapshot) {', start)
if start < 0 or end < 0:
    raise SystemExit("PlayerController buffer block anchors not found")
new_block = '''    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        bufferState = PlaybackBufferState(
            livePlayableRanges: value.bufferedRanges,
            verifiedHistoryRanges: verifiedBufferedRanges,
            isBuffering: value.isBuffering,
            waitingReason: value.waitingReason
        )
    }

'''
text = text[:start] + new_block + text[end:]
text = text.replace(' timelineBufferedEnd=\\(String(format: "%.3f", bufferState.timelineBufferedEnd))', '')
text = text.replace('        timelineBufferedRange = fullRange\n', '')
text = text.replace('        bufferState.timelineBufferedEnd = duration\n', '')
controller.write_text(text)


slider = Path("Sources/UI/BufferedTimelineSlider.swift")
slider.write_text('''import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let bufferState: PlaybackBufferState
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    init(value: Binding<Double>, range: ClosedRange<Double>, bufferState: PlaybackBufferState, cacheByteRanges: [ClosedRange<Double>] = [], onEditingChanged: @escaping (Bool) -> Void) {
        self._value = value
        self.range = range
        self.bufferState = bufferState
        self.onEditingChanged = onEditingChanged
        _ = cacheByteRanges
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 6
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.20)).frame(height: trackHeight)

                ForEach(Array(normalizedRanges(bufferState.verifiedHistoryRanges).enumerated()), id: \\.offset) { _, buffered in
                    Rectangle()
                        .fill(Color.white.opacity(0.38))
                        .frame(width: max(1, width * CGFloat(buffered.upperBound - buffered.lowerBound)), height: trackHeight)
                        .offset(x: width * CGFloat(buffered.lowerBound))
                }

                ForEach(Array(normalizedRanges(bufferState.livePlayableRanges).enumerated()), id: \\.offset) { _, buffered in
                    Rectangle()
                        .fill(Color.white.opacity(0.68))
                        .frame(width: max(1, width * CGFloat(buffered.upperBound - buffered.lowerBound)), height: trackHeight)
                        .offset(x: width * CGFloat(buffered.lowerBound))
                }

                Rectangle().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: trackHeight)
            }
            .frame(width: width, height: trackHeight)
            .clipShape(Capsule())
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

    private func normalizedRanges(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return [] }
        return ranges.compactMap { item in
            let clippedLower = max(range.lowerBound, item.lowerBound)
            let clippedUpper = min(range.upperBound, item.upperBound)
            guard clippedUpper > clippedLower else { return nil }
            let lower = min(1, max(0, (clippedLower - range.lowerBound) / duration))
            let upper = min(1, max(0, (clippedUpper - range.lowerBound) / duration))
            return upper > lower ? lower...upper : nil
        }
    }

    private var accessibilityValue: String {
        let duration = max(0, range.upperBound - range.lowerBound)
        guard duration > 0 else { return "0%" }
        let percent = Int(((value - range.lowerBound) / duration * 100).rounded())
        return bufferState.isBuffering ? "\\(percent)%，正在缓冲" : "\\(percent)%"
    }

    private func fraction(for value: Double) -> CGFloat {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / duration, 0), 1))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: value) }

    private func valueForLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let ratio = Double(min(max(x / max(totalWidth, 1), 0), 1))
        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio
    }
}
''')


project = Path("project.mdklab.yml")
text = project_text
text = text.replace("# OnePlayer 0.13.11 stabilizes the single-track playback timeline above instantaneous engine buffer re-anchoring.", "# OnePlayer 0.13.12 renders engine-live and session-verified media-time buffer ranges on one truthful timeline.")
text = text.replace('MARKETING_VERSION: "0.13.11"', 'MARKETING_VERSION: "0.13.12"')
text = text.replace('CURRENT_PROJECT_VERSION: "78"', 'CURRENT_PROJECT_VERSION: "79"')
project.write_text(text)

print("OnePlayer 0.13.12 multi-range playback buffer materialized")
