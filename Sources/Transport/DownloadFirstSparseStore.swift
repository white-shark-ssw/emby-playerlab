import CryptoKit
import Darwin
import Foundation

final class DownloadFirstSparseStore: @unchecked Sendable {
    enum StoreError: LocalizedError {
        case openFailed(Int32)
        case closed
        case readFailed(Int32)
        case writeFailed(Int32)
        case timeout(offset: Int64)

        var errorDescription: String? {
            switch self {
            case .openFailed(let code): return "下载优先缓存文件打开失败：errno=\(code)"
            case .closed: return "下载优先缓存已经关闭。"
            case .readFailed(let code): return "下载优先缓存读取失败：errno=\(code)"
            case .writeFailed(let code): return "下载优先缓存写入失败：errno=\(code)"
            case .timeout(let offset): return "等待下载数据超时，offset=\(offset)。"
            }
        }
    }

    private struct Metadata: Codable, Equatable {
        let contentLength: Int64
        let etag: String?
        let lastModified: String?
    }

    private let condition = NSCondition()
    private let directory: URL
    private let mediaURL: URL
    private let rangesURL: URL
    private let metadataURL: URL
    private let keepFiles: Bool
    private let contentLength: Int64
    private var fileDescriptor: Int32 = -1
    private var rangeSet: SparseByteRangeSet
    private var closed = false
    private var lastPersistedBytes: Int64 = 0

