import Foundation
import QuartzCore

/// MPV backed by the same KTVHTTPCache localhost proxy used by native AVPlayer.
/// libmpv never receives Emby/115 credentials or the final CDN URL directly in this mode.
final class KTVMPVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .mpv
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    var displayLayer: CAMetalLayer { underlying.displayLayer }

    private let source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let underlying = MPVPlayerEngine(sharedTransportSession: nil)
    private var cacheSession: KTVCachePlaybackSession?
    private var lastSnapshot = PlayerSnapshot()

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        bindUnderlying()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        do {
            let session = cacheSession ?? (try KTVCachePlaybackSession(source: source, configuration: configuration, openWarmupEnabled: false))
            cacheSession = session
            DiagnosticsLogger.shared.log("KTVMPV", "prepare proxyHost=\(session.proxyURL.host ?? "localhost") proxyPort=\(session.proxyURL.port ?? 0) transport=KTVProxyTransportV2")
            session.prepareForPlayback { [weak self, weak session] in
                guard let self, let session, self.cacheSession === session else { return }
                self.underlying.prepare(url: session.proxyURL, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
            }
        } catch {
            DiagnosticsLogger.shared.log("KTVMPV", "proxy preparation failed; direct MPV fallback without forwarded auth headers error=\(error.localizedDescription)")
            underlying.prepare(url: url, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
        }
    }

    func play() { underlying.play() }
    func pause() { underlying.pause() }

    func seek(to seconds: Double, direction: SeekDirection) {
        let duration = lastSnapshot.duration > 0 ? lastSnapshot.duration : source.mediaSource.durationSeconds ?? 0
        cacheSession?.prioritizeSeek(position: seconds, duration: duration)
        underlying.seek(to: seconds, direction: direction)
    }

    func reload(at seconds: Double) {
        cacheSession?.ensurePreloadActive(reason: "MPV same-engine reload")
        underlying.reload(at: seconds)
    }

    func recoverStall(position: Double, duration: Double) {
        cacheSession?.ensurePreloadActive(reason: "MPV stall at \(String(format: "%.2f", position))")
    }

    func transportMetrics() async -> TransportMetricsSnapshot? { cacheSession?.metrics() }

    func stop() {
        underlying.onSnapshot = nil
        underlying.onSeekCompleted = nil
        underlying.stop()
        cacheSession?.stop()
        cacheSession = nil
    }

    private func bindUnderlying() {
        underlying.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.lastSnapshot = snapshot
            self.cacheSession?.updatePlayback(position: snapshot.position, duration: snapshot.duration)
            if snapshot.position > 0.25 {
                let bufferedEnd = snapshot.bufferedRanges.filter { $0.lowerBound <= snapshot.position + 0.05 && $0.upperBound >= snapshot.position - 0.05 }.map(\.upperBound).max() ?? snapshot.position
                let forward = max(0, bufferedEnd - snapshot.position)
                self.cacheSession?.updatePlaybackDemand(position: snapshot.position, duration: snapshot.duration, forwardPlayable: forward, isBuffering: snapshot.isBuffering)
            }
            self.onSnapshot?(snapshot)
        }
        underlying.onSeekCompleted = { [weak self] result in self?.onSeekCompleted?(result) }
    }
}
