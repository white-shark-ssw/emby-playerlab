from pathlib import Path

path = Path("Sources/UI/EmbyHomeFramePipelineProbeV3.swift")
s = path.read_text()
replacements = [
    ("    case carouselPan\n", "    case carouselPan\n    case carouselPanLatched\n"),
    ('        case .carouselPan: return "CAROUSEL PAN"\n', '        case .carouselPan: return "CAROUSEL PAN"\n        case .carouselPanLatched: return "CAROUSEL PAN LATCH"\n'),
    ('        case .carouselPan: return "UIPanGestureRecognizer → real carousel state/tree"\n', '        case .carouselPan: return "UIPanGestureRecognizer + max-refresh → real carousel"\n        case .carouselPanLatched: return "same Pan → display-link latched real carousel"\n'),
    ("        case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop: return true\n"),
    ("        case .carousel, .carouselPan, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false\n", "        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false\n"),
    ("        case .carousel, .carouselPan, .carouselTree, .carouselBackdrop: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselBackdrop: return true\n"),
    ("        case .carousel, .carouselPan, .carouselTree, .carouselHero: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero: return true\n"),
    ("            case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop:\n", "            case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop:\n"),
    ("        case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n"),
    ("        case .carousel, .carouselPan, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break\n", "        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break\n"),
]
for old, new in replacements:
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"replacement mismatch count={count}: {old!r}")
    s = s.replace(old, new, 1)
path.write_text(s)
