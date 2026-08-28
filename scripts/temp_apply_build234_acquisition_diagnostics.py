from pathlib import Path

# App identity
p = Path('Sources/Core/AppIdentity.swift')
text = p.read_text()
text = text.replace('static let sourceVersion = "0.14.66"', 'static let sourceVersion = "0.14.67"')
text = text.replace('as? String ?? "0.14.66"', 'as? String ?? "0.14.67"')
p.write_text(text)

# Interaction: preserve Build233 behavior, expose acquisition coalesced decision facts.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
text = p.read_text()
old = '''            let acquisitionTranslation = translation.width
            let coalescedBaselineTranslation = acquisitionRenderBaselineTranslation(for: touch, event: event, view: view, origin: origin, acquisitionTranslation: acquisitionTranslation)
            horizontalAcquisitionTranslation = coalescedBaselineTranslation ?? acquisitionTranslation
            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, touch: touch, event: event)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            state = .began
            if coalescedBaselineTranslation != nil {
                let renderedTranslation = renderTranslation(for: translation)
                V3HomeCarouselCadenceDiagnostics.shared.recordFirstRender(translation: renderedTranslation.width, totalTranslation: translation.width, touchTimestamp: touch.timestamp)
                onHorizontalChanged?(renderedTranslation)
            }
'''
new = '''            let acquisitionTranslation = translation.width
            let acquisitionSample = acquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin, acquisitionTranslation: acquisitionTranslation)
            horizontalAcquisitionTranslation = acquisitionSample.baseline ?? acquisitionTranslation
            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            state = .began
            if acquisitionSample.baseline != nil {
                let renderedTranslation = renderTranslation(for: translation)
                V3HomeCarouselCadenceDiagnostics.shared.recordFirstRender(translation: renderedTranslation.width, totalTranslation: translation.width, touchTimestamp: touch.timestamp)
                onHorizontalChanged?(renderedTranslation)
            }
'''
if old not in text: raise SystemExit('Build233 acquisition block not found')
text = text.replace(old, new, 1)
old = '''    private func acquisitionRenderBaselineTranslation(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint, acquisitionTranslation: CGFloat) -> CGFloat? {
        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }
        guard let predecessor = samples.last(where: { $0.timestamp < touch.timestamp - 0.000001 }) else { return nil }
        let predecessorTranslation = predecessor.location(in: view).x - origin.x
        let delta = acquisitionTranslation - predecessorTranslation
        guard delta != 0, delta * acquisitionTranslation > 0 else { return nil }
        return predecessorTranslation
    }
'''
new = '''    private func acquisitionRenderBaselineSample(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint, acquisitionTranslation: CGFloat) -> (baseline: CGFloat?, count: Int, status: String, delta: CGFloat?, ageMS: Double?) {
        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }
        guard let predecessor = samples.last(where: { $0.timestamp < touch.timestamp - 0.000001 }) else { return (nil, samples.count, "none", nil, nil) }
        let predecessorTranslation = predecessor.location(in: view).x - origin.x
        let delta = acquisitionTranslation - predecessorTranslation
        let ageMS = max(0, (touch.timestamp - predecessor.timestamp) * 1000)
        guard delta != 0 else { return (nil, samples.count, "zero", delta, ageMS) }
        guard delta * acquisitionTranslation > 0 else { return (nil, samples.count, "direction", delta, ageMS) }
        return (predecessorTranslation, samples.count, "accepted", delta, ageMS)
    }
'''
if old not in text: raise SystemExit('Build233 acquisition helper not found')
text = text.replace(old, new, 1)
p.write_text(text)

