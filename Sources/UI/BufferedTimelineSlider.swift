import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Exact UnifiedTransport playback-byte cache coverage normalized to 0...1.
    /// Sparse seeks remain sparse here: a hole is rendered as a hole instead of being
    /// disguised by aggregate cacheBytes/resourceBytes.
    let downloadCacheRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 10
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                ForEach(Array(normalizedDownloadRanges.enumerated()), id: \.offset) { _, cached in
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

    private var normalizedDownloadRanges: [ClosedRange<Double>] {
        downloadCacheRanges.compactMap { item in
            let lower = min(1, max(0, item.lowerBound))
            let upper = min(1, max(0, item.upperBound))
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
