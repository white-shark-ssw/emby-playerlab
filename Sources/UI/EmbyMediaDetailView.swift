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

private struct EmbyEpisodeJump: Identifiable {
    let label: Int
    let episode: LibraryItem
    var id: String { episode.id }
}

struct EmbyMediaDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    let item: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: EmbyMediaDetailViewModel
    @State private var showFullOverview = false
    @State private var showAllEpisodes = false
    @State private var selectedStill: EmbyImageInfo?

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ambientBackground(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)
                        VStack(alignment: .leading, spacing: 26) {
                            overview
                            if model.isSeries { seriesContent }
                            castSection
                            tagSection
                            stillsSection
                            similarSection
                            if let error = model.errorMessage { errorView(error) }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 52)
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(width: geometry.size.width)
                .ignoresSafeArea(edges: .top)

                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
                    .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .task { await model.load() }
        .sheet(isPresented: $showFullOverview) { overviewSheet }
        .fullScreenCover(isPresented: $showAllEpisodes) { EmbyEpisodePickerView(model: model, client: client) }
        .fullScreenCover(item: $selectedStill) { info in
            EmbyStillViewer(url: client.imageURL(itemId: model.item.id, imageType: info.imageType, maxWidth: 2200, index: info.imageIndex))
        }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private func ambientBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .scaleEffect(1.22)
                .blur(radius: 52)
                .opacity(colorScheme == .dark ? 0.62 : 0.44)
            Color(uiColor: .systemBackground)
                .opacity(colorScheme == .dark ? 0.58 : 0.68)
        }
        .frame(width: width, height: height)
        .clipped()
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.48))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            if model.item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.48))
                    .clipShape(Circle())
            }
        }
    }

    private func hero(width: CGFloat) -> some View {
        let heroHeight = min(500, max(455, width * 1.15))
        let contentWidth = max(0, width - 40)
        return ZStack(alignment: .bottom) {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(width: width, height: heroHeight)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [.black, .black, .black.opacity(0.92), .black.opacity(0.56), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 10) {
                heroIdentity(width: contentWidth)

                Text(heroMetadataLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
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
                    .buttonStyle(.plain)
                    .disabled(model.isResolvingPlayback)
                }

                detailActionRow(width: contentWidth)
            }
            .frame(width: width)
            .padding(.bottom, 8)
        }
        .frame(width: width, height: heroHeight)
    }

    @ViewBuilder
    private func heroIdentity(width: CGFloat) -> some View {
        if let logoURL = logoImageURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().frame(width: min(270, width), height: 88)
                default:
                    fallbackHeroTitle(width: width)
                }
            }
            .frame(width: width, height: 88)
        } else {
            fallbackHeroTitle(width: width)
        }
    }

    private func fallbackHeroTitle(width: CGFloat) -> some View {
        Text(model.item.name)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(width: width, minHeight: 54)
    }

    private func heroTagScroller(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(model.detailFilters) { filter in
                    NavigationLink(destination: EmbyDetailFilterResultsView(filter: filter, client: client)) {
                        Text(filter.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(width: width, height: 24)
    }

    private func detailActionRow(width: CGFloat) -> some View {
        HStack(spacing: 18) {
            actionButton(systemName: model.item.isPlayed ? "checkmark.circle.fill" : "checkmark.circle", active: model.item.isPlayed, label: model.item.isPlayed ? "标记为未看" : "标记为已看") { Task { await model.togglePlayed() } }
            actionButton(systemName: model.item.isFavorite ? "heart.fill" : "heart", active: model.item.isFavorite, label: model.item.isFavorite ? "取消收藏" : "收藏") { Task { await model.toggleFavorite() } }
            deferredAction(systemName: "arrow.down.circle", label: "下载")
            deferredAction(systemName: "film", label: "版本")
            deferredAction(systemName: "headphones", label: "音轨")
        }
        .frame(width: width, height: 34)
    }

    private func actionButton(systemName: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(active ? .blue : .secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(model.isUpdatingUserData)
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
        if !model.item.backdropImageTags.isEmpty {
            return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1600, tag: model.item.backdropImageTags.first, index: 0)
        }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1200, tag: model.item.preferredPrimaryImageTag)
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
                        .font(.system(size: 15))
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

    private var overviewSheet: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    ambientBackground(width: geometry.size.width, height: geometry.size.height)
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(model.normalizedOverview ?? "")
                            .font(.body)
                            .lineSpacing(5)
                            .frame(width: max(0, geometry.size.width - 40), alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 24)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("简介")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showFullOverview = false } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private var seriesContent: some View {
        if model.isLoadingEpisodes && model.episodes.isEmpty {
            HStack { Spacer(); ProgressView("正在加载剧集…"); Spacer() }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
        } else if !model.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 28) {
                upcomingEpisodesSection
                seasonsSection
            }
        }
    }

    private var upcomingEpisodesSection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("即将播放")
                        .font(.title2.weight(.bold))
                        .fixedSize()
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
                    Button("查看全部") { showAllEpisodes = true }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                        .fixedSize()
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(model.selectedSeasonEpisodes) { episode in
                            episodePreviewCard(episode).id(episode.id)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func episodePreviewCard(_ episode: LibraryItem) -> some View {
        Button { Task { await model.play(episode) } } label: {
            VStack(alignment: .leading, spacing: 6) {
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 174, alignment: .leading)

                if let overview = model.normalizedOverview(for: episode), !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.78))
                        .lineLimit(3)
                        .lineSpacing(2)
                        .frame(width: 174, alignment: .leading)
                }
            }
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
                        Text(String(count))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 29, minHeight: 29)
                            .background(Color.green)
                            .clipShape(Circle())
                            .padding(6)
                    }
                }
                Text(seasonDisplayTitle(season, item: seasonItem))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 106, alignment: .leading)
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
                        ForEach(model.visiblePeople) { person in personCard(person) }
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
            Text(person.name).font(.subheadline.weight(.semibold)).lineLimit(1).frame(width: 108, alignment: .leading)
            if let role = person.role, !role.isEmpty {
                Text("饰 " + role).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: 108, alignment: .leading)
            } else if let type = person.type, !type.isEmpty {
                Text(personTypeTitle(type)).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: 108, alignment: .leading)
            }
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
                        ForEach(model.stillImages) { info in
                            Button { selectedStill = info } label: {
                                EmbyDetailRemoteImage(url: client.imageURL(itemId: model.item.id, imageType: info.imageType, maxWidth: 900, index: info.imageIndex), contentMode: .fill)
                                    .frame(width: 248, height: 140)
                                    .clipped()
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
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

private struct EmbyEpisodePickerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: EmbyMediaDetailViewModel
    let client: EmbyAPIClient
    @State private var sortAscending = true

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    pickerBackground(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            pickerHero(width: geometry.size.width)
                            LazyVStack(spacing: 16) {
                                ForEach(displayedEpisodes) { episode in
                                    episodeRow(episode).id(episode.id)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                        .frame(width: geometry.size.width)
                    }
                    .frame(width: geometry.size.width)
                    .ignoresSafeArea(edges: .top)

                    HStack {
                        Button { presentationMode.wrappedValue.dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.48))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button { sortAscending.toggle() } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.48))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(sortAscending ? "改为倒序" : "改为正序")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
                    .frame(width: geometry.size.width)

                    VStack {
                        Spacer().frame(height: max(150, geometry.size.height * 0.18))
                        HStack {
                            Spacer()
                            quickJumpRail(proxy: proxy)
                                .frame(width: 42, height: min(560, geometry.size.height * 0.66))
                                .padding(.trailing, 4)
                        }
                        Spacer().frame(height: 70)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(true)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarHidden(true)
    }

    private var displayedEpisodes: [LibraryItem] {
        sortAscending ? model.selectedSeasonEpisodes : Array(model.selectedSeasonEpisodes.reversed())
    }

    private var quickJumps: [EmbyEpisodeJump] {
        let items = displayedEpisodes
        guard !items.isEmpty else { return [] }
        let step = max(1, Int(ceil(Double(max(0, items.count - 1)) / 29.0)))
        var offsets = Array(stride(from: 0, to: items.count, by: step))
        if offsets.last != items.count - 1 { offsets.append(items.count - 1) }
        return offsets.map { offset in
            let episode = items[offset]
            return EmbyEpisodeJump(label: episode.indexNumber ?? offset + 1, episode: episode)
        }
    }

    private func pickerBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            EmbyDetailRemoteImage(url: pickerHeroURL, contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .scaleEffect(1.2)
                .blur(radius: 54)
                .opacity(colorScheme == .dark ? 0.45 : 0.26)
            Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.72 : 0.82)
        }
        .frame(width: width, height: height)
        .clipped()
        .ignoresSafeArea()
    }

    private func pickerHero(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            EmbyDetailRemoteImage(url: pickerHeroURL, contentMode: .fill)
                .frame(width: width, height: 238)
                .clipped()
                .mask(LinearGradient(colors: [.black, .black, .black.opacity(0.82), .clear], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.item.name).font(.headline).lineLimit(1)
                Text(model.selectedSeasonTitle).font(.title2.weight(.bold))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: width, height: 238)
    }

    private var pickerHeroURL: URL? {
        if !model.item.backdropImageTags.isEmpty {
            return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1600, tag: model.item.backdropImageTags.first, index: 0)
        }
        if let season = model.selectedSeason, let seasonItem = model.seasonItem(number: season) {
            return client.imageURL(itemId: seasonItem.preferredPrimaryImageItemId, maxWidth: 1000, tag: seasonItem.preferredPrimaryImageTag)
        }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1200, tag: model.item.preferredPrimaryImageTag)
    }

    private func quickJumpRail(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geometry in
            let jumps = quickJumps
            let rowHeight = jumps.isEmpty ? 0 : min(18, geometry.size.height / CGFloat(jumps.count))
            VStack(spacing: 0) {
                ForEach(jumps) { jump in
                    Button { proxy.scrollTo(jump.episode.id, anchor: .top) } label: {
                        Text(String(jump.label))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 38, height: rowHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.80))
            .clipShape(Capsule())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !jumps.isEmpty, geometry.size.height > 0 else { return }
                        let fraction = min(0.999, max(0, value.location.y / geometry.size.height))
                        let index = min(jumps.count - 1, max(0, Int(fraction * CGFloat(jumps.count))))
                        proxy.scrollTo(jumps[index].episode.id, anchor: .top)
                    }
            )
        }
    }

    private func episodeRow(_ episode: LibraryItem) -> some View {
        Button {
            presentationMode.wrappedValue.dismiss()
            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                await model.play(episode)
            }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    EmbyDetailRemoteImage(url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag), contentMode: .fill)
                        .frame(width: 136, height: 78)
                        .clipped()
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.48))
                        .clipShape(Circle())
                }
                .frame(width: 136, height: 78)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.displayEpisodeTitle(episode))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let overview = model.normalizedOverview(for: episode), !overview.isEmpty {
                        Text(overview)
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary.opacity(0.78))
                            .lineLimit(3)
                            .lineSpacing(2)
                    } else {
                        HStack(spacing: 6) {
                            if let date = episode.premiereDate, date.count >= 10 { Text(String(date.prefix(10))) }
                            else if let year = episode.productionYear { Text(String(year)) }
                            if let duration = episode.durationSeconds { Text("·"); Text(formatDuration(duration)) }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时" }
        return "\(minutes)分钟"
    }
}

