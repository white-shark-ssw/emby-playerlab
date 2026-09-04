import SwiftUI
import Combine
import UIKit

final class V3HomeCarouselTransitionState: ObservableObject {
    @Published var fromID: String?
    @Published var toID: String?
    let progress = V3HomeCarouselProgressState()
    @Published var direction = 1
    var isDragging = false
    var tapSuppressedUntil = Date.distantPast
}

struct V3HomeCarouselTransitionScope<Content: View>: View {
    @ObservedObject var state: V3HomeCarouselTransitionState
    let content: () -> Content

    init(state: V3HomeCarouselTransitionState, @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.content = content
    }

    var body: some View { content() }
}

private enum V3HomeCarouselTouchAxis {
    case horizontal
    case vertical
}

private final class V3HomeCarouselInteractionRecognizer: UIGestureRecognizer {
    var shouldBeginHorizontal: ((CGSize) -> Bool)?
    var onHorizontalChanged: ((CGSize) -> Void)?
    var onHorizontalEnded: ((CGSize, CGFloat?) -> Void)?
    var onHorizontalCancelled: (() -> Void)?
    var onTap: (() -> Void)?

    private var trackedTouch: UITouch?
    private var origin: CGPoint?
    private var axis: V3HomeCarouselTouchAxis?
    private var latestPredictedTranslation: CGSize?
    private var horizontalAcquisitionTranslation: CGFloat?
    private var horizontalAcquisitionTouchTimestamp: TimeInterval?
    private var horizontalAcquisitionDirectionTranslation: CGFloat = 0
    private var pendingPostAcquisitionBaseline = false
    private var touchDownTimestamp: TimeInterval?
    private var latestMoveTranslationX: CGFloat?
    private var latestMoveTimestamp: TimeInterval?
    private var latestMoveDeliveredVelocityX: CGFloat?
    private var latestMoveCoalescedVelocityX: CGFloat?
    private var latestPredictionBaseTranslationX: CGFloat?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard origin == nil, touches.count == 1, let touch = touches.first, let view else {
            if axis == .horizontal, state == .began || state == .changed {
                onHorizontalCancelled?()
                state = .cancelled
            } else {
                state = .failed
            }
            return
        }
        trackedTouch = touch
        origin = touch.location(in: view)
        axis = nil
        latestPredictedTranslation = nil
        horizontalAcquisitionTranslation = nil
        horizontalAcquisitionTouchTimestamp = nil
        horizontalAcquisitionDirectionTranslation = 0
        pendingPostAcquisitionBaseline = false
        touchDownTimestamp = touch.timestamp
        latestMoveTranslationX = nil
        latestMoveTimestamp = nil
        latestMoveDeliveredVelocityX = nil
        latestMoveCoalescedVelocityX = nil
        latestPredictionBaseTranslationX = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, let view, let origin else { state = .failed; return }
        let location = touch.location(in: view)
        let translation = CGSize(width: location.x - origin.x, height: location.y - origin.y)

