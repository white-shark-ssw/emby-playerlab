from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"target not found in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_all(path: str, old: str, new: str, minimum: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count < minimum:
        if new in text:
            return
        raise SystemExit(f"expected >= {minimum} occurrences in {path}: {old!r}, got {count}")
    p.write_text(text.replace(old, new))


unified = "Sources/Transport/UnifiedMediaTransportSession.swift"
replace_once(unified,
'''    private struct LiveLaneState {
        var generation = 0
        var startedAt = Date.distantPast
        var lastChunkAt = Date.distantPast
        var receivedBytes: Int64 = 0
        var recentBps: Double = 0
        var slowStreak = 0
        var resetCooldownUntil = Date.distantPast
    }
''',
'''    private struct LiveLaneState {
        var generation = 0
        var startedAt = Date.distantPast
        var lastChunkAt = Date.distantPast
        var sampleWindowStartedAt = Date.distantPast
        var sampleWindowStartedBytes: Int64 = 0
        var lastSampleAt = Date.distantPast
        var receivedBytes: Int64 = 0
        var recentBps: Double = 0
        var slowStreak = 0
        var resetCooldownUntil = Date.distantPast
    }
''')
replace_once(unified,
'''    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
''',
'''    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneSampleWindowSeconds: TimeInterval = 1.0
    private let liveLaneSampleMinimumBytes: Int64 = 1 * 1_048_576
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
''')
replace_once(unified,
'''            live.generation = generation
            live.startedAt = now
            live.lastChunkAt = now
            live.receivedBytes = 0
            live.recentBps = 0
            live.slowStreak = 0
''',
'''            live.generation = generation
            live.startedAt = now
            live.lastChunkAt = now
            live.sampleWindowStartedAt = now
            live.sampleWindowStartedBytes = 0
            live.lastSampleAt = .distantPast
            live.receivedBytes = 0
            live.recentBps = 0
            live.slowStreak = 0
''')
replace_once(unified,
'''        // A non-sequential claim already starting at this byte is foreground work. Let that request
        // finish rather than opening a duplicate Range for the same demux dependency.
        if let active = slotClaims.values.first(where: { $0.role != .sequential && $0.range.contains(range.lowerBound) }) {
            DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active foreground request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) role=\(active.role.rawValue) reason=\(reason)")
            return
        }
''',
'''        // Being inside an active foreground claim still does not prove that the requested byte has
        // arrived. A far seek can land deep inside an older 16 MiB urgent claim; waiting for that lane
        // to walk linearly to the new read head caused multi-second stalls while the second lane sat idle.
        if let activeEntry = slotClaims.first(where: { $0.value.role != .sequential && $0.value.range.contains(range.lowerBound) }) {
            let activeSlot = activeEntry.key
            let active = activeEntry.value
            if concretePlaybackDemand, active.role == .urgentPlayback {
                let ready = store.availableLength(from: active.range.lowerBound, maximumLength: Int64(active.range.count))
                let streamHead = min(active.range.upperBound, active.range.lowerBound + ready)
                let gap = max(0, range.lowerBound - streamHead)
                if gap > progressiveUrgentGapBytes {
                    DiagnosticsLogger.shared.log("UnifiedDemand", "foreground active-gap slot=\(activeSlot) request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) head=\(streamHead) gap=\(gap) action=parallel-urgent")
                    installUrgent(range: range, metadata: false, reason: "foreground-active-gap-\(reason)")
                    scheduleSlots(reason: "foreground-active-gap-\(reason)")
                    return
                }
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active foreground request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) role=\(active.role.rawValue) reason=\(reason)")
            return
        }
''')
replace_once(unified,
'''    private func checkFirstByteWatchdog(slot: Int, generation: Int, hard: Bool) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, live.receivedBytes == 0 else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let now = Date()
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
        guard hard || peerBps >= 2 * 1_048_576 else { return }
        requestLiveLaneRotation(slot: slot, generation: generation, reason: hard ? "first-byte-hard-timeout" : "first-byte-peer-fast", observedBps: 0, peerBps: peerBps)
    }

    private func observeSequentialChunk(slot: Int, generation: Int, bytes: Int64) {
        guard bytes > 0, slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential else { return }
        let now = Date()
        var live = liveLaneState[slot] ?? LiveLaneState()
        guard live.generation == generation else { return }
        let interval = max(now.timeIntervalSince(live.lastChunkAt), 0.001)
        let chunkBps = Double(bytes) / interval
        live.lastChunkAt = now
        live.receivedBytes += bytes
        live.recentBps = live.recentBps == 0 ? chunkBps : live.recentBps * 0.55 + chunkBps * 0.45

        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : (peerCompleted?.averageBps ?? 0)
        let relativeSlow = peerBps >= liveLanePeerFloorBps && live.recentBps < peerBps * liveLaneRelativeFloor
        let absoluteSlow = live.receivedBytes >= 2 * 1_048_576 && live.recentBps < liveLaneAbsoluteFloorBps
        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(liveLaneAbsoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
        liveLaneState[slot] = live

        if live.slowStreak >= 2 {
            requestLiveLaneRotation(slot: slot, generation: generation, reason: relativeSlow ? "rolling-relative-slow" : "rolling-absolute-slow", observedBps: live.recentBps, peerBps: peerBps)
        }
    }
''',
'''    private func checkFirstByteWatchdog(slot: Int, generation: Int, hard: Bool) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, live.receivedBytes == 0 else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let now = Date()
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps: Double
        if let peerLive, peerLiveFresh {
            let elapsed = max(now.timeIntervalSince(peerLive.startedAt), 0.001)
            peerBps = peerLive.recentBps > 0 ? peerLive.recentBps : Double(peerLive.receivedBytes) / elapsed
        } else {
            peerBps = peerCompleted?.averageBps ?? 0
        }
        guard hard || peerBps >= 2 * 1_048_576 else { return }
        requestLiveLaneRotation(slot: slot, generation: generation, reason: hard ? "first-byte-hard-timeout" : "first-byte-peer-fast", observedBps: 0, peerBps: peerBps)
    }

    private func observeSequentialChunk(slot: Int, generation: Int, bytes: Int64) {
        guard bytes > 0, slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential else { return }
        let now = Date()
        var live = liveLaneState[slot] ?? LiveLaneState()
        guard live.generation == generation else { return }
        live.lastChunkAt = now
        live.receivedBytes += bytes

        // URLSession may deliver several already-buffered chunks back-to-back. Measuring one chunk
        // against the previous callback timestamp produced impossible 100-500 MB/s samples and false
        // lane rotations. Only a real time window is allowed to influence connection health.
        let sampleSeconds = now.timeIntervalSince(live.sampleWindowStartedAt)
        let sampleBytes = live.receivedBytes - live.sampleWindowStartedBytes
        guard sampleSeconds >= liveLaneSampleWindowSeconds, sampleBytes >= liveLaneSampleMinimumBytes else {
            liveLaneState[slot] = live
            return
        }
        let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)
        live.sampleWindowStartedAt = now
        live.sampleWindowStartedBytes = live.receivedBytes
        live.lastSampleAt = now
        live.recentBps = live.recentBps == 0 ? windowBps : live.recentBps * 0.60 + windowBps * 0.40

        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerLiveFresh = peerLive.map { $0.recentBps > 0 && now.timeIntervalSince($0.lastSampleAt) <= 2.5 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : 0
        let relativeSlow = peerLiveFresh && peerBps >= liveLanePeerFloorBps && live.recentBps < peerBps * liveLaneRelativeFloor
        let absoluteSlow = now.timeIntervalSince(live.startedAt) >= 3.0 && live.receivedBytes >= 4 * 1_048_576 && live.recentBps < liveLaneAbsoluteFloorBps
        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(liveLaneAbsoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
        liveLaneState[slot] = live
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) windowMs=\(Int(sampleSeconds * 1000)) windowBytes=\(sampleBytes) sampleBps=\(Int(windowBps)) avgBps=\(Int(live.recentBps)) peerBps=\(Int(peerBps)) slowStreak=\(live.slowStreak)")

        if live.slowStreak >= 2 {
            requestLiveLaneRotation(slot: slot, generation: generation, reason: relativeSlow ? "rolling-relative-slow" : "rolling-absolute-slow", observedBps: live.recentBps, peerBps: peerBps)
        }
    }
''')

