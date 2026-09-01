from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one match in {path}: {old!r}, got {count}")
    p.write_text(text.replace(old, new, 1))


replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.15.15"', 'static let sourceVersion = "0.15.17"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.15.15"', '?? "0.15.17"')
replace_once("Sources/UI/EmbyHomeFramePipelineProbeV3.swift", 'case .carouselTree: return "TREE FULL"', 'case .carouselTree: return "CROSSOVER"')
replace_once("Sources/UI/EmbyHomeFramePipelineProbeV3.swift", 'case .carouselTree: return "Full tree ← 120 Hz progress"', 'case .carouselTree: return "same Home tree: REF ↔ TREE ×3"')

probe = Path("Sources/UI/EmbyHomeFramePipelineProbeV3.swift")
text = probe.read_text()
start = text.index("final class V3HomeCarouselTreeProgressView: UIView {")
end = text.index("\nprivate struct V3HomeInputPipelineProbe", start)
replacement = r'''final class V3HomeCarouselTreeProgressView: UIView {
    var onProgress: ((CGFloat) -> Void)?
    private let phaseDuration: CFTimeInterval = 15
    private let markerLayer = CALayer()
    private let phaseLayer = CATextLayer()
    private var displayLink: CADisplayLink?
    private var startedAt: CFTimeInterval?
    private var lastPhaseIndex = -1
    private var lastTimestamp: CFTimeInterval?
    private var intervalCount = 0
    private var totalGapMS: Double = 0
    private var maxGapMS: Double = 0

    deinit { stop() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() }
        else { start() }
    }

    private func start() {
        guard displayLink == nil else { return }
        startedAt = nil
        lastPhaseIndex = -1
        resetCadence()
        installReferenceLayers()
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        link.add(to: .main, forMode: .common)
        displayLink = link
        DiagnosticsLogger.shared.playback("HomeCarouselCrossover", "start maxFPS=\(UIScreen.main.maximumFramesPerSecond) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) thermal=\(thermalStateName)")
    }

    private func stop() {
        logPhaseSummary(reason: "stop")
        displayLink?.invalidate()
        displayLink = nil
        markerLayer.removeFromSuperlayer()
        phaseLayer.removeFromSuperlayer()
        startedAt = nil
        lastPhaseIndex = -1
        resetCadence()
    }

    private func installReferenceLayers() {
        guard let window else { return }
        markerLayer.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
        markerLayer.backgroundColor = UIColor.white.cgColor
        markerLayer.cornerRadius = 6
        markerLayer.zPosition = 100_000
        phaseLayer.contentsScale = UIScreen.main.scale
        phaseLayer.alignmentMode = .center
        phaseLayer.fontSize = 13
        phaseLayer.foregroundColor = UIColor.white.cgColor
        phaseLayer.backgroundColor = UIColor.black.withAlphaComponent(0.72).cgColor
        phaseLayer.cornerRadius = 12
        phaseLayer.zPosition = 100_000
        let labelWidth = min(230, max(0, window.bounds.width - 24))
        phaseLayer.frame = CGRect(x: max(12, (window.bounds.width - labelWidth) / 2), y: max(52, window.safeAreaInsets.top + 8), width: labelWidth, height: 32)
        window.layer.addSublayer(markerLayer)
        window.layer.addSublayer(phaseLayer)
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        if startedAt == nil { startedAt = link.timestamp }
        guard let startedAt else { return }
        recordCadence(link.timestamp)
        let elapsed = max(0, link.timestamp - startedAt)
        let phaseIndex = Int(elapsed / phaseDuration) % 6
        if phaseIndex != lastPhaseIndex {
            logPhaseSummary(reason: "phase-change")
            lastPhaseIndex = phaseIndex
            resetCadence(keepingTimestamp: link.timestamp)
            let treeActive = phaseIndex % 2 == 1
            let round = phaseIndex / 2 + 1
            phaseLayer.string = treeActive ? "CROSSOVER TREE \(round)/3" : "CROSSOVER REF \(round)/3"
            DiagnosticsLogger.shared.playback("HomeCarouselCrossover", "phase=\(treeActive ? \"tree\" : \"reference\") round=\(round) maxFPS=\(UIScreen.main.maximumFramesPerSecond) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) thermal=\(thermalStateName)")
            if !treeActive { onProgress?(0.5) }
        }

        if let window {
            let markerCycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
            let markerProgress = markerCycle < 0.5 ? markerCycle * 2 : (1 - markerCycle) * 2
            let markerX = 20 + CGFloat(markerProgress) * max(0, window.bounds.width - 40)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            markerLayer.position = CGPoint(x: markerX, y: max(110, window.safeAreaInsets.top + 92))
            CATransaction.commit()
        }

        guard phaseIndex % 2 == 1 else { return }
        let treeCycle = link.timestamp.truncatingRemainder(dividingBy: 1.44) / 1.44
        let value = treeCycle < 0.5 ? treeCycle * 2 : (1 - treeCycle) * 2
        onProgress?(CGFloat(value))
    }

    private func recordCadence(_ timestamp: CFTimeInterval) {
        if let lastTimestamp {
            let gapMS = max(0, (timestamp - lastTimestamp) * 1000)
            intervalCount += 1
            totalGapMS += gapMS
            maxGapMS = max(maxGapMS, gapMS)
        }
        lastTimestamp = timestamp
    }

    private func resetCadence(keepingTimestamp timestamp: CFTimeInterval? = nil) {
        lastTimestamp = timestamp
        intervalCount = 0
        totalGapMS = 0
        maxGapMS = 0
    }

    private func logPhaseSummary(reason: String) {
        guard lastPhaseIndex >= 0, intervalCount > 0 else { return }
        let treeActive = lastPhaseIndex % 2 == 1
        let round = lastPhaseIndex / 2 + 1
        let average = totalGapMS / Double(intervalCount)
        DiagnosticsLogger.shared.playback("HomeCarouselCrossover", "summary phase=\(treeActive ? \"tree\" : \"reference\") round=\(round) intervals=\(intervalCount) avgGapMS=\(String(format: \"%.3f\", average)) maxGapMS=\(String(format: \"%.3f\", maxGapMS)) reason=\(reason)")
    }

    private var thermalStateName: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
'''
probe.write_text(text[:start] + replacement + text[end:])
