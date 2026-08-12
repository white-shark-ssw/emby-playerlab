from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


# Models: retain the current playback model and expand only metadata decoding.
models_path = Path("Sources/Models/EmbyModels.swift")
models = models_path.read_text()
models = replace_once(models,
'''    let officialRating: String?\n    let premiereDate: String?\n    let seriesName: String?\n''',
'''    let officialRating: String?\n    let premiereDate: String?\n    let dateCreated: String?\n    let seriesName: String?\n''', "LibraryItem dateCreated property")
models = replace_once(models,
'''        case officialRating = "OfficialRating"\n        case premiereDate = "PremiereDate"\n        case seriesName = "SeriesName"\n''',
'''        case officialRating = "OfficialRating"\n        case premiereDate = "PremiereDate"\n        case dateCreated = "DateCreated"\n        case seriesName = "SeriesName"\n''', "LibraryItem dateCreated key")
models = replace_once(models,
'''        officialRating = try? container.decode(String.self, forKey: .officialRating)\n        premiereDate = try? container.decode(String.self, forKey: .premiereDate)\n        seriesName = try? container.decode(String.self, forKey: .seriesName)\n''',
'''        officialRating = try? container.decode(String.self, forKey: .officialRating)\n        premiereDate = try? container.decode(String.self, forKey: .premiereDate)\n        dateCreated = try? container.decode(String.self, forKey: .dateCreated)\n        seriesName = try? container.decode(String.self, forKey: .seriesName)\n''', "LibraryItem dateCreated decode")
old_stream = '''struct MediaStream: Decodable, Hashable {\n    let index: Int?\n    let type: String?\n    let codec: String?\n    let language: String?\n    let displayTitle: String?\n    let isExternal: Bool?\n\n    enum CodingKeys: String, CodingKey {\n        case index = "Index"\n        case type = "Type"\n        case codec = "Codec"\n        case language = "Language"\n        case displayTitle = "DisplayTitle"\n        case isExternal = "IsExternal"\n    }\n}\n'''
new_stream = '''struct MediaStream: Decodable, Hashable {\n    let index: Int?\n    let type: String?\n    let codec: String?\n    let language: String?\n    let displayTitle: String?\n    let title: String?\n    let profile: String?\n    let level: Double?\n    let width: Int?\n    let height: Int?\n    let aspectRatio: String?\n    let isInterlaced: Bool?\n    let realFrameRate: Double?\n    let averageFrameRate: Double?\n    let bitRate: Int?\n    let videoRange: String?\n    let videoRangeType: String?\n    let colorPrimaries: String?\n    let colorSpace: String?\n    let colorTransfer: String?\n    let bitDepth: Int?\n    let pixelFormat: String?\n    let refFrames: Int?\n    let channels: Int?\n    let channelLayout: String?\n    let sampleRate: Int?\n    let isDefault: Bool?\n    let isForced: Bool?\n    let isExternal: Bool?\n\n    enum CodingKeys: String, CodingKey {\n        case index = "Index"\n        case type = "Type"\n        case codec = "Codec"\n        case language = "Language"\n        case displayTitle = "DisplayTitle"\n        case title = "Title"\n        case profile = "Profile"\n        case level = "Level"\n        case width = "Width"\n        case height = "Height"\n        case aspectRatio = "AspectRatio"\n        case isInterlaced = "IsInterlaced"\n        case realFrameRate = "RealFrameRate"\n        case averageFrameRate = "AverageFrameRate"\n        case bitRate = "BitRate"\n        case videoRange = "VideoRange"\n        case videoRangeType = "VideoRangeType"\n        case colorPrimaries = "ColorPrimaries"\n        case colorSpace = "ColorSpace"\n        case colorTransfer = "ColorTransfer"\n        case bitDepth = "BitDepth"\n        case pixelFormat = "PixelFormat"\n        case refFrames = "RefFrames"\n        case channels = "Channels"\n        case channelLayout = "ChannelLayout"\n        case sampleRate = "SampleRate"\n        case isDefault = "IsDefault"\n        case isForced = "IsForced"\n        case isExternal = "IsExternal"\n    }\n\n    init(from decoder: Decoder) throws {\n        let container = try decoder.container(keyedBy: CodingKeys.self)\n        index = try? container.decode(Int.self, forKey: .index)\n        type = try? container.decode(String.self, forKey: .type)\n        codec = try? container.decode(String.self, forKey: .codec)\n        language = try? container.decode(String.self, forKey: .language)\n        displayTitle = try? container.decode(String.self, forKey: .displayTitle)\n        title = try? container.decode(String.self, forKey: .title)\n        profile = try? container.decode(String.self, forKey: .profile)\n        level = try? container.decode(Double.self, forKey: .level)\n        width = try? container.decode(Int.self, forKey: .width)\n        height = try? container.decode(Int.self, forKey: .height)\n        aspectRatio = try? container.decode(String.self, forKey: .aspectRatio)\n        isInterlaced = try? container.decode(Bool.self, forKey: .isInterlaced)\n        realFrameRate = try? container.decode(Double.self, forKey: .realFrameRate)\n        averageFrameRate = try? container.decode(Double.self, forKey: .averageFrameRate)\n        bitRate = try? container.decode(Int.self, forKey: .bitRate)\n        videoRange = try? container.decode(String.self, forKey: .videoRange)\n        videoRangeType = try? container.decode(String.self, forKey: .videoRangeType)\n        colorPrimaries = try? container.decode(String.self, forKey: .colorPrimaries)\n        colorSpace = try? container.decode(String.self, forKey: .colorSpace)\n        colorTransfer = try? container.decode(String.self, forKey: .colorTransfer)\n        bitDepth = try? container.decode(Int.self, forKey: .bitDepth)\n        pixelFormat = try? container.decode(String.self, forKey: .pixelFormat)\n        refFrames = try? container.decode(Int.self, forKey: .refFrames)\n        channels = try? container.decode(Int.self, forKey: .channels)\n        channelLayout = try? container.decode(String.self, forKey: .channelLayout)\n        sampleRate = try? container.decode(Int.self, forKey: .sampleRate)\n        isDefault = try? container.decode(Bool.self, forKey: .isDefault)\n        isForced = try? container.decode(Bool.self, forKey: .isForced)\n        isExternal = try? container.decode(Bool.self, forKey: .isExternal)\n    }\n}\n'''
models = replace_once(models, old_stream, new_stream, "MediaStream metadata model")
models_path.write_text(models)


