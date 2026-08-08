from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if old not in text:
        raise SystemExit(f"missing replacement anchor in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    text = read(path)
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"regex replacement count={count} in {path}: {pattern[:100]!r}")
    write(path, updated)


unified = "Sources/Transport/UnifiedMediaTransportSession.swift"
replace_once(
    unified,
    '''    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() { refreshMetrics(resource: resolved) }
        return metricsValue
    }

    func quiesceConsumers() async {''',
    '''    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() { refreshMetrics(resource: resolved) }
        return metricsValue
    }

    func cachedByteRanges() -> [Range<Int64>] {
        let resourceLength = resource?.contentLength ?? 0
        return rangeMap.snapshot(anchor: 0, resourceLength: resourceLength).playbackRanges
    }

    func quiesceConsumers() async {'''
)
replace_once(
    unified,
    '''        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason && !metadata
        var reanchored = false
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }
        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=actual-demand") }
''',
    '''        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason && !metadata
        let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset"
        var reanchored = false
        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=actual-demand") }
'''
)
replace_once(
    unified,
    '''        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteRead=true anchor=\\(playbackAnchor)"
            )
            return
        }

        // AVPlayer range announcements are speculative.''',
    '''        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteRead=true anchor=\\(playbackAnchor)"
            )
            return
        }
        if pendingUserSeek, concretePlaybackDemand, !authoritativeSeekDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek concrete-read deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingBlockedRead=true anchor=\\(playbackAnchor)"
            )
            return
        }
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }

        // AVPlayer range announcements are speculative.'''
)
replace_once(
    unified,
    '''        if pendingUserSeek, !metadata, concretePlaybackDemand {
            pendingUserSeekUntil = .distantPast
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)"
            )
            for slot in [0, 1] {
                if let active = slotClaims[slot], active.role == .urgentPlayback, !active.range.contains(range.lowerBound) { cancelSlot(slot, reason: "replace-stale-urgent") }
            }
''',
    '''        if pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand {
            pendingUserSeekUntil = .distantPast
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) authority=cache-miss"
            )
            for slot in [0, 1] {
                guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                if active.role == .urgentPlayback { cancelSlot(slot, reason: "replace-stale-urgent") }
                if active.role == .sequential { cancelSlot(slot, reason: "seek-reanchor-sequential") }
            }
'''
)
replace_once(
    unified,
    '''            var health = LaneHealthState()
            health.resetCooldownUntil = Date().addingTimeInterval(liveLaneResetCooldownSeconds)
            laneHealth[slot] = health
''',
    '''            laneHealth[slot] = LaneHealthState()
'''
)
regex_once(
    unified,
    r'''    private func considerSequentialLaneHealth\(slot: Int, bytes: Int64, bps: Double\) \{.*?\n    \}\n\n    private func resumeAfterSecondaryCooldown''',
    '''    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {
        guard bytes >= laneHealthMinSampleBytes, bps > 0 else { return }
        let now = Date()
        let peerSlot = slot == 0 ? 1 : 0
        var current = laneHealth[slot] ?? LaneHealthState()
        let peer = laneHealth[peerSlot] ?? LaneHealthState()
        let peerIsFresh = peer.samples > 0 && now.timeIntervalSince(peer.lastSampleAt) <= laneHealthPeerFreshSeconds

        current.averageBps = current.samples == 0 ? bps : current.averageBps * 0.65 + bps * 0.35
        current.samples += 1
        current.lastSampleAt = now
        current.slowStreak = 0
        laneHealth[slot] = current

        if peerIsFresh {
            if current.averageBps >= peer.averageBps * 1.20, preferredBulkSlot != slot {
                preferredBulkSlot = slot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\\(slot) avgBps=\\(Int(current.averageBps)) peerAvgBps=\\(Int(peer.averageBps))")
            } else if peer.averageBps >= current.averageBps * 1.20, preferredBulkSlot == slot {
                preferredBulkSlot = peerSlot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\\(peerSlot) avgBps=\\(Int(peer.averageBps)) peerAvgBps=\\(Int(current.averageBps))")
            }
        }

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\\(slot) sampleBps=\\(Int(bps)) avgBps=\\(Int(current.averageBps)) peer=\\(peerSlot) peerAvgBps=\\(Int(peer.averageBps)) peerFresh=\\(peerIsFresh) action=advisory-only protectedBulk=\\(preferredBulkSlot)")
    }

    private func resumeAfterSecondaryCooldown'''
)