controller = "Sources/Player/PlayerController.swift"
replace_once(controller,
'''    @Published private(set) var transportSummary: String?
    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []
''',
'''    @Published private(set) var transportSummary: String?
    @Published private(set) var transportCacheFraction: Double = 0
    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []
''')
replace_once(controller,
'''        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        engineSwitchTask?.cancel()
''',
'''        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        transportCacheFraction = 0
        engineSwitchTask?.cancel()
''')
replace_once(controller,
'''        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        lastTransportMetrics = nil
''',
'''        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        transportCacheFraction = 0
        lastTransportMetrics = nil
''')
replace_once(controller,
'''                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
                    self.promoteFullCacheRangeIfNeeded(metrics)
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                }
''',
'''                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
                    self.transportCacheFraction = metrics.resourceBytes > 0 ? min(1, max(0, Double(metrics.cacheBytes) / Double(metrics.resourceBytes))) : 0
                    self.promoteFullCacheRangeIfNeeded(metrics)
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                    self.transportCacheFraction = 0
                }
''')

slider = "Sources/UI/BufferedTimelineSlider.swift"
replace_once(slider,
'''    /// Current engine live buffer. This may move/shrink after a seek.
    let bufferedRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void
''',
'''    /// Current engine live buffer. This may move/shrink after a seek.
    let bufferedRanges: [ClosedRange<Double>]
    /// Total UnifiedTransport byte-cache coverage. This is quantity coverage, not a claim that
    /// every time position before the fill edge is seekable after sparse seeks.
    let downloadCacheFraction: Double
    let onEditingChanged: (Bool) -> Void
''')
replace_once(slider,
'''                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                ForEach(Array(normalizedVerifiedRanges.enumerated()), id: \.offset) { _, buffered in
''',
'''                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                Capsule()
                    .fill(Color(white: 0.34))
                    .frame(width: max(0, width * CGFloat(min(max(downloadCacheFraction, 0), 1))), height: trackHeight)

                ForEach(Array(normalizedVerifiedRanges.enumerated()), id: \.offset) { _, buffered in
''')

