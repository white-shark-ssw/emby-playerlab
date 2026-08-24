import Foundation
import SwiftUI

@MainActor
final class PlayerEpisodeCoordinator: ObservableObject {
    @Published private(set) var currentItemID: String
    @Published private(set) var seriesName: String?
    @Published private(set) var episodes: [LibraryItem] = []
    @Published private(set) var contextAvailable = false
    @Published private(set) var isLoadingContext = false
    @Published private(set) var isLoadingEpisodes = false
    @Published private(set) var resolvingItemID: String?
    @Published private(set) var errorMessage: String?

    private let client: EmbyAPIClient
    private var seriesID: String?
    private var contextResolvedItemID: String?
    private var loadedSeriesID: String?
    private var prepareTask: Task<Void, Never>?
    private var episodeListTask: Task<Void, Never>?

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient) {
        self.currentItemID = source.itemId
        self.client = client
    }

    func activate(source: ResolvedPlaybackSource) {
        guard source.itemId != currentItemID else { return }
        currentItemID = source.itemId
        errorMessage = nil
        resolvingItemID = nil
        prepareTask?.cancel()
        prepareTask = nil

        if let episode = episodes.first(where: { $0.id == source.itemId }), let episodeSeriesID = episode.seriesId, !episodeSeriesID.isEmpty {
            seriesID = episodeSeriesID
            seriesName = episode.seriesName
            contextAvailable = true
            contextResolvedItemID = source.itemId
        } else {
            seriesID = nil
            seriesName = nil
            contextAvailable = false
            contextResolvedItemID = nil
        }
    }

    func prepareForPlayback() async {
        if contextResolvedItemID != currentItemID {
            if let prepareTask { await prepareTask.value }
            if contextResolvedItemID != currentItemID { await startPrepareTask() }
        }
        if contextAvailable { await loadEpisodesIfNeeded() }
    }

    func playbackSource(for episode: LibraryItem, reason: String) async -> ResolvedPlaybackSource? {
        guard episode.id != currentItemID else { return nil }
        guard resolvingItemID == nil else { return nil }
        resolvingItemID = episode.id
        errorMessage = nil
        defer { resolvingItemID = nil }

        do {
            let info = try await client.playbackInfo(itemId: episode.id)
            guard let mediaSource = info.mediaSources.first(where: { $0.supportsDirectPlay == true }) ?? info.mediaSources.first else { throw EmbyAPIError.noMediaSource }
            let initialTicks = episode.isPlayed ? 0 : max(0, episode.userData?.playbackPositionTicks ?? 0)
            let resolved = try client.resolvePlaybackSource(itemId: episode.id, itemName: episode.name, mediaSource: mediaSource, playSessionId: info.playSessionId, initialPlaybackPositionTicks: initialTicks)
            PlaybackClickResolveRegistry.shared.arm(source: resolved)
            DiagnosticsLogger.shared.playback("EpisodeSwitch", "resolved reason=\(reason) from=\(currentItemID) to=\(episode.id) season=\(episode.parentIndexNumber.map(String.init) ?? "nil") episode=\(episode.indexNumber.map(String.init) ?? "nil") resumeTicks=\(initialTicks)")
            return resolved
        } catch {
            if !isEmbyRequestCancellation(error) {
                errorMessage = error.localizedDescription
                DiagnosticsLogger.shared.playback("EpisodeSwitch", "resolve failed reason=\(reason) from=\(currentItemID) to=\(episode.id) error=\(error.localizedDescription)")
            }
            return nil
        }
    }

    func nextPlaybackSource() async -> ResolvedPlaybackSource? {
        await prepareForPlayback()
        guard let currentIndex = episodes.firstIndex(where: { $0.id == currentItemID }) else {
            DiagnosticsLogger.shared.playback("EpisodeSwitch", "automatic next unavailable current=\(currentItemID) reason=current-not-in-series")
            return nil
        }
        let nextIndex = currentIndex + 1
        guard episodes.indices.contains(nextIndex) else {
            DiagnosticsLogger.shared.playback("EpisodeSwitch", "automatic next unavailable current=\(currentItemID) reason=series-end")
            return nil
        }
        return await playbackSource(for: episodes[nextIndex], reason: "trusted-natural-end")
    }

    func imageURL(for episode: LibraryItem) -> URL? {
        client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 620, tag: episode.preferredPrimaryImageTag)
    }

    private func startPrepareTask() async {
        let itemID = currentItemID
        isLoadingContext = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.currentItemID == itemID { self.isLoadingContext = false }
            }
            do {
                let item = try await self.client.libraryItem(itemId: itemID)
                guard !Task.isCancelled, self.currentItemID == itemID else { return }
                self.contextResolvedItemID = itemID
                guard item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesID = item.seriesId, !seriesID.isEmpty else {
                    self.seriesID = nil
                    self.seriesName = nil
                    self.contextAvailable = false
                    return
                }
                self.seriesID = seriesID
                self.seriesName = item.seriesName
                self.contextAvailable = true
                DiagnosticsLogger.shared.playback("EpisodeContext", "prepared item=\(itemID) series=\(seriesID)")
            } catch {
                guard !Task.isCancelled, self.currentItemID == itemID else { return }
                self.contextResolvedItemID = itemID
                self.seriesID = nil
                self.seriesName = nil
                self.contextAvailable = false
                if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.playback("EpisodeContext", "prepare failed item=\(itemID) error=\(error.localizedDescription)") }
            }
        }
        prepareTask = task
        await task.value
        if currentItemID == itemID { prepareTask = nil }
    }

    private func loadEpisodesIfNeeded() async {
        guard let seriesID, !seriesID.isEmpty else { return }
        if loadedSeriesID == seriesID, !episodes.isEmpty { return }
        if let episodeListTask {
            await episodeListTask.value
            if loadedSeriesID == seriesID, !episodes.isEmpty { return }
        }

        let requestedSeriesID = seriesID
        isLoadingEpisodes = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.seriesID == requestedSeriesID { self.isLoadingEpisodes = false }
            }
            do {
                let items = try await self.client.seriesEpisodes(seriesId: requestedSeriesID)
                guard !Task.isCancelled, self.seriesID == requestedSeriesID else { return }
                self.episodes = items
                self.loadedSeriesID = requestedSeriesID
                if let current = items.first(where: { $0.id == self.currentItemID }), self.seriesName == nil { self.seriesName = current.seriesName }
                DiagnosticsLogger.shared.playback("EpisodeContext", "episodes loaded series=\(requestedSeriesID) count=\(items.count) current=\(self.currentItemID)")
            } catch {
                guard !Task.isCancelled, self.seriesID == requestedSeriesID else { return }
                if !isEmbyRequestCancellation(error) {
                    self.errorMessage = error.localizedDescription
                    DiagnosticsLogger.shared.playback("EpisodeContext", "episodes failed series=\(requestedSeriesID) error=\(error.localizedDescription)")
                }
            }
        }
        episodeListTask = task
        await task.value
        if seriesID == requestedSeriesID { episodeListTask = nil }
    }
}

