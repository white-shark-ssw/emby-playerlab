import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

enum PlaybackVerticalAdjustment {
    case brightness
    case volume
}

struct PlaybackGestureOverlay: UIViewRepresentable {
    let volumeHapticsEnabled: Bool
    let resetGeneration: Int
    let onSingleTap: () -> Void
    let onLeftDoubleTap: () -> Void
    let onCenterDoubleTap: () -> Void
    let onRightDoubleTap: () -> Void
    let onTemporaryRateBegan: () -> Void
    let onTemporaryRateEnded: () -> Void
    let onScreenScrubBegan: () -> Void
    let onScreenScrubChanged: (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void
    let onScreenScrubEnded: () -> Void
    let onScreenScrubCancelled: () -> Void
    let onAdjustmentBegan: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
    let onAdjustmentChanged: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
    let onAdjustmentEnded: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            volumeHapticsEnabled: volumeHapticsEnabled,
            resetGeneration: resetGeneration,
            onSingleTap: onSingleTap,
            onLeftDoubleTap: onLeftDoubleTap,
            onCenterDoubleTap: onCenterDoubleTap,
            onRightDoubleTap: onRightDoubleTap,
            onTemporaryRateBegan: onTemporaryRateBegan,
            onTemporaryRateEnded: onTemporaryRateEnded,
            onScreenScrubBegan: onScreenScrubBegan,
            onScreenScrubChanged: onScreenScrubChanged,
            onScreenScrubEnded: onScreenScrubEnded,
            onScreenScrubCancelled: onScreenScrubCancelled,
            onAdjustmentBegan: onAdjustmentBegan,
            onAdjustmentChanged: onAdjustmentChanged,
            onAdjustmentEnded: onAdjustmentEnded
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let volumeView = MPVolumeView(frame: CGRect(x: -10, y: -10, width: 1, height: 1))
        volumeView.showsRouteButton = false
        volumeView.showsVolumeSlider = true
        volumeView.alpha = 0.001
        view.addSubview(volumeView)
        context.coordinator.volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1
        singleTap.cancelsTouchesInView = false
        singleTap.delegate = context.coordinator
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)

