from pathlib import Path
import subprocess


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)


# Materialize the already validated MPV 0.13.7 comparison telemetry first so the
# dual-engine architecture build contains the exact MPV diagnostics used by the A/B test.
subprocess.run(["python3", "scripts/apply_mpv_compare_0137.py"], check=True)

# Version identity: first formal dual-engine architecture build.
path = Path("project.yml")
text = path.read_text()
text = text.replace('MARKETING_VERSION: "0.13.7"', 'MARKETING_VERSION: "0.13.8"')
text = text.replace('CURRENT_PROJECT_VERSION: "74"', 'CURRENT_PROJECT_VERSION: "75"')
path.write_text(text)

path = Path("Sources/Core/AppIdentity.swift")
text = path.read_text()
text = text.replace('static let sourceVersion = "0.13.7"', 'static let sourceVersion = "0.13.8"')
text = text.replace('?? "0.13.7"', '?? "0.13.8"')
path.write_text(text)

# Build MDK and MPV in the same iOS 15 target. Keep both dependencies pinned.
path = Path("project.mdklab.yml")
text = path.read_text()
text = replace_once(
    text,
    '  SwiftMDK:\n    url: https://github.com/wang-bin/swift-mdk.git\n    revision: f112a85f2f51c5352439465204c1ae0fa51a9f18\n  KSPlayerShim:',
    '  SwiftMDK:\n    url: https://github.com/wang-bin/swift-mdk.git\n    revision: f112a85f2f51c5352439465204c1ae0fa51a9f18\n  MPVKit:\n    url: https://github.com/mpvkit/MPVKit.git\n    exactVersion: 1.0.0\n  KSPlayerShim:',
    'dual engine package',
)
text = replace_once(
    text,
    '      - package: SwiftMDK\n        product: swift-mdk\n      - package: KSPlayerShim',
    '      - package: SwiftMDK\n        product: swift-mdk\n      - package: MPVKit\n        product: MPVKit\n      - package: KSPlayerShim',
    'dual engine target dependency',
)
text = text.replace('# MDK Lab 0.13.6 active-native watchdog and rendered-frame seek recovery baseline. Keep the pinned SDK fixed for this comparison round.\n# Rapid user taps remain immediate at the UI layer; only native MDK seek dispatch is coalesced latest-wins.\n# The MDK lab CI audits both LC_BUILD_VERSION and legacy LC_VERSION_MIN_IPHONEOS slices.', '# OnePlayer 0.13.8 dual-engine playback architecture baseline. MDK is the default high-performance engine; MPV is the high-compatibility engine.\n# Playback/session/transport/buffer semantics stay above engine adapters; engine-specific recovery remains inside each adapter.\n# The CI audits both LC_BUILD_VERSION and legacy LC_VERSION_MIN_IPHONEOS slices for iOS 15 compatibility.')
text = text.replace('MARKETING_VERSION: "0.13.6"', 'MARKETING_VERSION: "0.13.8"')
text = text.replace('CURRENT_PROJECT_VERSION: "73"', 'CURRENT_PROJECT_VERSION: "75"')
path.write_text(text)

