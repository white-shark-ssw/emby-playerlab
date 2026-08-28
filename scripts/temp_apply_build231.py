from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift")
text = identity.read_text()
text = text.replace('sourceVersion = "0.14.61"', 'sourceVersion = "0.14.64"')
text = text.replace('?? "0.14.61"', '?? "0.14.64"')
identity.write_text(text)

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
text = hero.read_text()
old = '''                carouselHeroForeground(item: item, width: width, viewportHeight: viewportHeight)\n                    .opacity(carouselForegroundOpacity(for: item.id))'''
new = '''                carouselHeroForeground(item: item, width: width, viewportHeight: viewportHeight)\n                    .compositingGroup()\n                    .opacity(carouselForegroundOpacity(for: item.id))'''
if new not in text:
    if old not in text: raise SystemExit("foreground mount anchor not found")
    text = text.replace(old, new, 1)
hero.write_text(text)

changelog = Path("docs/changelog/CHANGELOG_v0_14_64_build231.md")
changelog.write_text("""# OnePlayer 0.14.64 / Build231\n\n- Diagnostic-only Home carousel foreground compositing A/B.\n- Base: cleaned carousel Build228 foundation (Build226 three-slot Hero residency + Build228 max-refresh-through-settle).\n- Adds one SwiftUI `compositingGroup()` boundary to each existing carousel foreground page before opacity/X offset.\n- Does not carry Build230 persistent residency or Build227 pixel rounding.\n- Gesture ownership, acquisition-relative motion, 0.28/0.48 release gates, Hero/persistent visual semantics, release timing, preload and Frozen/P0 paths remain unchanged.\n- Purpose: test whether slow-drag title shimmer is caused by foreground child-layer compositing/presentation rather than geometry or backdrop first-mount pressure.\n""")
