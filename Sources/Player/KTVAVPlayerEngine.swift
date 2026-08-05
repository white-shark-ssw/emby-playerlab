import AVFoundation
import Foundation

final class KTVAVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .ktvAVPlayer
    var onSnapshot: ((PlayerSnapshot) -> Void)? {
        didSet { underlying.onSnapshot = onSnapshot }
    }
    var onSeekCompleted: ((SeekResult) -> Void)? {
        didSet { underlying.onSeekCompleted = onSeekCompleted }
    }

    let player: AVPlayer

    private let source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let underlying: AVPlayerEngine
    private var cacheSession: KTVCachePlaybackSession?

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        self.underlying = AVPlayerEngine(kind: .avPlayer)
        self.player = underlying.player
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        do {
            let session = try KTVCachePlaybackSession(source: source, configuration: configuration)
            cacheSession = session
            DiagnosticsLogger.shared.log("KTVPlayer", "prepare proxyHost=\(session.proxyURL.host ?? "localhost") proxyPort=\(session.proxyURL.port ?? 0)")
            underlying.prepare(
                url: session.proxyURL,
                headers: headers,
                preferredForwardBuffer: preferredForwardBuffer,
                startPosition: startPosition
            )
        } catch {
            DiagnosticsLogger.shared.log("KTVPlayer", "proxy preparation failed, direct AVPlayer fallback error=\(error.localizedDescription)")
            underlying.prepare(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
        }
    }

    func play() { underlying.play() }
    func pause() { underlying.pause() }
    func seek(to seconds: Double, direction: SeekDirection) { underlying.seek(to: seconds, direction: direction) }
    func reload(at seconds: Double) { underlying.reload(at: seconds) }

    func recoverStall(position: Double, duration: Double) {
        cacheSession?.ensurePreloadActive(reason: "stall at \(String(format: "%.2f", position))")
        DiagnosticsLogger.shared.log("KTVPlayer", "stall waits for cache position=\(position) duration=\(duration)")
    }

    func transportMetrics() async -> TransportMetricsSnapshot? { cacheSession?.metrics() }

    func stop() {
        underlying.onSnapshot = nil
        underlying.onSeekCompleted = nil
        underlying.stop()
        cacheSession?.stop()
        cacheSession = nil
    }
}
