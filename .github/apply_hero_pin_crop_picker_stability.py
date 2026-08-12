from pathlib import Path
import re

# Shared Hero metrics + native scroll observer
p = Path("Sources/UI/ImmersiveUIComponents.swift")
s = p.read_text()

old = "static let cropResponseFactor: CGFloat = 0.65"
new = "static let cropResponseFactor: CGFloat = 0.45"
if s.count(old) != 1:
    raise SystemExit(f"crop factor match count={s.count(old)}")
s = s.replace(old, new, 1)

old = """    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {
        min(max(0, upwardScroll) * cropResponseFactor, max(0, cropTravel))
    }

    // Native container motion remains 1:1 with UIScrollView. The clear backdrop releases crop
"""
new = """    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {
        min(max(0, upwardScroll) * cropResponseFactor, max(0, cropTravel))
    }

    static func cropPhaseScrollDistance(cropTravel: CGFloat) -> CGFloat {
        guard cropResponseFactor > 0 else { return 0 }
        return max(0, cropTravel) / cropResponseFactor
    }

    static func backdropPinOffset(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {
        min(max(0, upwardScroll), cropPhaseScrollDistance(cropTravel: cropTravel))
    }

    // Native container motion remains 1:1 with UIScrollView. The clear backdrop releases crop
"""
if s.count(old) != 1:
    raise SystemExit(f"crop helper insertion match count={s.count(old)}")
s = s.replace(old, new, 1)

old = """struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable {
    let forceVerticalBounce: Bool
    let onChange: (CGFloat) -> Void

    init(forceVerticalBounce: Bool = false, onChange: @escaping (CGFloat) -> Void) {
        self.forceVerticalBounce = forceVerticalBounce
        self.onChange = onChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(forceVerticalBounce: forceVerticalBounce, onChange: onChange) }
"""
new = """struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }
"""
if s.count(old) != 1:
    raise SystemExit(f"observer header match count={s.count(old)}")
s = s.replace(old, new, 1)

old = """    func updateUIView(_ uiView: AdaptiveHeroScrollProbeUIView, context: Context) {
        context.coordinator.forceVerticalBounce = forceVerticalBounce
        context.coordinator.onChange = onChange
        context.coordinator.applyBouncePolicy()
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
"""
new = """    func updateUIView(_ uiView: AdaptiveHeroScrollProbeUIView, context: Context) {
        context.coordinator.onChange = onChange
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
"""
if s.count(old) != 1:
    raise SystemExit(f"observer update match count={s.count(old)}")
s = s.replace(old, new, 1)

old = """    final class Coordinator {
        var forceVerticalBounce: Bool
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var originalBounces: Bool?
        private var originalAlwaysBounceVertical: Bool?

        init(forceVerticalBounce: Bool, onChange: @escaping (CGFloat) -> Void) {
            self.forceVerticalBounce = forceVerticalBounce
            self.onChange = onChange
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorScrollView(from: probe) else { return }
            guard self.scrollView !== scrollView else {
                applyBouncePolicy()
                emit(scrollView)
                return
            }
            restoreBouncePolicy()
            contentOffsetObservation?.invalidate()
            self.scrollView = scrollView
            originalBounces = scrollView.bounces
            originalAlwaysBounceVertical = scrollView.alwaysBounceVertical
            applyBouncePolicy()
            contentOffsetObservation = scrollView.observe(\\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            restoreBouncePolicy()
            scrollView = nil
            originalBounces = nil
            originalAlwaysBounceVertical = nil
        }

        func applyBouncePolicy() {
            guard forceVerticalBounce, let scrollView else { return }
            scrollView.bounces = true
            scrollView.alwaysBounceVertical = true
        }

        private func restoreBouncePolicy() {
            guard let scrollView else { return }
            if let originalBounces { scrollView.bounces = originalBounces }
            if let originalAlwaysBounceVertical { scrollView.alwaysBounceVertical = originalAlwaysBounceVertical }
        }
"""
new = """    final class Coordinator {
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?

        init(onChange: @escaping (CGFloat) -> Void) { self.onChange = onChange }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorScrollView(from: probe) else { return }
            guard self.scrollView !== scrollView else {
                emit(scrollView)
                return
            }
            contentOffsetObservation?.invalidate()
            self.scrollView = scrollView
            contentOffsetObservation = scrollView.observe(\\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
        }
"""
if s.count(old) != 1:
    raise SystemExit(f"coordinator match count={s.count(old)}")
