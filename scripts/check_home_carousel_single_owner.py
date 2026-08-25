from pathlib import Path

interaction = Path('Sources/UI/EmbyHomeCarouselInteractionV3.swift').read_text()
state = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text()
core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
hero = Path('Sources/UI/EmbyHomeHeroV3.swift').read_text()
identity = Path('Sources/Core/AppIdentity.swift').read_text()
project = Path('project.yml').read_text()

assert 'static let sourceVersion = "0.14.31"' in identity
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
assert 'predictedTranslation' not in interaction.split('onHorizontalChanged: ((CGSize) -> Void)?', 1)[0]
assert 'onHorizontalChanged: ((CGSize) -> Void)?' in interaction
assert 'onHorizontalEnded: ((CGSize, CGSize?) -> Void)?' in interaction
assert 'max(actualDistance, predictedDistance) >= width * 0.48' in interaction
assert 'transitionProgress >= 0.28' in interaction

assert 'V3HomeCarouselInteractionSurface(' in hero
assert '.simultaneousGesture(carouselDragGesture' not in hero
assert '.onTapGesture { openCurrentCarouselDetailIfAllowed() }' not in hero
assert 'DragGesture(' not in state
assert 'carouselDragGesture(width:' not in state

assert 'carouselForegroundOpacity' in state
assert 'if let fromID = transitionFromID, let toID = transitionToID { return itemID == fromID || itemID == toID ? 1 : 0 }' in state
assert 'return -direction * progress * width' in state
assert 'return direction * (1 - progress) * width' in state
assert 'func carouselBackdropBlendProgress(_ rawProgress: CGFloat) -> CGFloat { min(1, max(0, rawProgress)) }' in state
assert '.blur(radius: 30)' in hero
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project

print('Build198 home carousel single-owner contracts passed')