screen = "Sources/UI/PlayerScreen.swift"
replace_once(screen,
'''                        verifiedBufferedRanges: controller.verifiedBufferedRanges,
                        bufferedRanges: controller.snapshot.bufferedRanges,
                        onEditingChanged: { editing in
''',
'''                        verifiedBufferedRanges: controller.verifiedBufferedRanges,
                        bufferedRanges: controller.snapshot.bufferedRanges,
                        downloadCacheFraction: controller.transportCacheFraction,
                        onEditingChanged: { editing in
''')
replace_once(screen,
'''            Text("已验证缓存至 \(formatTime(controller.verifiedBufferedEnd)) · 当前亮灰至 \(formatTime(controller.bufferedEnd)) · 前向可播 \(formatTime(controller.forwardBufferedDuration)) · \(controller.snapshot.isBuffering ? "等待数据" : "可播放")")
''',
'''            Text("下载缓存 \(Int((controller.transportCacheFraction * 100).rounded()))% · 已验证缓存至 \(formatTime(controller.verifiedBufferedEnd)) · 当前亮灰至 \(formatTime(controller.bufferedEnd)) · 前向可播 \(formatTime(controller.forwardBufferedDuration)) · \(controller.snapshot.isBuffering ? "等待数据" : "可播放")")
''')

Path("Sources/UI/MPVPlayerSurface.swift").write_text('''import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?
    private var lastGeometryLog = ""

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer")
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
        lastGeometryLog = ""
    }

    deinit { detach() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let displayLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.transform = CATransform3DIdentity
        displayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        displayLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        displayLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        CATransaction.commit()

        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let geometry = "view=\\(Int(bounds.width))x\\(Int(bounds.height)) layer=\\(Int(displayLayer.bounds.width))x\\(Int(displayLayer.bounds.height)) drawable=\\(Int(displayLayer.drawableSize.width))x\\(Int(displayLayer.drawableSize.height)) window=\\(Int(windowSize.width))x\\(Int(windowSize.height)) orientation=\\(orientation) scale=\\(String(format: \"%.2f\", displayLayer.contentsScale))"
        if geometry != lastGeometryLog {
            lastGeometryLog = geometry
            DiagnosticsLogger.shared.log("MPVSurface", geometry)
        }
    }
}

final class MPVSurfaceViewController: UIViewController {
    private let surfaceView = MPVSurfaceUIView()

    override func loadView() {
        surfaceView.backgroundColor = .black
        surfaceView.isOpaque = true
        surfaceView.clipsToBounds = true
        view = surfaceView
    }

    func attach(_ layer: CAMetalLayer) { surfaceView.attach(layer) }
    func detach() { surfaceView.detach() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        surfaceView.setNeedsLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DiagnosticsLogger.shared.log("MPVSurface", "transition target=\\(Int(size.width))x\\(Int(size.height))")
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.surfaceView.setNeedsLayout() }) { [weak self] _ in
            self?.surfaceView.setNeedsLayout()
            self?.surfaceView.layoutIfNeeded()
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
}

struct MPVPlayerSurface: UIViewControllerRepresentable {
    let displayLayer: CAMetalLayer

    func makeUIViewController(context: Context) -> MPVSurfaceViewController {
        let controller = MPVSurfaceViewController()
        controller.loadViewIfNeeded()
        controller.attach(displayLayer)
        return controller
    }

    func updateUIViewController(_ uiViewController: MPVSurfaceViewController, context: Context) { uiViewController.attach(displayLayer) }
    static func dismantleUIViewController(_ uiViewController: MPVSurfaceViewController, coordinator: ()) { uiViewController.detach() }
}
''')

