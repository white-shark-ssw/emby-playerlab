import CryptoKit
import Foundation

enum TransportStrategy: String, CaseIterable, Identifiable {
    case unified
    case ktvHTTP
    case downloadFirst
    case legacyMultiRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unified: return "统一双槽 Range（v0.9）"
        case .ktvHTTP: return "KTVHTTPCache 持续预取（旧诊断）"
        case .downloadFirst: return "下载优先"
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
    static let ktvContinuousPreload = "transport.ktvContinuousPreload"
    static let ktvPreloadOnCellular = "transport.ktvPreloadOnCellular"
}

enum VideoCacheCapacity: Int, CaseIterable, Identifiable {
    case disabled = 0
    case mb256 = 256
    case mb512 = 512
    case gb1 = 1024
    case gb2 = 2048
    case gb3 = 3072
    case gb4 = 4096
    case gb5 = 5120
    case gb6 = 6144
    case gb7 = 7168
    case gb8 = 8192
    case gb9 = 9216
    case gb10 = 10240

    static let defaultWiFiMB = 2048
    static let defaultCellularMB = 512

    var id: Int { rawValue }
    var title: String { Self.title(for: rawValue) }

    static func title(for mb: Int) -> String {
        if mb <= 0 { return "不缓存" }
        if mb < 1024 { return "\(mb) MB" }
        return "\(mb / 1024) GB"
    }

    static func normalizedMB(_ value: Int, defaultValue: Int) -> Int {
        allCases.contains(where: { $0.rawValue == value }) ? value : defaultValue
    }
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
    let ktvContinuousPreloadEnabled: Bool
    let ktvPreloadOnCellular: Bool

    var usesMemoryCache: Bool { cacheMode == .memory || cacheMode == .automatic }
    var usesDiskCache: Bool { cacheMode == .disk || cacheMode == .automatic }

    func resourceLoaderProfile() -> MediaTransportConfiguration {
        MediaTransportConfiguration(
            strategy: .legacyMultiRange,
            cacheMode: cacheMode,
            memoryLimitBytes: 0,
            diskLimitBytes: diskLimitBytes,
            wifiPreloadBytes: wifiPreloadBytes,
            cellularPreloadBytes: cellularPreloadBytes,
            segmentSizeBytes: min(max(segmentSizeBytes, Int64(1_048_576)), Int64(4 * 1_048_576)),
            upstreamBlockSizeBytes: Int64(32 * 1_048_576),
            maximumConcurrentRequests: 2,
            keepLastCache: keepLastCache,
            ktvContinuousPreloadEnabled: ktvContinuousPreloadEnabled,
            ktvPreloadOnCellular: ktvPreloadOnCellular
        )
    }

    static func current(defaults: UserDefaults = .standard) -> MediaTransportConfiguration {
        defaults.register(defaults: [
            TransportSettingsKey.strategy: TransportStrategy.unified.rawValue,
            TransportSettingsKey.cacheMode: TransportCacheMode.disk.rawValue,
            TransportSettingsKey.memoryCacheMB: 0,
            TransportSettingsKey.diskCacheGB: 2,
            TransportSettingsKey.wifiPreloadMB: VideoCacheCapacity.defaultWiFiMB,
            TransportSettingsKey.cellularPreloadMB: VideoCacheCapacity.defaultCellularMB,
            TransportSettingsKey.segmentSizeMB: 1,
            TransportSettingsKey.upstreamBlockSizeMB: 32,
            TransportSettingsKey.concurrentRequests: 2,
            TransportSettingsKey.keepLastCache: true,
            TransportSettingsKey.ktvContinuousPreload: true,
            TransportSettingsKey.ktvPreloadOnCellular: true,
        ])

        let strategy = TransportStrategy(rawValue: defaults.string(forKey: TransportSettingsKey.strategy) ?? "") ?? .unified
        let wifiMB = VideoCacheCapacity.normalizedMB(defaults.integer(forKey: TransportSettingsKey.wifiPreloadMB), defaultValue: VideoCacheCapacity.defaultWiFiMB)
        let cellularMB = VideoCacheCapacity.normalizedMB(defaults.integer(forKey: TransportSettingsKey.cellularPreloadMB), defaultValue: VideoCacheCapacity.defaultCellularMB)
        let activeMB = NetworkPathMonitor.shared.isCellular ? cellularMB : wifiMB
        let segmentMB = [1, 2, 4].contains(defaults.integer(forKey: TransportSettingsKey.segmentSizeMB)) ? defaults.integer(forKey: TransportSettingsKey.segmentSizeMB) : 1
        let upstreamBlockMB = [4, 8, 16, 32, 64].contains(defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB)) ? defaults.integer(forKey: TransportSettingsKey.upstreamBlockSizeMB) : 32
        let activeBytes = Int64(activeMB) * 1_048_576
        let keepLast = defaults.bool(forKey: TransportSettingsKey.keepLastCache) && activeMB > 0