        if axis == nil {
            guard max(abs(translation.width), abs(translation.height)) >= 0.5 else { return }
            axis = abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical
            if axis == .vertical { state = .failed; return }
            guard shouldBeginHorizontal?(translation) == true else { state = .failed; return }
            let acquisitionTranslation = translation.width
            let acquisitionSample = acquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin, acquisitionTranslation: acquisitionTranslation)
            horizontalAcquisitionTranslation = acquisitionSample.baseline ?? acquisitionTranslation
            horizontalAcquisitionTouchTimestamp = touch.timestamp
            horizontalAcquisitionDirectionTranslation = acquisitionTranslation
            pendingPostAcquisitionBaseline = acquisitionSample.status == "none" && acquisitionSample.count == 1
            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)
            recordReleaseMotionSample(translationX: translation.width, touch: touch, event: event, view: view)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            latestPredictionBaseTranslationX = translation.width
            state = .began
            if acquisitionSample.baseline != nil {
                let renderedTranslation = renderTranslation(for: translation)
                V3HomeCarouselCadenceDiagnostics.shared.recordFirstRender(translation: renderedTranslation.width, totalTranslation: translation.width, touchTimestamp: touch.timestamp)
                onHorizontalChanged?(renderedTranslation)
            }
            return
        }

        guard axis == .horizontal, state == .began || state == .changed else { return }
        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
        recordReleaseMotionSample(translationX: translation.width, touch: touch, event: event, view: view)
        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
        latestPredictionBaseTranslationX = translation.width
        if pendingPostAcquisitionBaseline {
            let postAcquisitionSample = postAcquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin)
            if let baseline = postAcquisitionSample.baseline { horizontalAcquisitionTranslation = baseline }
            V3HomeCarouselCadenceDiagnostics.shared.recordPostAcquisitionSample(count: postAcquisitionSample.count, status: postAcquisitionSample.status, delta: postAcquisitionSample.delta, ageMS: postAcquisitionSample.ageMS)
            pendingPostAcquisitionBaseline = false
        }
        let renderedTranslation = renderTranslation(for: translation)
        V3HomeCarouselCadenceDiagnostics.shared.recordFirstRender(translation: renderedTranslation.width, totalTranslation: translation.width, touchTimestamp: touch.timestamp)
        state = .changed
        onHorizontalChanged?(renderedTranslation)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch, touches.contains(where: { $0 === touch }), let view, let origin else { return }
        let location = touch.location(in: view)
        let translation = CGSize(width: location.x - origin.x, height: location.y - origin.y)
        if axis == .horizontal, state == .began || state == .changed {
            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
            let endVelocityX = deliveredEndVelocityX(translationX: translation.width, touchTimestamp: touch.timestamp)
            logReleaseIntent(translation: translation, touch: touch, endVelocityX: endVelocityX)
            onHorizontalEnded?(translation, latestMoveDeliveredVelocityX)
            state = .ended
        } else if axis == nil {
            onTap?()
            state = .recognized
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if axis == .horizontal, state == .began || state == .changed {
            onHorizontalCancelled?()
            state = .cancelled
        } else {
            state = .failed
        }
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventedGestureRecognizer.view as? UIScrollView, preventedGestureRecognizer === scrollView.panGestureRecognizer { return true }
        return super.canPrevent(preventedGestureRecognizer)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventingGestureRecognizer.view as? UIScrollView, preventingGestureRecognizer === scrollView.panGestureRecognizer { return false }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        origin = nil
        axis = nil
        latestPredictedTranslation = nil
        horizontalAcquisitionTranslation = nil
        horizontalAcquisitionTouchTimestamp = nil
        horizontalAcquisitionDirectionTranslation = 0
        pendingPostAcquisitionBaseline = false
        touchDownTimestamp = nil
        latestMoveTranslationX = nil
        latestMoveTimestamp = nil
        latestMoveDeliveredVelocityX = nil
        latestMoveCoalescedVelocityX = nil
        latestPredictionBaseTranslationX = nil
    }

    private func recordReleaseMotionSample(translationX: CGFloat, touch: UITouch, event: UIEvent, view: UIView) {
        if let previousX = latestMoveTranslationX, let previousTimestamp = latestMoveTimestamp {
            let deltaTime = touch.timestamp - previousTimestamp
            if deltaTime > 0.000001 { latestMoveDeliveredVelocityX = (translationX - previousX) / deltaTime }
        }
        latestMoveCoalescedVelocityX = coalescedVelocityX(for: touch, event: event, view: view) ?? latestMoveCoalescedVelocityX
        latestMoveTranslationX = translationX
        latestMoveTimestamp = touch.timestamp
    }

    private func coalescedVelocityX(for touch: UITouch, event: UIEvent, view: UIView) -> CGFloat? {
        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }
        guard samples.count >= 2 else { return nil }
        let current = samples[samples.count - 1]
        guard let previous = samples[..<(samples.count - 1)].last(where: { current.timestamp - $0.timestamp > 0.000001 }) else { return nil }
        return (current.location(in: view).x - previous.location(in: view).x) / (current.timestamp - previous.timestamp)
    }

    private func deliveredEndVelocityX(translationX: CGFloat, touchTimestamp: TimeInterval) -> CGFloat? {
        guard let previousX = latestMoveTranslationX, let previousTimestamp = latestMoveTimestamp else { return nil }
        let deltaTime = touchTimestamp - previousTimestamp
        guard deltaTime > 0.000001 else { return nil }
        return (translationX - previousX) / deltaTime
    }

    private func logReleaseIntent(translation: CGSize, touch: UITouch, endVelocityX: CGFloat?) {
        let predictedX = latestPredictedTranslation?.width
        let predictionBaseX = latestPredictionBaseTranslationX
        let predictedExtraX: CGFloat? = if let predictedX, let predictionBaseX { predictedX - predictionBaseX } else { nil }
        let renderedX = renderTranslation(for: translation).width
        let durationMS = max(0, (touch.timestamp - (touchDownTimestamp ?? touch.timestamp)) * 1000)
        func value(_ value: CGFloat?) -> String { value.map { String(format: "%.2f", $0) } ?? "none" }
        DiagnosticsLogger.shared.app("HomeCarouselRelease", "actual_x=\(String(format: "%.2f", translation.width)) rendered_x=\(String(format: "%.2f", renderedX)) predicted_x=\(value(predictedX)) prediction_base_x=\(value(predictionBaseX)) predicted_extra_x=\(value(predictedExtraX)) last_move_delivered_velocity_x=\(value(latestMoveDeliveredVelocityX)) last_move_coalesced_velocity_x=\(value(latestMoveCoalescedVelocityX)) end_velocity_x=\(value(endVelocityX)) touch_duration_ms=\(String(format: "%.2f", durationMS))")
    }

    private func renderTranslation(for translation: CGSize) -> CGSize {
        guard let acquisitionTranslation = horizontalAcquisitionTranslation else { return translation }
        return CGSize(width: translation.width - acquisitionTranslation, height: 0)
    }

    private func acquisitionRenderBaselineSample(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint, acquisitionTranslation: CGFloat) -> (baseline: CGFloat?, count: Int, status: String, delta: CGFloat?, ageMS: Double?) {
        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }
        guard let predecessor = samples.last(where: { $0.timestamp < touch.timestamp - 0.000001 }) else { return (nil, samples.count, "none", nil, nil) }
        let predecessorTranslation = predecessor.location(in: view).x - origin.x
        let delta = acquisitionTranslation - predecessorTranslation
        let ageMS = max(0, (touch.timestamp - predecessor.timestamp) * 1000)
        guard delta != 0 else { return (nil, samples.count, "zero", delta, ageMS) }
        guard delta * acquisitionTranslation > 0 else { return (nil, samples.count, "direction", delta, ageMS) }
        return (predecessorTranslation, samples.count, "accepted", delta, ageMS)
    }

    private func postAcquisitionRenderBaselineSample(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint) -> (baseline: CGFloat?, count: Int, status: String, delta: CGFloat?, ageMS: Double?) {
        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }
        guard let acquisitionTimestamp = horizontalAcquisitionTouchTimestamp else { return (nil, samples.count, "missing-acquisition", nil, nil) }
        guard let predecessor = samples.last(where: { $0.timestamp > acquisitionTimestamp + 0.000001 && $0.timestamp < touch.timestamp - 0.000001 }) else { return (nil, samples.count, "none", nil, nil) }
        let predecessorTranslation = predecessor.location(in: view).x - origin.x
        let currentTranslation = touch.location(in: view).x - origin.x
        let delta = currentTranslation - predecessorTranslation
        let ageMS = max(0, (touch.timestamp - predecessor.timestamp) * 1000)
        guard delta != 0 else { return (nil, samples.count, "zero", delta, ageMS) }
        guard delta * horizontalAcquisitionDirectionTranslation > 0 else { return (nil, samples.count, "direction", delta, ageMS) }
        return (predecessorTranslation, samples.count, "accepted", delta, ageMS)
    }

    private func predictedTranslation(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint) -> CGSize? {
        guard let predicted = event.predictedTouches(for: touch)?.last else { return nil }
        let location = predicted.location(in: view)
        return CGSize(width: location.x - origin.x, height: location.y - origin.y)
    }
}

