import Foundation

enum DiagnosticsLogChannel: String, CaseIterable, Identifiable {
    case app
    case playback

    var id: String { rawValue }
    var title: String { self == .app ? "App 日志" : "播放日志" }
    var enabledKey: String { self == .app ? "OnePlayer.Log.App.Enabled" : "OnePlayer.Log.Playback.Enabled" }
    var fileName: String { self == .app ? "app.log" : "playback.log" }
    var exportPrefix: String { self == .app ? "OnePlayer-App" : "OnePlayer-Playback" }
}

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private final class ChannelStore {
        let channel: DiagnosticsLogChannel
        let persistentURL: URL
        var persistentHandle: FileHandle?
        var pendingPersistentData = Data()
        var flushWorkItem: DispatchWorkItem?

        init(channel: DiagnosticsLogChannel, directory: URL) {
            self.channel = channel
            persistentURL = directory.appendingPathComponent(channel.fileName)
            if !FileManager.default.fileExists(atPath: persistentURL.path) { FileManager.default.createFile(atPath: persistentURL.path, contents: nil) }
            persistentHandle = try? FileHandle(forWritingTo: persistentURL)
            try? persistentHandle?.seekToEnd()
        }
    }

    private let queue = DispatchQueue(label: "com.oneplayer.diagnostics", qos: .utility)
    private let formatter: ISO8601DateFormatter
    private let maximumPersistentBytes: UInt64 = 8 * 1024 * 1024
    private let flushThresholdBytes = 64 * 1024
    private let flushDelay: TimeInterval = 0.35
    private var stores: [DiagnosticsLogChannel: ChannelStore] = [:]

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OnePlayer/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for channel in DiagnosticsLogChannel.allCases { stores[channel] = ChannelStore(channel: channel, directory: directory) }
        app("Lifecycle", "logger initialized bundle=\(AppIdentity.version) source=\(AppIdentity.sourceVersion)")
        if let breadcrumb = EngineTransitionBreadcrumb.previousDescription() { playback("CrashBreadcrumb", "previous uncleared engine transition \(breadcrumb)") }
    }

    func log(_ category: String, _ message: String) {
        write(channel: playbackCategory(category, message: message) ? .playback : .app, category: category, message: message)
    }

    func app(_ category: String, _ message: String) { write(channel: .app, category: category, message: message) }
    func playback(_ category: String, _ message: String) { write(channel: .playback, category: category, message: message) }

    func export() throws -> URL { try export(.playback) }

    func export(_ channel: DiagnosticsLogChannel) throws -> URL {
        try queue.sync {
            guard let store = stores[channel] else { throw CocoaError(.fileNoSuchFile) }
            flushWorkItem(store)
            try? store.persistentHandle?.synchronize()
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = directory.appendingPathComponent("\(channel.exportPrefix)-\(Int(Date().timeIntervalSince1970)).log")
            try? FileManager.default.removeItem(at: destination)
            if FileManager.default.fileExists(atPath: store.persistentURL.path) { try FileManager.default.copyItem(at: store.persistentURL, to: destination) }
            else { try Data().write(to: destination) }
            return destination
        }
    }

    func clear(_ channel: DiagnosticsLogChannel) {
        queue.async {
            guard let store = self.stores[channel] else { return }
            store.flushWorkItem?.cancel()
            store.flushWorkItem = nil
            store.pendingPersistentData.removeAll(keepingCapacity: true)
            try? store.persistentHandle?.close()
            store.persistentHandle = nil
            try? Data().write(to: store.persistentURL, options: .atomic)
            store.persistentHandle = try? FileHandle(forWritingTo: store.persistentURL)
            try? store.persistentHandle?.seekToEnd()
        }
    }

    func fileSize(_ channel: DiagnosticsLogChannel) -> UInt64 {
        queue.sync {
            guard let path = stores[channel]?.persistentURL.path,
                  let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attributes[.size] as? NSNumber else { return 0 }
            return size.uint64Value
        }
    }

    private func write(channel: DiagnosticsLogChannel, category: String, message: String) {
        guard UserDefaults.standard.bool(forKey: channel.enabledKey) else {
            #if DEBUG
            print("[\(channel.rawValue)] [\(category)] \(SensitiveRedactor.redact(message))")
            #endif
            return
        }
        queue.async {
            guard let store = self.stores[channel] else { return }
            let line = "\(self.formatter.string(from: Date())) [\(category)] \(SensitiveRedactor.redact(message))"
            if let data = (line + "\n").data(using: .utf8) { store.pendingPersistentData.append(data) }
            if store.pendingPersistentData.count >= self.flushThresholdBytes { self.flush(store) }
            else { self.scheduleFlush(store) }
            #if DEBUG
            print(line)
            #endif
        }
    }

    private func scheduleFlush(_ store: ChannelStore) {
        guard store.flushWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self, weak store] in
            guard let self, let store else { return }
            store.flushWorkItem = nil
            self.flush(store)
        }
        store.flushWorkItem = workItem
        queue.asyncAfter(deadline: .now() + flushDelay, execute: workItem)
    }

    private func flushWorkItem(_ store: ChannelStore) {
        store.flushWorkItem?.cancel()
        store.flushWorkItem = nil
        flush(store)
    }

    private func flush(_ store: ChannelStore) {
        guard !store.pendingPersistentData.isEmpty else { return }
        rotateIfNeeded(store, additionalBytes: UInt64(store.pendingPersistentData.count))
        if store.persistentHandle == nil {
            store.persistentHandle = try? FileHandle(forWritingTo: store.persistentURL)
            try? store.persistentHandle?.seekToEnd()
        }
        let data = store.pendingPersistentData
        store.pendingPersistentData.removeAll(keepingCapacity: true)
        do { try store.persistentHandle?.write(contentsOf: data) }
        catch {
            try? store.persistentHandle?.close()
            store.persistentHandle = nil
        }
    }

    private func rotateIfNeeded(_ store: ChannelStore, additionalBytes: UInt64) {
        let currentBytes: UInt64
        if let attributes = try? FileManager.default.attributesOfItem(atPath: store.persistentURL.path), let size = attributes[.size] as? NSNumber { currentBytes = size.uint64Value }
        else { currentBytes = 0 }
        guard currentBytes + additionalBytes > maximumPersistentBytes else { return }
        try? store.persistentHandle?.close()
        store.persistentHandle = nil
        try? Data().write(to: store.persistentURL, options: .atomic)
        store.persistentHandle = try? FileHandle(forWritingTo: store.persistentURL)
        try? store.persistentHandle?.seekToEnd()
    }

    private func playbackCategory(_ category: String, message: String) -> Bool {
        let normalized = category.lowercased()
        let playbackTokens = ["player", "playback", "seek", "buffer", "engine", "mpv", "avplayer", "avio", "transport", "range", "eof", "stall", "decoder", "video", "audio", "resource", "cachelane", "upstream"]
        if playbackTokens.contains(where: { normalized.contains($0) }) { return true }
        return normalized == "lifecycle" && message.lowercased().contains("player")
    }
}
