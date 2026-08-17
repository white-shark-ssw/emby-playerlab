import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Engine-reported playable TIME ranges. The slider is a time axis, so byte-space
    /// UnifiedTransport ranges must never be projected onto it by file-size ratio.
    let playableRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 10
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                ForEach(Array(normalizedPlayableRanges.enumerated()), id: \.offset) { _, cached in
                    Capsule()
                        .fill(Color(white: 0.48))
                        .frame(width: max(2, width * CGFloat(cached.upperBound - cached.lowerBound)), height: trackHeight)
                        .offset(x: width * CGFloat(cached.lowerBound))
                }

                Capsule().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: 4)
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

    private var normalizedPlayableRanges: [ClosedRange<Double>] {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return [] }
        return playableRanges.compactMap { item in
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
        return "\(Int(((value - range.lowerBound) / duration * 100).rounded()))%"
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
