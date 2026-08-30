import SwiftUI
import Combine
import UIKit

extension V3EmbyHomeView {
    func immersiveCarouselHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + homeCarouselDisplayHeightAdjustment(viewportHeight: viewportHeight)
        return ZStack(alignment: .bottom) {
            ForEach(carouselHeroResidentItems) { item in
                carouselHeroArtwork(item: item, width: width, viewportHeight: viewportHeight)
                    .opacity(carouselOpacity(for: item.id))
                    .allowsHitTesting(false)
            }

            ForEach(model.carouselItems) { item in
                carouselHeroForeground(item: item, width: width, viewportHeight: viewportHeight)
                    .compositingGroup()
                    .opacity(carouselForegroundOpacity(for: item.id))
                    .offset(x: carouselForegroundOffset(for: item.id, width: width))
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
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            V3HomeCarouselCadenceRenderProbe(progress: transitionProgress)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: baseHeight)
        .overlay {
            V3HomeCarouselInteractionSurface(
                shouldBeginHorizontal: { translation in shouldBeginNativeCarouselDrag(translation) },
                onHorizontalChanged: { translation in handleNativeCarouselDrag(translation, width: width) },
                onHorizontalEnded: { translation, releaseVelocityX in finishNativeCarouselDrag(translation, releaseVelocityX: releaseVelocityX, width: width) },
                onHorizontalCancelled: { cancelNativeCarouselDrag() },
                onTap: { openCurrentCarouselDetailIfAllowed() }
            )
        }
    }

