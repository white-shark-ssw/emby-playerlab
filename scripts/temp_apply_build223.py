from pathlib import Path

core = Path("Sources/UI/EmbyHomeCoreV3.swift")
text = core.read_text()
old = '                    if immersive { persistentCarouselBackdrop(size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)) }\n'
if text.count(old) != 1:
    raise SystemExit(f"persistent root mount match count={text.count(old)}")
core.write_text(text.replace(old, "", 1))

checker = Path("scripts/check_home_vertical_persistent_isolation.py")
checker.write_text('''from pathlib import Path\n\nidentity = Path("Sources/Core/AppIdentity.swift").read_text()\ncore = Path("Sources/UI/EmbyHomeCoreV3.swift").read_text()\nhero = Path("Sources/UI/EmbyHomeHeroV3.swift").read_text()\nstate = Path("Sources/UI/EmbyHomeCarouselStateV3.swift").read_text()\n\nassert 'static let sourceVersion = "0.14.56"' in identity\nroot = core.split('ZStack(alignment: .top) {', 1)[1].split('if immersive { carouselPreloadLayer }', 1)[0]\nassert 'persistentCarouselBackdrop(' not in root\nassert 'if immersive { carouselPreloadLayer }' in core\nassert 'func persistentCarouselBackdrop(size: CGSize) -> some View' in hero\nassert '.scaleEffect(1.12)' in hero\nassert '.blur(radius: 30)' in hero\nassert 'var carouselPreloadLayer: some View' in hero\nassert 'ForEach(model.carouselItems)' in hero\nassert 'abs(homeRawScrollMinY)' not in state\nprint("Build223 Home persistent-root isolation source contract passed")\n''')

Path("docs/changelog/CHANGELOG_v0_14_56_build223.md").write_text('''# OnePlayer 0.14.56 / Build223\n\n- Diagnostic A/B only for Home vertical smoothness.\n- Do not mount the root-level full-screen persistent carousel backdrop in the Home root ZStack.\n- Hero artwork, carousel preload, automatic carousel behavior and horizontal interaction remain unchanged from the accepted main baseline.\n- Purpose: isolate whether the always-mounted 1400px `scaleEffect(1.12)` + `blur(radius: 30)` persistent backdrop is a structural contributor to Home vertical hitching.\n- This intentionally changes the immersive Home background appearance and is not a proposed final visual design.\n''')

Path(__file__).unlink()
print("Build223 patch applied")
