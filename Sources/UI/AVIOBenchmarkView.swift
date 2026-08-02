import SwiftUI

struct AVIOBenchmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AVIOBenchmarkViewModel()
    @State private var shareURL: URL?

    let source: ResolvedPlaybackSource

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("隔离实验")) {
                    Text("本页面不启动 AVPlayer、MPV 或 FFmpeg，只测试 302 后的 115 网络模式和最小 AVIO read/seek 语义。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if model.isResolving {
                        HStack {
                            ProgressView()
                            Text("正在解析 302 和文件大小…")
                        }
                    } else if let resource = model.resolvedResource {
                        AVIOValueRow(title: "文件大小", value: ByteCountFormatter.string(fromByteCount: resource.contentLength, countStyle: .file))
                        AVIOValueRow(title: "HTTP Range", value: resource.supportsByteRanges ? "支持" : "不支持")
                        AVIOValueRow(title: "115 CDN", value: resource.looksLike115CDN ? "是" : "未识别")
                        AVIOValueRow(title: "重定向", value: "\(resource.redirectCount) 次")
                    }
                }

                Section(header: Text("实验参数")) {
                    Picker("请求头", selection: $model.requestProfileRaw) {
                        ForEach(AVIORequestProfile.allCases) { profile in
                            Text(profile.title).tag(profile.rawValue)
                        }
                    }
                    Text(model.requestProfile.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("单项持续时间", selection: $model.durationSeconds) {
                        Text("15 秒").tag(15)
                        Text("30 秒").tag(30)
                        Text("60 秒").tag(60)
                    }

                    Picker("有限 Range 总量", selection: $model.targetMB) {
                        Text("64 MB").tag(64)
                        Text("128 MB").tag(128)
                        Text("256 MB").tag(256)
                        Text("512 MB").tag(512)
                    }
                }
                .disabled(model.isRunning || model.resolvedResource == nil)

                Section(header: Text("网络基线")) {
                    Button("依次运行全部模式") { model.startAll() }
                        .disabled(model.isRunning || model.resolvedResource == nil)

                    ForEach(AVIOBenchmarkMode.allCases) { mode in
                        Button {
                            model.start(mode: mode)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title)
                                Text(mode.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(model.isRunning || model.resolvedResource == nil)
                    }

                    if let progress = model.progress {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: min(1, progress.elapsedSeconds / Double(model.durationSeconds)))
                            Text(progress.summary)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }

                    if model.isRunning {
                        Button("停止当前实验", role: .destructive) { model.cancel() }
                    }
                }

                Section(header: Text("最小 AVIO 自检")) {
                    Button("运行 read / seek / fileSize 轨迹") { model.runProbe() }
                        .disabled(model.isRunning || model.resolvedResource == nil)
                    Text("读取文件头两次，跳到文件中部读取，再跳回 1 MB 位置读取；用于验证后续 FFmpeg AVIO 桥接所需的逻辑位置语义。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let report = model.probeReport {
                        ForEach(report.operations) { operation in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(operation.operation)
                                    .font(.subheadline.monospaced())
                                Text("请求 \(operation.requestedOffset) → 结果 \(operation.resultingOffset) · \(operation.bytesRead) B · \(Int(operation.elapsedMilliseconds)) ms")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                if let error = operation.error {
                                    Text(error).font(.caption).foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                if !model.results.isEmpty {
                    Section(header: Text("实验结果")) {
                        ForEach(model.results) { result in
                            DisclosureGroup {
                                AVIOValueRow(title: "请求头", value: result.requestProfile.title)
                                AVIOValueRow(title: "实际时间", value: String(format: "%.1f 秒", result.actualDurationSeconds))
                                AVIOValueRow(title: "接收数据", value: ByteCountFormatter.string(fromByteCount: result.totalBytesReceived, countStyle: .file))
                                AVIOValueRow(title: "平均速度", value: speedText(result.averageBytesPerSecond))
                                AVIOValueRow(title: "首字节", value: result.firstByteMilliseconds.map { "\(Int($0)) ms" } ?? "无")
                                AVIOValueRow(title: "重定向", value: "\(result.redirectCount) 次")
                                ForEach(result.lanes) { lane in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(lane.label).font(.subheadline.monospaced())
                                        Text("\(lane.requestedRange) · \(speedText(lane.averageBytesPerSecond)) · \(ByteCountFormatter.string(fromByteCount: lane.bytesReceived, countStyle: .file))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.secondary)
                                        Text("HTTP \(lane.statusCode.map(String.init) ?? "-") · \(lane.networkProtocol ?? "协议未知") · 复用 \(lane.reusedConnection.map { $0 ? "是" : "否" } ?? "未知")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let error = lane.error {
                                            Text(error).font(.caption).foregroundColor(.red)
                                        }
                                    }
                                }
                                if let error = result.error {
                                    Text(error).font(.caption).foregroundColor(.red)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                    Text(result.summary)
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Button("导出 JSON 实验报告") {
                            do {
                                shareURL = try model.export()
                            } catch {
                                model.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section(header: Text("错误")) {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("115AVIO Lab")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        model.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear { model.prepare(source: source) }
            .onDisappear { model.cancel() }
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil },
                    set: { if !$0 { shareURL = nil } }
                )
            ) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func speedText(_ bytesPerSecond: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }
}

private struct AVIOValueRow: View {
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