# Client: carry the already-known server display name into detail UI, no extra request.
client_path = Path("Sources/Networking/EmbyAPIClient.swift")
client = client_path.read_text()
client = replace_once(client,
'''    let baseURL: URL\n    let accessToken: String?\n    let userId: String?\n\n    init(baseURL: URL, accessToken: String? = nil, userId: String? = nil) {\n        self.baseURL = baseURL\n        self.accessToken = accessToken\n        self.userId = userId\n    }\n''',
'''    let baseURL: URL\n    let accessToken: String?\n    let userId: String?\n    let serverName: String?\n\n    init(baseURL: URL, accessToken: String? = nil, userId: String? = nil, serverName: String? = nil) {\n        self.baseURL = baseURL\n        self.accessToken = accessToken\n        self.userId = userId\n        self.serverName = serverName\n    }\n''', "EmbyAPIClient server name")
client_path.write_text(client)


session_path = Path("Sources/Session/SessionStore.swift")
session = session_path.read_text()
session = replace_once(session,
'''        return EmbyAPIClient(baseURL: stored.serverURL, accessToken: token, userId: stored.user.id)\n''',
'''        return EmbyAPIClient(baseURL: stored.serverURL, accessToken: token, userId: stored.user.id, serverName: stored.serverName)\n''', "SessionStore server name propagation")
session_path.write_text(session)