    init(cacheKey: String, contentLength: Int64, etag: String?, lastModified: String?, keepFiles: Bool) throws {
        self.contentLength = contentLength
        self.keepFiles = keepFiles
        self.rangeSet = SparseByteRangeSet()

        let digest = SHA256.hash(data: Data(cacheKey.utf8)).map { String(format: "%02x", $0) }.joined()
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmbyPlayerLabDownloadFirst", isDirectory: true)
        directory = root.appendingPathComponent(digest, isDirectory: true)
        mediaURL = directory.appendingPathComponent("media.sparse")
        rangesURL = directory.appendingPathComponent("ranges.json")
        metadataURL = directory.appendingPathComponent("metadata.json")

        let expectedMetadata = Metadata(contentLength: contentLength, etag: etag, lastModified: lastModified)
        let existingMetadata: Metadata? = {
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? JSONDecoder().decode(Metadata.self, from: data)
        }()

        if !keepFiles || existingMetadata != expectedMetadata {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if keepFiles,
           existingMetadata == expectedMetadata,
           let data = try? Data(contentsOf: rangesURL),
           let stored = try? JSONDecoder().decode([SparseStoredRange].self, from: data) {
            rangeSet = SparseByteRangeSet(ranges: stored.map(\.range))
        } else {
            rangeSet = SparseByteRangeSet()
        }

        if let data = try? JSONEncoder().encode(expectedMetadata) {
            try? data.write(to: metadataURL, options: .atomic)
        }

        fileDescriptor = Darwin.open(mediaURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else { throw StoreError.openFailed(errno) }
        guard ftruncate(fileDescriptor, off_t(contentLength)) == 0 else {
            let code = errno
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw StoreError.openFailed(code)
        }
        lastPersistedBytes = rangeSet.totalBytes
    }

    deinit {
        close(removeFiles: !keepFiles)
    }

    func write(_ data: Data, at offset: Int64) throws {
        guard !data.isEmpty else { return }
        let end = min(contentLength, offset + Int64(data.count))
        guard offset >= 0, end > offset else { return }
        let writableCount = Int(end - offset)

        condition.lock()
        let fd = fileDescriptor
        let isClosed = closed
        condition.unlock()
        guard !isClosed, fd >= 0 else { throw StoreError.closed }

        let written = try data.withUnsafeBytes { rawBuffer -> Int in
            guard let base = rawBuffer.baseAddress else { return 0 }
            var total = 0
            while total < writableCount {
                let result = pwrite(fd, base.advanced(by: total), writableCount - total, off_t(offset) + off_t(total))
                if result < 0 { throw StoreError.writeFailed(errno) }
                if result == 0 { break }
                total += result
            }
            return total
        }
        guard written == writableCount else { throw StoreError.writeFailed(EIO) }

        condition.lock()
        rangeSet.insert(offset..<end)
        persistRangesIfNeededLocked(force: false)
        condition.broadcast()
        condition.unlock()
    }

    func readWhenAvailable(offset: Int64, maximumLength: Int, timeout: TimeInterval = 30) async throws -> Data {
        guard maximumLength > 0, offset < contentLength else { return Data() }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: StoreError.closed)
                    return
                }
                do {
                    continuation.resume(returning: try self.blockingRead(offset: offset, maximumLength: maximumLength, timeout: timeout))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func availableLength(from offset: Int64, maximumLength: Int64) -> Int64 {
        condition.lock()
        defer { condition.unlock() }
        return rangeSet.contiguousLength(from: offset, maximumLength: maximumLength)
    }

    func contains(_ range: Range<Int64>) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        return rangeSet.contains(range)
    }

    func firstMissingOffset(from offset: Int64, upperBound: Int64) -> Int64? {
        condition.lock()
        defer { condition.unlock() }
        return rangeSet.firstMissingOffset(from: offset, upperBound: upperBound)
    }

    var uniqueBytes: Int64 {
        condition.lock()
        defer { condition.unlock() }
        return rangeSet.totalBytes
    }

    var cachedRanges: [Range<Int64>] {
        condition.lock()
        defer { condition.unlock() }
        return rangeSet.ranges
    }

    @discardableResult
    func evictCachedBytes(before upperBound: Int64, targetBytes: Int64, protectedPrefixBytes: Int64 = 8 * 1_048_576) -> [Range<Int64>] {
        let safeUpper = min(contentLength, max(protectedPrefixBytes, upperBound))
        let target = max(0, targetBytes)

        condition.lock()
        defer { condition.unlock() }
        guard !closed, fileDescriptor >= 0, rangeSet.totalBytes > target, safeUpper > protectedPrefixBytes else { return [] }

        var remainingToFree = rangeSet.totalBytes - target
        var evicted: [Range<Int64>] = []
        let page = Int64(max(4096, getpagesize()))

        for cached in rangeSet.ranges where remainingToFree > 0 {
            let candidateLower = max(cached.lowerBound, protectedPrefixBytes)
            let candidateUpper = min(cached.upperBound, safeUpper)
            guard candidateUpper > candidateLower else { continue }

            let alignedLower = ((candidateLower + page - 1) / page) * page
            let maximumUpper = min(candidateUpper, alignedLower + remainingToFree)
            let alignedUpper = (maximumUpper / page) * page
            guard alignedUpper > alignedLower else { continue }

            var hole = fpunchhole_t(fp_flags: 0, reserved: 0, fp_offset: off_t(alignedLower), fp_length: off_t(alignedUpper - alignedLower))
            guard fcntl(fileDescriptor, F_PUNCHHOLE, &hole) == 0 else {
                DiagnosticsLogger.shared.playback("RollingCache", "punch-hole failed range=\(alignedLower)-\(alignedUpper) errno=\(errno)")
                continue
            }

            let removal = alignedLower..<alignedUpper
            rangeSet.remove(removal)
            evicted.append(removal)
            remainingToFree = max(0, remainingToFree - Int64(removal.count))
        }

        if !evicted.isEmpty {
            persistRangesIfNeededLocked(force: true)
            condition.broadcast()
        }
        return evicted
    }

    func close(removeFiles: Bool) {
        condition.lock()
        guard !closed else {
            condition.unlock()
            return
        }
        closed = true
        persistRangesIfNeededLocked(force: true)
        let fd = fileDescriptor
        fileDescriptor = -1
        condition.broadcast()
        condition.unlock()

        if fd >= 0 { Darwin.close(fd) }
        if removeFiles { try? FileManager.default.removeItem(at: directory) }
    }

    private func blockingRead(offset: Int64, maximumLength: Int, timeout: TimeInterval) throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        var readableLength: Int64 = 0
        var fd: Int32 = -1

        condition.lock()
        defer { condition.unlock() }
        while !closed {
            readableLength = rangeSet.contiguousLength(from: offset, maximumLength: Int64(maximumLength))
            if readableLength > 0 {
                fd = fileDescriptor
                break
            }
            if !condition.wait(until: deadline) { break }
        }

        if closed || fd < 0 { throw StoreError.closed }
        guard readableLength > 0 else { throw StoreError.timeout(offset: offset) }

        // Keep the condition locked through the physical pread. Rolling eviction uses the same lock,
        // so bytes cannot be punched out after the range was declared readable but before it is read.
        var data = Data(count: Int(readableLength))
        let readCount = try data.withUnsafeMutableBytes { rawBuffer -> Int in
            guard let base = rawBuffer.baseAddress else { return 0 }
            var total = 0
            while total < Int(readableLength) {
                let result = pread(fd, base.advanced(by: total), Int(readableLength) - total, off_t(offset) + off_t(total))
                if result < 0 { throw StoreError.readFailed(errno) }
                if result == 0 { break }
                total += result
            }
            return total
        }
        if readCount < data.count { data.removeSubrange(readCount..<data.count) }
        return data
    }

    private func persistRangesIfNeededLocked(force: Bool) {
        guard keepFiles else { return }
        let bytes = rangeSet.totalBytes
        guard force || abs(bytes - lastPersistedBytes) >= 8 * 1_048_576 else { return }
        if let data = try? JSONEncoder().encode(rangeSet.storedRanges) {
            try? data.write(to: rangesURL, options: .atomic)
            lastPersistedBytes = bytes
        }
    }
}