private struct EmbyStillViewer: View {
    @Environment(\.presentationMode) private var presentationMode
    let url: URL?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()
                EmbyDetailRemoteImage(url: url, contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, geometry.safeAreaInsets.top + 8)
            }
        }
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
                if model.isLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) {
                            EmbyDetailPosterCard(item: item, client: client)
                        }
                        .buttonStyle(.plain)
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
            Text(item.productionYear.map(String.init) ?? " ")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: width, height: 16, alignment: .leading)
                .opacity(item.productionYear == nil ? 0 : 1)
        }
        .frame(width: width, alignment: .leading)
    }
}

@MainActor
private final class EmbyMediaDetailViewModel: ObservableObject {
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
    @Published var isUpdatingUserData = false
    @Published var selectedSource: ResolvedPlaybackSource?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
    }

    var isSeries: Bool { item.type?.caseInsensitiveCompare("Series") == .orderedSame }
    var isPlayable: Bool { ["movie", "episode", "video"].contains(item.type?.lowercased() ?? "") }

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

    func toggleFavorite() async {
        guard !isUpdatingUserData else { return }
        isUpdatingUserData = true
        defer { isUpdatingUserData = false }
        do {
            try await client.setFavorite(itemId: item.id, favorite: !item.isFavorite)
            item = try await client.libraryItem(itemId: item.id)
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    func togglePlayed() async {
        guard !isUpdatingUserData else { return }
        isUpdatingUserData = true
        defer { isUpdatingUserData = false }
        do {
            try await client.setPlayed(itemId: item.id, played: !item.isPlayed)
            item = try await client.libraryItem(itemId: item.id)
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
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
            Image(systemName: "photo")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
