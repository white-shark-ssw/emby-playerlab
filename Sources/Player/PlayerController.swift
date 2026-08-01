import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class PlayerController: ObservableObject {
    @Published private(set) var snapshot = PlayerSnapshot()
    @Published private(set) var displayedPosition: Double = 0
    @Published private(set) var seekFeedback: String?
    @Published private(set) var lastSeekSummary = "尚未 Seek"
    @Published private(set) var prematureEOFMessage: String?

    let engine: AVPlayerEngine
    let source: ResolvedPlaybackSource

    private let client: EmbyAPIClient
    private var progressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var started = false
    private var userIsScrubbing = false
    private var pendingSeekTarget: Double?
    private var eofRetryCount = 0

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient) {
        self.source = source
        self.client = client
        self.engine = AVPlayerEngine()

        engine.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            Task { @MainActor in
                let wasEnd = self.snapshot.didReachEnd
                self.snapshot = snapshot
                if !self.userIsScrubbing, self.pendingSeekTarget == nil {
                    self.displayedPosition = snapshot.position
                }
                if snapshot.didReachEnd && !wasEnd {
                    self.handleEndEvent()
                }
            }
        }

        engine.onSeekCompleted = { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {
                    self.pendingSeekTarget = nil
                    self.displayedPosition = result.target
                }
                self.lastSeekSummary = String(
                    format: "%.0fms · %@ · 目标 %.2fs",
                    result.completionLatencyMs,
                    result.bufferHit ? "缓存命中" : "缓存未命中",
                    result.target
                )
                DiagnosticsLogger.shared.log(
                    "Seek",
                    "target=\(result.target) bufferHit=\(result.bufferHit) completionMs=\(result.completionLatencyMs)"
                )
            }
        }
    }

    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        started = true
        configureAudioSession()
        engine.prepare(url: source.url, headers: source.headers, preferredForwardBuffer: preferredForwardBuffer)
        engine.play()

        DiagnosticsLogger.shared.log(
            "Player",
            "Start item=\(source.itemId) mediaSource=\(source.mediaSource.id) container=\(source.mediaSource.container ?? "unknown") url=\(source.url.absoluteString)"
        )

        Task {
            await client.reportStart(source: source, position: 0, paused: false)
        }

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self else { return }
                await self.client.reportProgress(
                    source: self.source,
                    position: self.snapshot.position,
                    paused: !self.snapshot.isPlaying
                )
            }
        }
    }

    func stop() {
        guard started else { return }
        progressTask?.cancel()
        progressTask = nil
        let position = snapshot.position
        engine.stop()
        Task {
            await client.reportStopped(source: source, position: position)
        }
        started = false
        pendingSeekTarget = nil
    }

    func togglePlayPause() {
        if snapshot.isPlaying {
            engine.pause()
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }
        } else {
            engine.play()
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: false, eventName: "Unpause") }
        }
    }

    func seek(by offset: Double) {
        let base = pendingSeekTarget ?? snapshot.position
        let duration = effectiveDuration
        let target = min(max(0, base + offset), duration > 0 ? duration : base + offset)
        pendingSeekTarget = target
        displayedPosition = target

        let direction: SeekDirection = offset >= 0 ? .forward : .backward
        engine.seek(to: target, direction: direction)
        showFeedback(offset: offset)

        Task {
            await client.reportProgress(
                source: source,
                position: target,
                paused: !snapshot.isPlaying,
                eventName: "TimeUpdate"
            )
        }
    }

    func beginScrubbing() {
        userIsScrubbing = true
    }

    func updateScrubbing(to value: Double) {
        displayedPosition = value
    }

    func endScrubbing() {
        userIsScrubbing = false
        pendingSeekTarget = displayedPosition
        engine.seek(to: displayedPosition, direction: .absolute)
        Task {
            await client.reportProgress(
                source: source,
                position: displayedPosition,
                paused: !snapshot.isPlaying,
                eventName: "TimeUpdate"
            )
        }
    }

    var effectiveDuration: Double {
        if snapshot.duration > 0 { return snapshot.duration }
        return source.mediaSource.durationSeconds ?? 0
    }

    var bufferedEnd: Double {
        snapshot.bufferedRanges
            .filter { $0.lowerBound <= snapshot.position + 0.5 }
            .map(\.upperBound)
            .max() ?? 0
    }

    private func handleEndEvent() {
        let decision = PrematureEOFGuard.evaluate(
            current: snapshot.position,
            avDuration: snapshot.duration,
            embyDuration: source.mediaSource.durationSeconds
        )

        DiagnosticsLogger.shared.log(
            "EOF",
            "premature=\(decision.isPremature) reason=\(decision.reason) current=\(snapshot.position) avDuration=\(snapshot.duration) embyDuration=\(source.mediaSource.durationSeconds ?? 0)"
        )

        if decision.isPremature, eofRetryCount < 2 {
            eofRetryCount += 1
            prematureEOFMessage = "\(decision.reason)；自动恢复 \(eofRetryCount)/2"
            let retry = min(snapshot.position + 0.25, effectiveDuration)
            pendingSeekTarget = retry
            engine.seek(to: retry, direction: .forward)
            engine.play()
        } else if decision.isPremature {
            prematureEOFMessage = "\(decision.reason)；AVPlayer 自动恢复已达上限，请导出日志，下一阶段由 MPV 容错引擎接管。"
        } else {
            Task { await client.reportStopped(source: source, position: snapshot.position) }
        }
    }

    private func showFeedback(offset: Double) {
        let seconds = abs(Int(offset.rounded()))
        seekFeedback = offset >= 0 ? "↻ \(seconds) 秒" : "↺ \(seconds) 秒"
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.seekFeedback = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            DiagnosticsLogger.shared.log("Audio", "Audio session failed: \(error.localizedDescription)")
        }
    }
}
