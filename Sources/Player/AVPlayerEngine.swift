import AVFoundation
import CoreVideo
import Foundation
import QuartzCore

final class AVPlayerEngine: NSObject, PlayerEngine {
    let kind: PlayerEngineKind
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
    private let transportSource: ResolvedPlaybackSource?
    private let transportClient: EmbyAPIClient?
    private let transportConfiguration: MediaTransportConfiguration?
    private var transportServer: TransportHTTPServer?
    private var transportPrepareTask: Task<Void, Never>?
    private var prepareGeneration = 0
    private var shouldPlayWhenReady = false

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

    init(
        kind: PlayerEngineKind = .avPlayer,
        transportSource: ResolvedPlaybackSource? = nil,
        transportClient: EmbyAPIClient? = nil,
        transportConfiguration: MediaTransportConfiguration? = nil
    ) {
        self.kind = kind
        self.transportSource = transportSource
        self.transportClient = transportClient
        self.transportConfiguration = transportConfiguration
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
        stop()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        lastConfiguration = Configuration(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer)
        prepareGeneration += 1
        let generation = prepareGeneration

        stopObservers()
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        transportServer?.stop()
        transportServer = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        videoOutput = nil
        pendingFrameMeasurement = nil

        snapshot = PlayerSnapshot(
            position: max(0, startPosition),
            isBuffering: kind == .transportAVPlayer,
            waitingReason: kind == .transportAVPlayer ? "Transport HTTP preparing" : nil
        )
        emit()

        if kind == .transportAVPlayer,
           let transportSource,
           let transportClient,
           let transportConfiguration {
            let session: TransportDataSession
            switch transportConfiguration.strategy {
            case .downloadFirst:
                session = DownloadFirstMediaSession(
                    source: transportSource,
                    client: transportClient,
                    configuration: transportConfiguration
                )
            case .legacyMultiRange:
                session = MediaTransportSession(
                    source: transportSource,
                    client: transportClient,
                    configuration: transportConfiguration
                )
            }
            let server = TransportHTTPServer(session: session, fileExtension: transportSource.mediaSource.normalizedContainer)
            transportServer = server

            DiagnosticsLogger.shared.log(
                "TransportPlayer",
                "prepare-local-http item=\(transportSource.itemId) strategy=\(transportConfiguration.strategy.rawValue) mode=\(transportConfiguration.cacheMode.rawValue) memory=\(transportConfiguration.memoryLimitBytes) disk=\(transportConfiguration.diskLimitBytes) wifiPreload=\(transportConfiguration.wifiPreloadBytes) cellularPreload=\(transportConfiguration.cellularPreloadBytes) segment=\(transportConfiguration.segmentSizeBytes) upstreamBlock=\(transportConfiguration.upstreamBlockSizeBytes) concurrent=\(transportConfiguration.maximumConcurrentRequests)"
            )

            transportPrepareTask = Task { [weak self, weak server] in
                guard let self, let server else { return }
                do {
                    let localURL = try await server.start()
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async { [weak self, weak server] in
                        guard let self, let server,
                              generation == self.prepareGeneration,
                              self.transportServer === server else { return }
                        DiagnosticsLogger.shared.log("TransportPlayer", "local HTTP asset ready")
                        self.installAsset(
                            AVURLAsset(url: localURL),
                            preferredForwardBuffer: min(max(2, preferredForwardBuffer), 8),
                            startPosition: startPosition
                        )
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self, generation == self.prepareGeneration else { return }
                        self.snapshot.isBuffering = false
                        self.snapshot.errorMessage = error.localizedDescription
                        self.snapshot.waitingReason = "Transport HTTP failed"
                        DiagnosticsLogger.shared.log("TransportPlayer", "prepare failed: \(error.localizedDescription)")
                        self.emit()
                    }
                }
            }
            return
        }

        let asset: AVURLAsset
        if headers.isEmpty {
            asset = AVURLAsset(url: url)
        } else {
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
        installAsset(asset, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
    }

    func play() {
        shouldPlayWhenReady = true
        snapshot.isPlaying = true
        emit()
        player.playImmediately(atRate: 1)
    }

    func pause() {
        shouldPlayWhenReady = false
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

        if kind == .transportAVPlayer, let transportServer {
            Task { [transportServer] in
                await transportServer.prioritizeSeek(position: target, duration: duration)
            }
        }

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

    func recoverStall(position: Double, duration: Double) {
        guard kind == .transportAVPlayer, let transportServer else { return }
        Task { [transportServer] in
            await transportServer.recoverStall(position: position, duration: duration)
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
        shouldPlayWhenReady = false
        prepareGeneration += 1
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        transportServer?.stop()
        transportServer = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservers()
        videoOutput = nil
        pendingFrameMeasurement = nil
        snapshot = PlayerSnapshot()
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        guard let transportServer else { return nil }
        return await transportServer.metrics()
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

    private func installAsset(_ asset: AVURLAsset, preferredForwardBuffer: Double, startPosition: Double) {
        stopObservers()
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = preferredForwardBuffer
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false

        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ])
        item.add(output)
        videoOutput = output

        player.replaceCurrentItem(with: item)
        snapshot.position = max(0, startPosition)
        snapshot.isBuffering = true
        snapshot.waitingReason = kind == .transportAVPlayer ? "Transport HTTP loading" : snapshot.waitingReason
        snapshot.errorMessage = nil
        emit()
        observe(item: item)

        if startPosition > 0 {
            item.seek(
                to: CMTime(seconds: startPosition, preferredTimescale: 600),
                toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600),
                completionHandler: { [weak self] finished in
                    guard let self, finished, self.shouldPlayWhenReady else { return }
                    self.player.playImmediately(atRate: 1)
                }
            )
        } else if shouldPlayWhenReady {
            player.playImmediately(atRate: 1)
        }
    }

    private func observe(item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if item.status == .failed {
                    self.snapshot.errorMessage = item.error?.localizedDescription ?? "AVPlayerItem failed"
                    DiagnosticsLogger.shared.log(
                        "AVPlayer",
                        "item failed engine=\(self.kind.title) error=\(self.snapshot.errorMessage ?? "unknown")"
                    )
                    self.emit()
                } else if item.status == .readyToPlay, self.shouldPlayWhenReady {
                    self.player.playImmediately(atRate: 1)
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