struct V3HomeCarouselInteractionSurface: UIViewRepresentable {
    let shouldBeginHorizontal: (CGSize) -> Bool
    let onHorizontalChanged: (CGSize) -> Void
    let onHorizontalEnded: (CGSize, CGFloat?) -> Void
    let onHorizontalCancelled: () -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldBeginHorizontal: shouldBeginHorizontal, onHorizontalChanged: onHorizontalChanged, onHorizontalEnded: onHorizontalEnded, onHorizontalCancelled: onHorizontalCancelled, onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let recognizer = V3HomeCarouselInteractionRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.shouldBeginHorizontal = { context.coordinator.shouldBeginHorizontal($0) }
        recognizer.onHorizontalChanged = { context.coordinator.onHorizontalChanged($0) }
        recognizer.onHorizontalEnded = { context.coordinator.onHorizontalEnded($0, $1) }
        recognizer.onHorizontalCancelled = { context.coordinator.onHorizontalCancelled() }
        recognizer.onTap = { context.coordinator.onTap() }
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.shouldBeginHorizontal = shouldBeginHorizontal
        context.coordinator.onHorizontalChanged = onHorizontalChanged
        context.coordinator.onHorizontalEnded = onHorizontalEnded
        context.coordinator.onHorizontalCancelled = onHorizontalCancelled
        context.coordinator.onTap = onTap
    }

    final class Coordinator {
        var shouldBeginHorizontal: (CGSize) -> Bool
        var onHorizontalChanged: (CGSize) -> Void
        var onHorizontalEnded: (CGSize, CGFloat?) -> Void
        var onHorizontalCancelled: () -> Void
        var onTap: () -> Void

        init(shouldBeginHorizontal: @escaping (CGSize) -> Bool, onHorizontalChanged: @escaping (CGSize) -> Void, onHorizontalEnded: @escaping (CGSize, CGFloat?) -> Void, onHorizontalCancelled: @escaping () -> Void, onTap: @escaping () -> Void) {
            self.shouldBeginHorizontal = shouldBeginHorizontal
            self.onHorizontalChanged = onHorizontalChanged
            self.onHorizontalEnded = onHorizontalEnded
            self.onHorizontalCancelled = onHorizontalCancelled
            self.onTap = onTap
        }
    }
}

