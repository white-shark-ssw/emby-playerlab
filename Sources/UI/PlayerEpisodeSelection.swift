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
    private var activeSource: ResolvedPlaybackSource
    private var seriesID: String?
    private var contextResolvedItemID: String?
    private var loadedSeriesID: String?
    private var prepareTask: Task<Void, Never>?
    private var episodeListTask: Task<Void, Never>?

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient) {
        self.activeSource = source
        self.currentItemID = source.itemId
        self.client = client
    }

    func activate(source: ResolvedPlaybackSource) {
        guard source.itemId != currentItemID else { activeSource = source; return }
        activeSource = source
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
        client.imageURL(itemId: episode.preferredPrimaryImageItemId, maxWidth: 640, tag: episode.preferredPrimaryImageTag)
    }

    func episodeCode(_ episode: LibraryItem) -> String {
        let season = episode.parentIndexNumber.map { "S\($0)" } ?? "S?"
        let number = episode.indexNumber.map { "E\($0)" } ?? "E?"
        return "\(season) \(number)"
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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.20).ignoresSafeArea().contentShape(Rectangle()).onTapGesture(perform: onDismiss)
            panel
        }
        .ignoresSafeArea()
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选集").font(.system(size: 18, weight: .bold))
                    if let seriesName = coordinator.seriesName, !seriesName.isEmpty { Text(seriesName).font(.caption).foregroundColor(.white.opacity(0.62)).lineLimit(1) }
                }
                Spacer()
                if coordinator.isLoadingEpisodes { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 34, height: 34).background(Color.white.opacity(0.10)).clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭选集")
            }
            .padding(.horizontal, 18)

            if coordinator.episodes.isEmpty {
                HStack {
                    Spacer()
                    if coordinator.isLoadingContext || coordinator.isLoadingEpisodes { ProgressView("正在加载剧集…").progressViewStyle(CircularProgressViewStyle(tint: .white)).foregroundColor(.white.opacity(0.82)) }
                    else { Text(coordinator.errorMessage ?? "没有可用剧集").font(.footnote).foregroundColor(.white.opacity(0.68)) }
                    Spacer()
                }
                .frame(height: 142)
            } else {
                episodeScroller
            }

            if let errorMessage = coordinator.errorMessage, !coordinator.episodes.isEmpty { Text(errorMessage).font(.caption2).foregroundColor(.red.opacity(0.90)).padding(.horizontal, 18).lineLimit(2) }
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.88))
    }

    private var episodeScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(coordinator.episodes) { episode in episodeCard(episode).id(episode.id) }
                }
                .padding(.horizontal, 18)
            }
            .onAppear { scrollToCurrent(proxy) }
            .onChange(of: coordinator.episodes.count) { _ in scrollToCurrent(proxy) }
            .onChange(of: coordinator.currentItemID) { _ in scrollToCurrent(proxy) }
        }
    }

    private func episodeCard(_ episode: LibraryItem) -> some View {
        let isCurrent = episode.id == coordinator.currentItemID
        let isResolving = episode.id == coordinator.resolvingItemID
        return Button {
            if isCurrent { onDismiss() }
            else { onSelect(episode) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .leading) {
                    EmbyCachedRemoteImage(url: coordinator.imageURL(for: episode), contentMode: .fill, placeholderSystemImage: "film", showsLoadingIndicator: false)
                        .frame(width: 190, height: 107)
                        .clipped()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    if isCurrent {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right.2").font(.system(size: 12, weight: .bold))
                            Text("正在播放").font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.62))
                        .clipShape(Capsule())
                        .padding(.leading, 10)
                    } else if isResolving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding(10).background(Color.black.opacity(0.62)).clipShape(Circle()).padding(.leading, 10)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(isCurrent ? Color.white : Color.white.opacity(0.12), lineWidth: isCurrent ? 2 : 0.8))

                Text(coordinator.episodeCode(episode)).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(episode.name).font(.system(size: 12.5, weight: .regular)).foregroundColor(.white.opacity(0.62)).lineLimit(1)
            }
            .frame(width: 190, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(coordinator.resolvingItemID != nil && !isCurrent)
        .accessibilityLabel(isCurrent ? "\(coordinator.episodeCode(episode))，正在播放" : coordinator.episodeCode(episode))
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        let itemID = coordinator.currentItemID
        DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.20)) { proxy.scrollTo(itemID, anchor: .center) } }
    }
}
