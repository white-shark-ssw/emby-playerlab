import Combine
import QuartzCore
import SwiftUI
import UIKit

enum V3HomeFramePipelineProbeMode: String, CaseIterable {
    case carousel
    case coreAnimation
    case nativeDisplayLink
    case swiftUI

    var title: String {
        switch self {
        case .carousel: return "CAROUSEL"
        case .coreAnimation: return "CA"
        case .nativeDisplayLink: return "DISPLAYLINK"
        case .swiftUI: return "SWIFTUI"
        }
    }

    var detail: String {
        switch self {
        case .carousel: return "Build265 normal carousel"
        case .coreAnimation: return "Core Animation render-server motion"
        case .nativeDisplayLink: return "CADisplayLink → native CALayer"
        case .swiftUI: return "CADisplayLink → @Published → SwiftUI"
        }
    }

    var next: V3HomeFramePipelineProbeMode {
        let modes = Self.allCases
        guard let index = modes.firstIndex(of: self) else { return .carousel }
        return modes[(index + 1) % modes.count]
    }
}

struct V3HomeFramePipelineModeControl: View {
    @Binding var mode: V3HomeFramePipelineProbeMode

    var body: some View {
        Button {
            mode = mode.next
            DiagnosticsLogger.shared.playback("HomeCarouselPipelineProbe", "mode=\(mode.rawValue) maxFPS=\(UIScreen.main.maximumFramesPerSecond)")
        } label: {
            Text("PIPE \(mode.title)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color.black.opacity(0.72))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct V3HomeFramePipelineProbe: View {
    let mode: V3HomeFramePipelineProbeMode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch mode {
            case .carousel:
                EmptyView()
            case .coreAnimation, .nativeDisplayLink:
                V3HomeNativeFramePipelineProbe(mode: mode).ignoresSafeArea()
            case .swiftUI:
                V3HomeSwiftUIFramePipelineProbe().ignoresSafeArea()
            }

            VStack(spacing: 5) {
                Text("PIPELINE \(mode.title)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Text(mode.detail)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.72))
            }
            .foregroundColor(.white)
            .allowsHitTesting(false)
        }
        .onAppear { DiagnosticsLogger.shared.playback("HomeCarouselPipelineProbe", "probe appear mode=\(mode.rawValue) maxFPS=\(UIScreen.main.maximumFramesPerSecond)") }
    }
}

private struct V3HomeNativeFramePipelineProbe: UIViewRepresentable {
    let mode: V3HomeFramePipelineProbeMode

    func makeUIView(context: Context) -> V3HomeNativeFramePipelineView {
        let view = V3HomeNativeFramePipelineView()
        view.setMode(mode)
        return view
    }

    func updateUIView(_ uiView: V3HomeNativeFramePipelineView, context: Context) { uiView.setMode(mode) }
}

private final class V3HomeNativeFramePipelineView: UIView {
    private let markerLayer = CALayer()
    private var mode: V3HomeFramePipelineProbeMode = .coreAnimation
    private var displayLink: CADisplayLink?
    private var animationWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        markerLayer.backgroundColor = UIColor.white.cgColor
        markerLayer.cornerRadius = 12
        layer.addSublayer(markerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { displayLink?.invalidate() }

    func setMode(_ mode: V3HomeFramePipelineProbeMode) {
        guard self.mode != mode || displayLink == nil && markerLayer.animation(forKey: "pipeline-probe") == nil else { return }
        self.mode = mode
        applyMode()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopDisplayLink(); markerLayer.removeAllAnimations() }
        else { applyMode() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        markerLayer.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.position = CGPoint(x: 24, y: bounds.midY)
        CATransaction.commit()
        if mode == .coreAnimation, abs(animationWidth - bounds.width) > 0.5 { startCoreAnimation() }
    }

    private func applyMode() {
        stopDisplayLink()
        markerLayer.removeAllAnimations()
        guard window != nil else { return }
        switch mode {
        case .coreAnimation: startCoreAnimation()
        case .nativeDisplayLink: startDisplayLink()
        case .carousel, .swiftUI: break
        }
    }

    private func startCoreAnimation() {
        guard bounds.width > 60 else { return }
        animationWidth = bounds.width
        markerLayer.removeAllAnimations()
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = bounds.width - 48
        animation.duration = 0.72
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        markerLayer.add(animation, forKey: "pipeline-probe")
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        guard bounds.width > 60 else { return }
        let cycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        let phase = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
        let x = 24 + CGFloat(phase) * (bounds.width - 48)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.position = CGPoint(x: x, y: bounds.midY)
        CATransaction.commit()
    }
}

@MainActor
private final class V3HomeSwiftUIFrameProbeClock: NSObject, ObservableObject {
    @Published private(set) var phase: CGFloat = 0
    private var displayLink: CADisplayLink?

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        let cycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        let value = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
        phase = CGFloat(value)
    }
}

private struct V3HomeSwiftUIFramePipelineProbe: View {
    @StateObject private var clock = V3HomeSwiftUIFrameProbeClock()

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .position(x: 24 + clock.phase * max(0, geometry.size.width - 48), y: geometry.size.height / 2)
        }
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
    }
}
