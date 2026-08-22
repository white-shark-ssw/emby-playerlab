import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage(PlayerPreferenceKeys.enginePreference) private var enginePreference = PlayerEnginePreference.defaultPreference.rawValue
    @AppStorage(PlayerPreferenceKeys.backwardSeconds) private var backwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.forwardSeconds) private var forwardSeconds = 10
    @AppStorage(PlayerPreferenceKeys.bufferPreset) private var bufferPreset = BufferPreset.balanced.rawValue
    @AppStorage(PlayerPreferenceKeys.orientationPolicy) private var orientationPolicy = PlaybackOrientationPolicy.adaptive.rawValue
    @AppStorage(PlayerPreferenceKeys.temporaryPlaybackRate) private var temporaryPlaybackRate = 2.0
    @AppStorage(PlayerPreferenceKeys.volumeHapticsEnabled) private var volumeHapticsEnabled = true
    @AppStorage(PlayerPreferenceKeys.independentBrightnessEnabled) private var independentBrightnessEnabled = false
    @AppStorage(PlayerPreferenceKeys.pauseWhenBackgrounded) private var pauseWhenBackgrounded = true
    @AppStorage(PlayerPreferenceKeys.resumeWhenForegrounded) private var resumeWhenForegrounded = false
    @AppStorage(PlayerPreferenceKeys.defaultScaleMode) private var defaultScaleMode = PlayerVideoScaleMode.fit.rawValue
    @AppStorage(PlayerPreferenceKeys.controlsAutoHideSeconds) private var controlsAutoHideSeconds = 3.0

    @Environment(\.presentationMode) private var presentationMode
    private let seekIntervals = [5, 10, 15, 20, 30, 60]
    private let temporaryRates = [1.5, 1.75, 2.0, 2.5, 3.0]
    private let hideIntervals = [2.0, 3.0, 5.0, 0.0]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("播放器引擎"), footer: Text("高性能引擎为默认选择；高兼容引擎用于媒体兼容兜底。当前设置决定新播放会话使用的引擎。")) {
                    Picker("播放引擎", selection: $enginePreference) {
                        ForEach(PlayerEnginePreference.selectableCases) { preference in Text(preference.title).tag(preference.rawValue) }
                    }
                }

                Section(header: Text("播放")) {
                    Picker("播放方向", selection: $orientationPolicy) {
                        ForEach(PlaybackOrientationPolicy.allCases) { policy in Text(policy.title).tag(policy.rawValue) }
                    }
                    Toggle("挂起后自动暂停", isOn: $pauseWhenBackgrounded)
                    Toggle("回到前台自动播放", isOn: $resumeWhenForegrounded)
                }

                Section(header: Text("手势")) {
                    Picker("双击快退", selection: $backwardSeconds) {
                        ForEach(seekIntervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Picker("双击快进", selection: $forwardSeconds) {
                        ForEach(seekIntervals, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    Picker("长按临时倍速", selection: $temporaryPlaybackRate) {
                        ForEach(temporaryRates, id: \.self) { Text(rateTitle($0)).tag($0) }
                    }
                    Toggle("音量刻度震动", isOn: $volumeHapticsEnabled)
                    Toggle("播放器独立亮度", isOn: $independentBrightnessEnabled)
                }

                Section(header: Text("画面")) {
                    Picker("默认画面尺寸", selection: $defaultScaleMode) {
                        ForEach(PlayerVideoScaleMode.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
                    }
                }

                Section(header: Text("控制层")) {
                    Picker("自动隐藏", selection: $controlsAutoHideSeconds) {
                        ForEach(hideIntervals, id: \.self) { seconds in Text(seconds == 0 ? "从不" : "\(Int(seconds)) 秒").tag(seconds) }
                    }
                }

                Section(header: Text("前向缓冲")) {
                    Picker("缓冲策略", selection: $bufferPreset) {
                        ForEach(BufferPreset.allCases) { preset in Text("\(preset.title)（\(Int(preset.seconds)) 秒）").tag(preset.rawValue) }
                    }
                }
            }
            .navigationTitle("播放设置")
            .onAppear {
                let available = PlayerEnginePreference.persisted(rawValue: enginePreference)
                if available.rawValue != enginePreference { enginePreference = available.rawValue }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { presentationMode.wrappedValue.dismiss() } }
            }
        }
    }

    private func rateTitle(_ rate: Double) -> String {
        rate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fx", rate) : String(format: "%.2gx", rate)
    }
}