        return MediaTransportConfiguration(
            strategy: strategy,
            cacheMode: activeMB > 0 ? .disk : .disabled,
            memoryLimitBytes: 0,
            diskLimitBytes: activeBytes,
            wifiPreloadBytes: Int64(wifiMB) * 1_048_576,
            cellularPreloadBytes: Int64(cellularMB) * 1_048_576,
            segmentSizeBytes: Int64(segmentMB) * 1_048_576,
            upstreamBlockSizeBytes: Int64(upstreamBlockMB) * 1_048_576,
            maximumConcurrentRequests: 2,
            keepLastCache: keepLast,
            ktvContinuousPreloadEnabled: activeMB > 0,
            ktvPreloadOnCellular: cellularMB > 0
        )
    }
}

struct CacheStorageUsage: Equatable, Sendable {
    let bytes: Int64
    let fileCount: Int
    static let zero = CacheStorageUsage(bytes: 0, fileCount: 0)
}

enum CacheStorageFormatter {
    static func string(bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

enum TransportCacheMaintenance {
    private static let fileManager = FileManager.default
    private static var cacheRoot: URL { fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0] }
    private static var unifiedRoot: URL { cacheRoot.appendingPathComponent("EmbyPlayerLabDownloadFirst", isDirectory: true) }
    private static var legacyRoot: URL { cacheRoot.appendingPathComponent("EmbyPlayerLabTransport", isDirectory: true) }

    static func stableVideoCacheKey(for source: ResolvedPlaybackSource) -> String {
        let scheme = source.url.scheme?.lowercased() ?? "https"
        let host = source.url.host?.lowercased() ?? "unknown"
        let port = source.url.port.map { ":\($0)" } ?? ""
        let size = source.mediaSource.size ?? 0
        let container = source.mediaSource.normalizedContainer
        return "unified-v2|\(scheme)://\(host)\(port)|\(source.itemId)|\(source.mediaSource.id)|\(size)|\(container)"
    }

    static func preparePersistentVideoCache(cacheKey: String) {
        let keepName = digest(cacheKey)
        guard let directories = try? fileManager.contentsOfDirectory(at: unifiedRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        for directory in directories where directory.lastPathComponent != keepName { try? fileManager.removeItem(at: directory) }
    }

    static func clearPersistentUnifiedVideoCaches() {
        if fileManager.fileExists(atPath: unifiedRoot.path) { try? fileManager.removeItem(at: unifiedRoot) }
    }

    static func videoUsage() -> CacheStorageUsage {
        var bytes: Int64 = 0
        var fileCount = 0

        if let directories = try? fileManager.contentsOfDirectory(at: unifiedRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for directory in directories {
                let rangesURL = directory.appendingPathComponent("ranges.json")
                guard let data = try? Data(contentsOf: rangesURL), let ranges = try? JSONDecoder().decode([SparseStoredRange].self, from: data) else { continue }
                let itemBytes = ranges.reduce(Int64(0)) { $0 + max(0, $1.upperBound - $1.lowerBound) }
                if itemBytes > 0 { bytes += itemBytes; fileCount += 1 }
            }
        }

        if let directories = try? fileManager.contentsOfDirectory(at: legacyRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for directory in directories {
                let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
                let itemBytes = files.filter { $0.lastPathComponent.hasPrefix("segment-") }.reduce(Int64(0)) { result, file in
                    let values = try? file.resourceValues(forKeys: [.fileSizeKey])
                    return result + Int64(values?.fileSize ?? 0)
                }
                if itemBytes > 0 { bytes += itemBytes; fileCount += 1 }
            }
        }
        return CacheStorageUsage(bytes: bytes, fileCount: fileCount)
    }

    static func clearVideoCaches() throws {
        EPLKTVCacheBridge.clearAllCaches()
        for root in [unifiedRoot, legacyRoot] where fileManager.fileExists(atPath: root.path) { try fileManager.removeItem(at: root) }
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
