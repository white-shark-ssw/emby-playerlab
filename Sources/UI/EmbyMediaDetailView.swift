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
            LazyVStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 20) {
                    metadata
                    if model.isSeries { seriesContent } else if model.isPlayable { playButton(model.item) }
                    overview
                    if let error = model.errorMessage { errorView(error) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(model.item.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .task { await model.load() }
        .fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            EmbyDetailRemoteImage(
                url: client.imageURL(
                    itemId: model.item.id,
                    imageType: model.item.backdropImageTags.isEmpty ? "Primary" : "Backdrop",
                    maxWidth: 1400,
                    tag: model.item.backdropImageTags.first ?? model.item.primaryImageTag
                ),
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: 285)
            .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.28), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                EmbyDetailRemoteImage(
                    url: client.imageURL(itemId: model.item.id, maxWidth: 420, tag: model.item.primaryImageTag),
                    contentMode: .fill
                )
                .frame(width: 92, height: 138)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 7) {
                    Text(model.item.name)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                    Text(detailSubtitle(model.item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.82))
                    if let secondary = heroSecondaryLine {
                        Text(secondary)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 285)
        .clipped()
    }

    private var heroSecondaryLine: String? {
        var parts: [String] = []
        if let year = model.item.productionYear { parts.append(String(year)) }
        if let rating = model.item.communityRating { parts.append("★ " + String(format: "%.1f", rating)) }
        if let duration = model.item.durationSeconds, !model.isSeries { parts.append(formatDuration(duration)) }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private var metadata: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                detailPill(detailSubtitle(model.item), systemImage: mediaSymbol)
                if let year = model.item.productionYear { detailPill(String(year)) }
                if let rating = model.item.communityRating { detailPill(String(format: "%.1f", rating), systemImage: "star.fill") }
                if let duration = model.item.durationSeconds, !model.isSeries { detailPill(formatDuration(duration), systemImage: "clock") }
                if model.isSeries, !model.episodes.isEmpty { detailPill("\(model.episodes.count) 集", systemImage: "rectangle.stack") }
            }
        }
    }

    private var overview: some View {
        Group {
            if let overview = model.item.overview, !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("简介").font(.title3.weight(.bold))
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
        }
    }

    @ViewBuilder
    private var seriesContent: some View {
        if model.isLoadingEpisodes && model.episodes.isEmpty {
            HStack { Spacer(); ProgressView("正在加载剧集…"); Spacer() }.padding(.vertical, 24)
        } else if !model.episodes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("剧集").font(.title3.weight(.bold))
                    Spacer()
                    if model.seasonNumbers.count > 1 { seasonMenu }
                    Text("\(model.visibleEpisodes.count) 集").font(.subheadline).foregroundColor(.secondary)
                }

                LazyVStack(spacing: 12) {
                    ForEach(model.visibleEpisodes) { episode in episodeRow(episode) }
                }
            }
        } else if model.hasLoaded {
            Text("没有找到可播放的剧集。\n如果这是刚更新的媒体库，请先在 Emby 服务端确认剧集已完成扫描。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
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
            .padding(.horizontal, 11)
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
                        url: client.imageURL(itemId: episode.id, maxWidth: 520, tag: episode.primaryImageTag),
                        contentMode: .fill
                    )
                    .frame(width: 122, height: 69)
                    .clipped()

                    Color.black.opacity(0.16)
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.56))
                        .clipShape(Circle())
                }
                .frame(width: 122, height: 69)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(episodeIndexTitle(episode)).font(.caption.weight(.bold)).foregroundColor(.secondary)
                        if episode.isPlayed { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.green) }
                    }
                    Text(episode.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(2)
                    if let duration = episode.durationSeconds { Text(formatDuration(duration)).font(.caption).foregroundColor(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 25)
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func playButton(_ mediaItem: LibraryItem) -> some View {
        Button { Task { await model.play(mediaItem) } } label: {
            HStack(spacing: 9) {
                if model.isResolvingPlayback { ProgressView().tint(.white) }
                else { Image(systemName: mediaItem.playbackProgress > 0.01 ? "play.fill" : "play.fill") }
                Text(model.isResolvingPlayback ? "正在准备播放…" : (mediaItem.playbackProgress > 0.01 ? "继续播放" : "播放"))
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isResolvingPlayback)
    }

    private func detailPill(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.primary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Capsule())
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
    }

    private var mediaSymbol: String {
        switch model.item.type?.lowercased() {
        case "movie": return "film"
        case "series": return "tv"
        case "episode": return "play.rectangle"
        case "boxset": return "rectangle.stack"
        default: return "play.rectangle"
        }
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
        guard let selectedSeason else { return episodes }
        return episodes.filter { $0.parentIndexNumber == selectedSeason }
    }

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
                if selectedSeason == nil { selectedSeason = seasonNumbers.first }
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
            Image(systemName: "play.rectangle").font(.system(size: 28)).foregroundColor(.secondary)
        }
    }
}