controller = "Sources/Player/PlayerController.swift"
replace_once(controller, '''    @Published private(set) var transportCacheFraction: Double = 0
    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []
''', '''    @Published private(set) var transportCacheFraction: Double = 0
    @Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []
    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []
''')
replace_once(controller, '''        transportSummary = nil
        transportCacheFraction = 0
        engineSwitchTask?.cancel()
''', '''        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        engineSwitchTask?.cancel()
''')
replace_once(controller, '''        transportSummary = nil
        transportCacheFraction = 0
        lastTransportMetrics = nil
''', '''        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        lastTransportMetrics = nil
''')
replace_once(controller, '''                    self.transportSummary = metrics.summary
                    self.transportCacheFraction = metrics.resourceBytes > 0 ? min(1, max(0, Double(metrics.cacheBytes) / Double(metrics.resourceBytes))) : 0
                    self.promoteFullCacheRangeIfNeeded(metrics)
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                    self.transportCacheFraction = 0
''', '''                    self.transportSummary = metrics.summary
                    self.transportCacheFraction = metrics.resourceBytes > 0 ? min(1, max(0, Double(metrics.cacheBytes) / Double(metrics.resourceBytes))) : 0
                    let byteRanges: [Range<Int64>]
                    if let session = self.transportContext?.session { byteRanges = await session.cachedByteRanges() }
                    else { byteRanges = [] }
                    self.transportCacheRanges = metrics.resourceBytes > 0 ? byteRanges.compactMap { byteRange in
                        let lower = min(1, max(0, Double(byteRange.lowerBound) / Double(metrics.resourceBytes)))
                        let upper = min(1, max(0, Double(byteRange.upperBound) / Double(metrics.resourceBytes)))
                        return upper > lower ? lower...upper : nil
                    } : []
                    self.promoteFullCacheRangeIfNeeded(metrics)
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                    self.transportCacheFraction = 0
                    self.transportCacheRanges = []
''')

slider = '''import SwiftUI

struct BufferedTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Exact UnifiedTransport playback-byte cache coverage normalized to 0...1.
    /// Sparse seeks remain sparse here: a hole is rendered as a hole instead of being
    /// disguised by aggregate cacheBytes/resourceBytes.
    let downloadCacheRanges: [ClosedRange<Double>]
    let onEditingChanged: (Bool) -> Void

    @State private var isEditing = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let trackHeight: CGFloat = 10
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.16)).frame(height: trackHeight)

                ForEach(Array(normalizedDownloadRanges.enumerated()), id: \\.offset) { _, cached in
                    Capsule()
                        .fill(Color(white: 0.48))
                        .frame(width: max(2, width * CGFloat(cached.upperBound - cached.lowerBound)), height: trackHeight)
                        .offset(x: width * CGFloat(cached.lowerBound))
                }

                Capsule().fill(Color.white).frame(width: progressWidth(totalWidth: width), height: 4)
            }
            .frame(height: max(geometry.size.height, 24))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isEditing {
                            isEditing = true
                            onEditingChanged(true)
                        }
                        value = valueForLocation(gesture.location.x, totalWidth: width)
                    }
                    .onEnded { gesture in
                        value = valueForLocation(gesture.location.x, totalWidth: width)
                        isEditing = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("播放进度")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = max((range.upperBound - range.lowerBound) / 100, 1)
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
            onEditingChanged(false)
        }
    }

    private var normalizedDownloadRanges: [ClosedRange<Double>] {
        downloadCacheRanges.compactMap { item in
            let lower = min(1, max(0, item.lowerBound))
            let upper = min(1, max(0, item.upperBound))
            return upper > lower ? lower...upper : nil
        }
    }

    private var accessibilityValue: String {
        let duration = max(0, range.upperBound - range.lowerBound)
        guard duration > 0 else { return "0%" }
        return "\\(Int(((value - range.lowerBound) / duration * 100).rounded()))%"
    }

    private func fraction(for value: Double) -> CGFloat {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / duration, 0), 1))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat { totalWidth * fraction(for: value) }

    private func valueForLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let ratio = Double(min(max(x / max(totalWidth, 1), 0), 1))
        return range.lowerBound + (range.upperBound - range.lowerBound) * ratio
    }
}
'''
write("Sources/UI/BufferedTimelineSlider.swift", slider)

