from pathlib import Path
import re

coordinator_path = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
coordinator = coordinator_path.read_text()

# Build160 owns one visible SampleBuffer source surface during the whole inline <-> PiP handoff.
field_anchor = "    private var homeRequested = false\n"
extra_fields = """    private var restoreRequested = false
    private var systemPiPStopped = false
    private var rendererRestoreInProgress = false
    private var rendererRestoreReady = false
    private var rendererRestoreActualPosition: Double?
    private var rendererRestoreAttempt = 0
    private var pendingSeekAuthoritativePosition: Double?
    private var pendingSeekLandingHostTime: CFTimeInterval?
"""
if "private var restoreRequested = false" not in coordinator:
    if coordinator.count(field_anchor) != 1:
        raise SystemExit("Build160 coordinator field anchor mismatch")
    coordinator = coordinator.replace(field_anchor, field_anchor + extra_fields, 1)

# When the authoritative MPV landing is known, remember the host-clock instant. The SampleBuffer
# timebase is rebased to landing + elapsed when the first target frame becomes visible.
old = """        let authoritative = max(0, result.actualPosition ?? result.target)
        displayLayer?.flush()
        activeGeneration = pipeline.seek(to: authoritative)
        pendingSkipGeneration = activeGeneration
        logicalPiPPosition = authoritative
"""
new = """        let authoritative = max(0, result.actualPosition ?? result.target)
        pendingSeekAuthoritativePosition = authoritative
        pendingSeekLandingHostTime = CACurrentMediaTime()
        displayLayer?.flush()
        activeGeneration = pipeline.seek(to: authoritative)
        pendingSkipGeneration = activeGeneration
        logicalPiPPosition = authoritative
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

# Fallback engines get the same clock treatment.
old = """            let authoritative = max(0, current)
            if let pipeline {
                displayLayer?.flush()
                activeGeneration = pipeline.seek(to: authoritative)
"""
new = """            let authoritative = max(0, current)
            pendingSeekAuthoritativePosition = authoritative
            pendingSeekLandingHostTime = CACurrentMediaTime()
            if let pipeline {
                displayLayer?.flush()
                activeGeneration = pipeline.seek(to: authoritative)
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

# A new skip invalidates the previous rebase point.
old = """        pendingSkipGeneration = nil
        pendingSeekStartedPosition = playbackController.snapshot.position
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
"""
new = """        pendingSkipGeneration = nil
        pendingSeekStartedPosition = playbackController.snapshot.position
        pendingSeekAuthoritativePosition = nil
        pendingSeekLandingHostTime = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

# Rebase the PiP control timebase to the engine landing plus real elapsed time, not merely the first
# SampleBuffer PTS. This keeps MPV audio and SampleBuffer video on one post-seek clock.
old = """            if let timebase = controlTimebase {
                CMTimebaseSetTime(timebase, time: CMTime(seconds: envelope.pts, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
            }
            pipeline?.setPaused(!pipWantsPlayback)
"""
new = """            if let timebase = controlTimebase {
                let elapsed = pendingSeekLandingHostTime.map { pipWantsPlayback ? max(0, CACurrentMediaTime() - $0) : 0 } ?? 0
                let alignedClock = pendingSeekAuthoritativePosition.map { $0 + elapsed } ?? envelope.pts
                CMTimebaseSetTime(timebase, time: CMTime(seconds: alignedClock, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
                logicalPiPPosition = alignedClock
                DiagnosticsLogger.shared.playback("PiPSession", "seek clock-rebase samplePts=\\(String(format: \"%.3f\", envelope.pts)) authoritative=\\(pendingSeekAuthoritativePosition.map { String(format: \"%.3f\", $0) } ?? \"unknown\") elapsed=\\(String(format: \"%.3f\", elapsed)) clock=\\(String(format: \"%.3f\", alignedClock))")
            }
            pendingSeekAuthoritativePosition = nil
            pendingSeekLandingHostTime = nil
            pipeline?.setPaused(!pipWantsPlayback)
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

# Expose the actual PiP media clock for restore. Packet read-ahead is not an authoritative position.
clock_helper = """
    private func currentPiPClockPosition() -> Double {
        if let timebase = controlTimebase {
            let value = CMTimeGetSeconds(CMTimebaseGetTime(timebase))
            if value.isFinite, value >= 0 { return value }
        }
        return max(0, logicalPiPPosition)
    }

"""
if "private func currentPiPClockPosition()" not in coordinator:
    marker = "    private func handleForegroundActive() {\n"
    if coordinator.count(marker) != 1:
        raise SystemExit("Build160 foreground marker mismatch")
    coordinator = coordinator.replace(marker, clock_helper + marker, 1)

# The system restore callback must complete immediately so iOS can foreground the app. The visible
# SampleBuffer source remains the transition cover while MPV resumes underneath it.
restore_pattern = re.compile(r"    func pictureInPictureController\(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping \(Bool\) -> Void\) \{.*?\n    \}\n\n    func pictureInPictureController\(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError", re.S)
restore_replacement = """    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        state = .restoring
        restoreRequested = true
        systemPiPStopped = false
        rendererRestoreReady = false
        rendererRestoreActualPosition = nil
        rendererRestoreAttempt = 0
        let target = currentPiPClockPosition()
        logicalPiPPosition = target
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\\(UIApplication.shared.applicationState.rawValue) target=\\(String(format: \"%.3f\", target)) policy=system-first-cover-until-fresh-frame")
        completionHandler(true)
        beginRestoreHandoffIfPossible()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError"""
coordinator, count = restore_pattern.subn(restore_replacement, coordinator, count=1)
if count != 1:
    raise SystemExit("Build160 restore callback replacement mismatch")

# didStop must not tear down the SampleBuffer pipeline during an inline restore. It only marks the
# system transition as finished; the cover is removed after MPV proves a fresh frame.
didstop_pattern = re.compile(r"    func pictureInPictureControllerDidStopPictureInPicture\(_ pictureInPictureController: AVPictureInPictureController\) \{.*?\n    \}\n\n    func pictureInPictureController\(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler", re.S)
didstop_replacement = """    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        let previousState = state
        let position = currentPiPClockPosition()
        logicalPiPPosition = position
        systemPiPStopped = true
        DiagnosticsLogger.shared.playback("PiPSession", "system-stopped position=\\(String(format: \"%.3f\", position)) appState=\\(UIApplication.shared.applicationState.rawValue) previousState=\\(previousState.rawValue) restoreRequested=\\(restoreRequested)")
        if restoreRequested || previousState == .restoring {
            state = .restoring
            beginRestoreHandoffIfPossible()
            finishRestoreHandoffIfReady()
            return
        }
        state = .stopping
        pipeline?.stop()
        restoreInlineRendererWhenForeground(reason: "system-stopped", targetPosition: position) { [weak self] _, _ in self?.reset(reason: "system-stopped") }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler"""
coordinator, count = didstop_pattern.subn(didstop_replacement, coordinator, count=1)
if count != 1:
    raise SystemExit("Build160 didStop replacement mismatch")

# Insert the restore state machine before the current clock helper.
restore_helpers = """
    private func beginRestoreHandoffIfPossible() {
        guard restoreRequested, !rendererRestoreReady, !rendererRestoreInProgress else { finishRestoreHandoffIfReady(); return }
        let target = currentPiPClockPosition()
        logicalPiPPosition = target
        rendererRestoreInProgress = true
        rendererRestoreAttempt += 1
        let attempt = rendererRestoreAttempt
        DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff begin attempt=\\(attempt) target=\\(String(format: \"%.3f\", target)) appState=\\(UIApplication.shared.applicationState.rawValue)")
        restoreInlineRendererWhenForeground(reason: "restore-ui", targetPosition: target) { [weak self] success, actualPosition in
            guard let self else { return }
            self.rendererRestoreInProgress = false
            self.rendererRestoreActualPosition = actualPosition
            if success {
                self.rendererRestoreReady = true
                self.finishRestoreHandoffIfReady()
                return
            }
            guard self.restoreRequested, self.rendererRestoreAttempt < 2 else {
                DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff failed attempts=\\(self.rendererRestoreAttempt) action=keep-samplebuffer-cover")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in self?.beginRestoreHandoffIfPossible() }
        }
    }

    private func finishRestoreHandoffIfReady() {
        guard restoreRequested, systemPiPStopped, rendererRestoreReady else { return }
        restoreRequested = false
        pipeline?.stop()
        let actual = rendererRestoreActualPosition
        DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff visual-release actual=\\(actual.map { String(format: \"%.3f\", $0) } ?? \"unknown\") action=fade-samplebuffer-cover")
        guard let host = sourceHostView, host.alpha > 0.001 else { reset(reason: "restore-handoff-complete"); return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]) {
            host.alpha = 0
        } completion: { [weak self] _ in
            Task { @MainActor in self?.reset(reason: "restore-handoff-complete") }
        }
    }

"""
if "private func beginRestoreHandoffIfPossible()" not in coordinator:
    marker = "    private func currentPiPClockPosition() -> Double {\n"
    if coordinator.count(marker) != 1:
        raise SystemExit("Build160 restore helper marker mismatch")
    coordinator = coordinator.replace(marker, restore_helpers + marker, 1)

# Foreground activation resumes a deferred renderer restore, then advances the explicit restore FSM.
old = """    private func handleForegroundActive() {
        let pending = pendingForegroundRestore
        pendingForegroundRestore = nil
        pending?()
    }
"""
new = """    private func handleForegroundActive() {
        let pending = pendingForegroundRestore
        pendingForegroundRestore = nil
        pending?()
        if restoreRequested { beginRestoreHandoffIfPossible() }
    }
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

# Reset all handoff/seek-clock state.
old = """        pendingSeekStartedPosition = nil
        pendingForegroundRestore = nil
        possibleObservation = nil
"""
new = """        pendingSeekStartedPosition = nil
        pendingSeekAuthoritativePosition = nil
        pendingSeekLandingHostTime = nil
        pendingForegroundRestore = nil
        restoreRequested = false
        systemPiPStopped = false
        rendererRestoreInProgress = false
        rendererRestoreReady = false
        rendererRestoreActualPosition = nil
        rendererRestoreAttempt = 0
        possibleObservation = nil
"""
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

required = [
    'sourceSurface=visible-native-transition',
    'policy=wait-authoritative-engine-landing',
    'policy=system-first-cover-until-fresh-frame',
    'private func beginRestoreHandoffIfPossible()',
    'private func finishRestoreHandoffIfReady()',
    'seek clock-rebase',
]
for token in required:
    if token not in coordinator:
        raise SystemExit(f"Build160 coordinator finalization missing: {token}")
if 'fresh-frame-before-system-completion' in coordinator:
    raise SystemExit("Build160 must not block the system restore callback on renderer readiness")
coordinator_path.write_text(coordinator)

mpv_path = Path("Sources/Player/MPVPlayerEngine.swift")
mpv = mpv_path.read_text()

field_anchor = "    private var pictureInPictureResumeTimeout: DispatchWorkItem?\n"
extra = """    private var pictureInPictureResumePoll: DispatchWorkItem?
    private var pictureInPictureResumeSawPlaybackRestart = false
"""
if "private var pictureInPictureResumePoll" not in mpv:
    if mpv.count(field_anchor) != 1:
        raise SystemExit("Build160 MPV resume field anchor mismatch")
    mpv = mpv.replace(field_anchor, field_anchor + extra, 1)

# Reset resume polling whenever PiP suspends again.
old = """            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumeTimeout = nil
            self.pictureInPictureResumeCompletion = nil
            self.pictureInPictureResumeTargetPosition = nil
"""
new = """            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumeTimeout = nil
            self.pictureInPictureResumePoll?.cancel()
            self.pictureInPictureResumePoll = nil
            self.pictureInPictureResumeSawPlaybackRestart = false
            self.pictureInPictureResumeCompletion = nil
            self.pictureInPictureResumeTargetPosition = nil
"""
if old in mpv:
    mpv = mpv.replace(old, new, 1)

# The resume completion is renderer-backed: VO configured + playback restart seen + video PTS close
# to the PiP authoritative clock. A short poll handles the normal catch-up after playback-restart.
old = """            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumeCompletion = completion
            self.pictureInPictureResumeTargetPosition = max(0, targetPosition)
"""
new = """            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumePoll?.cancel()
            self.pictureInPictureResumePoll = nil
            self.pictureInPictureResumeSawPlaybackRestart = false
            self.pictureInPictureResumeCompletion = completion
            self.pictureInPictureResumeTargetPosition = max(0, targetPosition)
"""
if old in mpv:
    mpv = mpv.replace(old, new, 1)

old = """                self.pictureInPictureResumeTimeout = timeout
                self.queue.asyncAfter(deadline: .now() + 2.0, execute: timeout)
"""
new = """                self.pictureInPictureResumeTimeout = timeout
                self.queue.asyncAfter(deadline: .now() + 2.0, execute: timeout)
                self.schedulePictureInPictureRendererResumePoll(handle: handle)
"""
if old in mpv:
    mpv = mpv.replace(old, new, 1)

# Finish must cancel the poll and reset the playback-restart gate.
old = """        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumeCompletion = nil
"""
new = """        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumePoll?.cancel()
        pictureInPictureResumePoll = nil
        pictureInPictureResumeSawPlaybackRestart = false
        pictureInPictureResumeCompletion = nil
"""
if old in mpv:
    mpv = mpv.replace(old, new, 1)

# Replace the playback-restart-only handoff check with a gate plus renderer/video-PTS polling.
resume_block = re.compile(r"            if pictureInPictureResumeCompletion != nil \{.*?\n            \}\n            emitOnMain\(\)", re.S)
replacement = """            if pictureInPictureResumeCompletion != nil {
                pictureInPictureResumeSawPlaybackRestart = true
                _ = evaluatePictureInPictureRendererResume(handle: handle, fallbackPosition: actualPosition, reason: "playback-restart")
            }
            emitOnMain()"""
mpv, count = resume_block.subn(replacement, mpv, count=1)
if count != 1:
    raise SystemExit("Build160 MPV playback-restart handoff replacement mismatch")

helpers = """
    private func evaluatePictureInPictureRendererResume(handle: OpaquePointer, fallbackPosition: Double?, reason: String) -> Bool {
        guard pictureInPictureResumeCompletion != nil else { return true }
        let currentVO = getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
        let viewport = rendererViewportSize(handle: handle)
        var videoPTS = Double.nan
        let hasVideoPTS = getProperty(handle: handle, name: "video-pts", format: MPV_FORMAT_DOUBLE, value: &videoPTS) >= 0 && videoPTS.isFinite
        var timePosition = Double.nan
        let hasTimePosition = getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &timePosition) >= 0 && timePosition.isFinite
        let actualPosition = hasVideoPTS ? videoPTS : (hasTimePosition ? timePosition : (fallbackPosition ?? snapshot.position))
        let target = pictureInPictureResumeTargetPosition
        let delta = target.map { actualPosition - $0 }
        let positionMatched = delta.map { abs($0) <= 0.75 } ?? true
        let ready = pictureInPictureResumeSawPlaybackRestart && currentVO.contains("gpu-next") && viewport != nil && positionMatched
        DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame probe reason=\\(reason) restartSeen=\\(pictureInPictureResumeSawPlaybackRestart) currentVO=\\(currentVO) viewportReady=\\(viewport != nil) source=\\(hasVideoPTS ? \"video-pts\" : \"time-pos\") actual=\\(String(format: \"%.3f\", actualPosition)) target=\\(target.map { String(format: \"%.3f\", $0) } ?? \"unknown\") delta=\\(delta.map { String(format: \"%.3f\", $0) } ?? \"unknown\") ready=\\(ready)")
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

"""
if "private func evaluatePictureInPictureRendererResume" not in mpv:
    marker = "    func setPlaybackRate(_ rate: Double) {\n"
    if mpv.count(marker) != 1:
        raise SystemExit("Build160 MPV helper marker mismatch")
    mpv = mpv.replace(marker, helpers + marker, 1)

# Stop/reset must not leave a stale poll.
old = """        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumeCompletion = nil
        pictureInPictureResumeTargetPosition = nil
"""
new = """        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumePoll?.cancel()
        pictureInPictureResumePoll = nil
        pictureInPictureResumeSawPlaybackRestart = false
        pictureInPictureResumeCompletion = nil
        pictureInPictureResumeTargetPosition = nil
"""
if old in mpv:
    mpv = mpv.replace(old, new, 1)

required = [
    'PlayerPiPSeekLandingProviding',
    'pictureInPictureResumeSawPlaybackRestart',
    'private func evaluatePictureInPictureRendererResume',
    'name: "video-pts"',
    'abs($0) <= 0.75',
    'fresh-video-frame',
]
for token in required:
    if token not in mpv:
        raise SystemExit(f"Build160 MPV finalization missing: {token}")
mpv_path.write_text(mpv)

print("Build160 native PiP timeline + visual handoff finalized")
