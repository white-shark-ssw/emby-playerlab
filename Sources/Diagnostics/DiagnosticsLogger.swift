import Foundation

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let queue = DispatchQueue(label: "com.embyplayerlab.diagnostics", qos: .utility)
    private var entries: [String] = []
    private let formatter: ISO8601DateFormatter
    private let persistentURL: URL
    private let maximumPersistentBytes: UInt64 = 8 * 1024 * 1024
    private let flushThresholdBytes = 64 * 1024
    private let flushDelay: TimeInterval = 0.35

    private var persistentHandle: FileHandle?
    private var pendingPersistentData = Data()
    private var flushWorkItem: DispatchWorkItem?

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
        persistentHandle = try? FileHandle(forWritingTo: persistentURL)
        try? persistentHandle?.seekToEnd()

        log("Lifecycle", "logger initialized bundle=\(AppIdentity.version) source=\(AppIdentity.sourceVersion)")
        if let breadcrumb = EngineTransitionBreadcrumb.previousDescription() {
            log("CrashBreadcrumb", "previous uncleared engine transition \(breadcrumb)")
        }
    }

    func log(_ category: String, _ message: String) {
        queue.async {
            let line = "\(self.formatter.string(from: Date())) [\(category)] \(SensitiveRedactor.redact(message))"
            self.entries.append(line)
            if self.entries.count > 10_000 {
                self.entries.removeFirst(self.entries.count - 10_000)
            }

            if let data = (line + "\n").data(using: .utf8) {
                self.pendingPersistentData.append(data)
            }
            if self.pendingPersistentData.count >= self.flushThresholdBytes {
                self.flushPersisted()
            } else {
                self.scheduleFlush()
            }

            #if DEBUG
            print(line)
            #endif
        }
    }

    func export() throws -> URL {
        try queue.sync {
            flushWorkItem?.cancel()
            flushWorkItem = nil
            flushPersisted()
            try? persistentHandle?.synchronize()

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

    private func scheduleFlush() {
        guard flushWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flushWorkItem = nil
            self.flushPersisted()
        }
        flushWorkItem = workItem
        queue.asyncAfter(deadline: .now() + flushDelay, execute: workItem)
    }

    private func flushPersisted() {
        guard !pendingPersistentData.isEmpty else { return }
        rotateIfNeeded(additionalBytes: UInt64(pendingPersistentData.count))

        if persistentHandle == nil {
            persistentHandle = try? FileHandle(forWritingTo: persistentURL)
            try? persistentHandle?.seekToEnd()
        }

        let data = pendingPersistentData
        pendingPersistentData.removeAll(keepingCapacity: true)
        do {
            try persistentHandle?.write(contentsOf: data)
        } catch {
            try? persistentHandle?.close()
            persistentHandle = nil
        }
    }

    private func rotateIfNeeded(additionalBytes: UInt64) {
        let currentBytes: UInt64
        if let attributes = try? FileManager.default.attributesOfItem(atPath: persistentURL.path),
           let size = attributes[.size] as? NSNumber {
            currentBytes = size.uint64Value
        } else {
            currentBytes = 0
        }

        guard currentBytes + additionalBytes > maximumPersistentBytes else { return }
        try? persistentHandle?.close()
        persistentHandle = nil
        try? Data().write(to: persistentURL, options: .atomic)
        persistentHandle = try? FileHandle(forWritingTo: persistentURL)
        try? persistentHandle?.seekToEnd()
    }
}
