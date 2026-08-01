import Foundation

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let queue = DispatchQueue(label: "com.embyplayerlab.diagnostics")
    private var entries: [String] = []
    private let formatter: ISO8601DateFormatter

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func log(_ category: String, _ message: String) {
        queue.async {
            let line = "\(self.formatter.string(from: Date())) [\(category)] \(SensitiveRedactor.redact(message))"
            self.entries.append(line)
            if self.entries.count > 10_000 {
                self.entries.removeFirst(self.entries.count - 10_000)
            }
            #if DEBUG
            print(line)
            #endif
        }
    }

    func export() throws -> URL {
        let content = queue.sync { entries.joined(separator: "\n") + "\n" }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let name = "EmbyPlayerLab-\(Int(Date().timeIntervalSince1970)).log"
        let url = directory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
