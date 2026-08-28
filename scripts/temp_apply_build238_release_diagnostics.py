from pathlib import Path

# App identity.
p = Path('Sources/Core/AppIdentity.swift')
text = p.read_text()
if text.count('0.14.70') != 2: raise SystemExit('unexpected AppIdentity 0.14.70 count')
text = text.replace('0.14.70', '0.14.71')
p.write_text(text)

# Release-intent diagnostics only. Build237 release behavior must remain unchanged.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
text = p.read_text()
old = '''    private var pendingPostAcquisitionBaseline = false
    private var touchDownTimestamp: TimeInterval?
'''
new = '''    private var pendingPostAcquisitionBaseline = false
    private var touchDownTimestamp: TimeInterval?
    private var latestMoveTranslationX: CGFloat?
    private var latestMoveTimestamp: TimeInterval?
    private var latestMoveDeliveredVelocityX: CGFloat?
    private var latestMoveCoalescedVelocityX: CGFloat?
    private var latestPredictionBaseTranslationX: CGFloat?
'''
if text.count(old) != 1: raise SystemExit('state anchor mismatch')
text = text.replace(old, new, 1)

old = '''        pendingPostAcquisitionBaseline = false
        touchDownTimestamp = touch.timestamp
'''
new = '''        pendingPostAcquisitionBaseline = false
        touchDownTimestamp = touch.timestamp
        latestMoveTranslationX = nil
        latestMoveTimestamp = nil
        latestMoveDeliveredVelocityX = nil
        latestMoveCoalescedVelocityX = nil
        latestPredictionBaseTranslationX = nil
'''
if text.count(old) != 1: raise SystemExit('began reset anchor mismatch')
text = text.replace(old, new, 1)

old = '''            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            state = .began
'''
new = '''            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)
            recordReleaseMotionSample(translationX: translation.width, touch: touch, event: event, view: view)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            latestPredictionBaseTranslationX = translation.width
            state = .began
'''
if text.count(old) != 1: raise SystemExit('acquisition prediction anchor mismatch')
text = text.replace(old, new, 1)

old = '''        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
        if pendingPostAcquisitionBaseline {
'''
new = '''        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
        recordReleaseMotionSample(translationX: translation.width, touch: touch, event: event, view: view)
        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
        latestPredictionBaseTranslationX = translation.width
        if pendingPostAcquisitionBaseline {
'''
if text.count(old) != 1: raise SystemExit('move prediction anchor mismatch')
text = text.replace(old, new, 1)

old = '''        if axis == .horizontal, state == .began || state == .changed {
            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
            onHorizontalEnded?(translation, latestPredictedTranslation)
            state = .ended
'''
new = '''        if axis == .horizontal, state == .began || state == .changed {
            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
            let endVelocityX = deliveredEndVelocityX(translationX: translation.width, touchTimestamp: touch.timestamp)
            logReleaseIntent(translation: translation, touch: touch, endVelocityX: endVelocityX)
            onHorizontalEnded?(translation, latestPredictedTranslation)
            state = .ended
'''
if text.count(old) != 1: raise SystemExit('touch end anchor mismatch')
text = text.replace(old, new, 1)

old = '''        pendingPostAcquisitionBaseline = false
        touchDownTimestamp = nil
    }

    private func renderTranslation(for translation: CGSize) -> CGSize {
'''
new = '''        pendingPostAcquisitionBaseline = false
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
        DiagnosticsLogger.shared.app("HomeCarouselRelease", "actual_x=\(String(format: \"%.2f\", translation.width)) rendered_x=\(String(format: \"%.2f\", renderedX)) predicted_x=\(value(predictedX)) prediction_base_x=\(value(predictionBaseX)) predicted_extra_x=\(value(predictedExtraX)) last_move_delivered_velocity_x=\(value(latestMoveDeliveredVelocityX)) last_move_coalesced_velocity_x=\(value(latestMoveCoalescedVelocityX)) end_velocity_x=\(value(endVelocityX)) touch_duration_ms=\(String(format: \"%.2f\", durationMS))")
    }

    private func renderTranslation(for translation: CGSize) -> CGSize {
'''
if text.count(old) != 1: raise SystemExit('helper insertion anchor mismatch')
text = text.replace(old, new, 1)
p.write_text(text)

Path('docs/changelog/CHANGELOG_v0_14_71_build238.md').write_text('''# OnePlayer 0.14.71 / Build238\n\n- Measurement-only carousel release-intent diagnostics on top of Build237.\n- Logs actual/end translation, latest predicted endpoint, predicted extra travel, last-move delivered/coalesced real-touch velocity, terminal delivered velocity and touch duration.\n- Retains Build237 white-flash correction and its existing 0.24×width predicted-total-distance release gate unchanged so the log can measure why that distance-based approach still feels too resistant.\n- Retains Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail.\n- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.\n''')