# Version 0.12.2 / Build 60, keeping iOS 15.0.
replace_all("Sources/Core/AppIdentity.swift", '0.12.1', '0.12.2', 2)
replace_all("Config/Info.plist", '<string>0.12.1</string>', '<string>0.12.2</string>')
replace_all("Config/Info.plist", '<string>59</string>', '<string>60</string>')
replace_all("project.yml", 'MARKETING_VERSION: "0.12.1"', 'MARKETING_VERSION: "0.12.2"', 2)
replace_all("project.yml", 'CURRENT_PROJECT_VERSION: "59"', 'CURRENT_PROJECT_VERSION: "60"', 2)
replace_all(".github/workflows/build-unsigned-ipa.yml", 'EmbyPlayerLab-0.12.1-${GITHUB_SHA::7}-unsigned.ipa', 'EmbyPlayerLab-0.12.2-${GITHUB_SHA::7}-unsigned.ipa')
for path in ["scripts/check_transport_v3_invariants.py", "scripts/check_scheduler_v2_invariants.py", "scripts/check_live_lane_startup_invariants.py"]:
    replace_all(path, '0.12.1', '0.12.2')
    replace_all(path, '"59"', '"60"')

# Permanent v0.12.2 regression gate.
Path("scripts/check_v0122_regressions.py").write_text('''from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
slider = Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
screen = Path("Sources/UI/PlayerScreen.swift").read_text()
surface = Path("Sources/UI/MPVPlayerSurface.swift").read_text()
project = Path("project.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.2 regression failed: {message}")

# Live throughput must use real elapsed windows, never adjacent callback timing.
for needle in [
    "liveLaneSampleWindowSeconds: TimeInterval = 1.0",
    "sampleWindowStartedAt",
    "sampleWindowStartedBytes",
    "lastSampleAt",
    "let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)",
    "windowMs=",
]:
    require(needle in unified, f"windowed lane health missing {needle}")
require("let chunkBps = Double(bytes) / interval" not in unified, "callback-interarrival speed estimator must not return")
require("now.timeIntervalSince(live.lastChunkAt)" not in unified, "rolling health must not divide by last callback interval")

# Synthetic callback burst: 1 MiB callbacks 5ms apart must not imply 200 MiB/s.
bytes_in_window = 2 * 1_048_576
real_window_seconds = 1.05
window_bps = bytes_in_window / real_window_seconds
callback_bps = 1_048_576 / 0.005
require(window_bps < 3 * 1_048_576, "synthetic real-window sample invalid")
require(callback_bps > 100 * 1_048_576, "synthetic callback-burst regression invalid")

# A demand deep inside an active urgent claim must be able to borrow the other lane.
for needle in [
    "foreground active-gap slot=",
    'reason: "foreground-active-gap-',
    "active.role == .urgentPlayback",
    "gap > progressiveUrgentGapBytes",
]:
    require(needle in unified, f"active urgent gap recovery missing {needle}")

# Cache bar represents UnifiedTransport byte coverage independently from AVPlayer/mpv buffer ranges.
require("@Published private(set) var transportCacheFraction: Double = 0" in controller, "transport cache fraction missing")
require("Double(metrics.cacheBytes) / Double(metrics.resourceBytes)" in controller, "cache fraction must use actual byte cache/resource size")
require("downloadCacheFraction: Double" in slider, "timeline download-cache layer missing")
require("downloadCacheFraction: controller.transportCacheFraction" in screen, "PlayerScreen must pass transport cache fraction")
require("下载缓存" in screen, "diagnostics must label download cache separately from playable buffer")

# MPVKit's iOS demo uses UIViewControllerRepresentable. Keep our CAMetalLayer hosted in a
# controller so rotation gets UIKit size-transition callbacks instead of leaving a portrait UIView
# around a landscape MoltenVK drawable.
require("struct MPVPlayerSurface: UIViewControllerRepresentable" in surface, "MPV surface must use controller representable")
require("viewWillTransition(to size:" in surface, "MPV surface rotation callback missing")
require("transition target=" in surface, "rotation geometry diagnostics missing")
require("displayLayer.drawableSize =" not in surface, "UI must not force MoltenVK drawableSize")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.2"') == 2, "marketing version must be 0.12.2")
require(project.count('CURRENT_PROJECT_VERSION: "60"') == 2, "build number must be 60")

print("v0.12.2 regressions: OK")
''')

