from pathlib import Path

interaction = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift').read_text()
state = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text()
core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
hero = Path('Sources/UI/EmbyHomeHeroV3.swift').read_text()
identity = Path('Sources/Core/AppIdentity.swift').read_text()
info = Path('Config/Info.plist').read_text()
project = Path('project.yml').read_text()

assert 'static let sourceVersion = "0.14.44"' in identity
assert 'V3HomeCarouselTransitionState' in interaction
assert '@State var carouselTransitionState = V3HomeCarouselTransitionState()' in core
assert '@State var transitionProgress' not in core
assert '@State var transitionFromID' not in core
assert '@State var transitionToID' not in core
assert 'V3HomeCarouselTransitionScope(state: carouselTransitionState)' in core

assert 'private final class V3HomeCarouselInteractionRecognizer: UIGestureRecognizer' in interaction
for method in ['touchesBegan', 'touchesMoved', 'touchesEnded', 'touchesCancelled']:
    assert f'override func {method}' in interaction
for phase in ['state = .began', 'state = .changed', 'state = .ended', 'state = .cancelled', 'state = .failed']:
    assert phase in interaction
assert 'max(abs(translation.width), abs(translation.height)) >= 0.5' in interaction
assert 'axis = abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical' in interaction
assert 'if axis == .vertical { state = .failed; return }' in interaction
assert 'canPrevent(_ preventedGestureRecognizer:' in interaction
assert 'canBePrevented(by preventingGestureRecognizer:' in interaction
assert 'UIScrollView' in interaction and 'panGestureRecognizer' in interaction

assert 'event.predictedTouches(for: touch)?.last' in interaction
assert 'coalescedTouches' not in interaction
assert 'onHorizontalChanged: ((CGSize) -> Void)?' in interaction
assert 'onHorizontalEnded: ((CGSize, CGSize?) -> Void)?' in interaction
assert 'max(actualDistance, predictedDistance) >= width * 0.48' in interaction
assert 'let actualProgress = min(1, max(0, actualDistance / max(1, width)))' in interaction
assert 'let shouldCommit = actualProgress >= 0.28 || max(actualDistance, predictedDistance) >= width * 0.48' in interaction
assert 'transitionProgress >= 0.28' not in interaction

assert 'V3HomeCarouselInteractionSurface(' in hero
assert '.simultaneousGesture(carouselDragGesture' not in hero
assert '.onTapGesture { openCurrentCarouselDetailIfAllowed() }' not in hero
assert 'DragGesture(' not in state
assert 'carouselDragGesture(width:' not in state

assert 'ScrollView(.vertical, showsIndicators: false)' in core
assert 'V3HomeScrollOffsetObserver' in core
assert 'V3HomeOwnedRefreshControl' in core
assert 'V3HomeRefreshModifier' in core
assert 'carouselTimer = Timer.publish(every: 1' in core
assert 'autoAdvanceCarouselIfNeeded()' in core

assert 'carouselForegroundOpacity' in state
assert 'return itemID == fromID || itemID == toID ? 1 : 0' in state
assert 'let visualProgress = min(1, max(0, transitionProgress))' in state
assert 'let pageStep = width' in state
assert 'let travel = width * 0.80' not in state
assert 'return -direction * visualProgress * pageStep' in state
assert 'return direction * (1 - visualProgress) * pageStep' in state
assert 'let contentWidth = max(0, width - 56)' in hero
assert 'let progress = min(1, max(0, rawProgress))' in state
assert 'let remaining = 1 - progress' in state
assert 'let earlyWeight = remaining * remaining * remaining * remaining * remaining * remaining' in state
assert 'return progress * (1 - 0.85 * earlyWeight)' in state
assert 'horizontalAcquisitionTranslation = translation.width' in interaction
assert 'horizontalAcquisitionSign = translation.width < 0 ? -1 : 1' in interaction
assert 'onHorizontalChanged?(renderTranslation(for: translation))' in interaction
assert 'abs(translation.width) - abs(acquisitionTranslation)' in interaction
assert 'if horizontal == 0 {' in interaction
assert 'if isCarouselDragging { transitionProgress = 0 }' in interaction
assert 'return progress * progress' not in state
assert 'let next = (index + direction + items.count) % items.count' in state
assert '.blur(radius: 30)' in hero
assert '<key>CADisableMinimumFrameDurationOnPhone</key>' in info
assert '<true/>' in info.split('<key>CADisableMinimumFrameDurationOnPhone</key>', 1)[1][:80]
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project

print('Build211 home carousel acquisition-relative page-slot contracts passed')
