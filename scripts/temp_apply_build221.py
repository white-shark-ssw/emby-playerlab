from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    s = p.read_text()
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    p.write_text(s.replace(old, new, 1))

replace_once(
    "Sources/Core/AppIdentity.swift",
    'static let sourceVersion = "0.14.52"',
    'static let sourceVersion = "0.14.54"',
    "source version",
)
replace_once(
    "Sources/Core/AppIdentity.swift",
    'as? String ?? "0.14.52"',
    'as? String ?? "0.14.54"',
    "fallback version",
)
replace_once(
    "Sources/UI/EmbyHomeHeroV3.swift",
    '''            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }''',
    '''            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(isCarouselDragging ? 1 : carouselOpacity(for: item.id))
            }
            if !isCarouselDragging, let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }''',
    "persistent drag isolation",
)
replace_once(
    "scripts/check_home_carousel_single_owner.py",
    'static let sourceVersion = "0.14.52"',
    'static let sourceVersion = "0.14.54"',
    "checker version",
)
replace_once(
    "scripts/check_home_carousel_single_owner.py",
    "assert '.blur(radius: 30)' in hero",
    "assert '.blur(radius: 30)' in hero\nassert 'carouselPersistentImage(item: item, size: size).opacity(isCarouselDragging ? 1 : carouselOpacity(for: item.id))' in hero\nassert 'if !isCarouselDragging, let item = transitionTargetCarouselItem {' in hero\nassert hero.count('carouselPersistentImage(item: item, size: size)') == 2",
    "checker persistent contract",
)
replace_once(
    "scripts/check_home_carousel_single_owner.py",
    "print('Build219 home carousel retained contracts + exact max-refresh diagnostic request passed')",
    "print('Build221 home carousel retained contracts + persistent-drag isolation diagnostic passed')",
    "checker result",
)
Path("docs/changelog/CHANGELOG_v0_14_54_build221.md").write_text(
    "# OnePlayer 0.14.54 / Build221\n\n"
    "- Diagnostic A/B only: retain Build219 120 Hz request and all Build215 carousel motion contracts.\n"
    "- While the user is actively dragging, keep only the current full-screen blurred persistent backdrop at opacity 1 and do not mount the transition-target persistent image.\n"
    "- Hero artwork still mounts/crossfades normally. On release, the existing persistent transition path resumes.\n"
    "- Purpose: isolate the repeatable 50 ms display gaps observed ~19-25 ms after persistent 1400px image callbacks.\n"
)
Path(__file__).unlink()
print("Build221 one-shot patch applied")
