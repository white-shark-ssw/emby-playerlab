import SwiftUI

struct PlayerAdjustmentRulerHUD: View {
    let adjustment: PlaybackVerticalAdjustment
    let value: Double

    private var clampedValue: Double { min(1, max(0, value)) }
    private var percent: Int { Int((clampedValue * 100).rounded()) }

    var body: some View {
        VStack {
            VStack(spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: adjustmentSymbol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .frame(width: 18)
                    Text(String(percent))
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.94))

                MovingAdjustmentRuler(percent: percent)
                    .frame(width: 92, height: 18)
            }
            .frame(width: 132, height: 58)
            .background(Color.black.opacity(0.74))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.32), radius: 7, x: 0, y: 3)
            .padding(.top, 18)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var adjustmentSymbol: String {
        switch adjustment {
        case .brightness:
            return "sun.max.fill"
        case .volume:
            switch percent {
            case 0: return "speaker.slash.fill"
            case 1...32: return "speaker.wave.1.fill"
            case 33...66: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        }
    }
}

private struct MovingAdjustmentRuler: View {
    let percent: Int

    private let tickWidth: CGFloat = 2
    private let tickSpacing: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            let pitch = tickWidth + tickSpacing
            let totalWidth = CGFloat(101) * tickWidth + CGFloat(100) * tickSpacing
            let currentCenter = CGFloat(min(100, max(0, percent))) * pitch + tickWidth / 2

            ZStack {
                HStack(alignment: .center, spacing: tickSpacing) {
                    ForEach(0...100, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(index % 5 == 0 ? 0.34 : 0.22))
                            .frame(width: tickWidth, height: index % 5 == 0 ? 13 : 8)
                    }
                }
                .frame(width: totalWidth, height: geometry.size.height, alignment: .leading)
                .offset(x: geometry.size.width / 2 - currentCenter)
                .animation(.linear(duration: 0.04), value: percent)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 2.6, height: 18)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}
