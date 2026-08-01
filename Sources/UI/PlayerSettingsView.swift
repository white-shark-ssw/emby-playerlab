import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue
    @Environment(\.presentationMode) private var presentationMode

    private let intervals = [5, 10, 15, 20, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("双击跳转")) {
                    Picker("快退秒数", selection: $backwardSeconds) {
                        ForEach(intervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Picker("快进秒数", selection: $forwardSeconds) {
                        ForEach(intervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                }

                Section(header: Text("前向缓冲")) {
                    Picker("策略", selection: $bufferPreset) {
                        ForEach(BufferPreset.allCases) { preset in
                            Text("\(preset.title)（\(Int(preset.seconds)) 秒）").tag(preset.rawValue)
                        }
                    }
                }

                Section {
                    Text("连续双击不会等待防抖；每次识别到双击后立即更新目标并提交 Seek。")
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