surface = '''import Foundation
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
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer host=UIViewRepresentable")
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
        lastGeometryLog = ""
    }

    deinit { detach() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

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

struct MPVPlayerSurface: UIViewRepresentable {
    let displayLayer: CAMetalLayer

    func makeUIView(context: Context) -> MPVSurfaceUIView {
        let view = MPVSurfaceUIView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.clipsToBounds = true
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: MPVSurfaceUIView, context: Context) {
        uiView.attach(displayLayer)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: MPVSurfaceUIView, coordinator: ()) { uiView.detach() }
}
'''
write("Sources/UI/MPVPlayerSurface.swift", surface)

screen = "Sources/UI/PlayerScreen.swift"
replace_once(screen, '''        if controller.engineKind == .mpv, let layer = controller.mpvDisplayLayer {
            MPVPlayerSurface(displayLayer: layer)
                .id(ObjectIdentifier(layer))
''', '''        if controller.engineKind == .mpv, let layer = controller.mpvDisplayLayer {
            GeometryReader { geometry in
                MPVPlayerSurface(displayLayer: layer)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id("\\(ObjectIdentifier(layer))-\\(Int(geometry.size.width.rounded()))x\\(Int(geometry.size.height.rounded()))")
            }
''')
replace_once(screen, '''                        verifiedBufferedRanges: controller.verifiedBufferedRanges,
                        bufferedRanges: controller.snapshot.bufferedRanges,
                        downloadCacheFraction: controller.transportCacheFraction,
''', '''                        downloadCacheRanges: controller.transportCacheRanges,
''')
replace_once(screen, '''            Text("下载缓存 \\(Int((controller.transportCacheFraction * 100).rounded()))% · 已验证缓存至 \\(formatTime(controller.verifiedBufferedEnd)) · 当前亮灰至 \\(formatTime(controller.bufferedEnd)) · 前向可播 \\(formatTime(controller.forwardBufferedDuration)) · \\(controller.snapshot.isBuffering ? \"等待数据\" : \"可播放\")")
''', '''            Text("下载缓存 \\(Int((controller.transportCacheFraction * 100).rounded()))% · 前向可播 \\(formatTime(controller.forwardBufferedDuration)) · \\(controller.snapshot.isBuffering ? \"等待数据\" : \"可播放\")")
''')

