import SwiftUI
import UIKit

extension V3EmbyHomeView {
    func immersiveCarouselHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + V3HomeCarouselNativeLayout.displayHeightAdjustment(displayRange: carouselDisplayRange, viewportHeight: viewportHeight)
        return ZStack {
            Color.clear

            NavigationLink(
                destination: Group {
                    if let item = carouselDetailItem { EmbyMediaDetailView(item: item, client: client) }
                    else { EmptyView() }
                },
                isActive: $isCarouselDetailPresented
            ) { EmptyView() }
            .frame(width: 0, height: 0)
            .hidden()
            .allowsHitTesting(false)
        }
        .frame(width: width, height: baseHeight)
        .contentShape(Rectangle())
        .overlay {
            V3HomeCarouselInteractionSurface(
                shouldBeginHorizontal: { translation in carouselRuntimeState.prepareHorizontalDrag(acquisitionTranslationX: translation.width) },
                onHorizontalChanged: { translation in suppressCarouselTap(); carouselRuntimeState.updateDrag(translationX: translation.width, width: width) },
                onHorizontalEnded: { translation, releaseVelocityX in suppressCarouselTap(); carouselRuntimeState.finishDrag(actualTranslationX: translation.width, releaseVelocityX: releaseVelocityX, width: width) },
                onHorizontalCancelled: { carouselRuntimeState.cancelDrag() },
                onTap: { openCurrentCarouselDetailIfAllowed() }
            )
        }
    }

    func carouselHeroTitle(_ item: LibraryItem) -> String {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesName = item.seriesName, !seriesName.isEmpty { return seriesName }
        return item.name
    }
}