    func carouselHeroArtwork(item: LibraryItem, width: CGFloat, viewportHeight: CGFloat) -> some View {
        let displayHeightAdjustment = homeCarouselDisplayHeightAdjustment(viewportHeight: viewportHeight)
        let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width) + displayHeightAdjustment
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + displayHeightAdjustment
        let backdropViewportHeight = AdaptiveHeroRevealMetrics.detailBackdropViewportHeight(width: width)
        let backdropViewport = CGSize(width: width, height: backdropViewportHeight)
        let sourceSize = carouselSourceSizeByID[item.id]
        let defaultArtworkSize = homeInitialArtworkSize(imageSize: sourceSize, viewportSize: backdropViewport)
        let fullRevealSize = homeFullRevealArtworkSize(imageSize: sourceSize, viewportSize: backdropViewport)
        let initialArtworkSize = homeDisplayRangeArtworkSize(defaultSize: defaultArtworkSize, fullRevealSize: fullRevealSize)
        let cropTravel = max(0, initialArtworkSize.height - fullRevealSize.height)
        let stretch = max(0, homeRawScrollMinY)
        let upwardScroll = max(0, -homeRawScrollMinY)
        let consumedCropScroll = min(upwardScroll * AdaptiveHeroRevealMetrics.detailCropResponseFactor, cropTravel)
        let cropPhaseDistance = cropTravel / AdaptiveHeroRevealMetrics.detailCropResponseFactor
        let backdropPinOffset = min(upwardScroll, cropPhaseDistance)
        let backdropVisualHeight = backdropBaseHeight + stretch
        let visualHeight = baseHeight + stretch
        let renderedImageSize: CGSize
        if stretch > 0 {
            let overscrollScale = 1 + min(0.22, stretch / 420)
            renderedImageSize = CGSize(width: initialArtworkSize.width * overscrollScale, height: initialArtworkSize.height * overscrollScale)
        } else {
            let targetHeight = max(fullRevealSize.height, initialArtworkSize.height - consumedCropScroll)
            let aspect = initialArtworkSize.height > 1 ? initialArtworkSize.width / initialArtworkSize.height : 1
            renderedImageSize = CGSize(width: targetHeight * aspect, height: targetHeight)
        }
        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: backdropVisualHeight)
        let maskFadeSpan = min(0.34, clearImageBottom * 0.46)
        let maskStart = max(0.10, clearImageBottom - maskFadeSpan)
        let maskFirstMid = maskStart + (clearImageBottom - maskStart) * 0.29
        let maskSecondMid = maskStart + (clearImageBottom - maskStart) * 0.71
        let usesLight = carouselLightForegroundByID[item.id] ?? true
        let contrastScrim = usesLight ? Color.black.opacity(0.22) : Color.white.opacity(0.16)

        return ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "hero", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })
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
        }
        .frame(width: width, height: visualHeight)
        .offset(y: stretch > 0 ? -stretch : 0)
        .frame(width: width, height: baseHeight, alignment: .top)
    }

    func carouselHeroForeground(item: LibraryItem, width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + homeCarouselDisplayHeightAdjustment(viewportHeight: viewportHeight)
        let stretch = max(0, homeRawScrollMinY)
        let visualHeight = baseHeight + stretch
        let contentWidth = max(0, width - 56)
        let usesLight = carouselLightForegroundByID[item.id] ?? true
        let primaryForeground = usesLight ? Color.white : Color.black
        let secondaryForeground = usesLight ? Color.white.opacity(0.90) : Color.black.opacity(0.80)
        let foregroundShadow = usesLight ? Color.black.opacity(0.52) : Color.white.opacity(0.24)

        return VStack(alignment: .center, spacing: 10) {
            if let logoURL = carouselLogoURL(item) {
                EmbyCachedRemoteImage(url: logoURL, contentMode: .fit, showsLoadingIndicator: false)
                    .frame(width: min(300, contentWidth), height: 76, alignment: .center)
                    .frame(width: contentWidth, alignment: .center)
            } else {
                Text(carouselHeroTitle(item))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(primaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: contentWidth, alignment: .center)
                    .shadow(color: foregroundShadow, radius: 3, y: 1)
            }

            HStack(spacing: 8) {
                if let rating = item.communityRating { Text("★ " + String(format: "%.1f", rating)).foregroundColor(.yellow) }
                if let year = item.productionYear { Text(String(year)) }
                if let official = item.officialRating, !official.isEmpty { Text(official) }
                Text(v3MediaTypeTitle(item))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(secondaryForeground)
            .frame(width: contentWidth, alignment: .center)

            if let overview = item.overview, !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundColor(secondaryForeground)
                    .lineLimit(2)
                    .frame(width: contentWidth, alignment: .leading)
                    .shadow(color: foregroundShadow, radius: 2, y: 1)
            }
        }
        .frame(width: contentWidth, height: max(0, visualHeight - 56), alignment: .bottom)
        .frame(width: width, height: visualHeight, alignment: .top)
        .offset(y: stretch > 0 ? -stretch : 0)
        .frame(width: width, height: baseHeight, alignment: .top)
    }

    func carouselHeroTitle(_ item: LibraryItem) -> String {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesName = item.seriesName, !seriesName.isEmpty { return seriesName }
        return item.name
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
                carouselPersistentImage(item: item, size: size)
            }
            if let item = transitionTargetCarouselItem {
                carouselPersistentImage(item: item, size: size).opacity(Double(carouselBackdropBlendProgress(transitionProgress)))
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
        EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "persistent", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(1.12)
    }

    var carouselPreloadLayer: some View {
        ZStack {
            ForEach(model.carouselItems) { item in
                EmbyCachedRemoteImage(url: carouselImageURL(item), contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "preload", itemID: item.id); updateCarouselImageMetrics(image, itemID: item.id) })
                    .frame(width: 1, height: 1)
                    .clipped()
            }
        }
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

    private func homeInitialArtworkSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else {
            return CGSize(width: viewportSize.width, height: max(viewportSize.height, viewportSize.width * 1.5))
        }
        let scale = max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func homeFullRevealArtworkSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1 else {
            return homeInitialArtworkSize(imageSize: imageSize, viewportSize: viewportSize)
        }
        let scale = viewportSize.width / imageSize.width
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func homeCarouselDisplayHeightAdjustment(viewportHeight: CGFloat) -> CGFloat {
        let value = CGFloat(min(1, max(0, carouselDisplayRange)))
        if value >= 0.30 {
            let progress = (value - 0.30) / 0.70
            return min(132, viewportHeight * 0.16) * progress
        }
        let progress = (0.30 - value) / 0.30
        return -min(52, viewportHeight * 0.06) * progress
    }

    private func homeDisplayRangeArtworkSize(defaultSize: CGSize, fullRevealSize: CGSize) -> CGSize {
        let value = CGFloat(min(1, max(0, carouselDisplayRange)))
        if value >= 0.30 {
            let progress = min(1, ((value - 0.30) / 0.70) * 0.82)
            return CGSize(
                width: defaultSize.width + (fullRevealSize.width - defaultSize.width) * progress,
                height: defaultSize.height + (fullRevealSize.height - defaultSize.height) * progress
            )
        }
        let progress = (0.30 - value) / 0.30
        let scale = 1 + 0.12 * progress
        return CGSize(width: defaultSize.width * scale, height: defaultSize.height * scale)
    }
}
