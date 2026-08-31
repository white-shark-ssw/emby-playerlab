import Combine
import QuartzCore
import SwiftUI
import UIKit

enum V3HomeFramePipelineProbeMode: String, CaseIterable, Equatable {
    case carousel
    case carouselPan
    case carouselPanLatched
    case rawTouch
    case nativePan
    case nativeScroll
    case carouselTree
    case carouselHero
    case carouselBackdrop
    case coreAnimation
    case nativeDisplayLink
    case swiftUI

    var title: String {
        switch self {
        case .carousel: return "CAROUSEL"
        case .carouselPan: return "CAROUSEL PAN"
        case .carouselPanLatched: return "CAROUSEL PAN LATCH"
        case .rawTouch: return "TOUCH LAYER"
        case .nativePan: return "PAN LAYER"
        case .nativeScroll: return "SCROLLVIEW"
        case .carouselTree: return "TREE FULL"
        case .carouselHero: return "TREE HERO"
        case .carouselBackdrop: return "TREE BACKDROP"
        case .coreAnimation: return "CA"
        case .nativeDisplayLink: return "DISPLAYLINK"
        case .swiftUI: return "SWIFTUI"
        }
    }

    var detail: String {
        switch self {
        case .carousel: return "Build275 normal carousel owner"
        case .carouselPan: return "UIPanGestureRecognizer + max-refresh → real carousel"
        case .carouselPanLatched: return "same Pan → display-link latched real carousel"
        case .rawTouch: return "custom touchesMoved → native CALayer"
        case .nativePan: return "UIPanGestureRecognizer → native CALayer"
        case .nativeScroll: return "native horizontal UIScrollView"
        case .carouselTree: return "Full tree ← 120 Hz progress"
        case .carouselHero: return "Hero scope ← 120 Hz; backdrop frozen"
        case .carouselBackdrop: return "Backdrop scope ← 120 Hz; Hero frozen"
        case .coreAnimation: return "Core Animation render-server motion"
        case .nativeDisplayLink: return "CADisplayLink → native CALayer"
        case .swiftUI: return "CADisplayLink → @Published → SwiftUI"
        }
    }

    var usesHomePresentation: Bool {
        switch self {
        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop: return true
        case .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false
        }
    }

    var isCarouselTreeProbe: Bool {
        switch self {
        case .carouselTree, .carouselHero, .carouselBackdrop: return true
        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false
        }
    }

    var observesBackdropTransition: Bool {
        switch self {
        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselBackdrop: return true
        case .rawTouch, .nativePan, .nativeScroll, .carouselHero, .coreAnimation, .nativeDisplayLink, .swiftUI: return false
        }
    }

    var observesHeroTransition: Bool {
        switch self {
        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero: return true
        case .rawTouch, .nativePan, .nativeScroll, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI: return false
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
            case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop:
                EmptyView()
            case .rawTouch, .nativePan, .nativeScroll:
                ZStack {
                    V3HomeInputPipelineProbe(mode: mode).ignoresSafeArea()
                    V3HomeCarouselTreeProgressDriver { _ in }.frame(width: 0, height: 0)
                }
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

struct V3HomeCarouselTreeProgressDriver: UIViewRepresentable {
    let onProgress: (CGFloat) -> Void

    func makeUIView(context: Context) -> V3HomeCarouselTreeProgressView {
        let view = V3HomeCarouselTreeProgressView()
        view.onProgress = onProgress
        return view
    }

    func updateUIView(_ uiView: V3HomeCarouselTreeProgressView, context: Context) { uiView.onProgress = onProgress }
}

final class V3HomeCarouselTreeProgressView: UIView {
    var onProgress: ((CGFloat) -> Void)?
    private var displayLink: CADisplayLink?

    deinit { displayLink?.invalidate() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() }
        else { start() }
    }

    private func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        let cycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        let value = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
        onProgress?(CGFloat(value))
    }
}

private struct V3HomeInputPipelineProbe: UIViewRepresentable {
    let mode: V3HomeFramePipelineProbeMode

    func makeUIView(context: Context) -> V3HomeInputPipelineView {
        let view = V3HomeInputPipelineView()
        view.setMode(mode)
        return view
    }

