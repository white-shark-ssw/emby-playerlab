from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)

probe_path = Path("Sources/UI/EmbyHomeFramePipelineProbeV3.swift")
probe = probe_path.read_text()
probe = replace_once(probe, "    case carousel\n    case rawTouch", "    case carousel\n    case carouselPan\n    case rawTouch", "enum case")
probe = replace_once(probe, "        case .carousel: return \"CAROUSEL\"\n        case .rawTouch: return \"TOUCH LAYER\"", "        case .carousel: return \"CAROUSEL\"\n        case .carouselPan: return \"CAROUSEL PAN\"\n        case .rawTouch: return \"TOUCH LAYER\"", "title")
probe = replace_once(probe, "        case .carousel: return \"Build265 normal carousel\"\n        case .rawTouch: return \"custom touchesMoved → native CALayer\"", "        case .carousel: return \"Build275 normal carousel owner\"\n        case .carouselPan: return \"UIPanGestureRecognizer → real carousel state/tree\"\n        case .rawTouch: return \"custom touchesMoved → native CALayer\"", "detail")
probe = replace_once(probe, "        case .carousel, .carouselTree, .carouselHero, .carouselBackdrop: return true", "        case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop: return true", "usesHome true")
probe = replace_once(probe, "        case .carousel, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false", "        case .carousel, .carouselPan, .rawTouch, .nativePan, .nativeScroll, .coreAnimation, .nativeDisplayLink, .swiftUI: return false", "tree false")
probe = replace_once(probe, "        case .carousel, .carouselTree, .carouselBackdrop: return true", "        case .carousel, .carouselPan, .carouselTree, .carouselBackdrop: return true", "backdrop true")
probe = replace_once(probe, "        case .carousel, .carouselTree, .carouselHero: return true", "        case .carousel, .carouselPan, .carouselTree, .carouselHero: return true", "hero true")
probe = replace_once(probe, "            case .carousel, .carouselTree, .carouselHero, .carouselBackdrop:\n                EmptyView()", "            case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop:\n                EmptyView()", "probe empty")
probe = replace_once(probe, "    private var mode: V3HomeFramePipelineProbeMode = .rawTouch\n    private var cadence", "    private var mode: V3HomeFramePipelineProbeMode = .rawTouch\n    private var configuredMode: V3HomeFramePipelineProbeMode?\n    private var cadence", "configured field")
probe = replace_once(probe, "    func setMode(_ mode: V3HomeFramePipelineProbeMode) {\n        guard self.mode != mode || rawRecognizer == nil && panRecognizer == nil && scrollView.isHidden else { return }\n        self.mode = mode\n        configureMode()\n    }", "    func setMode(_ mode: V3HomeFramePipelineProbeMode) {\n        guard configuredMode != mode else { return }\n        self.mode = mode\n        configuredMode = mode\n        configureMode()\n    }", "setMode init fix")
probe = replace_once(probe, "        case .carousel, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n            break", "        case .carousel, .carouselPan, .carouselTree, .carouselHero, .carouselBackdrop, .coreAnimation, .nativeDisplayLink, .swiftUI:\n            break", "input switch")
probe = replace_once(probe, "        case .carousel, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break", "        case .carousel, .carouselPan, .rawTouch, .nativePan, .nativeScroll, .carouselTree, .carouselHero, .carouselBackdrop, .swiftUI: break", "native switch")
if probe.count("carouselPan") < 10:
    raise SystemExit(f"carouselPan coverage unexpectedly low: {probe.count('carouselPan')}")
probe_path.write_text(probe)

hero_path = Path("Sources/UI/EmbyHomeHeroV3.swift")
hero = hero_path.read_text()
old_overlay = '''        .overlay {\n            V3HomeCarouselInteractionSurface(\n                shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },\n                onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },\n                onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },\n                onHorizontalCancelled: { cancelNativeCarouselDrag() },\n                onTap: { openCurrentCarouselDetailIfAllowed() }\n            )\n        }'''
new_overlay = '''        .overlay {\n            if framePipelineProbeMode == .carouselPan {\n                V3HomeCarouselPanProbeSurface(\n                    shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },\n                    onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },\n                    onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },\n                    onHorizontalCancelled: { cancelNativeCarouselDrag() }\n                )\n            } else {\n                V3HomeCarouselInteractionSurface(\n                    shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },\n                    onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },\n                    onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },\n                    onHorizontalCancelled: { cancelNativeCarouselDrag() },\n                    onTap: { openCurrentCarouselDetailIfAllowed() }\n                )\n            }\n        }'''
hero = replace_once(hero, old_overlay, new_overlay, "hero interaction overlay")
hero_path.write_text(hero)

