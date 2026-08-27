from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift").read_text()
state = Path("Sources/UI/EmbyHomeCarouselStateV3.swift").read_text()
scroll_state = Path("Sources/UI/EmbyHomeHeroScrollStateV3.swift").read_text()
core = Path("Sources/UI/EmbyHomeCoreV3.swift").read_text()
hero = Path("Sources/UI/EmbyHomeHeroV3.swift").read_text()
project = Path("project.yml").read_text()

assert 'static let sourceVersion = "0.14.55"' in identity
assert 'static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.14.55"' in identity

auto_start = state.index("func autoAdvanceCarouselIfNeeded()")
auto_end = state.index("func settleCarousel", auto_start)
auto = state[auto_start:auto_end]
assert 'guard isHomeActive, !isCarouselDragging, transitionToID == nil, model.carouselItems.count > 1 else { return }' in auto
assert 'guard abs(homeRawScrollMinY) <= 0.5 else { return }' in auto
assert 'guard Date().timeIntervalSince(carouselLastSettledAt) >= 6 else { return }' in auto
assert state.count('guard abs(homeRawScrollMinY) <= 0.5 else { return }') == 1
assert '@Published private(set) var rawMinY: CGFloat = 0' in scroll_state
assert 'var homeRawScrollMinY: CGFloat { heroScrollState.rawMinY }' in scroll_state
assert 'private let carouselTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()' in core
assert '.blur(radius: 30)' in hero
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
assert 'deploymentTarget: "15.0"' in project

print("Build222 Home top-only automatic-carousel isolation contract passed")
