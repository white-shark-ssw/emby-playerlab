from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:220]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(
    engine_path,
    '''                    } else {
                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        if self.lastNativeEnded {
                            self.pendingSeekResume = nil
                            self.queuedLatestSeek = nil
                            DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) current=\\(isCurrent) action=eof-negative-callback-in-place-reprepare latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) source=cached-native-snapshot")
                            self.recoverStall(position: recoveryTarget, duration: dispatchedIntent.duration)
                            return
                        }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) current=\\(isCurrent) action=negative-callback-recover latestTarget=\\(String(format: \"%.3f\", recoveryTarget))")
                        self.recoverWedgedSeek(reason: "negative-callback-\\(actualMs)", fallbackTarget: recoveryTarget, playerGeneration: dispatchedIntent.playerGeneration)
                        return
                    }
''',
    '''                    } else {
                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        let message = "MDK session unsafe seek failure"
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=\\(actualMs) current=\\(isCurrent) action=quarantine-session-switch-mpv latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) sameProcessMDKRebuild=false")
                        self.quarantineCurrentGeneration(reason: "seek-negative-\\(actualMs)", position: recoveryTarget, failedGeneration: dispatchedIntent.playerGeneration, message: message)
                        return
                    }
''',
)

replace_once(
    engine_path,
    '''        if prematureEnd, shouldPlay {
            guard !prematureEOFRecoveryActive else {
                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) action=wait-existing-eof-recovery")
                return
            }
            guard abnormalMediaRecoveryLevel < 2 else {
                let message = "MDK abnormal media recovery exhausted"
                DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) level=\\(abnormalMediaRecoveryLevel) action=exhausted-switch-mpv-immediate")
                onSnapshot?(PlayerSnapshot(position: position, duration: duration, isPlaying: false, isBuffering: false, waitingReason: "MDK 异常媒体恢复已用尽", errorMessage: message))
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
''',
    '''        if prematureEnd, shouldPlay {
            let message = "MDK session unsafe premature EOF"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) action=quarantine-session-switch-mpv sameProcessMDKRebuild=false unifiedTransport=\\(sharedTransportSession != nil)")
            quarantineCurrentGeneration(reason: "confirmed-premature-eof", position: position, failedGeneration: generation, message: message)
            return
        }
''',
)

replace_once(
    engine_path,
    '''        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) active=\\(activeNativeSeek?.id ?? -1) queued=\\(queuedLatestSeek?.id ?? -1) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=rebuild-responsive-mdk-generation")
        transportHTTPServer?.resetClientStreams(reason: "mdk-seek-recovery-\\(reason)")
        activeNativeSeek = nil
        queuedLatestSeek = nil
        reload(at: recoveryTarget)
''',
    '''        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) active=\\(activeNativeSeek?.id ?? -1) queued=\\(queuedLatestSeek?.id ?? -1) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=quarantine-responsive-session-switch-mpv sameProcessMDKRebuild=false")
        quarantineCurrentGeneration(reason: "responsive-seek-recovery-\\(reason)", position: recoveryTarget, failedGeneration: playerGeneration, message: "MDK session unsafe seek recovery")
''',
)

orchestrator_path = "Sources/Player/PlaybackOrchestrator.swift"
replace_once(
    orchestrator_path,
    '''        if kind == .ksAVIO, automaticMode, normalized.contains("mdk abnormal media recovery exhausted") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) recoveryExhausted=true action=switch-mpv-immediate error=\\(message)")
            return .switchEngine(.mpv, reason: "MDK 异常媒体恢复已用尽；立即切换到 MPV 高兼容引擎")
        }
''',
    '''        if kind == .ksAVIO, automaticMode, normalized.contains("mdk session unsafe") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) sessionUnsafe=true action=switch-mpv-immediate error=\\(message)")
            return .switchEngine(.mpv, reason: "MDK 当前会话已进入不安全状态；立即切换到 MPV 高兼容引擎")
        }
        if kind == .ksAVIO, automaticMode, normalized.contains("mdk abnormal media recovery exhausted") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) recoveryExhausted=true action=switch-mpv-immediate error=\\(message)")
            return .switchEngine(.mpv, reason: "MDK 异常媒体恢复已用尽；立即切换到 MPV 高兼容引擎")
        }
''',
)

identity_path = "Sources/Core/AppIdentity.swift"
replace_once(identity_path, 'static let sourceVersion = "0.13.28"', 'static let sourceVersion = "0.13.29"')
replace_once(identity_path, '?? "0.13.28"', '?? "0.13.29"')

project_path = "project.mdklab.yml"
p = Path(project_path)
text = p.read_text()
if 'MARKETING_VERSION: "0.13.29"' not in text:
    if text.count('MARKETING_VERSION: "0.13.28"') != 2:
        raise SystemExit('unexpected MARKETING_VERSION anchor count')
    text = text.replace('MARKETING_VERSION: "0.13.28"', 'MARKETING_VERSION: "0.13.29"')
if 'CURRENT_PROJECT_VERSION: "96"' not in text:
    if text.count('CURRENT_PROJECT_VERSION: "95"') != 2:
        raise SystemExit('unexpected CURRENT_PROJECT_VERSION anchor count')
    text = text.replace('CURRENT_PROJECT_VERSION: "95"', 'CURRENT_PROJECT_VERSION: "96"')
p.write_text(text)

print('Build96 MDK single-generation safety materialized')