    func updateUIView(_ uiView: V3HomeInputPipelineView, context: Context) { uiView.setMode(mode) }
}

private struct V3HomeInputCadenceAccumulator {
    var sampleCount = 0
    var intervalCount = 0
    var totalGapMS: Double = 0
    var maxGapMS: Double = 0
    var lastTimestamp: CFTimeInterval?

    mutating func reset() {
        sampleCount = 0
        intervalCount = 0
        totalGapMS = 0
        maxGapMS = 0
        lastTimestamp = nil
    }

    mutating func record(_ timestamp: CFTimeInterval) {
        sampleCount += 1
        if let lastTimestamp {
            let gapMS = max(0, (timestamp - lastTimestamp) * 1000)
            intervalCount += 1
            totalGapMS += gapMS
            maxGapMS = max(maxGapMS, gapMS)
        }
        lastTimestamp = timestamp
    }

    var averageGapMS: Double { intervalCount > 0 ? totalGapMS / Double(intervalCount) : 0 }
}

private final class V3HomeRawTouchRecognizer: UIGestureRecognizer {
    var onBegan: ((CGPoint, TimeInterval) -> Void)?
    var onMoved: ((CGPoint, TimeInterval) -> Void)?
    var onEnded: (() -> Void)?
    private weak var trackedTouch: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, let touch = touches.first, let view else { state = .failed; return }
        trackedTouch = touch
        onBegan?(touch.location(in: view), touch.timestamp)
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, let view, state == .began || state == .changed else { return }
        onMoved?(touch.location(in: view), touch.timestamp)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(where: { $0 === touch }) else { return }
        onEnded?()
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onEnded?()
        state = .cancelled
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
    }
}

private final class V3HomeInputPipelineView: UIView, UIScrollViewDelegate {
    private let markerLayer = CALayer()
    private let scrollView = UIScrollView()
    private let scrollContentView = UIView()
    private var scrollMarkers: [UIView] = []
    private var rawRecognizer: V3HomeRawTouchRecognizer?
    private var panRecognizer: UIPanGestureRecognizer?
    private var mode: V3HomeFramePipelineProbeMode = .rawTouch
    private var configuredMode: V3HomeFramePipelineProbeMode?
    private var cadence = V3HomeInputCadenceAccumulator()
    private var didPositionMarker = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        markerLayer.backgroundColor = UIColor.white.cgColor
        markerLayer.cornerRadius = 12
        layer.addSublayer(markerLayer)
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.delegate = self
        scrollView.addSubview(scrollContentView)
        addSubview(scrollView)
        for _ in 0..<9 {
            let marker = UIView()
            marker.backgroundColor = .white
            marker.layer.cornerRadius = 12
            scrollContentView.addSubview(marker)
            scrollMarkers.append(marker)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMode(_ mode: V3HomeFramePipelineProbeMode) {
        guard configuredMode != mode else { return }
        self.mode = mode
        configuredMode = mode
        configureMode()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        markerLayer.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
        if !didPositionMarker {
            markerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            didPositionMarker = true
        }
        scrollView.frame = bounds
        let contentWidth = max(bounds.width * 4, bounds.width + 1)
        scrollContentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
        scrollView.contentSize = scrollContentView.bounds.size
        let spacing = contentWidth / CGFloat(max(1, scrollMarkers.count))
        for (index, marker) in scrollMarkers.enumerated() {
            marker.frame = CGRect(x: spacing * (CGFloat(index) + 0.5) - 12, y: bounds.midY - 12, width: 24, height: 24)
        }
    }

    private func configureMode() {
        endInputCadence(reason: "mode-change")
        if let rawRecognizer { removeGestureRecognizer(rawRecognizer); self.rawRecognizer = nil }
        if let panRecognizer { removeGestureRecognizer(panRecognizer); self.panRecognizer = nil }
        scrollView.isHidden = true
        markerLayer.isHidden = false
        didPositionMarker = false

        switch mode {
        case .rawTouch:
            let recognizer = V3HomeRawTouchRecognizer()
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.onBegan = { [weak self] point, timestamp in self?.beginInputCadence(timestamp: timestamp); self?.moveMarker(to: point) }
            recognizer.onMoved = { [weak self] point, timestamp in self?.recordInputCadence(timestamp: timestamp); self?.moveMarker(to: point) }
            recognizer.onEnded = { [weak self] in self?.endInputCadence(reason: "raw-ended") }
            addGestureRecognizer(recognizer)
            rawRecognizer = recognizer
        case .nativePan:
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(panChanged(_:)))
            recognizer.maximumNumberOfTouches = 1
            addGestureRecognizer(recognizer)
            panRecognizer = recognizer
        case .nativeScroll:
            markerLayer.isHidden = true
            scrollView.isHidden = false
        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:
            break
        }
    }

