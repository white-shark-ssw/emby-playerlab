from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

old = '''        let requested = min(length, Int(resolved.contentLength - offset))
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }
'''
new = '''        let requested = min(length, Int(resolved.contentLength - offset))
        let concreteRange = offset..<min(resolved.contentLength, offset + Int64(requested))
        acceptRealDemand(concreteRange, resource: resolved, reason: "concrete-read")
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }
'''
if old not in text:
    raise SystemExit("read concrete-demand target not found")
text = text.replace(old, new, 1)

old = '''        let concretePlaybackDemand = !metadata && (reason == "blocked-read" || reason == "byte-offset")
        let speculativeLargeRange = reason.hasPrefix("range-demand") && Int64(range.count) > blockBytes * 2
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }

        // AVAssetResourceLoader often emits a very large speculative range immediately after a seek.
        // It is not necessarily the byte position that AVFoundation will actually block on. Keep the
        // user-seek token alive until the concrete read/byte-offset demand arrives; otherwise the
        // scheduler can anchor hundreds of MiB away from the frame AVPlayer is really waiting for.
        if pendingUserSeek, !metadata, speculativeLargeRange {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteDemand=true anchor=\\(playbackAnchor)"
            )
            return
        }

        if pendingUserSeek, !metadata {
'''
new = '''        let concretePlaybackDemand = !metadata && (reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset")
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }

        // AVFoundation may emit stale/cached range requests from the pre-seek timeline while a seek is
        // still settling. Only the byte offset actually consumed by read(), or MPV's explicit byte seek,
        // may consume the pending seek token. This mirrors a logical-position reader: requested ranges
        // are hints, actual reads are authoritative.
        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) awaitingConcreteRead=true anchor=\\(playbackAnchor)"
            )
            return
        }

        if pendingUserSeek, !metadata, concretePlaybackDemand {
'''
if old not in text:
    raise SystemExit("seek authoritative-demand target not found")
text = text.replace(old, new, 1)

old = '''    private func preloadWindowBytes() -> Int64 {
        if NetworkPathMonitor.shared.isCellular {
            // Cellular remains explicitly opt-in for background prefetch.
            return configuration.ktvPreloadOnCellular ? max(0, configuration.cellularPreloadBytes) : 0
        }
'''
new = '''    private func preloadWindowBytes() -> Int64 {
        if NetworkPathMonitor.shared.isCellular {
            // Unified Transport v3 uses its own configured cellular byte window. A non-zero cellular
            // budget means prefetch is enabled; zero remains the explicit opt-out. Do not inherit the
            // legacy KTV proxy switch, otherwise v3 becomes urgent-only and can go idle after a seek.
            return max(0, configuration.cellularPreloadBytes)
        }
'''
if old not in text:
    raise SystemExit("cellular preload target not found")
text = text.replace(old, new, 1)

path.write_text(text)
print("v0.11.1 seek stall fix applied")
