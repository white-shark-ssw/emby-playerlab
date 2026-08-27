from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, got {count}: {old[:100]!r}")
    p.write_text(text.replace(old, new, 1))


p = Path("project.yml")
text = p.read_text()
old_revision = "revision: b66a8a02375f7e58a0dc868d57eb0f6f7f0dde11"
if text.count(old_revision) != 1:
    raise SystemExit("project.yml: unexpected Aether revision shape")
text = text.replace(old_revision, "revision: 7422d45727f3bea9a4aa1b616138448488a394d8")
if text.count('MARKETING_VERSION: "0.14.55"') != 2 or text.count('CURRENT_PROJECT_VERSION: "222"') != 2:
    raise SystemExit("project.yml: unexpected Build222 identity shape")
text = text.replace('MARKETING_VERSION: "0.14.55"', 'MARKETING_VERSION: "0.14.57"')
text = text.replace('CURRENT_PROJECT_VERSION: "222"', 'CURRENT_PROJECT_VERSION: "224"')
p.write_text(text)

replace_once(
    "Sources/Player/AetherPlayerEngine.swift",
    "    private var seekRequests: [Double: (requestedAt: CFTimeInterval, bufferHit: Bool)] = [:]\n",
    "    private var seekRequests: [Double: (requestedAt: CFTimeInterval, bufferHit: Bool)] = [:]\n\n    var maxSupportedPlaybackRate: Double { Double(aether?.maxSupportedRate ?? 2) }\n",
)

replace_once(
    "Sources/Player/AetherPlayerEngine.swift",
    '''        let bufferHit = target >= current - 0.05 && target <= aether.clock.bufferedPosition + 0.25
        seekRequests[target] = (CACurrentMediaTime(), bufferHit)
        DiagnosticsLogger.shared.playback("AetherSeek", "request target=\\(String(format: "%.3f", target)) direction=\\(String(describing: direction)) rendered=\\(String(format: "%.3f", aether.clock.sourceTime)) buffered=\\(String(format: "%.3f", aether.clock.bufferedPosition))")
        Task { @MainActor [weak self] in await self?.aether?.seek(to: target) }
''',
    '''        let bufferHit = target >= current - 0.05 && target <= aether.clock.bufferedPosition + 0.25
        let toleranceSeconds: Double
        switch direction {
        case .forward, .backward: toleranceSeconds = 0.75
        case .absolute: toleranceSeconds = 0
        }
        seekRequests[target] = (CACurrentMediaTime(), bufferHit)
        DiagnosticsLogger.shared.playback("AetherSeek", "request target=\\(String(format: "%.3f", target)) direction=\\(String(describing: direction)) tolerance=\\(String(format: "%.2f", toleranceSeconds)) rendered=\\(String(format: "%.3f", aether.clock.sourceTime)) buffered=\\(String(format: "%.3f", aether.clock.bufferedPosition))")
        Task { @MainActor [weak self] in await self?.aether?.seek(to: target, toleranceSeconds: toleranceSeconds) }
''',
)

replace_once(
    "Sources/Player/PlaybackRateBridge.swift",
    '''extension PlayerController {
    func setPlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
''',
    '''extension PlayerController {
    var maxSupportedPlaybackRate: Double {
        #if canImport(AetherEngine)
        if let engine = engine as? AetherPlayerEngine { return engine.maxSupportedPlaybackRate }
        #endif
        return 8
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(maxSupportedPlaybackRate, max(0.15, rate))
''',
)

replace_once(
    "Sources/UI/PlayerControlPanelViews.swift",
    '''    let currentRate: Double
    let onRateSelected: (Double) -> Void
''',
    '''    let currentRate: Double
    let maxRate: Double
    let onRateSelected: (Double) -> Void
''',
)
replace_once(
    "Sources/UI/PlayerControlPanelViews.swift",
    '''        currentRate: Double,
        onRateSelected: @escaping (Double) -> Void,
''',
    '''        currentRate: Double,
        maxRate: Double = 8,
        onRateSelected: @escaping (Double) -> Void,
''',
)
replace_once(
    "Sources/UI/PlayerControlPanelViews.swift",
    '''        self.currentRate = currentRate
        self.onRateSelected = onRateSelected
''',
    '''        self.currentRate = currentRate
        self.maxRate = maxRate
        self.onRateSelected = onRateSelected
''',
)
replace_once(
    "Sources/UI/PlayerControlPanelViews.swift",
    '''                currentRate: currentRate,
                onRateSelected: onRateSelected,
''',
    '''                currentRate: currentRate,
                maxRate: maxRate,
                onRateSelected: onRateSelected,
''',
)

replace_once(
    "Sources/UI/PlayerFloatingPanelViews.swift",
    '''    let currentRate: Double
    let onRateSelected: (Double) -> Void
''',
    '''    let currentRate: Double
    let maxRate: Double
    let onRateSelected: (Double) -> Void
''',
)
replace_once(
    "Sources/UI/PlayerFloatingPanelViews.swift",
    '''                    PlayerSpeedFloatingPanel(currentRate: currentRate, onSelect: { rate in
''',
    '''                    PlayerSpeedFloatingPanel(currentRate: currentRate, maxRate: maxRate, onSelect: { rate in
''',
)
replace_once(
    "Sources/UI/PlayerFloatingPanelViews.swift",
    '''private struct PlayerSpeedFloatingPanel: View {
    let currentRate: Double
    let onSelect: (Double) -> Void
    private let rates = [8.0, 6.0, 5.0, 4.0, 3.0, 2.5, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5, 0.15]
''',
    '''private struct PlayerSpeedFloatingPanel: View {
    let currentRate: Double
    let maxRate: Double
    let onSelect: (Double) -> Void
    private static let allRates = [8.0, 6.0, 5.0, 4.0, 3.0, 2.5, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5, 0.15]
    private var rates: [Double] { Self.allRates.filter { $0 <= maxRate + 0.001 } }
''',
)

replace_once(
    "Sources/UI/PlayerScreen.swift",
    '''                currentRate: sessionOverrides.basePlaybackRate,
                onRateSelected: applyBasePlaybackRate,
''',
    '''                currentRate: sessionOverrides.basePlaybackRate,
                maxRate: controller.maxSupportedPlaybackRate,
                onRateSelected: applyBasePlaybackRate,
''',
)
