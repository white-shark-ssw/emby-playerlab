import SwiftUI
import Combine

private struct EmbyEpisodeRange: Identifiable, Hashable {
    let startOffset: Int
    let endOffset: Int
    let firstNumber: Int
    let lastNumber: Int
    var id: Int { startOffset }
    var title: String { firstNumber == lastNumber ? String(firstNumber) : "\(firstNumber)-\(lastNumber)" }
}

private struct EmbyStillSelection: Identifiable {
    let index: Int
    var id: Int { index }
}

struct EmbyMediaDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    let item: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: EmbyMediaDetailViewModel
    @State private var showFullOverview = false
    @State private var showAllEpisodes = false
    @State private var selectedStill: EmbyStillSelection?

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ImmersiveBackdrop(url: heroImageURL, overlayOpacity: colorScheme == .dark ? 0.44 : 0.55)

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)
                        VStack(alignment: .leading, spacing: 24) {
                            overview
                            if model.isSeries { seriesContent }
                            castSection
                            tagSection
                            stillsSection
                            similarSection
                            if let error = model.errorMessage { errorView(error) }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 16))
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)
                .background(Color.clear)
                .ignoresSafeArea(edges: [.top, .bottom])

                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, geometry.safeAreaInsets.top + ImmersiveUIMetrics.topControlPadding)
                    .frame(width: geometry.size.width)
                    .zIndex(20)

                NavigationLink(destination: EmbyEpisodePickerView(model: model, client: client), isActive: $showAllEpisodes) { EmptyView() }
                    .frame(width: 0, height: 0)
                    .hidden()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .navigationBarHidden(true)
        .nativeInteractivePop()
        .task { await model.load() }
        .fullScreenCover(isPresented: $showFullOverview) {
            EmbyOverviewOverlayView(text: model.normalizedOverview ?? "", backdropURL: heroImageURL)
        }
        .fullScreenCover(item: $selectedStill) { selection in
            EmbyStillViewer(images: model.stillImages, initialIndex: selection.index, itemId: model.item.id, client: client)
        }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private var topBar: some View {
        HStack {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: ImmersiveUIMetrics.topControlVisualSize, height: ImmersiveUIMetrics.topControlVisualSize)
                    .background(Color.black.opacity(0.50))
                    .clipShape(Circle())
                    .frame(width: ImmersiveUIMetrics.topControlHitSize, height: ImmersiveUIMetrics.topControlHitSize)
            }
            .buttonStyle(DetailPressButtonStyle())
            Spacer()
        }
    }

    private func hero(width: CGFloat) -> some View {
        let heroHeight = min(488, max(430, width * 1.08))
        let contentWidth = max(0, width - 40)
        return ZStack(alignment: .bottom) {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(width: width, height: heroHeight)
                .clipped()
                .mask(LinearGradient(colors: [.black, .black, .black.opacity(0.94), .black.opacity(0.52), .clear], startPoint: .top, endPoint: .bottom))

            VStack(spacing: 9) {
                heroIdentity(width: contentWidth)

                Text(heroMetadataLine)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: contentWidth)

                if !model.detailFilters.isEmpty { heroTagScroller(width: width) }

                if let playableItem = model.primaryPlayableItem {
                    Button { Task { await model.play(playableItem) } } label: {
                        HStack(spacing: 9) {
                            if model.isResolvingPlayback { ProgressView().tint(.white) }
                            else { Image(systemName: "play.fill").font(.system(size: 15, weight: .bold)) }
                            Text(model.primaryPlayButtonTitle).font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(width: contentWidth, height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(DetailPressButtonStyle())
                    .disabled(model.isResolvingPlayback)
                }

                detailActionRow(width: contentWidth)
            }
            .frame(width: width)
            .padding(.bottom, 6)
        }
        .frame(width: width, height: heroHeight)
    }

    @ViewBuilder
    private func heroIdentity(width: CGFloat) -> some View {
        if let logoURL = logoImageURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit().frame(width: min(270, width), height: 82)
                default: fallbackHeroTitle(width: width)
                }
            }
            .frame(width: width, height: 82)
        } else {
            fallbackHeroTitle(width: width)
        }
    }

    private func fallbackHeroTitle(width: CGFloat) -> some View {
        Text(model.item.name)
            .font(.system(size: 27, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(width: width)
            .frame(minHeight: 50)
    }

    private func heroTagScroller(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 17) {
                ForEach(model.detailFilters) { filter in
                    NavigationLink(destination: EmbyDetailFilterResultsView(filter: filter, client: client)) {
                        Text(filter.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.92))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
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
                .foregroundColor(active ? .blue : .secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(DetailPressButtonStyle())
        .accessibilityLabel(label)
    }

    private func deferredAction(systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .regular))
            .foregroundColor(.secondary.opacity(0.46))
            .frame(width: 28, height: 28)
            .accessibilityLabel(label + "，后续实现")
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
                                Button {
                                    model.selectEpisodeRange(range.startOffset)
                                    if let target = model.episode(at: range.startOffset) {
                                        withAnimation(.easeInOut(duration: 0.32)) { proxy.scrollTo(target.id, anchor: .leading) }
                                    }
                                } label: {
                                    Text(range.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .frame(height: 31)
                                        .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
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
            }
        }
    }

    private func episodePreviewCard(_ episode: LibraryItem) -> some View {
        Button { Task { await model.play(episode) } } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    EmbyDetailRemoteImage(url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag), contentMode: .fill)
                        .frame(width: 174, height: 98)
                        .clipped()
                    if episode.playbackProgress > 0 {
                        VStack { Spacer(); GeometryReader { proxy in Rectangle().fill(Color.blue).frame(width: proxy.size.width * episode.playbackProgress, height: 3) } }
                    }
                }
                .frame(width: 174, height: 98)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(model.displayEpisodeTitle(episode))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 174, alignment: .leading)

                if let text = model.normalizedOverview(for: episode), !text.isEmpty {
                    Text(text)
                        .font(.system(size: 10.75))
                        .foregroundColor(.secondary.opacity(0.72))
                        .lineLimit(3)
                        .lineSpacing(1.5)
                        .frame(width: 174, alignment: .leading)
                        .frame(minHeight: 41, alignment: .topLeading)
                }
            }
            .frame(width: 174, alignment: .topLeading)
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
                            Button { selectedStill = EmbyStillSelection(index: index) } label: {
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

private struct EmbyDetailFilter: Identifiable, Hashable {
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
                if model.isLoading && model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 44) }
                else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { EmbyDetailPosterCard(item: item, client: client) }.buttonStyle(.plain)
                    }
                }
                if model.isLoading && !model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 24)
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasMore = true
    private let filter: EmbyDetailFilter
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private(set) var hasLoaded = false

    init(filter: EmbyDetailFilter, client: EmbyAPIClient) {
        self.filter = filter
        self.client = client
    }

    func reload() async {
        guard !isLoading else { return }
        items = []
        nextStartIndex = 0
        hasMore = true
        hasLoaded = false
        await fetchNextPage()
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        let start = nextStartIndex
        defer { isLoading = false; hasLoaded = true }
        do {
            let page = try await client.detailItems(filter: filter.name, isGenre: filter.isGenre, limit: pageSize, startIndex: start)
            var seen = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EmbyDetailRemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 440, tag: item.preferredPrimaryImageTag), contentMode: .fill)
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
    @Published var errorMessage: String?
    @Published var isLoadingEpisodes = false
    @Published var isResolvingPlayback = false
    @Published var selectedSource: ResolvedPlaybackSource?
    @Published private var desiredFavorite: Bool
    @Published private var desiredPlayed: Bool
    private var syncedFavorite: Bool
    private var syncedPlayed: Bool
    private var favoriteSyncTask: Task<Void, Never>?
    private var playedSyncTask: Task<Void, Never>?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        self.desiredFavorite = item.isFavorite
        self.desiredPlayed = item.isPlayed
        self.syncedFavorite = item.isFavorite
        self.syncedPlayed = item.isPlayed
    }

    var isSeries: Bool { item.type?.caseInsensitiveCompare("Series") == .orderedSame }
    var isPlayable: Bool { ["movie", "episode", "video"].contains(item.type?.lowercased() ?? "") }
    var displayedFavorite: Bool { desiredFavorite }
    var displayedPlayed: Bool { desiredPlayed }
    var normalizedOverview: String? { normalizedOverview(for: item) }

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
        let values = Set(episodes.compactMap(\.parentIndexNumber) + seasons.compactMap(\.indexNumber))
        return values.sorted()
    }

    var selectedSeasonEpisodes: [LibraryItem] {
        guard let season = selectedSeason else { return episodes }
        return episodes.filter { $0.parentIndexNumber == season }
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
        if let resume = episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed }) { return resume }
        if let unplayed = episodes.first(where: { !$0.isPlayed }) { return unplayed }
        return episodes.first
    }

    var primaryPlayButtonTitle: String {
        if isResolvingPlayback { return "正在准备播放…" }
        if isSeries, let episode = primaryPlayableItem {
            let index = episode.indexNumber.map { "E\($0)" } ?? ""
            return episode.playbackProgress > 0.001 ? "继续播放 \(index)" : "播放 \(index)"
        }
        return item.playbackProgress > 0.001 ? "继续播放" : "播放"
    }

    func seasonItem(number: Int) -> LibraryItem? { seasons.first { $0.indexNumber == number } }
    func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { $1.parentIndexNumber == season ? $0 + 1 : $0 } }
    func episode(at offset: Int) -> LibraryItem? { selectedSeasonEpisodes.indices.contains(offset) ? selectedSeasonEpisodes[offset] : nil }

    func selectSeason(_ season: Int) {
        selectedSeason = season
        selectedEpisodeRangeOffset = 0
    }

    func selectEpisodeRange(_ offset: Int) { selectedEpisodeRangeOffset = max(0, offset) }

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

                if let playable = primaryPlayableItem, let season = playable.parentIndexNumber {
                    selectedSeason = season
                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == playable.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
                } else if selectedSeason == nil {
                    selectedSeason = seasonNumbers.first
                }
            }

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

    func toggleFavorite() {
        desiredFavorite.toggle()
        DetailHaptics.selection()
        startFavoriteSyncIfNeeded()
    }

    func togglePlayed() {
        desiredPlayed.toggle()
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
                try await client.setPlayed(itemId: item.id, played: target)
                syncedPlayed = target
            } catch {
                desiredPlayed = syncedPlayed
                if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
                break
            }
        }
        playedSyncTask = nil
        if desiredPlayed != syncedPlayed { startPlayedSyncIfNeeded() }
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

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().aspectRatio(contentMode: contentMode)
            case .failure: placeholder
            case .empty: ZStack { placeholder; ProgressView() }
            @unknown default: placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "photo").font(.system(size: 26, weight: .medium)).foregroundColor(.secondary.opacity(0.6))
        }
    }
}
