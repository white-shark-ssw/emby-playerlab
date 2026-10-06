import UIKit
import Foundation

/// One task per URL, with independent visible/prefetch/first-screen consumers and a bounded scheduler.
@MainActor
final class EmbyImagePreparation {
    static let shared = EmbyImagePreparation()
    enum Priority: Int { case prefetch = 0, firstScreen = 1, visible = 2 }
    private final class Entry {
        let generation = UUID()
        var consumers: [UUID: (Priority, (UIImage?) -> Void)] = [:]
        var task: Task<Void, Never>?
        var image: UIImage?
        var completed = false
    }
    private var entries: [URL: Entry] = [:]
    private var running = Set<UUID>()
    private var tokens: [UUID: URL] = [:]
    private var pinOwners: [(UUID, [URL])] = []
    private var pins: [UUID: [URL: UUID]] = [:]
    private let operation: (URL) async -> UIImage?
    let concurrencyLimit: Int
    static let firstScreenLimit = 24
    private var observers: [NSObjectProtocol] = []

    init(concurrencyLimit: Int = 4, operation: @escaping (URL) async -> UIImage? = EmbyImagePreparation.prepare) {
        self.concurrencyLimit = concurrencyLimit
        self.operation = operation
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.releaseFirstScreens() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: EmbyDecodedImageRenderPool.didClear, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.invalidatePreparedImages() }
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func readyImage(for url: URL) -> UIImage? { entries[url]?.image ?? EmbyDecodedImageRenderPool.shared.image(for: url) }
    var activeTaskCount: Int { running.count }
    var demandCount: Int { entries.count }
    var firstScreenCount: Int { Set(pins.values.flatMap { $0.keys }).count }

    @discardableResult
    func subscribe(_ url: URL, priority: Priority, completion: @escaping (UIImage?) -> Void) -> UUID {
        let token = UUID()
        let entry = entries[url] ?? Entry()
        if entries[url] == nil {
            entry.image = EmbyDecodedImageRenderPool.shared.image(for: url)
            entry.completed = entry.image != nil
            entries[url] = entry
        }
        entry.consumers[token] = (priority, completion)
        tokens[token] = url
        if entry.completed { completion(entry.image) }
        pump()
        return token
    }

    func cancel(_ token: UUID) {
        guard let url = tokens.removeValue(forKey: token), let entry = entries[url] else { return }
        entry.consumers.removeValue(forKey: token)
        if entry.consumers.isEmpty { entry.task?.cancel(); entries.removeValue(forKey: url) }
        pump()
    }

    /// Strong ready references are demand-owned, globally capped and share the decoded UIImage object.
    func setFirstScreen(owner: UUID, urls: [URL]) {
        if let index = pinOwners.firstIndex(where: { $0.0 == owner }), pinOwners[index].1 == urls { return }
        pinOwners.removeAll { $0.0 == owner }
        if !urls.isEmpty { pinOwners.insert((owner, Array(urls.prefix(Self.firstScreenLimit))), at: 0) }
        if pinOwners.count > 2 { pinOwners.removeLast(pinOwners.count - 2) }
        var admitted = Set<URL>()
        var allowed: [UUID: Set<URL>] = [:]
        for (id, requests) in pinOwners {
            for url in requests where admitted.contains(url) || admitted.count < Self.firstScreenLimit {
                admitted.insert(url)
                allowed[id, default: []].insert(url)
            }
        }
        for (id, ownerPins) in pins {
            for (url, token) in ownerPins where !(allowed[id] ?? []).contains(url) { cancel(token); pins[id]?.removeValue(forKey: url) }
        }
        for (id, requests) in allowed {
            for url in requests where pins[id]?[url] == nil {
                pins[id, default: [:]][url] = subscribe(url, priority: .firstScreen) { _ in }
            }
        }
        pins = pins.filter { !$0.value.isEmpty }
    }

    private func releaseFirstScreens() {
        let all = pins.values.flatMap { $0.values }
        pins.removeAll(); pinOwners.removeAll()
        all.forEach(cancel)
    }

    private func invalidatePreparedImages() {
        for entry in entries.values { entry.image = nil; entry.completed = false }
        pump()
    }

    private func pump() {
        var available = concurrencyLimit - activeTaskCount
        let pending = entries.filter { !$0.value.completed && $0.value.task == nil }
            .sorted { priority($0.value) > priority($1.value) }
        for (url, entry) in pending where available > 0 {
            available -= 1
            let generation = entry.generation
            let operation = operation
            running.insert(generation)
            entry.task = Task { [weak self] in
                let image = Task.isCancelled ? nil : await operation(url)
                self?.finish(url, generation: generation, image: image, cancelled: Task.isCancelled)
            }
        }
    }

    private func priority(_ entry: Entry) -> Int { entry.consumers.values.map { $0.0.rawValue }.max() ?? 0 }

    private func finish(_ url: URL, generation: UUID, image: UIImage?, cancelled: Bool) {
        running.remove(generation)
        guard !cancelled, let entry = entries[url], entry.generation == generation else { pump(); return }
        entry.task = nil; entry.completed = true; entry.image = image
        if let image { EmbyDecodedImageRenderPool.shared.store(image, for: url) }
        let callbacks = Array(entry.consumers.values)
        callbacks.forEach { $0.1(image) }
        pump()
    }

    nonisolated static func prepare(_ url: URL) async -> UIImage? {
        if let data = await EmbyImageDiskCache.shared.data(for: url) {
            let image = await Task.detached(priority: .userInitiated) { EmbyImageDecoder.decode(data: data, url: url) }.value
            guard !Task.isCancelled else { return nil }
            if let image { return image }
            await EmbyImageDiskCache.shared.remove(url)
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return nil }
            await EmbyImageDiskCache.shared.store(data, for: url)
            let image = await Task.detached(priority: .userInitiated) { EmbyImageDecoder.decode(data: data, url: url) }.value
            return Task.isCancelled ? nil : image
        } catch { return nil }
    }
}
