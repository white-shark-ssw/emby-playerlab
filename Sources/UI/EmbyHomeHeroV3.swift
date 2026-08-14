import SwiftUI
import Combine
import UIKit

extension V3EmbyHomeView {
    func immersiveCarouselHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)
        return ZStack(alignment: .bottom) {
            if let item = currentCarouselItem {
                carouselHeroSlide(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }
            if let item = transitionTargetCarouselItem {
                carouselHeroSlide(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }

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

            carouselPageIndicators
                .padding(.bottom, 12)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: baseHeight)
        .contentShape(Rectangle())
        .onTapGesture { openCurrentCarouselDetailIfAllowed() }
        .simultaneousGesture(carouselDragGesture(width: width))
    }

    func carouselHeroSlide(item: LibraryItem, width: CGFloat, viewportHeight: CGFloat) -> some View {
        let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)
        let backdropViewportHeight = AdaptiveHeroRevealMetrics.detailBackdropViewportHeight(width: width)
        let backdropViewport = CGSize(width: width, height: backdropViewportHeight)
        let sourceSize = carouselSourceSizeByID[item.id]
        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: sourceSize, viewportSize: backdropViewport)
        let stretch = max(0, homeRawScrollMinY)
        let upwardScroll = max(0, -homeRawScrollMinY)
        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)
        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)
        let backdropVisualHeight = backdropBaseHeight + stretch
        let visualHeight = baseHeight + stretch
        let stretchedBackdropViewport = CGSize(width: width, height: backdropViewportHeight + stretch)
        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: sourceSize, viewportSize: stretchedBackdropViewport) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: sourceSize, viewportSize: backdropViewport, consumedCropScroll: consumedCropScroll)
        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: backdropVisualHeight)
        let maskFadeSpan = min(0.34, clearImageBottom * 0.46)
        let maskStart = max(0.10, clearImageBottom - maskFadeSpan)
        let maskFirstMid = maskStart + (clearImageBottom - maskStart) * 0.29
        let maskSecondMid = maskStart + (clearImageBottom - maskStart) * 0.71
        let usesLight = carouselLightForegroundByID[item.id] ?? true
        let contrastScrim = usesLight ? Color.black.opacity(0.22) : Color.white.opacity(0.16)

        return ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in updateCarouselImageMetrics(image, itemID: item.id) })
                    .frame(width: renderedImageSize.width, height: renderedImageSize.height)
            }
            .frame(width: width, height: backdropVisualHeight, alignment: .top)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.00),
                        .init(color: .black, location: maskStart),
                        .init(color: .black.opacity(0.92), location: maskFirstMid),
                        .init(color: .black.opacity(0.52), location: maskSecondMid),
                        .init(color: .clear, location: clearImageBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: stretch > 0 ? 0 : backdropPinOffset)
            .frame(width: width, height: visualHeight, alignment: .top)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.46),
                    .init(color: contrastScrim.opacity(0.42), location: 0.66),
                    .init(color: contrastScrim, location: 0.82),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            V3HeroCard(item: item, client: client, usesLightForeground: usesLight)
        }
        .frame(width: width, height: visualHeight)
        .offset(y: stretch > 0 ? -stretch : 0)
        .frame(width: width, height: baseHeight, alignment: .top)
    }

    var carouselPageIndicators: some View {
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

    func persistentCarouselBackdrop(size: CGSize) -> some View {
        ZStack {
            if let item = currentCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(carouselOpacity(for: item.id))
            }

            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.18 : 0.26),
                    Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.38 : 0.46),
                    Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.58 : 0.64)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    func carouselPersistentImage(item: LibraryItem, size: CGSize) -> some View {
        EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in updateCarouselImageMetrics(image, itemID: item.id) })
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(1.12)
            .blur(radius: 30)
    }

    var carouselPreloadLayer: some View {
        ZStack {
            ForEach(model.carouselItems) { item in
                EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in updateCarouselImageMetrics(image, itemID: item.id) })
                    .frame(width: 1, height: 1)
                    .clipped()
            }
        }
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

}
