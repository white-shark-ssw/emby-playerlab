import Foundation
import Network

final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.embyplayerlab.transport.path")
    private let lock = NSLock()
    private var cellular = false
    private var interfaceName = "unknown"
    private var expensive = false
    private var constrained = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.cellular = path.usesInterfaceType(.cellular)
            self.interfaceName = Self.interfaceLabel(for: path)
            self.expensive = path.isExpensive
            if #available(iOS 13.0, *) { self.constrained = path.isConstrained }
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    var isCellular: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cellular
    }

    var diagnosticSummary: String {
        lock.lock()
        defer { lock.unlock() }
        return "interface=\(interfaceName) expensive=\(expensive) constrained=\(constrained)"
    }

    private static func interfaceLabel(for path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) { return "wifi" }
        if path.usesInterfaceType(.cellular) { return "cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "ethernet" }
        if path.usesInterfaceType(.loopback) { return "loopback" }
        return "other"
    }
}