pan_path = Path("Sources/UI/EmbyHomeCarouselPanProbeV3.swift")
if pan_path.exists():
    raise SystemExit("Pan probe file already exists")
pan_path.write_text(r'''import SwiftUI
import UIKit

final class V3HomeCarouselPanProbeRecognizer: UIPanGestureRecognizer {
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventedGestureRecognizer.view as? UIScrollView, preventedGestureRecognizer === scrollView.panGestureRecognizer { return true }
        return super.canPrevent(preventedGestureRecognizer)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = preventingGestureRecognizer.view as? UIScrollView, preventingGestureRecognizer === scrollView.panGestureRecognizer { return false }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }
}

struct V3HomeCarouselPanProbeSurface: UIViewRepresentable {
    let shouldBeginHorizontal: (CGSize) -> Bool
    let onHorizontalChanged: (CGSize) -> Void
    let onHorizontalEnded: (CGSize, CGFloat?) -> Void
    let onHorizontalCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldBeginHorizontal: shouldBeginHorizontal, onHorizontalChanged: onHorizontalChanged, onHorizontalEnded: onHorizontalEnded, onHorizontalCancelled: onHorizontalCancelled)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let recognizer = V3HomeCarouselPanProbeRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.shouldBeginHorizontal = shouldBeginHorizontal
        context.coordinator.onHorizontalChanged = onHorizontalChanged
        context.coordinator.onHorizontalEnded = onHorizontalEnded
        context.coordinator.onHorizontalCancelled = onHorizontalCancelled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var shouldBeginHorizontal: (CGSize) -> Bool
        var onHorizontalChanged: (CGSize) -> Void
        var onHorizontalEnded: (CGSize, CGFloat?) -> Void
        var onHorizontalCancelled: () -> Void
        private var baselineX: CGFloat = 0
        private var sampleCount = 0
        private var intervalCount = 0
        private var totalGapMS: Double = 0
        private var maxGapMS: Double = 0
        private var lastTimestamp: CFTimeInterval?

        init(shouldBeginHorizontal: @escaping (CGSize) -> Bool, onHorizontalChanged: @escaping (CGSize) -> Void, onHorizontalEnded: @escaping (CGSize, CGFloat?) -> Void, onHorizontalCancelled: @escaping () -> Void) {
            self.shouldBeginHorizontal = shouldBeginHorizontal
            self.onHorizontalChanged = onHorizontalChanged
            self.onHorizontalEnded = onHorizontalEnded
            self.onHorizontalCancelled = onHorizontalCancelled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer, let view = recognizer.view else { return false }
            let velocity = recognizer.velocity(in: view)
            let horizontal = abs(velocity.x)
            let vertical = abs(velocity.y)
            guard horizontal > 0, horizontal >= vertical * 1.15 else { return false }
            return shouldBeginHorizontal(CGSize(width: velocity.x, height: velocity.y))
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translationX = recognizer.translation(in: view).x
            switch recognizer.state {
            case .began:
                baselineX = translationX
                beginCadence()
            case .changed:
                recordCadence()
                onHorizontalChanged(CGSize(width: translationX - baselineX, height: 0))
            case .ended:
                recordCadence()
                let rendered = CGSize(width: translationX - baselineX, height: 0)
                onHorizontalEnded(rendered, recognizer.velocity(in: view).x)
                endCadence(reason: "ended")
            case .cancelled, .failed:
                onHorizontalCancelled()
                endCadence(reason: "cancelled")
            default:
                break
            }
        }

        private func beginCadence() {
            sampleCount = 0
            intervalCount = 0
            totalGapMS = 0
            maxGapMS = 0
            lastTimestamp = nil
            recordCadence()
        }

        private func recordCadence() {
            let now = CACurrentMediaTime()
            sampleCount += 1
            if let lastTimestamp {
                let gapMS = max(0, (now - lastTimestamp) * 1000)
                intervalCount += 1
                totalGapMS += gapMS
                maxGapMS = max(maxGapMS, gapMS)
            }
            lastTimestamp = now
        }

        private func endCadence(reason: String) {
            guard sampleCount > 0 else { return }
            let average = intervalCount > 0 ? totalGapMS / Double(intervalCount) : 0
            DiagnosticsLogger.shared.app("HomeCarouselPanProbe", "reason=\(reason) samples=\(sampleCount) avg_gap_ms=\(String(format: \"%.2f\", average)) max_gap_ms=\(String(format: \"%.2f\", maxGapMS)) maxFPS=\(UIScreen.main.maximumFramesPerSecond)")
            sampleCount = 0
            intervalCount = 0
            totalGapMS = 0
            maxGapMS = 0
            lastTimestamp = nil
        }
    }
}
''')

print("Build279 carousel real-pan patch applied")
