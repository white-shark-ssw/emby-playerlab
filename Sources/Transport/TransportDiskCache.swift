import CryptoKit
import Foundation

actor TransportDiskCache {
    private struct Metadata: Codable, Equatable {
        let contentLength: Int64
        let etag: String?
        let lastModified: String?
    }

    private let directory: URL
    private let limitBytes: Int64
    private let keepFiles: Bool
    private var currentBytes: Int64 = 0

    init(cacheKey: String, limitBytes: Int64, keepFiles: Bool) {
        self.limitBytes = max(0, limitBytes)
        self.keepFiles = keepFiles

        let digest = SHA256.hash(data: Data(cacheKey.utf8)).map { String(format: "%02x", $0) }.joined()
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmbyPlayerLabTransport", isDirectory: true)
        directory = root.appendingPathComponent(digest, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        currentBytes = Self.calculateSize(directory: directory)
    }

    func validate(contentLength: Int64, etag: String?, lastModified: String?) {
        let expected = Metadata(contentLength: contentLength, etag: etag, lastModified: lastModified)
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let existing: Metadata? = {
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? JSONDecoder().decode(Metadata.self, from: data)
        }()

        if let existing, existing != expected {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            files.filter { $0.lastPathComponent != "metadata.json" }.forEach { try? FileManager.default.removeItem(at: $0) }
            currentBytes = 0
            DiagnosticsLogger.shared.log("TransportDisk", "metadata changed; stale segments cleared")
        }

        if let data = try? JSONEncoder().encode(expected) {
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    func contains(start: Int64) -> Bool {
        guard limitBytes > 0 else { return false }
        return FileManager.default.fileExists(atPath: fileURL(start: start).path)
    }

    func read(start: Int64) -> Data? {
        guard limitBytes > 0 else { return nil }
        let url = fileURL(start: start)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    func write(_ data: Data, start: Int64) {
        guard limitBytes > 0, !data.isEmpty else { return }
        let url = fileURL(start: start)
        let oldAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let oldSize = (oldAttributes?[.size] as? NSNumber)?.int64Value ?? 0
        do {
            try data.write(to: url, options: .atomic)
            currentBytes = max(0, currentBytes - oldSize) + Int64(data.count)
            evictIfNeeded()
        } catch {
            DiagnosticsLogger.shared.log("TransportDisk", "write failed: \(error.localizedDescription)")
        }
    }

    func size() -> Int64 {
        currentBytes
    }

    func close() {
        guard !keepFiles else { return }
        try? FileManager.default.removeItem(at: directory)
        currentBytes = 0
    }

    private func fileURL(start: Int64) -> URL {
        directory.appendingPathComponent("segment-\(start).bin")
    }

    private func evictIfNeeded() {
        guard currentBytes > limitBytes else { return }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        let segmentFiles = files.filter { $0.lastPathComponent.hasPrefix("segment-") }
        let sorted = segmentFiles.sorted { lhs, rhs in
            let leftValues = try? lhs.resourceValues(forKeys: keys)
            let rightValues = try? rhs.resourceValues(forKeys: keys)
            return (leftValues?.contentModificationDate ?? .distantPast)
                < (rightValues?.contentModificationDate ?? .distantPast)
        }

        for file in sorted where currentBytes > limitBytes {
            let values = try? file.resourceValues(forKeys: keys)
            let size = Int64(values?.fileSize ?? 0)
            try? FileManager.default.removeItem(at: file)
            currentBytes = max(0, currentBytes - size)
        }
    }

    private static func calculateSize(directory: URL) -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter { $0.lastPathComponent.hasPrefix("segment-") }.reduce(0) { result, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return result + Int64(values?.fileSize ?? 0)
        }
    }
}
