from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift").read_text()
core = Path("Sources/UI/EmbyHomeCoreV3.swift").read_text()
hero = Path("Sources/UI/EmbyHomeHeroV3.swift").read_text()
state = Path("Sources/UI/EmbyHomeCarouselStateV3.swift").read_text()

assert 'static let sourceVersion = "0.14.56"' in identity
root = core.split('ZStack(alignment: .top) {', 1)[1].split('if immersive { carouselPreloadLayer }', 1)[0]
assert 'persistentCarouselBackdrop(' not in root
assert 'if immersive { carouselPreloadLayer }' in core
assert 'func persistentCarouselBackdrop(size: CGSize) -> some View' in hero
assert '.scaleEffect(1.12)' in hero
assert '.blur(radius: 30)' in hero
assert 'var carouselPreloadLayer: some View' in hero
assert 'ForEach(model.carouselItems)' in hero
assert 'abs(homeRawScrollMinY)' not in state
print("Build223 Home persistent-root isolation source contract passed")
