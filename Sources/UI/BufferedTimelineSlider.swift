import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Playback-layer buffer semantics on the media TIME axis. These ranges come from
    /// the active engine and are never synthesized from file-size ratios.
    let bufferState: PlaybackBufferState
    /// UnifiedTransport cached BYTE ranges normalized to 0...1. They are rendered on
    /// a separate thin cache strip and are never interpreted as media-time ranges.
    let cacheByteRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    init(value: Binding<Double>, range: ClosedRange<Double>, bufferState: PlaybackBufferState, cacheByteRanges: [ClosedRange<Double>] = [], onEditingChanged: @escaping (Bool) -> Void) {
        self._value = value
        self.range = range
        self.bufferState = bufferState
        self.cacheByteRanges = cacheByteRanges
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 10
            let cacheTrackHeight: CGFloat = 3
            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                    ForEach(Array(normalizedRanges(bufferState.verifiedHistoryRanges).enumerated()), id: \.offset) { _, verified in
                        Capsule()
                            .fill(Color(white: 0.48))
                            .frame(width: max(2, width * CGFloat(verified.upperBound - verified.lowerBound)), height: trackHeight)
                            .offset(x: width * CGFloat(verified.lowerBound))
                    }

                    ForEach(Array(normalizedRanges(bufferState.livePlayableRanges).enumerated()), id: \.offset) { _, live in
                        Capsule()
                            .fill(Color(white: 0.68))
                            .frame(width: max(2, width * CGFloat(live.upperBound - live.lowerBound)), height: trackHeight)
                            .offset(x: width * CGFloat(live.lowerBound))
                    }

                    Capsule().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: 4)
                }
                .frame(height: trackHeight)

                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.12)).frame(height: cacheTrackHeight)
                    ForEach(Array(normalizedByteRanges(cacheByteRanges).enumerated()), id: \.offset) { _, cached in
                        Capsule()
                            .fill(Color(white: 0.42))
                            .frame(width: max(1, width * CGFloat(cached.upperBound - cached.lowerBound)), height: cacheTrackHeight)
                            .offset(x: width * CGFloat(cached.lowerBound))
                    }
                }
                .frame(height: cacheTrackHeight)
            }
            .frame(width: width, height: max(geometry.size.height, 24), alignment: .center)
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

    private func normalizedByteRanges(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        ranges.compactMap { item in
            let lower = min(1, max(0, item.lowerBound))
            let upper = min(1, max(0, item.upperBound))
            return upper > lower ? lower...upper : nil
        }
    }

    private var accessibilityValue: String {
        let duration = max(0, range.upperBound - range.lowerBound)
        guard duration > 0 else { return "0%" }
        let percent = Int(((value - range.lowerBound) / duration * 100).rounded())
        return bufferState.isBuffering ? "\(percent)%，正在缓冲" : "\(percent)%"
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
