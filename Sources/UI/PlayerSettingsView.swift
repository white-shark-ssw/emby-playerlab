import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue
    @AppStorage("player.enginePreference") private var enginePreference = PlayerEnginePreference.automatic.rawValue
    @Environment(\.presentationMode) private var presentationMode

    private let intervals = [5, 10, 15, 20, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("播放器")) {
                    Picker("默认引擎", selection: $enginePreference) {
                        ForEach(PlayerEnginePreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    Text("当前播放页右上角的 AV/MPV 按钮可以立即切换引擎。")
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

                Section(header: Text("前向缓冲")) {
                    Picker("策略", selection: $bufferPreset) {
                        ForEach(BufferPreset.allCases) { preset in
                            Text("\(preset.title)（\(Int(preset.seconds)) 秒）").tag(preset.rawValue)
                        }
                    }
                }

                Section {
                    Text("双击识别后立即 Seek；横向滑动只更新目标预览，松手时才提交一次 Seek，避免拖动过程中连续产生 Range 请求。")
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
