import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Session-persistent ranges that a playback engine has actually verified as playable.
    let verifiedBufferedRanges: [ClosedRange<Double>]
    /// Current engine live buffer. This may move/shrink after a seek.
    let bufferedRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 7
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.13)).frame(height: trackHeight)

                ForEach(Array(normalizedVerifiedRanges.enumerated()), id: \.offset) { _, buffered in
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: max(2, segmentWidth(buffered, totalWidth: width)), height: trackHeight)
                        .offset(x: segmentOffset(buffered, totalWidth: width))
                }

                ForEach(Array(normalizedBufferedRanges.enumerated()), id: \.offset) { _, buffered in
                    Capsule()
                        .fill(Color.white.opacity(0.58))
                        .frame(width: max(2, segmentWidth(buffered, totalWidth: width)), height: 5)
                        .offset(x: segmentOffset(buffered, totalWidth: width))
                }

                Capsule().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: 4)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 1)
                    .offset(x: thumbOffset(totalWidth: width))
            }
            .frame(height: max(geometry.size.height, 24))
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

    private var normalizedVerifiedRanges: [ClosedRange<Double>] { normalized(verifiedBufferedRanges) }
    private var normalizedBufferedRanges: [ClosedRange<Double>] { normalized(bufferedRanges) }

    private func normalized(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        ranges.compactMap { item in
            let lower = max(range.lowerBound, min(range.upperBound, item.lowerBound))
            let upper = max(range.lowerBound, min(range.upperBound, item.upperBound))
            return upper > lower ? lower...upper : nil
        }
    }

    private var accessibilityValue: String {
        let duration = max(0, range.upperBound - range.lowerBound)
        guard duration > 0 else { return "0%" }
        return "\(Int(((value - range.lowerBound) / duration * 100).rounded()))%"
    }

    private func fraction(for value: Double) -> CGFloat {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / duration, 0), 1))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: value) }

    private func thumbOffset(totalWidth: CGFloat) -> CGFloat {
        let thumbWidth: CGFloat = 16
        return min(max(0, totalWidth * fraction(for: value) - thumbWidth / 2), max(0, totalWidth - thumbWidth))
    }

    private func segmentOffset(_ buffered: ClosedRange<Double>, totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: buffered.lowerBound) }

    private func segmentWidth(_ buffered: ClosedRange<Double>, totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth * (fraction(for: buffered.upperBound) - fraction(for: buffered.lowerBound)))
    }

    private func valueForLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let ratio = Double(min(max(x / max(totalWidth, 1), 0), 1))
        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio
    }
}
