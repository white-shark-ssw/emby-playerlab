import SwiftUI

enum PlayerControlPanel: String, Identifiable {
    case info
    case tracks
    case episodes
    case speed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .info: return "播放信息"
        case .tracks: return "音轨字幕"
        case .episodes: return "选集"
        case .speed: return "倍速"
        }
    }
}

struct PlayerBottomFunctionBar: View {
    let tracksEnabled: Bool
    let episodesEnabled: Bool
    let currentRate: Double
    let onSelect: (PlayerControlPanel) -> Void

    var body: some View {
        HStack(spacing: 4) {
            functionButton(title: "播放信息", systemImage: "info.circle", enabled: true) { onSelect(.info) }
            functionButton(title: "音轨字幕", systemImage: "captions.bubble", enabled: tracksEnabled) { onSelect(.tracks) }
            functionButton(title: "选集", systemImage: "rectangle.stack", enabled: episodesEnabled) { onSelect(.episodes) }
            functionButton(title: rateTitle, systemImage: "speedometer", enabled: true) { onSelect(.speed) }
        }
        .frame(maxWidth: .infinity)
    }

    private var rateTitle: String {
        currentRate == 1 ? "倍速" : String(format: "%.2gx", currentRate)
    }

    private func functionButton(title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 17, weight: .medium))
                Text(title).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
    }
}

struct PlayerControlPanelSheet: View {
    let panel: PlayerControlPanel
    let source: ResolvedPlaybackSource
    let currentRate: Double
    let onRateSelected: (Double) -> Void
    let trackProvider: () -> [PlayerSelectableTrack]
    let onTrackSelected: (PlayerSelectableTrack) -> Bool

    @Environment(\.presentationMode) private var presentationMode

    init(
        panel: PlayerControlPanel,
        source: ResolvedPlaybackSource,
        currentRate: Double,
        onRateSelected: @escaping (Double) -> Void,
        trackProvider: @escaping () -> [PlayerSelectableTrack] = { [] },
        onTrackSelected: @escaping (PlayerSelectableTrack) -> Bool = { _ in false }
    ) {
        self.panel = panel
        self.source = source
        self.currentRate = currentRate
        self.onRateSelected = onRateSelected
        self.trackProvider = trackProvider
        self.onTrackSelected = onTrackSelected
    }

    @ViewBuilder
    var body: some View {
        switch panel {
        case .info, .speed:
            PlayerFloatingPanelOverlay(
                panel: panel,
                source: source,
                currentRate: currentRate,
                onRateSelected: onRateSelected,
                onDismiss: dismiss
            )
            .playerFloatingPanelPresentation()
        case .tracks, .episodes:
            legacyPanel
        }
    }

    private var legacyPanel: some View {
        NavigationView {
            Group {
                switch panel {
                case .tracks:
                    PlayerTrackSelectionView(source: source, trackProvider: trackProvider, onSelect: onTrackSelected)
                case .episodes:
                    PlayerUnavailablePanelView(message: "当前播放入口还没有携带剧集列表，选集会在下一阶段接入 Emby 剧集上下文。")
                case .info, .speed:
                    EmptyView()
                }
            }
            .navigationTitle(panel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成", action: dismiss) }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

private struct PlayerTrackSelectionView: View {
    let source: ResolvedPlaybackSource
    let trackProvider: () -> [PlayerSelectableTrack]
    let onSelect: (PlayerSelectableTrack) -> Bool

    @State private var tracks: [PlayerSelectableTrack] = []
    @State private var selectionError: String?

    var body: some View {
        Form {
            if !audioTracks.isEmpty {
                Section(header: Text("音轨")) {
                    ForEach(audioTracks) { track in selectableRow(track) }
                }
            }

            if !subtitleTracks.isEmpty {
                Section(header: Text("字幕")) {
                    ForEach(subtitleTracks) { track in selectableRow(track) }
                }
            }

            if tracks.isEmpty {
                Section(footer: Text("当前播放器尚未暴露可确认的实时轨道选择。这里仅展示 Emby 返回的信息，不会伪装成已切换成功。")) {
                    ForEach(Array(embyTracks.enumerated()), id: \.offset) { index, stream in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(embyTrackTitle(stream, fallbackIndex: index)).font(.body)
                            Text(embyTrackDetail(stream)).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if embyTracks.isEmpty { Text("没有可用的音轨或字幕信息").foregroundColor(.secondary) }
                }
            }

            if let selectionError {
                Section {
                    Text(selectionError).font(.footnote).foregroundColor(.red)
                }
            }
        }
        .onAppear(perform: reload)
    }

    private var audioTracks: [PlayerSelectableTrack] { tracks.filter { $0.kind == .audio } }
    private var subtitleTracks: [PlayerSelectableTrack] { tracks.filter { $0.kind == .subtitle } }
    private var embyTracks: [MediaStream] {
        (source.mediaSource.mediaStreams ?? []).filter {
            $0.type?.caseInsensitiveCompare("Audio") == .orderedSame || $0.type?.caseInsensitiveCompare("Subtitle") == .orderedSame
        }
    }

    private func selectableRow(_ track: PlayerSelectableTrack) -> some View {
        Button {
            if onSelect(track) {
                selectionError = nil
                reload()
            } else {
                selectionError = "播放器没有确认这次轨道切换，当前选择未改变。"
                reload()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title).foregroundColor(.primary)
                    if let detail = track.detail, !detail.isEmpty { Text(detail).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                if track.isSelected { Image(systemName: "checkmark").foregroundColor(.accentColor) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        tracks = trackProvider()
    }

    private func embyTrackTitle(_ stream: MediaStream, fallbackIndex: Int) -> String {
        let type = stream.type?.caseInsensitiveCompare("Subtitle") == .orderedSame ? "字幕" : "音轨"
        return stream.displayTitle ?? stream.title ?? "\(type) \(stream.index ?? fallbackIndex)"
    }

    private func embyTrackDetail(_ stream: MediaStream) -> String {
        [stream.codec?.uppercased(), stream.language, stream.isDefault == true ? "默认" : nil, stream.isForced == true ? "强制" : nil, stream.isExternal == true ? "外挂" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private struct PlayerUnavailablePanelView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hourglass").font(.system(size: 34)).foregroundColor(.secondary)
            Text(message).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(28)
    }
}
