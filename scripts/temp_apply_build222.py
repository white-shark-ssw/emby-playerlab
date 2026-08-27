from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "Sources/Core/AppIdentity.swift",
    'static let sourceVersion = "0.14.49"',
    'static let sourceVersion = "0.14.55"',
    "source version",
)
replace_once(
    "Sources/Core/AppIdentity.swift",
    'as? String ?? "0.14.49"',
    'as? String ?? "0.14.55"',
    "fallback version",
)
replace_once(
    "Sources/UI/EmbyHomeCarouselStateV3.swift",
    '''    func autoAdvanceCarouselIfNeeded() {
        guard isHomeActive, !isCarouselDragging, transitionToID == nil, model.carouselItems.count > 1 else { return }
        guard Date().timeIntervalSince(carouselLastSettledAt) >= 6 else { return }''',
    '''    func autoAdvanceCarouselIfNeeded() {
        guard isHomeActive, !isCarouselDragging, transitionToID == nil, model.carouselItems.count > 1 else { return }
        guard abs(homeRawScrollMinY) <= 0.5 else { return }
        guard Date().timeIntervalSince(carouselLastSettledAt) >= 6 else { return }''',
    "top-only automatic carousel transition guard",
)

Path("scripts/check_home_vertical_carousel_isolation.py").write_text('''from pathlib import Path

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
''')

Path("docs/changelog/CHANGELOG_v0_14_55_build222.md").write_text('''# OnePlayer 0.14.55 / Build222

- Diagnostic A/B only, based on the accepted Build216/main product source rather than Build221.
- Automatic Home carousel transitions may start only while the Home vertical scroll position is at its top/rest position (`abs(homeRawScrollMinY) <= 0.5`).
- Once the user has vertically browsed away from the top, the existing 1-second timer may still tick but it cannot start the 6-second automatic carousel transition; returning to the top restores the existing automatic behavior.
- Current persistent backdrop, preload layer, Hero rendering, manual horizontal carousel gestures, navigation and all playback/P0 paths are unchanged.
- Purpose: isolate whether offscreen automatic carousel transition/persistent-target presentation is a causal contributor to Home vertical scrolling hitches before attempting broader Home architecture changes.
''')

Path(__file__).unlink()
print("Build222 one-shot patch applied")
