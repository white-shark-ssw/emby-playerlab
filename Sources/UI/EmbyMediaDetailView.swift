import SwiftUI
import Combine

struct EmbyMediaDetailView: View {
    let item: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: EmbyMediaDetailViewModel

    init(item: LibraryItem, client: EmbyAPIClient) {
        self.item = item
        self.client = client
        _model = StateObject(wrappedValue: EmbyMediaDetailViewModel(item: item, client: client))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                artwork
                metadata
                if model.isSeries { seriesContent } else if model.isPlayable { playButton(model.item) }
                if let overview = model.item.overview, !overview.isEmpty {
                    Text("简介").font(.title3.weight(.bold))
                    Text(overview).font(.body).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(model.item.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .task { await model.load() }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            EmbyDetailRemoteImage(
                url: client.imageURL(
                    itemId: model.item.id,
                    imageType: model.item.backdropImageTags.isEmpty ? "Primary" : "Backdrop",
                    maxWidth: 1280,
                    tag: model.item.backdropImageTags.first ?? model.item.primaryImageTag
                ),
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Text(model.item.name).font(.title.weight(.bold)).foregroundColor(.white).lineLimit(2)
                Text(detailSubtitle(model.item)).font(.subheadline.weight(.medium)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 8)
    }

    private var metadata: some View {
        HStack(spacing: 12) {
            if let year = model.item.productionYear { detailPill(String(year)) }
            if let rating = model.item.communityRating { detailPill("★ " + String(format: "%.1f", rating)) }
            if let duration = model.item.durationSeconds, !model.isSeries { detailPill(formatDuration(duration)) }
            if model.isSeries, let count = model.item.childCount { detailPill("\(count) 集") }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var seriesContent: some View {
        if model.isLoadingEpisodes && model.episodes.isEmpty {
            ProgressView("正在加载剧集…").frame(maxWidth: .infinity).padding(.vertical, 18)
        } else if !model.episodes.isEmpty {
            HStack {
                Text("剧集").font(.title3.weight(.bold))
                Spacer()
                Text("\(model.episodes.count) 集").font(.subheadline).foregroundColor(.secondary)
            }

            LazyVStack(spacing: 0) {
                ForEach(model.episodes) { episode in
                    Button { Task { await model.play(episode) } } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)).frame(width: 92, height: 54)
                                Image(systemName: "play.fill").font(.system(size: 18, weight: .semibold)).foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episodeTitle(episode)).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(2)
                                if let duration = episode.durationSeconds { Text(formatDuration(duration)).font(.caption).foregroundColor(.secondary) }
                            }
                            Spacer()
                            if episode.isPlayed { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if episode.id != model.episodes.last?.id { Divider().padding(.leading, 104) }
                }
            }
        } else if model.hasLoaded {
            Text("没有找到可播放的剧集。\n如果这是刚更新的媒体库，请先在 Emby 服务端确认剧集已完成扫描。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func playButton(_ mediaItem: LibraryItem) -> some View {
        Button { Task { await model.play(mediaItem) } } label: {
            HStack(spacing: 8) {
                if model.isResolvingPlayback { ProgressView().tint(.white) } else { Image(systemName: "play.fill") }
                Text(model.isResolvingPlayback ? "正在准备播放…" : "播放")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func detailPill(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())
    }

    private func detailSubtitle(_ item: LibraryItem) -> String {
        switch item.type?.lowercased() {
        case "movie": return "电影"
        case "series": return "电视剧"
        case "episode":
            if let season = item.parentIndexNumber, let episode = item.indexNumber { return "第 \(season) 季 · 第 \(episode) 集" }
            return "剧集"
        case "boxset": return "合集"
        default: return item.type ?? "媒体"
        }
    }

    private func episodeTitle(_ episode: LibraryItem) -> String {
        if let season = episode.parentIndexNumber, let index = episode.indexNumber { return "S\(season) E\(index) · \(episode.name)" }
        if let index = episode.indexNumber { return "第 \(index) 集 · \(episode.name)" }
        return episode.name
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)小时\(minutes)分钟" }
        return "\(minutes)分钟"
    }
}

@MainActor
private final class EmbyMediaDetailViewModel: ObservableObject {
    @Published var item: LibraryItem
    @Published var episodes: [LibraryItem] = []
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

    func load() async {
        guard !hasLoaded else { return }
        errorMessage = nil
        do {
            let refreshed = try await client.libraryItem(itemId: item.id)
            item = refreshed
            if refreshed.type?.caseInsensitiveCompare("Series") == .orderedSame {
                isLoadingEpisodes = true
                defer { isLoadingEpisodes = false }
                episodes = try await client.seriesEpisodes(seriesId: refreshed.id)
            }
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
            Image(systemName: "play.rectangle").font(.system(size: 30)).foregroundColor(.secondary)
        }
    }
}