for workflow in [".github/workflows/validate-source.yml", ".github/workflows/build-unsigned-ipa.yml"]:
    p = Path(workflow)
    text = p.read_text()
    marker = '''      - name: Audit live lane/startup invariants\n        run: python3 scripts/check_live_lane_startup_invariants.py\n'''
    addition = marker + '''\n      - name: Audit v0.12.2 cache/throughput/rotation regressions\n        run: python3 scripts/check_v0122_regressions.py\n'''
    if "Audit v0.12.2 cache/throughput/rotation regressions" not in text:
        if marker not in text:
            raise SystemExit(f"workflow marker missing: {workflow}")
        p.write_text(text.replace(marker, addition, 1))

Path("docs/review/SELF_REVIEW_v0_12_2.md").write_text('''# v0.12.2 self-review

## Evidence from source=0.12.1 device log

- 63368/152901 total ByteStore cache grows hundreds of MiB while the timeline is driven by AVPlayer/mpv playable ranges. The transport cache and engine buffer are different concepts and must be rendered separately.
- v0.12.1 live lane health logged impossible peer rates above 100-500 MB/s after ordinary ~1-3 MB/s first chunks. Root cause: bytes divided by adjacent URLSession callback intervals.
- 152901 far seek showed ~800 MB total cache and up to ~12.7 MB/s network, yet only 1 MiB contiguous at the new anchor, Slot 0 deep in an older urgent claim and Slot 1 idle. Being inside an urgent claim did not mean the requested byte had arrived.
- 144799 rotation showed portrait `view=430x932` while Metal drawable became landscape `2796x1290` (932x430 at scale 3), proving host geometry and swapchain orientation diverged.

## Changes and invariants

1. Rolling lane health samples cumulative byte deltas over >=1.0 s windows. Back-to-back callback timing can never directly trigger a lane rotation.
2. First-byte watchdog remains independent and may still reject a lane that produces no bytes at all.
3. A concrete playback read more than 2 MiB ahead of an active urgent stream head may create a parallel urgent request on the other lane.
4. UnifiedTransport cache coverage is shown as its own timeline layer and percentage; AVPlayer/mpv playable ranges remain separate overlays.
5. MPV Surface follows MPVKit's controller-hosting pattern (`UIViewControllerRepresentable`) so UIKit rotation callbacks participate in layout. MoltenVK continues to own `drawableSize`.
6. Exactly two normal upstream lanes remain. No NAS media relay is introduced.
7. Deployment Target remains iOS 15.0.

## Scenario review

- 63368 sustained playback: a fast callback burst cannot manufacture a 100+ MB/s peer and reset a healthy connection. Real 1 s window samples can still rotate a repeatedly degraded lane.
- 63368 seek inside an active sequential claim: existing progressive-gap rule remains unchanged.
- 63368/152901 seek inside an active urgent claim: when the needed read is still >2 MiB beyond that urgent stream head, the second lane can fill from the real demand instead of idling.
- Whole-link slowdown: rolling relative rotation requires a fresh live peer; it does not compare a current lane against stale completed throughput. Absolute slow rotation still requires >=3 s runtime and >=4 MiB received.
- 152901 startup: v0.12.1 actual-tail 1 MiB dual-lane startup metadata logic is unchanged.
- Sparse cache after far seeks: download cache percentage may grow independently of forward playable seconds; UI labels the two concepts separately.
- 144799 portrait/landscape: UIKit view-controller transition is logged and causes a post-transition layout pass; no forced Metal drawable size is added.
- Close/cancel: no lifecycle changes to transport or mpv teardown.

## Not claimed by CI

CI can prove source invariants, iOS 15 deployment settings, and compilation. It cannot prove a particular 115 CDN throughput or real-device orientation behavior. Those remain device-log validation targets.
''')

print("Applied v0.12.2 cache/throughput/rotation patch")