    private func moveMarker(to point: CGPoint) {
        let x = min(max(12, point.x), max(12, bounds.width - 12))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.position = CGPoint(x: x, y: bounds.midY)
        CATransaction.commit()
    }

    private func beginInputCadence(timestamp: CFTimeInterval) {
        cadence.reset()
        cadence.record(timestamp)
    }

    private func recordInputCadence(timestamp: CFTimeInterval) {
        cadence.record(timestamp)
    }

    private func endInputCadence(reason: String) {
        guard cadence.sampleCount > 0 else { return }
        DiagnosticsLogger.shared.app("HomeCarouselInputProbe", "mode=\(mode.rawValue) reason=\(reason) samples=\(cadence.sampleCount) avg_gap_ms=\(String(format: "%.2f", cadence.averageGapMS)) max_gap_ms=\(String(format: "%.2f", cadence.maxGapMS)) maxFPS=\(UIScreen.main.maximumFramesPerSecond)")
        cadence.reset()
    }

    @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beginInputCadence(timestamp: CACurrentMediaTime())
            moveMarker(to: recognizer.location(in: self))
        case .changed:
            recordInputCadence(timestamp: CACurrentMediaTime())
            moveMarker(to: recognizer.location(in: self))
        case .ended:
            recordInputCadence(timestamp: CACurrentMediaTime())
            moveMarker(to: recognizer.location(in: self))
            endInputCadence(reason: "pan-ended")
        case .cancelled, .failed:
            endInputCadence(reason: "pan-cancelled")
        default:
            break
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        beginInputCadence(timestamp: CACurrentMediaTime())
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging || scrollView.isDecelerating, cadence.sampleCount > 0 else { return }
        recordInputCadence(timestamp: CACurrentMediaTime())
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endInputCadence(reason: "scroll-drag-ended") }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endInputCadence(reason: "scroll-deceleration-ended")
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
    private var configuredMode: V3HomeFramePipelineProbeMode?
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        markerLayer.backgroundColor = UIColor.white.cgColor
        markerLayer.cornerRadius = 12
        layer.addSublayer(markerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { stop() }

    override func layoutSubviews() {
        super.layoutSubviews()
        markerLayer.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
        if markerLayer.position == .zero { markerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY) }
        if mode == .coreAnimation, window != nil { startCoreAnimation() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() }
        else { configureMode() }
    }

    func setMode(_ mode: V3HomeFramePipelineProbeMode) {
        guard configuredMode != mode else { return }
        self.mode = mode
        configuredMode = mode
        if window != nil { configureMode() }
    }

    private func configureMode() {
        stop()
        switch mode {
        case .coreAnimation:
            startCoreAnimation()
        case .nativeDisplayLink:
            startDisplayLink()
        default:
            break
        }
    }

    private func startCoreAnimation() {
        guard bounds.width > 40 else { return }
        markerLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.position = CGPoint(x: 24, y: bounds.midY)
        CATransaction.commit()
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = 24
        animation.toValue = max(24, bounds.width - 24)
        animation.duration = 0.72
        animation.autoreverses = true
        animation.repeatCount = .infinity
        if #available(iOS 15.0, *) {
            let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        }
        markerLayer.add(animation, forKey: "probe-motion")
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stop() {
        markerLayer.removeAllAnimations()
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        let span = max(1, bounds.width - 48)
        let cycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        let position = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.position.x = 24 + span * CGFloat(position)
        CATransaction.commit()
    }
}

@MainActor
private final class V3HomeSwiftUIFrameProbeModel: ObservableObject {
    @Published var position: CGFloat = 0
    private var displayLink: CADisplayLink?

    deinit { displayLink?.invalidate() }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        let cycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        position = CGFloat(cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2)
    }
}

private struct V3HomeSwiftUIFramePipelineProbe: View {
    @StateObject private var model = V3HomeSwiftUIFrameProbeModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.black
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .offset(x: max(0, geometry.size.width - 24) * model.position)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