# Public engine naming/default semantics and common playback buffer state.
path = Path("Sources/Player/PlayerEngine.swift")
text = path.read_text()
text = text.replace('return "MDK Metal（实验）"', 'return "高性能引擎"')
text = text.replace('return "MPV 兼容引擎"', 'return "高兼容引擎"')
text = text.replace('case .automatic: return "自动（推荐）"', 'case .automatic: return "自动（高性能优先）"')
text = replace_once(
    text,
    '    static func persisted(rawValue: String?) -> PlayerEnginePreference {\n        let preference = rawValue.flatMap(PlayerEnginePreference.init(rawValue:)) ?? .automatic\n        return selectableCases.contains(preference) ? preference : .automatic\n    }',
    '    static var defaultPreference: PlayerEnginePreference {\n        #if MDK_LAB && canImport(KSPlayer)\n        return .ksAVIO\n        #else\n        return .automatic\n        #endif\n    }\n\n    static func persisted(rawValue: String?) -> PlayerEnginePreference {\n        let preference = rawValue.flatMap(PlayerEnginePreference.init(rawValue:)) ?? defaultPreference\n        return selectableCases.contains(preference) ? preference : defaultPreference\n    }',
    'default engine preference',
)
text = replace_once(
    text,
    '    static var automaticCompatibilityKind: PlayerEngineKind {\n        #if canImport(Libmpv)\n        return .mpv\n        #elseif canImport(KSPlayer)\n        return .ksAVIO\n        #else\n        return .resourceLoaderAVPlayer\n        #endif\n    }',
    '    static var automaticCompatibilityKind: PlayerEngineKind {\n        #if MDK_LAB && canImport(KSPlayer)\n        return .ksAVIO\n        #elseif canImport(Libmpv)\n        return .mpv\n        #elseif canImport(KSPlayer)\n        return .ksAVIO\n        #else\n        return .resourceLoaderAVPlayer\n        #endif\n    }',
    'automatic high-performance priority',
)
text = replace_once(
    text,
    '        case .automatic:\n            let nativeContainers: Set<String> = ["mp4", "mov", "m4v"]',
    '        case .automatic:\n            #if MDK_LAB && canImport(KSPlayer)\n            return .ksAVIO\n            #else\n            let nativeContainers: Set<String> = ["mp4", "mov", "m4v"]',
    'automatic MDK selection begin',
)
text = replace_once(
    text,
    '            return Self.automaticCompatibilityKind\n        }\n    }\n}\n\nstruct PlayerSnapshot:',
    '            return Self.automaticCompatibilityKind\n            #endif\n        }\n    }\n}\n\nstruct PlayerSnapshot:',
    'automatic MDK selection end',
)
text = replace_once(
    text,
    'struct SeekResult {\n',
    'struct PlaybackBufferState: Equatable {\n    var livePlayableRanges: [ClosedRange<Double>] = []\n    var verifiedHistoryRanges: [ClosedRange<Double>] = []\n    var isBuffering = false\n    var waitingReason: String?\n}\n\nstruct SeekResult {\n',
    'common playback buffer state',
)
path.write_text(text)

# Default engine setting and product wording.
path = Path("Sources/UI/PlayerSettingsView.swift")
text = path.read_text()
text = text.replace('@AppStorage(PlayerPreferenceKeys.enginePreference) private var enginePreference = PlayerEnginePreference.automatic.rawValue', '@AppStorage(PlayerPreferenceKeys.enginePreference) private var enginePreference = PlayerEnginePreference.defaultPreference.rawValue')
text = text.replace('Section(header: Text("播放器引擎"), footer: Text("KSPlayer KSME 仅在 KSPlayer Lab 构建中提供，用于与 MPV 真机对比；自动模式不会在运行中切换引擎。"))', 'Section(header: Text("播放器引擎"), footer: Text("高性能引擎为默认选择；高兼容引擎用于媒体兼容兜底。当前设置决定新播放会话使用的引擎。"))')
path.write_text(text)

