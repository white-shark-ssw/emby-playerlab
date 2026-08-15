import SwiftUI

struct LogSettingsView: View {
    @AppStorage(DiagnosticsLogChannel.app.enabledKey) private var appLogEnabled = false
    @AppStorage(DiagnosticsLogChannel.playback.enabledKey) private var playbackLogEnabled = false
    @State private var shareURL: URL?
    @State private var clearChannel: DiagnosticsLogChannel?
    @State private var actionError: String?

    var body: some View {
        Form {
            logSection(channel: .app, enabled: $appLogEnabled, description: "记录页面、导航、Emby API、图片缓存和 App 生命周期等问题。")
            logSection(channel: .playback, enabled: $playbackLogEnabled, description: "记录播放器引擎、视频轨、解码、302 / Range、缓冲、Seek、EOF 和播放异常。出现有声无画等问题时可临时开启后复现并导出。")
        }
        .navigationTitle("日志")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivityView(items: [shareURL]) } }
        .alert("清理日志", isPresented: Binding(get: { clearChannel != nil }, set: { if !$0 { clearChannel = nil } })) {
            Button("取消", role: .cancel) { clearChannel = nil }
            Button("清理", role: .destructive) {
                if let channel = clearChannel { DiagnosticsLogger.shared.clear(channel) }
                clearChannel = nil
            }
        } message: {
            Text("将清空当前保存的\(clearChannel?.title ?? "日志")，此操作不可撤销。")
        }
        .alert("日志操作失败", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("好", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "未知错误")
        }
    }

    @ViewBuilder
    private func logSection(channel: DiagnosticsLogChannel, enabled: Binding<Bool>, description: String) -> some View {
        Section(header: Text(channel.title), footer: Text(description)) {
            Toggle("记录\(channel.title)", isOn: enabled)
            Button("导出\(channel.title)") { export(channel) }
            Button("清理\(channel.title)", role: .destructive) { clearChannel = channel }
        }
    }

    private func export(_ channel: DiagnosticsLogChannel) {
        do { shareURL = try DiagnosticsLogger.shared.export(channel) }
        catch { actionError = error.localizedDescription }
    }
}
