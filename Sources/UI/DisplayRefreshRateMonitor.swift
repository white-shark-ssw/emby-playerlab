import Combine
import QuartzCore
import UIKit

@MainActor
final class DisplayRefreshRateMonitor: NSObject, ObservableObject {
    @Published private(set) var framesPerSecond: Double

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var samples: [Double] = []

    override init() {
        let maximum = max(60, UIScreen.main.maximumFramesPerSecond)
        framesPerSecond = Double(maximum)
        super.init()
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        link.add(to: .main, forMode: .common)
        displayLink = link
        DiagnosticsLogger.shared.playback("DisplayTiming", "monitor start maximum=\(UIScreen.main.maximumFramesPerSecond)")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
        samples.removeAll(keepingCapacity: false)
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let lastTimestamp else { return }
        let delta = link.timestamp - lastTimestamp
        guard delta > 0, delta < 0.1 else { return }
        let fps = 1 / delta
        samples.append(fps)
        if samples.count > 30 { samples.removeFirst(samples.count - 30) }
        guard samples.count >= 12 else { return }
        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        let clamped = min(Double(max(60, UIScreen.main.maximumFramesPerSecond)), max(30, median))
        if abs(clamped - framesPerSecond) >= 1 {
            framesPerSecond = clamped
            DiagnosticsLogger.shared.playback("DisplayTiming", "measured=\(String(format: "%.2f", clamped)) maximum=\(UIScreen.main.maximumFramesPerSecond)")
        }
    }
}
