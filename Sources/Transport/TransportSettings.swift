import Foundation

enum TransportStrategy: String, CaseIterable, Identifiable {
    case downloadFirst
    case legacyMultiRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloadFirst: return "下载优先（推荐）"
        case .legacyMultiRange: return "旧版多 Range"
        }
    }
}

enum TransportCacheMode: String, CaseIterable, Identifiable {
    case disabled
    case memory
    case disk
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: return "关闭"
        case .memory: return "内存"
        case .disk: return "磁盘"
        case .automatic: return "自动"
        }
    }
}

enum TransportSettingsKey {
    static let strategy = "transport.strategy"
    static let cacheMode = "transport.cacheMode"
    static let memoryCacheMB = "transport.memoryCacheMB"
    static let diskCacheGB = "transport.diskCacheGB"
    static let wifiPreloadMB = "transport.wifiPreloadMB"
    static let cellularPreloadMB = "transport.cellularPreloadMB"
    static let segmentSizeMB = "transport.segmentSizeMB"
    static let upstreamBlockSizeMB = "transport.upstreamBlockSizeMB"
    static let concurrentRequests = "transport.concurrentRequests"
    static let keepLastCache = "transport.keepLastCache"
}

struct MediaTransportConfiguration: Equatable {
    let strategy: TransportStrategy
    let cacheMode: TransportCacheMode
    let memoryLimitBytes: Int64
    let diskLimitBytes: Int64
    let wifiPreloadBytes: Int64
    let cellularPreloadBytes: Int64
    let segmentSizeBytes: Int64
    let upstreamBlockSizeBytes: Int64
    let maximumConcurrentRequests: Int
    let keepLastCache: Bool

    var usesMemoryCache: Bool {
        cacheMode == .memory || cacheMode == .automatic
    }

    var usesDiskCache: Bool {
        cacheMode == .disk || cacheMode == .automatic
    }

    func resourceLoaderProfile() -> MediaTransportConfiguration {
        let wifiWindow = min(max(wifiPreloadBytes, Int64(32 * 1_048_576)), Int64(128 * 1_048_576))
        let cellularWindow = min(max(cellularPreloadBytes, Int64(16 * 1_048_576)), Int64(64 * 1_048_576))
        let memoryCap = memoryLimitBytes > 0 ? min(memoryLimitBytes, Int64(128 * 1_048_576)) : 0
        return MediaTransportConfiguration(
            strategy: .legacyMultiRange,
            cacheMode: cacheMode,
            memoryLimitBytes: memoryCap,
            diskLimitBytes: diskLimitBytes,
            wifiPreloadBytes: wifiWindow,
            cellularPreloadBytes: cellularWindow,
            segmentSizeBytes: min(max(segmentSizeBytes, Int64(1_048_576)), Int64(4 * 1_048_576)),
            upstreamBlockSizeBytes: Int64(32 * 1_048_576),
            maximumConcurrentRequests: 2,
            keepLastCache: keepLastCache
        )
    }

    static func current(defaults: UserDefaults = .standard) -> MediaTransportConfiguration {
        defaults.register(defaults: [
            TransportSettingsKey.strategy: TransportStrategy.downloadFirst.rawValue,
            TransportSettingsKey.cacheMode: TransportCacheMode.automatic.rawValue,
            TransportSettingsKey.memoryCacheMB: 256,
            TransportSettingsKey.diskCacheGB: 2,
            TransportSettingsKey.wifiPreloadMB: 128,
            TransportSettingsKey.cellularPreloadMB: 64,
            TransportSettingsKey.segmentSizeMB: 1,
            TransportSettingsKey.upstreamBlockSizeMB: 16,
            TransportSettingsKey.concurrentRequests: 2,
            TransportSettingsKey.keepLastCache: false,
        ])

        let strategy = TransportStrategy(rawValue: defaults.string(forKey: TransportSettingsKey.strategy) ?? "") ?? .downloadFirst
        let mode = TransportCacheMode(rawValue: defaults.string(forKey: TransportSettingsKey.cacheMode) ?? "") ?? .automatic
        let memoryMB = max(0, defaults.integer(forKey: TransportSettingsKey.memoryCacheMB))
        let diskGB = max(0, defaults.integer(forKey: TransportSettingsKey.diskCacheGB))
        let wifiMB = max(0, defaults.integer(forKey: TransportSettingsKey.wifiPreloadMB))
        let cellularMB = max(0, defaults.integer(forKey: TransportSettingsKey.cellularPreloadMB))
        let segmentMB = [1, 2, 4, 8, 16].contains(defaults.integer(forKey: TransportSettingsKey.segmentSizeMB))
            ? defaults.integer(forKey: TransportSettingsKey.segmentSizeMB)
            : 1
        let upstreamBlockMB = [4, 8, 16, 32, 64].contains(defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB))
            ? defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB)
            : 16
        let concurrent = min(max(2, defaults.integer(forKey: TransportSettingsKey.concurrentRequests)), 8)

        return MediaTransportConfiguration(
            strategy: strategy,
            cacheMode: mode,
            memoryLimitBytes: Int64(memoryMB) * 1_048_576,
            diskLimitBytes: Int64(diskGB) * 1_073_741_824,
            wifiPreloadBytes: Int64(wifiMB) * 1_048_576,
            cellularPreloadBytes: Int64(cellularMB) * 1_048_576,
            segmentSizeBytes: Int64(segmentMB) * 1_048_576,
            upstreamBlockSizeBytes: Int64(upstreamBlockMB) * 1_048_576,
            maximumConcurrentRequests: concurrent,
            keepLastCache: defaults.bool(forKey: TransportSettingsKey.keepLastCache)
        )
    }
}

enum TransportCacheMaintenance {
    static func clearAll() throws {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for name in ["EmbyPlayerLabTransport", "EmbyPlayerLabDownloadFirst"] {
            let root = cacheRoot.appendingPathComponent(name, isDirectory: true)
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        }
    }
}
