import AVFoundation
import Foundation

final class KTVAVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .ktvAVPlayer
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    let player: AVPlayer

    private let source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let underlying: AVPlayerEngine
    private var cacheSession: KTVCachePlaybackSession?
    private var lastSnapshot = PlayerSnapshot()

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration, cacheSession: KTVCachePlaybackSession? = nil) {
        self.source = source
        self.configuration = configuration
        self.cacheSession = cacheSession
        self.underlying = AVPlayerEngine(kind: .ktvAVPlayer)
        self.player = underlying.player
        bindUnderlying()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        do {
            let session: KTVCachePlaybackSession
            if let cacheSession { session = cacheSession } else { session = try KTVCachePlaybackSession(source: source, configuration: configuration) }
            cacheSession = session
            DiagnosticsLogger.shared.log("KTVPlayer", "prepare proxyHost=\(session.proxyURL.host ?? "localhost") proxyPort=\(session.proxyURL.port ?? 0)")
            session.prepareForPlayback { [weak self, weak session] in
                guard let self, let session, self.cacheSession === session else { return }
                DiagnosticsLogger.shared.log("KTVPlayer", "open warmup ready item=\(self.source.itemId)")
                self.underlying.prepare(
                    url: session.proxyURL,
                    headers: headers,
                    preferredForwardBuffer: preferredForwardBuffer,
                    startPosition: startPosition
                )
            }
        } catch {
            DiagnosticsLogger.shared.log("KTVPlayer", "proxy preparation failed, direct AVPlayer fallback error=\(error.localizedDescription)")
            underlying.prepare(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
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
        cacheSession?.ensurePreloadActive(reason: "same-engine reload")
        underlying.reload(at: seconds)
    }

    func recoverStall(position: Double, duration: Double) {
        cacheSession?.ensurePreloadActive(reason: "AVPlayer stall at \(String(format: "%.2f", position))")
        DiagnosticsLogger.shared.log("KTVPlayer", "stall keeps staged preload active position=\(position) duration=\(duration)")
    }

    func transportMetrics() async -> TransportMetricsSnapshot? { cacheSession?.metrics() }


    func takeCacheSessionForHandoff() -> KTVCachePlaybackSession? {
        let session = cacheSession
        cacheSession = nil
        if session != nil { DiagnosticsLogger.shared.log("KTVCache", "handoff AVPlayer -> FFmpeg item=\(source.itemId)") }
        return session
    }

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
        underlying.onConfirmedVideoFreeze = { [weak self] total in
            guard let self, total >= 2 else { return }
            MediaCompatibilityStore.markFFmpegRequired(itemId: self.source.itemId, reason: "confirmed-video-freeze-total-\(total)")
        }
    }
}
