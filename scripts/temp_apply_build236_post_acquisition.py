from pathlib import Path
import re

# App identity
p = Path('Sources/Core/AppIdentity.swift')
text = p.read_text()
text = text.replace('static let sourceVersion = "0.14.67"', 'static let sourceVersion = "0.14.69"')
text = text.replace('as? String ?? "0.14.67"', 'as? String ?? "0.14.69"')
p.write_text(text)

# Interaction: extend the real-coalesced baseline rule by one UIEvent only for Build234-proven one-sample acquisition cases.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
text = p.read_text()
old = '''    private var horizontalAcquisitionTranslation: CGFloat?\n    private var touchDownTimestamp: TimeInterval?\n'''
new = '''    private var horizontalAcquisitionTranslation: CGFloat?\n    private var horizontalAcquisitionTouchTimestamp: TimeInterval?\n    private var horizontalAcquisitionDirectionTranslation: CGFloat = 0\n    private var pendingPostAcquisitionBaseline = false\n    private var touchDownTimestamp: TimeInterval?\n'''
if old not in text: raise SystemExit('interaction fields anchor missing')
text = text.replace(old, new, 1)

old = '''        horizontalAcquisitionTranslation = nil\n        touchDownTimestamp = touch.timestamp\n'''
new = '''        horizontalAcquisitionTranslation = nil\n        horizontalAcquisitionTouchTimestamp = nil\n        horizontalAcquisitionDirectionTranslation = 0\n        pendingPostAcquisitionBaseline = false\n        touchDownTimestamp = touch.timestamp\n'''
if old not in text: raise SystemExit('touchesBegan reset anchor missing')
text = text.replace(old, new, 1)

old = '''            let acquisitionSample = acquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin, acquisitionTranslation: acquisitionTranslation)\n            horizontalAcquisitionTranslation = acquisitionSample.baseline ?? acquisitionTranslation\n            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)\n'''
new = '''            let acquisitionSample = acquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin, acquisitionTranslation: acquisitionTranslation)\n            horizontalAcquisitionTranslation = acquisitionSample.baseline ?? acquisitionTranslation\n            horizontalAcquisitionTouchTimestamp = touch.timestamp\n            horizontalAcquisitionDirectionTranslation = acquisitionTranslation\n            pendingPostAcquisitionBaseline = acquisitionSample.status == "none" && acquisitionSample.count == 1\n            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: acquisitionTranslation, touchDownTimestamp: touchDownTimestamp ?? touch.timestamp, acquisitionCoalescedCount: acquisitionSample.count, acquisitionPredecessorStatus: acquisitionSample.status, acquisitionPredecessorDelta: acquisitionSample.delta, acquisitionPredecessorAgeMS: acquisitionSample.ageMS, touch: touch, event: event)\n'''
if old not in text: raise SystemExit('acquisition setup anchor missing')
text = text.replace(old, new, 1)

old = '''        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)\n        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)\n        let renderedTranslation = renderTranslation(for: translation)\n'''
new = '''        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)\n        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)\n        if pendingPostAcquisitionBaseline {\n            let postAcquisitionSample = postAcquisitionRenderBaselineSample(for: touch, event: event, view: view, origin: origin)\n            if let baseline = postAcquisitionSample.baseline { horizontalAcquisitionTranslation = baseline }\n            V3HomeCarouselCadenceDiagnostics.shared.recordPostAcquisitionSample(count: postAcquisitionSample.count, status: postAcquisitionSample.status, delta: postAcquisitionSample.delta, ageMS: postAcquisitionSample.ageMS)\n            pendingPostAcquisitionBaseline = false\n        }\n        let renderedTranslation = renderTranslation(for: translation)\n'''
if old not in text: raise SystemExit('post-acquisition moved anchor missing')
text = text.replace(old, new, 1)

old = '''        horizontalAcquisitionTranslation = nil\n        touchDownTimestamp = nil\n'''
new = '''        horizontalAcquisitionTranslation = nil\n        horizontalAcquisitionTouchTimestamp = nil\n        horizontalAcquisitionDirectionTranslation = 0\n        pendingPostAcquisitionBaseline = false\n        touchDownTimestamp = nil\n'''
if old not in text: raise SystemExit('recognizer reset anchor missing')
text = text.replace(old, new, 1)