# Detail UI: frozen Hero is not edited. Only add body states/sections below it.
detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
detail = replace_once(detail,
'''    @State private var heroSourceSize: CGSize?\n    @State private var heroRawScrollMinY: CGFloat = 0\n''',
'''    @State private var heroSourceSize: CGSize?\n    @State private var heroRawScrollMinY: CGFloat = 0\n    @State private var mediaInfoExpanded = false\n    @State private var showRawMediaPath = false\n''', "detail media state")
detail = replace_once(detail,
'''                                castSection\n                                tagSection\n                                stillsSection\n                                similarSection\n                                if let error = model.errorMessage { errorView(error) }\n''',
'''                                castSection\n                                mediaStreamInfoSection\n                                tagSection\n                                stillsSection\n                                similarSection\n                                mediaSourceSummarySection\n                                if let error = model.errorMessage { errorView(error) }\n''', "detail media sections")
insert_marker = '''    @ViewBuilder\n    private var tagSection: some View {\n'''
media_ui = r'''    @ViewBuilder
    private var mediaStreamInfoSection: some View {
        if !model.mediaStreams.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.34)) { mediaInfoExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Text("音视频字幕信息").font(.title2.weight(.bold)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(mediaInfoExpanded ? 180 : 0))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                if mediaInfoExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(model.mediaStreams.enumerated()), id: \.offset) { index, stream in
                                mediaStreamCard(stream, ordinal: index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func mediaStreamCard(_ stream: MediaStream, ordinal: Int) -> some View {
        let rows = mediaInfoRows(for: stream)
        let style = mediaStreamStyle(stream, ordinal: ordinal)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: style.icon).font(.system(size: 16, weight: .semibold))
                Text(style.title).font(.headline)
            }
            .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(row.value)
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 308, alignment: .topLeading)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.045))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func mediaStreamStyle(_ stream: MediaStream, ordinal: Int) -> (title: String, icon: String) {
        let type = stream.type?.lowercased() ?? ""
        let base: (String, String)
        switch type {
        case "video": base = ("视频", "video.fill")
        case "audio": base = ("音频", "music.note")
        case "subtitle": base = ("字幕", "captions.bubble.fill")
        default: base = (stream.type ?? "媒体流", "waveform")
        }
        let sameType = model.mediaStreams.filter { ($0.type?.lowercased() ?? "") == type }
        guard sameType.count > 1 else { return base }
        let number = model.mediaStreams.prefix(ordinal + 1).filter { ($0.type?.lowercased() ?? "") == type }.count
        return ("\(base.0) #\(number)", base.1)
    }

    private func mediaInfoRows(for stream: MediaStream) -> [DetailMediaInfoRow] {
        var rows: [DetailMediaInfoRow] = []
        func add(_ label: String, _ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { rows.append(DetailMediaInfoRow(label: label, value: trimmed)) }
        }
        add("标题", stream.displayTitle)
        if let title = stream.title, title != stream.displayTitle { add("内嵌标题", title) }
        add("语言", stream.language)
        add("编解码器", stream.codec?.uppercased())
        let type = stream.type?.lowercased() ?? ""
        if type == "video" {
            add("配置", stream.profile)
            add("等级", stream.level.map(formatMediaDecimal))
            if let width = stream.width, let height = stream.height {
                add("分辨率", "\(width)×\(height)\(width >= 3500 ? " [4K]" : "")")
            }
            add("长宽比", stream.aspectRatio)
            add("交错", stream.isInterlaced.map(yesNo))
            add("帧率", (stream.realFrameRate ?? stream.averageFrameRate).map { "\(formatMediaDecimal($0)) fps" })
            add("比特率", stream.bitRate.map(formatMediaBitRate))
            add("视频范围", stream.videoRange ?? stream.videoRangeType)
            add("基色", stream.colorPrimaries)
            add("色域", stream.colorSpace)
            add("色偏", stream.colorTransfer)
            add("位深度", stream.bitDepth.map { "\($0) bit" })
            add("像素格式", stream.pixelFormat)
            add("参考帧", stream.refFrames.map(String.init))
        } else if type == "audio" {
            add("配置", stream.profile)
            add("布局", stream.channelLayout)
            add("频道", stream.channels.map { "\($0) ch" })
            add("比特率", stream.bitRate.map(formatMediaBitRate))
            add("采样率", stream.sampleRate.map { "\($0) Hz" })
            add("默认", stream.isDefault.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        } else if type == "subtitle" {
            add("默认", stream.isDefault.map(yesNo))
            add("强制", stream.isForced.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        } else {
            add("默认", stream.isDefault.map(yesNo))
            add("外部", stream.isExternal.map(yesNo))
        }
        return rows
    }

    @ViewBuilder
    private var mediaSourceSummarySection: some View {
        if let source = model.primaryMediaSource, let mediaItem = model.mediaMetadataItem {
            Button {
                guard let path = source.path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.20)) { showRawMediaPath.toggle() }
            } label: {
                VStack(spacing: 7) {
                    if showRawMediaPath, let path = source.path, !path.isEmpty {
                        Text(path)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("点击返回媒体信息")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(mediaSourceDisplayName(source, item: mediaItem))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary.opacity(0.86))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(mediaSourceSecondaryLine(source, item: mediaItem))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.035))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    private func mediaSourceDisplayName(_ source: MediaSource, item: LibraryItem) -> String {
        if let path = source.path?.removingPercentEncoding, !path.isEmpty {
            let last = path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? ""
            let withoutQuery = last.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? last
            if withoutQuery.contains(".") && !withoutQuery.isEmpty { return withoutQuery }
        }
        if let name = source.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        if let container = source.container?.trimmingCharacters(in: .whitespacesAndNewlines), !container.isEmpty { return "\(item.name).\(container.lowercased())" }
        return item.name
    }

    private func mediaSourceSecondaryLine(_ source: MediaSource, item: LibraryItem) -> String {
        var parts: [String] = []
        parts.append(client.serverName ?? client.baseURL.host ?? "Emby")
        if let date = formatMediaDate(item.dateCreated) { parts.append(date) }
        if let size = source.size, size > 0 { parts.append(formatMediaSize(size)) }
        return parts.joined(separator: "  ")
    }

    private func formatMediaDate(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: value)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: value)
        }
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func formatMediaSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes) B"
    }

    private func formatMediaBitRate(_ bitsPerSecond: Int) -> String {
        if bitsPerSecond >= 1_000_000 { return String(format: "%.2f Mbps", Double(bitsPerSecond) / 1_000_000) }
        return "\(max(0, bitsPerSecond / 1_000)) kbps"
    }

    private func formatMediaDecimal(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 { return String(Int(value.rounded())) }
        return String(format: "%.2f", value).replacingOccurrences(of: "0+$", with: "", options: .regularExpression).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    private func yesNo(_ value: Bool) -> String { value ? "是" : "否" }

'''
detail = replace_once(detail, insert_marker, media_ui + insert_marker, "detail media UI")
# ViewModel metadata state.
detail = replace_once(detail,
'''    @Published var isResolvingPlayback = false\n    @Published var selectedSource: ResolvedPlaybackSource?\n    @Published private var desiredFavorite: Bool\n''',
'''    @Published var isResolvingPlayback = false\n    @Published var selectedSource: ResolvedPlaybackSource?\n    @Published var mediaSources: [MediaSource] = []\n    @Published var mediaMetadataItem: LibraryItem?\n    @Published private var desiredFavorite: Bool\n''', "detail media ViewModel state")
detail = replace_once(detail,
'''    var displayedFavorite: Bool { desiredFavorite }\n    var displayedPlayed: Bool { desiredPlayed }\n    var normalizedOverview: String? { normalizedOverview(for: item) }\n\n    func normalizedOverview(for item: LibraryItem) -> String? {\n''',
'''    var displayedFavorite: Bool { desiredFavorite }\n    var displayedPlayed: Bool { desiredPlayed }\n    var normalizedOverview: String? { normalizedOverview(for: item) }\n    var primaryMediaSource: MediaSource? { mediaSources.first(where: { $0.supportsDirectPlay == true }) ?? mediaSources.first }\n    var mediaStreams: [MediaStream] {\n        let streams = primaryMediaSource?.mediaStreams ?? []\n        func priority(_ stream: MediaStream) -> Int {\n            switch stream.type?.lowercased() {\n            case "video": return 0\n            case "audio": return 1\n            case "subtitle": return 2\n            default: return 3\n            }\n        }\n        return streams.sorted { lhs, rhs in\n            let lp = priority(lhs), rp = priority(rhs)\n            if lp != rp { return lp < rp }\n            return (lhs.index ?? Int.max) < (rhs.index ?? Int.max)\n        }\n    }\n\n    func normalizedOverview(for item: LibraryItem) -> String? {\n''', "detail media computed properties")
detail = replace_once(detail,
'''            do { imageInfos = try await client.imageInfos(itemId: refreshed.id) }\n''',
'''            await loadMediaMetadata(for: primaryPlayableItem)\n\n            do { imageInfos = try await client.imageInfos(itemId: refreshed.id) }\n''', "detail metadata load call")
helper_marker = '''    func toggleFavorite() {\n'''
metadata_helper = '''    private func loadMediaMetadata(for mediaItem: LibraryItem?) async {\n        guard let mediaItem else {\n            mediaSources = []\n            mediaMetadataItem = nil\n            return\n        }\n        do {\n            let info = try await client.playbackInfo(itemId: mediaItem.id)\n            mediaSources = info.mediaSources\n            mediaMetadataItem = mediaItem\n        } catch {\n            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "media metadata failed: \\(error.localizedDescription)") }\n        }\n    }\n\n'''
detail = replace_once(detail, helper_marker, metadata_helper + helper_marker, "detail metadata loader")
detail_path.write_text(detail)

