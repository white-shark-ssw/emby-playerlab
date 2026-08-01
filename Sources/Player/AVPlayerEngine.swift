import AVFoundation
import Foundation
import QuartzCore

final class AVPlayerEngine: NSObject, PlayerEngine {
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    let player = AVPlayer()
    private var snapshot = PlayerSnapshot()
    private var observations: [NSKeyValueObservation] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?

    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = false
    }

    deinit {
        stop()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double) {
        stopObservers()

        let asset: AVURLAsset
        if headers.isEmpty {
            asset = AVURLAsset(url: url)
        } else {
            // AVURLAssetHTTPHeaderFieldsKey is broadly used by AVFoundation clients.
            // It remains isolated here so a resource-loader implementation can replace it later.
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = preferredForwardBuffer
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        player.replaceCurrentItem(with: item)
        snapshot = PlayerSnapshot()
        emit()
        observe(item: item)
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

        let targetTime = CMTime(seconds: target, preferredTimescale: 600)
        item.seek(
            to: targetTime,
            toleranceBefore: CMTime(seconds: before, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: after, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self else { return }
            let latency = (CACurrentMediaTime() - requestedAt) * 1000
            let result = SeekResult(
                requestedAt: requestedAt,
                target: target,
                bufferHit: bufferHit,
                completionLatencyMs: latency
            )
            DispatchQueue.main.async {
                guard finished else { return }
                if wasPlaying {
                    self.player.playImmediately(atRate: 1)
                    self.snapshot.isPlaying = true
                }
                self.onSeekCompleted?(result)
                self.emit()
            }
        }

        if wasPlaying {
            player.playImmediately(atRate: 1)
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservers()
        snapshot = PlayerSnapshot()
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
                if #available(iOS 15.0, *) {
                    self.snapshot.waitingReason = player.reasonForWaitingToPlay?.rawValue
                }
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
