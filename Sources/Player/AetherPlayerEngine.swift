#if canImport(AetherEngine)
import AetherEngine
import Combine
import Foundation
import QuartzCore
import UIKit

@MainActor
final class AetherPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .aether
    let playerView = AetherPlayerView()
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    private let source: ResolvedPlaybackSource
    private let session: UnifiedMediaTransportSession?
    private var aether: AetherEngine?
    private var reader: AetherTransportIOReader?
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var wantsPlayback = false
    private var seekRequests: [Double: (requestedAt: CFTimeInterval, bufferHit: Bool)] = [:]

    var maxSupportedPlaybackRate: Double { Double(aether?.maxSupportedRate ?? 2) }

    init(source: ResolvedPlaybackSource, sharedTransportSession: UnifiedMediaTransportSession?) {
        self.source = source
        self.session = sharedTransportSession
        do {
            let engine = try AetherEngine()
            aether = engine
            engine.bind(view: playerView)
            bindState(engine)
            DiagnosticsLogger.shared.playback("Aether", "engine created item=\(source.itemId) unifiedTransport=\(sharedTransportSession != nil)")
        } catch {
            DiagnosticsLogger.shared.playback("Aether", "engine init failed item=\(source.itemId) error=\(error.localizedDescription)")
            emitFailure("Aether 初始化失败：\(error.localizedDescription)")
        }
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        guard let aether, let session else {
            emitFailure("Aether 缺少 UnifiedTransport 会话。")
            return
        }
        loadTask?.cancel()
        reader?.cancel()
        let source = self.source
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let resource = try await session.resolve()
                guard !Task.isCancelled else { return }
                let reader = AetherTransportIOReader(session: session, contentLength: resource.contentLength)
                self.reader = reader
                var options = LoadOptions()
                options.httpHeaders = headers
                if let duration = source.mediaSource.durationSeconds, duration > 0 { options.declaredDurationSeconds = duration }
                let hint = Self.formatHint(source.mediaSource.container)
                DiagnosticsLogger.shared.playback("Aether", "load begin item=\(source.itemId) bytes=\(resource.contentLength) start=\(String(format: "%.3f", startPosition)) format=\(hint ?? "probe") directURL=false nasMediaProxy=false byteGuess=disabled")
                try await aether.load(source: .custom(reader, formatHint: hint), startPosition: startPosition > 0.5 ? startPosition : nil, options: options)
                guard !Task.isCancelled else { return }
                DiagnosticsLogger.shared.playback("Aether", "load ready item=\(source.itemId) duration=\(String(format: "%.3f", aether.duration))")
                if self.wantsPlayback { aether.play() } else { aether.pause() }
                self.emitSnapshot()
            } catch is CancellationError {
                DiagnosticsLogger.shared.playback("Aether", "load cancelled item=\(source.itemId)")
            } catch {
                guard !Task.isCancelled else { return }
                DiagnosticsLogger.shared.playback("Aether", "load failed item=\(source.itemId) error=\(error.localizedDescription)")
                self.emitFailure("Aether 打开失败：\(error.localizedDescription)")
            }
        }
        _ = url
        _ = preferredForwardBuffer
    }

    func play() {
        wantsPlayback = true
        aether?.play()
    }

    func pause() {
        wantsPlayback = false
        aether?.pause()
    }

    func setPlaybackRate(_ rate: Double) { aether?.setRate(Float(max(0, rate))) }

    func seek(to seconds: Double, direction: SeekDirection) {
        guard let aether else { return }
        let target = max(0, seconds)
        let current = aether.clock.currentTime
        let bufferHit = target >= current - 0.05 && target <= aether.clock.bufferedPosition + 0.25
        let toleranceSeconds: Double
        switch direction {
        case .forward, .backward: toleranceSeconds = 0.75
        case .absolute: toleranceSeconds = 0
        }
        seekRequests[target] = (CACurrentMediaTime(), bufferHit)
        DiagnosticsLogger.shared.playback("AetherSeek", "request target=\(String(format: "%.3f", target)) direction=\(String(describing: direction)) tolerance=\(String(format: "%.2f", toleranceSeconds)) rendered=\(String(format: "%.3f", aether.clock.sourceTime)) buffered=\(String(format: "%.3f", aether.clock.bufferedPosition))")
        Task { @MainActor [weak self] in await self?.aether?.seek(to: target, toleranceSeconds: toleranceSeconds) }
    }

    func reload(at seconds: Double) { seek(to: seconds, direction: .absolute) }

    func recoverStall(position: Double, duration: Double) {
        reader?.reprioritizeCurrentOffset()
        DiagnosticsLogger.shared.playback("Aether", "recover stall position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) action=reprioritize-real-byte")
    }

    func transportMetrics() async -> TransportMetricsSnapshot? { await session?.metrics() }

    func stop() {
        wantsPlayback = false
        loadTask?.cancel()
        loadTask = nil
        reader?.cancel()
        aether?.stop()
        reader = nil
        seekRequests.removeAll()
        DiagnosticsLogger.shared.playback("Aether", "stop item=\(source.itemId)")
    }

    private func bindState(_ engine: AetherEngine) {
        engine.$state.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.$playbackPhase.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.$isBuffering.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.$duration.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.$hasFirstFrameReadyForDisplay.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.clock.$currentTime.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.clock.$sourceTime.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.clock.$bufferedPosition.sink { [weak self] _ in Task { @MainActor in self?.emitSnapshot() } }.store(in: &cancellables)
        engine.seekEvents.sink { [weak self] event in Task { @MainActor in self?.handleSeekEvent(event) } }.store(in: &cancellables)
    }

    private func handleSeekEvent(_ event: SeekEvent) {
        switch event.outcome {
        case .began:
            if seekRequests[event.target] == nil { seekRequests[event.target] = (CACurrentMediaTime(), false) }
        case .landed(let renderedTime):
            let request = seekRequests.removeValue(forKey: event.target)
            let requestedAt = request?.requestedAt ?? CACurrentMediaTime()
            let latency = max(0, (CACurrentMediaTime() - requestedAt) * 1000)
            DiagnosticsLogger.shared.playback("AetherSeek", "landed id=\(event.id) target=\(String(format: "%.3f", event.target)) rendered=\(String(format: "%.3f", renderedTime)) ms=\(String(format: "%.1f", latency))")
            onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: event.target, actualPosition: renderedTime, bufferHit: request?.bufferHit ?? false, completionLatencyMs: latency, measurement: "Aether SeekEvent.landed"))
        case .stalled:
            DiagnosticsLogger.shared.playback("AetherSeek", "stalled id=\(event.id) target=\(String(format: "%.3f", event.target))")
        case .superseded, .rejected:
            seekRequests.removeValue(forKey: event.target)
        }
        emitSnapshot()
    }

    private func emitSnapshot() {
        guard let aether else { return }
        let position = max(0, aether.clock.currentTime)
        let duration = max(aether.duration, source.mediaSource.durationSeconds ?? 0)
        let bufferedEnd = duration > 0 ? min(duration, max(position, aether.clock.bufferedPosition)) : max(position, aether.clock.bufferedPosition)
        let bufferedRanges = bufferedEnd > position + 0.01 ? [position...bufferedEnd] : []
        let rendered = aether.hasFirstFrameReadyForDisplay && aether.clock.sourceTime.isFinite ? max(0, aether.clock.sourceTime) : nil
        let isPlaying: Bool
        let didReachEnd: Bool
        let errorMessage: String?
        switch aether.state {
        case .playing, .seeking: isPlaying = true; didReachEnd = false; errorMessage = nil
        case .ended: isPlaying = false; didReachEnd = true; errorMessage = nil
        case .error(let message): isPlaying = false; didReachEnd = false; errorMessage = message
        case .idle, .loading, .paused: isPlaying = false; didReachEnd = false; errorMessage = nil
        }
        let waitingReason: String?
        switch aether.playbackPhase {
        case .loading: waitingReason = "Aether loading"
        case .seeking: waitingReason = "Aether seeking"
        case .rebuffering: waitingReason = "Aether rebuffering"
        case .stalled(let reconnecting): waitingReason = reconnecting ? "Aether source reconnecting" : "Aether source stalled"
        default: waitingReason = nil
        }
        let buffering = aether.isBuffering || aether.playbackPhase == .loading || aether.playbackPhase == .rebuffering
        onSnapshot?(PlayerSnapshot(position: position, renderedPosition: rendered, duration: duration, bufferedRanges: bufferedRanges, isPlaying: isPlaying, isBuffering: buffering, waitingReason: waitingReason, errorMessage: errorMessage, didReachEnd: didReachEnd))
    }

    private func emitFailure(_ message: String) {
        let duration = source.mediaSource.durationSeconds ?? 0
        onSnapshot?(PlayerSnapshot(position: 0, duration: duration, errorMessage: message))
    }

    private static func formatHint(_ container: String?) -> String? {
        guard let value = container?.lowercased(), !value.isEmpty else { return nil }
        switch value {
        case "mkv": return "matroska"
        case "ts", "m2ts": return "mpegts"
        default: return value
        }
    }
}
#endif
