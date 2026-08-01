import Foundation
import Network

final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.embyplayerlab.transport.path")
    private let lock = NSLock()
    private var cellular = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.cellular = path.usesInterfaceType(.cellular)
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    var isCellular: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cellular
    }
}