# Common controller-owned buffer state. Transport byte ranges remain diagnostics only.
path = Path("Sources/Player/PlayerController.swift")
text = path.read_text()
text = replace_once(
    text,
    '    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []\n',
    '    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []\n    @Published private(set) var bufferState = PlaybackBufferState()\n',
    'controller buffer state property',
)
text = replace_once(
    text,
    '    var verifiedBufferedEnd: Double { verifiedBufferedRanges.map(\\.upperBound).max() ?? 0 }\n\n    private func updateVerifiedBufferedRanges(from value: PlayerSnapshot) {',
    '    var verifiedBufferedEnd: Double { verifiedBufferedRanges.map(\\.upperBound).max() ?? 0 }\n\n    private func updatePlaybackBufferState(from value: PlayerSnapshot) {\n        bufferState = PlaybackBufferState(livePlayableRanges: value.bufferedRanges, verifiedHistoryRanges: verifiedBufferedRanges, isBuffering: value.isBuffering, waitingReason: value.waitingReason)\n    }\n\n    private func updateVerifiedBufferedRanges(from value: PlayerSnapshot) {',
    'controller buffer state updater',
)
text = replace_once(
    text,
    '                self.updateVerifiedBufferedRanges(from: value)\n                self.logBufferTimelineIfNeeded(value)',
    '                self.updateVerifiedBufferedRanges(from: value)\n                self.updatePlaybackBufferState(from: value)\n                self.logBufferTimelineIfNeeded(value)',
    'bind common buffer state',
)
text = replace_once(
    text,
    '        verifiedBufferedRanges = [fullRange]\n        DiagnosticsLogger.shared.log("BufferHistory",',
    '        verifiedBufferedRanges = [fullRange]\n        bufferState.verifiedHistoryRanges = verifiedBufferedRanges\n        DiagnosticsLogger.shared.log("BufferHistory",',
    'full cache buffer state promotion',
)
text = text.replace('MPV 兼容引擎', '高兼容引擎')
path.write_text(text)

# Timeline UI: dim session-history TIME ranges + brighter current live TIME ranges + played progress.
Path("Sources/UI/BufferedTimelineSlider.swift").write_text('''import SwiftUI\n\nstruct BufferedTimelineSlider: View {\n    @Binding var value: Double\n    let range: ClosedRange<Double>\n    /// Playback-layer buffer semantics on the media TIME axis. UnifiedTransport byte\n    /// ranges are deliberately excluded because byte/file-size projection is invalid for VBR/MKV.\n    let bufferState: PlaybackBufferState\n    let onEditingChanged: (Bool) -> Void\n\n    @State private var isEditing = false\n\n    var body: some View {\n        GeometryReader { geometry in\n            let width = max(geometry.size.width, 1)\n            let trackHeight: CGFloat = 10\n            ZStack(alignment: .leading) {\n                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)\n\n                ForEach(Array(normalizedRanges(bufferState.verifiedHistoryRanges).enumerated()), id: \\.offset) { _, verified in\n                    Capsule()\n                        .fill(Color(white: 0.32))\n                        .frame(width: max(2, width * CGFloat(verified.upperBound - verified.lowerBound)), height: trackHeight)\n                        .offset(x: width * CGFloat(verified.lowerBound))\n                }\n\n                ForEach(Array(normalizedRanges(bufferState.livePlayableRanges).enumerated()), id: \\.offset) { _, live in\n                    Capsule()\n                        .fill(Color(white: 0.58))\n                        .frame(width: max(2, width * CGFloat(live.upperBound - live.lowerBound)), height: trackHeight)\n                        .offset(x: width * CGFloat(live.lowerBound))\n                }\n\n                Capsule().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: 4)\n            }\n            .frame(height: max(geometry.size.height, 24))\n            .contentShape(Rectangle())\n            .gesture(\n                DragGesture(minimumDistance: 0)\n                    .onChanged { gesture in\n                        if !isEditing {\n                            isEditing = true\n                            onEditingChanged(true)\n                        }\n                        value = valueForLocation(gesture.location.x, totalWidth: width)\n                    }\n                    .onEnded { gesture in\n                        value = valueForLocation(gesture.location.x, totalWidth: width)\n                        isEditing = false\n                        onEditingChanged(false)\n                    }\n            )\n        }\n        .frame(height: 32)\n        .accessibilityElement(children: .ignore)\n        .accessibilityLabel("播放进度")\n        .accessibilityValue(accessibilityValue)\n        .accessibilityAdjustableAction { direction in\n            let step = max((range.upperBound - range.lowerBound) / 100, 1)\n            switch direction {\n            case .increment: value = min(range.upperBound, value + step)\n            case .decrement: value = max(range.lowerBound, value - step)\n            @unknown default: break\n            }\n            onEditingChanged(false)\n        }\n    }\n\n    private func normalizedRanges(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {\n        let duration = range.upperBound - range.lowerBound\n        guard duration > 0 else { return [] }\n        return ranges.compactMap { item in\n            let clippedLower = max(range.lowerBound, item.lowerBound)\n            let clippedUpper = min(range.upperBound, item.upperBound)\n            guard clippedUpper > clippedLower else { return nil }\n            let lower = min(1, max(0, (clippedLower - range.lowerBound) / duration))\n            let upper = min(1, max(0, (clippedUpper - range.lowerBound) / duration))\n            return upper > lower ? lower...upper : nil\n        }\n    }\n\n    private var accessibilityValue: String {\n        let duration = max(0, range.upperBound - range.lowerBound)\n        guard duration > 0 else { return "0%" }\n        let percent = Int(((value - range.lowerBound) / duration * 100).rounded())\n        return bufferState.isBuffering ? "\\(percent)%，正在缓冲" : "\\(percent)%"\n    }\n\n    private func fraction(for value: Double) -> CGFloat {\n        let duration = range.upperBound - range.lowerBound\n        guard duration > 0 else { return 0 }\n        return CGFloat(min(max((value - range.lowerBound) / duration, 0), 1))\n    }\n\n    private func progressWidth(totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: value) }\n\n    private func valueForLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {\n        let ratio = Double(min(max(x / max(totalWidth, 1), 0), 1))\n        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio\n    }\n}\n''')

