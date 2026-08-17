from pathlib import Path

# Playback timeline: only engine-reported TIME ranges belong on the time axis.
p = Path("Sources/UI/BufferedTimelineSlider.swift")
s = p.read_text()
s = s.replace('''    /// Exact UnifiedTransport playback-byte cache coverage normalized to 0...1.
    /// Sparse seeks remain sparse here: a hole is rendered as a hole instead of being
    /// disguised by aggregate cacheBytes/resourceBytes.
    let downloadCacheRanges: [ClosedRange<Double>]
''', '''    /// Engine-reported playable TIME ranges. The slider is a time axis, so byte-space
    /// UnifiedTransport ranges must never be projected onto it by file-size ratio.
    let playableRanges: [ClosedRange<Double>]
''')
s = s.replace("normalizedDownloadRanges", "normalizedPlayableRanges")
s = s.replace('''    private var normalizedPlayableRanges: [ClosedRange<Double>] {
        downloadCacheRanges.compactMap { item in
            let lower = min(1, max(0, item.lowerBound))
            let upper = min(1, max(0, item.upperBound))
            return upper > lower ? lower...upper : nil
        }
    }
''', '''    private var normalizedPlayableRanges: [ClosedRange<Double>] {
        let duration = range.upperBound - range.lowerBound
        guard duration > 0 else { return [] }
        return playableRanges.compactMap { item in
            let clippedLower = max(range.lowerBound, item.lowerBound)
            let clippedUpper = min(range.upperBound, item.upperBound)
            guard clippedUpper > clippedLower else { return nil }
            let lower = min(1, max(0, (clippedLower - range.lowerBound) / duration))
            let upper = min(1, max(0, (clippedUpper - range.lowerBound) / duration))
            return upper > lower ? lower...upper : nil
        }
    }
''')
p.write_text(s)

p = Path("Sources/UI/PlayerScreen.swift")
s = p.read_text().replace("downloadCacheRanges: controller.transportCacheRanges,", "playableRanges: controller.snapshot.bufferedRanges,")
p.write_text(s)

# Cached seek: update logical playback head, but keep warm sequential CDN lanes intact.
p = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
s = p.read_text()
s = s.replace('''        if concretePlaybackDemand, authoritativeSeekDemand, !resumeHistoricalDependency {
            lastBlockingPlaybackDemand = range
            lastBlockingPlaybackDemandAt = Date()
        }
''', '''        if concretePlaybackDemand, authoritativeSeekDemand, !resumeHistoricalDependency, !cachedSeekRead {
            lastBlockingPlaybackDemand = range
            lastBlockingPlaybackDemandAt = Date()
        }
''')
s = s.replace("        // still settling. Only a cache-miss blocked read, or MPV's explicit byte seek, may consume the\n        // pending seek token. Ordinary concrete reads can be stale demux traffic from the old timeline.\n", "        // still settling. A cache miss, an explicit byte seek, or a sufficiently distant cached concrete\n        // read may consume the token. Cached authority updates the logical head without resetting bulk IO.\n")
old = '''        if pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand {
            pendingUserSeekUntil = .distantPast
            pendingUserSeekPosition = nil
            pendingUserSeekDuration = nil
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            initialResumeAnchorByte = nil
            initialResumeCandidateByte = nil
            initialResumeHistoryGuardUntil = .distantPast
            demandCoordinator.reset()
            playbackDemandSamples.removeAll()
            recordPlaybackDemand(offset: range.lowerBound)
            resetCacheWindowCenter(to: range.lowerBound, resource: resource, reason: "user-seek-real-demand")
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) authority=\(cachedSeekRead ? "cached-read" : "cache-miss")"
            )
            for slot in [0, 1] {
                guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                if active.role == .urgentPlayback { cancelSlot(slot, reason: "replace-stale-urgent") }
                if active.role == .sequential { cancelSlot(slot, reason: "seek-reanchor-sequential") }
            }
        }
'''
new = '''        if pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand {
            pendingUserSeekUntil = .distantPast
            pendingUserSeekPosition = nil
            pendingUserSeekDuration = nil
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            initialResumeAnchorByte = nil
            initialResumeCandidateByte = nil
            initialResumeHistoryGuardUntil = .distantPast
            demandCoordinator.reset()
            playbackDemandSamples.removeAll()
            recordPlaybackDemand(offset: range.lowerBound)
            reanchored = true

            if cachedSeekRead {
                // A seek into bytes already present in the sparse store must not tear down the warmed
                // 115/CDN sequential lanes. Keep cacheWindowCenter and bulk claims stable; subsequent
                // real playback reads can naturally promote the center if the new head truly moves away.
                DiagnosticsLogger.shared.log(
                    "UnifiedAnchor",
                    "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) authority=cached-read action=keep-cache-window center=\(cacheWindowCenter)"
                )
            } else {
                resetCacheWindowCenter(to: range.lowerBound, resource: resource, reason: "user-seek-real-demand")
                DiagnosticsLogger.shared.log(
                    "UnifiedAnchor",
                    "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) authority=cache-miss action=reanchor-cache-window"
                )
                for slot in [0, 1] {
                    guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                    if active.role == .urgentPlayback { cancelSlot(slot, reason: "replace-stale-urgent") }
                    if active.role == .sequential { cancelSlot(slot, reason: "seek-reanchor-sequential") }
                }
            }
        }
'''
if old not in s:
    raise SystemExit("transport seek block not found")
