import Foundation

enum AVIOBenchmarkMode: String, CaseIterable, Codable, Identifiable {
    case sharedSingleOpen
    case sharedSingleFinite
    case sharedDualFinite
    case isolatedDualFinite
    case sharedSingleDisk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sharedSingleOpen: return "共享会话 · 单长连接"
        case .sharedSingleFinite: return "共享会话 · 单有限 Range"
        case .sharedDualFinite: return "共享会话 · 双连续 Range"
        case .isolatedDualFinite: return "独立会话 · 双连续 Range"
        case .sharedSingleDisk: return "共享会话 · 边下边写磁盘"
        }
    }

    var detail: String {
        switch self {
        case .sharedSingleOpen:
            return "发送 bytes=0-，持续读取到测试时间结束，用于寻找单持久连接上限。"
        case .sharedSingleFinite:
            return "单个共享 URLSession 下载固定字节范围，排除开放 Range 差异。"
        case .sharedDualFinite:
            return "同一 URLSession 同时下载两个相邻区间，验证连接池是否能够叠加吞吐。"
        case .isolatedDualFinite:
            return "两个独立 URLSession 分别下载相邻区间，与共享连接池进行对照。"
        case .sharedSingleDisk:
            return "单连接接收数据并持续写入临时文件，测量真实缓存写入成本。"
        }
    }
}

enum AVIORequestProfile: String, CaseIterable, Codable, Identifiable {
    case capturedRedirect
    case minimal115

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capturedRedirect: return "沿用 302 请求头"
        case .minimal115: return "115 最小请求头"
        }
    }

    var detail: String {
        switch self {
        case .capturedRedirect: return "使用 302 跳转后捕获的安全请求头和 Cookie。"
        case .minimal115: return "仅保留 Range、identity 编码和 115 Cookie，用于排除自定义请求头影响。"
        }
    }
}

struct AVIOBenchmarkConfiguration: Equatable {
    let mode: AVIOBenchmarkMode
    let requestProfile: AVIORequestProfile
    let durationSeconds: Int
    let targetBytes: Int64
}

struct AVIOBenchmarkLaneResult: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let requestedRange: String
    let bytesReceived: Int64
    let elapsedSeconds: Double
    let firstByteMilliseconds: Double?
    let statusCode: Int?
    let redirectCount: Int
    let networkProtocol: String?
    let reusedConnection: Bool?
    let connectMilliseconds: Double?
    let completed: Bool
    let error: String?

    var averageBytesPerSecond: Double {
        elapsedSeconds > 0 ? Double(bytesReceived) / elapsedSeconds : 0
    }
}

struct AVIOBenchmarkSample: Codable, Equatable, Identifiable {
    let id: UUID
    let elapsedSeconds: Double
    let totalBytes: Int64
    let currentBytesPerSecond: Double
}

struct AVIOBenchmarkResult: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let mode: AVIOBenchmarkMode
    let requestProfile: AVIORequestProfile
    let configuredDurationSeconds: Int
    let configuredTargetBytes: Int64
    let actualDurationSeconds: Double
    let contentLength: Int64
    let looksLike115CDN: Bool
    let totalBytesReceived: Int64
    let averageBytesPerSecond: Double
    let firstByteMilliseconds: Double?
    let httpStatusCodes: [Int]
    let redirectCount: Int
    let lanes: [AVIOBenchmarkLaneResult]
    let samples: [AVIOBenchmarkSample]
    let error: String?

    var title: String { mode.title }

    var summary: String {
        let speed = ByteCountFormatter.string(fromByteCount: Int64(averageBytesPerSecond), countStyle: .file)
        let bytes = ByteCountFormatter.string(fromByteCount: totalBytesReceived, countStyle: .file)
        let firstByte = firstByteMilliseconds.map { "首字节 \(Int($0)) ms" } ?? "无首字节"
        return "平均 \(speed)/s · \(bytes) · \(firstByte) · HTTP \(httpStatusCodes.map(String.init).joined(separator: ","))"
    }
}

struct AVIOBenchmarkProgress: Equatable {
    let mode: AVIOBenchmarkMode
    let elapsedSeconds: Double
    let totalBytes: Int64
    let currentBytesPerSecond: Double
    let activeLaneCount: Int

    var summary: String {
        let speed = ByteCountFormatter.string(fromByteCount: Int64(currentBytesPerSecond), countStyle: .file)
        let bytes = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(mode.title) · \(speed)/s · \(bytes) · 活动通道 \(activeLaneCount)"
    }
}

struct AVIOProbeOperation: Codable, Equatable, Identifiable {
    let id: UUID
    let operation: String
    let requestedOffset: Int64
    let resultingOffset: Int64
    let bytesRead: Int
    let elapsedMilliseconds: Double
    let error: String?
}

struct AVIOProbeReport: Codable, Equatable {
    let createdAt: Date
    let contentLength: Int64
    let operations: [AVIOProbeOperation]
}

struct AVIOBenchmarkExport: Codable {
    let generatedAt: Date
    let appVersion: String
    let sourceVersion: String
    let deploymentTarget: String
    let results: [AVIOBenchmarkResult]
    let probe: AVIOProbeReport?
}