anchor = '''    private func predictedTranslation(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint) -> CGSize? {\n'''
helper = '''    private func postAcquisitionRenderBaselineSample(for touch: UITouch, event: UIEvent, view: UIView, origin: CGPoint) -> (baseline: CGFloat?, count: Int, status: String, delta: CGFloat?, ageMS: Double?) {\n        let samples = (event.coalescedTouches(for: touch) ?? []).sorted { $0.timestamp < $1.timestamp }\n        guard let acquisitionTimestamp = horizontalAcquisitionTouchTimestamp else { return (nil, samples.count, "missing-acquisition", nil, nil) }\n        guard let predecessor = samples.last(where: { $0.timestamp > acquisitionTimestamp + 0.000001 && $0.timestamp < touch.timestamp - 0.000001 }) else { return (nil, samples.count, "none", nil, nil) }\n        let predecessorTranslation = predecessor.location(in: view).x - origin.x\n        let currentTranslation = touch.location(in: view).x - origin.x\n        let delta = currentTranslation - predecessorTranslation\n        let ageMS = max(0, (touch.timestamp - predecessor.timestamp) * 1000)\n        guard delta != 0 else { return (nil, samples.count, "zero", delta, ageMS) }\n        guard delta * horizontalAcquisitionDirectionTranslation > 0 else { return (nil, samples.count, "direction", delta, ageMS) }\n        return (predecessorTranslation, samples.count, "accepted", delta, ageMS)\n    }\n\n'''
if anchor not in text: raise SystemExit('predicted helper anchor missing')
text = text.replace(anchor, helper + anchor, 1)
p.write_text(text)

# Cadence diagnostics: preserve Build234 acquisition facts and add the single post-acquisition decision.
p = Path('Sources/UI/EmbyHomeCarouselCadenceDiagnosticsV3.swift')
text = p.read_text()
old = '''    private var acquisitionPredecessorAgeMS: Double?\n    private var firstRenderTranslation: CGFloat?\n'''
new = '''    private var acquisitionPredecessorAgeMS: Double?\n    private var postAcquisitionCoalescedCount = 0\n    private var postAcquisitionPredecessorStatus = "not-needed"\n    private var postAcquisitionPredecessorDelta: CGFloat?\n    private var postAcquisitionPredecessorAgeMS: Double?\n    private var firstRenderTranslation: CGFloat?\n'''
if old not in text: raise SystemExit('cadence post-acq fields anchor missing')
text = text.replace(old, new, 1)

old = '''        self.acquisitionPredecessorDelta = acquisitionPredecessorDelta\n        self.acquisitionPredecessorAgeMS = acquisitionPredecessorAgeMS\n        touchDownToAcquisitionMS = max(0, (touch.timestamp - touchDownTimestamp) * 1000)\n'''
new = '''        self.acquisitionPredecessorDelta = acquisitionPredecessorDelta\n        self.acquisitionPredecessorAgeMS = acquisitionPredecessorAgeMS\n        postAcquisitionCoalescedCount = 0\n        postAcquisitionPredecessorStatus = "not-needed"\n        postAcquisitionPredecessorDelta = nil\n        postAcquisitionPredecessorAgeMS = nil\n        touchDownToAcquisitionMS = max(0, (touch.timestamp - touchDownTimestamp) * 1000)\n'''
if old not in text: raise SystemExit('cadence begin reset anchor missing')
text = text.replace(old, new, 1)

anchor = '''    func recordFirstRender(translation: CGFloat, totalTranslation: CGFloat, touchTimestamp: TimeInterval) {\n'''
method = '''    func recordPostAcquisitionSample(count: Int, status: String, delta: CGFloat?, ageMS: Double?) {\n        precondition(Thread.isMainThread)\n        guard active else { return }\n        postAcquisitionCoalescedCount = count\n        postAcquisitionPredecessorStatus = status\n        postAcquisitionPredecessorDelta = delta\n        postAcquisitionPredecessorAgeMS = ageMS\n    }\n\n'''
if anchor not in text: raise SystemExit('recordFirstRender anchor missing')
text = text.replace(anchor, method + anchor, 1)

old = '''        let predecessorDeltaX = acquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"\n        let predecessorAgeMS = acquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"\n'''
new = '''        let predecessorDeltaX = acquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"\n        let predecessorAgeMS = acquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"\n        let postPredecessorDeltaX = postAcquisitionPredecessorDelta.map { String(format: "%.2f", $0) } ?? "none"\n        let postPredecessorAgeMS = postAcquisitionPredecessorAgeMS.map { String(format: "%.2f", $0) } ?? "none"\n'''
if old not in text: raise SystemExit('cadence end formatting anchor missing')
text = text.replace(old, new, 1)

old = '''acq_predecessor_age_ms=\\(predecessorAgeMS) acquire_to_first_render_ms=\\(firstDelayMS)'''
new = '''acq_predecessor_age_ms=\\(predecessorAgeMS) post_acq_coalesced_count=\\(postAcquisitionCoalescedCount) post_acq_predecessor_status=\\(postAcquisitionPredecessorStatus) post_acq_predecessor_delta_x=\\(postPredecessorDeltaX) post_acq_predecessor_age_ms=\\(postPredecessorAgeMS) acquire_to_first_render_ms=\\(firstDelayMS)'''
if old not in text: raise SystemExit('cadence log anchor missing')
text = text.replace(old, new, 1)
p.write_text(text)

