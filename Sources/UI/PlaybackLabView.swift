import SwiftUI

struct PlaybackLabView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var model = PlaybackLabViewModel()
    @State private var client: EmbyAPIClient?
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            Form {
                if let session = sessionStore.session {
                    Section(header: Text("当前服务器")) {
                        LabeledValue(title: "名称", value: session.serverName)
                        LabeledValue(title: "版本", value: session.serverVersion)
                        LabeledValue(title: "用户", value: session.user.name)
                        LabeledValue(title: "入口", value: session.serverURL.absoluteString)
                    }
                }

                Section(header: Text("媒体测试")) {
                    TextField("输入 Emby ItemId", text: $model.itemId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("播放引擎由 App 在会话开始前自动选择；播放过程中保持当前引擎，不再热切换。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Button {
                        guard let client else { return }
                        Task { await model.load(client: client) }
                    } label: {
                        if model.isLoading {
                            ProgressView()
                        } else {
                            Text("加载媒体信息")
                        }
                    }
                    .disabled(client == nil || model.itemId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let item = model.item {
                    Section(header: Text("媒体条目")) {
                        LabeledValue(title: "标题", value: item.name)
                        LabeledValue(title: "类型", value: item.type ?? "未知")
                        LabeledValue(title: "ItemId", value: item.id)
                    }
                }

                if let info = model.playbackInfo {
                    Section(header: Text("媒体源（\(info.mediaSources.count)）")) {
                        ForEach(info.mediaSources) { source in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(model.item?.name ?? "媒体")
                                    .font(.headline)
                                if let sourceName = source.name, !sourceName.isEmpty {
                                    Text("媒体源：\(sourceName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(sourceSummary(source))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Button("播放") {
                                        guard let client else { return }
                                        model.resolve(client: client, mediaSource: source)
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button("115AVIO 实验") {
                                        guard let client else { return }
                                        model.resolveAVIO(client: client, mediaSource: source)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section(header: Text("错误")) {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section(header: Text("诊断")) {
                    Button("导出日志") {
                        do {
                            shareURL = try DiagnosticsLogger.shared.export()
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    }

                    Button("退出登录", role: .destructive) {
                        Task { await sessionStore.logout() }
                    }
                }
            }
            .navigationTitle("播放器实验室")
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                do {
                    client = try sessionStore.client()
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(item: $model.selectedSource) { source in
                if let client {
                    PlayerScreen(
                        source: source,
                        client: client,
                        preference: .automatic
                    )
                }
            }
            .fullScreenCover(item: $model.selectedAVIOSource) { source in
                AVIOBenchmarkView(source: source)
            }
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL {
                    ActivityView(items: [shareURL])
                }
            }
        }
    }

    private func sourceSummary(_ source: MediaSource) -> String {
        let duration = source.durationSeconds.map { formatTime($0) } ?? "未知时长"
        let size = source.size.map(ByteCountFormatter.string) ?? "未知大小"
        let video = source.videoCodec?.uppercased() ?? "未知视频"
        let audio = source.audioCodec?.uppercased() ?? "未知音频"
        return "\(source.container?.uppercased() ?? "UNKNOWN") · \(video) / \(audio) · \(duration) · \(size)"
    }
}

private struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension ByteCountFormatter {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
