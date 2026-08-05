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
    private var accessLogObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var pendingFrameMeasurement: FrameMeasurement?
    private var lastConfiguration: Configuration?
    private let transportSource: ResolvedPlaybackSource?
    private let transportClient: EmbyAPIClient?
    private let transportConfiguration: MediaTransportConfiguration?
    private let sharedTransportSession: MediaTransportSession?
    private var transportServer: TransportHTTPServer?
    private var transportResourceLoader: TransportResourceLoader?
    private var transportPrepareTask: Task<Void, Never>?
    private var transportLocalURL: URL?
    private var transportForwardBufferDuration: Double = 4
    private var prepareGeneration = 0
    private var shouldPlayWhenReady = false
    private var seekRequestGeneration = 0
    private var lastStallPosition: Double = -1
    private var stallRecoveryAttempts = 0
    private var lastTransportItemRebindAt = Date.distantPast
    private var transportAssetRevision = 0
    private var lastTransportFailureReloadAt = Date.distantPast

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
        transportConfiguration: MediaTransportConfiguration? = nil,
        sharedTransportSession: MediaTransportSession? = nil
    ) {
        self.kind = kind
        self.transportSource = transportSource
        self.transportClient = transportClient
        self.transportConfiguration = transportConfiguration
        self.sharedTransportSession = sharedTransportSession
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
        seekRequestGeneration += 1
        let generation = prepareGeneration

        stopObservers()
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        transportServer?.stop()
        transportServer = nil
        transportResourceLoader?.invalidate()
        transportResourceLoader = nil
        transportLocalURL = nil
        lastTransportItemRebindAt = .distantPast
        transportAssetRevision = 0
        player.pause()
        player.replaceCurrentItem(with: nil)
        videoOutput = nil
        pendingFrameMeasurement = nil
        lastStallPosition = -1
        stallRecoveryAttempts = 0

        snapshot = PlayerSnapshot(
            position: max(0, startPosition),
            isBuffering: kind == .transportAVPlayer || kind == .resourceLoaderAVPlayer,
            waitingReason: kind == .transportAVPlayer ? "Transport HTTP preparing" : (kind == .resourceLoaderAVPlayer ? "ResourceLoader preparing" : nil)
        )
        emit()


        if kind == .resourceLoaderAVPlayer,
           let transportSource,
           let transportClient,
           let transportConfiguration {
            let profile = transportConfiguration.resourceLoaderProfile()
            let session = sharedTransportSession ?? MediaTransportSession(source: transportSource, client: transportClient, configuration: profile)
            let loader = TransportResourceLoader(session: session, stopSessionOnInvalidate: sharedTransportSession == nil)
            transportResourceLoader = loader
            let forwardBuffer = min(max(4, preferredForwardBuffer), 30)
            DiagnosticsLogger.shared.log(
                "SmartAV",
                "prepare-resource-loader item=\(transportSource.itemId) memory=\(profile.memoryLimitBytes) disk=\(profile.diskLimitBytes) wifiWindow=\(profile.wifiPreloadBytes) cellularWindow=\(profile.cellularPreloadBytes) segment=\(profile.segmentSizeBytes) concurrent=\(profile.maximumConcurrentRequests)"
            )
            installAsset(
                loader.makeAsset(fileExtension: transportSource.mediaSource.normalizedContainer),
                preferredForwardBuffer: forwardBuffer,
                startPosition: startPosition
            )
            return
        }
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
                        let forwardBuffer = min(max(2, preferredForwardBuffer), 8)
                        self.transportLocalURL = localURL
                        self.transportForwardBufferDuration = forwardBuffer
                        DiagnosticsLogger.shared.log("TransportPlayer", "local HTTP asset ready")
                        self.installAsset(
                            AVURLAsset(url: localURL),
                            preferredForwardBuffer: forwardBuffer,
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
        resumePlayback(reason: "user-play", generation: seekRequestGeneration)
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
        let shouldResume = shouldPlayWhenReady || player.rate > 0 || snapshot.isPlaying
        seekRequestGeneration += 1
        let generation = seekRequestGeneration

        if shouldResume { shouldPlayWhenReady = true }
        if kind == .resourceLoaderAVPlayer, let transportResourceLoader {
            transportResourceLoader.prioritizeSeek(position: target, duration: duration)
        } else if kind == .transportAVPlayer, let transportServer {
            transportServer.resetClientStreams(reason: "user-seek generation=\(generation)")
            Task { [transportServer] in
                await transportServer.prioritizeSeek(position: target, duration: duration)
            }
        }

        item.cancelPendingSeeks()
        snapshot.didReachEnd = false
        snapshot.isPlaying = shouldResume
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
                guard generation == self.seekRequestGeneration else { return }
                if shouldResume { self.resumePlayback(reason: "seek-completed", generation: generation, immediate: true) }
                self.emit()
            }
        }

        if shouldResume { resumePlayback(reason: "seek-submitted", generation: generation, immediate: true) }

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
        guard shouldPlayWhenReady else { return }
        if abs(position - lastStallPosition) < 0.5 { stallRecoveryAttempts += 1 }
        else { lastStallPosition = position; stallRecoveryAttempts = 1 }
        let attempt = stallRecoveryAttempts
        DiagnosticsLogger.shared.log(
            "AVPlayerState",
            "stall engine=\(kind.title) position=\(position) attempt=\(attempt) rate=\(player.rate) timeControl=\(player.timeControlStatus.rawValue) itemStatus=\(player.currentItem?.status.rawValue ?? -1) bufferEmpty=\(player.currentItem?.isPlaybackBufferEmpty ?? false) likelyToKeepUp=\(player.currentItem?.isPlaybackLikelyToKeepUp ?? false) waiting=\(player.reasonForWaitingToPlay?.rawValue ?? "none")"
        )

        if kind == .resourceLoaderAVPlayer, let transportResourceLoader {
            transportResourceLoader.recoverStall(position: position, duration: duration)
            player.automaticallyWaitsToMinimizeStalling = true
            if attempt == 1 {
                resumePlayback(reason: "resource-loader-stall", generation: seekRequestGeneration)
            } else {
                let target = max(0, position)
                player.currentItem?.cancelPendingSeeks()
                player.currentItem?.seek(
                    to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600)
                ) { [weak self] finished in
                    guard let self, finished else { return }
                    DispatchQueue.main.async { self.resumePlayback(reason: "resource-loader-reseek", generation: self.seekRequestGeneration, immediate: true) }
                }
            }
            return
        }

        guard kind == .transportAVPlayer, let transportServer else { return }
        Task { [transportServer] in await transportServer.recoverStall(position: position, duration: duration) }
        DispatchQueue.main.async { [weak self, weak transportServer] in
            guard let self, let transportServer, self.shouldPlayWhenReady else { return }
            self.player.automaticallyWaitsToMinimizeStalling = true
            let bufferedEnd = self.snapshot.bufferedRanges.map(\.upperBound).max() ?? 0
            let timelineIsBehind = bufferedEnd + 1 < position
            if attempt <= 1, !timelineIsBehind {
                transportServer.resetClientStreams(reason: "stall-recovery attempt=1")
                self.resumePlayback(reason: "stall-recovery", generation: self.seekRequestGeneration)
                return
            }
            if Date().timeIntervalSince(self.lastTransportItemRebindAt) >= 2.5 {
                let detail = timelineIsBehind ? "timeline-behind bufferedEnd=\(bufferedEnd)" : "stall"
                self.rebindTransportItem(at: position, reason: "\(detail) attempt=\(attempt)")
            } else {
                self.resumePlayback(reason: "stall-rebind-throttled", generation: self.seekRequestGeneration)
            }
        }
    }

    func reload(at seconds: Double) {
        guard let configuration = lastConfiguration else { return }
        let shouldResume = shouldPlayWhenReady
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
        seekRequestGeneration += 1
        prepareGeneration += 1
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        transportServer?.stop()
        transportServer = nil
        transportResourceLoader?.invalidate()
        transportResourceLoader = nil
        transportLocalURL = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservers()
        videoOutput = nil
        pendingFrameMeasurement = nil
        lastStallPosition = -1
        stallRecoveryAttempts = 0
        lastTransportFailureReloadAt = .distantPast
        snapshot = PlayerSnapshot()
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        if let transportResourceLoader { return await transportResourceLoader.metrics() }
        if let transportServer { return await transportServer.metrics() }
        return nil
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
        player.automaticallyWaitsToMinimizeStalling = true
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
        snapshot.waitingReason = kind == .transportAVPlayer ? "Transport HTTP loading" : (kind == .resourceLoaderAVPlayer ? "ResourceLoader loading" : snapshot.waitingReason)
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
                    self.resumePlayback(reason: "initial-seek", generation: self.seekRequestGeneration)
                }
            )
        } else if shouldPlayWhenReady {
            resumePlayback(reason: "asset-installed", generation: seekRequestGeneration)
        }
    }

    private func observe(item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if item.status == .failed {
                    let message = item.error?.localizedDescription ?? "AVPlayerItem failed"
                    let position = max(0, self.player.currentTime().seconds.isFinite ? self.player.currentTime().seconds : self.snapshot.position)
                    if self.scheduleTransportSessionReload(at: position, error: message) { return }
                    self.shouldPlayWhenReady = false
                    self.snapshot.isPlaying = false
                    self.snapshot.errorMessage = message
                    DiagnosticsLogger.shared.log(
                        "AVPlayer",
                        "item failed engine=\(self.kind.title) error=\(self.snapshot.errorMessage ?? "unknown")"
                    )
                    self.emit()
                } else if item.status == .readyToPlay, self.shouldPlayWhenReady {
                    self.resumePlayback(reason: "ready-to-play", generation: self.seekRequestGeneration)
                }
            }
        })

        observations.append(player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.snapshot.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.snapshot.isPlaying = self.shouldPlayWhenReady
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
                if self.lastStallPosition >= 0, seconds - self.lastStallPosition >= 0.75 {
                    self.lastStallPosition = -1
                    self.stallRecoveryAttempts = 0
                }
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
            self.shouldPlayWhenReady = false
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
            self.shouldPlayWhenReady = false
            self.snapshot.isPlaying = false
            self.snapshot.errorMessage = error?.localizedDescription ?? "Failed to play to end"
            self.emit()
        }

        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            guard let self, let event = item?.accessLog()?.events.last else { return }
            let stalls = max(0, event.numberOfStalls)
            let dropped = max(0, event.numberOfDroppedVideoFrames)
            let observed = event.observedBitrate.isFinite ? max(0, event.observedBitrate) : 0
            let indicated = event.indicatedBitrate.isFinite ? max(0, event.indicatedBitrate) : 0
            self.snapshot.accessLogStalls = stalls
            self.snapshot.droppedVideoFrames = dropped
            self.snapshot.observedBitrate = observed
            DiagnosticsLogger.shared.log(
                "AVAccess",
                "engine=\(self.kind.title) stalls=\(stalls) dropped=\(dropped) observedBitrate=\(Int(observed)) indicatedBitrate=\(Int(indicated))"
            )
            self.emit()
        }
    }

    private func rebindTransportItem(at position: Double, reason: String) {
        guard kind == .transportAVPlayer, let transportServer else {
            resumePlayback(reason: "rebind-missing-local-url", generation: seekRequestGeneration)
            return
        }
        lastTransportItemRebindAt = Date()
        seekRequestGeneration += 1
        let generation = seekRequestGeneration
        transportAssetRevision += 1
        let revision = transportAssetRevision
        pendingFrameMeasurement = nil
        player.pause()
        snapshot.isBuffering = true
        snapshot.waitingReason = "Transport HTTP rebuilding item"
        emit()
        DiagnosticsLogger.shared.log(
            "AVPlayerRecovery",
            "rebind-item position=\(position) generation=\(generation) revision=\(revision) reason=\(reason)"
        )
        Task { [weak self, weak transportServer] in
            guard let self, let transportServer else { return }
            do {
                let localURL = try await transportServer.restartListener()
                DispatchQueue.main.async { [weak self, weak transportServer] in
                    guard let self, let transportServer, self.transportServer === transportServer,
                          self.shouldPlayWhenReady, generation == self.seekRequestGeneration else { return }
                    self.transportLocalURL = localURL
                    let assetURL = self.versionedTransportURL(localURL, revision: revision)
                    DiagnosticsLogger.shared.log(
                        "AVPlayerRecovery",
                        "rebind-listener-ready position=\(position) generation=\(generation) revision=\(revision)"
                    )
                    self.installAsset(
                        AVURLAsset(url: assetURL),
                        preferredForwardBuffer: self.transportForwardBufferDuration,
                        startPosition: max(0, position)
                    )
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, generation == self.seekRequestGeneration else { return }
                    _ = self.scheduleTransportSessionReload(at: position, error: "listener restart failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func versionedTransportURL(_ url: URL, revision: Int) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "transportRevision" }
        queryItems.append(URLQueryItem(name: "transportRevision", value: String(revision)))
        components.queryItems = queryItems
        return components.url ?? url
    }

    @discardableResult
    private func scheduleTransportSessionReload(at position: Double, error: String) -> Bool {
        guard kind == .transportAVPlayer, shouldPlayWhenReady,
              Date().timeIntervalSince(lastTransportFailureReloadAt) >= 15 else { return false }
        lastTransportFailureReloadAt = Date()
        snapshot.isBuffering = true
        snapshot.errorMessage = nil
        snapshot.waitingReason = "Transport HTTP item failed; rebuilding session"
        DiagnosticsLogger.shared.log(
            "AVPlayerRecovery",
            "item-failure-reload position=\(position) error=\(error)"
        )
        emit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.shouldPlayWhenReady else { return }
            self.reload(at: position)
        }
        return true
    }

    private func resumePlayback(reason: String, generation: Int, immediate: Bool = false) {
        guard shouldPlayWhenReady, generation == seekRequestGeneration else { return }
        player.automaticallyWaitsToMinimizeStalling = true
        if immediate {
            player.playImmediately(atRate: 1)
        } else {
            player.play()
        }
        snapshot.isPlaying = true
        emit()

        for delay in [0.15, 0.45] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.shouldPlayWhenReady, generation == self.seekRequestGeneration,
                      self.player.currentItem != nil, self.player.timeControlStatus != .playing else { return }
                let retryImmediately = immediate && delay < 0.3
                DiagnosticsLogger.shared.log(
                    "AVPlayerResume",
                    "retry reason=\(reason) delay=\(delay) mode=\(retryImmediately ? "immediate" : "automatic") status=\(self.player.timeControlStatus.rawValue) waiting=\(self.player.reasonForWaitingToPlay?.rawValue ?? "none")"
                )
                if retryImmediately {
                    self.player.playImmediately(atRate: 1)
                } else {
                    self.player.play()
                }
                self.snapshot.isPlaying = true
                self.emit()
            }
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
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
            self.accessLogObserver = nil
        }
    }

    private func emit() {
        onSnapshot?(snapshot)
    }

    private func finiteDuration(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }
}
