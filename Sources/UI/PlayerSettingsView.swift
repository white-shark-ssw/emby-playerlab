import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue

    @AppStorage(TransportSettingsKey.strategy) private var transportStrategy = TransportStrategy.ktvHTTP.rawValue
    @AppStorage(TransportSettingsKey.cacheMode) private var cacheMode = TransportCacheMode.automatic.rawValue
    @AppStorage(TransportSettingsKey.memoryCacheMB) private var memoryCacheMB = 256
    @AppStorage(TransportSettingsKey.diskCacheGB) private var diskCacheGB = 2
    @AppStorage(TransportSettingsKey.wifiPreloadMB) private var wifiWindowMB = 128
    @AppStorage(TransportSettingsKey.cellularPreloadMB) private var cellularWindowMB = 64
    @AppStorage(TransportSettingsKey.segmentSizeMB) private var segmentSizeMB = 1
    @AppStorage(TransportSettingsKey.keepLastCache) private var keepLastCache = false
    @AppStorage(TransportSettingsKey.ktvContinuousPreload) private var ktvContinuousPreload = true
    @AppStorage(TransportSettingsKey.ktvPreloadOnCellular) private var ktvPreloadOnCellular = false

    @Environment(\.presentationMode) private var presentationMode
    @State private var cacheMaintenanceMessage: String?

    private let intervals = [5, 10, 15, 20, 30, 60]
    private let segmentSizes = [1, 2, 4]

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

                Section(header: Text("115 持续缓存实验")) {
                    Picker("传输实现", selection: $transportStrategy) {
                        ForEach(TransportStrategy.allCases) { strategy in
                            Text(strategy.title).tag(strategy.rawValue)
                        }
                    }
                    Picker("缓存位置", selection: $cacheMode) {
                        ForEach(TransportCacheMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    Stepper("内存缓存：\(memoryCacheMB) MB", value: $memoryCacheMB, in: 64...2048, step: 64)
                    Stepper("磁盘缓存预算：\(diskCacheGB) GB", value: $diskCacheGB, in: 0...50, step: 1)
                    Stepper("Wi-Fi 播放窗口：\(normalizedWiFiWindow) MB", value: wifiWindowBinding, in: 32...128, step: 16)
                    Stepper("蜂窝播放窗口：\(normalizedCellularWindow) MB", value: cellularWindowBinding, in: 16...64, step: 16)
                    Picker("缓存分片", selection: $segmentSizeMB) {
                        ForEach(segmentSizes, id: \.self) { size in Text("\(size) MB").tag(size) }
                    }
                    Toggle("持续预取到缓存上限或文件结尾", isOn: $ktvContinuousPreload)
                    Toggle("蜂窝网络也持续预取", isOn: $ktvPreloadOnCellular)
                    Toggle("退出后保留磁盘缓存", isOn: $keepLastCache)
                    Text("KTVHTTPCache 负责稀疏缓存，App 使用 16/32/64 MB 分段测速并自动选择表现更好的 Range 大小。连接持续低速或无增长时会从当前字节位置重建；Seek 后预取窗口立即迁移到目标位置，再继续补全文件。缓存预算大于视频体积时会自然形成完整缓存。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Button("清空已保留的传输缓存", role: .destructive) {
                        do {
                            try TransportCacheMaintenance.clearAll()
                            cacheMaintenanceMessage = "缓存已清空"
                        } catch {
                            cacheMaintenanceMessage = error.localizedDescription
                        }
                    }
                    if let cacheMaintenanceMessage {
                        Text(cacheMaintenanceMessage).font(.footnote).foregroundColor(.secondary)
                    }
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
            .onAppear {
                wifiWindowMB = normalizedWiFiWindow
                cellularWindowMB = normalizedCellularWindow
                if !segmentSizes.contains(segmentSizeMB) { segmentSizeMB = 1 }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private var normalizedWiFiWindow: Int { min(max(wifiWindowMB, 32), 128) }
    private var normalizedCellularWindow: Int { min(max(cellularWindowMB, 16), 64) }
    private var wifiWindowBinding: Binding<Int> { Binding(get: { normalizedWiFiWindow }, set: { wifiWindowMB = $0 }) }
    private var cellularWindowBinding: Binding<Int> { Binding(get: { normalizedCellularWindow }, set: { cellularWindowMB = $0 }) }
}
