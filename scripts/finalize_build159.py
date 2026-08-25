from pathlib import Path

engine_path = Path("Sources/Player/MPVPlayerEngine.swift")
text = engine_path.read_text()

old_decl = "final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter {"
new_decl = "final class MPVPlayerEngine: PlayerEngine, PlaybackPresentationEngineAdapter, PlayerPiPInlineRendererControlling {"
if old_decl in text:
    text = text.replace(old_decl, new_decl)

field_anchor = "    private var lastPresentationTimingSignature: PresentationTimingSignature?\n"
if "private var pictureInPictureRendererSuspended = false" not in text:
    if text.count(field_anchor) != 1:
        raise SystemExit("MPV PiP field anchor mismatch")
    text = text.replace(field_anchor, field_anchor + "    private var pictureInPictureRendererSuspended = false\n", 1)

if "func suspendInlineRendererForPictureInPicture" not in text:
    anchor = '''    func play() { setPropertyAsync(name: "pause", value: "no") }
    func pause() { setPropertyAsync(name: "pause", value: "yes") }

    func setPlaybackRate(_ rate: Double) {'''
    if text.count(anchor) != 1:
        raise SystemExit("MPV play/pause anchor mismatch")
    methods = '''    func play() { setPropertyAsync(name: "pause", value: "no") }
    func pause() { setPropertyAsync(name: "pause", value: "yes") }

    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { DispatchQueue.main.async { completion(false) }; return }
            if self.pictureInPictureRendererSuspended { DispatchQueue.main.async { completion(true) }; return }
            let previousVO = self.getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
            guard self.setPropertyChecked(handle: handle, name: "vo", value: "null") else {
                DiagnosticsLogger.shared.log("MPVPiP", "vo suspend request failed previousVO=\\(previousVO)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.waitForPictureInPictureVO(handle: handle, target: "null", attempt: 0) { [weak self] ready, currentVO in
                guard let self else { DispatchQueue.main.async { completion(false) }; return }
                self.pictureInPictureRendererSuspended = ready
                DiagnosticsLogger.shared.log("MPVPiP", "vo suspend ready=\\(ready) previousVO=\\(previousVO) currentVO=\\(currentVO) decoderPreserved=true")
                DispatchQueue.main.async { completion(ready) }
            }
        }
    }

    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) {
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

    private func waitForPictureInPictureVO(handle: OpaquePointer, target: String, attempt: Int, completion: @escaping (Bool, String) -> Void) {
        guard let currentHandle = mpv, currentHandle == handle, !isStopping else { completion(false, "detached"); return }
        let currentVO = getStringProperty(handle: handle, name: "current-vo") ?? "unknown"
        let voMatched = target == "null" ? currentVO.contains("null") : currentVO.contains("gpu-next")
        let drawable = displayLayer.drawableSize
        let drawableReady = target == "null" || (drawable.width > 1 && drawable.height > 1)
        if voMatched && drawableReady { completion(true, currentVO); return }
        guard attempt < 40 else { completion(false, currentVO); return }
        queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.waitForPictureInPictureVO(handle: handle, target: target, attempt: attempt + 1, completion: completion) }
    }

    func setPlaybackRate(_ rate: Double) {'''
    text = text.replace(anchor, methods, 1)

    fallback = '''    func play() {}
    func pause() {}
    func setVideoGeometry(panscan: Double, aspectOverride: String?) {}'''
    if text.count(fallback) != 1:
        raise SystemExit("MPV fallback anchor mismatch")
    replacement = '''    func play() {}
    func pause() {}
    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) { completion(false) }
    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) { completion(false) }
    func setVideoGeometry(panscan: Double, aspectOverride: String?) {}'''
    text = text.replace(fallback, replacement, 1)

create_anchor = '''        enhancementBaseline = nil
        lastPresentationTimingSignature = nil

        check(mpv_request_log_messages(handle, "warn"), operation: "request logs")'''
if text.count(create_anchor) == 1:
    text = text.replace(create_anchor, '''        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureRendererSuspended = false

        check(mpv_request_log_messages(handle, "warn"), operation: "request logs")''', 1)

stop_anchor = '''        snapshot = PlayerSnapshot()
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil

        let flushLayer = { [displayLayer] in'''
if text.count(stop_anchor) == 1:
    text = text.replace(stop_anchor, '''        snapshot = PlayerSnapshot()
        enhancementBaseline = nil
        lastPresentationTimingSignature = nil
        pictureInPictureRendererSuspended = false

        let flushLayer = { [displayLayer] in''', 1)

engine_path.write_text(text)

coordinator_path = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
coordinator = coordinator_path.read_text()
old_guard = '''        guard UIApplication.shared.applicationState != .background else {
            pendingForegroundRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(reason: reason, completion: completion) }
            DiagnosticsLogger.shared.playback("PiPSession", "renderer restore deferred reason=\\(reason) appState=background")
            return
        }'''
new_guard = '''        guard UIApplication.shared.applicationState == .active else {
            pendingForegroundRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(reason: reason, completion: completion) }
            DiagnosticsLogger.shared.playback("PiPSession", "renderer restore deferred reason=\\(reason) appState=\\(UIApplication.shared.applicationState.rawValue) wait=didBecomeActive")
            return
        }'''
if old_guard in coordinator:
    coordinator = coordinator.replace(old_guard, new_guard, 1)
if "playbackController.engine as? PlayerPiPInlineRendererControlling" not in coordinator:
    raise SystemExit("Coordinator engine renderer adapter missing")
coordinator_path.write_text(coordinator)

print("Build159 final source materialized")
