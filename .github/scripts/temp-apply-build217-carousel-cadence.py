from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, got {count}')
    return text.replace(old, new, 1)


# App identity
p = Path('Sources/Core/AppIdentity.swift')
s = p.read_text()
s = replace_once(s, 'static let sourceVersion = "0.14.48"', 'static let sourceVersion = "0.14.50"', 'sourceVersion')
s = replace_once(s, '?? "0.14.48"', '?? "0.14.50"', 'fallback version')
p.write_text(s)

# Carousel interaction: diagnostic observation only; preserve owner/mapping/release behavior.
p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
s = p.read_text()
s = replace_once(
    s,
    '''            horizontalAcquisitionTranslation = translation.width
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            state = .began
            return
''',
    '''            horizontalAcquisitionTranslation = translation.width
            V3HomeCarouselCadenceDiagnostics.shared.begin(acquisitionTranslation: translation.width, touch: touch, event: event)
            latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
            state = .began
            return
''',
    'horizontal acquisition diagnostics')
s = replace_once(
    s,
    '''        guard axis == .horizontal, state == .began || state == .changed else { return }
        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
        state = .changed
        onHorizontalChanged?(renderTranslation(for: translation))
''',
    '''        guard axis == .horizontal, state == .began || state == .changed else { return }
        V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
        latestPredictedTranslation = predictedTranslation(for: touch, event: event, view: view, origin: origin)
        state = .changed
        onHorizontalChanged?(renderTranslation(for: translation))
''',
    'post-acquisition touch diagnostics')
s = replace_once(
    s,
    '''        if axis == .horizontal, state == .began || state == .changed {
            onHorizontalEnded?(translation, latestPredictedTranslation)
            state = .ended
''',
    '''        if axis == .horizontal, state == .began || state == .changed {
            V3HomeCarouselCadenceDiagnostics.shared.recordTouch(touch, event: event)
            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended")
            onHorizontalEnded?(translation, latestPredictedTranslation)
            state = .ended
''',
    'touch end diagnostics')
s = replace_once(
    s,
    '''    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if axis == .horizontal, state == .began || state == .changed {
            onHorizontalCancelled?()
            state = .cancelled
''',
    '''    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if axis == .horizontal, state == .began || state == .changed {
            V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled")
            onHorizontalCancelled?()
            state = .cancelled
''',
    'touch cancel diagnostics')
s = replace_once(
    s,
    '''            if axis == .horizontal, state == .began || state == .changed {
                onHorizontalCancelled?()
                state = .cancelled
''',
    '''            if axis == .horizontal, state == .began || state == .changed {
                V3HomeCarouselCadenceDiagnostics.shared.end(reason: "cancelled-new-touch")
                onHorizontalCancelled?()
                state = .cancelled
''',
    'unexpected new touch diagnostics')
s = replace_once(
    s,
    '''        if horizontal == 0 {
            if isCarouselDragging { transitionProgress = 0 }
            return
        }
''',
    '''        if horizontal == 0 {
            if isCarouselDragging {
                transitionProgress = 0
                V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish(transitionProgress)
            }
            return
        }
''',
    'zero progress diagnostics')
s = replace_once(
    s,
    '''        transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
''',
    '''        transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
        V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish(transitionProgress)
''',
    'progress publish diagnostics')
p.write_text(s)

# Hero: one zero-sized SwiftUI update probe + image-role timestamps; visual output unchanged.
p = Path('Sources/UI/EmbyHomeHeroV3.swift')
s = p.read_text()
image_callback = 'EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in updateCarouselImageMetrics(image, itemID: item.id) })'
if s.count(image_callback) != 3:
    raise SystemExit(f'hero image callback: expected exactly 3 matches, got {s.count(image_callback)}')
