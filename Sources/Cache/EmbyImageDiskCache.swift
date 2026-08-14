import CryptoKit
import Foundation

struct EmbyImageCacheUsage: Equatable, Sendable {
    let bytes: Int64
    let fileCount: Int
    static let zero = EmbyImageCacheUsage(bytes: 0, fileCount: 0)
}

actor EmbyImageDiskCache {
    static let shared = EmbyImageDiskCache()

    private let fileManager = FileManager.default
    private let root: URL
    private let softLimitBytes: Int64 = 2 * 1_073_741_824
    private let minimumFreeBytes: Int64 = 2 * 1_073_741_824
    private var writesSincePrune = 0

    private init() {
        root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("EmbyPlayerLabImages", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func data(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard let data = try? Data(contentsOf: file, options: [.mappedIfSafe]) else { return nil }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return data
    }

    func store(_ data: Data, for url: URL) {
        guard !data.isEmpty else { return }
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let file = fileURL(for: url)
        do {
            try data.write(to: file, options: .atomic)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            writesSincePrune += 1
            if writesSincePrune >= 24 {
                writesSincePrune = 0
                pruneIfNeeded()
            }
        } catch {
            DiagnosticsLogger.shared.log("ImageCache", "disk write failed: \(error.localizedDescription)")
        }
    }

    func remove(_ url: URL) { try? fileManager.removeItem(at: fileURL(for: url)) }

    func usage() -> EmbyImageCacheUsage {
        let files = cachedFiles()
        let bytes = files.reduce(Int64(0)) { result, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return result + Int64(values?.fileSize ?? 0)
        }
        return EmbyImageCacheUsage(bytes: bytes, fileCount: files.count)
    }

    func clear() {
        try? fileManager.removeItem(at: root)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        writesSincePrune = 0
    }

    private func stableKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        components.queryItems = (components.queryItems ?? []).filter { item in
            let name = item.name.lowercased()
            return name != "api_key" && name != "x-emby-token" && name != "token"
        }.sorted { lhs, rhs in
            if lhs.name == rhs.name { return (lhs.value ?? "") < (rhs.value ?? "") }
            return lhs.name < rhs.name
        }
        return components.string ?? url.absoluteString
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(stableKey(for: url).utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("\(digest).img")
    }

    private func cachedFiles() -> [URL] {
        (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]))?.filter { $0.pathExtension == "img" } ?? []
    }

    private func pruneIfNeeded() {
        let files = cachedFiles()
        guard !files.isEmpty else { return }
        let totalBytes = files.reduce(Int64(0)) { result, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return result + Int64(values?.fileSize ?? 0)
        }
        let available = (try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
        guard totalBytes > softLimitBytes || available < minimumFreeBytes else { return }

        let targetBytes = totalBytes > softLimitBytes ? softLimitBytes * 4 / 5 : max(0, totalBytes - (minimumFreeBytes - available))
        let sorted = files.sorted { lhs, rhs in
            let left = try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
            let right = try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
            return (left?.contentModificationDate ?? .distantPast) < (right?.contentModificationDate ?? .distantPast)
        }
        var remaining = totalBytes
        for file in sorted where remaining > targetBytes {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey])
            let bytes = Int64(values?.fileSize ?? 0)
            try? fileManager.removeItem(at: file)
            remaining = max(0, remaining - bytes)
        }
        DiagnosticsLogger.shared.log("ImageCache", "LRU prune before=\(totalBytes) after=\(remaining) available=\(available)")
    }
}