        let directionalPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDirectionalPan(_:)))
        directionalPan.maximumNumberOfTouches = 1
        directionalPan.cancelsTouchesInView = false
        directionalPan.delegate = context.coordinator
        view.addGestureRecognizer(directionalPan)

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.42
        longPress.allowableMovement = 10
        longPress.numberOfTouchesRequired = 1
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        view.addGestureRecognizer(longPress)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.volumeHapticsEnabled = volumeHapticsEnabled
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onLeftDoubleTap = onLeftDoubleTap
        context.coordinator.onCenterDoubleTap = onCenterDoubleTap
        context.coordinator.onRightDoubleTap = onRightDoubleTap
        context.coordinator.onTemporaryRateBegan = onTemporaryRateBegan
        context.coordinator.onTemporaryRateEnded = onTemporaryRateEnded
        context.coordinator.onScreenScrubBegan = onScreenScrubBegan
        context.coordinator.onScreenScrubChanged = onScreenScrubChanged
        context.coordinator.onScreenScrubEnded = onScreenScrubEnded
        context.coordinator.onScreenScrubCancelled = onScreenScrubCancelled
        context.coordinator.onAdjustmentBegan = onAdjustmentBegan
        context.coordinator.onAdjustmentChanged = onAdjustmentChanged
        context.coordinator.onAdjustmentEnded = onAdjustmentEnded
        context.coordinator.applyResetGeneration(resetGeneration)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private enum GestureOwner {
            case verticalAdjustment
            case screenScrub
            case temporaryRate
        }

        var volumeHapticsEnabled: Bool
        var onSingleTap: () -> Void
        var onLeftDoubleTap: () -> Void
        var onCenterDoubleTap: () -> Void
        var onRightDoubleTap: () -> Void
        var onTemporaryRateBegan: () -> Void
        var onTemporaryRateEnded: () -> Void
        var onScreenScrubBegan: () -> Void
        var onScreenScrubChanged: (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void
        var onScreenScrubEnded: () -> Void
        var onScreenScrubCancelled: () -> Void
        var onAdjustmentBegan: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        var onAdjustmentChanged: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        var onAdjustmentEnded: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        weak var volumeSlider: UISlider?

        private var resetGeneration: Int
        private var gestureOwner: GestureOwner?
        private var activeAdjustment: PlaybackVerticalAdjustment?
        private var adjustmentStartValue: Double = 0
        private var lastVolumeTick = -1
        private let adjustmentStep = 0.01
        private let volumeTickHaptics = PlaybackVolumeTickHaptics()

        init(
            volumeHapticsEnabled: Bool,
            resetGeneration: Int,
            onSingleTap: @escaping () -> Void,
            onLeftDoubleTap: @escaping () -> Void,
            onCenterDoubleTap: @escaping () -> Void,
            onRightDoubleTap: @escaping () -> Void,
            onTemporaryRateBegan: @escaping () -> Void,
            onTemporaryRateEnded: @escaping () -> Void,
            onScreenScrubBegan: @escaping () -> Void,
            onScreenScrubChanged: @escaping (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void,
            onScreenScrubEnded: @escaping () -> Void,
            onScreenScrubCancelled: @escaping () -> Void,
            onAdjustmentBegan: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void,
            onAdjustmentChanged: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void,
            onAdjustmentEnded: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        ) {
            self.volumeHapticsEnabled = volumeHapticsEnabled
            self.resetGeneration = resetGeneration
            self.onSingleTap = onSingleTap
            self.onLeftDoubleTap = onLeftDoubleTap
            self.onCenterDoubleTap = onCenterDoubleTap
            self.onRightDoubleTap = onRightDoubleTap
            self.onTemporaryRateBegan = onTemporaryRateBegan
            self.onTemporaryRateEnded = onTemporaryRateEnded
            self.onScreenScrubBegan = onScreenScrubBegan
            self.onScreenScrubChanged = onScreenScrubChanged
            self.onScreenScrubEnded = onScreenScrubEnded
            self.onScreenScrubCancelled = onScreenScrubCancelled
            self.onAdjustmentBegan = onAdjustmentBegan
            self.onAdjustmentChanged = onAdjustmentChanged
            self.onAdjustmentEnded = onAdjustmentEnded
        }

        func applyResetGeneration(_ generation: Int) {
            guard generation != resetGeneration else { return }
            resetGeneration = generation
            resetActiveInteraction()
        }

        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, gestureOwner == nil else { return }
            onSingleTap()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, gestureOwner == nil, let view = recognizer.view else { return }
            let x = recognizer.location(in: view).x / max(view.bounds.width, 1)
            if x < 0.35 { onLeftDoubleTap() }
            else if x > 0.65 { onRightDoubleTap() }
            else { onCenterDoubleTap() }
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                guard gestureOwner == nil else { return }
                gestureOwner = .temporaryRate
                onTemporaryRateBegan()
            case .ended, .cancelled, .failed:
                guard gestureOwner == .temporaryRate else { return }
                onTemporaryRateEnded()
                gestureOwner = nil
            default:
                break
            }
        }

        @objc func handleDirectionalPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                guard gestureOwner == nil else { return }
                let velocity = recognizer.velocity(in: view)
                if abs(velocity.x) > 35, abs(velocity.x) > abs(velocity.y) * 1.15 {
                    gestureOwner = .screenScrub
                    onScreenScrubBegan()
                    return
                }

                guard abs(velocity.y) > 35, abs(velocity.y) > abs(velocity.x) * 1.15 else { return }
                let x = recognizer.location(in: view).x / max(view.bounds.width, 1)
                if x < 0.35 {
                    activeAdjustment = .brightness
                    adjustmentStartValue = quantized(Double(UIScreen.main.brightness))
                } else if x > 0.65 {
                    activeAdjustment = .volume
                    adjustmentStartValue = quantized(Double(AVAudioSession.sharedInstance().outputVolume))
                    lastVolumeTick = Int((adjustmentStartValue / adjustmentStep).rounded())
                    if volumeHapticsEnabled { volumeTickHaptics.prepare() }
                } else {
                    activeAdjustment = nil
                    return
                }
                gestureOwner = .verticalAdjustment
                if let activeAdjustment { onAdjustmentBegan(activeAdjustment, adjustmentStartValue) }

            case .changed:
                switch gestureOwner {
                case .screenScrub:
                    onScreenScrubChanged(recognizer.translation(in: view).x, max(view.bounds.width, 1))
                case .verticalAdjustment:
                    guard let activeAdjustment else { return }
                    let translation = recognizer.translation(in: view)
                    let span = max(view.bounds.height * 0.65, 220)
                    let rawValue = adjustmentStartValue - Double(translation.y / span)
                    let value = quantized(rawValue)
                    apply(activeAdjustment, value: value)
                    onAdjustmentChanged(activeAdjustment, value)
                default:
                    break
                }

            case .ended:
                switch gestureOwner {
                case .screenScrub: onScreenScrubEnded()
                case .verticalAdjustment: finishAdjustment()
                default: break
                }
                gestureOwner = nil

            case .cancelled, .failed:
                switch gestureOwner {
                case .screenScrub: onScreenScrubCancelled()
                case .verticalAdjustment: finishAdjustment()
                default: break
                }
                gestureOwner = nil

            default:
                break
            }
        }

        private func resetActiveInteraction() {
            switch gestureOwner {
            case .temporaryRate: onTemporaryRateEnded()
            case .screenScrub: onScreenScrubCancelled()
            case .verticalAdjustment: finishAdjustment()
            case .none: break
            }
            gestureOwner = nil
            activeAdjustment = nil
        }

        private func quantized(_ value: Double) -> Double {
            let clamped = min(1, max(0, value))
            return (clamped / adjustmentStep).rounded() * adjustmentStep
        }

        private func apply(_ adjustment: PlaybackVerticalAdjustment, value: Double) {
            switch adjustment {
            case .brightness:
                UIScreen.main.brightness = CGFloat(value)
            case .volume:
                volumeSlider?.setValue(Float(value), animated: false)
                volumeSlider?.sendActions(for: .valueChanged)
                guard volumeHapticsEnabled else { return }
                let tick = Int((value / adjustmentStep).rounded())
                if tick != lastVolumeTick {
                    lastVolumeTick = tick
                    volumeTickHaptics.play()
                }
            }
        }

        private func finishAdjustment() {
            guard let activeAdjustment else { return }
            let value: Double
            switch activeAdjustment {
            case .brightness: value = quantized(Double(UIScreen.main.brightness))
            case .volume: value = quantized(Double(AVAudioSession.sharedInstance().outputVolume))
            }
            onAdjustmentEnded(activeAdjustment, value)
            self.activeAdjustment = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureOwner == nil else { return false }
            if let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view {
                let velocity = pan.velocity(in: view)
                if abs(velocity.x) > 35, abs(velocity.x) > abs(velocity.y) * 1.15 { return true }
                guard abs(velocity.y) > 35, abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
                let x = pan.location(in: view).x / max(view.bounds.width, 1)
                return x < 0.35 || x > 0.65
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}
