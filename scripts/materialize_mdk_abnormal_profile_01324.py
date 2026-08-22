from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_all_exact(path: str, old: str, new: str, expected: int) -> None:
    p = Path(path)
    text = p.read_text()
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 0:
        if new_count == expected:
            return
        raise SystemExit(f"unexpected materialized count in {path}: {new!r} count={new_count} expected={expected}")
    if old_count != expected:
        raise SystemExit(f"unexpected anchor count in {path}: {old!r} count={old_count} expected={expected}")
    p.write_text(text.replace(old, new))


engine_path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
engine = engine_path.read_text()

old_property = '''    private var didConfigureGlobalIO = false
    private var prematureEOFRecoveryActive = false
'''
new_property = '''    private var didConfigureGlobalIO = false
    private var prematureEOFRecoveryActive = false
    private var abnormalMediaRecoveryLevel = 0
'''
if new_property not in engine:
    if old_property not in engine:
        raise SystemExit("missing MDK abnormal recovery property anchor")
    engine = engine.replace(old_property, new_property, 1)

old_recovery = '''        if prematureEnd, shouldPlay {
            guard !prematureEOFRecoveryActive else {
                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) action=wait-existing-eof-recovery")
                return
            }
            prematureEOFRecoveryActive = true
            transportHTTPServer?.resetClientStreams(reason: "mdk-premature-eof-reprepare")
            let recoveryGeneration = generation
            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) playing=\\(lastNativeIsPlaying) status=0x\\(String(status, radix: 16)) unifiedTransport=\\(sharedTransportSession != nil) action=reprepare-same-player nativeQueue=isolated")
            let queue = nativeControlQueue
            queue.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return }
                player.prepare(from: self.milliseconds(position), complete: { [weak self, weak player] preparedAtMs, boost in
                    guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return false }
                    boost = true
                    DispatchQueue.main.async { [weak self, weak player] in
                        guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return }
                        if preparedAtMs < 0 {
                            self.prematureEOFRecoveryActive = false
                            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) preparedAtMs=\\(preparedAtMs) action=reprepare-failed-no-rebuild")
                            return
                        }
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: recoveryGeneration) }
                        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) preparedAtMs=\\(preparedAtMs) action=reprepare-ready-await-frame")
                    }
                    return true
                })
            }
            return
        }
'''
new_recovery = '''        if prematureEnd, shouldPlay {
            guard !prematureEOFRecoveryActive else {
                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) action=wait-existing-eof-recovery")
                return
            }
            guard abnormalMediaRecoveryLevel < 2 else {
                DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) level=\\(abnormalMediaRecoveryLevel) action=exhausted-mdk-generations")
                onSnapshot?(PlayerSnapshot(position: position, duration: duration, isPlaying: false, isBuffering: false, waitingReason: "MDK 异常媒体恢复已用尽", errorMessage: "MDK abnormal media recovery exhausted"))
                return
            }
            prematureEOFRecoveryActive = true
            abnormalMediaRecoveryLevel += 1
            let level = abnormalMediaRecoveryLevel
            let profile = level == 1 ? "fresh-player" : "software-tolerant"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) level=\\(level) profile=\\(profile) action=quarantine-eos-generation-and-rebuild samePlayerPrepare=false unifiedTransport=\\(sharedTransportSession != nil)")
            reload(at: position)
            return
        }
'''
if new_recovery not in engine:
    if old_recovery not in engine:
        raise SystemExit("missing same-player premature EOF recovery anchor")
    engine = engine.replace(old_recovery, new_recovery, 1)

old_native_setup = '''            player.videoDecoders = ["VT", "FFmpeg"]
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.setProperty(name: "keep_open", value: "1")
            player.media = url.absoluteString
'''
new_native_setup = '''            let compatLevel = self.abnormalMediaRecoveryLevel
            let decoderList = compatLevel >= 2 ? ["FFmpeg", "VT"] : ["VT", "FFmpeg"]
            player.videoDecoders = decoderList
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.setProperty(name: "keep_open", value: "1")
            if compatLevel >= 2 {
                player.setProperty(name: "avformat.err_detect", value: "ignore_err")
                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")
            }
            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")
            DiagnosticsLogger.shared.playback("MDKCompat", "generation=\\(currentGeneration) level=\\(compatLevel) profile=\\(compatProfile) videoDecoders=\\(decoderList.joined(separator: \",\")) avformatTolerance=\\(compatLevel >= 2 ? \"ignore_err+discardcorrupt\" : \"off\") globalDemuxTolerance=off")
            player.media = url.absoluteString
'''
if new_native_setup not in engine:
    if old_native_setup not in engine:
        raise SystemExit("missing MDK native setup anchor")
    engine = engine.replace(old_native_setup, new_native_setup, 1)

old_prepare_log = '''                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\\(preparedAtMs) requestedStart=\\(String(format: \"%.3f\", startPosition)) sourceFPS=\\(self.sourceFrameRateText) videoDecoders=VT,FFmpeg transport=\\(transportMode) mainNativeCall=false")'''
new_prepare_log = '''                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\\(preparedAtMs) requestedStart=\\(String(format: \"%.3f\", startPosition)) sourceFPS=\\(self.sourceFrameRateText) compatLevel=\\(compatLevel) videoDecoders=\\(decoderList.joined(separator: \",\")) transport=\\(transportMode) mainNativeCall=false")'''
if new_prepare_log not in engine:
    if old_prepare_log not in engine:
        raise SystemExit("missing MDK prepare log anchor")
    engine = engine.replace(old_prepare_log, new_prepare_log, 1)

old_stop = '''        prematureEOFRecoveryActive = false
        stopPlayerOnly()
'''
new_stop = '''        prematureEOFRecoveryActive = false
        abnormalMediaRecoveryLevel = 0
        stopPlayerOnly()
'''
if new_stop not in engine:
    if old_stop not in engine:
        raise SystemExit("missing MDK stop recovery reset anchor")
    engine = engine.replace(old_stop, new_stop, 1)

engine_path.write_text(engine)

replace_all_exact("project.mdklab.yml", 'MARKETING_VERSION: "0.13.23"', 'MARKETING_VERSION: "0.13.24"', expected=2)
replace_all_exact("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "90"', 'CURRENT_PROJECT_VERSION: "91"', expected=2)
replace_once("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.13.23"', 'sourceVersion = "0.13.24"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.23"', '?? "0.13.24"')

print("Build91 materialized: tiered MDK abnormal-media generations + scoped FFmpeg tolerance")
