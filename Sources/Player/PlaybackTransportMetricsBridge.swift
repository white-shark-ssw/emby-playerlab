import Foundation

extension PlayerController {
    func currentDownloadBytesPerSecond() async -> Double {
        let currentEngine = engine
        guard let metrics = await currentEngine.transportMetrics(), engine === currentEngine else { return 0 }
        return max(0, metrics.currentDownloadBytesPerSecond)
    }
}