path = Path("Sources/UI/PlayerScreen.swift")
text = path.read_text()
text = replace_once(text, '                    playableRanges: controller.snapshot.bufferedRanges,', '                    bufferState: controller.bufferState,', 'player screen common buffer state')
path.write_text(text)

# MDK: add a one-shot 1s fast watchdog. It does no polling; normal seeks that finish
# before one second fail the identity guard and never query transport metrics.
path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()
text = replace_once(
    text,
    '        var nativeStartedAt: TimeInterval?\n',
    '        var nativeStartedAt: TimeInterval?\n        var nativeStartFrameSerial: UInt64?\n',
    'MDK native frame baseline',
)
text = replace_once(
    text,
    '    private let activeNativeSeekWatchdogSeconds: TimeInterval = 2.0\n',
    '    private let activeNativeSeekFastWatchdogSeconds: TimeInterval = 1.0\n    private let activeNativeSeekWatchdogSeconds: TimeInterval = 2.0\n',
    'MDK fast watchdog threshold',
)
text = replace_once(
    text,
    '        dispatchedIntent.nativeStartedAt = nativeStartedAt\n        activeNativeSeek = dispatchedIntent\n',
    '        dispatchedIntent.nativeStartedAt = nativeStartedAt\n        dispatchedIntent.nativeStartFrameSerial = renderedFrameSerial\n        activeNativeSeek = dispatchedIntent\n',
    'MDK native frame baseline capture',
)
text = replace_once(
    text,
    '        scheduleActiveNativeSeekWatchdog(player: player, intent: dispatchedIntent, hard: false)\n        DiagnosticsLogger.shared.playback("MDKSeek",',
    '        scheduleActiveNativeSeekFastWatchdog(player: player, intent: dispatchedIntent)\n        scheduleActiveNativeSeekWatchdog(player: player, intent: dispatchedIntent, hard: false)\n        DiagnosticsLogger.shared.playback("MDKSeek",',
    'schedule MDK fast watchdog',
)
fast_method = '''    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {\n        guard let nativeStartedAt = intent.nativeStartedAt, let startFrameSerial = intent.nativeStartFrameSerial else { return }\n        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in\n            guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }\n            guard self.renderedFrameSerial <= startFrameSerial else {\n                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\\(intent.id) elapsedNativeMs=\\(String(format: \"%.1f\", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-render-progress")\n                return\n            }\n            guard let session = self.sharedTransportSession else {\n                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\\(intent.id) elapsedNativeMs=\\(String(format: \"%.1f\", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-no-unified-transport")\n                return\n            }\n            Task { [weak self, weak player] in\n                let metrics = await session.metrics()\n                await MainActor.run {\n                    guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }\n                    let status = player.mediaStatus.rawValue\n                    let rawBuffering = self.hasStatus(status, bit: 3) || self.hasStatus(status, bit: 4)\n                    let bufferMs = player.buffered()\n                    let noRenderedProgress = self.renderedFrameSerial <= startFrameSerial\n                    let transportHealthy = metrics.rangeFailureCount == 0 && metrics.resourceBytes > 0 && (metrics.cacheBytes > 0 || metrics.currentDownloadBytesPerSecond >= 1_048_576 || metrics.activeRequestCount == 0)\n                    let engineDataHealthy = bufferMs >= 500 && !rawBuffering\n                    let shouldRecover = noRenderedProgress && transportHealthy && engineDataHealthy\n                    let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)\n                    DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedNativeMs=\\(String(format: \"%.1f\", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) frameSerial=\\(self.renderedFrameSerial)/\\(startFrameSerial) bufferMs=\\(bufferMs) rawBuffering=\\(rawBuffering) transportHealthy=\\(transportHealthy) cacheBytes=\\(metrics.cacheBytes) active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=\\(shouldRecover ? \"recover-latest-target\" : \"defer-standard-watchdog\")")\n                    if shouldRecover { self.recoverWedgedSeek(reason: "active-native-fast-timeout", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration) }\n                }\n            }\n        }\n    }\n\n'''
text = replace_once(text, '    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n', fast_method + '    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n', 'MDK fast watchdog method')
path.write_text(text)

