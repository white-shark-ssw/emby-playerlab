import SwiftUI

struct CacheSettingsView: View {
    @AppStorage(TransportSettingsKey.wifiPreloadMB) private var wifiCacheMB = VideoCacheCapacity.defaultWiFiMB
    @AppStorage(TransportSettingsKey.cellularPreloadMB) private var cellularCacheMB = VideoCacheCapacity.defaultCellularMB
    @AppStorage(TransportSettingsKey.keepLastCache) private var keepLastCache = true

    @State private var imageUsage = EmbyImageCacheUsage.zero
    @State private var videoUsage = CacheStorageUsage.zero
    @State private var clearTarget: CacheClearTarget?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section(header: Text("缓存管理")) {
                Button { clearTarget = .images } label: { cacheUsageRow(title: "图片缓存", systemImage: "photo.on.rectangle", usage: imageUsage.bytes) }.buttonStyle(.plain)
                Button { clearTarget = .videos } label: { cacheUsageRow(title: "视频缓存", systemImage: "film", usage: videoUsage.bytes) }.buttonStyle(.plain)
                if let statusMessage { Text(statusMessage).font(.footnote).foregroundColor(.secondary) }
            }

            Section(header: Text("视频缓存"), footer: Text("中途切换 Wi‑Fi / 蜂窝网络后，需要重新播放视频才能完整按新的缓存容量生效。")) {
                capacityMenu(title: "Wi-Fi 视频缓存", systemImage: "wifi", value: $wifiCacheMB, defaultValue: VideoCacheCapacity.defaultWiFiMB)
                capacityMenu(title: "蜂窝网络视频缓存", systemImage: "antenna.radiowaves.left.and.right", value: $cellularCacheMB, defaultValue: VideoCacheCapacity.defaultCellularMB)
            }

            Section(header: Text("缓存策略"), footer: Text("开启后保留最后一次播放的视频缓存；再次播放同一视频时会继续复用已有磁盘 Range。播放其他视频时，旧的长期缓存会自动清理。若当前网络设置为“不缓存”，则不会保留视频缓存。")) {
                Toggle("保留上次视频缓存", isOn: $keepLastCache)
            }

            Section {
                Text("图片只使用磁盘缓存，由 App 自动管理 LRU 与磁盘空间压力；不提供图片缓存容量和应用级内存缓存设置。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("缓存管理")
        .task {
            wifiCacheMB = VideoCacheCapacity.normalizedMB(wifiCacheMB, defaultValue: VideoCacheCapacity.defaultWiFiMB)
            cellularCacheMB = VideoCacheCapacity.normalizedMB(cellularCacheMB, defaultValue: VideoCacheCapacity.defaultCellularMB)
            await refreshUsage()
        }
        .alert(item: $clearTarget) { target in
            switch target {
            case .images:
                return Alert(
                    title: Text("清除图片缓存"),
                    message: Text("确定要清除所有已缓存的图片吗？清除后，海报和背景图片将在下次浏览时重新加载。"),
                    primaryButton: .destructive(Text("确定")) { Task { await clearImages() } },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .videos:
                return Alert(
                    title: Text("清除视频缓存"),
                    message: Text("确定要清除所有视频缓存吗？"),
                    primaryButton: .destructive(Text("确定")) { Task { await clearVideos() } },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }

    private func cacheUsageRow(title: String, systemImage: String, usage: Int64) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundColor(.blue).frame(width: 26)
            Text(title).foregroundColor(.primary)
            Spacer()
            Text(CacheStorageFormatter.string(bytes: usage)).foregroundColor(.secondary)
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func capacityMenu(title: String, systemImage: String, value: Binding<Int>, defaultValue: Int) -> some View {
        Menu {
            ForEach(VideoCacheCapacity.allCases) { option in
                Button {
                    value.wrappedValue = option.rawValue
                } label: {
                    if value.wrappedValue == option.rawValue { Label(option.title, systemImage: "checkmark") }
                    else { Text(option.title) }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage).foregroundColor(.blue).frame(width: 26)
                Text(title).foregroundColor(.primary)
                Spacer()
                Text(VideoCacheCapacity.title(for: VideoCacheCapacity.normalizedMB(value.wrappedValue, defaultValue: defaultValue))).foregroundColor(.secondary)
                Image(systemName: "arrow.up.arrow.down").font(.caption2).foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    @MainActor
    private func refreshUsage() async {
        imageUsage = await EmbyImageDiskCache.shared.usage()
        videoUsage = await Task.detached(priority: .utility) { TransportCacheMaintenance.videoUsage() }.value
    }

    @MainActor
    private func clearImages() async {
        await EmbyImageDiskCache.shared.clear()
        statusMessage = "图片缓存已清除"
        await refreshUsage()
    }

    @MainActor
    private func clearVideos() async {
        do {
            try await Task.detached(priority: .utility) { try TransportCacheMaintenance.clearVideoCaches() }.value
            statusMessage = "视频缓存已清除"
        } catch {
            statusMessage = error.localizedDescription
        }
        await refreshUsage()
    }
}

private enum CacheClearTarget: String, Identifiable {
    case images
    case videos
    var id: String { rawValue }
}
