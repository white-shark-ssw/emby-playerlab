import AVFoundation
import CoreVideo
import Foundation
import QuartzCore

final class AVPlayerEngine: NSObject, PlayerEngine {
    let kind: PlayerEngineKind = .avPlayer
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    let player = AVPlayer()

    private var snapshot = PlayerSnapshot()
    private var observations: [NSKeyValueObservation] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var pendingFrameMeasurement: FrameMeasurement?
    private var lastConfiguration: Configuration?

    private struct Configuration {
        let url: URL
        let headers: [String: String]
        let preferredForwardBuffer: Double
    }

    private struct FrameMeasurement {
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
    }

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = false
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
        stop()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        lastConfiguration = Configuration(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer)
        stopObservers()

        let asset: AVURLAsset
        if headers.isEmpty {
            asset = AVURLAsset(url: url)
        } else {
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = preferredForwardBuffer
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ])
        item.add(output)
        videoOutput = output

        player.replaceCurrentItem(with: item)
        snapshot = PlayerSnapshot(position: max(0, startPosition))
        emit()
        observe(item: item)

        if startPosition > 0 {
            item.seek(
                to: CMTime(seconds: startPosition, preferredTimescale: 600),
                toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
            )
        }
    }

    func play() {
        snapshot.isPlaying = true
        emit()
        player.playImmediately(atRate: 1)
    }

    func pause() {
        player.pause()
        snapshot.isPlaying = false
        emit()
    }

    func seek(to seconds: Double, direction: SeekDirection) {
        guard let item = player.currentItem else { return }
        let duration = finiteDuration(item.duration.seconds)
        let target = min(max(0, seconds), duration > 0 ? duration : seconds)
        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })
        let requestedAt = CACurrentMediaTime()
        let wasPlaying = player.rate > 0 || snapshot.isPlaying

        item.cancelPendingSeeks()
        snapshot.position = target
        snapshot.didReachEnd = false
        emit()

        let before: Double
        let after: Double
        switch direction {
        case .forward:
            before = 0.35
            after = 0.65
        case .backward:
            before = 0.65
            after = 0.35
        case .absolute:
            before = 0.5
            after = 0.5
        }

        pendingFrameMeasurement = FrameMeasurement(requestedAt: requestedAt, target: target, bufferHit: bufferHit)
        let targetTime = CMTime(seconds: target, preferredTimescale: 600)
        item.seek(
            to: targetTime,
            toleranceBefore: CMTime(seconds: before, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: after, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self, finished else { return }
            DispatchQueue.main.async {
                if wasPlaying {
                    self.player.playImmediately(atRate: 1)
                    self.snapshot.isPlaying = true
                }
                self.emit()
            }
        }

        if wasPlaying {
            player.playImmediately(atRate: 1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let pending = self.pendingFrameMeasurement,
                  abs(pending.target - target) < 0.01 else { return }
            self.pendingFrameMeasurement = nil
            self.onSeekCompleted?(SeekResult(
                requestedAt: pending.requestedAt,
                target: pending.target,
                actualPosition: self.player.currentTime().seconds.isFinite ? self.player.currentTime().seconds : nil,
                bufferHit: pending.bufferHit,
                completionLatencyMs: (CACurrentMediaTime() - pending.requestedAt) * 1000,
                measurement: "AV 首帧等待超时"
            ))
        }
    }

    func reload(at seconds: Double) {
        guard let configuration = lastConfiguration else { return }
        let shouldResume = snapshot.isPlaying || player.rate > 0
        prepare(
            url: configuration.url,
            headers: configuration.headers,
            preferredForwardBuffer: configuration.preferredForwardBuffer,
            startPosition: seconds
        )
        if shouldResume { play() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservers()
        videoOutput = nil
        pendingFrameMeasurement = nil
        snapshot = PlayerSnapshot()
    }

    @objc private func displayLinkTick() {
        guard let pending = pendingFrameMeasurement,
              let output = videoOutput else { return }

        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard itemTime.isNumeric else { return }
        let seconds = itemTime.seconds
        guard seconds.isFinite, abs(seconds - pending.target) <= 2.0,
              output.hasNewPixelBuffer(forItemTime: itemTime) else { return }

        _ = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        pendingFrameMeasurement = nil
        onSeekCompleted?(SeekResult(
            requestedAt: pending.requestedAt,
            target: pending.target,
            actualPosition: seconds,
            bufferHit: pending.bufferHit,
            completionLatencyMs: (CACurrentMediaTime() - pending.requestedAt) * 1000,
            measurement: "AV 新画面"
        ))
    }

    private func observe(item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if item.status == .failed {
                    self.snapshot.errorMessage = item.error?.localizedDescription ?? "AVPlayerItem failed"
                    self.emit()
                }
            }
        })

        observations.append(player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.snapshot.isPlaying = player.timeControlStatus == .playing
                self.snapshot.waitingReason = player.reasonForWaitingToPlay?.rawValue
                self.emit()
            }
        })

        observations.append(item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot.bufferedRanges = item.loadedTimeRanges.compactMap { value in
                    let range = value.timeRangeValue
                    let start = range.start.seconds
                    let end = CMTimeRangeGetEnd(range).seconds
                    guard start.isFinite, end.isFinite, end >= start else { return nil }
                    return start...end
                }
                self.emit()
            }
        })

        observations.append(item.observe(\.duration, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot.duration = self.finiteDuration(item.duration.seconds)
                self.emit()
            }
        })

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                self.snapshot.position = seconds
                self.emit()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.snapshot.didReachEnd = true
            self.snapshot.isPlaying = false
            self.emit()
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self.snapshot.errorMessage = error?.localizedDescription ?? "Failed to play to end"
            self.emit()
        }
    }

    private func stopObservers() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }
    }

    private func emit() {
        onSnapshot?(snapshot)
    }

    private func finiteDuration(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }
}