s = s.replace(old, new)
p.write_text(s)

# Update the regression contract so byte-space cache coverage can never masquerade as time coverage.
p = Path("scripts/check_v0123_regressions.py")
s = p.read_text()
s = s.replace('''for needle in [
    'let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset"',
    "seek concrete-read deferred request=",
    "awaitingBlockedRead=true",
    "authority=cache-miss",
    'cancelSlot(slot, reason: "seek-reanchor-sequential")',
]:
    require(needle in unified, f"seek-anchor fix missing {needle}")
require("pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand" in unified, "pending seek must require authoritative demand")
''', '''for needle in [
    'let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset" || cachedSeekRead',
    "seek concrete-read deferred request=",
    "awaitingBlockedRead=true",
    "authority=cache-miss action=reanchor-cache-window",
    "authority=cached-read action=keep-cache-window",
    'cancelSlot(slot, reason: "seek-reanchor-sequential")',
]:
    require(needle in unified, f"seek-anchor fix missing {needle}")
require("pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand" in unified, "pending seek must require authoritative demand")
require("!cachedSeekRead" in unified, "cached seek must not be recorded as a blocking network demand")
''')
s = s.replace('''for needle in [
    "func cachedByteRanges() -> [Range<Int64>]",
    "@Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []",
    "downloadCacheRanges: [ClosedRange<Double>]",
    "downloadCacheRanges: controller.transportCacheRanges",
]:
    require(needle in unified + controller + slider + screen, f"sparse cache UI missing {needle}")
require("verifiedBufferedRanges:" not in slider and "bufferedRanges:" not in slider, "engine buffer overlays must not be rendered")
require("downloadCacheFraction:" not in slider, "aggregate cache fraction must not masquerade as positional coverage")
''', '''require("func cachedByteRanges() -> [Range<Int64>]" in unified, "transport sparse byte diagnostics must remain available")
require("@Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []" in controller, "transport byte diagnostics must remain available")
require("playableRanges: [ClosedRange<Double>]" in slider, "timeline must accept engine playable time ranges")
require("playableRanges: controller.snapshot.bufferedRanges" in screen, "timeline must render engine-reported time coverage")
require("downloadCacheRanges" not in slider + screen, "byte-space cache ranges must not be projected onto the time axis")
require("controller.transportCacheRanges" not in screen, "playback timeline must not use normalized byte positions")
require("downloadCacheFraction:" not in slider, "aggregate cache fraction must not masquerade as positional coverage")
''')
p.write_text(s)

p = Path("project.mdklab.yml")
s = p.read_text().replace("MDK Lab 0.13.4 rapid-seek recovery baseline", "MDK Lab 0.13.5 truthful-buffer and latest-wins seek baseline").replace('MARKETING_VERSION: "0.13.4"', 'MARKETING_VERSION: "0.13.5"').replace('CURRENT_PROJECT_VERSION: "71"', 'CURRENT_PROJECT_VERSION: "72"')
p.write_text(s)

for temporary in ["scripts/mdk0135-ui-transport.patch", "scripts/mdk0135-support.patch"]:
    try:
        Path(temporary).unlink()
    except OSError:
        pass
Path(__file__).unlink()
