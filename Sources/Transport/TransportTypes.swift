import Foundation

struct TransportResolvedResource: Equatable {
    let originalURL: URL
    let finalURL: URL
    let requestHeaders: [String: String]
    let contentLength: Int64
    let contentType: String?
    let supportsByteRanges: Bool
    let etag: String?
    let lastModified: String?
    let redirectCount: Int
    let looksLike115CDN: Bool
}

struct TransportMetricsSnapshot: Equatable {
    var bytesDownloaded: Int64 = 0
    var bytesServed: Int64 = 0
    var cacheHitBytes: Int64 = 0
    var networkRequestCount: Int = 0
    var rangeFailureCount: Int = 0
    var activeRequestCount: Int = 0
    var cacheBytes: Int64 = 0
    var memoryCacheBytes: Int64 = 0
    var diskCacheBytes: Int64 = 0
    var contiguousCacheBytes: Int64 = 0
    var currentDownloadBytesPerSecond: Double = 0
    var elapsedSeconds: Double = 0

    var averageDownloadBytesPerSecond: Double {
        elapsedSeconds > 0 ? Double(bytesDownloaded) / elapsedSeconds : 0
    }

    var cacheHitRatio: Double {
        guard bytesServed > 0 else { return 0 }
        return min(1, Double(cacheHitBytes) / Double(bytesServed))
    }

    var summary: String {
        let currentSpeed = ByteCountFormatter.string(fromByteCount: Int64(currentDownloadBytesPerSecond), countStyle: .file)
        let averageSpeed = ByteCountFormatter.string(fromByteCount: Int64(averageDownloadBytesPerSecond), countStyle: .file)
        let cached = ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)
        let contiguous = ByteCountFormatter.string(fromByteCount: contiguousCacheBytes, countStyle: .file)
        let contiguousText = contiguousCacheBytes > 0 ? " · 连续 \(contiguous)" : ""
        return "115上游 \(currentSpeed)/s · 平均 \(averageSpeed)/s · 总缓存 \(cached)\(contiguousText) · 命中 \(Int(cacheHitRatio * 100))% · 并发 \(activeRequestCount)"
    }
}

enum MediaTransportError: LocalizedError {
    case invalidResponse
    case rangeUnsupported(statusCode: Int)
    case invalidContentRange
    case unavailableContentLength
    case expiredURL(statusCode: Int)
    case shortRead(expected: Int, actual: Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "传输层收到无效 HTTP 响应。"
        case .rangeUnsupported(let statusCode):
            return "上游未返回 HTTP 206，状态码为 \(statusCode)。"
        case .invalidContentRange:
            return "上游返回的 Content-Range 无法解析。"
        case .unavailableContentLength:
            return "无法确定远程媒体文件大小。"
        case .expiredURL(let statusCode):
            return "115 临时直链可能已过期，状态码为 \(statusCode)。"
        case .shortRead(let expected, let actual):
            return "Range 数据不完整，预期 \(expected) 字节，实际 \(actual) 字节。"
        case .cancelled:
            return "传输任务已取消。"
        }
    }
}
