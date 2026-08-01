import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue
    @AppStorage("player.enginePreference") private var enginePreference = PlayerEnginePreference.automatic.rawValue

    @AppStorage(TransportSettingsKey.cacheMode) private var cacheMode = TransportCacheMode.automatic.rawValue
    @AppStorage(TransportSettingsKey.memoryCacheMB) private var memoryCacheMB = 256
    @AppStorage(TransportSettingsKey.diskCacheGB) private var diskCacheGB = 2
    @AppStorage(TransportSettingsKey.wifiPreloadMB) private var wifiPreloadMB = 1024
    @AppStorage(TransportSettingsKey.cellularPreloadMB) private var cellularPreloadMB = 128
    @AppStorage(TransportSettingsKey.segmentSizeMB) private var segmentSizeMB = 1
    @AppStorage(TransportSettingsKey.upstreamBlockSizeMB) private var upstreamBlockSizeMB = 16
    @AppStorage(TransportSettingsKey.concurrentRequests) private var concurrentRequests = 4
    @AppStorage(TransportSettingsKey.keepLastCache) private var keepLastCache = false

    @Environment(\.presentationMode) private var presentationMode
    @State private var cacheMaintenanceMessage: String?

    private let intervals = [5, 10, 15, 20, 30, 60]
    private let segmentSizes = [1, 2, 4, 8, 16]
    private let upstreamBlockSizes = [4, 8, 16, 32, 64]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("播放器")) {
                    Picker("默认引擎", selection: $enginePreference) {
                        ForEach(PlayerEnginePreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    Text("自动模式下，MP4/MOV/M4V 优先使用 0.3 传输层 AVPlayer；其他容器暂时使用 MPV。播放页右上角按钮可循环切换。")
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

                Section(header: Text("115 / 302 传输缓存")) {
                    Picker("缓存模式", selection: $cacheMode) {
                        ForEach(TransportCacheMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }

                    Stepper("内存缓存：\(memoryCacheMB) MB", value: $memoryCacheMB, in: 64...2048, step: 64)
                    Stepper("磁盘缓存：\(diskCacheGB) GB", value: $diskCacheGB, in: 0...50, step: 1)
                    Stepper("Wi-Fi 预加载：\(wifiPreloadMB) MB", value: $wifiPreloadMB, in: 0...8192, step: 128)
                    Stepper("蜂窝预加载：\(cellularPreloadMB) MB", value: $cellularPreloadMB, in: 0...2048, step: 64)

                    Picker("本地缓存分片", selection: $segmentSizeMB) {
                        ForEach(segmentSizes, id: \.self) { size in
                            Text("\(size) MB").tag(size)
                        }
                    }

                    Picker("115 持续预取块", selection: $upstreamBlockSizeMB) {
                        ForEach(upstreamBlockSizes, id: \.self) { size in
                            Text("\(size) MB").tag(size)
                        }
                    }

                    Stepper("并行下载通道：\(concurrentRequests)", value: $concurrentRequests, in: 2...8)
                    Text("本地分片保持 1 MB 可加快起播和 Seek；后台会用多条独立连接持续下载较大的 115 Range，并边下载边拆分写入缓存。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Toggle("退出后保留磁盘缓存", isOn: $keepLastCache)

                    Button("清空已保留的传输缓存", role: .destructive) {
                        do {
                            try TransportCacheMaintenance.clearAll()
                            cacheMaintenanceMessage = "缓存已清空"
                        } catch {
                            cacheMaintenanceMessage = error.localizedDescription
                        }
                    }
                    if let cacheMaintenanceMessage {
                        Text(cacheMaintenanceMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("传输层会缓存 Emby 302 解析出的 115 临时直链。播放请求使用小分片保证响应速度，后台预加载使用独立长连接和大 Range 提升吞吐；临时直链连续返回 403/410 时才重新请求 PlaybackInfo。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("旧引擎前向缓冲")) {
                    Picker("MPV/原生 AV 策略", selection: $bufferPreset) {
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
            .onAppear {
                if concurrentRequests < 2 { concurrentRequests = 2 }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
