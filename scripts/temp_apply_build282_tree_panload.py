from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: replacement count={count} for {old!r}")
    path.write_text(text.replace(old, new, 1))

app = Path("Sources/Core/AppIdentity.swift")
replace_once(app, 'static let sourceVersion = "0.15.14"', 'static let sourceVersion = "0.15.15"')
replace_once(app, '?? "0.15.14"', '?? "0.15.15"')

probe = Path("Sources/UI/EmbyHomeFramePipelineProbeV3.swift")
replacements = [
    ("    case carouselPanLatched\n    case rawTouch\n", "    case carouselPanLatched\n    case carouselTreePanLoad\n    case rawTouch\n"),
    ('        case .carouselPanLatched: return "CAROUSEL PAN LATCH"\n', '        case .carouselPanLatched: return "CAROUSEL PAN LATCH"\n        case .carouselTreePanLoad: return "TREE PANLOAD"\n'),
    ('        case .carouselPanLatched: return "same Pan → display-link latched real carousel"\n', '        case .carouselPanLatched: return "same Pan → display-link latched real carousel"\n        case .carouselTreePanLoad: return "Full tree ← 120 Hz + active Pan load"\n'),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .carouselTree, .carouselHero, .carouselBackdrop: return true\n"),
    ("        case .carouselTree, .carouselHero, .carouselBackdrop: return true\n", "        case .carouselTreePanLoad, .carouselTree, .carouselHero, .carouselBackdrop: return true\n"),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false\n", "        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false\n"),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselBackdrop: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .carouselTree, .carouselBackdrop: return true\n"),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero: return true\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .carouselTree, .carouselHero: return true\n"),
    ("            case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop:\n", "            case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .carouselTree, .carouselHero, .carouselBackdrop:\n"),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n"),
    ("        case .carousel, .carouselPan, .carouselPanLatched, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break\n", "        case .carousel, .carouselPan, .carouselPanLatched, .carouselTreePanLoad, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break\n"),
]
for old, new in replacements:
    replace_once(probe, old, new)

pan = Path("Sources/UI/EmbyHomeCarouselPanProbeV3.swift")
text = pan.read_text()
marker = "\nstruct V3HomeCarouselPanProbeSurface: UIViewRepresentable {\n"
if text.count(marker) != 1:
    raise SystemExit("Pan probe insertion marker mismatch")
pan_load = '''\nstruct V3HomeCarouselPanLoadProbeSurface: UIViewRepresentable {\n    func makeCoordinator() -> Coordinator { Coordinator() }\n\n    func makeUIView(context: Context) -> UIView {\n        let view = UIView(frame: .zero)\n        view.backgroundColor = .clear\n        view.isUserInteractionEnabled = true\n        let recognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))\n        recognizer.maximumNumberOfTouches = 1\n        recognizer.cancelsTouchesInView = false\n        recognizer.delaysTouchesBegan = false\n        recognizer.delaysTouchesEnded = false\n        view.addGestureRecognizer(recognizer)\n        return view\n    }\n\n    final class Coordinator: NSObject {\n        private var samples = 0\n        private var intervals = 0\n        private var totalGapMS: Double = 0\n        private var maxGapMS: Double = 0\n        private var lastTimestamp: CFTimeInterval?\n\n        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {\n            switch recognizer.state {\n            case .began:\n                reset()\n                record()\n            case .changed:\n                record()\n            case .ended:\n                record()\n                finish(reason: "ended")\n            case .cancelled, .failed:\n                finish(reason: "cancelled")\n            default:\n                break\n            }\n        }\n\n        private func reset() {\n            samples = 0\n            intervals = 0\n            totalGapMS = 0\n            maxGapMS = 0\n            lastTimestamp = nil\n        }\n\n        private func record() {\n            let now = CACurrentMediaTime()\n            samples += 1\n            if let lastTimestamp {\n                let gapMS = max(0, (now - lastTimestamp) * 1000)\n                intervals += 1\n                totalGapMS += gapMS\n                maxGapMS = max(maxGapMS, gapMS)\n            }\n            lastTimestamp = now\n        }\n\n        private func finish(reason: String) {\n            guard samples > 0 else { return }\n            let average = intervals > 0 ? totalGapMS / Double(intervals) : 0\n            DiagnosticsLogger.shared.app("HomeCarouselPanLoadProbe", "reason=\\(reason) samples=\\(samples) avg_gap_ms=\\(String(format: \"%.2f\", average)) max_gap_ms=\\(String(format: \"%.2f\", maxGapMS)) maxFPS=\\(UIScreen.main.maximumFramesPerSecond)")\n            reset()\n        }\n    }\n}\n'''
pan.write_text(text.replace(marker, pan_load + marker, 1))

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
old = '''            if framePipelineProbeMode == .carouselPan || framePipelineProbeMode == .carouselPanLatched {\n                V3HomeCarouselPanProbeSurface(\n                    frameLatched: framePipelineProbeMode == .carouselPanLatched,\n                    shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },\n                    onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },\n                    onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },\n                    onHorizontalCancelled: { cancelNativeCarouselDrag() }\n                )\n            } else {\n'''
new = '''            if framePipelineProbeMode == .carouselPan || framePipelineProbeMode == .carouselPanLatched {\n                V3HomeCarouselPanProbeSurface(\n                    frameLatched: framePipelineProbeMode == .carouselPanLatched,\n                    shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },\n                    onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },\n                    onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },\n                    onHorizontalCancelled: { cancelNativeCarouselDrag() }\n                )\n            } else if framePipelineProbeMode == .carouselTreePanLoad {\n                V3HomeCarouselPanLoadProbeSurface()\n            } else {\n'''
replace_once(hero, old, new)
