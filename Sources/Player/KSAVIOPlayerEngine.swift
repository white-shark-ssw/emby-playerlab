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
    private let sharedTransportSession: MediaTransportSession?
    private var player: KSMEPlayer?
    private var session: MediaTransportSession?
    private var coordinator: SparseAVIOReadCoordinator?
    private var context: KSPlayerSparseAVIOContext?
    private var options: KSAVIOOptions?
    private var ktvOptions: KTVKSPlayerOptions?
    private var ktvCacheSession: KTVCachePlaybackSession?
    private var prepareTask: Task<Void, Never>?
    private var ktvStartupGuardTask: Task<Void, Never>?
    private var stateTimer: Timer?
    private var shouldPlay = false
    private var preferredForwardBuffer: Double = 90
    private var lastURL: URL?
    private var lastHeaders: [String: String] = [:]
    private var initialSeek: Double?
    private var initialSeekCommitted = false
    private var generation = 0

    var playerView: UIView? { player?.view }

    init(
        source: ResolvedPlaybackSource,
        client: EmbyAPIClient,
        configuration: MediaTransportConfiguration,
        sharedTransportSession: MediaTransportSession? = nil,
        ktvCacheSession: KTVCachePlaybackSession? = nil
    ) {
        self.source = source
        self.client = client
        self.configuration = configuration
        self.sharedTransportSession = sharedTransportSession
        self.ktvCacheSession = ktvCacheSession
        super.init()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        prepareTask?.cancel()
        prepareTask = nil
        ktvStartupGuardTask?.cancel()
        ktvStartupGuardTask = nil
        stopPlayerOnly()
        generation += 1
        let currentGeneration = generation
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        initialSeek = startPosition > 0 ? startPosition : nil
        initialSeekCommitted = false

        if configuration.strategy == .ktvHTTP {
            prepareKTVBacked(currentGeneration: currentGeneration)
        } else {
            prepareAVIOBacked(currentGeneration: currentGeneration)
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
        if let ktvCacheSession {
            let duration = max(source.mediaSource.durationSeconds ?? 0, player.duration)
            ktvCacheSession.prioritizeSeek(position: target, duration: duration)
        } else {
            coordinator?.armUserSeek()
        }
        player.seek(time: target) { [weak self, weak player] success in
            guard let self else { return }
            let actual = player?.currentPlaybackTime
            let latency = (Date().timeIntervalSince1970 - requestedAt) * 1_000
            self.onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: actual, bufferHit: success && latency < 150, completionLatencyMs: latency, measurement: self.ktvCacheSession != nil ? "KSPlayer KTV seek callback" : "KSPlayer seek callback"))
        }
    }

    func reload(at seconds: Double) {
        guard let url = lastURL else { return }
        prepare(url: url, headers: lastHeaders, preferredForwardBuffer: preferredForwardBuffer, startPosition: seconds)
        if shouldPlay { play() }
    }

    func recoverStall(position: Double, duration: Double) {
        if let ktvCacheSession {
            ktvCacheSession.ensurePreloadActive(reason: "KSPlayer stall at \(String(format: "%.2f", position))")
        } else {
            coordinator?.recoverStall(position: position, duration: duration)
        }
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        if let ktvCacheSession { return ktvCacheSession.metrics() }
        return await coordinator?.metrics()
    }

    func takeCacheSessionForHandoff() -> KTVCachePlaybackSession? {
        let session = ktvCacheSession
        ktvCacheSession = nil
        if session != nil { DiagnosticsLogger.shared.log("KTVCache", "handoff FFmpeg -> AVPlayer item=\(source.itemId)") }
        return session
    }

    func stop() {
        shouldPlay = false
        generation += 1
        prepareTask?.cancel()
        prepareTask = nil
        ktvStartupGuardTask?.cancel()
        ktvStartupGuardTask = nil
        stopPlayerOnly()
        ktvCacheSession?.stop()
        ktvCacheSession = nil
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func prepareKTVBacked(currentGeneration: Int) {
        do {
            let cacheSession = ktvCacheSession ?? (try KTVCachePlaybackSession(source: source, configuration: configuration))
            ktvCacheSession = cacheSession
            cacheSession.prepareForPlayback { [weak self, weak cacheSession] in
                guard let self, let cacheSession, currentGeneration == self.generation, self.ktvCacheSession === cacheSession else { return }
                let options = KTVKSPlayerOptions()
                options.preferredForwardBufferDuration = 2
                options.maxBufferDuration = 30
                options.isSecondOpen = true
                options.isAccurateSeek = false
                options.isSeekedAutoPlay = true
                options.hardwareDecode = true
                options.registerRemoteControll = false
                let player = KSMEPlayer(url: cacheSession.proxyURL, options: options)
                player.view?.backgroundColor = .black
                player.view?.contentMode = .scaleAspectFit
                self.ktvOptions = options
                self.player = player
                self.startStateTimer()
                player.prepareToPlay()
                if self.shouldPlay { player.play() }
                DiagnosticsLogger.shared.log("KSKTV", "prepared item=\(self.source.itemId) proxyPort=\(cacheSession.proxyURL.port ?? 0) transport=KTV-dual-lane")
                self.scheduleKTVStartupGuard(player: player, generation: currentGeneration)
            }
        } catch {
            DiagnosticsLogger.shared.log("KSKTV", "cache setup failed item=\(source.itemId) error=\(error.localizedDescription); fallback transport=AVIO")
            ktvCacheSession = nil
            prepareAVIOBacked(currentGeneration: currentGeneration)
        }
    }

    private func scheduleKTVStartupGuard(player: KSMEPlayer, generation: Int) {
        ktvStartupGuardTask?.cancel()
        ktvStartupGuardTask = Task { @MainActor [weak self, weak player] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, let player, !Task.isCancelled, generation == self.generation, self.player === player else { return }
            guard !player.isReadyToPlay, player.currentPlaybackTime < 0.5 else { self.ktvStartupGuardTask = nil; return }
            DiagnosticsLogger.shared.log("KSKTV", "startup timeout item=\(self.source.itemId); fallback transport=AVIO")
            self.ktvStartupGuardTask = nil
            self.stopPlayerOnly()
            self.ktvCacheSession?.stop()
            self.ktvCacheSession = nil
            self.prepareAVIOBacked(currentGeneration: generation)
        }
    }

    private func prepareAVIOBacked(currentGeneration: Int) {
        prepareTask = Task { [weak self] in
            guard let self else { return }
            let session = sharedTransportSession ?? MediaTransportSession(source: source, client: client, configuration: configuration.resourceLoaderProfile())
            do {
                let resource = try await session.resolve()
                guard !Task.isCancelled, currentGeneration == self.generation else { await session.stop(); return }
                let coordinator = SparseAVIOReadCoordinator(session: session, contentLength: resource.contentLength, stopSessionOnClose: self.sharedTransportSession == nil)
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
                    DiagnosticsLogger.shared.log("KSAVIO", "prepared item=\(self.source.itemId) bytes=\(resource.contentLength) sharedWindow=true buffer=262144")
                }
            } catch {
                await MainActor.run {
                    guard currentGeneration == self.generation else { return }
                    self.emitError(error.localizedDescription)
                }
            }
        }
    }

    private func stopPlayerOnly() {
        stateTimer?.invalidate()
        stateTimer = nil
        player?.shutdown()
        player?.view?.removeFromSuperview()
        player = nil
        coordinator?.close()
        coordinator = nil
        context = nil
        options = nil
        ktvOptions = nil
        session = nil
    }

    private func startStateTimer() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pollState() }
        if let stateTimer { RunLoop.main.add(stateTimer, forMode: .common) }
    }

    private func pollState() {
        guard let player else { return }
        if player.isReadyToPlay {
            ktvStartupGuardTask?.cancel()
            ktvStartupGuardTask = nil
        }
        if !initialSeekCommitted, player.isReadyToPlay, let target = initialSeek {
            initialSeekCommitted = true
            initialSeek = nil
            seek(to: target, direction: .absolute)
        }
        let position = sane(player.currentPlaybackTime)
        let duration = sane(player.duration)
        let playable = max(position, sane(player.playableTime))
        let buffering = player.loadState == .loading
        ktvCacheSession?.updatePlayback(position: position, duration: duration > 0 ? duration : source.mediaSource.durationSeconds ?? 0)
        let snapshot = PlayerSnapshot(
            position: position,
            duration: duration,
            bufferedRanges: playable > position ? [position...playable] : [],
            isPlaying: player.isPlaying,
            isBuffering: buffering,
            waitingReason: buffering ? (ktvCacheSession != nil ? "KSPlayer 等待 KTV 缓存数据" : "KSPlayer 等待 AVIO 数据") : nil,
            errorMessage: nil,
            didReachEnd: player.playbackState == .finished
        )
        onSnapshot?(snapshot)
    }

    private func emitError(_ message: String) {
        onSnapshot?(PlayerSnapshot(errorMessage: message))
        DiagnosticsLogger.shared.log(ktvCacheSession != nil ? "KSKTV" : "KSAVIO", "prepare failed: \(message)")
    }

    private func sane(_ value: Double) -> Double { value.isFinite && value >= 0 ? value : 0 }
}
