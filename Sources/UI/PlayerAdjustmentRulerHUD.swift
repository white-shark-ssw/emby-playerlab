import QuartzCore
import SwiftUI
import UIKit

struct PlayerAdjustmentRulerHUD: View {
    let adjustment: PlaybackVerticalAdjustment
    let value: Double

    private var clampedValue: Double { min(1, max(0, value)) }
    private var percent: Int { Int((clampedValue * 100).rounded()) }

    var body: some View {
        VStack {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: adjustmentSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 17)
                    Text(String(percent))
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.94))

                PlayerMovingAdjustmentRuler(percent: percent)
                    .frame(width: 62, height: 10)
            }
            .frame(width: 112, height: 50)
            .background(Color.black.opacity(0.72))
            .clipShape(Capsule())
            .padding(.top, 16)

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

private struct PlayerMovingAdjustmentRuler: UIViewRepresentable {
    let percent: Int

    func makeUIView(context: Context) -> AdjustmentRulerUIView {
        let view = AdjustmentRulerUIView()
        view.setPercent(percent, animated: false)
        return view
    }

    func updateUIView(_ uiView: AdjustmentRulerUIView, context: Context) {
        uiView.setPercent(percent, animated: true)
    }
}

private final class AdjustmentRulerUIView: UIView {
    private var displayPercent: CGFloat = 0
    private var animationStartPercent: CGFloat = 0
    private var animationTargetPercent: CGFloat = 0
    private var animationStartTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?
    private var hasInitialValue = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    deinit { displayLink?.invalidate() }

    func setPercent(_ percent: Int, animated: Bool) {
        let target = CGFloat(min(100, max(0, percent)))
        guard hasInitialValue else {
            hasInitialValue = true
            displayPercent = target
            animationTargetPercent = target
            setNeedsDisplay()
            return
        }
        guard abs(target - animationTargetPercent) > 0.001 else { return }
        animationStartPercent = displayPercent
        animationTargetPercent = target
        animationStartTime = CACurrentMediaTime()
        guard animated else {
            stopDisplayLink()
            displayPercent = target
            setNeedsDisplay()
            return
        }
        startDisplayLink()
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0, let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(bounds)
        context.setLineCap(.round)

        let centerX = bounds.midX
        let baseline = bounds.maxY
        let pointsPerPercent: CGFloat = 5
        let halfWidth = max(bounds.width / 2, 1)

        for tickValue in stride(from: 0, through: 100, by: 2) {
            let x = centerX + (CGFloat(tickValue) - displayPercent) * pointsPerPercent
            guard x >= -2, x <= bounds.width + 2 else { continue }
            let major = tickValue % 10 == 0
            let height: CGFloat = major ? 10 : 5
            let distance = min(1, abs(x - centerX) / halfWidth)
            let alpha = 0.42 - 0.20 * distance
            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(2)
            context.move(to: CGPoint(x: x, y: baseline - height))
            context.addLine(to: CGPoint(x: x, y: baseline))
            context.strokePath()
        }

        context.setStrokeColor(UIColor(red: 0.95, green: 0.79, blue: 0.04, alpha: 1).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: centerX, y: baseline - 10))
        context.addLine(to: CGPoint(x: centerX, y: baseline))
        context.strokePath()
    }

    @objc private func updateAnimation(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(1, CGFloat(elapsed / 0.045))
        displayPercent = animationStartPercent + (animationTargetPercent - animationStartPercent) * progress
        setNeedsDisplay()
        if progress >= 1 { stopDisplayLink() }
    }

    private func startDisplayLink() {
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(updateAnimation(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayPercent = animationTargetPercent
        setNeedsDisplay()
    }
}
