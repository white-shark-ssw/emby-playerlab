import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage("seek.backwardSeconds") private var backwardSeconds = 10
    @AppStorage("seek.forwardSeconds") private var forwardSeconds = 10
    @AppStorage("seek.screenPanEnabled") private var screenPanEnabled = true
    @AppStorage("buffer.preset") private var bufferPreset = BufferPreset.balanced.rawValue

    @AppStorage(TransportSettingsKey.cacheMode) private var cacheMode = TransportCacheMode.automatic.rawValue
    @AppStorage(TransportSettingsKey.memoryCacheMB) private var memoryCacheMB = 256
    @AppStorage(TransportSettingsKey.diskCacheGB) private var diskCacheGB = 2
    @AppStorage(TransportSettingsKey.wifiPreloadMB) private var wifiWindowMB = 128
    @AppStorage(TransportSettingsKey.cellularPreloadMB) private var cellularWindowMB = 64
    @AppStorage(TransportSettingsKey.segmentSizeMB) private var segmentSizeMB = 1
    @AppStorage(TransportSettingsKey.keepLastCache) private var keepLastCache = false

    @Environment(\.presentationMode) private var presentationMode
    @State private var cacheMaintenanceMessage: String?

    private let intervals = [5, 10, 15, 20, 30, 60]
    private let segmentSizes = [1, 2, 4]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("自动播放器")) {
                    Text("App 自动选择智能 AVPlayer、KSPlayer FFmpeg 或 MPV。普通播放不提供手动引擎开关；发生兼容问题时只会向更强容错引擎单向降级。")
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

                Section(header: Text("115 按需缓存")) {
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
                    Toggle("退出后保留磁盘缓存", isOn: $keepLastCache)
                    Text("播放窗口只覆盖当前播放位置前方的数据。Seek 后旧窗口立即降级，新位置先填充连续数据；不会再以尽快下载完整文件为播放目标。115 默认只使用一条连续预取连接，稳定阶段采用 64 MB 长 Range。")
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
                    Text("诊断日志会记录自动路由原因、当前位置有效速度、连续缓存、ResourceLoader 请求取消、引擎降级和 Seek 首帧耗时。")
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
