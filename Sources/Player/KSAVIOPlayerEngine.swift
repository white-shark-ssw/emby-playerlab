import Foundation
import KSPlayer
import UIKit

final class KSAVIOPlayerEngine: NSObject, PlayerEngine {
    let kind: PlayerEngineKind = .ksAVIO
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    private let source: ResolvedPlaybackSource
    private let client: EmbyAPIClient
    private let configuration: MediaTransportConfiguration
    private var player: KSMEPlayer?
    private var session: DownloadFirstMediaSession?
    private var coordinator: SparseAVIOReadCoordinator?
    private var context: KSPlayerSparseAVIOContext?
    private var options: KSAVIOOptions?
    private var prepareTask: Task<Void, Never>?
    private var stateTimer: Timer?
    private var shouldPlay = false
    private var preferredForwardBuffer: Double = 90
    private var lastURL: URL?
    private var lastHeaders: [String: String] = [:]
    private var initialSeek: Double?
    private var initialSeekCommitted = false
    private var generation = 0

    var playerView: UIView? { player?.view }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        self.source = source
        self.client = client
        self.configuration = configuration
        super.init()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopCurrentPlayback()
        generation += 1
        let currentGeneration = generation
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        initialSeek = startPosition > 0 ? startPosition : nil
        initialSeekCommitted = false

        prepareTask = Task { [weak self] in
            guard let self else { return }
            let session = DownloadFirstMediaSession(source: source, client: client, configuration: configuration, demandMode: .directAVIO)
            do {
                let resource = try await session.resolve()
                guard !Task.isCancelled, currentGeneration == self.generation else { await session.stop(); return }
                let coordinator = SparseAVIOReadCoordinator(session: session, contentLength: resource.contentLength)
                let context = KSPlayerSparseAVIOContext(coordinator: coordinator)
                let options = KSAVIOOptions(context: context)
                let ext = source.mediaSource.normalizedContainer.isEmpty ? "mp4" : source.mediaSource.normalizedContainer
                let virtualURL = URL(string: "embyavio://local/item.\(ext)")!

                await MainActor.run {
                    guard currentGeneration == self.generation else { coordinator.close(); return }
                    self.session = session
                    self.coordinator = coordinator
                    self.context = context
                    self.options = options
                    let player = KSMEPlayer(url: virtualURL, options: options)
                    player.view?.backgroundColor = .black
                    player.view?.contentMode = .scaleAspectFit
                    self.player = player
                    self.startStateTimer()
                    player.prepareToPlay()
                    if self.shouldPlay { player.play() }
                    DiagnosticsLogger.shared.log("KSAVIO", "prepared item=\(self.source.itemId) bytes=\(resource.contentLength) directAVIO=true buffer=262144")
                }
            } catch {
                await MainActor.run {
                    guard currentGeneration == self.generation else { return }
                    self.emitError(error.localizedDescription)
                }
            }
        }
    }

    func play() {
        shouldPlay = true
        player?.play()
    }

    func pause() {
        shouldPlay = false
        player?.pause()
    }

    func seek(to seconds: Double, direction: SeekDirection) {
        guard let player else { initialSeek = seconds; return }
        let target = max(0, seconds)
        let requestedAt = Date().timeIntervalSince1970
        coordinator?.armUserSeek()
        player.seek(time: target) { [weak self, weak player] success in
            guard let self else { return }
            let actual = player?.currentPlaybackTime
            let latency = (Date().timeIntervalSince1970 - requestedAt) * 1_000
            self.onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: actual, bufferHit: success && latency < 150, completionLatencyMs: latency, measurement: "KSPlayer seek callback"))
        }
    }

    func reload(at seconds: Double) {
        guard let url = lastURL else { return }
        prepare(url: url, headers: lastHeaders, preferredForwardBuffer: preferredForwardBuffer, startPosition: seconds)
        if shouldPlay { play() }
    }

    func recoverStall(position: Double, duration: Double) {
        coordinator?.recoverStall(position: position, duration: duration)
    }

    func transportMetrics() async -> TransportMetricsSnapshot? { await coordinator?.metrics() }

    func stop() {
        shouldPlay = false
        generation += 1
        prepareTask?.cancel()
        prepareTask = nil
        stopCurrentPlayback()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func stopCurrentPlayback() {
        stateTimer?.invalidate()
        stateTimer = nil
        player?.shutdown()
        player?.view?.removeFromSuperview()
        player = nil
        coordinator?.close()
        coordinator = nil
        context = nil
        options = nil
        session = nil
    }

    private func startStateTimer() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pollState() }
        if let stateTimer { RunLoop.main.add(stateTimer, forMode: .common) }
    }

    private func pollState() {
        guard let player else { return }
        if !initialSeekCommitted, player.isReadyToPlay, let target = initialSeek {
            initialSeekCommitted = true
            initialSeek = nil
            seek(to: target, direction: .absolute)
        }
        let position = sane(player.currentPlaybackTime)
        let duration = sane(player.duration)
        let playable = max(position, sane(player.playableTime))
        let buffering = player.loadState == .loading
        let snapshot = PlayerSnapshot(
            position: position,
            duration: duration,
            bufferedRanges: playable > position ? [position...playable] : [],
            isPlaying: player.isPlaying,
            isBuffering: buffering,
            waitingReason: buffering ? "KSPlayer 等待 AVIO 数据" : nil,
            errorMessage: nil,
            didReachEnd: player.playbackState == .finished
        )
        onSnapshot?(snapshot)
    }

    private func emitError(_ message: String) {
        onSnapshot?(PlayerSnapshot(errorMessage: message))
        DiagnosticsLogger.shared.log("KSAVIO", "prepare failed: \(message)")
    }

    private func sane(_ value: Double) -> Double { value.isFinite && value >= 0 ? value : 0 }
}
