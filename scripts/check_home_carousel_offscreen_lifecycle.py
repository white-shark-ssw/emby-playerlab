from pathlib import Path

identity = Path('Sources/Core/AppIdentity.swift').read_text()
core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
scroll_state = Path('Sources/UI/EmbyHomeHeroScrollStateV3.swift').read_text()
carousel_state = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text()
project = Path('project.yml').read_text()

assert 'static let sourceVersion = "0.14.55"' in identity
assert 'private(set) var isFullyOffscreen = false' in scroll_state
assert 'func update(_ value: CGFloat, isFullyOffscreen: Bool)' in scroll_state
assert 'self.isFullyOffscreen = isFullyOffscreen' in scroll_state
assert '@Published private(set) var rawMinY: CGFloat = 0' in scroll_state
assert '@Published private(set) var isFullyOffscreen' not in scroll_state
assert 'heroScrollState.update(clampedValue, isFullyOffscreen: value <= -heroTrackingLimit)' in core
assert '.onReceive(carouselTimer) { _ in if !heroScrollState.isFullyOffscreen { autoAdvanceCarouselIfNeeded() } }' in core
assert core.count('Timer.publish(') == 1
assert 'func autoAdvanceCarouselIfNeeded()' in carousel_state
assert 'withAnimation(.easeInOut(duration: 0.62))' in carousel_state
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print('Build222 Home carousel offscreen lifecycle A/B checks passed')
