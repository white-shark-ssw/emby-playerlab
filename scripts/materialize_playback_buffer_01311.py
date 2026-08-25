from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"{label}: already materialized")
        return text
    if old not in text:
        raise SystemExit(f"{label}: anchor not found")
    return text.replace(old, new, 1)


player_engine = Path("Sources/Player/PlayerEngine.swift")
text = player_engine.read_text()
text = replace_once(
    text,
    '''struct PlaybackBufferState: Equatable {
    var livePlayableRanges: [ClosedRange<Double>] = []
    var verifiedHistoryRanges: [ClosedRange<Double>] = []
    var isBuffering = false
    var waitingReason: String?
}
''',
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
    "PlaybackBufferState",
)
player_engine.write_text(text)


controller = Path("Sources/Player/PlayerController.swift")
text = controller.read_text()
text = replace_once(
    text,
    '''    private var lastVerifiedMPVPosition: Double?
    private var stallWatchdogSuppressedUntil = Date.distantPast
''',
    '''    private var lastVerifiedMPVPosition: Double?
    private var timelineBufferedRange: ClosedRange<Double>?
    private var stallWatchdogSuppressedUntil = Date.distantPast
''',
    "PlayerController timeline state",
)
text = replace_once(
    text,
    '''        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        engineSwitchTask?.cancel()
''',
    '''        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        timelineBufferedRange = nil
        bufferState = PlaybackBufferState()
        engineSwitchTask?.cancel()
''',
    "PlayerController stop reset",
)
text = replace_once(
    text,
    '''        pendingSeekTarget = target
        pendingSeekDirection = offset >= 0 ? .forward : .backward
        displayedPosition = target
        suppressStallWatchdog(for: 3)
''',
    '''        pendingSeekTarget = target
        pendingSeekDirection = offset >= 0 ? .forward : .backward
        displayedPosition = target
        prepareTimelineBufferForSeek(target, reason: offset >= 0 ? "double-tap-forward" : "double-tap-backward")
        suppressStallWatchdog(for: 3)
''',
    "PlayerController button seek timeline handoff",
)
text = replace_once(
    text,
    '''    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        bufferState = PlaybackBufferState(livePlayableRanges: value.bufferedRanges, verifiedHistoryRanges: verifiedBufferedRanges, isBuffering: value.isBuffering, waitingReason: value.waitingReason)
    }
''',
    '''    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        updateTimelineBufferedRange(from: value)
        bufferState = PlaybackBufferState(
            livePlayableRanges: value.bufferedRanges,
            verifiedHistoryRanges: verifiedBufferedRanges,
            timelineBufferedEnd: timelineBufferedEnd(for: value.position),
            isBuffering: value.isBuffering,
            waitingReason: value.waitingReason
        )
    }

    private func prepareTimelineBufferForSeek(_ target: Double, reason: String) {
        let position = max(0, target)
        let previousEnd = bufferState.timelineBufferedEnd
        if let verified = verifiedRange(containing: position) {
            timelineBufferedRange = verified
        } else if let current = timelineBufferedRange,
                  position <= current.upperBound + 0.75,
                  position >= current.lowerBound - max(60, preferredForwardBuffer * 1.5) {
            timelineBufferedRange = min(current.lowerBound, position)...max(current.upperBound, position)
        } else {
            timelineBufferedRange = position...position
        }
        bufferState.timelineBufferedEnd = timelineBufferedEnd(for: position)
        if abs(previousEnd - bufferState.timelineBufferedEnd) > 0.05 {
            DiagnosticsLogger.shared.log("BufferTimelineUI", "seek-handoff reason=\\(reason) target=\\(String(format: \"%.3f\", position)) previousEnd=\\(String(format: \"%.3f\", previousEnd)) stableEnd=\\(String(format: \"%.3f\", bufferState.timelineBufferedEnd))")
        }
    }

    private func updateTimelineBufferedRange(from value: PlayerSnapshot) {
        let position = max(0, value.position)

        if let target = pendingSeekTarget {
            if let verified = verifiedRange(containing: target) {
                timelineBufferedRange = verified
                return
            }
            if let current = timelineBufferedRange,
               target <= current.upperBound + 0.75,
               target >= current.lowerBound - max(60, preferredForwardBuffer * 1.5) {
                return
            }
            if abs(position - target) <= 1.0, let live = liveRange(containing: position, in: value), live.upperBound > position + 0.25 {
                timelineBufferedRange = min(target, position)...max(target, live.upperBound)
            }
            return
        }

        if let verified = verifiedRange(containing: position) {
            if let current = timelineBufferedRange, rangesTouch(current, verified), rangeContains(current, position) || rangeContains(verified, position) {
                timelineBufferedRange = min(current.lowerBound, verified.lowerBound)...max(current.upperBound, verified.upperBound)
            } else {
                timelineBufferedRange = verified
            }
            return
        }

        if let live = liveRange(containing: position, in: value), live.upperBound > position + 0.25 {
            if let current = timelineBufferedRange, rangeContains(current, position) {
                timelineBufferedRange = min(current.lowerBound, position)...max(current.upperBound, live.upperBound)
            } else {
                timelineBufferedRange = position...live.upperBound
            }
            return
        }

        if let current = timelineBufferedRange, rangeContains(current, position) { return }
        timelineBufferedRange = position...position
    }

    private func timelineBufferedEnd(for position: Double) -> Double {
        let raw = max(max(0, position), timelineBufferedRange?.upperBound ?? max(0, position))
        let duration = effectiveDuration
        return duration > 0 ? min(duration, raw) : raw
    }

    private func verifiedRange(containing position: Double) -> ClosedRange<Double>? {
        verifiedBufferedRanges.first { rangeContains($0, position) }
    }

    private func liveRange(containing position: Double, in value: PlayerSnapshot) -> ClosedRange<Double>? {
        value.bufferedRanges.first { rangeContains($0, position) }
    }

    private func rangeContains(_ range: ClosedRange<Double>, _ position: Double, tolerance: Double = 0.75) -> Bool {
        range.lowerBound <= position + tolerance && range.upperBound >= position - tolerance
    }

    private func rangesTouch(_ lhs: ClosedRange<Double>, _ rhs: ClosedRange<Double>) -> Bool {
        lhs.lowerBound <= rhs.upperBound + 1.0 && rhs.lowerBound <= lhs.upperBound + 1.0
    }
''',
    "PlayerController stable timeline buffer",
)
text = replace_once(
    text,
    '''        let target = clampPosition(displayedPosition)
        pendingSeekTarget = target
        pendingSeekDirection = .absolute
        suppressStallWatchdog(for: 3)
''',
    '''        let target = clampPosition(displayedPosition)
        pendingSeekTarget = target
        pendingSeekDirection = .absolute
        prepareTimelineBufferForSeek(target, reason: "scrub")
        suppressStallWatchdog(for: 3)
''',
    "PlayerController scrub timeline handoff",
)
text = replace_once(
    text,
    '''        verifiedBufferedRanges = [fullRange]
        bufferState.verifiedHistoryRanges = verifiedBufferedRanges
        DiagnosticsLogger.shared.log("BufferHistory", "transport cache complete bytes=\\(metrics.cacheBytes)/\\(metrics.resourceBytes) action=promote-full-duration duration=\\(String(format: \"%.3f\", duration))")
''',
    '''        verifiedBufferedRanges = [fullRange]
        timelineBufferedRange = fullRange
        bufferState.verifiedHistoryRanges = verifiedBufferedRanges
        bufferState.timelineBufferedEnd = duration
        DiagnosticsLogger.shared.log("BufferHistory", "transport cache complete bytes=\\(metrics.cacheBytes)/\\(metrics.resourceBytes) action=promote-full-duration duration=\\(String(format: \"%.3f\", duration))")
''',
    "PlayerController full-cache timeline promotion",
)
text = replace_once(
    text,
    '''        DiagnosticsLogger.shared.log("BufferTimeline", "engine=\\(engineKind.title) position=\\(String(format: \"%.3f\", value.position)) forwardPlayable=\\(String(format: \"%.3f\", forward)) playableRanges=[\\(ranges)\\(suffix)] buffering=\\(value.isBuffering)")
''',
    '''        DiagnosticsLogger.shared.log("BufferTimeline", "engine=\\(engineKind.title) position=\\(String(format: \"%.3f\", value.position)) forwardPlayable=\\(String(format: \"%.3f\", forward)) timelineBufferedEnd=\\(String(format: \"%.3f\", bufferState.timelineBufferedEnd)) playableRanges=[\\(ranges)\\(suffix)] buffering=\\(value.isBuffering)")
''',
    "PlayerController buffer timeline diagnostics",
)
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
                Rectangle().fill(Color.white.opacity(0.68)).frame(width: bufferedWidth(totalWidth: width), height: trackHeight)
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

    private func bufferedWidth(totalWidth: CGFloat) -> CGFloat {
        totalWidth * fraction(for: max(value, bufferState.timelineBufferedEnd))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: value) }

    private func valueForLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let ratio = Double(min(max(x / max(totalWidth, 1), 0), 1))
        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio
    }
}
''')


project = Path("project.mdklab.yml")
text = project.read_text()
text = text.replace("# OnePlayer 0.13.10 restores the single-track playback timeline: played > live buffered > unbuffered.", "# OnePlayer 0.13.11 stabilizes the single-track playback timeline above instantaneous engine buffer re-anchoring.")
text = text.replace('MARKETING_VERSION: "0.13.10"', 'MARKETING_VERSION: "0.13.11"')
text = text.replace('CURRENT_PROJECT_VERSION: "77"', 'CURRENT_PROJECT_VERSION: "78"')
project.write_text(text)

print("OnePlayer 0.13.11 playback buffer stability materialized")
