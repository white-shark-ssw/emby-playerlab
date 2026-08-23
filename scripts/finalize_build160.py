from pathlib import Path

engine_path = Path("Sources/Player/MPVPlayerEngine.swift")
text = engine_path.read_text()

text = text.replace(
    "final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling {",
    "final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling, PlayerPiPSeekLandingProviding {"
)

field_anchor = "    private var pictureInPictureRendererSuspended = false\n"
field_block = """    private var pictureInPictureRendererSuspended = false
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)?
    private var pictureInPictureResumeCompletion: ((Bool, Double?) -> Void)?
    private var pictureInPictureResumeTargetPosition: Double?
    private var pictureInPictureResumeTimeout: DispatchWorkItem?
"""
if "pictureInPictureResumeCompletion" not in text:
    if text.count(field_anchor) != 1:
        raise SystemExit("Build160 MPV PiP field anchor mismatch")
    text = text.replace(field_anchor, field_block, 1)

old_resume = '''    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false) }; return }
            guard self.pictureInPictureRendererSuspended else { DispatchQueue.main.async { completion(true) }; return }
            guard self.setPropertyChecked(handle: handle, name: "vo", value: "gpu-next") else {
                DiagnosticsLogger.shared.log("MPVPiP", "vo restore request failed")
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.waitForPictureInPictureVO(handle: handle, target: "gpu-next", attempt: 0) { [weak self] ready, currentVO in
                guard let self else { DispatchQueue.main.async { completion(false) }; return }
                if ready { self.pictureInPictureRendererSuspended = false }
                let drawable = self.displayLayer.drawableSize
                DiagnosticsLogger.shared.log("MPVPiP", "vo restore ready=\\(ready) currentVO=\\(currentVO) drawable=\\(Int(drawable.width))x\\(Int(drawable.height)) decoderPreserved=true")
                DispatchQueue.main.async { completion(ready) }
            }
        }
    }
'''
new_resume = '''    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) {
        resumeInlineRendererAfterPictureInPicture(targetPosition: snapshot.position) { success, _ in completion(success) }
    }

    func resumeInlineRendererAfterPictureInPicture(targetPosition: Double, completion: @escaping (Bool, Double?) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false, nil) }; return }
            guard self.pictureInPictureRendererSuspended else { DispatchQueue.main.async { completion(true, self.snapshot.position) }; return }
            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumeCompletion = completion
            self.pictureInPictureResumeTargetPosition = max(0, targetPosition)
            guard self.setPropertyChecked(handle: handle, name: "vo", value: "gpu-next") else {
                DiagnosticsLogger.shared.log("MPVPiP", "vo restore request failed target=\\(String(format: \"%.3f\", targetPosition))")
                self.finishPictureInPictureRendererResume(success: false, actualPosition: nil, reason: "vo-property-failed")
                return
            }
            self.waitForPictureInPictureVO(handle: handle, target: "gpu-next", attempt: 0) { [weak self] ready, currentVO in
                guard let self else { return }
                let drawable = self.displayLayer.drawableSize
                guard ready else {
                    DiagnosticsLogger.shared.log("MPVPiP", "vo restore unavailable currentVO=\\(currentVO) drawable=\\(Int(drawable.width))x\\(Int(drawable.height))")
                    self.finishPictureInPictureRendererResume(success: false, actualPosition: nil, reason: "vo-not-ready")
                    return
                }
                DiagnosticsLogger.shared.log("MPVPiP", "vo restore configured currentVO=\\(currentVO) drawable=\\(Int(drawable.width))x\\(Int(drawable.height)) target=\\(String(format: \"%.3f\", targetPosition)) handoff=await-playback-restart")
                let timeout = DispatchWorkItem { [weak self] in
                    guard let self, self.pictureInPictureResumeCompletion != nil else { return }
                    self.finishPictureInPictureRendererResume(success: false, actualPosition: self.snapshot.position, reason: "fresh-frame-timeout")
                }
                self.pictureInPictureResumeTimeout = timeout
                self.queue.asyncAfter(deadline: .now() + 2.0, execute: timeout)
            }
        }
    }
'''
if old_resume not in text and "handoff=await-playback-restart" not in text:
    raise SystemExit("Build160 MPV resume anchor mismatch")
if old_resume in text:
    text = text.replace(old_resume, new_resume, 1)

wait_anchor = '''    private func waitForPictureInPictureVO(handle: OpaquePointer, target: String, attempt: Int, completion: @escaping (Bool, String) -> Void) {
        guard let currentHandle = mpv, currentHandle == handle, !isStopping else { completion(false, "detached"); return }
        let currentVO = getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
        let voMatched = target == "null" ? currentVO.contains("null") : currentVO.contains("gpu-next")
        let drawable = displayLayer.drawableSize
        let drawableReady = target == "null" || (drawable.width > 1 && drawable.height > 1)
        if voMatched && drawableReady { completion(true, currentVO); return }
        guard attempt < 40 else { completion(false, currentVO); return }
        queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.waitForPictureInPictureVO(handle: handle, target: target, attempt: attempt + 1, completion: completion) }
    }
'''
finish_helper = wait_anchor + '''
    private func finishPictureInPictureRendererResume(success: Bool, actualPosition: Double?, reason: String) {
        guard let completion = pictureInPictureResumeCompletion else { return }
        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumeCompletion = nil
        let target = pictureInPictureResumeTargetPosition
        pictureInPictureResumeTargetPosition = nil
        if success { pictureInPictureRendererSuspended = false }
        DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame handoff success=\\(success) target=\\(target.map { String(format: \"%.3f\", $0) } ?? \"unknown\") actual=\\(actualPosition.map { String(format: \"%.3f\", $0) } ?? \"unknown\") reason=\\(reason)")
        DispatchQueue.main.async { completion(success, actualPosition) }
    }
'''
if "private func finishPictureInPictureRendererResume" not in text:
    if text.count(wait_anchor) != 1:
        raise SystemExit("Build160 MPV wait helper anchor mismatch")
    text = text.replace(wait_anchor, finish_helper, 1)

