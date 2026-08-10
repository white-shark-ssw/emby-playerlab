import SwiftUI
import Combine

struct EmbyMediaDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    let item: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: EmbyMediaDetailViewModel
    @State private var showFullOverview = false

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero
                        VStack(alignment: .leading, spacing: 26) {
                            if model.isSeries { seriesContent }
                            overview
                            castSection
                            similarSection
                            if let error = model.errorMessage { errorView(error) }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 42)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .background(Color(uiColor: .systemBackground))

                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top + 8)
            }
        }
        .navigationBarHidden(true)
        .task { await model.load() }
        .sheet(isPresented: $showFullOverview) { overviewSheet }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private var topBar: some View {
        HStack {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            if model.item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 535)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.06),
                    Color.black.opacity(0.08),
                    Color(uiColor: .systemBackground).opacity(0.14),
                    Color(uiColor: .systemBackground).opacity(0.82),
                    Color(uiColor: .systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 12) {
                Text(model.item.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 28)

                Text(heroMetadataLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                if !model.item.genres.isEmpty {
                    Text(model.item.genres.prefix(4).joined(separator: "  ·  "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 24)
                }

                if let playableItem = model.primaryPlayableItem {
                    Button { Task { await model.play(playableItem) } } label: {
                        HStack(spacing: 9) {
                            if model.isResolvingPlayback { ProgressView().tint(.white) }
                            else { Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)) }
                            Text(model.primaryPlayButtonTitle)
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isResolvingPlayback)
                    .padding(.horizontal, 56)
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(height: 535)
        .clipped()
    }

    private var heroImageURL: URL? {
        if !model.item.backdropImageTags.isEmpty {
            return client.imageURL(itemId: model.item.id, imageType: "Backdrop", maxWidth: 1600, tag: model.item.backdropImageTags.first)
        }
        return client.imageURL(itemId: model.item.preferredPrimaryImageItemId, maxWidth: 1200, tag: model.item.preferredPrimaryImageTag)
    }

    private var heroMetadataLine: String {
        var parts: [String] = []
        if let duration = model.item.durationSeconds, !model.isSeries { parts.append(formatDuration(duration)) }
        if let year = model.item.productionYear { parts.append(String(year)) }
        if let rating = model.item.communityRating { parts.append("★ " + String(format: "%.1f", rating)) }
        if let official = model.item.officialRating, !official.isEmpty { parts.append(official) }
        if model.isSeries, !model.episodes.isEmpty { parts.append("\(model.episodes.count) 集") }
        return parts.isEmpty ? detailSubtitle(model.item) : parts.joined(separator: "   ")
    }

    @ViewBuilder
    private var overview: some View {
        if let text = model.item.overview, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("简介")
                    .font(.title2.weight(.bold))
                Button { showFullOverview = true } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.78))
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
            ZStack {
                EmbyDetailRemoteImage(url: heroImageURL, contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 22)
                    .overlay(Color(uiColor: .systemBackground).opacity(0.72).ignoresSafeArea())
                ScrollView {
                    Text(model.item.overview ?? "")
                        .font(.body)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
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
                .frame(width: 108, height: 144)
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
                                    EmbyDetailRemoteImage(
                                        url: client.imageURL(itemId: similar.preferredPrimaryImageItemId, maxWidth: 420, tag: similar.preferredPrimaryImageTag),
                                        contentMode: .fill
                                    )
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
                                        Text(String(year))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
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

    @ViewBuilder
    private var seriesContent: some View {
        if model.isLoadingEpisodes && model.episodes.isEmpty {
            HStack { Spacer(); ProgressView("正在加载剧集…"); Spacer() }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
        } else if !model.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("剧集").font(.title2.weight(.bold))
                    Spacer()
                    if model.seasonNumbers.count > 1 { seasonMenu }
                }
                .padding(.horizontal, 20)

                LazyVStack(spacing: 12) {
                    ForEach(model.visibleEpisodes) { episode in episodeRow(episode) }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var seasonMenu: some View {
        Menu {
            ForEach(model.seasonNumbers, id: \.self) { season in
                Button { model.selectedSeason = season } label: {
                    if model.selectedSeason == season { Label("第 \(season) 季", systemImage: "checkmark") }
                    else { Text("第 \(season) 季") }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(model.selectedSeason.map { "第 \($0) 季" } ?? "全部")
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())
        }
    }

    private func episodeRow(_ episode: LibraryItem) -> some View {
        Button { Task { await model.play(episode) } } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    EmbyDetailRemoteImage(
                        url: client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 520, tag: episode.preferredPrimaryImageTag),
                        contentMode: .fill
                    )
                    .frame(width: 126, height: 72)
                    .clipped()
                    Color.black.opacity(0.16)
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .frame(width: 126, height: 72)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(episodeIndexTitle(episode))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                    Text(episode.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let duration = episode.durationSeconds {
                        Text(formatDuration(duration)).font(.caption).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
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

    private func episodeIndexTitle(_ episode: LibraryItem) -> String {
        if let season = episode.parentIndexNumber, let index = episode.indexNumber { return "S\(season) · E\(index)" }
        if let index = episode.indexNumber { return "第 \(index) 集" }
        return "剧集"
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
    @Published var similarItems: [LibraryItem] = []
    @Published var selectedSeason: Int?
    @Published var errorMessage: String?
    @Published var isLoadingEpisodes = false
    @Published var isResolvingPlayback = false
    @Published var selectedSource: ResolvedPlaybackSource?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
    }

    var isSeries: Bool { item.type?.caseInsensitiveCompare("Series") == .orderedSame }
    var isPlayable: Bool { ["movie", "episode", "video"].contains(item.type?.lowercased() ?? "") }
    var seasonNumbers: [Int] { Array(Set(episodes.compactMap(\.parentIndexNumber))).sorted() }
    var visibleEpisodes: [LibraryItem] {
        guard let season = selectedSeason else { return episodes }
        return episodes.filter { $0.parentIndexNumber == season }
    }
    var visiblePeople: [EmbyPerson] { Array(item.people.prefix(18)) }
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
                isLoadingEpisodes = false
                if selectedSeason == nil { selectedSeason = seasonNumbers.first }
            }
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
