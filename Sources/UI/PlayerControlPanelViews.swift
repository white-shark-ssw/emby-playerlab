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

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Group {
                switch panel {
                case .info:
                    PlayerPlaybackInfoView(source: source)
                case .tracks:
                    PlayerTrackOverviewView(source: source)
                case .episodes:
                    PlayerUnavailablePanelView(message: "当前播放入口还没有携带剧集列表，选集会在下一阶段接入 Emby 剧集上下文。")
                case .speed:
                    PlayerSpeedPickerView(currentRate: currentRate, onSelect: onRateSelected)
                }
            }
            .navigationTitle(panel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { presentationMode.wrappedValue.dismiss() } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct PlayerPlaybackInfoView: View {
    let source: ResolvedPlaybackSource

    var body: some View {
        Form {
            Section(header: Text("媒体")) {
                infoRow("容器", source.mediaSource.container?.uppercased())
                infoRow("时长", source.mediaSource.durationSeconds.map(formatTime))
                if let size = source.mediaSource.size { infoRow("文件大小", ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
            }

            if let video = videoStream {
                Section(header: Text("视频")) {
                    infoRow("编码", video.codec?.uppercased())
                    if let width = video.width, let height = video.height { infoRow("分辨率", "\(width) × \(height)") }
                    infoRow("显示比例", video.displayAspectRatio.map { String(format: "%.3f:1", $0) })
                    if let rotation = video.rotation, rotation % 360 != 0 { infoRow("旋转", "\(rotation)°") }
                    if let frameRate = video.averageFrameRate ?? video.realFrameRate { infoRow("帧率", String(format: "%.3g fps", frameRate)) }
                    if let bitRate = video.bitRate { infoRow("码率", bitrateTitle(bitRate)) }
                    infoRow("动态范围", video.videoRangeType ?? video.videoRange)
                    if let bitDepth = video.bitDepth { infoRow("位深", "\(bitDepth) bit") }
                    infoRow("像素格式", video.pixelFormat)
                }
            }

            if let audio = audioStream {
                Section(header: Text("音频")) {
                    infoRow("编码", audio.codec?.uppercased())
                    infoRow("声道", audio.channelLayout ?? audio.channels.map(String.init))
                    if let sampleRate = audio.sampleRate { infoRow("采样率", "\(sampleRate) Hz") }
                    if let bitRate = audio.bitRate { infoRow("码率", bitrateTitle(bitRate)) }
                    infoRow("语言", audio.language)
                }
            }
        }
    }

    private var videoStream: MediaStream? { source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame }) }
    private var audioStream: MediaStream? { source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Audio") == .orderedSame }) }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Text(title)
                Spacer()
                Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing)
            }
        }
    }

    private func bitrateTitle(_ value: Int) -> String {
        value >= 1_000_000 ? String(format: "%.2f Mbps", Double(value) / 1_000_000) : String(format: "%.0f Kbps", Double(value) / 1_000)
    }
}

private struct PlayerTrackOverviewView: View {
    let source: ResolvedPlaybackSource

    var body: some View {
        Form {
            Section(footer: Text("这里先展示 Emby 返回的轨道信息。真正的轨道切换会在播放器引擎暴露统一选择接口后启用，当前不会假装已经切换成功。")) {
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, stream in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trackTitle(stream, fallbackIndex: index)).font(.body)
                        Text(trackDetail(stream)).font(.caption).foregroundColor(.secondary)
                    }
                }
                if tracks.isEmpty { Text("没有可用的音轨或字幕信息").foregroundColor(.secondary) }
            }
        }
    }

    private var tracks: [MediaStream] {
        (source.mediaSource.mediaStreams ?? []).filter {
            $0.type?.caseInsensitiveCompare("Audio") == .orderedSame || $0.type?.caseInsensitiveCompare("Subtitle") == .orderedSame
        }
    }

    private func trackTitle(_ stream: MediaStream, fallbackIndex: Int) -> String {
        let type = stream.type?.caseInsensitiveCompare("Subtitle") == .orderedSame ? "字幕" : "音轨"
        return stream.displayTitle ?? stream.title ?? "\(type) \(stream.index ?? fallbackIndex)"
    }

    private func trackDetail(_ stream: MediaStream) -> String {
        [stream.codec?.uppercased(), stream.language, stream.isDefault == true ? "默认" : nil, stream.isForced == true ? "强制" : nil, stream.isExternal == true ? "外挂" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private struct PlayerSpeedPickerView: View {
    let currentRate: Double
    let onSelect: (Double) -> Void
    private let rates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var body: some View {
        List(rates, id: \.self) { rate in
            Button {
                onSelect(rate)
            } label: {
                HStack {
                    Text(String(format: "%.2gx", rate))
                    Spacer()
                    if abs(currentRate - rate) < 0.001 { Image(systemName: "checkmark") }
                }
            }
        }
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