extension V3EmbyHomeView {
    func shouldBeginNativeCarouselDrag(_ translation: CGSize) -> Bool {
        guard transitionToID == nil || isCarouselDragging else { return false }
        let direction = translation.width < 0 ? 1 : -1
        guard let currentID = currentCarouselItemID else { return false }
        return neighborCarouselItemID(from: currentID, direction: direction) != nil
    }

    func handleNativeCarouselDrag(_ translation: CGSize, width: CGFloat) {
        let horizontal = translation.width
        suppressCarouselTap()
        guard transitionToID == nil || isCarouselDragging else { return }
        if horizontal == 0 {
            if isCarouselDragging {
                transitionProgress = 0
                V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish(transitionProgress)
            }
            return
        }
        let direction = horizontal < 0 ? 1 : -1
        guard let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: direction) else { return }
        if !isCarouselDragging || transitionFromID != currentID || transitionToID != targetID {
            transitionFromID = currentID
            transitionToID = targetID
            transitionProgress = 0
            transitionDirection = direction
            isCarouselDragging = true
        }
        transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
        V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish(transitionProgress)
    }

    func finishNativeCarouselDrag(_ translation: CGSize, releaseVelocityX: CGFloat?, width: CGFloat) {
        suppressCarouselTap()
        let actualDistance = abs(translation.width)
        let releaseDirection = isCarouselDragging ? transitionDirection : (translation.width < 0 ? 1 : -1)
        let expectedSign: CGFloat = releaseDirection > 0 ? -1 : 1
        let actualProgress = min(1, max(0, actualDistance / max(1, width)))
        let releaseVelocity = releaseVelocityX ?? 0
        let directionalVelocity = releaseVelocity * expectedSign
        let velocityCommit = directionalVelocity >= 500
        let shouldCommit = actualProgress >= 0.28 || velocityCommit
        DiagnosticsLogger.shared.app("HomeCarouselReleaseDecision", "actual_progress=\(String(format: "%.3f", actualProgress)) release_velocity_x=\(String(format: "%.2f", releaseVelocity)) directional_velocity=\(String(format: "%.2f", directionalVelocity)) velocity_commit=\(velocityCommit) should_commit=\(shouldCommit)")
        if !isCarouselDragging {
            guard shouldCommit, let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: releaseDirection) else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-transition"); return }
            transitionFromID = currentID
            transitionToID = targetID
            transitionProgress = 0
            transitionDirection = releaseDirection
            completeInteractiveTransition(to: targetID)
            return
        }
        guard let targetID = transitionToID else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended-no-target"); return }
        isCarouselDragging = false
        if shouldCommit { completeInteractiveTransition(to: targetID) }
        else { cancelInteractiveTransition() }
    }

    func cancelNativeCarouselDrag() {
        guard isCarouselDragging else { V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-no-transition"); return }
        isCarouselDragging = false
        cancelInteractiveTransition()
    }
}
