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
    let onSingleTap: () -> Void
    let onLeftDoubleTap: () -> Void
    let onCenterDoubleTap: () -> Void
    let onRightDoubleTap: () -> Void
    let onTemporaryRateBegan: () -> Void
    let onTemporaryRateEnded: () -> Void
    let onAdjustmentBegan: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
    let onAdjustmentChanged: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
    let onAdjustmentEnded: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            volumeHapticsEnabled: volumeHapticsEnabled,
            onSingleTap: onSingleTap,
            onLeftDoubleTap: onLeftDoubleTap,
            onCenterDoubleTap: onCenterDoubleTap,
            onRightDoubleTap: onRightDoubleTap,
            onTemporaryRateBegan: onTemporaryRateBegan,
            onTemporaryRateEnded: onTemporaryRateEnded,
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

        let verticalPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleVerticalPan(_:)))
        verticalPan.maximumNumberOfTouches = 1
        verticalPan.cancelsTouchesInView = false
        verticalPan.delegate = context.coordinator
        view.addGestureRecognizer(verticalPan)

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
        context.coordinator.onAdjustmentBegan = onAdjustmentBegan
        context.coordinator.onAdjustmentChanged = onAdjustmentChanged
        context.coordinator.onAdjustmentEnded = onAdjustmentEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private enum GestureOwner {
            case verticalAdjustment
            case temporaryRate
        }

        var volumeHapticsEnabled: Bool
        var onSingleTap: () -> Void
        var onLeftDoubleTap: () -> Void
        var onCenterDoubleTap: () -> Void
        var onRightDoubleTap: () -> Void
        var onTemporaryRateBegan: () -> Void
        var onTemporaryRateEnded: () -> Void
        var onAdjustmentBegan: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        var onAdjustmentChanged: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        var onAdjustmentEnded: (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        weak var volumeSlider: UISlider?

        private var gestureOwner: GestureOwner?
        private var activeAdjustment: PlaybackVerticalAdjustment?
        private var adjustmentStartValue: Double = 0
        private var lastVolumeTick = -1
        private let adjustmentStep = 0.01
        private let hapticGenerator = UISelectionFeedbackGenerator()

        init(
            volumeHapticsEnabled: Bool,
            onSingleTap: @escaping () -> Void,
            onLeftDoubleTap: @escaping () -> Void,
            onCenterDoubleTap: @escaping () -> Void,
            onRightDoubleTap: @escaping () -> Void,
            onTemporaryRateBegan: @escaping () -> Void,
            onTemporaryRateEnded: @escaping () -> Void,
            onAdjustmentBegan: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void,
            onAdjustmentChanged: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void,
            onAdjustmentEnded: @escaping (_ adjustment: PlaybackVerticalAdjustment, _ value: Double) -> Void
        ) {
            self.volumeHapticsEnabled = volumeHapticsEnabled
            self.onSingleTap = onSingleTap
            self.onLeftDoubleTap = onLeftDoubleTap
            self.onCenterDoubleTap = onCenterDoubleTap
            self.onRightDoubleTap = onRightDoubleTap
            self.onTemporaryRateBegan = onTemporaryRateBegan
            self.onTemporaryRateEnded = onTemporaryRateEnded
            self.onAdjustmentBegan = onAdjustmentBegan
            self.onAdjustmentChanged = onAdjustmentChanged
            self.onAdjustmentEnded = onAdjustmentEnded
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

        @objc func handleVerticalPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                guard gestureOwner == nil else { return }
                let x = recognizer.location(in: view).x / max(view.bounds.width, 1)
                if x < 0.35 {
                    activeAdjustment = .brightness
                    adjustmentStartValue = quantized(Double(UIScreen.main.brightness))
                } else if x > 0.65 {
                    activeAdjustment = .volume
                    adjustmentStartValue = quantized(Double(AVAudioSession.sharedInstance().outputVolume))
                    lastVolumeTick = Int((adjustmentStartValue / adjustmentStep).rounded())
                    if volumeHapticsEnabled { hapticGenerator.prepare() }
                } else {
                    activeAdjustment = nil
                    return
                }
                gestureOwner = .verticalAdjustment
                if let activeAdjustment { onAdjustmentBegan(activeAdjustment, adjustmentStartValue) }
            case .changed:
                guard gestureOwner == .verticalAdjustment, let activeAdjustment else { return }
                let translation = recognizer.translation(in: view)
                let span = max(view.bounds.height * 0.65, 220)
                let rawValue = adjustmentStartValue - Double(translation.y / span)
                let value = quantized(rawValue)
                apply(activeAdjustment, value: value)
                onAdjustmentChanged(activeAdjustment, value)
            case .ended, .cancelled, .failed:
                guard gestureOwner == .verticalAdjustment else { return }
                finishAdjustment()
                gestureOwner = nil
            default:
                break
            }
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
                    hapticGenerator.selectionChanged()
                    hapticGenerator.prepare()
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
            if let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view {
                guard gestureOwner == nil else { return false }
                let velocity = pan.velocity(in: view)
                guard abs(velocity.y) > 35, abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
                let x = pan.location(in: view).x / max(view.bounds.width, 1)
                return x < 0.35 || x > 0.65
            }
            if gestureRecognizer is UILongPressGestureRecognizer { return gestureOwner == nil }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}
