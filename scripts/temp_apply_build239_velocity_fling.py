from pathlib import Path

p = Path('Sources/Core/AppIdentity.swift')
text = p.read_text()
if text.count('0.14.71') != 2: raise SystemExit('unexpected AppIdentity version count')
text = text.replace('0.14.71', '0.14.72')
p.write_text(text)

p = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift')
text = p.read_text()
old_type = '(CGSize, CGSize?) -> Void'
if text.count(old_type) != 4: raise SystemExit(f'unexpected onHorizontalEnded type count: {text.count(old_type)}')
text = text.replace(old_type, '(CGSize, CGFloat?) -> Void')
old_call = '            onHorizontalEnded?(translation, latestPredictedTranslation)'
if text.count(old_call) != 1: raise SystemExit('touchesEnded call anchor mismatch')
text = text.replace(old_call, '            onHorizontalEnded?(translation, latestMoveDeliveredVelocityX)', 1)
old = '''    func finishNativeCarouselDrag(_ translation: CGSize, predictedTranslation: CGSize?, width: CGFloat) {
        suppressCarouselTap()
        let actualDistance = abs(translation.width)
        let releaseDirection = isCarouselDragging ? transitionDirection : (translation.width < 0 ? 1 : -1)
        let expectedSign: CGFloat = releaseDirection > 0 ? -1 : 1
        let predictedDistance: CGFloat
        if let predictedTranslation, predictedTranslation.width == 0 || predictedTranslation.width * expectedSign > 0 { predictedDistance = abs(predictedTranslation.width) }
        else { predictedDistance = actualDistance }
        let actualProgress = min(1, max(0, actualDistance / max(1, width)))
        let shouldCommit = actualProgress >= 0.28 || max(actualDistance, predictedDistance) >= width * 0.24
'''
new = '''    func finishNativeCarouselDrag(_ translation: CGSize, releaseVelocityX: CGFloat?, width: CGFloat) {
        suppressCarouselTap()
        let actualDistance = abs(translation.width)
        let releaseDirection = isCarouselDragging ? transitionDirection : (translation.width < 0 ? 1 : -1)
        let expectedSign: CGFloat = releaseDirection > 0 ? -1 : 1
        let actualProgress = min(1, max(0, actualDistance / max(1, width)))
        let releaseVelocity = releaseVelocityX ?? 0
        let directionalVelocity = releaseVelocity * expectedSign
        let velocityCommit = directionalVelocity >= 600
        let shouldCommit = actualProgress >= 0.28 || velocityCommit
        DiagnosticsLogger.shared.app("HomeCarouselReleaseDecision", "actual_progress=\(String(format: \"%.3f\", actualProgress)) release_velocity_x=\(String(format: \"%.2f\", releaseVelocity)) directional_velocity=\(String(format: \"%.2f\", directionalVelocity)) velocity_commit=\(velocityCommit) should_commit=\(shouldCommit)")
'''
if text.count(old) != 1: raise SystemExit('finishNativeCarouselDrag anchor mismatch')
text = text.replace(old, new, 1)
if 'width * 0.24' in text: raise SystemExit('legacy 0.24 distance fling gate still present')
if 'actualProgress >= 0.28 || velocityCommit' not in text: raise SystemExit('velocity commit missing')
p.write_text(text)

Path('docs/changelog/CHANGELOG_v0_14_72_build239.md').write_text('''# OnePlayer 0.14.72 / Build239\n\n- Replaces the rejected predicted-total-distance carousel fling gate with a direction-aware latest-delivered-move velocity gate.\n- Keeps the ordinary slow-drag commit threshold at 0.28 progress.\n- Uses 600 pt/s as the first target-device A/B threshold, selected inside Build238's measured empty interval between short slow drags (0–160 pt/s) and intentional quick flicks (~1140–2240 pt/s); this is a OnePlayer tuning value, not an asserted EX constant.\n- Retains Build237 persistent source-over white-flash correction, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail.\n- Adds release-decision logging only at touch release; no timer/interpolation/debounce/throttle or second gesture owner.\n- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.\n''')
