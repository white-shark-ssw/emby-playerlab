import SwiftUI
import Combine
import UIKit

struct EmbyEpisodeRange: Identifiable, Hashable {
    let startOffset: Int
    let endOffset: Int
    let firstNumber: Int
    let lastNumber: Int
    var id: Int { startOffset }
    var title: String { firstNumber == lastNumber ? String(firstNumber) : "\(firstNumber)-\(lastNumber)" }
}

struct EmbyMediaDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: EmbyMediaDetailViewModel
    @State private var showFullOverview = false
    @State private var showAllEpisodes = false
    @State private var selectedStillIndex: Int?
    @State private var heroUsesLightForeground = true
    @State private var heroSourceSize: CGSize?
    @State private var heroRawScrollMinY: CGFloat = 0
    @State private var mediaInfoExpanded = false
    @State private var showRawMediaPath = false

    init(item: LibraryItem, client: EmbyAPIClient, initialEpisodeID: String? = nil) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client, initialEpisodeID: initialEpisodeID))
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
            ZStack(alignment: .top) {
                persistentBackdrop

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                            hero(width: geometry.size.width, viewportHeight: viewportHeight)
                            VStack(alignment: .leading, spacing: 24) {
                                overview
                                if model.isSeries { seriesContent }
                                castSection
                                mediaStreamInfoSection
                                tagSection
                                stillsSection
                                similarSection
                                mediaSourceSummarySection
                                if let error = model.errorMessage { errorView(error) }
                            }
                            .padding(.top, 2)
                            .padding(.bottom, max(88, geometry.safeAreaInsets.bottom + 70))
                    }
                    .frame(width: geometry.size.width)
                    .background(
                        AdaptiveHeroNativeScrollObserver { value in
                            if abs(heroRawScrollMinY - value) > 0.10 { heroRawScrollMinY = value }
                        }
                    )
                }
                .frame(width: geometry.size.width, height: viewportHeight)
                .background(Color.clear)
                .ignoresSafeArea(edges: [.top, .bottom])


                NavigationLink(destination: EmbyEpisodePickerView(model: model, client: client), isActive: $showAllEpisodes) { EmptyView() }
                    .frame(width: 0, height: 0)
                    .hidden()
            }
            .frame(width: geometry.size.width, height: viewportHeight, alignment: .top)
            .ignoresSafeArea(edges: [.top, .bottom])
            .onAppear { DiagnosticsLogger.shared.log("ImmersiveViewport", "page=detail geometry=\(geometry.size) safe=\(geometry.safeAreaInsets) viewportHeight=\(viewportHeight)") }
        }
        .navigationBarHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .immersiveSystemNavigationAppearance()
        .nativeInteractivePop()
        .detailPagePresentation()
        .onAppear { DiagnosticsLogger.shared.log("NavigationRace", "event=detail-appear item=\(model.item.id)") }
        .onDisappear { DiagnosticsLogger.shared.log("NavigationRace", "event=detail-disappear item=\(model.item.id)") }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in
            guard let source = notification.object as? EmbyAPIClient, source === client,
                  notification.userInfo?[EmbyUserDataChange.reasonKey] as? String == EmbyUserDataChange.playbackStoppedReason,
                  let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }
            Task { await model.refreshPlaybackUserData(itemID: itemID) }
        }
        .background(EmbyStillViewerPresenter(selectedIndex: $selectedStillIndex, images: model.stillImages, itemId: model.item.id, client: client).frame(width: 0, height: 0))
        .fullScreenCover(isPresented: $showFullOverview) {
            EmbyOverviewOverlayView(text: model.normalizedOverview ?? "", backdropURL: heroImageURL)
        }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private func hero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)
        let contentWidth = max(0, width - 40)
        let backdropViewportHeight = AdaptiveHeroRevealMetrics.detailBackdropViewportHeight(width: width)
        let backdropViewport = CGSize(width: width, height: backdropViewportHeight)
        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: heroSourceSize, viewportSize: backdropViewport)
        let stretch = max(0, heroRawScrollMinY)
        let upwardScroll = max(0, -heroRawScrollMinY)
        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)
        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)
        let backdropVisualHeight = backdropBaseHeight + stretch
        let visualHeight = baseHeight + stretch
        let stretchedBackdropViewport = CGSize(width: width, height: backdropViewportHeight + stretch)
        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: heroSourceSize, viewportSize: stretchedBackdropViewport) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: heroSourceSize, viewportSize: backdropViewport, consumedCropScroll: consumedCropScroll)
        let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedImageSize, viewportHeight: backdropVisualHeight)
        let maskFadeSpan = min(0.34, clearImageBottom * 0.46)
        let maskStart = max(0.10, clearImageBottom - maskFadeSpan)
        let maskFirstMid = maskStart + (clearImageBottom - maskStart) * 0.29
        let maskSecondMid = maskStart + (clearImageBottom - maskStart) * 0.71
        let contrastScrim = heroUsesLightForeground ? Color.black.opacity(0.22) : Color.white.opacity(0.16)

        return ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                EmbyCachedRemoteImage(url: heroImageURL, contentMode: .fill, onImageLoaded: { image in updateHeroImageMetrics(image) })
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
                    .init(color: .clear, location: 0.48),
                    .init(color: contrastScrim.opacity(0.48), location: 0.67),
                    .init(color: contrastScrim, location: 0.82),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 9) {
                heroIdentity(width: contentWidth)

                Text(heroMetadataLine)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(heroSecondaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: contentWidth)

                if !model.detailFilters.isEmpty { heroTagScroller(width: width) }

                if let playableItem = model.primaryPlayableItem {
                    Button { Task { await model.play(playableItem) } } label: { primaryPlayButtonLabel(width: contentWidth) }
                        .buttonStyle(DetailPressButtonStyle())
                        .disabled(model.isResolvingPlayback)
                }

                detailActionRow(width: contentWidth)
            }
            .frame(width: width)
            .padding(.bottom, 6)
        }
        .frame(width: width, height: visualHeight)
        .offset(y: stretch > 0 ? -stretch : 0)
        .frame(width: width, height: baseHeight, alignment: .top)
    }

    private func primaryPlayButtonLabel(width: CGFloat) -> some View {
        let progress = CGFloat(min(max(0, model.primaryPlayButtonProgress), 1))
        let foreground = Color.black.opacity(0.82)
        let baseOpacity = model.primaryPlayButtonShowsResume ? 0.56 : 0.82
        let shape = RoundedRectangle(cornerRadius: 25, style: .continuous)
        return ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    shape.fill(Color.white.opacity(baseOpacity))
                    if model.primaryPlayButtonShowsResume && progress > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.42))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .clipShape(shape)
            }

            HStack(spacing: 12) {
                if model.isResolvingPlayback {
                    ProgressView().tint(foreground)
                } else {
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .bold))
                }

                if model.isResolvingPlayback {
                    Text(model.primaryPlayButtonTitle).font(.system(size: 18, weight: .semibold))
                } else if model.primaryPlayButtonShowsResume {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("继续播放").font(.system(size: 18, weight: .bold))
                        if let position = model.primaryPlayButtonPositionText {
                            Text("上次播放到：\(position)").font(.system(size: 12.5, weight: .medium))
                        }
                    }
                } else {
                    Text("播放").font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundColor(foreground)
        }
        .frame(width: width, height: 50)
        .clipShape(shape)
    }

    @ViewBuilder
    private func heroIdentity(width: CGFloat) -> some View {
        if let logoURL = logoImageURL {
            EmbyCachedRemoteImage(url: logoURL, contentMode: .fit)
                .frame(width: min(270, width), height: 82)
                .frame(width: width, height: 82)
        } else {
            fallbackHeroTitle(width: width)
        }
    }

    private func fallbackHeroTitle(width: CGFloat) -> some View {
        Text(model.item.name)
            .font(.system(size: 27, weight: .bold, design: .rounded))
            .foregroundColor(heroForeground)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(width: width)
            .frame(minHeight: 50)
    }

    private func heroTagScroller(width: CGFloat) -> some View {
        let contentWidth = max(0, width - 40)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 17) {
                ForEach(model.detailFilters) { filter in
                    NavigationLink(destination: EmbyDetailFilterResultsView(filter: filter, client: client)) {
                        Text(filter.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(heroSecondaryForeground)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minWidth: contentWidth, alignment: .center)
            .padding(.horizontal, 20)
        }
        .frame(width: width, height: 25)
    }

    private func detailActionRow(width: CGFloat) -> some View {
        HStack(spacing: 17) {
            actionButton(systemName: model.displayedPlayed ? "checkmark.circle.fill" : "checkmark.circle", active: model.displayedPlayed, label: model.displayedPlayed ? "标记为未看" : "标记为已看") { model.togglePlayed() }
            actionButton(systemName: model.displayedFavorite ? "heart.fill" : "heart", active: model.displayedFavorite, label: model.displayedFavorite ? "取消收藏" : "收藏") { model.toggleFavorite() }
            deferredAction(systemName: "arrow.down.circle", label: "下载")
            deferredAction(systemName: "film", label: "版本")
            deferredAction(systemName: "headphones", label: "音轨")
        }
        .frame(width: width, height: 32)
    }

    private func actionButton(systemName: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(active ? .blue : heroSecondaryForeground)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(DetailPressButtonStyle())
        .accessibilityLabel(label)
    }

    private func deferredAction(systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .regular))
            .foregroundColor(heroSecondaryForeground.opacity(0.56))
            .frame(width: 28, height: 28)
            .accessibilityLabel(label + "，后续实现")
    }

    private var persistentBackdrop: some View {
        GeometryReader { proxy in
            ZStack {
                EmbyCachedRemoteImage(url: heroImageURL, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(1.06)
                    .blur(radius: 30)
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.18 : 0.28),
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.40 : 0.50),
                        Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.60 : 0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private var heroForeground: Color { heroUsesLightForeground ? .white : .black }
    private var heroSecondaryForeground: Color { heroUsesLightForeground ? .white.opacity(0.78) : .black.opacity(0.72) }

    private func updateHeroImageMetrics(_ image: UIImage) {
        if heroSourceSize != image.size { heroSourceSize = image.size }
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        if heroUsesLightForeground != prefersLight {
            withAnimation(.easeOut(duration: 0.18)) { heroUsesLightForeground = prefersLight }
        }
    }

    private var heroImageURL: URL? {
        if !model.item.backdropImageTags.isEmpty { return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1800, tag: model.item.backdropImageTags.first, index: 0) }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1400, tag: model.item.preferredPrimaryImageTag)
    }

    private var logoImageURL: URL? {
        guard let logo = model.logoImage else { return nil }
        return client.imageURL(itemId: model.item.id, imageType: "Logo", maxWidth: 900, index: logo.imageIndex)
    }

    private var heroMetadataLine: String {
        var parts: [String] = []
        if let duration = model.item.durationSeconds, !model.isSeries { parts.append(formatDuration(duration)) }
        if let date = model.item.premiereDate, date.count >= 10 { parts.append(String(date.prefix(10))) }
        else if let year = model.item.productionYear { parts.append(String(year)) }
        if let rating = model.item.communityRating { parts.append("★ " + String(format: "%.1f", rating)) }
        if let official = model.item.officialRating, !official.isEmpty { parts.append(official) }
        if model.isSeries, !model.episodes.isEmpty { parts.append("\(model.episodes.count) 集") }
        return parts.isEmpty ? detailSubtitle(model.item) : parts.joined(separator: "   ")
    }

    @ViewBuilder
    private var overview: some View {
        if let text = model.normalizedOverview, !text.isEmpty {
            Button { showFullOverview = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.primary.opacity(0.82))
                        .lineLimit(4)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text("查看完整简介")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var seriesContent: some View {
        if model.isLoadingEpisodes && model.episodes.isEmpty {
            HStack { Spacer(); ProgressView("正在加载剧集…"); Spacer() }.padding(.vertical, 24).padding(.horizontal, 20)
        } else if !model.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 28) {
                upcomingEpisodesSection
                seasonsSection
            }
        }
    }

    private var upcomingEpisodesSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Text("即将播放").font(.title2.weight(.bold)).fixedSize()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(model.episodeRanges) { range in
                                Text(range.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                    .padding(.horizontal, 11)
                                    .frame(height: 31)
                                    .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                    .clipShape(Capsule())
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                    .highPriorityGesture(TapGesture().onEnded { jumpToEpisodeRange(range, proxy: proxy) })
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { jumpToEpisodeRange(range, proxy: proxy) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Button("查看全部") { showAllEpisodes = true }.font(.caption.weight(.semibold)).foregroundColor(.blue).fixedSize()
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(model.selectedSeasonEpisodes) { episode in episodePreviewCard(episode).id(episode.id) }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 165, alignment: .top)
            }
            .onAppear { scrollToInitialEpisodeIfNeeded(proxy) }
            .onChange(of: model.episodeScrollTargetID) { _ in scrollToInitialEpisodeIfNeeded(proxy) }
        }
    }

    private func scrollToInitialEpisodeIfNeeded(_ proxy: ScrollViewProxy) {
        guard let target = model.episodeScrollTargetID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target, anchor: .center) }
            model.consumeEpisodeScrollTarget(target)
        }
    }

    private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy) {
        let previousOffset = model.selectedEpisodeRangeOffset
        DiagnosticsLogger.shared.log("EpisodeRangeJump", "tap fromOffset=\(previousOffset) toOffset=\(range.startOffset) title=\(range.title)")
        model.selectEpisodeRange(range.startOffset)
        guard let target = model.episode(at: range.startOffset) else {
            DiagnosticsLogger.shared.log("EpisodeRangeJump", "target-missing offset=\(range.startOffset)")
            return
        }
        DispatchQueue.main.async {
            DiagnosticsLogger.shared.log("EpisodeRangeJump", "scroll target=\(target.id) offset=\(range.startOffset)")
            withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }
        }
    }

    private func episodePreviewCard(_ episode: LibraryItem) -> some View {
        let overview = model.normalizedOverview(for: episode) ?? ""
        return Button { model.selectEpisode(episode); Task { await model.play(episode) } } label: {
            VStack(alignment: .leading, spacing: 5) {
                EmbyDetailRemoteImage(url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: 174, height: 98)
                    .clipped()
                .frame(width: 174, height: 98)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(model.selectedEpisodeID == episode.id ? Color.blue : Color.clear, lineWidth: 2))

                Text(model.displayEpisodeTitle(episode))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 174, alignment: .leading)

                Text(overview.isEmpty ? " " : overview)
                    .font(.system(size: 10.75))
                    .foregroundColor(.secondary.opacity(0.72))
                    .lineLimit(3)
                    .lineSpacing(1.5)
                    .frame(width: 174, height: 42, alignment: .topLeading)
                    .opacity(overview.isEmpty ? 0 : 1)
            }
            .frame(width: 174, height: 165, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("季").font(.title2.weight(.bold)).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(model.seasonNumbers, id: \.self) { season in seasonCard(season) }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func seasonCard(_ season: Int) -> some View {
        let seasonItem = model.seasonItem(number: season)
        let count = model.seasonEpisodeCount(season)
        return Button {
            model.selectSeason(season)
            showAllEpisodes = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    EmbyDetailRemoteImage(url: seasonItem.flatMap { client.imageURL(itemId: $0.preferredPrimaryImageItemId, maxWidth: 420, tag: $0.preferredPrimaryImageTag) }, contentMode: .fill)
                        .frame(width: 106, height: 150)
                        .clipped()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if count > 0 {
                        Text(String(count)).font(.caption2.weight(.bold)).foregroundColor(.white).frame(minWidth: 29, minHeight: 29).background(Color.green).clipShape(Circle()).padding(6)
                    }
                }
                Text(seasonDisplayTitle(season, item: seasonItem)).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(1).frame(width: 106, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var castSection: some View {
        if !model.visiblePeople.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("演职人员").font(.title2.weight(.bold)).padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(model.visiblePeople) { person in
                            NavigationLink(destination: EmbyPersonMediaView(person: person, client: client)) { personCard(person) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func personCard(_ person: EmbyPerson) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            EmbyDetailRemoteImage(url: personImageURL(person), contentMode: .fill)
                .frame(width: 108, height: 136)
                .clipped()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(person.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(1).frame(width: 108, alignment: .leading)
            if let role = person.role, !role.isEmpty { Text("饰 " + role).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: 108, alignment: .leading) }
            else if let type = person.type, !type.isEmpty { Text(personTypeTitle(type)).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: 108, alignment: .leading) }
        }
    }

    private func personImageURL(_ person: EmbyPerson) -> URL? {
        guard let itemId = person.itemId, !itemId.isEmpty else { return nil }
        return client.imageURL(itemId: itemId, maxWidth: 360, tag: person.primaryImageTag)
    }

    @ViewBuilder
    private var mediaStreamInfoSection: some View {
        if !model.mediaStreams.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.34)) { mediaInfoExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Text("音视频字幕信息").font(.title2.weight(.bold)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(mediaInfoExpanded ? 180 : 0))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    if mediaInfoExpanded {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(Array(model.mediaStreams.enumerated()), id: \.offset) { index, stream in
                                    mediaStreamCard(stream, ordinal: index)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
    }

    private func mediaStreamCard(_ stream: MediaStream, ordinal: Int) -> some View {
        let rows = mediaInfoRows(for: stream)
        let style = mediaStreamStyle(stream, ordinal: ordinal)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: style.icon).font(.system(size: 16, weight: .semibold))
                Text(style.title).font(.headline)
            }
            .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(row.value)
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 308, alignment: .topLeading)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.045))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func mediaStreamStyle(_ stream: MediaStream, ordinal: Int) -> (title: String, icon: String) {
        let type = stream.type?.lowercased() ?? ""
        let base: (String, String)
        switch type {
        case "video": base = ("视频", "video.fill")
        case "audio": base = ("音频", "music.note")
        case "subtitle": base = ("字幕", "captions.bubble.fill")
        default: base = (stream.type ?? "媒体流", "waveform")
        }
        let sameType = model.mediaStreams.filter { ($0.type?.lowercased() ?? "") == type }
        guard sameType.count > 1 else { return base }
        let number = model.mediaStreams.prefix(ordinal + 1).filter { ($0.type?.lowercased() ?? "") == type }.count
        return ("\(base.0) #\(number)", base.1)
    }

    private func mediaInfoRows(for stream: MediaStream) -> [DetailMediaInfoRow] {
        var rows: [DetailMediaInfoRow] = []
        func add(_ label: String, _ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { rows.append(DetailMediaInfoRow(label: label, value: trimmed)) }
        }
        add("标题", stream.displayTitle)
        if let title = stream.title, title != stream.displayTitle { add("内嵌标题", title) }
        add("语言", stream.language)
        add("编解码器", stream.codec?.uppercased())
        let type = stream.type?.lowercased() ?? ""
        if type == "video" {
            add("配置", stream.profile)
            add("等级", stream.level.map(formatMediaDecimal))
            if let width = stream.width, let height = stream.height {
                add("分辨率", "\(width)×\(height)\(width >= 3500 ? " [4K]" : "")")
            }
            add("长宽比", stream.aspectRatio)
            add("交错", stream.isInterlaced.map(yesNo))
            add("帧率", (stream.realFrameRate ?? stream.averageFrameRate).map { "\(formatMediaDecimal($0)) fps" })
            add("比特率", stream.bitRate.map(formatMediaBitRate))
            add("视频范围", stream.videoRange ?? stream.videoRangeType)
            add("基色", stream.colorPrimaries)
            add("色域", stream.colorSpace)
            add("色偏", stream.colorTransfer)
            add("位深度", stream.bitDepth.map { "\($0) bit" })
            add("像素格式", stream.pixelFormat)
            add("参考帧", stream.refFrames.map(String.init))
        } else if type == "audio" {
            add("配置", stream.profile)
            add("布局", stream.channelLayout)
            add("频道", stream.channels.map { "\($0) ch" })
            add("比特率", stream.bitRate.map(formatMediaBitRate))
            add("采样率", stream.sampleRate.map { "\($0) Hz" })
            add("默认", stream.isDefault.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        } else if type == "subtitle" {
            add("默认", stream.isDefault.map(yesNo))
            add("强制", stream.isForced.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        } else {
            add("默认", stream.isDefault.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        }
        return rows
    }

    @ViewBuilder
    private var mediaSourceSummarySection: some View {
        if let source = model.primaryMediaSource, let mediaItem = model.mediaMetadataItem {
            Button {
                guard let path = source.path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.20)) { showRawMediaPath.toggle() }
            } label: {
                VStack(spacing: 7) {
                    if showRawMediaPath, let path = source.path, !path.isEmpty {
                        Text(path)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("点击返回媒体信息")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(mediaSourceDisplayName(source, item: mediaItem))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary.opacity(0.86))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(mediaSourceSecondaryLine(source, item: mediaItem))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.035))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    private func mediaSourceDisplayName(_ source: MediaSource, item: LibraryItem) -> String {
        if let path = source.path?.removingPercentEncoding, !path.isEmpty {
            let last = path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? ""
            let withoutQuery = last.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? last
            if withoutQuery.contains(".") && !withoutQuery.isEmpty { return withoutQuery }
        }
        if let name = source.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        if let container = source.container?.trimmingCharacters(in: .whitespacesAndNewlines), !container.isEmpty { return "\(item.name).\(container.lowercased())" }
        return item.name
    }

    private func mediaSourceSecondaryLine(_ source: MediaSource, item: LibraryItem) -> String {
        var parts: [String] = []
        parts.append(client.serverName ?? client.baseURL.host ?? "Emby")
        if let date = formatMediaDate(item.dateCreated) { parts.append(date) }
        if let size = source.size, size > 0 { parts.append(formatMediaSize(size)) }
        return parts.joined(separator: "  ")
    }

    private func formatMediaDate(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: value)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: value)
        }
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func formatMediaSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes) B"
    }

    private func formatMediaBitRate(_ bitsPerSecond: Int) -> String {
        if bitsPerSecond >= 1_000_000 { return String(format: "%.2f Mbps", Double(bitsPerSecond) / 1_000_000) }
        return "\(max(0, bitsPerSecond / 1_000)) kbps"
    }

    private func formatMediaDecimal(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 { return String(Int(value.rounded())) }
        return String(format: "%.2f", value).replacingOccurrences(of: "0+$", with: "", options: .regularExpression).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    private func yesNo(_ value: Bool) -> String { value ? "是" : "否" }

    @ViewBuilder
    private var tagSection: some View {
        if !model.detailFilters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("标签").font(.title2.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(model.detailFilters) { filter in
                        NavigationLink(destination: EmbyDetailFilterResultsView(filter: filter, client: client)) {
                            HStack(spacing: 7) {
                                Image(systemName: "tag")
                                Text(filter.name).lineLimit(1)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary.opacity(0.84))
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .background(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var stillsSection: some View {
        if !model.stillImages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("剧照").font(.title2.weight(.bold)).padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(model.stillImages.enumerated()), id: \.element.id) { index, info in
                            Button { selectedStillIndex = index } label: {
                                EmbyDetailRemoteImage(url: client.imageURL(itemId: model.item.id, imageType: info.imageType, maxWidth: 900, index: info.imageIndex), contentMode: .fill)
                                    .frame(width: 248, height: 140)
                                    .clipped()
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(DetailPressButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private var similarSection: some View {
        if !model.similarItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.isSeries ? "更多类似" : "相似作品").font(.title2.weight(.bold)).padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(model.similarItems) { similar in
                            NavigationLink(destination: EmbyMediaDetailView(item: similar, client: client)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    EmbyDetailRemoteImage(url: client.imageURL(itemId: similar.preferredPrimaryImageItemId, maxWidth: 420, tag: similar.preferredPrimaryImageTag), contentMode: .fill)
                                        .frame(width: 112, height: 168)
                                        .clipped()
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    Text(similar.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(1).frame(width: 112, alignment: .leading)
                                    if let year = similar.productionYear { Text(String(year)).font(.caption).foregroundColor(.secondary) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func detailSubtitle(_ item: LibraryItem) -> String {
        switch item.type?.lowercased() {
        case "movie": return "电影"
        case "series": return "电视剧"
        case "episode": return "剧集"
        case "boxset": return "合集"
        default: return item.type ?? "媒体"
        }
    }

    private func personTypeTitle(_ value: String) -> String {
        switch value.lowercased() {
        case "actor": return "演员"
        case "director": return "导演"
        case "writer": return "编剧"
        case "producer": return "制片"
        default: return value
        }
    }

    private func seasonDisplayTitle(_ season: Int, item: LibraryItem?) -> String {
        if let name = item?.name, !name.isEmpty { return name }
        return season == 0 ? "特别篇" : "第 \(season) 季"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时" }
        return "\(minutes)分钟"
    }
}

private struct DetailMediaInfoRow: Identifiable {
    let label: String
    let value: String
    var id: String { "\(label)|\(value)" }
}

struct EmbyDetailFilter: Identifiable, Hashable {
    let name: String
    let isGenre: Bool
    var id: String { "\(isGenre ? "genre" : "tag")|\(name)" }
}

private struct EmbyDetailFilterResultsView: View {
    let filter: EmbyDetailFilter
    let client: EmbyAPIClient
    @StateObject private var model: EmbyDetailFilterResultsViewModel

    init(filter: EmbyDetailFilter, client: EmbyAPIClient) {
        self.filter = filter
        self.client = client
        _model = StateObject(wrappedValue: EmbyDetailFilterResultsViewModel(filter: filter, client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.isInitialLoading && model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 44) }
                else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        EmbyPosterDetailLink(item: item, client: client) {
                            EmbyDetailPosterCard(item: item, client: client)
                        }
                    }
                }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 86)
        }
        .navigationBarHidden(false)
        .navigationTitle(filter.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }
}

@MainActor
private final class EmbyDetailFilterResultsViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isInitialLoading = false
    @Published var errorMessage: String?
    private(set) var hasMore = true
    private let filter: EmbyDetailFilter
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var isFetching = false
    private var seenItemIDs = Set<String>()
    private(set) var hasLoaded = false

    init(filter: EmbyDetailFilter, client: EmbyAPIClient) {
        self.filter = filter
        self.client = client
    }

    func reload() async {
        guard !isFetching else { return }
        items = []
        seenItemIDs.removeAll(keepingCapacity: true)
        nextStartIndex = 0
        hasMore = true
        hasLoaded = false
        await fetchNextPage()
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isFetching else { return }
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isFetching, hasMore else { return }
        isFetching = true
        if items.isEmpty { isInitialLoading = true }
        if errorMessage != nil { errorMessage = nil }
        let start = nextStartIndex
        defer {
            isFetching = false
            if isInitialLoading { isInitialLoading = false }
            hasLoaded = true
        }
        do {
            let page = try await client.detailItems(filter: filter.name, isGenre: filter.isGenre, limit: pageSize, startIndex: start)
            let newItems = page.items.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems) }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}

private struct EmbyDetailPosterCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    private var width: CGFloat { gridCellWidth ?? 118 }
    private var height: CGFloat { floor(width / EmbyPosterGridMetrics.posterAspectRatio) }
    private var imageMaxWidth: Int { min(440, max(1, Int(ceil(width * UIScreen.main.scale)))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EmbyDetailRemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: imageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name).font(.subheadline).lineLimit(1).frame(width: width, height: 20, alignment: .leading)
            Text(item.productionYear.map(String.init) ?? " ").font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: width, height: 16, alignment: .leading).opacity(item.productionYear == nil ? 0 : 1)
        }
        .frame(width: width, alignment: .leading)
    }
}

@MainActor
final class EmbyMediaDetailViewModel: ObservableObject {
    @Published var item: LibraryItem
    @Published var episodes: [LibraryItem] = []
    @Published var seasons: [LibraryItem] = []
    @Published var imageInfos: [EmbyImageInfo] = []
    @Published var similarItems: [LibraryItem] = []
    @Published var selectedSeason: Int?
    @Published var selectedEpisodeRangeOffset = 0
    @Published var selectedEpisodeID: String?
    @Published var episodeScrollTargetID: String?
    @Published var errorMessage: String?
    @Published var isLoadingEpisodes = false
    @Published var isResolvingPlayback = false
    @Published var selectedSource: ResolvedPlaybackSource?
    @Published var mediaSources: [MediaSource] = []
    @Published var mediaMetadataItem: LibraryItem?
    @Published private var desiredFavorite: Bool
    @Published private var desiredPlayed: Bool
    @Published private var hasPlaybackPositionOverride = false
    @Published private var playbackPositionOverrideTicks: Int64?
    private var syncedFavorite: Bool
    private var syncedPlayed: Bool
    private var favoriteSyncTask: Task<Void, Never>?
    private var playedSyncTask: Task<Void, Never>?
    private let client: EmbyAPIClient
    private let initialEpisodeID: String?
    private(set) var hasLoaded = false

    init(item: LibraryItem, client: EmbyAPIClient, initialEpisodeID: String? = nil) {
        self.item = item
        self.client = client
        self.initialEpisodeID = initialEpisodeID
        self.desiredFavorite = item.isFavorite
        self.desiredPlayed = item.isPlayed
        self.syncedFavorite = item.isFavorite
        self.syncedPlayed = item.isPlayed
    }

    var isSeries: Bool { item.type?.caseInsensitiveCompare("Series") == .orderedSame }
    var isPlayable: Bool { ["movie", "episode", "video", "trailer"].contains(item.type?.lowercased() ?? "") }
    var displayedFavorite: Bool { desiredFavorite }
    var displayedPlayed: Bool { desiredPlayed }
    var normalizedOverview: String? { normalizedOverview(for: item) }
    var primaryMediaSource: MediaSource? { mediaSources.first(where: { $0.supportsDirectPlay == true }) ?? mediaSources.first }
    var mediaStreams: [MediaStream] {
        let streams = primaryMediaSource?.mediaStreams ?? []
        func priority(_ stream: MediaStream) -> Int {
            switch stream.type?.lowercased() {
            case "video": return 0
            case "audio": return 1
            case "subtitle": return 2
            default: return 3
            }
        }
        return streams.sorted { lhs, rhs in
            let lp = priority(lhs), rp = priority(rhs)
            if lp != rp { return lp < rp }
            return (lhs.index ?? Int.max) < (rhs.index ?? Int.max)
        }
    }

    func normalizedOverview(for item: LibraryItem) -> String? {
        guard let overview = item.overview else { return nil }
        let normalized = overview
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    var detailFilters: [EmbyDetailFilter] {
        var result: [EmbyDetailFilter] = []
        var seen = Set<String>()
        for genre in item.genres {
            let trimmed = genre.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "genre|\(trimmed.lowercased())"
            if !trimmed.isEmpty && seen.insert(key).inserted { result.append(EmbyDetailFilter(name: trimmed, isGenre: true)) }
        }
        for tag in item.tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "tag|\(trimmed.lowercased())"
            if !trimmed.isEmpty && seen.insert(key).inserted { result.append(EmbyDetailFilter(name: trimmed, isGenre: false)) }
        }
        return result
    }

    var logoImage: EmbyImageInfo? { imageInfos.first { $0.imageType.caseInsensitiveCompare("Logo") == .orderedSame } }

    var seasonNumbers: [Int] {
        let explicitSeasons = Set(seasons.compactMap(\.indexNumber))
        if !explicitSeasons.isEmpty { return explicitSeasons.sorted() }
        return Set(episodes.compactMap(\.parentIndexNumber)).sorted()
    }

    var selectedSeasonEpisodes: [LibraryItem] {
        guard let season = selectedSeason else { return episodes }
        return episodes.filter { episodeBelongsToSeason($0, season: season) }
    }

    var episodeRanges: [EmbyEpisodeRange] {
        let items = selectedSeasonEpisodes
        guard !items.isEmpty else { return [] }
        var ranges: [EmbyEpisodeRange] = []
        var offset = 0
        while offset < items.count {
            let end = min(items.count, offset + 10)
            let slice = Array(items[offset..<end])
            let first = slice.first?.indexNumber ?? offset + 1
            let last = slice.last?.indexNumber ?? end
            ranges.append(EmbyEpisodeRange(startOffset: offset, endOffset: end, firstNumber: first, lastNumber: last))
            offset = end
        }
        return ranges
    }

    var selectedSeasonTitle: String {
        guard let season = selectedSeason else { return "剧集" }
        return season == 0 ? "特别篇" : "第 \(season) 季"
    }

    var visiblePeople: [EmbyPerson] { Array(item.people.prefix(24)) }

    var stillImages: [EmbyImageInfo] {
        let screenshots = imageInfos.filter { $0.imageType.caseInsensitiveCompare("Screenshot") == .orderedSame }
        let backdrops = imageInfos.filter { $0.imageType.caseInsensitiveCompare("Backdrop") == .orderedSame }
        return Array((screenshots + backdrops).prefix(20))
    }

    var primaryPlayableItem: LibraryItem? {
        if isPlayable { return item }
        guard isSeries else { return nil }
        if let selectedEpisodeID, let selected = episodes.first(where: { $0.id == selectedEpisodeID }) { return selected }
        if let resume = episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed }) { return resume }
        if let unplayed = episodes.first(where: { !$0.isPlayed }) { return unplayed }
        return episodes.first
    }

    var primaryPlayButtonShowsResume: Bool {
        guard !displayedPlayed, let playable = primaryPlayableItem else { return false }
        return effectivePlaybackProgress(for: playable) > 0.001
    }

    var primaryPlayButtonProgress: Double {
        guard primaryPlayButtonShowsResume, let playable = primaryPlayableItem else { return 0 }
        return min(1, max(0, effectivePlaybackProgress(for: playable)))
    }

    var primaryPlayButtonPositionText: String? {
        guard primaryPlayButtonShowsResume, let playable = primaryPlayableItem, let ticks = effectivePlaybackPositionTicks(for: playable), ticks > 0 else { return nil }
        let total = max(0, Int(Double(ticks) / AppIdentity.ticksPerSecond))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func effectivePlaybackPositionTicks(for playable: LibraryItem) -> Int64? {
        if playable.id == item.id && hasPlaybackPositionOverride { return playbackPositionOverrideTicks }
        return playable.userData?.playbackPositionTicks
    }

    private func effectivePlaybackProgress(for playable: LibraryItem) -> Double {
        guard let runTimeTicks = playable.runTimeTicks, runTimeTicks > 0, let position = effectivePlaybackPositionTicks(for: playable), position > 0 else { return 0 }
        return min(1, max(0, Double(position) / Double(runTimeTicks)))
    }

    var primaryPlayButtonTitle: String {
        if isResolvingPlayback { return "正在准备播放…" }
        return primaryPlayButtonShowsResume ? "继续播放" : "播放"
    }

    func seasonItem(number: Int) -> LibraryItem? { seasons.first { $0.indexNumber == number } }

    private func seasonNumber(for episode: LibraryItem) -> Int? {
        if let seasonID = episode.seasonId, let season = seasons.first(where: { $0.id == seasonID }), let number = season.indexNumber { return number }
        return episode.parentIndexNumber
    }

    private func episodeBelongsToSeason(_ episode: LibraryItem, season number: Int) -> Bool {
        if let episodeSeasonID = episode.seasonId, let season = seasonItem(number: number) { return episodeSeasonID == season.id }
        return episode.parentIndexNumber == number
    }

    func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { episodeBelongsToSeason($1, season: season) ? $0 + 1 : $0 } }
    func episode(at offset: Int) -> LibraryItem? { selectedSeasonEpisodes.indices.contains(offset) ? selectedSeasonEpisodes[offset] : nil }

    func selectSeason(_ season: Int) {
        selectedSeason = season
        selectedEpisodeRangeOffset = 0
        selectedEpisodeID = nil
        episodeScrollTargetID = nil
    }

    func selectEpisodeRange(_ offset: Int) { selectedEpisodeRangeOffset = max(0, offset); selectedEpisodeID = nil; episodeScrollTargetID = nil }
    func selectEpisode(_ episode: LibraryItem) { selectedEpisodeID = episode.id }
    func consumeEpisodeScrollTarget(_ itemID: String) { if episodeScrollTargetID == itemID { episodeScrollTargetID = nil } }

    func displayEpisodeTitle(_ episode: LibraryItem) -> String {
        let number = episode.indexNumber ?? (selectedSeasonEpisodes.firstIndex(where: { $0.id == episode.id }).map { $0 + 1 } ?? 0)
        let trimmed = episode.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if number <= 0 { return trimmed.isEmpty ? "剧集" : trimmed }
        if trimmed.isEmpty || isGenericEpisodeName(trimmed, number: number) { return "\(number).\(fallbackEpisodeName(number))" }
        return "\(number).\(trimmed)"
    }

    private func isGenericEpisodeName(_ name: String, number: Int) -> Bool {
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "")
        let candidates = ["episode\(number)", "ep\(number)", "e\(number)", "第\(number)集", String(number)]
        return candidates.contains(normalized)
    }

    private func fallbackEpisodeName(_ number: Int) -> String { "第\(chineseNumber(number))集" }

    private func chineseNumber(_ number: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        guard number > 0 else { return String(number) }
        if number < 10 { return digits[number] }
        if number == 10 { return "十" }
        if number < 20 { return "十" + digits[number % 10] }
        if number < 100 {
            let tens = digits[number / 10] + "十"
            return number % 10 == 0 ? tens : tens + digits[number % 10]
        }
        return String(number)
    }

    func load() async {
        guard !hasLoaded else { return }
        errorMessage = nil
        do {
            let refreshed = try await client.libraryItem(itemId: item.id)
            item = refreshed
            if favoriteSyncTask == nil { syncedFavorite = refreshed.isFavorite; desiredFavorite = refreshed.isFavorite }
            if playedSyncTask == nil { syncedPlayed = refreshed.isPlayed; desiredPlayed = refreshed.isPlayed }

            if refreshed.type?.caseInsensitiveCompare("Series") == .orderedSame {
                isLoadingEpisodes = true
                do { episodes = try await client.seriesEpisodes(seriesId: refreshed.id) }
                catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
                do { seasons = try await client.seriesSeasons(seriesId: refreshed.id) }
                catch { if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "seasons failed: \(error.localizedDescription)") } }
                isLoadingEpisodes = false

                if let initialEpisodeID, let requestedEpisode = episodes.first(where: { $0.id == initialEpisodeID }), let season = seasonNumber(for: requestedEpisode) {
                    selectedSeason = season
                    selectedEpisodeID = requestedEpisode.id
                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == requestedEpisode.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
                    episodeScrollTargetID = requestedEpisode.id
                } else if let playable = primaryPlayableItem, let season = seasonNumber(for: playable) {
                    selectedSeason = season
                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == playable.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
                } else if selectedSeason == nil {
                    selectedSeason = seasonNumbers.first
                }
                logEpisodeDiagnostics(seriesID: refreshed.id)
            }

            await loadMediaMetadata(for: primaryPlayableItem)

            do { imageInfos = try await client.imageInfos(itemId: refreshed.id) }
            catch { if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "image info failed: \(error.localizedDescription)") } }

            let similarTypes = refreshed.type?.caseInsensitiveCompare("Series") == .orderedSame ? ["Series"] : ["Movie", "Video"]
            do { similarItems = try await client.similarItems(itemId: refreshed.id, includeItemTypes: similarTypes) }
            catch { if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "similar items failed: \(error.localizedDescription)") } }
            hasLoaded = true
        } catch {
            if isEmbyRequestCancellation(error) { return }
            hasLoaded = true
            errorMessage = error.localizedDescription
        }
    }

    private func logEpisodeDiagnostics(seriesID: String) {
        func countByOptionalInt(_ values: [Int?]) -> String {
            var counts: [String: Int] = [:]
            for value in values { counts[value.map(String.init) ?? "nil", default: 0] += 1 }
            return counts.sorted { lhs, rhs in
                if lhs.key == "nil" { return true }
                if rhs.key == "nil" { return false }
                return (Int(lhs.key) ?? Int.max) < (Int(rhs.key) ?? Int.max)
            }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        }

        func countByOptionalString(_ values: [String?]) -> String {
            var counts: [String: Int] = [:]
            for value in values { counts[value ?? "nil", default: 0] += 1 }
            let sorted = counts.sorted { lhs, rhs in
                if lhs.key == "nil" { return true }
                if rhs.key == "nil" { return false }
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            let visible = sorted.prefix(12).map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            return sorted.count > 12 ? visible + ",...groups=\(sorted.count)" : visible
        }

        func sample(_ episode: LibraryItem) -> String {
            let compactName = episode.name.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
            let name = String(compactName.prefix(48))
            return "id=\(episode.id)|name=\(name)|index=\(episode.indexNumber.map(String.init) ?? "nil")|parentIndex=\(episode.parentIndexNumber.map(String.init) ?? "nil")|seasonId=\(episode.seasonId ?? "nil")|parentId=\(episode.parentId ?? "nil")|seriesId=\(episode.seriesId ?? "nil")"
        }

        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episodeBelongsToSeason(episode, season: season) ? subtotal + 1 : subtotal } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episodeBelongsToSeason(episode, season: season) ? subtotal : subtotal + 1 } } ?? 0
        let nilIndexCount = episodes.reduce(0) { subtotal, episode in episode.indexNumber == nil ? subtotal + 1 : subtotal }
        let wrongSeriesCount = episodes.reduce(0) { subtotal, episode in
            guard let episodeSeriesID = episode.seriesId else { return subtotal }
            return episodeSeriesID == seriesID ? subtotal : subtotal + 1
        }

        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) episodesTotal=\(episodes.count) seasonsTotal=\(seasons.count) selectedSeason=\(selectedSeason.map(String.init) ?? "nil") selectedCount=\(selectedCount) unmatched=\(unmatchedCount) nilIndex=\(nilIndexCount) wrongSeries=\(wrongSeriesCount)")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) parentIndex={\(countByOptionalInt(episodes.map(\.parentIndexNumber)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) seasonId={\(countByOptionalString(episodes.map(\.seasonId)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) parentId={\(countByOptionalString(episodes.map(\.parentId)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) seasonIndex={\(countByOptionalInt(seasons.map(\.indexNumber)))}")
        for (index, episode) in episodes.prefix(5).enumerated() { DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) sampleFirst[\(index)]=\(sample(episode))") }
        let tail = Array(episodes.suffix(5))
        for (index, episode) in tail.enumerated() { DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) sampleLast[\(index)]=\(sample(episode))") }
    }

    private func loadMediaMetadata(for mediaItem: LibraryItem?) async {
        guard let mediaItem else {
            mediaSources = []
            mediaMetadataItem = nil
            return
        }
        do {
            let info = try await client.playbackInfo(itemId: mediaItem.id)
            mediaSources = info.mediaSources
            mediaMetadataItem = mediaItem
        } catch {
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "media metadata failed: \(error.localizedDescription)") }
        }
    }

    func toggleFavorite() {
        desiredFavorite.toggle()
        DetailHaptics.selection()
        startFavoriteSyncIfNeeded()
    }

    func togglePlayed() {
        desiredPlayed.toggle()
        if !desiredPlayed {
            hasPlaybackPositionOverride = true
            playbackPositionOverrideTicks = 0
        }
        DetailHaptics.selection()
        startPlayedSyncIfNeeded()
    }

    private func startFavoriteSyncIfNeeded() {
        guard favoriteSyncTask == nil else { return }
        favoriteSyncTask = Task { [weak self] in await self?.syncFavoriteLoop() }
    }

    private func startPlayedSyncIfNeeded() {
        guard playedSyncTask == nil else { return }
        playedSyncTask = Task { [weak self] in await self?.syncPlayedLoop() }
    }

    private func syncFavoriteLoop() async {
        while desiredFavorite != syncedFavorite {
            let target = desiredFavorite
            do {
                try await client.setFavorite(itemId: item.id, favorite: target)
                syncedFavorite = target
            } catch {
                desiredFavorite = syncedFavorite
                if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
                break
            }
        }
        favoriteSyncTask = nil
        if desiredFavorite != syncedFavorite { startFavoriteSyncIfNeeded() }
    }

    private func syncPlayedLoop() async {
        while desiredPlayed != syncedPlayed {
            let target = desiredPlayed
            do {
                let changedItemID = item.id
                try await client.setPlayed(itemId: changedItemID, played: target)
                syncedPlayed = target
                if let refreshed = try? await client.libraryItem(itemId: changedItemID) { item = refreshed }
                if !target || !desiredPlayed {
                    hasPlaybackPositionOverride = true
                    playbackPositionOverrideTicks = 0
                } else {
                    hasPlaybackPositionOverride = false
                    playbackPositionOverrideTicks = nil
                }
                NotificationCenter.default.post(
                    name: EmbyUserDataChange.notification,
                    object: client,
                    userInfo: [
                        EmbyUserDataChange.itemIDKey: changedItemID,
                        EmbyUserDataChange.reasonKey: EmbyUserDataChange.manualPlayedReason,
                    ]
                )
            } catch {
                desiredPlayed = syncedPlayed
                if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
                break
            }
        }
        playedSyncTask = nil
        if desiredPlayed != syncedPlayed { startPlayedSyncIfNeeded() }
    }

    func refreshPlaybackUserData(itemID: String) async {
        do {
            let refreshed = try await client.libraryItem(itemId: itemID)
            if item.id == itemID {
                item = refreshed
                hasPlaybackPositionOverride = false
                playbackPositionOverrideTicks = nil
                syncedPlayed = refreshed.isPlayed
                desiredPlayed = refreshed.isPlayed
            } else if let index = episodes.firstIndex(where: { $0.id == itemID }) {
                episodes[index] = refreshed
            }
            DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refreshed item=\(itemID) positionTicks=\(refreshed.userData?.playbackPositionTicks ?? 0)")
        } catch {
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refresh failed item=\(itemID): \(error.localizedDescription)") }
        }
    }

    func play(_ mediaItem: LibraryItem) async {
        guard !isResolvingPlayback else { return }
        isResolvingPlayback = true
        errorMessage = nil
        defer { isResolvingPlayback = false }
        do {
            let info = try await client.playbackInfo(itemId: mediaItem.id)
            guard let source = info.mediaSources.first(where: { $0.supportsDirectPlay == true }) ?? info.mediaSources.first else { throw EmbyAPIError.noMediaSource }
            selectedSource = try client.resolvePlaybackSource(itemId: mediaItem.id, itemName: mediaItem.name, mediaSource: source, playSessionId: info.playSessionId)
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}

private struct EmbyDetailRemoteImage: View {
    let url: URL?
    let contentMode: ContentMode

    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode) }
}