s = s.replace(old, new, 1)
p.write_text(s)

# Detail: keep the clear backdrop pinned until crop release finishes, while content scrolls normally.
p = Path("Sources/UI/EmbyMediaDetailView.swift")
s = p.read_text()
old = """        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let visualHeight = baseHeight + stretch
"""
new = """        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let visualHeight = baseHeight + stretch
"""
if s.count(old) != 1:
    raise SystemExit(f"detail pin metric match count={s.count(old)}")
s = s.replace(old, new, 1)
old = """                )
            )

            LinearGradient(
"""
new = """                )
            )
            .offset(y: stretch > 0 ? 0 : backdropPinOffset)

            LinearGradient(
"""
if s.count(old) < 1:
    raise SystemExit("detail clear backdrop mask tail not found")
s = s.replace(old, new, 1)
p.write_text(s)

# Episode picker: isolate high-frequency Hero scroll state from the ScrollViewReader root.
p = Path("Sources/UI/EmbyEpisodePickerView.swift")
s = p.read_text()

old = """private struct EmbyEpisodeJump: Identifiable {
    let label: Int
    let episode: LibraryItem
    var id: String { episode.id }
}

struct EmbyEpisodePickerView: View {
"""
new = """private struct EmbyEpisodeJump: Identifiable {
    let label: Int
    let episode: LibraryItem
    var id: String { episode.id }
}

private struct EmbyEpisodePickerHeroView: View {
    @ObservedObject var model: EmbyMediaDetailViewModel
    let imageURL: URL?
    let width: CGFloat
    @State private var sourceSize: CGSize?
    @State private var rawScrollMinY: CGFloat = 0

    var body: some View {
        let baseHeight = AdaptiveHeroRevealMetrics.compactBaseHeight(width: width)
        let heroViewport = CGSize(width: width, height: baseHeight)
        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: sourceSize, viewportSize: heroViewport)
        let stretch = max(0, rawScrollMinY)
        let upwardScroll = max(0, -rawScrollMinY)
        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel)
        let visualHeight = baseHeight + stretch
        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: sourceSize, viewportSize: CGSize(width: width, height: visualHeight)) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: sourceSize, viewportSize: heroViewport, consumedCropScroll: consumedCropScroll)
        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: visualHeight)
        let maskFadeSpan = min(0.67, clearImageBottom * 0.67)
        let maskStart = max(0.08, clearImageBottom - maskFadeSpan)
        let maskMid = maskStart + (clearImageBottom - maskStart) * 0.50

        ZStack(alignment: .bottomLeading) {
            ZStack(alignment: .top) {
                EmbyCachedRemoteImage(url: imageURL, contentMode: .fill, onImageLoaded: { image in
                    if sourceSize != image.size { sourceSize = image.size }
                })
                .frame(width: renderedImageSize.width, height: renderedImageSize.height)
            }
            .frame(width: width, height: visualHeight, alignment: .top)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.00),
                        .init(color: .black, location: maskStart),
                        .init(color: .black.opacity(0.80), location: maskMid),
                        .init(color: .clear, location: clearImageBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: stretch > 0 ? 0 : backdropPinOffset)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.item.name).font(.headline).lineLimit(1)
                Text(model.selectedSeasonTitle).font(.title2.weight(.bold))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: visualHeight)
        .offset(y: stretch > 0 ? -stretch : 0)
        .frame(width: width, height: baseHeight, alignment: .top)
        .background(
            AdaptiveHeroNativeScrollObserver { value in
                if abs(rawScrollMinY - value) > 0.10 { rawScrollMinY = value }
            }
        )
    }
}

struct EmbyEpisodePickerView: View {
"""
if s.count(old) != 1:
    raise SystemExit(f"picker child insertion match count={s.count(old)}")
s = s.replace(old, new, 1)

s = s.replace("    @State private var pickerHeroSourceSize: CGSize?\n", "", 1)
s = s.replace("    @State private var pickerHeroRawScrollMinY: CGFloat = 0\n", "", 1)

