import AVFoundation
import Foundation
import Metal
import QuartzCore
import UIKit
#if canImport(MPVKit)
import MPVKit
#elseif canImport(_MPVKit)
import _MPVKit
#endif
#if canImport(Libmpv)
import Libmpv
#endif

final class MPVMetalLayer: CAMetalLayer {
    // MoltenVK may temporarily request a 1x1 drawable to force presentation completion.
    // Reject that transient size so the renderer cannot get stranded at 1x1 / black.
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if Int(newValue.width) > 1, Int(newValue.height) > 1 { super.drawableSize = newValue }
        }
    }

}

#if canImport(Libmpv)
final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling, PlayerPiPSeekLandingProviding {
    let kind: PlayerEngineKind = .mpv
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    var displayLayer = MPVMetalLayer()

    private let queue = DispatchQueue(label: "com.embyplayerlab.mpv", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<UInt8>()
    private var mpv: OpaquePointer?
    private var snapshot = PlayerSnapshot()
    private var pendingSeek: PendingSeek?
    private var pendingRendererLayout: PendingRendererLayout?
    private var lastConfiguration: Configuration?
    private var isStopping = false
    private var lastPositionEmission: TimeInterval = 0
    private var playbackRateGeneration: UInt64 = 0
    private var seekGeneration: UInt64 = 0
    private var latestNativeSeekDispatchID: UInt64?
    private var activeSeekEventOwnerID: UInt64?
    private var seekingPropertyActive = false
    private var keyframeIndexGeneration: UInt64 = 0
    private var keyframeIndexTask: Task<Void, Never>?
    private var keyframeBackfillTask: Task<Void, Never>?
    private var keyframeLookupBusy = false
    private let sessionKeyframeMap = OnePlayerSessionKeyframeMap()
    private var keyframeIndexRetryWorkItem: DispatchWorkItem?
    private var keyframeIndexRetryAttempt = 0
    private var keyframeIndexRetrySession: TransportDataSession?
    private var keyframeIndexRetryContentLength: Int64 = 0
    private var keyframeIndex: OnePlayerKeyframeIndex?
    private static let keyframeIndexRetryDelays: [TimeInterval] = [1, 2, 4, 8, 16]
    private static let keyframeLookupBudgetMs: Double = 20
    private let sharedTransportSession: TransportDataSession?
    private var streamBridge: MPVUnifiedStreamBridge?
    private var streamPrepareTask: Task<Void, Never>?
    private var enhancementBaseline: EnhancementBaseline?
    private var lastPresentationTimingSignature: PresentationTimingSignature?
    private var pictureInPictureVideoTrackSuspended = false
    private var pictureInPictureSuspendedVideoID: String?
    var pictureInPictureSeekDispatchHandler: ((PlayerPiPSeekDispatchInfo) -> Void)?
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)?
    private var pictureInPictureResumeCompletion: ((Bool, Double?) -> Void)?
    private var pictureInPictureResumeTargetPosition: Double?
    private var pictureInPictureResumeStartedAt: CFTimeInterval?
    private var pictureInPictureResumePlaybackAdvancing = false
    private var pictureInPictureResumeTimeout: DispatchWorkItem?
    private var pictureInPictureResumePoll: DispatchWorkItem?
    private var pictureInPictureResumeSawPlaybackRestart = false

    private struct Configuration {
        let url: URL
        let headers: [String: String]
        let preferredForwardBuffer: Double
        let compatibilityMode: Bool
    }

    private struct PendingSeek {
        let id: UInt64
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
        let intent: String
        let mode: String
        var dispatchTarget: Double
        var keyframeLookupMs: Double
        var keyframeAction: String
        var previousKeyframe: Double?
        var nextKeyframe: Double?
        var nearestKeyframe: Double?
    }

    private enum KeyframeLookupRaceResult {
        case probe(OnePlayerKeyframeNeighborProbeResult)
        case timeout
    }

    private final class KeyframeLookupGate: @unchecked Sendable {
        private let lock = NSLock()
        private var finished = false
        private let continuation: CheckedContinuation<KeyframeLookupRaceResult, Never>

        init(continuation: CheckedContinuation<KeyframeLookupRaceResult, Never>) { self.continuation = continuation }

        func finish(_ result: KeyframeLookupRaceResult) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            lock.unlock()
            continuation.resume(returning: result)
        }
    }

    private struct EnhancementBaseline {
        let scale: String
        let cscale: String
        let deband: String
        let sigmoidUpscaling: String
    }

    private struct PresentationTimingSignature: Equatable {
        let requestedRate: Double
        let displayFPS: Double
        let effectiveMotionTargetFPS: Double?
        let timingStrategy: PlaybackTimingStrategy
    }

    private final class PendingRendererLayout {
        enum Phase: String { case waitingTemporaryReconfig, waitingTargetReconfig, polling }

        let request: RendererLayoutRequest
        let completion: (RendererLayoutAcknowledgement) -> Void
        let targetPanscan: Double
        let targetAspect: String
        var phase: Phase
        var pollAttempt = 0

        init(request: RendererLayoutRequest, completion: @escaping (RendererLayoutAcknowledgement) -> Void, targetPanscan: Double, targetAspect: String, phase: Phase) {
            self.request = request
            self.completion = completion
            self.targetPanscan = targetPanscan
            self.targetAspect = targetAspect
            self.phase = phase
        }
    }

    init(sharedTransportSession: TransportDataSession? = nil) {
        self.sharedTransportSession = sharedTransportSession
        queue.setSpecific(key: queueKey, value: 1)
        displayLayer.backgroundColor = UIColor.black.cgColor
        displayLayer.contentsScale = UIScreen.main.nativeScale
        displayLayer.framebufferOnly = true
    }

    deinit { stop() }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        lastConfiguration = Configuration(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, compatibilityMode: false)
        if mpv == nil {
            do { try createMPV() }
            catch {
                snapshot.errorMessage = error.localizedDescription
                emitOnMain()
                return
            }
        }
        if sharedTransportSession == nil {
            DiagnosticsLogger.shared.log("MPVStream", "load direct HTTP transport=direct-fallback host=\(url.host ?? "unknown")")
            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: false)
            return
        }
        prepareUnifiedStreamAndLoad(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: false)
    }

    func reloadForBadInterleavedMP4(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, reason: String) {
        lastConfiguration = Configuration(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, compatibilityMode: true)
        DiagnosticsLogger.shared.log("MPVCompatibility", "reload reason=\(reason) start=\(startPosition) mode=bad-interleaved-mp4")
        if sharedTransportSession == nil || streamBridge != nil {
            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: true)
        } else {
            prepareUnifiedStreamAndLoad(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: true)
        }
    }

    func play() { setPropertyAsync(name: "pause", value: "no") }
    func pause() { setPropertyAsync(name: "pause", value: "yes") }

    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false) }; return }
            self.cancelPictureInPictureRendererResumeState()
            let currentVID = self.getStringProperty(handle: handle, name: "vid") ?? "unknown"
            let currentVO = self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown"

            if currentVID == "no" {
                self.pictureInPictureVideoTrackSuspended = true
                if self.pictureInPictureSuspendedVideoID == nil { self.pictureInPictureSuspendedVideoID = "auto" }
                DiagnosticsLogger.shared.log("MPVPiP", "video suspend already-active vid=no currentVO=\(currentVO) policy=disable-video-track-preserve-audio")
                DispatchQueue.main.async { completion(true) }
                return
            }

            self.pictureInPictureSuspendedVideoID = currentVID == "unknown" ? "auto" : currentVID
            guard self.setPropertyChecked(handle: handle, name: "vid", value: "no") else {
                self.reconcilePictureInPictureVideoState(handle: handle, reason: "suspend-property-failed")
                DiagnosticsLogger.shared.log("MPVPiP", "video suspend request failed previousVID=\(currentVID) currentVO=\(currentVO)")
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.waitForPictureInPictureVideoDisabled(handle: handle, attempt: 0) { [weak self] ready, observedVID in
                guard let self else { DispatchQueue.main.async { completion(false) }; return }
                self.pictureInPictureVideoTrackSuspended = observedVID == "no"
                let audioPTS = self.getStringProperty(handle: handle, name: "audio-pts") ?? "unknown"
                DiagnosticsLogger.shared.log("MPVPiP", "video suspend ready=\(ready) previousVID=\(currentVID) observedVID=\(observedVID) currentVO=\(self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown") audioPTS=\(audioPTS) policy=vid-no-preserve-audio")
                DispatchQueue.main.async { completion(ready && self.pictureInPictureVideoTrackSuspended) }
            }
        }
    }

    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) {
        resumeInlineRendererAfterPictureInPicture(targetPosition: snapshot.position) { success, _ in completion(success) }
    }

    func resumeInlineRendererAfterPictureInPicture(targetPosition: Double, completion: @escaping (Bool, Double?) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false, nil) }; return }
            self.cancelPictureInPictureRendererResumeState()
            self.pictureInPictureResumeCompletion = completion
            self.pictureInPictureResumeTargetPosition = max(0, targetPosition)
            self.pictureInPictureResumeStartedAt = CACurrentMediaTime()
            self.pictureInPictureResumePlaybackAdvancing = (self.getStringProperty(handle: handle, name: "pause") ?? "no") != "yes"
            self.pictureInPictureResumeSawPlaybackRestart = false

            let currentVID = self.getStringProperty(handle: handle, name: "vid") ?? "unknown"
            let restoreVID = self.pictureInPictureSuspendedVideoID ?? "auto"
            if currentVID != "no" && currentVID != "unknown" {
                self.pictureInPictureVideoTrackSuspended = false
                DiagnosticsLogger.shared.log("MPVPiP", "video restore reconciled already-enabled currentVID=\(currentVID) restoreVID=\(restoreVID) currentVO=\(self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown")")
                self.beginPictureInPictureRendererResumePolling(handle: handle)
                return
            }

            guard self.setPropertyChecked(handle: handle, name: "vid", value: restoreVID) else {
                self.reconcilePictureInPictureVideoState(handle: handle, reason: "restore-property-failed")
                self.finishPictureInPictureRendererResume(success: false, actualPosition: nil, reason: "video-track-property-failed")
                return
            }

            self.waitForPictureInPictureVideoEnabled(handle: handle, attempt: 0) { [weak self] ready, observedVID in
                guard let self else { return }
                self.pictureInPictureVideoTrackSuspended = observedVID == "no"
                guard ready else {
                    DiagnosticsLogger.shared.log("MPVPiP", "video restore unavailable restoreVID=\(restoreVID) observedVID=\(observedVID) currentVO=\(self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown")")
                    self.finishPictureInPictureRendererResume(success: false, actualPosition: nil, reason: "video-track-not-ready")
                    return
                }
                DiagnosticsLogger.shared.log("MPVPiP", "video restore configured restoreVID=\(restoreVID) observedVID=\(observedVID) currentVO=\(self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown") target=\(String(format: "%.3f", targetPosition)) handoff=await-fresh-video-frame")
                self.beginPictureInPictureRendererResumePolling(handle: handle)
            }
        }
    }

    private func waitForPictureInPictureVideoDisabled(handle: OpaquePointer, attempt: Int, completion: @escaping (Bool, String) -> Void) {
        guard let currentHandle = mpv, currentHandle == handle, !isStopping else { completion(false, "detached"); return }
        let currentVID = getStringProperty(handle: handle, name: "vid") ?? "unknown"
        if currentVID == "no" { completion(true, currentVID); return }
        guard attempt < 60 else { completion(false, currentVID); return }
        queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.waitForPictureInPictureVideoDisabled(handle: handle, attempt: attempt + 1, completion: completion) }
    }

    private func waitForPictureInPictureVideoEnabled(handle: OpaquePointer, attempt: Int, completion: @escaping (Bool, String) -> Void) {
        guard let currentHandle = mpv, currentHandle == handle, !isStopping else { completion(false, "detached"); return }
        let currentVID = getStringProperty(handle: handle, name: "vid") ?? "unknown"
        if currentVID != "no" && currentVID != "unknown" { completion(true, currentVID); return }
        guard attempt < 100 else { completion(false, currentVID); return }
        queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.waitForPictureInPictureVideoEnabled(handle: handle, attempt: attempt + 1, completion: completion) }
    }

    private func beginPictureInPictureRendererResumePolling(handle: OpaquePointer) {
        guard pictureInPictureResumeCompletion != nil else { return }
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.pictureInPictureResumeCompletion != nil else { return }
            self.reconcilePictureInPictureVideoState(handle: handle, reason: "fresh-frame-timeout")
            self.finishPictureInPictureRendererResume(success: false, actualPosition: self.snapshot.position, reason: "fresh-frame-timeout")
        }
        pictureInPictureResumeTimeout = timeout
        queue.asyncAfter(deadline: .now() + 2.5, execute: timeout)
        schedulePictureInPictureRendererResumePoll(handle: handle)
    }

    private func cancelPictureInPictureRendererResumeState() {
        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumePoll?.cancel()
        pictureInPictureResumePoll = nil
        pictureInPictureResumeSawPlaybackRestart = false
        pictureInPictureResumeCompletion = nil
        pictureInPictureResumeTargetPosition = nil
        pictureInPictureResumeStartedAt = nil
        pictureInPictureResumePlaybackAdvancing = false
    }

    private func reconcilePictureInPictureVideoState(handle: OpaquePointer, reason: String) {
        let currentVID = getStringProperty(handle: handle, name: "vid") ?? "unknown"
        pictureInPictureVideoTrackSuspended = currentVID == "no"
        if !pictureInPictureVideoTrackSuspended, currentVID != "unknown" { pictureInPictureSuspendedVideoID = nil }
        DiagnosticsLogger.shared.log("MPVPiP", "video state reconciled reason=\(reason) currentVID=\(currentVID) suspended=\(pictureInPictureVideoTrackSuspended) currentVO=\(getStringProperty(handle: handle, name: "current-vo") ?? "unknown")")
    }

    private func finishPictureInPictureRendererResume(success: Bool, actualPosition: Double?, reason: String) {
        guard let completion = pictureInPictureResumeCompletion else { return }
        let handle = mpv
        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumePoll?.cancel()
        pictureInPictureResumePoll = nil
        pictureInPictureResumeSawPlaybackRestart = false
        pictureInPictureResumeCompletion = nil
        let target = pictureInPictureResumeTargetPosition
        pictureInPictureResumeTargetPosition = nil
        pictureInPictureResumeStartedAt = nil
        pictureInPictureResumePlaybackAdvancing = false
        if let handle { reconcilePictureInPictureVideoState(handle: handle, reason: "resume-finish-\(reason)") }
        DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame handoff success=\(success) target=\(target.map { String(format: "%.3f", $0) } ?? "unknown") actual=\(actualPosition.map { String(format: "%.3f", $0) } ?? "unknown") reason=\(reason)")
        DispatchQueue.main.async { completion(success, actualPosition) }
    }

    private func evaluatePictureInPictureRendererResume(handle: OpaquePointer, fallbackPosition: Double?, reason: String) -> Bool {
        guard pictureInPictureResumeCompletion != nil else { return true }
        let currentVO = getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
        let currentVID = getStringProperty(handle: handle, name: "vid") ?? "unknown"
        let viewport = rendererViewportSize(handle: handle)
        var videoPTS = Double.nan
        let hasVideoPTS = getProperty(handle: handle, name: "video-pts", format: MPV_FORMAT_DOUBLE, value: &videoPTS) >= 0 && videoPTS.isFinite
        var timePosition = Double.nan
        let hasTimePosition = getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &timePosition) >= 0 && timePosition.isFinite
        let actualPosition = hasVideoPTS ? videoPTS : (hasTimePosition ? timePosition : (fallbackPosition ?? snapshot.position))
        let target = pictureInPictureResumeTargetPosition
        let elapsed = pictureInPictureResumeStartedAt.map { max(0, CACurrentMediaTime() - $0) } ?? 0
        let expected = target.map { $0 + (pictureInPictureResumePlaybackAdvancing ? elapsed : 0) }
        let delta = expected.map { actualPosition - $0 }
        let positionMatched = delta.map { abs($0) <= 0.85 } ?? true
        let videoEnabled = currentVID != "no" && currentVID != "unknown"
        let freshSignal = pictureInPictureResumeSawPlaybackRestart || (!pictureInPictureResumePlaybackAdvancing && hasVideoPTS)
        let ready = freshSignal && videoEnabled && currentVO.contains("gpu-next") && viewport != nil && positionMatched
        DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame probe reason=\(reason) restartSeen=\(pictureInPictureResumeSawPlaybackRestart) videoEnabled=\(videoEnabled) currentVID=\(currentVID) currentVO=\(currentVO) viewportReady=\(viewport != nil) source=\(hasVideoPTS ? "video-pts" : "time-pos") actual=\(String(format: "%.3f", actualPosition)) target=\(target.map { String(format: "%.3f", $0) } ?? "unknown") expected=\(expected.map { String(format: "%.3f", $0) } ?? "unknown") delta=\(delta.map { String(format: "%.3f", $0) } ?? "unknown") advancing=\(pictureInPictureResumePlaybackAdvancing) ready=\(ready)")
        if ready { finishPictureInPictureRendererResume(success: true, actualPosition: actualPosition, reason: "fresh-video-frame"); return true }
        return false
    }

    private func schedulePictureInPictureRendererResumePoll(handle: OpaquePointer) {
        pictureInPictureResumePoll?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let currentHandle = self.mpv, currentHandle == handle, !self.isStopping, self.pictureInPictureResumeCompletion != nil else { return }
            if self.evaluatePictureInPictureRendererResume(handle: handle, fallbackPosition: nil, reason: "poll") { return }
            self.schedulePictureInPictureRendererResumePoll(handle: handle)
        }
        pictureInPictureResumePoll = work
        queue.asyncAfter(deadline: .now() + 0.02, execute: work)
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
        let displayFPS = Double(max(60, UIScreen.main.maximumFramesPerSecond))
        let plan = PlaybackPresentationPlan(
            requestedRate: clamped,
            sourceFPS: nil,
            displayFPS: displayFPS,
            timingStrategy: clamped > 2 ? .displayCadenced : .audioMaster,
            motionSmoothingMode: .off,
            effectiveMotionTargetFPS: nil,
            videoEnhancementEnabled: false,
            requestedEnhancementFeatures: []
        )
        applyPresentationPlan(plan) { _ in }
    }

    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else {
                completion(.unsupported)
                return
            }

            let displayFPS = min(240, max(30, plan.displayFPS))
            let motionRequested = plan.motionSmoothingRequested && abs(plan.requestedRate - 1) < 0.01
            let timingSignature = PresentationTimingSignature(
                requestedRate: plan.requestedRate,
                displayFPS: displayFPS,
                effectiveMotionTargetFPS: plan.effectiveMotionTargetFPS,
                timingStrategy: plan.timingStrategy
            )

            if self.lastPresentationTimingSignature == timingSignature {
                let enhancementStartedAt = CACurrentMediaTime()
                let activeEnhancementFeatures = self.applyVideoEnhancement(handle: handle, requested: plan.requestedEnhancementFeatures)
                let enhancementApplyMs = (CACurrentMediaTime() - enhancementStartedAt) * 1000
                let actualSync = self.getStringProperty(handle: handle, name: "video-sync") ?? "unknown"
                let actualInterpolation = self.getStringProperty(handle: handle, name: "interpolation") ?? "no"
                let actualDisplayFPS = Double(self.getStringProperty(handle: handle, name: "display-fps") ?? "") ?? displayFPS
                let activeMotionFPS = motionRequested && actualSync.hasPrefix("display-") && actualInterpolation == "yes" ? actualDisplayFPS : nil
                let detail = "sync=\(actualSync), interpolation=\(actualInterpolation), display=\(String(format: "%.2f", actualDisplayFPS))"
                DiagnosticsLogger.shared.log("MPVEnhancement", "phase=enhancement-only requested=\(plan.requestedEnhancementFeatures.map(\.rawValue).joined(separator: ",")) active=\(activeEnhancementFeatures.map(\.rawValue).joined(separator: ",")) applyMs=\(String(format: "%.1f", enhancementApplyMs))")
                completion(PlaybackPresentationAcknowledgement(activeMotionFPS: activeMotionFPS, activeEnhancementFeatures: activeEnhancementFeatures, detail: detail))
                return
            }

            self.playbackRateGeneration &+= 1
            let generation = self.playbackRateGeneration
            var startPosition = Double(0)
            _ = self.getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &startPosition)
            let startedAt = CACurrentMediaTime()
            let startVODrops = self.integerProperty(handle: handle, name: "frame-drop-count")
            let startDecoderDrops = self.integerProperty(handle: handle, name: "decoder-frame-drop-count")
            let sourceFPS = self.resolvedSourceFPS(handle: handle, plannedSourceFPS: plan.sourceFPS)
            let demandedFPS = sourceFPS.map { $0 * plan.requestedRate }
            let exceedsDisplayBudget = demandedFPS.map { $0 > displayFPS * 1.05 } ?? (plan.requestedRate >= 3)
            let decoderPressure = plan.requestedRate > 2 && exceedsDisplayBudget

            self.setProperty(handle: handle, name: "display-fps-override", value: String(format: "%.3f", displayFPS))
            self.setProperty(handle: handle, name: "audio-pitch-correction", value: "yes")

            let highRateMode: String
            if motionRequested {
                self.setProperty(handle: handle, name: "video-sync", value: "display-resample")
                self.setProperty(handle: handle, name: "interpolation", value: "yes")
                self.setProperty(handle: handle, name: "tscale", value: "oversample")
                self.setProperty(handle: handle, name: "framedrop", value: "vo")
                self.setProperty(handle: handle, name: "vd-lavc-framedrop", value: "none")
                highRateMode = "motion-smoothed"
            } else if decoderPressure {
                self.setProperty(handle: handle, name: "video-sync", value: "audio")
                self.setProperty(handle: handle, name: "interpolation", value: "no")
                self.setProperty(handle: handle, name: "framedrop", value: "decoder+vo")
                self.setProperty(handle: handle, name: "vd-lavc-framedrop", value: "nonref")
                highRateMode = "decoder-budgeted"
            } else if plan.requestedRate > 2 {
                self.setProperty(handle: handle, name: "video-sync", value: "display-vdrop")
                self.setProperty(handle: handle, name: "interpolation", value: "no")
                self.setProperty(handle: handle, name: "framedrop", value: "vo")
                self.setProperty(handle: handle, name: "vd-lavc-framedrop", value: "none")
                highRateMode = "display-cadenced"
            } else {
                self.setProperty(handle: handle, name: "video-sync", value: "audio")
                self.setProperty(handle: handle, name: "interpolation", value: "no")
                self.setProperty(handle: handle, name: "framedrop", value: "vo")
                self.setProperty(handle: handle, name: "vd-lavc-framedrop", value: "none")
                highRateMode = "normal"
            }
            self.setProperty(handle: handle, name: "speed", value: String(format: "%.3f", plan.requestedRate))
            self.lastPresentationTimingSignature = timingSignature

            let enhancementStartedAt = CACurrentMediaTime()
            let activeEnhancementFeatures = self.applyVideoEnhancement(handle: handle, requested: plan.requestedEnhancementFeatures)
            let enhancementApplyMs = (CACurrentMediaTime() - enhancementStartedAt) * 1000
            let actualSync = self.getStringProperty(handle: handle, name: "video-sync") ?? "unknown"
            let actualInterpolation = self.getStringProperty(handle: handle, name: "interpolation") ?? "no"
            let actualFramedrop = self.getStringProperty(handle: handle, name: "framedrop") ?? "unknown"
            let actualDecoderDrop = self.getStringProperty(handle: handle, name: "vd-lavc-framedrop") ?? "unknown"
            let actualDisplayFPS = Double(self.getStringProperty(handle: handle, name: "display-fps") ?? "") ?? displayFPS
            let activeMotionFPS = motionRequested && actualSync.hasPrefix("display-") && actualInterpolation == "yes" ? actualDisplayFPS : nil
            let detail = "sync=\(actualSync), interpolation=\(actualInterpolation), display=\(String(format: "%.2f", actualDisplayFPS))"
            let demandedFPSText = demandedFPS.map { String(format: "%.1f", $0) } ?? "unknown"

            DiagnosticsLogger.shared.log("MPVEnhancement", "phase=full-plan requested=\(plan.requestedEnhancementFeatures.map(\.rawValue).joined(separator: ",")) active=\(activeEnhancementFeatures.map(\.rawValue).joined(separator: ",")) applyMs=\(String(format: "%.1f", enhancementApplyMs))")
            DiagnosticsLogger.shared.log(
                "MPVRate",
                "requested=\(String(format: "%.2f", plan.requestedRate)) strategy=\(plan.timingStrategy.rawValue) mode=\(highRateMode) sourceFPS=\(sourceFPS.map { String(format: "%.2f", $0) } ?? "unknown") demandedFPS=\(demandedFPSText) displayFPS=\(String(format: "%.2f", actualDisplayFPS)) videoSync=\(actualSync) framedrop=\(actualFramedrop) decoderDrop=\(actualDecoderDrop) interpolation=\(actualInterpolation) pitchCorrection=yes"
            )

            if self.snapshot.isPlaying {
                self.schedulePlaybackRateHealth(handle: handle, generation: generation, requested: plan.requestedRate, plannedSourceFPS: plan.sourceFPS, startedAt: startedAt, startPosition: startPosition, startVODrops: startVODrops, startDecoderDrops: startDecoderDrops, delay: 1.5)
                self.schedulePlaybackRateHealth(handle: handle, generation: generation, requested: plan.requestedRate, plannedSourceFPS: plan.sourceFPS, startedAt: startedAt, startPosition: startPosition, startVODrops: startVODrops, startDecoderDrops: startDecoderDrops, delay: 4.0)
            }

            completion(PlaybackPresentationAcknowledgement(activeMotionFPS: activeMotionFPS, activeEnhancementFeatures: activeEnhancementFeatures, detail: detail))
        }
    }

    private func resolvedSourceFPS(handle: OpaquePointer, plannedSourceFPS: Double?) -> Double? {
        if let plannedSourceFPS, plannedSourceFPS.isFinite, plannedSourceFPS > 0 { return plannedSourceFPS }
        for name in ["container-fps", "estimated-vf-fps"] {
            if let text = getStringProperty(handle: handle, name: name), let value = Double(text), value.isFinite, value > 0 { return value }
        }
        return nil
    }

    private func applyVideoEnhancement(handle: OpaquePointer, requested: [VideoEnhancementFeature]) -> [VideoEnhancementFeature] {
        if enhancementBaseline == nil, !requested.isEmpty {
            enhancementBaseline = EnhancementBaseline(
                scale: getStringProperty(handle: handle, name: "scale") ?? "bilinear",
                cscale: getStringProperty(handle: handle, name: "cscale") ?? "bilinear",
                deband: getStringProperty(handle: handle, name: "deband") ?? "no",
                sigmoidUpscaling: getStringProperty(handle: handle, name: "sigmoid-upscaling") ?? "no"
            )
        }

        guard let baseline = enhancementBaseline else { return [] }
        if requested.isEmpty {
            setPropertyIfChanged(handle: handle, name: "scale", value: baseline.scale)
            setPropertyIfChanged(handle: handle, name: "cscale", value: baseline.cscale)
            setPropertyIfChanged(handle: handle, name: "deband", value: baseline.deband)
            setPropertyIfChanged(handle: handle, name: "sigmoid-upscaling", value: baseline.sigmoidUpscaling)
            return []
        }

        var active: [VideoEnhancementFeature] = []
        if requested.contains(.upscale) {
            let scaleOK = setPropertyIfChanged(handle: handle, name: "scale", value: "ewa_lanczossharp")
            let sigmoidOK = setPropertyIfChanged(handle: handle, name: "sigmoid-upscaling", value: "yes")
            if scaleOK && sigmoidOK { active.append(.upscale) }
        } else {
            setPropertyIfChanged(handle: handle, name: "scale", value: baseline.scale)
            setPropertyIfChanged(handle: handle, name: "sigmoid-upscaling", value: baseline.sigmoidUpscaling)
        }

        if requested.contains(.chroma) {
            if setPropertyIfChanged(handle: handle, name: "cscale", value: "ewa_lanczossharp") { active.append(.chroma) }
        } else { setPropertyIfChanged(handle: handle, name: "cscale", value: baseline.cscale) }

        if requested.contains(.deband) {
            if setPropertyIfChanged(handle: handle, name: "deband", value: "yes") { active.append(.deband) }
        } else { setPropertyIfChanged(handle: handle, name: "deband", value: baseline.deband) }

        return active
    }

    func setVideoGeometry(panscan: Double, aspectOverride: String?) {
        let clampedPanscan = min(1, max(0, panscan))
        let targetAspect = aspectOverride ?? "no"
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { return }
            self.applyVideoGeometry(handle: handle, panscan: clampedPanscan, aspect: targetAspect)
            DiagnosticsLogger.shared.log("MPVVideo", "geometry panscan=\(String(format: "%.3f", clampedPanscan)) aspect=\(aspectOverride ?? "source")")
            self.queue.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, let handle = self.mpv, !self.isStopping else { return }
                self.logVideoOutputGeometry(handle: handle, reason: "layout")
            }
        }
    }

    func applyRendererLayout(_ request: RendererLayoutRequest, completion: @escaping (RendererLayoutAcknowledgement) -> Void) {
        let targetPanscan = min(1, max(0, request.plan.mpvPanscan))
        let targetAspect = request.plan.mpvAspectOverride ?? "no"
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isStopping else {
                completion(RendererLayoutAcknowledgement(generation: request.generation, matched: false, rendererConfigured: false, actualBackingSize: nil, detail: "engine-stopping"))
                return
            }
            guard let handle = self.mpv else {
                completion(RendererLayoutAcknowledgement(generation: request.generation, matched: true, rendererConfigured: false, actualBackingSize: request.surface.hasObservedBacking ? request.surface.observedBackingSize : nil, detail: "preinit-layout-recorded"))
                return
            }
            guard request.surface.hasObservedBacking else {
                completion(RendererLayoutAcknowledgement(generation: request.generation, matched: false, rendererConfigured: true, actualBackingSize: nil, detail: "surface-backing-not-ready"))
                return
            }

            let phase: PendingRendererLayout.Phase = request.forceRendererRefresh ? .waitingTemporaryReconfig : .waitingTargetReconfig
            let pending = PendingRendererLayout(request: request, completion: completion, targetPanscan: targetPanscan, targetAspect: targetAspect, phase: phase)
            self.pendingRendererLayout = pending

            if request.forceRendererRefresh {
                let temporaryAspect = targetAspect == "no" ? "1:1" : "no"
                self.applyVideoGeometry(handle: handle, panscan: targetPanscan, aspect: temporaryAspect)
                DiagnosticsLogger.shared.log("MPVRenderer", "refresh begin generation=\(request.generation) temporaryAspect=\(temporaryAspect) targetAspect=\(targetAspect) target=\(Int(request.surface.expectedBackingSize.width))x\(Int(request.surface.expectedBackingSize.height))")
                self.queue.asyncAfter(deadline: .now() + 0.08) { [weak self, weak pending] in
                    guard let self, let pending, self.pendingRendererLayout === pending, pending.phase == .waitingTemporaryReconfig, let handle = self.mpv, !self.isStopping else { return }
                    self.applyRendererTarget(handle: handle, pending: pending, reason: "temporary-timeout")
                }
            } else {
                self.applyVideoGeometry(handle: handle, panscan: targetPanscan, aspect: targetAspect)
                DiagnosticsLogger.shared.log("MPVRenderer", "layout apply generation=\(request.generation) aspect=\(targetAspect) panscan=\(String(format: "%.3f", targetPanscan)) target=\(Int(request.surface.expectedBackingSize.width))x\(Int(request.surface.expectedBackingSize.height))")
                self.scheduleRendererViewportPoll(handle: handle, pending: pending, delay: 0.02)
            }
        }
    }

    func seek(to seconds: Double, direction: SeekDirection) {
        let duration = snapshot.duration
        let target = min(max(0, seconds), duration > 0 ? duration : seconds)
        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })
        let intent: String
        switch direction {
        case .forward, .backward: intent = "doubleTapFastSeek"
        case .absolute: intent = "scrubReleaseFastSeek"
        }
        let mode = "absolute+keyframes"
        seekGeneration &+= 1
        let seekID = seekGeneration
        let requestedAt = CACurrentMediaTime()
        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode, dispatchTarget: target, keyframeLookupMs: 0, keyframeAction: "pending", previousKeyframe: nil, nextKeyframe: nil, nearestKeyframe: nil)
        DiagnosticsLogger.shared.log("MPVSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) phase=request intent=\(intent) mode=\(mode) bufferHit=\(bufferHit) enginePosition=\(String(format: "%.3f", snapshot.position)) direction=\(String(describing: direction))")
        snapshot.didReachEnd = false
        snapshot.isBuffering = true
        snapshot.waitingReason = "MPV seek"
        emitOnMain()

        Task { [weak self] in
            guard let self else { return }
            let priorityTask = Task { if let session = self.sharedTransportSession { await session.prioritizeSeek(position: target, duration: duration) } }
            var dispatchTarget = target
            var keyframeAction = "fallback-index-not-ready-or-busy"
            var previousKeyframe: Double?
            var nextKeyframe: Double?
            var nearestKeyframe: Double?
            var keyframeLookupMs = Double(0)

            if let neighbors = self.sessionKeyframeMap.neighbors(around: target) {
                previousKeyframe = neighbors.previous
                nextKeyframe = neighbors.next
                nearestKeyframe = neighbors.nearest
                if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {
                    dispatchTarget = next
                    keyframeAction = "session-gap-nearest-next"
                } else { keyframeAction = "session-gap-nearest-previous-no-change" }
            } else if let index = self.claimKeyframeLookupIndex() {
                let preflightStartedAt = CACurrentMediaTime()
                let race = await self.runKeyframeLookup(index: index, target: target)
                keyframeLookupMs = (CACurrentMediaTime() - preflightStartedAt) * 1000
                switch race {
                case .timeout: keyframeAction = "fallback-time-budget"
                case .probe(.unavailable(let reason)): keyframeAction = "fallback-probe-unavailable:\(reason)"
                case .probe(.ready(let neighbors)):
                    previousKeyframe = neighbors.previous
                    nextKeyframe = neighbors.next
                    nearestKeyframe = neighbors.nearest
                    if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {
                        dispatchTarget = next
                        keyframeAction = "probe-nearest-next"
                    } else if neighbors.previous != nil, neighbors.next != nil { keyframeAction = "probe-nearest-previous-no-change" }
                    else { keyframeAction = "fallback-incomplete-neighbors" }
                }
            }

            _ = await priorityTask.value
            let prioritizedAt = CACurrentMediaTime()
            self.queue.async { [weak self] in
                guard let self, let handle = self.mpv else { return }
                guard var pending = self.pendingSeek, pending.id == seekID else {
                    DiagnosticsLogger.shared.log("MPVFastSeek", "id=\(seekID) phase=dispatch-skipped reason=stale-generation requestedTarget=\(String(format: "%.3f", target))")
                    return
                }
                var finalDispatchTarget = dispatchTarget
                var finalKeyframeAction = keyframeAction
                var finalPreviousKeyframe = previousKeyframe
                var finalNextKeyframe = nextKeyframe
                var finalNearestKeyframe = nearestKeyframe
                if finalKeyframeAction.hasPrefix("fallback-"), let neighbors = self.sessionKeyframeMap.neighbors(around: target) {
                    finalPreviousKeyframe = neighbors.previous
                    finalNextKeyframe = neighbors.next
                    finalNearestKeyframe = neighbors.nearest
                    if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {
                        finalDispatchTarget = next
                        finalKeyframeAction = "dispatch-recheck-nearest-next"
                    } else { finalKeyframeAction = "dispatch-recheck-nearest-previous-no-change" }
                }
                pending.dispatchTarget = finalDispatchTarget
                pending.keyframeLookupMs = keyframeLookupMs
                pending.keyframeAction = finalKeyframeAction
                pending.previousKeyframe = finalPreviousKeyframe
                pending.nextKeyframe = finalNextKeyframe
                pending.nearestKeyframe = finalNearestKeyframe
                self.pendingSeek = pending
                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekEventOwnerID = nil
                let previousText = finalPreviousKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nextText = finalNextKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nearestText = finalNearestKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                DiagnosticsLogger.shared.log("MPVFastSeek", "id=\(seekID) phase=preflight requestedTarget=\(String(format: "%.3f", target)) dispatchTarget=\(String(format: "%.6f", finalDispatchTarget)) previous=\(previousText) next=\(nextText) nearest=\(nearestText) keyframeLookupMs=\(String(format: "%.1f", keyframeLookupMs)) budgetMs=\(String(format: "%.0f", Self.keyframeLookupBudgetMs)) action=\(finalKeyframeAction)")
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\(seekID) phase=native-dispatch owner=awaiting-mpv-event-seek")
                DiagnosticsLogger.shared.log("MPVSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) dispatchTarget=\(String(format: "%.6f", finalDispatchTarget)) phase=native-dispatch prioritizeMs=\(String(format: "%.1f", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\(String(format: "%.1f", (dispatchAt - requestedAt) * 1000)) keyframeLookupMs=\(String(format: "%.1f", keyframeLookupMs)) intent=\(intent) mode=\(mode) bufferHit=\(bufferHit) enginePosition=\(String(format: "%.3f", self.snapshot.position))")
                let dispatchInfo = PlayerPiPSeekDispatchInfo(seekID: seekID, requestedTarget: target, dispatchTarget: finalDispatchTarget, previousKeyframe: finalPreviousKeyframe, nextKeyframe: finalNextKeyframe)
                DispatchQueue.main.async { [weak self] in self?.pictureInPictureSeekDispatchHandler?(dispatchInfo) }
                self.command(handle, ["seek", String(format: "%.6f", finalDispatchTarget), mode])
            }
        }
    }

    private func claimKeyframeLookupIndex() -> OnePlayerKeyframeIndex? {
        let claim = { () -> OnePlayerKeyframeIndex? in
            guard !self.keyframeLookupBusy, self.keyframeBackfillTask == nil, let index = self.keyframeIndex else { return nil }
            self.keyframeLookupBusy = true
            return index
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil { return claim() }
        return queue.sync(execute: claim)
    }

    private func runKeyframeLookup(index: OnePlayerKeyframeIndex, target: Double) async -> KeyframeLookupRaceResult {
        await withCheckedContinuation { continuation in
            let gate = KeyframeLookupGate(continuation: continuation)
            Task { [weak self] in
                let result = await index.neighbors(around: target)
                gate.finish(.probe(result))
                if case .ready(let neighbors) = result, let self { _ = self.sessionKeyframeMap.record(neighbors) }
                self?.queue.async { [weak self] in self?.keyframeLookupBusy = false }
            }
            queue.asyncAfter(deadline: .now() + Self.keyframeLookupBudgetMs / 1000) { gate.finish(.timeout) }
        }
    }

    func reload(at seconds: Double) {
        guard let configuration = lastConfiguration else { return }
        if streamBridge != nil { load(url: configuration.url, headers: configuration.headers, preferredForwardBuffer: configuration.preferredForwardBuffer, startPosition: seconds, compatibilityMode: configuration.compatibilityMode) }
        else { prepareUnifiedStreamAndLoad(url: configuration.url, headers: configuration.headers, preferredForwardBuffer: configuration.preferredForwardBuffer, startPosition: seconds, compatibilityMode: configuration.compatibilityMode) }
    }

    func recoverStall(position: Double, duration: Double) {
        guard let session = sharedTransportSession else { return }
        Task { await session.recoverStall(position: position, duration: duration) }
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        guard let session = sharedTransportSession else { return nil }
        return await session.metrics()
    }

    func stop() {
        guard !isStopping else { return }
        guard let handle = mpv else { return }
        isStopping = true
        DiagnosticsLogger.shared.log("MPVLifecycle", "stop begin")
        mpv_set_wakeup_callback(handle, nil, nil)
        pendingSeek = nil
        latestNativeSeekDispatchID = nil
        activeSeekEventOwnerID = nil
        seekingPropertyActive = false
        keyframeIndexGeneration &+= 1
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeBackfillTask?.cancel()
        keyframeBackfillTask = nil
        keyframeLookupBusy = false
        sessionKeyframeMap.clear()
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt = 0
        keyframeIndexRetrySession = nil
        keyframeIndexRetryContentLength = 0
        keyframeIndex = nil
        pendingRendererLayout = nil
        streamPrepareTask?.cancel()
        streamPrepareTask = nil
        let retainedStreamBridge = streamBridge
        retainedStreamBridge?.cancelAll()
        streamBridge = nil

        let shutdown = { [self] in
            _ = commandSync(handle, ["quit"])
            var drainCount = 0
            while drainCount < 100, let event = mpv_wait_event(handle, 0.02)?.pointee {
                if event.event_id == MPV_EVENT_NONE || event.event_id == MPV_EVENT_SHUTDOWN { break }
                drainCount += 1
            }
            DiagnosticsLogger.shared.log("MPVLifecycle", "events drained=\(drainCount)")
        }

        if DispatchQueue.getSpecific(key: queueKey) != nil { shutdown() }
        else { queue.sync(execute: shutdown) }
        mpv = nil
        snapshot = PlayerSnapshot()
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureVideoTrackSuspended = false
        pictureInPictureSeekLandingHandler = nil
        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumePoll?.cancel()
        pictureInPictureResumePoll = nil
        pictureInPictureResumeSawPlaybackRestart = false
        pictureInPictureResumeCompletion = nil
        pictureInPictureResumeTargetPosition = nil
        pictureInPictureSuspendedVideoID = nil

        let flushLayer = { [displayLayer] in
            displayLayer.contents = nil
            displayLayer.removeAllAnimations()
        }
        if Thread.isMainThread { flushLayer() }
        else { DispatchQueue.main.sync(execute: flushLayer) }

        DispatchQueue.global(qos: .userInitiated).async {
            mpv_terminate_destroy(handle)
            withExtendedLifetime(retainedStreamBridge) {}
            DiagnosticsLogger.shared.log("MPVLifecycle", "terminate_destroy finished")
        }
        DiagnosticsLogger.shared.log("MPVLifecycle", "stop detached")
    }

    private func createMPV() throws {
        guard let handle = mpv_create() else { throw MPVEngineError.creationFailed }
        mpv = handle
        isStopping = false
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureVideoTrackSuspended = false
        pictureInPictureSuspendedVideoID = nil

        check(mpv_request_log_messages(handle, "warn"), operation: "request logs")
        try require(mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &displayLayer), operation: "set CAMetalLayer")
        try require(mpv_set_option_string(handle, "vo", "gpu-next"), operation: "enable gpu-next")
        try require(mpv_set_option_string(handle, "gpu-api", "vulkan"), operation: "set Vulkan GPU API")
        check(mpv_set_option_string(handle, "gpu-context", "moltenvk"), operation: "set MoltenVK context")
        check(mpv_set_option_string(handle, "gpu-shader-cache", "yes"), operation: "enable GPU shader cache")
        if let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let shaderCacheDirectory = cacheRoot.appendingPathComponent("OnePlayer/MPVShaderCache", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: shaderCacheDirectory, withIntermediateDirectories: true)
                check(mpv_set_option_string(handle, "gpu-shader-cache-dir", shaderCacheDirectory.path), operation: "set GPU shader cache directory")
                DiagnosticsLogger.shared.log("MPVEnhancement", "shaderCache=enabled path=\(shaderCacheDirectory.path)")
            } catch {
                DiagnosticsLogger.shared.log("MPVEnhancement", "shaderCache=default reason=\(error.localizedDescription)")
            }
        }
        check(mpv_set_option_string(handle, "libplacebo-opts", "preserve_mixing_cache=yes"), operation: "preserve libplacebo mixing cache")
        check(mpv_set_option_string(handle, "hwdec", "videotoolbox"), operation: "set hwdec")
        check(mpv_set_option_string(handle, "video-rotate", "no"), operation: "disable automatic video rotation")
        check(mpv_set_option_string(handle, "hwdec-codecs", "all"), operation: "set hwdec codecs")
        check(mpv_set_option_string(handle, "hwdec-software-fallback", "yes"), operation: "set hw fallback")
        check(mpv_set_option_string(handle, "video-sync", "audio"), operation: "set audio-master video sync")
        check(mpv_set_option_string(handle, "framedrop", "vo"), operation: "set normal frame drop")
        check(mpv_set_option_string(handle, "vd-lavc-framedrop", "none"), operation: "disable decoder frame drop")
        check(mpv_set_option_string(handle, "audio-pitch-correction", "yes"), operation: "enable pitch correction")
        check(mpv_set_option_string(handle, "cache", "yes"), operation: "enable cache")
        check(mpv_set_option_string(handle, "demuxer-seekable-cache", "yes"), operation: "seekable cache")
        check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "disable precise seek")
        check(mpv_set_option_string(handle, "hr-seek-framedrop", "yes"), operation: "enable precise seek frame drop")
        check(mpv_set_option_string(handle, "network-timeout", "30"), operation: "network timeout")
        check(mpv_set_option_string(handle, "demuxer-termination-timeout", "2"), operation: "demuxer termination timeout")
        check(mpv_set_option_string(handle, "sub-auto", "fuzzy"), operation: "subtitle auto")

        let status = mpv_initialize(handle)
        guard status >= 0 else {
            mpv = nil
            mpv_terminate_destroy(handle)
            throw MPVEngineError.initializationFailed(status)
        }

        DiagnosticsLogger.shared.log("MPVVideo", "renderer=gpu-next gpu-api=vulkan gpu-context=moltenvk layer=CAMetalLayer hwdec=videotoolbox")
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", OnePlayerKeyframeIndexProbe.runtimeDescription)
        observeProperties(handle)
        mpv_set_wakeup_callback(handle, { context in
            guard let context else { return }
            let engine = Unmanaged<MPVPlayerEngine>.fromOpaque(context).takeUnretainedValue()
            engine.processEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func prepareUnifiedStreamAndLoad(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, compatibilityMode: Bool) {
        guard let session = sharedTransportSession else {
            snapshot.errorMessage = "MPV v0.9 实验需要统一媒体传输会话。"
            snapshot.isBuffering = false
            emitOnMain()
            return
        }
        streamPrepareTask?.cancel()
        snapshot.isBuffering = true
        snapshot.waitingReason = "Unified transport preparing"
        emitOnMain()
        streamPrepareTask = Task { [weak self] in
            guard let self else { return }
            do {
                let resource = try await session.resolve()
                guard !Task.isCancelled else { return }
                let bridge = MPVUnifiedStreamBridge(session: session, contentLength: resource.contentLength)
                self.queue.async { [weak self] in
                    guard let self, let handle = self.mpv, !self.isStopping else { return }
                    do {
                        try bridge.register(on: handle)
                        self.streamBridge = bridge
                        DiagnosticsLogger.shared.log("MPVStream", "load unified source finalHost=\(resource.finalURL.host ?? "unknown") bytes=\(resource.contentLength)")
                        self.load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: compatibilityMode)
                    } catch {
                        self.snapshot.errorMessage = error.localizedDescription
                        self.snapshot.isBuffering = false
                        self.emitOnMain()
                    }
                }
            } catch {
                self.snapshot.errorMessage = error.localizedDescription
                self.snapshot.isBuffering = false
                self.emitOnMain()
            }
        }
    }

    private func load(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, compatibilityMode: Bool) {
        snapshot = PlayerSnapshot(position: max(0, startPosition), isBuffering: true, waitingReason: compatibilityMode ? "MPV compatibility loading" : "MPV loading")
        pendingSeek = startPosition > 0 ? PendingSeek(id: 0, requestedAt: CACurrentMediaTime(), target: startPosition, bufferHit: false, intent: "startupResume", mode: "loadfile-start", dispatchTarget: startPosition, keyframeLookupMs: 0, keyframeAction: "startup-resume", previousKeyframe: nil, nextKeyframe: nil, nearestKeyframe: nil) : nil
        emitOnMain()

        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { return }
            self.updateHTTPHeaders(handle: handle, headers: self.streamBridge == nil ? headers : [:])
            let cacheSeconds = max(30, Int(preferredForwardBuffer.rounded()))
            self.setProperty(handle: handle, name: "cache", value: "yes")
            self.setProperty(handle: handle, name: "cache-secs", value: String(cacheSeconds))
            self.setProperty(handle: handle, name: "demuxer-max-bytes", value: "512MiB")

            if compatibilityMode {
                self.setProperty(handle: handle, name: "demuxer-lavf-o", value: "interleaved_read=0")
                self.setProperty(handle: handle, name: "demuxer-seekable-cache", value: "no")
                self.setProperty(handle: handle, name: "demuxer-max-back-bytes", value: "0")
                self.setProperty(handle: handle, name: "cache-pause", value: "no")
                self.setProperty(handle: handle, name: "cache-pause-wait", value: "0")
            } else {
                self.setProperty(handle: handle, name: "demuxer-lavf-o", value: "interleaved_read=1")
                self.setProperty(handle: handle, name: "demuxer-seekable-cache", value: "auto")
                self.setProperty(handle: handle, name: "demuxer-max-back-bytes", value: "128MiB")
                self.setProperty(handle: handle, name: "cache-pause", value: "yes")
                self.setProperty(handle: handle, name: "cache-pause-wait", value: "1")
            }

            self.setProperty(handle: handle, name: "start", value: String(format: "%.3f", max(0, startPosition)))
            DiagnosticsLogger.shared.log("MPVLoad", "mode=\(compatibilityMode ? "bad-interleaved-mp4" : "normal") start=\(startPosition) cacheSecs=\(cacheSeconds)")
            let target: String
            if self.streamBridge != nil { target = "embyunified://media" }
            else if url.isFileURL { target = url.path }
            else { target = url.absoluteString }
            _ = self.commandSync(handle, ["loadfile", target, "replace"])
        }
    }

    private func observeProperties(_ handle: OpaquePointer) {
        let properties: [(String, mpv_format)] = [
            ("duration", MPV_FORMAT_DOUBLE), ("time-pos", MPV_FORMAT_DOUBLE), ("pause", MPV_FORMAT_FLAG),
            ("paused-for-cache", MPV_FORMAT_FLAG), ("demuxer-cache-duration", MPV_FORMAT_DOUBLE),
            ("current-ao", MPV_FORMAT_STRING), ("aid", MPV_FORMAT_STRING), ("audio-params", MPV_FORMAT_STRING),
            ("demuxer-cache-idle", MPV_FORMAT_FLAG), ("seekable", MPV_FORMAT_FLAG), ("partially-seekable", MPV_FORMAT_FLAG),
            ("seeking", MPV_FORMAT_FLAG), ("demuxer-via-network", MPV_FORMAT_FLAG)
        ]
        for (name, format) in properties { mpv_observe_property(handle, 0, name, format) }
    }

    private func processEvents() {
        queue.async { [weak self] in
            guard let self, !self.isStopping else { return }
            while !self.isStopping, let handle = self.mpv, let eventPointer = mpv_wait_event(handle, 0) {
                let event = eventPointer.pointee
                if event.event_id == MPV_EVENT_NONE { break }
                self.handle(event: event, handle: handle)
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
            }
        }
    }

    private func handle(event: mpv_event, handle: OpaquePointer) {
        switch event.event_id {
        case MPV_EVENT_FILE_LOADED:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            logAudioState(handle: handle, reason: "file-loaded")
            logVideoState(handle: handle, reason: "file-loaded")
            if let session = sharedTransportSession, let bridge = streamBridge { startKeyframeIndexSupport(session: session, contentLength: bridge.contentLength) }
            emitOnMain()
        case MPV_EVENT_VIDEO_RECONFIG:
            logVideoOutputGeometry(handle: handle, reason: "video-reconfig")
            handleRendererVideoReconfig(handle: handle)
        case MPV_EVENT_SEEK:
            snapshot.isBuffering = true
            snapshot.waitingReason = "MPV seek"
            if let pending = pendingSeek, pending.id > 0, latestNativeSeekDispatchID == pending.id {
                activeSeekEventOwnerID = pending.id
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\(pending.id) phase=mpv-event-seek owner=claimed")
            } else {
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\(pendingSeek.map { String($0.id) } ?? "none") phase=mpv-event-seek owner=unclaimed nativeOwner=\(latestNativeSeekDispatchID.map(String.init) ?? "none")")
            }
            let pendingText = pendingSeek.map { "id=\($0.id) latestTarget=\(String(format: "%.3f", $0.target))" } ?? "id=none latestTarget=none"
            DiagnosticsLogger.shared.log("MPVSeekEvent", "\(pendingText) position=\(String(format: "%.3f", snapshot.position)) event=seek")
            emitOnMain()
        case MPV_EVENT_PLAYBACK_RESTART:
            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite { actualPosition = queriedPosition }
            if let pending = pendingSeek, pending.id > 0, activeSeekEventOwnerID != pending.id {
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\(pending.id) phase=playback-restart ignored=true reason=no-latest-seek-event-owner actual=\(String(format: "%.3f", actualPosition)) nativeOwner=\(latestNativeSeekDispatchID.map(String.init) ?? "none") seekEventOwner=\(activeSeekEventOwnerID.map(String.init) ?? "none") seeking=\(seekingPropertyActive)")
                return
            }
            snapshot.position = actualPosition
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            if let pending = pendingSeek {
                pendingSeek = nil
                latestNativeSeekDispatchID = nil
                activeSeekEventOwnerID = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\(pending.id) phase=playback-restart accepted=true owner=mpv-event-seek")
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) actual=\(String(format: "%.3f", actualPosition)) delta=\(String(format: "%.3f", delta)) completionMs=\(String(format: "%.1f", latency)) bufferHit=\(pending.bufferHit) intent=\(pending.intent) mode=\(pending.mode) event=playback-restart")
                let previousText = pending.previousKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nextText = pending.nextKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                let nearestText = pending.nearestKeyframe.map { String(format: "%.3f", $0) } ?? "none"
                DiagnosticsLogger.shared.log("MPVFastSeek", "id=\(pending.id) phase=landing requestedTarget=\(String(format: "%.3f", pending.target)) dispatchTarget=\(String(format: "%.6f", pending.dispatchTarget)) actual=\(String(format: "%.3f", actualPosition)) requestedDelta=\(String(format: "%.3f", actualPosition - pending.target)) dispatchDelta=\(String(format: "%.3f", actualPosition - pending.dispatchTarget)) previous=\(previousText) next=\(nextText) nearest=\(nearestText) keyframeLookupMs=\(String(format: "%.1f", pending.keyframeLookupMs)) action=\(pending.keyframeAction)")
                if pending.previousKeyframe == nil || pending.nextKeyframe == nil { self.backfillKeyframeGapAfterLanding(seekID: pending.id, target: pending.target) }
                let result = SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: latency, measurement: "MPV playback-restart after latest MPV_EVENT_SEEK")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(result)
                    self?.pictureInPictureSeekLandingHandler?(result)
                }
            } else { DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\(String(format: "%.3f", actualPosition)) event=playback-restart-without-pending") }
            if pictureInPictureResumeCompletion != nil {
                pictureInPictureResumeSawPlaybackRestart = true
                _ = evaluatePictureInPictureRendererResume(handle: handle, fallbackPosition: actualPosition, reason: "playback-restart")
            }
            emitOnMain()
        case MPV_EVENT_END_FILE:
            if !isStopping {
                var reasonValue: Int32 = -1
                var errorValue: Int32 = 0
                if let data = event.data?.assumingMemoryBound(to: mpv_event_end_file.self) {
                    reasonValue = Int32(data.pointee.reason.rawValue)
                    errorValue = data.pointee.error
                }
                let isRealPlaybackEnd = reasonValue == 0 || reasonValue == 4
                DiagnosticsLogger.shared.log("MPVEndFile", "reason=\(reasonValue) error=\(errorValue) realEnd=\(isRealPlaybackEnd) position=\(snapshot.position) duration=\(snapshot.duration)")
                if isRealPlaybackEnd {
                    snapshot.didReachEnd = true
                    snapshot.isPlaying = false
                    emitOnMain()
                } else { DiagnosticsLogger.shared.log("MPVEndFile", "ignored transition event reason=\(reasonValue)") }
            }
        case MPV_EVENT_PROPERTY_CHANGE:
            if let propertyPointer = event.data?.assumingMemoryBound(to: mpv_event_property.self), let namePointer = propertyPointer.pointee.name {
                let name = String(cString: namePointer)
                if name == "seeking", propertyPointer.pointee.format == MPV_FORMAT_FLAG, let data = propertyPointer.pointee.data {
                    let active = data.assumingMemoryBound(to: Int32.self).pointee != 0
                    handleSeekingPropertyChange(active)
                } else { refreshProperty(name: name, handle: handle) }
            }
        case MPV_EVENT_LOG_MESSAGE:
            if let message = event.data?.assumingMemoryBound(to: mpv_event_log_message.self).pointee {
                let prefix = String(cString: message.prefix)
                let text = String(cString: message.text).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { DiagnosticsLogger.shared.log("MPV", "[\(prefix)] \(text)") }
            }
        case MPV_EVENT_SHUTDOWN: DiagnosticsLogger.shared.log("MPV", "shutdown")
        default: break
        }
    }

    private func handleSeekingPropertyChange(_ active: Bool) {
        seekingPropertyActive = active
        DiagnosticsLogger.shared.log("MPVSeekingState", "active=\(active) pending=\(pendingSeek.map { String($0.id) } ?? "none") nativeOwner=\(latestNativeSeekDispatchID.map(String.init) ?? "none") seekEventOwner=\(activeSeekEventOwnerID.map(String.init) ?? "none")")
    }

    private func startKeyframeIndexSupport(session: TransportDataSession, contentLength: Int64) {
        keyframeIndexGeneration &+= 1
        let generation = keyframeIndexGeneration
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeBackfillTask?.cancel()
        keyframeBackfillTask = nil
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt = 0
        sessionKeyframeMap.clear()
        keyframeIndexRetrySession = session
        keyframeIndexRetryContentLength = contentLength
        keyframeIndex = nil
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=scheduled generation=\(generation) attempt=1 delayMs=0 bytes=\(contentLength) mode=cache-only")
        attemptKeyframeIndexBuild(generation: generation)
    }

    private func attemptKeyframeIndexBuild(generation: UInt64) {
        guard !isStopping, keyframeIndexGeneration == generation, keyframeIndex == nil, keyframeIndexTask == nil, let session = keyframeIndexRetrySession, keyframeIndexRetryContentLength > 0 else { return }
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt += 1
        let attempt = keyframeIndexRetryAttempt
        let contentLength = keyframeIndexRetryContentLength
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=starting generation=\(generation) attempt=\(attempt) bytes=\(contentLength) mode=cache-only")
        keyframeIndexTask = Task { [weak self] in
            let result = await OnePlayerKeyframeIndexProbe.buildIndex(session: session, contentLength: contentLength)
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                guard let self, !self.isStopping, self.keyframeIndexGeneration == generation else { return }
                self.keyframeIndexTask = nil
                switch result {
                case .ready(let index):
                    self.keyframeIndex = index
                    self.keyframeIndexRetryWorkItem?.cancel()
                    self.keyframeIndexRetryWorkItem = nil
                    self.keyframeIndexRetrySession = nil
                    self.keyframeIndexRetryContentLength = 0
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=ready generation=\(generation) attempt=\(attempt) mode=\(index.mode) stream=\(index.videoStreamIndex) timeBase=\(String(format: "%.9f", index.timeBaseSeconds)) streamStart=\(String(format: "%.3f", index.streamStartSeconds)) action=fast-seek-support")
                case .unavailable(let reason):
                    self.keyframeIndex = nil
                    guard attempt <= Self.keyframeIndexRetryDelays.count else {
                        self.keyframeIndexRetrySession = nil
                        self.keyframeIndexRetryContentLength = 0
                        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=unavailable-final generation=\(generation) attempts=\(attempt) reason=\(reason) action=fast-seek-support")
                        return
                    }
                    let delay = Self.keyframeIndexRetryDelays[attempt - 1]
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=retry-pending generation=\(generation) attempt=\(attempt) nextAttempt=\(attempt + 1) delayMs=\(Int(delay * 1000)) reason=\(reason) action=fast-seek-support")
                    let work = DispatchWorkItem { [weak self] in self?.attemptKeyframeIndexBuild(generation: generation) }
                    self.keyframeIndexRetryWorkItem = work
                    self.queue.asyncAfter(deadline: .now() + delay, execute: work)
                }
            }
        }
    }

    private func backfillKeyframeGapAfterLanding(seekID: UInt64, target: Double) {
        guard let index = keyframeIndex, keyframeBackfillTask == nil, !keyframeLookupBusy else { return }
        keyframeBackfillTask = Task { [weak self] in
            let result = await index.neighbors(around: target)
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                guard let self, !self.isStopping else { return }
                self.keyframeBackfillTask = nil
                switch result {
                case .ready(let neighbors):
                    let gapCount = self.sessionKeyframeMap.record(neighbors)
                    DiagnosticsLogger.shared.log("MPVKeyframeBackfill", "id=\(seekID) target=\(String(format: "%.3f", target)) result=recorded gapCount=\(gapCount)")
                case .unavailable(let reason): DiagnosticsLogger.shared.log("MPVKeyframeBackfill", "id=\(seekID) target=\(String(format: "%.3f", target)) result=unavailable reason=\(reason)")
                }
            }
        }
    }

    private func refreshProperty(name: String, handle: OpaquePointer) {
        switch name {
        case "duration":
            var value = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value) >= 0, value.isFinite, value > 0 {
                snapshot.duration = value
                rebuildBufferedRange()
                emitOnMain()
            }
        case "time-pos":
            var value = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value) >= 0, value.isFinite {
                snapshot.position = value
                rebuildBufferedRange()
                let now = CACurrentMediaTime()
                if pendingSeek != nil || now - lastPositionEmission >= 0.25 {
                    lastPositionEmission = now
                    emitOnMain()
                }
            }
        case "pause":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 {
                snapshot.isPlaying = flag == 0
                emitOnMain()
            }
        case "paused-for-cache":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 {
                snapshot.isBuffering = flag != 0
                snapshot.waitingReason = flag != 0 ? "MPV paused-for-cache" : nil
                emitOnMain()
            }
        case "demuxer-cache-duration":
            var seconds = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &seconds) >= 0, seconds.isFinite {
                let end = max(snapshot.position, snapshot.position + max(0, seconds))
                snapshot.bufferedRanges = [snapshot.position...end]
                emitOnMain()
            }
        case "current-ao", "aid", "audio-params":
            let value = getStringProperty(handle: handle, name: name) ?? "nil"
            DiagnosticsLogger.shared.log("MPVAudio", "\(name)=\(value)")
        case "demuxer-cache-idle", "seekable", "partially-seekable", "demuxer-via-network":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 { DiagnosticsLogger.shared.log("MPVNetwork", "\(name)=\(flag != 0)") }
        default: break
        }
    }

    private func rebuildBufferedRange() {
        guard let current = snapshot.bufferedRanges.first else { return }
        let length = max(0, current.upperBound - current.lowerBound)
        snapshot.bufferedRanges = [snapshot.position...(snapshot.position + length)]
    }

    private func getStringProperty(handle: OpaquePointer, name: String) -> String? {
        guard let pointer = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(pointer) }
        return String(cString: pointer)
    }

    private func integerProperty(handle: OpaquePointer, name: String) -> Int64 {
        if let value = getStringProperty(handle: handle, name: name), let parsed = Int64(value) { return parsed }
        var value = Int64(0)
        _ = getProperty(handle: handle, name: name, format: MPV_FORMAT_INT64, value: &value)
        return value
    }

    private func logAudioState(handle: OpaquePointer, reason: String) {
        let currentAO = getStringProperty(handle: handle, name: "current-ao") ?? "nil"
        let aid = getStringProperty(handle: handle, name: "aid") ?? "nil"
        let audioParams = getStringProperty(handle: handle, name: "audio-params") ?? "nil"
        DiagnosticsLogger.shared.log("MPVAudio", "reason=\(reason) currentAO=\(currentAO) aid=\(aid) audioParams=\(audioParams)")
    }

    private func logVideoOutputGeometry(handle: OpaquePointer, reason: String) {
        let osdWidth = getStringProperty(handle: handle, name: "osd-width") ?? "nil"
        let osdHeight = getStringProperty(handle: handle, name: "osd-height") ?? "nil"
        let dwidth = getStringProperty(handle: handle, name: "dwidth") ?? "nil"
        let dheight = getStringProperty(handle: handle, name: "dheight") ?? "nil"
        let panscan = getStringProperty(handle: handle, name: "panscan") ?? "nil"
        let aspectOverride = getStringProperty(handle: handle, name: "video-aspect-override") ?? "nil"
        DiagnosticsLogger.shared.log("MPVViewport", "reason=\(reason) osd=\(osdWidth)x\(osdHeight) display=\(dwidth)x\(dheight) panscan=\(panscan) aspectOverride=\(aspectOverride)")
    }

    private func rendererViewportSize(handle: OpaquePointer) -> CGSize? {
        guard let widthText = getStringProperty(handle: handle, name: "osd-width"), let width = Double(widthText), width > 1,
              let heightText = getStringProperty(handle: handle, name: "osd-height"), let height = Double(heightText), height > 1 else { return nil }
        return CGSize(width: width, height: height)
    }

    private func applyVideoGeometry(handle: OpaquePointer, panscan: Double, aspect: String) {
        setProperty(handle: handle, name: "video-unscaled", value: "no")
        setProperty(handle: handle, name: "video-aspect-override", value: aspect)
        setProperty(handle: handle, name: "panscan", value: String(format: "%.3f", panscan))
    }

    private func handleRendererVideoReconfig(handle: OpaquePointer) {
        guard let pending = pendingRendererLayout else { return }
        DiagnosticsLogger.shared.log("MPVRenderer", "video-reconfig generation=\(pending.request.generation) phase=\(pending.phase.rawValue)")
        switch pending.phase {
        case .waitingTemporaryReconfig: applyRendererTarget(handle: handle, pending: pending, reason: "temporary-reconfig")
        case .waitingTargetReconfig, .polling:
            pending.phase = .polling
            scheduleRendererViewportPoll(handle: handle, pending: pending, delay: 0)
        }
    }

    private func applyRendererTarget(handle: OpaquePointer, pending: PendingRendererLayout, reason: String) {
        guard pendingRendererLayout === pending else { return }
        pending.phase = .waitingTargetReconfig
        applyVideoGeometry(handle: handle, panscan: pending.targetPanscan, aspect: pending.targetAspect)
        DiagnosticsLogger.shared.log("MPVRenderer", "target apply generation=\(pending.request.generation) reason=\(reason) aspect=\(pending.targetAspect) panscan=\(String(format: "%.3f", pending.targetPanscan))")
        scheduleRendererViewportPoll(handle: handle, pending: pending, delay: 0.02)
    }

    private func scheduleRendererViewportPoll(handle: OpaquePointer, pending: PendingRendererLayout, delay: TimeInterval) {
        guard pendingRendererLayout === pending else { return }
        queue.asyncAfter(deadline: .now() + delay) { [weak self, weak pending] in
            guard let self, let pending, self.pendingRendererLayout === pending, let currentHandle = self.mpv, currentHandle == handle, !self.isStopping else { return }
            pending.phase = .polling
            pending.pollAttempt += 1
            let actual = self.rendererViewportSize(handle: handle)
            let target = pending.request.surface.expectedBackingSize
            if let actual, RendererSurfaceGeometry.matches(actual, target, tolerance: 4) {
                self.logVideoOutputGeometry(handle: handle, reason: "renderer-ack")
                self.finishRendererLayout(pending: pending, matched: true, actual: actual, detail: "viewport-match")
                return
            }
            if pending.pollAttempt >= 24 {
                self.logVideoOutputGeometry(handle: handle, reason: "renderer-timeout")
                self.finishRendererLayout(pending: pending, matched: false, actual: actual, detail: "viewport-timeout")
                return
            }
            self.scheduleRendererViewportPoll(handle: handle, pending: pending, delay: 0.025)
        }
    }

    private func finishRendererLayout(pending: PendingRendererLayout, matched: Bool, actual: CGSize?, detail: String) {
        guard pendingRendererLayout === pending else { return }
        pendingRendererLayout = nil
        pending.completion(RendererLayoutAcknowledgement(generation: pending.request.generation, matched: matched, rendererConfigured: true, actualBackingSize: actual, detail: detail))
    }

    private func logVideoState(handle: OpaquePointer, reason: String) {
        let width = getStringProperty(handle: handle, name: "width") ?? "nil"
        let height = getStringProperty(handle: handle, name: "height") ?? "nil"
        let dwidth = getStringProperty(handle: handle, name: "dwidth") ?? "nil"
        let dheight = getStringProperty(handle: handle, name: "dheight") ?? "nil"
        let rotate = getStringProperty(handle: handle, name: "video-rotate") ?? "nil"
        let aspect = getStringProperty(handle: handle, name: "video-aspect") ?? "nil"
        let hwdec = getStringProperty(handle: handle, name: "hwdec-current") ?? "nil"
        let params = getStringProperty(handle: handle, name: "video-out-params") ?? getStringProperty(handle: handle, name: "video-params") ?? "nil"
        DiagnosticsLogger.shared.log("MPVVideoState", "reason=\(reason) size=\(width)x\(height) display=\(dwidth)x\(dheight) rotate=\(rotate) aspect=\(aspect) hwdec=\(hwdec) params=\(params)")
    }

    private func schedulePlaybackRateHealth(handle: OpaquePointer, generation: UInt64, requested: Double, plannedSourceFPS: Double?, startedAt: TimeInterval, startPosition: Double, startVODrops: Int64, startDecoderDrops: Int64, delay: TimeInterval) {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.playbackRateGeneration == generation, let currentHandle = self.mpv, currentHandle == handle, !self.isStopping else { return }
            var currentPosition = Double(0)
            guard self.getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &currentPosition) >= 0, currentPosition.isFinite else { return }
            let elapsed = max(0.001, CACurrentMediaTime() - startedAt)
            let actualRate = max(0, (currentPosition - startPosition) / elapsed)
            let avsync = self.getStringProperty(handle: handle, name: "avsync") ?? "nil"
            let voDrops = self.integerProperty(handle: handle, name: "frame-drop-count")
            let decoderDrops = self.integerProperty(handle: handle, name: "decoder-frame-drop-count")
            let sourceFPS = plannedSourceFPS.map { String(format: "%.3f", $0) } ?? self.getStringProperty(handle: handle, name: "container-fps") ?? self.getStringProperty(handle: handle, name: "estimated-vf-fps") ?? "nil"
            let displayFPS = self.getStringProperty(handle: handle, name: "display-fps") ?? "nil"
            let displaySyncActive = self.getStringProperty(handle: handle, name: "display-sync-active") ?? "nil"
            let vsyncRatio = self.getStringProperty(handle: handle, name: "vsync-ratio") ?? "nil"
            let delayedFrames = self.getStringProperty(handle: handle, name: "vo-delayed-frame-count") ?? "nil"
            let hwdec = self.getStringProperty(handle: handle, name: "hwdec-current") ?? "nil"
            DiagnosticsLogger.shared.log("MPVRateHealth", "requested=\(String(format: "%.2f", requested)) actual=\(String(format: "%.2f", actualRate)) sample=\(String(format: "%.1f", elapsed))s avsync=\(avsync) voDropsDelta=\(max(0, voDrops - startVODrops)) decoderDropsDelta=\(max(0, decoderDrops - startDecoderDrops)) sourceFPS=\(sourceFPS) displayFPS=\(displayFPS) displaySync=\(displaySyncActive) vsyncRatio=\(vsyncRatio) delayed=\(delayedFrames) hwdec=\(hwdec)")
        }
    }

    private func updateHTTPHeaders(handle: OpaquePointer, headers: [String: String]) {
        guard !headers.isEmpty else {
            mpv_set_property(handle, "http-header-fields", MPV_FORMAT_NONE, nil)
            return
        }
        let value = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
        setProperty(handle: handle, name: "http-header-fields", value: value)
    }

    private func setPropertyAsync(name: String, value: String) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.setProperty(handle: handle, name: name, value: value)
        }
    }

    @discardableResult
    private func setPropertyIfChanged(handle: OpaquePointer, name: String, value: String) -> Bool {
        if getStringProperty(handle: handle, name: name) == value { return true }
        return setPropertyChecked(handle: handle, name: name, value: value)
    }

    @discardableResult
    private func setPropertyChecked(handle: OpaquePointer, name: String, value: String) -> Bool {
        let status = mpv_set_property_string(handle, name, value)
        check(status, operation: "set \(name)=\(value)")
        return status >= 0
    }

    private func setProperty(handle: OpaquePointer, name: String, value: String) { _ = setPropertyChecked(handle: handle, name: name, value: value) }

    private func command(_ handle: OpaquePointer, _ arguments: [String]) {
        guard !arguments.isEmpty else { return }
        withCStringArray(arguments) { pointer in _ = mpv_command_async(handle, 0, pointer) }
    }

    @discardableResult
    private func commandSync(_ handle: OpaquePointer, _ arguments: [String]) -> Int32 {
        guard !arguments.isEmpty else { return -1 }
        return withCStringArray(arguments) { pointer in mpv_command(handle, pointer) }
    }

    @discardableResult
    private func getProperty<T>(handle: OpaquePointer, name: String, format: mpv_format, value: inout T) -> Int32 {
        withUnsafeMutablePointer(to: &value) { pointer in mpv_get_property(handle, name, format, pointer) }
    }

    private func check(_ status: Int32, operation: String) {
        guard status < 0 else { return }
        let message = String(cString: mpv_error_string(status))
        DiagnosticsLogger.shared.log("MPV", "\(operation) failed: \(message) (\(status))")
    }

    private func require(_ status: Int32, operation: String) throws {
        guard status < 0 else { return }
        let message = String(cString: mpv_error_string(status))
        DiagnosticsLogger.shared.log("MPV", "\(operation) failed: \(message) (\(status))")
        throw MPVEngineError.requiredVideoOutputUnavailable(operation, status, message)
    }

    private func emitOnMain() {
        let value = snapshot
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(value) }
    }

    @inline(__always)
    private func withCStringArray<Result>(_ arguments: [String], body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Result) -> Result {
        var strings = arguments.map { strdup($0) }
        strings.append(nil)
        defer { for pointer in strings where pointer != nil { free(pointer) } }
        return strings.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) { rebound in body(UnsafeMutablePointer(mutating: rebound)) }
        }
    }
}

