import QuartzCore
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
    let frameLatched: Bool
    let shouldBeginHorizontal: (CGSize) -> Bool
    let onHorizontalChanged: (CGSize) -> Void
    let onHorizontalEnded: (CGSize, CGFloat?) -> Void
    let onHorizontalCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(frameLatched: frameLatched, shouldBeginHorizontal: shouldBeginHorizontal, onHorizontalChanged: onHorizontalChanged, onHorizontalEnded: onHorizontalEnded, onHorizontalCancelled: onHorizontalCancelled)
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
        context.coordinator.frameLatched = frameLatched
        context.coordinator.shouldBeginHorizontal = shouldBeginHorizontal
        context.coordinator.onHorizontalChanged = onHorizontalChanged
        context.coordinator.onHorizontalEnded = onHorizontalEnded
        context.coordinator.onHorizontalCancelled = onHorizontalCancelled
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopForRemoval()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var frameLatched: Bool
        var shouldBeginHorizontal: (CGSize) -> Bool
        var onHorizontalChanged: (CGSize) -> Void
        var onHorizontalEnded: (CGSize, CGFloat?) -> Void
        var onHorizontalCancelled: () -> Void
        private var baselineX: CGFloat = 0
        private var inputSampleCount = 0
        private var inputIntervalCount = 0
        private var inputTotalGapMS: Double = 0
        private var inputMaxGapMS: Double = 0
        private var inputLastTimestamp: CFTimeInterval?
        private var publishSampleCount = 0
        private var publishIntervalCount = 0
        private var publishTotalGapMS: Double = 0
        private var publishMaxGapMS: Double = 0
        private var publishLastTimestamp: CFTimeInterval?
        private var pendingTranslation: CGSize?
        private var pendingDirty = false
        private var displayLink: CADisplayLink?

        init(frameLatched: Bool, shouldBeginHorizontal: @escaping (CGSize) -> Bool, onHorizontalChanged: @escaping (CGSize) -> Void, onHorizontalEnded: @escaping (CGSize, CGFloat?) -> Void, onHorizontalCancelled: @escaping () -> Void) {
            self.frameLatched = frameLatched
            self.shouldBeginHorizontal = shouldBeginHorizontal
            self.onHorizontalChanged = onHorizontalChanged
            self.onHorizontalEnded = onHorizontalEnded
            self.onHorizontalCancelled = onHorizontalCancelled
        }

        deinit { displayLink?.invalidate() }

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
                startRefreshLink()
            case .changed:
                recordInputCadence()
                let rendered = CGSize(width: translationX - baselineX, height: 0)
                if frameLatched {
                    pendingTranslation = rendered
                    pendingDirty = true
                } else {
                    publish(rendered)
                }
            case .ended:
                recordInputCadence()
                let rendered = CGSize(width: translationX - baselineX, height: 0)
                if frameLatched {
                    pendingTranslation = rendered
                    pendingDirty = true
                    publishPendingIfNeeded()
                }
                onHorizontalEnded(rendered, recognizer.velocity(in: view).x)
                endCadence(reason: "ended")
                stopRefreshLink()
            case .cancelled, .failed:
                onHorizontalCancelled()
                endCadence(reason: "cancelled")
                stopRefreshLink()
            default:
                break
            }
        }

        func stopForRemoval() {
            if inputSampleCount > 0 { endCadence(reason: "removed") }
            stopRefreshLink()
        }

        private func beginCadence() {
            inputSampleCount = 0
            inputIntervalCount = 0
            inputTotalGapMS = 0
            inputMaxGapMS = 0
            inputLastTimestamp = nil
            publishSampleCount = 0
            publishIntervalCount = 0
            publishTotalGapMS = 0
            publishMaxGapMS = 0
            publishLastTimestamp = nil
            pendingTranslation = nil
            pendingDirty = false
            recordInputCadence()
        }

        private func recordInputCadence() {
            let now = CACurrentMediaTime()
            inputSampleCount += 1
            if let inputLastTimestamp {
                let gapMS = max(0, (now - inputLastTimestamp) * 1000)
                inputIntervalCount += 1
                inputTotalGapMS += gapMS
                inputMaxGapMS = max(inputMaxGapMS, gapMS)
            }
            inputLastTimestamp = now
        }

        private func publish(_ translation: CGSize) {
            let now = CACurrentMediaTime()
            publishSampleCount += 1
            if let publishLastTimestamp {
                let gapMS = max(0, (now - publishLastTimestamp) * 1000)
                publishIntervalCount += 1
                publishTotalGapMS += gapMS
                publishMaxGapMS = max(publishMaxGapMS, gapMS)
            }
            publishLastTimestamp = now
            onHorizontalChanged(translation)
        }

        private func publishPendingIfNeeded() {
            guard pendingDirty, let pendingTranslation else { return }
            self.pendingDirty = false
            publish(pendingTranslation)
        }

        private func startRefreshLink() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
            let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopRefreshLink() {
            displayLink?.invalidate()
            displayLink = nil
            pendingTranslation = nil
            pendingDirty = false
        }

        @objc private func displayLinkDidFire(_ link: CADisplayLink) {
            if frameLatched { publishPendingIfNeeded() }
        }

        private func endCadence(reason: String) {
            guard inputSampleCount > 0 else { return }
            let inputAverage = inputIntervalCount > 0 ? inputTotalGapMS / Double(inputIntervalCount) : 0
            let publishAverage = publishIntervalCount > 0 ? publishTotalGapMS / Double(publishIntervalCount) : 0
            let mode = frameLatched ? "latched" : "direct"
            DiagnosticsLogger.shared.app("HomeCarouselPanProbe", "mode=\(mode) reason=\(reason) input_samples=\(inputSampleCount) input_avg_gap_ms=\(String(format: "%.2f", inputAverage)) input_max_gap_ms=\(String(format: "%.2f", inputMaxGapMS)) publish_samples=\(publishSampleCount) publish_avg_gap_ms=\(String(format: "%.2f", publishAverage)) publish_max_gap_ms=\(String(format: "%.2f", publishMaxGapMS)) maxFPS=\(UIScreen.main.maximumFramesPerSecond)")
            inputSampleCount = 0
            inputIntervalCount = 0
            inputTotalGapMS = 0
            inputMaxGapMS = 0
            inputLastTimestamp = nil
            publishSampleCount = 0
            publishIntervalCount = 0
            publishTotalGapMS = 0
            publishMaxGapMS = 0
            publishLastTimestamp = nil
            pendingTranslation = nil
            pendingDirty = false
        }
    }
}