# Changelog
Path('docs/changelog/CHANGELOG_v0_14_69_build236.md').write_text('''# OnePlayer 0.14.69 / Build236\n\n- Home carousel acquisition-start A/B based on Build234 target-device evidence.\n- If the acquisition UIEvent has only the current delivered touch (`acq_predecessor_status=none`, count 1), inspect only the first post-acquisition UIEvent for a real coalesced predecessor after acquisition.\n- When such a predecessor exists and continues in the already-selected horizontal direction, use it once as the render baseline while still publishing the current delivered touch; immediately return to ordinary delivered-touch ownership afterwards.\n- If no valid real predecessor exists, preserve the existing fallback.\n- Adds post-acquisition predecessor diagnostics; no timer, interpolation, step cap, easing, debounce/throttle, predicted-touch render authority, or second state owner.\n- Retains Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle, 0.28/0.48 release rules and all Frozen/P0 playback/transport contracts.\n- Deployment target remains iOS 15.0.\n''')

# Early resumable checkpoint on the feature branch.
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
text = p.read_text()
status = '**Active — Build234 / 0.14.67 target-device diagnostics prove the dominant residual coarse-start case is acquisition-event predecessor absence (`acq_coalesced_count=1`), not direction/zero rejection. Build236 / 0.14.69 is now the current single-variable behavior A/B: only for those one-sample acquisition cases, inspect the first post-acquisition UIEvent for a real direction-compatible predecessor after acquisition, use it once as the render baseline while publishing the current delivered touch, then immediately return to ordinary delivered-touch ownership. Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 max-refresh-through-settle and existing 0.28/0.48 release semantics remain retained. Build235 is reserved by Aether and is not reused. Build216 remains the accepted overall runtime baseline.**'
text = re.sub(r'^\*\*Active — Build234 / 0\.14\.67.*?\*\*$', status, text, count=1, flags=re.M)
text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `perf/home-carousel-post-acquisition-baseline-build236`', text, count=1, flags=re.M)
text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.69 (236)`', text, count=1, flags=re.M)
section = '''## Build236 / 0.14.69 — first post-acquisition real-predecessor A/B\n\nBuild234 target-device evidence records 31 drags with 20 `accepted` acquisition events and 11 `none` events. Every `none` event has `acq_coalesced_count=1`, with zero `direction` and zero `zero` rejections; those fallback starts have median first visible step 9.0pt and >=5pt in 9/11 cases. This directly justifies extending the one-time real-coalesced-baseline rule by at most one UIEvent only for those one-sample acquisition cases.\n\nBuild236 preserves Build233 acquisition-event behavior. If acquisition already has an accepted predecessor, nothing changes. If acquisition is exactly `none` with count 1, the first post-acquisition `touchesMoved` checks only real coalesced samples whose timestamp is after the acquisition touch and before the current delivered touch. The immediately preceding direction-compatible real sample may become the render baseline once; the visual publication is still the current delivered touch. If no such sample exists, the old fallback is preserved. The pending path is cleared after that first post-acquisition event. No timer, interpolation, numeric step cap, easing, debounce/throttle, predicted render authority or second owner is introduced.\n\nBuild235 / 0.14.68 is reserved by the independent Aether task. Build236 / 0.14.69 is the unique carousel candidate after branch/active-checkpoint collision checks.\n\nEvidence: code patch prepared on `perf/home-carousel-post-acquisition-baseline-build236`; CI/IPA pending at this checkpoint; real-device pending; stable ❌.\n\n'''
marker = '\n## Rejected directions not to repeat'
if section.splitlines()[0] not in text:
    if marker not in text: raise SystemExit('checkpoint rejected marker missing')
    text = text.replace(marker, '\n' + section + '## Rejected directions not to repeat', 1)
next_start = text.index('## Next exact action')
text = text[:next_start] + '''## Next exact action\n\nRun exact-scope/Frozen validation and Xcode 16.4 Release CI for Build236 / 0.14.69. If CI/IPA succeeds and package identity is independently verified, test repeated immediate touch-and-drag starts on iPhone 15 Pro Max / iOS 17.0 and export the App log. Compare acquisition `accepted` starts with acquisition `none` starts split by `post_acq_predecessor_status`; the key acceptance signal is whether `none -> post_acq accepted` first visible steps materially converge toward the already-fine acquisition-accepted group without harming hold-before-drag, reversal, title compositing or release tail.\n'''
p.write_text(text)
