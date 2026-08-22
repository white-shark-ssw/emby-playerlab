from pathlib import Path

path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = path.read_text()

old_queue = '''    private var nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.0", qos: .userInitiated)
    private let playerLock = NSLock()
'''
new_queue = '''    private var nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.0", qos: .userInitiated)
    private let quarantineAudioQueue = DispatchQueue(label: "OnePlayer.MDK.QuarantineAudio", qos: .userInitiated)
    private let playerLock = NSLock()
'''
if text.count(old_queue) != 1:
    raise SystemExit(f"expected one native queue anchor, found {text.count(old_queue)}")
text = text.replace(old_queue, new_queue, 1)

old_commit = '''    private func commitHealthFailure(reason: String, position: Double, failedGeneration: Int, message: String) {
'''
new_commit = '''    private func silenceQuarantinedPlayer(_ player: swift_mdk.Player, reason: String, failedGeneration: Int) {
        DiagnosticsLogger.shared.playback("MDKQuarantineAudio", "generation=\\(failedGeneration) phase=request reason=\\(reason) action=mute-retained-player")
        quarantineAudioQueue.async { [weak player] in
            guard let player else { return }
            player.mute = true
            DiagnosticsLogger.shared.playback("MDKQuarantineAudio", "generation=\\(failedGeneration) phase=applied reason=\\(reason) muted=true nativeStop=false")
        }
    }

    private func commitHealthFailure(reason: String, position: Double, failedGeneration: Int, message: String) {
'''
if text.count(old_commit) != 1:
    raise SystemExit(f"expected one commit health anchor, found {text.count(old_commit)}")
text = text.replace(old_commit, new_commit, 1)

old_quarantine = '''        nativeQuarantineActive = false
        MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(failedGeneration) phase=quarantine reason=\\(reason) position=\\(String(format: \"%.3f\", position)) action=switch-mpv skipNativeStop=true")
'''
new_quarantine = '''        nativeQuarantineActive = false
        silenceQuarantinedPlayer(oldPlayer, reason: reason, failedGeneration: failedGeneration)
        MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(failedGeneration) phase=quarantine reason=\\(reason) position=\\(String(format: \"%.3f\", position)) action=switch-mpv skipNativeStop=true quarantineMuted=true")
'''
if text.count(old_quarantine) != 1:
    raise SystemExit(f"expected one quarantine retain anchor, found {text.count(old_quarantine)}")
text = text.replace(old_quarantine, new_quarantine, 1)

old_stop_quarantine = '''        if nativeQuarantineActive {
            nativeQuarantineActive = false
            MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\\(generation) activeSeek=\\(activeSeekID ?? -1) action=quarantine-retain-skip-native-stop mainResponsive=true")
            return
        }
'''
new_stop_quarantine = '''        if nativeQuarantineActive {
            nativeQuarantineActive = false
            silenceQuarantinedPlayer(oldPlayer, reason: "ui-stop-quarantine", failedGeneration: generation)
            MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\\(generation) activeSeek=\\(activeSeekID ?? -1) action=quarantine-retain-skip-native-stop mainResponsive=true quarantineMuted=true")
            return
        }
'''
if text.count(old_stop_quarantine) != 1:
    raise SystemExit(f"expected one stop quarantine anchor, found {text.count(old_stop_quarantine)}")
text = text.replace(old_stop_quarantine, new_stop_quarantine, 1)

path.write_text(text)
final = path.read_text()
assert 'OnePlayer.MDK.QuarantineAudio' in final
assert 'MDKQuarantineAudio' in final
assert 'player.mute = true' in final
assert 'quarantineMuted=true' in final
assert 'player.setProperty(name: "video.decoder"' not in final
assert 'dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart' in final
print("Applied Build129 quarantine audio mute fix on clean Build126 decoder baseline")
