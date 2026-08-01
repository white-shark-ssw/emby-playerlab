import Foundation

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let queue = DispatchQueue(label: "com.embyplayerlab.diagnostics")
    private var entries: [String] = []
    private let formatter: ISO8601DateFormatter
    private let persistentURL: URL
    private let maximumPersistentBytes: UInt64 = 8 * 1024 * 1024

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmbyPlayerLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistentURL = directory.appendingPathComponent("current-session.log")

        if !FileManager.default.fileExists(atPath: persistentURL.path) {
            FileManager.default.createFile(atPath: persistentURL.path, contents: nil)
        }

        log("Lifecycle", "logger initialized app=\(AppIdentity.version)")
    }

    func log(_ category: String, _ message: String) {
        queue.async {
            let line = "\(self.formatter.string(from: Date())) [\(category)] \(SensitiveRedactor.redact(message))"
            self.entries.append(line)
            if self.entries.count > 10_000 {
                self.entries.removeFirst(self.entries.count - 10_000)
            }
            self.appendPersisted(line + "\n")
            #if DEBUG
            print(line)
            #endif
        }
    }

    func export() throws -> URL {
        try queue.sync {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let name = "EmbyPlayerLab-\(Int(Date().timeIntervalSince1970)).log"
            let destination = directory.appendingPathComponent(name)

            if FileManager.default.fileExists(atPath: persistentURL.path) {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: persistentURL, to: destination)
            } else {
                let content = entries.joined(separator: "\n") + "\n"
                try content.write(to: destination, atomically: true, encoding: .utf8)
            }
            return destination
        }
    }

    private func appendPersisted(_ text: String) {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: persistentURL.path),
           let size = attributes[.size] as? NSNumber,
           size.uint64Value > maximumPersistentBytes {
            try? Data().write(to: persistentURL, options: .atomic)
        }

        guard let data = text.data(using: .utf8) else { return }
        do {
            let handle = try FileHandle(forWritingTo: persistentURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            // Logging must never crash playback.
        }
    }
}