struct PlayerEpisodeSelectionOverlay: View {
    @ObservedObject var coordinator: PlayerEpisodeCoordinator
    let onDismiss: () -> Void
    let onSelect: (LibraryItem) -> Void
    @State private var selectedSeasonNumber: Int?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture(perform: onDismiss)
            panel
        }
        .onAppear { synchronizeSelectedSeason(force: true) }
        .onChange(of: coordinator.episodes.count) { _ in synchronizeSelectedSeason(force: selectedSeasonNumber == nil) }
        .onChange(of: coordinator.currentItemID) { _ in synchronizeSelectedSeason(force: true) }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 9) {
            seasonSelector
            if coordinator.episodes.isEmpty { emptyState }
            else { episodeScroller }
            if let errorMessage = coordinator.errorMessage, !coordinator.episodes.isEmpty {
                Text(errorMessage).font(.caption2).foregroundColor(.red.opacity(0.92)).lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 5)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var seasonSelector: some View {
        if seasonNumbers.count > 1 {
            Menu {
                ForEach(Array(seasonNumbers.reversed()), id: \.self) { season in
                    Button {
                        selectedSeasonNumber = season
                    } label: {
                        if season == effectiveSeasonNumber { Label(seasonTitle(season), systemImage: "checkmark") }
                        else { Text(seasonTitle(season)) }
                    }
                }
            } label: { seasonSelectorLabel }
            .buttonStyle(.plain)
            .accessibilityLabel("选择季")
        } else {
            seasonSelectorLabel
        }
    }

    private var seasonSelectorLabel: some View {
        HStack(spacing: 4) {
            Text(effectiveSeasonNumber.map(seasonTitle) ?? "选季")
                .font(.system(size: 13, weight: .semibold))
            if seasonNumbers.count > 1 { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.82), radius: 2, x: 0, y: 1)
        .frame(height: 26)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            if coordinator.isLoadingContext || coordinator.isLoadingEpisodes {
                ProgressView("正在加载剧集…").progressViewStyle(CircularProgressViewStyle(tint: .white)).foregroundColor(.white.opacity(0.86))
            } else {
                Text(coordinator.errorMessage ?? "没有可用剧集").font(.footnote).foregroundColor(.white.opacity(0.72))
            }
            Spacer()
        }
        .frame(height: 138)
    }

    private var episodeScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 13) {
                    ForEach(displayedEpisodes) { episode in episodeCard(episode).id(episode.id) }
                }
            }
            .onAppear { scrollToRelevantEpisode(proxy) }
            .onChange(of: selectedSeasonNumber) { _ in scrollToRelevantEpisode(proxy) }
            .onChange(of: coordinator.currentItemID) { _ in scrollToRelevantEpisode(proxy) }
            .onChange(of: displayedEpisodes.count) { _ in scrollToRelevantEpisode(proxy) }
        }
    }

    private func episodeCard(_ episode: LibraryItem) -> some View {
        let isCurrent = episode.id == coordinator.currentItemID
        let isResolving = episode.id == coordinator.resolvingItemID
        let overview = episodeOverview(episode)
        return Button {
            if isCurrent { onDismiss() }
            else { onSelect(episode) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .leading) {
                    EmbyCachedRemoteImage(url: coordinator.imageURL(for: episode), contentMode: .fill, placeholderSystemImage: "film", showsLoadingIndicator: false)
                        .frame(width: 174, height: 98)
                        .clipped()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if isCurrent {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.right.2").font(.system(size: 10.5, weight: .bold))
                            Text("正在播放").font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.64))
                        .clipShape(Capsule())
                        .padding(.leading, 9)
                    } else if isResolving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding(9).background(Color.black.opacity(0.64)).clipShape(Circle()).padding(.leading, 9)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isCurrent ? Color.white : Color.white.opacity(0.14), lineWidth: isCurrent ? 2 : 0.7))

                Text(episodeTitle(episode))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.82), radius: 2, x: 0, y: 1)

                Text(overview.isEmpty ? " " : overview)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(2)
                    .lineSpacing(1)
                    .frame(width: 174, minHeight: 28, alignment: .topLeading)
                    .opacity(overview.isEmpty ? 0 : 1)
                    .shadow(color: .black.opacity(0.72), radius: 2, x: 0, y: 1)
            }
            .frame(width: 174, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(coordinator.resolvingItemID != nil && !isCurrent)
        .accessibilityLabel(isCurrent ? "\(episodeTitle(episode))，正在播放" : episodeTitle(episode))
    }

    private var seasonNumbers: [Int] {
        Array(Set(coordinator.episodes.compactMap(\.parentIndexNumber))).sorted()
    }

    private var currentSeasonNumber: Int? {
        coordinator.episodes.first(where: { $0.id == coordinator.currentItemID })?.parentIndexNumber
    }

    private var effectiveSeasonNumber: Int? {
        if let selectedSeasonNumber, seasonNumbers.contains(selectedSeasonNumber) { return selectedSeasonNumber }
        if let currentSeasonNumber, seasonNumbers.contains(currentSeasonNumber) { return currentSeasonNumber }
        return seasonNumbers.first
    }

    private var displayedEpisodes: [LibraryItem] {
        guard let season = effectiveSeasonNumber else { return coordinator.episodes }
        return coordinator.episodes.filter { $0.parentIndexNumber == season }
    }

    private func seasonTitle(_ season: Int) -> String {
        season == 0 ? "特别篇" : "第\(season)季"
    }

    private func episodeTitle(_ episode: LibraryItem) -> String {
        let trimmed = episode.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let number = episode.indexNumber { return "第\(number)集" }
        return "剧集"
    }

    private func episodeOverview(_ episode: LibraryItem) -> String {
        episode.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func synchronizeSelectedSeason(force: Bool) {
        guard !seasonNumbers.isEmpty else { return }
        if force, let currentSeasonNumber, seasonNumbers.contains(currentSeasonNumber) { selectedSeasonNumber = currentSeasonNumber; return }
        if let selectedSeasonNumber, seasonNumbers.contains(selectedSeasonNumber) { return }
        selectedSeasonNumber = currentSeasonNumber ?? seasonNumbers.first
    }

    private func scrollToRelevantEpisode(_ proxy: ScrollViewProxy) {
        let items = displayedEpisodes
        guard let target = items.first(where: { $0.id == coordinator.currentItemID })?.id ?? items.first?.id else { return }
        DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.20)) { proxy.scrollTo(target, anchor: .leading) } }
    }
}
