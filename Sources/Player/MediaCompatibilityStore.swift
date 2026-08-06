import Foundation

enum MediaCompatibilityStore {
    private static let key = "player.compatibility.ffmpeg-item-ids"
    private static let lock = NSLock()

    static func requiresFFmpeg(itemId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedItemIds().contains(itemId)
    }

    static func markFFmpegRequired(itemId: String, reason: String) {
        lock.lock()
        var ids = storedItemIds()
        let inserted = ids.insert(itemId).inserted
        if inserted { UserDefaults.standard.set(Array(ids).sorted(), forKey: key) }
        lock.unlock()
        if inserted { DiagnosticsLogger.shared.log("Compatibility", "item=\(itemId) marked=KSPlayer-FFmpeg reason=\(reason)") }
    }

    static func clear(itemId: String) {
        lock.lock()
        var ids = storedItemIds()
        let removed = ids.remove(itemId) != nil
        if removed { UserDefaults.standard.set(Array(ids).sorted(), forKey: key) }
        lock.unlock()
    }

    private static func storedItemIds() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
}