s = s.replace(image_callback, 'EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "hero", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })', 1)
s = s.replace(image_callback, 'EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "persistent", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })', 1)
s = s.replace(image_callback, 'EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "preload", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })', 1)
s = replace_once(
    s,
    '''            carouselPageIndicators
                .padding(.bottom, 18)
                .allowsHitTesting(false)
        }
''',
    '''            carouselPageIndicators
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            V3HomeCarouselCadenceRenderProbe(progress: transitionProgress)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
''',
    'SwiftUI render probe')
p.write_text(s)

# Build217 contract checker: preserve Build215 behavior and assert diagnostics are observation-only.
p = Path('scripts/check_home_carousel_single_owner.py')
s = p.read_text()
s = replace_once(s, "hero = Path('Sources/UI/EmbyHomeHeroV3.swift').read_text()\n", "hero = Path('Sources/UI/EmbyHomeHeroV3.swift').read_text()\ncadence = Path('Sources/UI/EmbyHomeCarouselCadenceDiagnosticsV3.swift').read_text()\n", 'checker cadence source')
s = replace_once(s, 'assert \'static let sourceVersion = "0.14.48"\' in identity', 'assert \'static let sourceVersion = "0.14.50"\' in identity', 'checker version')
s = replace_once(s, "assert 'coalescedTouches' not in interaction", "assert 'event.coalescedTouches(for: touch)' in cadence\nassert 'coalescedTouches' not in interaction", 'checker coalesced ownership')
s = replace_once(s, "print('Build215 home carousel acquisition-relative page-slot contracts passed')", '''assert 'V3HomeCarouselCadenceDiagnostics.shared.begin' in interaction
assert 'V3HomeCarouselCadenceDiagnostics.shared.recordTouch' in interaction
assert 'V3HomeCarouselCadenceDiagnostics.shared.recordProgressPublish' in interaction
assert 'V3HomeCarouselCadenceRenderProbe(progress: transitionProgress)' in hero
for role in ['hero', 'persistent', 'preload']:
    assert f'recordImageCallback(role: "{role}"' in hero
assert 'CADisplayLink(target: self' in cadence
assert 'link.add(to: .main, forMode: .common)' in cadence
assert 'preferredFramesPerSecond' not in cadence
assert 'preferredFrameRateRange' not in cadence
assert 'DiagnosticsLogger.shared.app(' in cadence and '"HomeCarouselCadence"' in cadence
assert 'Timer.' not in cadence
assert 'DispatchQueue.main.asyncAfter' not in cadence
assert 'withAnimation' not in cadence
assert 'onHorizontalChanged' not in cadence
assert 'transitionProgress =' not in cadence

print('Build217 home carousel acquisition-relative contracts + cadence diagnostics passed')''', 'checker Build217 diagnostics')
p.write_text(s)

# Changelog
Path('docs/changelog/CHANGELOG_v0_14_50_build217.md').write_text('''# OnePlayer 0.14.50 / Build217\n\n## Home carousel cadence diagnostics\n\n- Diagnostic-only successor to Build215.\n- Preserves the accepted acquisition-relative 1:1 foreground motion, opaque interactive foreground, full-width page slots, single UIKit owner, 0.28 commit threshold, 0.48×width predicted-distance gate, reversal/cancel/settle/wrap behavior and backdrop mapping.\n- Adds horizontal-drag-only cadence observation for delivered/coalesced touch timing, progress publication timing, SwiftUI representable update timing and passive `CADisplayLink` frame gaps.\n- Correlates the worst display gaps with the latest carousel 1400px image callback role (`hero`, `persistent`, `preload`) and item ID.\n- Emits one aggregated `HomeCarouselCadence` App-log summary per drag; it does not log every touch/frame.\n- The diagnostic display link does not request a preferred frame rate and never drives animation.\n- No smoothing/interpolation/timer/debounce/throttle/watchdog/retry/fallback.\n- No Player / MPV / PiP / Transport / Cache / Session path change. Deployment target remains iOS 15.0.\n''')