old_seek_callback = '''                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: latency, measurement: "MPV playback-restart after latest MPV_EVENT_SEEK"))
                }
'''
new_seek_callback = '''                let result = SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: latency, measurement: "MPV playback-restart after latest MPV_EVENT_SEEK")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(result)
                    self?.pictureInPictureSeekLandingHandler?(result)
                }
'''
if old_seek_callback in text:
    text = text.replace(old_seek_callback, new_seek_callback, 1)
elif "pictureInPictureSeekLandingHandler?(result)" not in text:
    raise SystemExit("Build160 MPV seek callback anchor mismatch")

restart_anchor = '''            } else { DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending") }
            emitOnMain()
'''
restart_replacement = '''            } else { DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending") }
            if pictureInPictureResumeCompletion != nil {
                let currentVO = getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
                let viewport = rendererViewportSize(handle: handle)
                let target = pictureInPictureResumeTargetPosition
                let delta = target.map { actualPosition - $0 }
                if currentVO.contains("gpu-next"), viewport != nil {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame event=playback-restart actual=\\(String(format: \"%.3f\", actualPosition)) target=\\(target.map { String(format: \"%.3f\", $0) } ?? \"unknown\") delta=\\(delta.map { String(format: \"%.3f\", $0) } ?? \"unknown\") viewport=ready")
                    finishPictureInPictureRendererResume(success: true, actualPosition: actualPosition, reason: "playback-restart")
                } else {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame deferred event=playback-restart currentVO=\\(currentVO) viewportReady=\\(viewport != nil)")
                }
            }
            emitOnMain()
'''
if restart_anchor in text:
    text = text.replace(restart_anchor, restart_replacement, 1)
elif "fresh-frame event=playback-restart" not in text:
    raise SystemExit("Build160 MPV playback-restart anchor mismatch")

suspend_anchor = '''    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false) }; return }
'''
suspend_replacement = '''    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false) }; return }
            self.pictureInPictureResumeTimeout?.cancel()
            self.pictureInPictureResumeTimeout = nil
            self.pictureInPictureResumeCompletion = nil
            self.pictureInPictureResumeTargetPosition = nil
'''
if suspend_anchor in text:
    text = text.replace(suspend_anchor, suspend_replacement, 1)

stop_anchor = '''        snapshot = PlayerSnapshot()
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureRendererSuspended = false
'''
stop_replacement = '''        snapshot = PlayerSnapshot()
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureRendererSuspended = false
        pictureInPictureSeekLandingHandler = nil
        pictureInPictureResumeTimeout?.cancel()
        pictureInPictureResumeTimeout = nil
        pictureInPictureResumeCompletion = nil
        pictureInPictureResumeTargetPosition = nil
'''
if text.count(stop_anchor) >= 1 and "pictureInPictureSeekLandingHandler = nil" not in text:
    text = text.replace(stop_anchor, stop_replacement, 1)

fallback_decl = "final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling, PlayerPiPSeekLandingProviding {"
# The global declaration replacement above also updates the fallback class.
fallback_field = '''    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?
    var displayLayer = MPVMetalLayer()
'''
fallback_field_replacement = '''    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)?
    var displayLayer = MPVMetalLayer()
'''
if text.count(fallback_field) == 1:
    text = text.replace(fallback_field, fallback_field_replacement, 1)

fallback_seek = '''        onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: seconds, actualPosition: nil, bufferHit: false, completionLatencyMs: 0, measurement: "MPV unavailable in this build"))
        emit()
'''
fallback_seek_replacement = '''        let result = SeekResult(requestedAt: requestedAt, target: seconds, actualPosition: nil, bufferHit: false, completionLatencyMs: 0, measurement: "MPV unavailable in this build")
        onSeekCompleted?(result)
        pictureInPictureSeekLandingHandler?(result)
        emit()
'''
if fallback_seek in text:
    text = text.replace(fallback_seek, fallback_seek_replacement, 1)

engine_path.write_text(text)

screen_path = Path("Sources/UI/PlayerScreen.swift")
screen = screen_path.read_text()
old_button = '''                Button {
                    pictureInPictureController.toggle(using: controller)
                    showControls()
                } label: {
'''
new_button = '''                Button {
                    pictureInPictureController.toggle(using: controller)
                    controlsHideWorkItem?.cancel()
                    controlsHideWorkItem = nil
                    controlsVisible = false
                } label: {
'''
if old_button in screen:
    screen = screen.replace(old_button, new_button, 1)
elif "controlsVisible = false" not in screen:
    raise SystemExit("Build160 PlayerScreen PiP control anchor mismatch")
screen_path.write_text(screen)

print("Build160 final source materialized")
