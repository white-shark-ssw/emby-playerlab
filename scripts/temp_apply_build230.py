from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift")
text = identity.read_text()
if 'sourceVersion = "0.14.63"' not in text:
    old = 'sourceVersion = "0.14.61"'
    if old not in text: raise SystemExit("Build230 AppIdentity anchor missing")
    text = text.replace(old, 'sourceVersion = "0.14.63"', 1)
    text = text.replace('?? "0.14.61"', '?? "0.14.63"', 1)
    identity.write_text(text)

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
text = hero.read_text()
new = '''        ZStack {
            ForEach(carouselHeroResidentItems) { item in
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }

            LinearGradient('''
if new not in text:
    old = '''        ZStack {
            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }

            LinearGradient('''
    if old not in text: raise SystemExit("Build230 persistent backdrop anchor missing")
    text = text.replace(old, new, 1)
    hero.write_text(text)

changelog = Path("docs/changelog/CHANGELOG_v0_14_63_build230.md")
changelog.write_text('''# OnePlayer 0.14.63 (Build230)\n\n## Home carousel persistent residency A/B\n\n- Starts from the accepted-for-now carousel Build228 release-tail foundation.\n- Reuses the existing settled current + previous + next carousel residency window for the full-screen persistent backdrop.\n- Keeps normal current→target persistent opacity crossfade; unlike Build221, the outgoing backdrop is not frozen during drag.\n- Moves adjacent persistent 1400px + blur presentation creation out of active finger tracking so the target persistent is already mounted before horizontal acquisition.\n- Build226 Hero residency, Build228 max-refresh-through-settle, acquisition-relative foreground motion, 0.28/0.48 release rules and all P0/Frozen playback/transport contracts are unchanged.\n- Diagnostic candidate only until target-device slow-drag/title-shimmer and overall hand-feel A/B.\n''')
