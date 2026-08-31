import SwiftUI
import UIKit

final class V3HomeCarouselPanProbeRecognizer: UIPanGestureRecognizer {
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventedGestureRecognizer.view as? UIScrollView, preventedGestureRecognizer === scrollView.panGestureRecognizer { return true }
        return super.canPrevent(preventedGestureRecognizer)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventingGestureRecognizer.view as? UIScrollView, preventingGestureRecognizer === scrollView.panGestureRecognizer { return false }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }
}

struct V3HomeCarouselPanProbeSurface: UIViewRepresentable {
    let shouldBeginHorizontal: (CGSize) -> Bool
    let onHorizontalChanged: (CGSize) -> Void
    let onHorizontalEnded: (CGSize, CGFloat?) -> Void
    let onHorizontalCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldBeginHorizontal: shouldBeginHorizontal, onHorizontalChanged: onHorizontalChanged, onHorizontalEnded: onHorizontalEnded, onHorizontalCancelled: onHorizontalCancelled)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let recognizer = V3HomeCarouselPanProbeRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.shouldBeginHorizontal = shouldBeginHorizontal
        context.coordinator.onHorizontalChanged = onHorizontalChanged
        context.coordinator.onHorizontalEnded = onHorizontalEnded
        context.coordinator.onHorizontalCancelled = onHorizontalCancelled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var shouldBeginHorizontal: (CGSize) -> Bool
        var onHorizontalChanged: (CGSize) -> Void
        var onHorizontalEnded: (CGSize, CGFloat?) -> Void
        var onHorizontalCancelled: () -> Void
        private var baselineX: CGFloat = 0
        private var sampleCount = 0
        private var intervalCount = 0
        private var totalGapMS: Double = 0
        private var maxGapMS: Double = 0
        private var lastTimestamp: CFTimeInterval?

        init(shouldBeginHorizontal: @escaping (CGSize) -> Bool, onHorizontalChanged: @escaping (CGSize) -> Void, onHorizontalEnded: @escaping (CGSize, CGFloat?) -> Void, onHorizontalCancelled: @escaping () -> Void) {
            self.shouldBeginHorizontal = shouldBeginHorizontal
            self.onHorizontalChanged = onHorizontalChanged
            self.onHorizontalEnded = onHorizontalEnded
            self.onHorizontalCancelled = onHorizontalCancelled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer, let view = recognizer.view else { return false }
            let velocity = recognizer.velocity(in: view)
            let horizontal = abs(velocity.x)
            let vertical = abs(velocity.y)
            guard horizontal > 0, horizontal >= vertical * 1.15 else { return false }
            return shouldBeginHorizontal(CGSize(width: velocity.x, height: velocity.y))
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translationX = recognizer.translation(in: view).x
            switch recognizer.state {
            case .began:
                baselineX = translationX
                beginCadence()
            case .changed:
                recordCadence()
                onHorizontalChanged(CGSize(width: translationX - baselineX, height: 0))
            case .ended:
                recordCadence()
                let rendered = CGSize(width: translationX - baselineX, height: 0)
                onHorizontalEnded(rendered, recognizer.velocity(in: view).x)
                endCadence(reason: "ended")
            case .cancelled, .failed:
                onHorizontalCancelled()
                endCadence(reason: "cancelled")
            default:
                break
            }
        }

        private func beginCadence() {
            sampleCount = 0
            intervalCount = 0
            totalGapMS = 0
            maxGapMS = 0
            lastTimestamp = nil
            recordCadence()
        }

        private func recordCadence() {
            let now = CACurrentMediaTime()
            sampleCount += 1
            if let lastTimestamp {
                let gapMS = max(0, (now - lastTimestamp) * 1000)
                intervalCount += 1
                totalGapMS += gapMS
                maxGapMS = max(maxGapMS, gapMS)
            }
            lastTimestamp = now
        }

        private func endCadence(reason: String) {
            guard sampleCount > 0 else { return }
            let average = intervalCount > 0 ? totalGapMS / Double(intervalCount) : 0
            DiagnosticsLogger.shared.app("HomeCarouselPanProbe", "reason=\(reason) samples=\(sampleCount) avg_gap_ms=\(String(format: \"%.2f\", average)) max_gap_ms=\(String(format: \"%.2f\", maxGapMS)) maxFPS=\(UIScreen.main.maximumFramesPerSecond)")
            sampleCount = 0
            intervalCount = 0
            totalGapMS = 0
            maxGapMS = 0
            lastTimestamp = nil
        }
    }
}