# A tiny local row model keeps SwiftUI ForEach stable and iOS 15-compatible.
detail = detail_path.read_text()
row_marker = '''struct EmbyDetailFilter: Identifiable, Hashable {\n'''
row_struct = '''private struct DetailMediaInfoRow: Identifiable {\n    let label: String\n    let value: String\n    var id: String { "\\(label)|\\(value)" }\n}\n\n'''
detail = replace_once(detail, row_marker, row_struct + row_marker, "detail media row model")
detail_path.write_text(detail)

# Focused regression checker. It also protects the already-approved Hero model.
checker = r'''from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


models = Path("Sources/Models/EmbyModels.swift").read_text()
client = Path("Sources/Networking/EmbyAPIClient.swift").read_text()
session = Path("Sources/Session/SessionStore.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
project = Path("project.yml").read_text()

require('case dateCreated = "DateCreated"' in models and 'let dateCreated: String?' in models, "detail media summary must decode DateCreated")
for token in ['case width = "Width"', 'case height = "Height"', 'case bitRate = "BitRate"', 'case bitDepth = "BitDepth"', 'case channels = "Channels"', 'case sampleRate = "SampleRate"', 'case isDefault = "IsDefault"', 'case isForced = "IsForced"']:
    require(token in models, f"missing media stream metadata field: {token}")
require('init(from decoder: Decoder) throws' in models and 'realFrameRate = try? container.decode(Double.self' in models, "MediaStream metadata must use tolerant per-field decoding")
require('let serverName: String?' in client and 'serverName: String? = nil' in client, "EmbyAPIClient must carry an optional server display name")
require('serverName: stored.serverName' in session, "SessionStore must propagate server name into EmbyAPIClient")
require('@State private var mediaInfoExpanded = false' in detail and '@State private var showRawMediaPath = false' in detail, "detail media UI state missing")
require('Text("音视频字幕信息")' in detail and 'Image(systemName: "chevron.up")' in detail, "foldable media stream header missing")
require('withAnimation(.easeInOut(duration: 0.34)) { mediaInfoExpanded.toggle() }' in detail, "media stream fold must retain competitor-style animation timing")
require('ScrollView(.horizontal, showsIndicators: false)' in detail and 'mediaStreamCard(stream, ordinal: index)' in detail, "media stream cards must use a horizontal container")
require('mediaSourceSummarySection' in detail and 'showRawMediaPath.toggle()' in detail and 'source.path' in detail, "media source card must toggle between summary and raw STRM/media path")
require('@Published var mediaSources: [MediaSource] = []' in detail and 'await loadMediaMetadata(for: primaryPlayableItem)' in detail, "detail ViewModel must load PlaybackInfo metadata")
require(detail.count('client.playbackInfo(itemId:') >= 2, "actual play must still request a fresh PlaybackInfo instead of reusing detail metadata")
require('detailBackdropViewportHeight(width: width)' in detail and 'responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor' in detail, "frozen detail Hero geometry must remain intact")
require('static let detailCropResponseFactor: CGFloat = 0.90' in metrics, "frozen 0.90 detail crop response must remain unchanged")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("detail media metadata invariants: OK")
'''
Path("scripts/check_detail_media_metadata.py").write_text(checker)
