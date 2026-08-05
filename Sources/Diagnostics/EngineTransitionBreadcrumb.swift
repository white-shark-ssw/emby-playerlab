import Foundation

enum EngineTransitionBreadcrumb {
    private struct Entry: Codable {
        let timestamp: Date
        let stage: String
        let from: String
        let to: String
        let position: Double
        let reason: String
    }

    private static let lock = NSLock()
    private static let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmbyPlayerLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("engine-transition-breadcrumb.json")
    }()

    static func record(stage: String, from: PlayerEngineKind, to: PlayerEngineKind, position: Double, reason: String) {
        let entry = Entry(timestamp: Date(), stage: stage, from: from.rawValue, to: to.rawValue, position: position, reason: reason)
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func previousDescription() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL), let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        return "stage=\(entry.stage) from=\(entry.from) to=\(entry.to) position=\(entry.position) reason=\(entry.reason) timestamp=\(ISO8601DateFormatter().string(from: entry.timestamp))"
    }
}
