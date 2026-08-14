import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue

    @Environment(\.presentationMode) private var presentationMode
    private let intervals = [5, 10, 15, 20, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("自动播放器")) {
                    Text("App 在播放开始前选择引擎。本次播放开始后固定使用该引擎；卡住时只等待缓存或恢复当前传输，不再自动热切换，避免警告后闪退。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("跳转手势")) {
                    Picker("快退秒数", selection: $backwardSeconds) {
                        ForEach(intervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Picker("快进秒数", selection: $forwardSeconds) {
                        ForEach(intervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Toggle("横向滑动屏幕调整进度", isOn: $screenPanEnabled)
                }

                Section(header: Text("原生前向缓冲")) {
                    Picker("缓冲策略", selection: $bufferPreset) {
                        ForEach(BufferPreset.allCases) { preset in
                            Text("\(preset.title)（\(Int(preset.seconds)) 秒）").tag(preset.rawValue)
                        }
                    }
                }

                Section {
                    Text("诊断日志会分别记录 115/CDN 上游缓存增长速度、分段 Range 选优、慢连接重建、Seek 下载迁移、视频帧冻结检测和同引擎恢复。")
                        .font(.footnote)
                }
            }
            .navigationTitle("播放设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
