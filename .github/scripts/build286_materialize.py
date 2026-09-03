from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one match in {path}: {old!r}, got {count}")
    p.write_text(text.replace(old, new, 1))


replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.14.49"', 'static let sourceVersion = "0.15.19"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.14.49"', '?? "0.15.19"')
replace_once("Sources/UI/EmbyHomeCarouselInteractionV3.swift", '    @Published var progress: CGFloat = 0\n', '    let progress = V3HomeCarouselProgressState()\n')
replace_once("Sources/UI/EmbyHomeCarouselStateV3.swift", '        get { carouselTransitionState.progress }', '        get { carouselTransitionState.progress.value }')
replace_once("Sources/UI/EmbyHomeCarouselStateV3.swift", '        nonmutating set { carouselTransitionState.progress = newValue }', '        nonmutating set { carouselTransitionState.progress.value = newValue }')

Path("Sources/UI/EmbyHomeCarouselProgressPresentationV3.swift").write_text('''import SwiftUI
import Combine

final class V3HomeCarouselProgressState: ObservableObject {
    @Published var value: CGFloat = 0
}

struct V3HomeCarouselProgressOpacity<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let resolveOpacity: (CGFloat) -> Double
    let content: Content

    init(progress: V3HomeCarouselProgressState, resolveOpacity: @escaping (CGFloat) -> Double, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.resolveOpacity = resolveOpacity
        self.content = content()
    }

    var body: some View { content.opacity(resolveOpacity(progress.value)) }
}

struct V3HomeCarouselProgressOffsetX<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let resolveOffsetX: (CGFloat) -> CGFloat
    let content: Content

    init(progress: V3HomeCarouselProgressState, resolveOffsetX: @escaping (CGFloat) -> CGFloat, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.resolveOffsetX = resolveOffsetX
        self.content = content()
    }

    var body: some View { content.offset(x: resolveOffsetX(progress.value)) }
}

struct V3HomeCarouselProgressReadScope<Content: View>: View {
    @ObservedObject var progress: V3HomeCarouselProgressState
    let content: (CGFloat) -> Content

    init(progress: V3HomeCarouselProgressState, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.progress = progress
        self.content = content
    }

    var body: some View { content(progress.value) }
}
''')

hero = Path("Sources/UI/EmbyHomeHeroV3.swift")
text = hero.read_text()

old = '''    func immersiveCarouselHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + homeCarouselDisplayHeightAdjustment(viewportHeight: viewportHeight)
        return ZStack(alignment: .bottom) {
'''
new = '''    func immersiveCarouselHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + homeCarouselDisplayHeightAdjustment(viewportHeight: viewportHeight)
        let progressState = carouselTransitionState.progress
        let fromID = transitionFromID
        let toID = transitionToID
        let direction = transitionDirection
        let currentID = currentCarouselItemID
        return ZStack(alignment: .bottom) {
'''
if text.count(old) != 1:
    raise SystemExit("immersiveCarouselHero header mismatch")
text = text.replace(old, new, 1)

old = '''            ForEach(carouselHeroResidentItems) { item in
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
'''
new = '''            ForEach(carouselHeroResidentItems) { item in
                V3HomeCarouselProgressOpacity(progress: progressState, resolveOpacity: { rawProgress in
                    if let fromID, let toID {
                        let blend = carouselBackdropBlendProgress(rawProgress)
                        if item.id == fromID { return Double(1 - blend) }
                        if item.id == toID { return Double(blend) }
                        return 0
                    }
                    return item.id == currentID ? 1 : 0
                }) {
                    carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                }
                .allowsHitTesting(false)
            }
'''
if text.count(old) != 1:
    raise SystemExit("Hero artwork block mismatch")
text = text.replace(old, new, 1)

old = '''            ForEach(model.carouselItems) { item in
                carouselHeroForeground(item: item, width: width, viewportHeight: viewportHeight)
                    .compositingGroup()
                    .opacity(carouselForegroundOpacity(for: item.id))
                    .offset(x: carouselForegroundOffset(for: item.id, width: width))
                    .allowsHitTesting(false)
            }
'''
new = '''            ForEach(model.carouselItems) { item in
                V3HomeCarouselProgressOffsetX(progress: progressState, resolveOffsetX: { rawProgress in
                    guard let fromID, let toID else { return 0 }
                    let visualProgress = min(1, max(0, rawProgress))
                    let pageStep = width
                    let visualDirection = CGFloat(direction)
                    if item.id == fromID { return -visualDirection * visualProgress * pageStep }
                    if item.id == toID { return visualDirection * (1 - visualProgress) * pageStep }
                    return 0
                }) {
                    carouselHeroForeground(item: item, width: width, viewportHeight: viewportHeight)
                        .compositingGroup()
                        .opacity(carouselForegroundOpacity(for: item.id))
                }
                .allowsHitTesting(false)
            }
'''
if text.count(old) != 1:
    raise SystemExit("Hero foreground block mismatch")
text = text.replace(old, new, 1)

old = '''            carouselPageIndicators
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            V3HomeCarouselCadenceRenderProbe(progress: transitionProgress)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
'''
new = '''            V3HomeCarouselProgressReadScope(progress: progressState) { progress in
                let displayedItemID = (toID != nil && progress >= 0.5) ? toID : currentID
                carouselPageIndicators(displayedItemID: displayedItemID)
            }
            .padding(.bottom, 18)
            .allowsHitTesting(false)

            V3HomeCarouselProgressReadScope(progress: progressState) { progress in
                V3HomeCarouselCadenceRenderProbe(progress: progress)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
'''
if text.count(old) != 1:
    raise SystemExit("Indicators/probe block mismatch")
text = text.replace(old, new, 1)

old = '''    var carouselPageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(model.carouselItems) { item in
                Circle()
                    .fill(item.id == displayedCarouselItemID ? Color.primary.opacity(0.88) : Color.primary.opacity(0.26))
                    .frame(width: item.id == displayedCarouselItemID ? 7 : 6, height: item.id == displayedCarouselItemID ? 7 : 6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 18)
    }
'''
new = '''    func carouselPageIndicators(displayedItemID: String?) -> some View {
        HStack(spacing: 8) {
            ForEach(model.carouselItems) { item in
                Circle()
                    .fill(item.id == displayedItemID ? Color.primary.opacity(0.88) : Color.primary.opacity(0.26))
                    .frame(width: item.id == displayedItemID ? 7 : 6, height: item.id == displayedItemID ? 7 : 6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 18)
    }
'''
if text.count(old) != 1:
    raise SystemExit("Page indicators block mismatch")
text = text.replace(old, new, 1)

old = '''    func persistentCarouselBackdrop(size: CGSize) -> some View {
        ZStack {
            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size)
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(Double(carouselBackdropBlendProgress(transitionProgress)))
            }
'''
new = '''    func persistentCarouselBackdrop(size: CGSize) -> some View {
        let progressState = carouselTransitionState.progress
        return ZStack {
            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size)
            }
            if let item = transitionTargetCarouselItem {
                V3HomeCarouselProgressOpacity(progress: progressState, resolveOpacity: { Double(carouselBackdropBlendProgress($0)) }) {
                    carouselPersistentImage(item: item, size: size)
                }
            }
'''
if text.count(old) != 1:
    raise SystemExit("Persistent backdrop block mismatch")
text = text.replace(old, new, 1)

hero.write_text(text)