enum MPVEngineError: LocalizedError {
    case creationFailed
    case initializationFailed(Int32)
    case requiredVideoOutputUnavailable(String, Int32, String)

    var errorDescription: String? {
        switch self {
        case .creationFailed: return "无法创建 MPV 实例。"
        case .initializationFailed(let status): return "MPV 初始化失败：\(status)。"
        case .requiredVideoOutputUnavailable(let operation, let status, let message): return "MPV 视频输出不可用：\(operation)，\(message)（\(status)）。"
        }
    }
}

#else
final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling, PlayerPiPSeekLandingProviding {
    let kind: PlayerEngineKind = .mpv
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?
    var pictureInPictureSeekDispatchHandler: ((PlayerPiPSeekDispatchInfo) -> Void)?
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)?
    var displayLayer = MPVMetalLayer()

    private var snapshot = PlayerSnapshot(errorMessage: "当前构建未链接 MPVKit；v0.9 自动模式需要 MPVKit。")

    init(sharedTransportSession: TransportDataSession? = nil) {
        displayLayer.backgroundColor = UIColor.black.cgColor
        displayLayer.contentsScale = UIScreen.main.nativeScale
        displayLayer.framebufferOnly = true
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        snapshot.position = max(0, startPosition)
        snapshot.errorMessage = "当前构建未链接 MPVKit；v0.9 自动模式需要 MPVKit。"
        emit()
    }

    func reloadForBadInterleavedMP4(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, reason: String) { prepare(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition) }
    func play() {}
    func pause() {}
    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) { completion(false) }
    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) { completion(false) }
    func setVideoGeometry(panscan: Double, aspectOverride: String?) {}
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) { completion(.unsupported) }

    func applyRendererLayout(_ request: RendererLayoutRequest, completion: @escaping (RendererLayoutAcknowledgement) -> Void) {
        completion(RendererLayoutAcknowledgement(generation: request.generation, matched: true, rendererConfigured: false, actualBackingSize: nil, detail: "mpv-unavailable"))
    }

    func seek(to seconds: Double, direction: SeekDirection) {
        let requestedAt = CACurrentMediaTime()
        snapshot.position = max(0, seconds)
        pictureInPictureSeekDispatchHandler?(PlayerPiPSeekDispatchInfo(seekID: 0, requestedTarget: seconds, dispatchTarget: seconds, previousKeyframe: nil, nextKeyframe: nil))
        let result = SeekResult(requestedAt: requestedAt, target: seconds, actualPosition: nil, bufferHit: false, completionLatencyMs: 0, measurement: "MPV unavailable in this build")
        onSeekCompleted?(result)
        pictureInPictureSeekLandingHandler?(result)
        emit()
    }

    func reload(at seconds: Double) { snapshot.position = max(0, seconds); emit() }
    func stop() { displayLayer.contents = nil; snapshot = PlayerSnapshot() }

    private func emit() {
        let value = snapshot
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(value) }
    }
}
#endif