old = "pickerHero(width: geometry.size.width)"
new = "EmbyEpisodePickerHeroView(model: model, imageURL: pickerHeroURL, width: geometry.size.width)"
if s.count(old) != 1:
    raise SystemExit(f"picker hero call match count={s.count(old)}")
s = s.replace(old, new, 1)

old = """                        .frame(width: geometry.size.width)
                        .background(
                            AdaptiveHeroNativeScrollObserver(forceVerticalBounce: true) { value in
                                if abs(pickerHeroRawScrollMinY - value) > 0.10 { pickerHeroRawScrollMinY = value }
                            }
                        )
"""
new = """                        .frame(width: geometry.size.width)
"""
if s.count(old) != 1:
    raise SystemExit(f"picker root observer match count={s.count(old)}")
s = s.replace(old, new, 1)

pattern = re.compile(r"\n    private func pickerHero\(width: CGFloat\) -> some View \{.*?\n    \}\n\n    private var pickerHeroURL", re.S)
m = pattern.search(s)
if not m:
    raise SystemExit("picker hero function block not found")
s = s[:m.start()] + "\n    private var pickerHeroURL" + s[m.end():]
p.write_text(s)

# Regression checker
p = Path("scripts/check_adaptive_hero_reveal.py")
s = p.read_text()
s = s.replace(
    'require("cropResponseFactor: CGFloat = 0.65" in metrics and "upwardScroll) * cropResponseFactor" in metrics, "crop response must stay 35 percent softer than native container travel")',
    'require("cropResponseFactor: CGFloat = 0.45" in metrics and "upwardScroll) * cropResponseFactor" in metrics, "crop response must stay 55 percent softer than native container travel")',
)
marker = 'require("initialSize.height - max(0, consumedCropScroll)" in metrics, "rendered image height must subtract the softened crop response directly")\n'
insert = marker + 'require("cropPhaseScrollDistance" in metrics and "backdropPinOffset" in metrics and "cropTravel) / cropResponseFactor" in metrics, "clear backdrop pin duration must be derived from the real crop travel and response factor")\n'
if marker not in s:
    raise SystemExit("checker crop marker missing")
s = s.replace(marker, insert, 1)
s = s.replace(
    'require("stretch > 0 ? -stretch : 0" in detail, "detail Hero crop and native container motion must run simultaneously while preserving elastic overscroll")',
    'require("stretch > 0 ? -stretch : 0" in detail, "detail content must keep native container motion while preserving elastic overscroll")\nrequire("stretch > 0 ? 0 : backdropPinOffset" in detail, "detail clear backdrop must remain top-pinned until crop release completes")',
)
s = s.replace(
    'require("pickerHeroRawScrollMinY" in picker, "episode picker must read raw ScrollView displacement from the native ScrollView")\nrequire("AdaptiveHeroNativeScrollObserver" in picker, "episode picker must observe native ScrollView content offset")\nrequire("AdaptiveHeroNativeScrollObserver(forceVerticalBounce: true)" in picker, "episode picker must keep native vertical bounce tracking available at the top edge")',
    'require("private struct EmbyEpisodePickerHeroView" in picker and "@State private var rawScrollMinY" in picker, "episode picker Hero must isolate high-frequency scroll state from the ScrollViewReader root")\nrequire("AdaptiveHeroNativeScrollObserver" in picker, "episode picker Hero must observe native ScrollView content offset")\nrequire("forceVerticalBounce" not in picker and "forceVerticalBounce" not in metrics, "episode picker must use the same native bounce policy as detail instead of mutating UIScrollView bounce settings")',
)
s = s.replace(
    'require("stretch > 0 ? -stretch : 0" in picker, "episode picker crop and native container motion must run simultaneously while preserving elastic overscroll")',
    'require("stretch > 0 ? -stretch : 0" in picker, "episode picker content must preserve elastic overscroll")\nrequire("stretch > 0 ? 0 : backdropPinOffset" in picker, "episode picker clear backdrop must remain top-pinned until crop release completes")',
)
s = s.replace(
    'require("baseHeight + consumedCropScroll" not in picker, "episode picker must not extend layout height to pin Hero during crop release")',
    'require("baseHeight + consumedCropScroll" not in picker, "episode picker must not extend layout height to pin the whole Hero during crop release")',
)
p.write_text(s)

print("Hero pin/crop response and Picker scroll-state isolation patch applied")