# Source-level contracts for this materialized build.
checks = {
    "0.13.8 identity": 'static let sourceVersion = "0.13.8"' in Path("Sources/Core/AppIdentity.swift").read_text(),
    "dual engine packages": 'exactVersion: 1.0.0' in Path("project.mdklab.yml").read_text() and 'f112a85f2f51c5352439465204c1ae0fa51a9f18' in Path("project.mdklab.yml").read_text(),
    "default high performance engine": 'return .ksAVIO' in Path("Sources/Player/PlayerEngine.swift").read_text() and '高性能引擎' in Path("Sources/Player/PlayerEngine.swift").read_text(),
    "high compatibility engine name": '高兼容引擎' in Path("Sources/Player/PlayerEngine.swift").read_text(),
    "common buffer state": 'struct PlaybackBufferState' in Path("Sources/Player/PlayerEngine.swift").read_text() and 'bufferState: controller.bufferState' in Path("Sources/UI/PlayerScreen.swift").read_text(),
    "two layer time timeline": 'verifiedHistoryRanges' in Path("Sources/UI/BufferedTimelineSlider.swift").read_text() and 'livePlayableRanges' in Path("Sources/UI/BufferedTimelineSlider.swift").read_text(),
    "no byte projection in timeline": 'transportCacheRanges' not in Path("Sources/UI/BufferedTimelineSlider.swift").read_text(),
    "MDK conditional 1s recovery": 'activeNativeSeekFastWatchdogSeconds: TimeInterval = 1.0' in Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift").read_text() and 'active-native-fast-timeout' in Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift").read_text(),
    "MPV comparison telemetry retained": 'MPVSeekEvent' in Path("Sources/Player/MPVPlayerEngine.swift").read_text(),
}
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL"), name)
    if not ok:
        raise SystemExit(f"contract failed: {name}")

print("OnePlayer 0.13.8 playback architecture patch applied")