# Cadence diagnostics: add acquisition-local decision fields only.
p = Path('Sources/UI/EmbyHomeCarouselCadenceDiagnosticsV3.swift')
text = p.read_text()
old = '''    private var acquisitionTouchTimestamp: TimeInterval = 0
    private var firstRenderTranslation: CGFloat?
'''
new = '''    private var acquisitionTouchTimestamp: TimeInterval = 0
    private var acquisitionCoalescedCount = 0
    private var acquisitionPredecessorStatus = "unknown"
    private var acquisitionPredecessorDelta: CGFloat?
    private var acquisitionPredecessorAgeMS: Double?
    private var firstRenderTranslation: CGFloat?
'''
if old not in text: raise SystemExit('cadence field anchor not found')
text = text.replace(old, new, 1)
old = '''    func begin(acquisitionTranslation: CGFloat, touchDownTimestamp: TimeInterval, touch: UITouch, event: UIEvent) {
'''
new = '''    func begin(acquisitionTranslation: CGFloat, touchDownTimestamp: TimeInterval, acquisitionCoalescedCount: Int, acquisitionPredecessorStatus: String, acquisitionPredecessorDelta: CGFloat?, acquisitionPredecessorAgeMS: Double?, touch: UITouch, event: UIEvent) {
'''
if old not in text: raise SystemExit('cadence begin signature not found')
text = text.replace(old, new, 1)
old = '''        self.acquisitionTranslation = acquisitionTranslation
        acquisitionTouchTimestamp = touch.timestamp
        touchDownToAcquisitionMS = max(0, (touch.timestamp - touchDownTimestamp) * 1000)
'''
new = '''        self.acquisitionTranslation = acquisitionTranslation
        acquisitionTouchTimestamp = touch.timestamp
        self.acquisitionCoalescedCount = acquisitionCoalescedCount
        self.acquisitionPredecessorStatus = acquisitionPredecessorStatus
        self.acquisitionPredecessorDelta = acquisitionPredecessorDelta
        self.acquisitionPredecessorAgeMS = acquisitionPredecessorAgeMS
        touchDownToAcquisitionMS = max(0, (touch.timestamp - touchDownTimestamp) * 1000)
'''
if old not in text: raise SystemExit('cadence begin assignments anchor not found')
text = text.replace(old, new, 1)
old = '''        let firstRenderX = firstRenderTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstTotalX = firstRenderTotalTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstDelayMS = acquisitionToFirstRenderMS.map { String(format: "%.2f", $0) } ?? "none"
'''
new = '''        let firstRenderX = firstRenderTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstTotalX = firstRenderTotalTranslation.map { String(format: "%.2f", $0) } ?? "none"
        let firstDelayMS = acquisitionToFirstRenderMS.map { String(format: "%.2f", $0) } ?? "none"
        let predecessorDeltaX = acquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"
        let predecessorAgeMS = acquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"
'''
if old not in text: raise SystemExit('cadence end formatting anchor not found')
text = text.replace(old, new, 1)
old = '''touch_down_to_acquire_ms=\\(String(format: "%.2f", touchDownToAcquisitionMS)) acquisition_x=\\(String(format: "%.2f", acquisitionTranslation)) acquire_to_first_render_ms=\\(firstDelayMS)'''
new = '''touch_down_to_acquire_ms=\\(String(format: "%.2f", touchDownToAcquisitionMS)) acquisition_x=\\(String(format: "%.2f", acquisitionTranslation)) acq_coalesced_count=\\(acquisitionCoalescedCount) acq_predecessor_status=\\(acquisitionPredecessorStatus) acq_predecessor_delta_x=\\(predecessorDeltaX) acq_predecessor_age_ms=\\(predecessorAgeMS) acquire_to_first_render_ms=\\(firstDelayMS)'''
if old not in text: raise SystemExit('cadence log anchor not found')
text = text.replace(old, new, 1)
p.write_text(text)

changelog = Path('docs/changelog/CHANGELOG_v0_14_67_build234.md')
changelog.write_text('''# OnePlayer 0.14.67 / Build234\n\n- Diagnostic-only Home carousel acquisition coalesced-sample instrumentation.\n- Keeps Build233 acquisition-first-frame behavior unchanged.\n- Adds acquisition-event coalesced sample count, predecessor status, predecessor delta X, and predecessor age to `HomeCarouselCadence`.\n- Purpose: explain the remaining Build233 coarse-start cases before changing sample selection or guards.\n- Retains Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle, 0.28/0.48 release rules, and all Frozen/P0 playback/transport contracts.\n- Deployment target remains iOS 15.0.\n''')
