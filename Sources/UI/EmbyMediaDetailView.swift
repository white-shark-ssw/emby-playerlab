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
    let position: Int
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

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ambientBackground(width: geometry.size.width, height: geometry.size.height)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)
                        VStack(alignment: .leading, spacing: 28) {
                            overview
                            if model.isSeries { seriesContent }
                            castSection
                            tagSection
                            stillsSection
                            similarSection
                            if let error = model.errorMessage { errorView(error) }
                        }
                        .padding(.top, 10)
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
            .clipped()
        }
        .navigationBarHidden(true)
        .task { await model.load() }
        .sheet(isPresented: $showFullOverview) { overviewSheet }
        .sheet(isPresented: $showAllEpisodes) { EmbyEpisodePickerSheet(model: model, client: client) }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private func ambientBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .scaleEffect(1.18)
                .blur(radius: 48)
                .opacity(colorScheme == .dark ? 0.58 : 0.38)
            Color(uiColor: .systemBackground)
                .opacity(colorScheme == .dark ? 0.60 : 0.70)
            LinearGradient(
                colors: [Color.clear, Color(uiColor: .systemBackground).opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            if model.item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
        }
    }

    private func hero(width: CGFloat) -> some View {
        let heroHeight: CGFloat = 555
        let contentWidth = max(0, width - 40)
        return ZStack(alignment: .bottom) {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(width: width, height: heroHeight)
                .clipped()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(uiColor: .systemBackground).opacity(0.06),
                    Color(uiColor: .systemBackground).opacity(0.46),
                    Color(uiColor: .systemBackground).opacity(0.90),
                    Color(uiColor: .systemBackground).opacity(0.98),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: heroHeight)

            VStack(spacing: 11) {
                Text(model.item.name)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: contentWidth)

                Text(heroMetadataLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: contentWidth)

                if !model.detailTags.isEmpty {
                    heroTagScroller(width: width)
                }

                if let playableItem = model.primaryPlayableItem {
                    Button { Task { await model.play(playableItem) } } label: {
                        HStack(spacing: 9) {
                            if model.isResolvingPlayback { ProgressView().tint(.white) }
                            else { Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)) }
                            Text(model.primaryPlayButtonTitle).font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(width: contentWidth, height: 52)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isResolvingPlayback)
                }

                detailActionRow(width: contentWidth)
            }
            .frame(width: width)
            .padding(.bottom, 16)
        }
        .frame(width: width, height: heroHeight)
        .clipped()
    }

    private func heroTagScroller(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.detailTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.82))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.82))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(width: width, height: 32)
    }

    private func detailActionRow(width: CGFloat) -> some View {
        HStack(spacing: 26) {
            actionButton(systemName: model.item.isPlayed ? "checkmark.circle.fill" : "checkmark.circle", active: model.item.isPlayed, label: model.item.isPlayed ? "标记为未看" : "标记为已看") { Task { await model.togglePlayed() } }
            actionButton(systemName: model.item.isFavorite ? "heart.fill" : "heart", active: model.item.isFavorite, label: model.item.isFavorite ? "取消收藏" : "收藏") { Task { await model.toggleFavorite() } }
            deferredAction(systemName: "arrow.down.circle", label: "下载")
            deferredAction(systemName: "film", label: "版本")
            deferredAction(systemName: "headphones", label: "音轨")
        }
        .frame(width: width, height: 42)
    }

    private func actionButton(systemName: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(active ? .blue : .secondary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(model.isUpdatingUserData)
        .accessibilityLabel(label)
    }

    private func deferredAction(systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.secondary.opacity(0.48))
            .frame(width: 34, height: 34)
            .accessibilityLabel(label + "，后续实现")
    }

    private var heroImageURL: URL? {
        if !model.item.backdropImageTags.isEmpty {
            return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1600, tag: model.item.backdropImageTags.first, index: 0)
        }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1200, tag: model.item.preferredPrimaryImageTag)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("简介").font(.title2.weight(.bold))
                Button { showFullOverview = true } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.82))
                            .lineLimit(4)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 4) {
                            Text("查看完整简介")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
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
                .clipped()
            }
            .navigationTitle("简介")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showFullOverview = false }
                }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("即将播放")
                    .font(.title2.weight(.bold))
                    .fixedSize()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(model.episodeRanges) { range in
                            Button { model.selectEpisodeRange(range.startOffset) } label: {
                                Text(range.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(model.selectedEpisodeRangeOffset == range.startOffset ? .white : .primary)
                                    .padding(.horizontal, 11)
                                    .frame(height: 32)
                                    .background(model.selectedEpisodeRangeOffset == range.startOffset ? Color.blue : Color(uiColor: .secondarySystemBackground).opacity(0.82))
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
                HStack(alignment: .top, spacing: 12) {
                    ForEach(model.selectedPreviewEpisodes) { episode in episodePreviewCard(episode) }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func episodePreviewCard(_ episode: LibraryItem) -> some View {
        Button { Task { await model.play(episode) } } label: {
            VStack(alignment: .leading, spacing: 7) {
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

                Text(episodePreviewTitle(episode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(width: 174, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("季")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
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
                    EmbyDetailRemoteImage(
                        url: seasonItem.flatMap { client.imageURL(itemId: $0.preferredPrimaryImageItemId, maxWidth: 420, tag: $0.preferredPrimaryImageTag) },
                        contentMode: .fill
                    )
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
                Text("演职人员")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 20)
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
            Text(person.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(width: 108, alignment: .leading)
            if let role = person.role, !role.isEmpty {
                Text("饰 " + role)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 108, alignment: .leading)
            } else if let type = person.type, !type.isEmpty {
                Text(personTypeTitle(type))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 108, alignment: .leading)
            }
        }
    }

    private func personImageURL(_ person: EmbyPerson) -> URL? {
        guard let itemId = person.itemId, !itemId.isEmpty else { return nil }
        return client.imageURL(itemId: itemId, maxWidth: 360, tag: person.primaryImageTag)
    }

    @ViewBuilder
    private var tagSection: some View {
        if !model.detailTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("标签").font(.title2.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(model.detailTags, id: \.self) { tag in
                        HStack(spacing: 7) {
                            Image(systemName: "tag")
                            Text(tag).lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.86))
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.82))
                        .clipShape(Capsule())
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
                Text("剧照")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.stillImages) { info in
                            EmbyDetailRemoteImage(
                                url: client.imageURL(itemId: model.item.id, imageType: info.imageType, maxWidth: 900, index: info.imageIndex),
                                contentMode: .fill
                            )
                            .frame(width: 248, height: 140)
                            .clipped()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
                Text(model.isSeries ? "更多类似" : "相似作品")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 20)
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
                                    Text(similar.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .leading)
                                    if let year = similar.productionYear {
                                        Text(String(year)).font(.caption).foregroundColor(.secondary)
                                    }
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
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.82))
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

    private func episodePreviewTitle(_ episode: LibraryItem) -> String {
        let prefix = episode.indexNumber.map { "S\(episode.parentIndexNumber ?? model.selectedSeason ?? 0):E\($0)" } ?? "剧集"
        return "\(prefix) · \(episode.name)"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时" }
        return "\(minutes)分钟"
    }
}

private struct EmbyEpisodePickerSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var model: EmbyMediaDetailViewModel
    let client: EmbyAPIClient

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 14) {
                                ForEach(model.selectedSeasonEpisodes) { episode in
                                    episodeRow(episode)
                                        .id(episode.id)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                        }
                        .frame(width: max(0, geometry.size.width - 48))

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 5) {
                                ForEach(quickJumps) { jump in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(jump.episode.id, anchor: .top) }
                                    } label: {
                                        Text(String(jump.position))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(.blue)
                                            .frame(width: 42, height: 19)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .frame(width: 48)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .navigationTitle(model.selectedSeasonTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(model.seasonNumbers, id: \.self) { season in
                            Button { model.selectSeason(season) } label: {
                                if model.selectedSeason == season { Label(season == 0 ? "特别篇" : "第 \(season) 季", systemImage: "checkmark") }
                                else { Text(season == 0 ? "特别篇" : "第 \(season) 季") }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var quickJumps: [EmbyEpisodeJump] {
        let items = model.selectedSeasonEpisodes
        guard !items.isEmpty else { return [] }
        let step = max(1, Int(ceil(Double(max(0, items.count - 1)) / 29.0)))
        var offsets = Array(stride(from: 0, to: items.count, by: step))
        if offsets.last != items.count - 1 { offsets.append(items.count - 1) }
        return offsets.map { EmbyEpisodeJump(position: $0 + 1, episode: items[$0]) }
    }

    private func episodeRow(_ episode: LibraryItem) -> some View {
        Button {
            presentationMode.wrappedValue.dismiss()
            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                await model.play(episode)
            }
        } label: {
            HStack(alignment: .center, spacing: 13) {
                EmbyDetailRemoteImage(url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: 136, height: 78)
                    .clipped()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(episodeRowTitle(episode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if let date = episode.premiereDate, date.count >= 10 { Text(String(date.prefix(10))) }
                        else if let year = episode.productionYear { Text(String(year)) }
                        if let duration = episode.durationSeconds { Text("·"); Text(formatDuration(duration)) }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func episodeRowTitle(_ episode: LibraryItem) -> String {
        let index = episode.indexNumber.map { "第 \($0) 集" } ?? "剧集"
        return "\(index) · \(episode.name)"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时" }
        return "\(minutes)分钟"
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

    var normalizedOverview: String? {
        guard let overview = item.overview else { return nil }
        let normalized = overview
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    var detailTags: [String] {
        var seen = Set<String>()
        return (item.genres + item.tags).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted }
    }

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

    var selectedPreviewEpisodes: [LibraryItem] {
        let items = selectedSeasonEpisodes
        guard !items.isEmpty else { return [] }
        let validOffset = min(max(0, selectedEpisodeRangeOffset), max(0, items.count - 1))
        let end = min(items.count, validOffset + 10)
        return Array(items[validOffset..<end])
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

    func selectSeason(_ season: Int) {
        selectedSeason = season
        selectedEpisodeRangeOffset = 0
    }

    func selectEpisodeRange(_ offset: Int) {
        selectedEpisodeRangeOffset = max(0, offset)
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