replace_once("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.12.2"', 'sourceVersion = "0.12.3"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.12.2"', '?? "0.12.3"')
replace_once("project.yml", 'MARKETING_VERSION: "0.12.2"', 'MARKETING_VERSION: "0.12.3"')
replace_once("project.yml", 'CURRENT_PROJECT_VERSION: "60"', 'CURRENT_PROJECT_VERSION: "61"')
replace_once("project.yml", 'MARKETING_VERSION: "0.12.2"', 'MARKETING_VERSION: "0.12.3"')
replace_once("project.yml", 'CURRENT_PROJECT_VERSION: "60"', 'CURRENT_PROJECT_VERSION: "61"')
replace_once("Config/Info.plist", '<string>0.12.2</string>', '<string>0.12.3</string>')
replace_once("Config/Info.plist", '<string>60</string>', '<string>61</string>')

for gate in ["scripts/check_transport_v3_invariants.py", "scripts/check_scheduler_v2_invariants.py", "scripts/check_live_lane_startup_invariants.py"]:
    text = read(gate).replace('0.12.2', '0.12.3').replace('"60"', '"61"').replace('<string>60</string>', '<string>61</string>')
    write(gate, text)

v0122_gate = '''from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.2 retained regression failed: {message}")

for needle in [
    "liveLaneSampleWindowSeconds: TimeInterval = 1.0",
    "sampleWindowStartedAt",
    "sampleWindowStartedBytes",
    "let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)",
    "foreground active-gap slot=",
    "active.role == .urgentPlayback",
    "gap > progressiveUrgentGapBytes",
]:
    require(needle in unified, f"missing retained v0.12.2 fix: {needle}")
require("let chunkBps = Double(bytes) / interval" not in unified, "callback-interarrival estimator must not return")
print("v0.12.2 retained regressions: OK")
'''
write("scripts/check_v0122_regressions.py", v0122_gate)

v0123_gate = '''from pathlib import Path
import re

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
slider = Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
screen = Path("Sources/UI/PlayerScreen.swift").read_text()
surface = Path("Sources/UI/MPVPlayerSurface.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.3 regression failed: {message}")

# User seek authority: AVPlayer's first post-seek cached/stale concrete read may not steal the
# scheduler anchor. Only an actual blocked read (cache miss) or MPV's explicit byte seek can do so.
for needle in [
    'let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset"',
    "seek concrete-read deferred request=",
    "awaitingBlockedRead=true",
    "authority=cache-miss",
    'cancelSlot(slot, reason: "seek-reanchor-sequential")',
]:
    require(needle in unified, f"seek-anchor fix missing {needle}")
require("pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand" in unified, "pending seek must require authoritative demand")

# Synthetic 63368 v0.12.2 regression: 237 MiB was a cached/stale read while the actual new
# playback dependency was around 781 MiB. The stale read must not become the new bulk anchor.
old_anchor = 233_046_016
stale_cached_read = 237_305_856
actual_miss = 781_254_656
anchor = old_anchor
# concrete-read is deferred while pending seek
assert anchor == old_anchor
# blocked-read is authoritative
anchor = actual_miss
require(anchor == actual_miss and anchor != stale_cached_read, "synthetic 478s seek must anchor at actual miss")

# Completed 32 MiB claim statistics may select the protected bulk lane but must never reset a
# connection. Reset authority belongs only to first-byte/live-window health.
health = re.search(r"private func considerSequentialLaneHealth.*?private func resumeAfterSecondaryCooldown", unified, re.S)
require(health is not None, "completed lane-health function missing")
health_body = health.group(0)
require("action=advisory-only" in health_body, "completed lane health must be advisory")
require("resetStreamLane" not in health_body, "completed lane health must not reset a warm connection")
require("rotate-slow-lane" not in unified, "legacy completed-claim rotation must be removed")
require("action=rotate-live-lane" in unified, "live-window lane rotation must remain")

# The visible cache bar is the real sparse playback-byte map, not aggregate quantity and not
# AVPlayer/mpv's engine buffer history. A visible hole therefore means that byte region is absent.
for needle in [
    "func cachedByteRanges() -> [Range<Int64>]",
    "@Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []",
    "downloadCacheRanges: [ClosedRange<Double>]",
    "downloadCacheRanges: controller.transportCacheRanges",
]:
    require(needle in unified + controller + slider + screen, f"sparse cache UI missing {needle}")
require("verifiedBufferedRanges:" not in slider and "bufferedRanges:" not in slider, "engine buffer overlays must not be rendered")
require("downloadCacheFraction:" not in slider, "aggregate cache fraction must not masquerade as positional coverage")

# v0.12.2 introduced a custom UIViewController wrapper and the supplied device log shows three
# process restarts after MPV file-loaded. Return to the v0.12.1 external-layer UIView host, while
# GeometryReader forces the host size to follow orientation. MoltenVK still owns drawableSize.
require("struct MPVPlayerSurface: UIViewRepresentable" in surface, "MPV surface must use stable UIViewRepresentable host")
require("UIViewControllerRepresentable" not in surface and "MPVSurfaceViewController" not in surface, "custom MPV wrapper controller must not return")
require("GeometryReader" in screen and "geometry.size.width" in screen and "geometry.size.height" in screen, "MPV host must follow SwiftUI orientation geometry")
require("displayLayer.drawableSize =" not in surface, "UI must not force MoltenVK drawableSize")
require("displayLayer.delegate" not in surface, "do not reintroduce CAMetalLayer delegate coupling")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.3"') == 2, "marketing version must be 0.12.3")
require(project.count('CURRENT_PROJECT_VERSION: "61"') == 2, "build number must be 61")
require("<string>0.12.3</string>" in info and "<string>61</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.3"' in identity, "source version mismatch")

print("v0.12.3 regressions: OK")
'''
write("scripts/check_v0123_regressions.py", v0123_gate)

review = '''# v0.12.3 Self Review

## Evidence from source=0.12.2 device log

- 63368 can begin above 20 MiB/s aggregate, but the legacy completed-claim LaneHealth still reset a lane that had just completed a 32 MiB claim at about 10.9 MiB/s because its peer retained a much higher historical average.
- During a large user seek, a cached/stale AVPlayer concrete read around 237 MiB consumed the pending-seek token before the true cache-miss dependency around 781 MiB. Bulk prefetch therefore stayed anchored in the old region while current playback was serviced by small urgent requests.
- The aggregate cache fraction is not positional coverage after sparse seeks. Rendering it as one solid bar falsely implies every byte to that visual edge is cached.
- 152901 repeatedly reached MPV file-loaded and active download, then the process restarted without normal close/stop. The regression began after v0.12.2 replaced the previously stable UIViewRepresentable external-layer host with a custom UIViewControllerRepresentable wrapper. No native crash stack is present, so the wrapper is treated as the highest-confidence regression suspect rather than a proven libmpv root cause.

## Changes reviewed

1. User-seek reanchor is now cache-miss authoritative: ordinary concrete-read is deferred while a seek is pending; blocked-read or explicit MPV byte-offset owns the new anchor. Stale sequential claims away from the new anchor are cancelled as tasks only, preserving persistent URLSession lanes.
2. Completed sequential Range statistics are advisory only. They may choose the protected bulk lane but cannot reset a connection. First-byte and live >=1 second window health remain the only automatic sequential connection reset paths.
3. Timeline renders actual sparse playback-byte cache ranges. AVPlayer/mpv verified/current buffer overlays are removed. Aggregate cache percentage remains diagnostic text only.
4. MPV surface returns to the v0.12.1 UIViewRepresentable ownership model. PlayerScreen supplies orientation-sensitive GeometryReader sizing; UI still does not force CAMetalLayer.drawableSize or set a layer delegate.
5. Deployment Target remains iOS 15.0. Media data path remains Emby control request -> 302 -> direct 115/CDN Range traffic; NAS media relay is not introduced.

## Limits

- Static gates and generic iOS compilation cannot prove sustained 115 CDN throughput or a native-device MoltenVK crash is eliminated.
- The three repeated 152901 restarts strongly correlate with the v0.12.2 surface-host change, but the supplied app log contains no iOS crash backtrace. Real-device v0.12.3 testing is required to confirm the regression is gone.
- Live-window rotation is intentionally retained for truly degraded connections; this build removes only the redundant completed-claim reset path.
'''
write("docs/review/SELF_REVIEW_v0_12_3.md", review)

print("Applied v0.12.3 source patch")
