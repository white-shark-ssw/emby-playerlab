from pathlib import Path

coordinator_path = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
coordinator = coordinator_path.read_text()

old = '''        let layer = host.displayLayer
        layer.videoGravity = .resizeAspect
'''
new = '''        let layer = host.displayLayer
        layer.videoGravity = .resizeAspect
        layer.preventsAutomaticBackgroundingDuringVideoPlayback = false
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''        if pendingSkipGeneration == envelope.generation {
            let completion = pendingSkipCompletion
            pendingSkipCompletion = nil
            pendingSkipGeneration = nil
            pendingSeekStartedPosition = nil
            if let timebase = controlTimebase {
                CMTimebaseSetTime(timebase, time: CMTime(seconds: envelope.pts, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
            }
            controller?.invalidatePlaybackState()
'''
new = '''        if pendingSkipGeneration == envelope.generation {
            let completion = pendingSkipCompletion
            pendingSkipCompletion = nil
            pendingSkipGeneration = nil
            pendingSeekStartedPosition = nil
            if let timebase = controlTimebase {
                CMTimebaseSetTime(timebase, time: CMTime(seconds: envelope.pts, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
            }
            pipeline?.setPaused(!pipWantsPlayback)
            controller?.invalidatePlaybackState()
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''        pipeline?.setPaused(!playing)
        if pendingSkipGeneration == nil, pendingSkipCompletion == nil, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
'''
new = '''        pipeline?.setPaused(pendingSkipCompletion != nil ? true : !playing)
        if pendingSkipGeneration == nil, pendingSkipCompletion == nil, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController, controlTimebase != nil else { completionHandler(); return }
'''
new = '''    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController, let pipeline, controlTimebase != nil else { completionHandler(); return }
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''        if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: 0) }
        displayLayer?.flush()
        playbackController.seek(by: delta)
'''
new = '''        if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: 0) }
        pipeline.setPaused(true)
        displayLayer?.flush()
        playbackController.seek(by: delta)
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''        let authoritative = max(0, result.actualPosition ?? result.target)
        activeGeneration = pipeline.seek(to: authoritative)
'''
new = '''        let authoritative = max(0, result.actualPosition ?? result.target)
        displayLayer?.flush()
        activeGeneration = pipeline.seek(to: authoritative)
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

old = '''            if let pipeline {
                activeGeneration = pipeline.seek(to: authoritative)
'''
new = '''            if let pipeline {
                displayLayer?.flush()
                activeGeneration = pipeline.seek(to: authoritative)
'''
if old in coordinator:
    coordinator = coordinator.replace(old, new, 1)

required = [
    'layer.preventsAutomaticBackgroundingDuringVideoPlayback = false',
    'pipeline.setPaused(true)',
    'pipeline?.setPaused(pendingSkipCompletion != nil ? true : !playing)',
    'displayLayer?.flush()\n        activeGeneration = pipeline.seek(to: authoritative)',
]
for token in required:
    if token not in coordinator:
        raise SystemExit(f"Build160 coordinator finalization missing: {token}")
coordinator_path.write_text(coordinator)

mpv_path = Path("Sources/Player/MPVPlayerEngine.swift")
mpv = mpv_path.read_text()
old = '''                let target = pictureInPictureResumeTargetPosition
                let delta = target.map { actualPosition - $0 }
                if currentVO.contains("gpu-next"), viewport != nil {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame event=playback-restart actual=\\(String(format: \"%.3f\", actualPosition)) target=\\(target.map { String(format: \"%.3f\", $0) } ?? \"unknown\") delta=\\(delta.map { String(format: \"%.3f\", $0) } ?? \"unknown\") viewport=ready")
                    finishPictureInPictureRendererResume(success: true, actualPosition: actualPosition, reason: "playback-restart")
                } else {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame deferred event=playback-restart currentVO=\\(currentVO) viewportReady=\\(viewport != nil)")
                }
'''
new = '''                let target = pictureInPictureResumeTargetPosition
                let delta = target.map { actualPosition - $0 }
                let positionMatched = delta.map { abs($0) <= 1.5 } ?? true
                if currentVO.contains("gpu-next"), viewport != nil, positionMatched {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame event=playback-restart actual=\\(String(format: \"%.3f\", actualPosition)) target=\\(target.map { String(format: \"%.3f\", $0) } ?? \"unknown\") delta=\\(delta.map { String(format: \"%.3f\", $0) } ?? \"unknown\") viewport=ready positionMatched=true")
                    finishPictureInPictureRendererResume(success: true, actualPosition: actualPosition, reason: "playback-restart")
                } else {
                    DiagnosticsLogger.shared.log("MPVPiP", "fresh-frame deferred event=playback-restart currentVO=\\(currentVO) viewportReady=\\(viewport != nil) positionMatched=\\(positionMatched) delta=\\(delta.map { String(format: \"%.3f\", $0) } ?? \"unknown\")")
                }
'''
if old in mpv:
    mpv = mpv.replace(old, new, 1)
if 'let positionMatched = delta.map { abs($0) <= 1.5 } ?? true' not in mpv:
    raise SystemExit("Build160 MPV fresh-frame position gate missing")
mpv_path.write_text(mpv)

print("Build160 final native PiP handoff source finalized")
