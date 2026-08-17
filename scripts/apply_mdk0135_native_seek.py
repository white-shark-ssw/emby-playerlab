from pathlib import Path

p = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
s = p.read_text()

s = s.replace('''    private struct PendingSeekResume {
        let id: Int
        let target: Double
        let requestedAt: TimeInterval
        var callbackAt: TimeInterval?
        var callbackPosition: Double?
        var didLogBufferingSuppression = false
    }
''', '''    private struct PendingSeekResume {
        let id: Int
        let target: Double
        let requestedAt: TimeInterval
        var callbackAt: TimeInterval?
        var callbackPosition: Double?
        var didLogBufferingSuppression = false
    }

    private struct NativeSeekIntent {
        let id: Int
        let target: Double
        let duration: Double
        let requestedAt: TimeInterval
        let direction: SeekDirection
        let playerGeneration: Int
        var retryCount = 0
    }
''')

s = s.replace('''    private var pendingSeekResume: PendingSeekResume?
    private var inFlightSeekIDs: Set<Int> = []
    private var didInstallLogHandler = false
''', '''    private var pendingSeekResume: PendingSeekResume?
    private var activeNativeSeek: NativeSeekIntent?
    private var queuedLatestSeek: NativeSeekIntent?
    private var didInstallLogHandler = false
''')

s = s.replace('''        pendingSeekResume = nil
        inFlightSeekIDs.removeAll()
        installMDKLoggingIfNeeded()
''', '''        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        installMDKLoggingIfNeeded()
''')

start = s.index('    func seek(to targetSeconds: Double, direction: SeekDirection) {')
end = s.index('\n    func reload(at seconds: Double) {', start)
new_seek = '''    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player else { return }
        let target = max(0, targetSeconds)
        let duration = max(source.mediaSource.durationSeconds ?? 0, seconds(player.mediaInfo.duration))
        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        seekGeneration &+= 1
        let seekID = seekGeneration
        let intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil)
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request generation=\\(currentPlayerGeneration) nativeOutstanding=\\(nativeSeekOutstandingCount) unifiedTransport=\\(sharedTransportSession != nil) direction=\\(String(describing: direction))")

        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) active=\\(activeNativeSeek.id) replacedQueued=\\(replaced.map { String($0) } ?? \"none\") action=latest-wins")
        } else {
            dispatchNativeSeek(intent, player: player)
        }
        scheduleSeekWatchdog(player: player, seekID: seekID, target: target, requestedAt: requestedAt, playerGeneration: currentPlayerGeneration)
    }

    private var nativeSeekOutstandingCount: Int { (activeNativeSeek == nil ? 0 : 1) + (queuedLatestSeek == nil ? 0 : 1) }

    private func dispatchNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player else { return }
        activeNativeSeek = intent
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) phase=native-arm retry=\\(intent.retryCount) nativeOutstanding=\\(nativeSeekOutstandingCount)")

        if let session = sharedTransportSession {
            Task { @MainActor [weak self, weak player] in
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
                guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }
                if let queued = self.queuedLatestSeek {
                    self.activeNativeSeek = nil
                    self.queuedLatestSeek = nil
                    DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "skipped=\\(intent.id) latest=\\(queued.id) phase=before-native-dispatch action=latest-wins")
                    self.dispatchNativeSeek(queued, player: player)
                    return
                }
                self.performNativeSeek(intent, player: player)
            }
        } else {
            performNativeSeek(intent, player: player)
        }
    }

    private func performNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player, activeNativeSeek?.id == intent.id else { return }
        let immediateResult = player.seek(milliseconds(intent.target), flags: .Default) { [weak self, weak player] actualMs in
            let callbackAt = Date().timeIntervalSince1970
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self else { return }
                let latency = (callbackAt - intent.requestedAt) * 1_000
                guard let player, intent.playerGeneration == self.generation, self.player === player else {
                    DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) callbackMs=\\(String(format: \"%.1f\", latency)) result=\\(actualMs) current=false action=discard-stale-player-generation requestGeneration=\\(intent.playerGeneration) activeGeneration=\\(self.generation)")
                    return
                }
                guard self.activeNativeSeek?.id == intent.id else {
                    DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) callbackMs=\\(String(format: \"%.1f\", latency)) result=\\(actualMs) action=discard-nonactive-native")
                    return
                }

                self.activeNativeSeek = nil
                let isCurrent = self.pendingSeekResume?.id == intent.id
                if actualMs >= 0 {
                    let actual = self.seconds(actualMs)
                    if var pending = self.pendingSeekResume, pending.id == intent.id { pending.callbackAt = callbackAt; pending.callbackPosition = actual; self.pendingSeekResume = pending }
                    if isCurrent {
                        self.onSeekCompleted?(SeekResult(requestedAt: intent.requestedAt, target: intent.target, actualPosition: actual, bufferHit: latency < 150, completionLatencyMs: latency, measurement: "MDK latest seek callback"))
                        if self.shouldPlay, player.state != .Playing { player.state = .Playing }
                    }
                    DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) callbackMs=\\(String(format: \"%.1f\", latency)) actual=\\(String(format: \"%.3f\", actual)) current=\\(isCurrent) action=\\(isCurrent ? \"complete-current\" : \"diagnostic-only\") nativeOutstanding=\\(self.nativeSeekOutstandingCount) unifiedTransport=\\(self.sharedTransportSession != nil) direction=\\(String(describing: intent.direction))")
                } else {
                    if actualMs == -2, isCurrent, self.queuedLatestSeek == nil, intent.retryCount < 1 {
                        var retry = intent
                        retry.retryCount += 1
                        self.queuedLatestSeek = retry
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) callbackMs=\\(String(format: \"%.1f\", latency)) result=-2 current=true action=retry-ignored-once")
                    } else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) callbackMs=\\(String(format: \"%.1f\", latency)) result=\\(actualMs) current=\\(isCurrent) action=negative-callback nativeOutstanding=\\(self.nativeSeekOutstandingCount)")
                    }
                }
                self.dispatchQueuedSeekIfNeeded(player: player)
            }
        }
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) phase=native-dispatch immediateResult=\\(immediateResult) semantics=advisory retry=\\(intent.retryCount) nativeOutstanding=\\(nativeSeekOutstandingCount)")
    }

    private func dispatchQueuedSeekIfNeeded(player: swift_mdk.Player) {
        guard activeNativeSeek == nil, let next = queuedLatestSeek else { return }
        queuedLatestSeek = nil
        dispatchNativeSeek(next, player: player)
    }
'''
s = s[:start] + new_seek + s[end:]
s = s.replace('outstanding=\\(inFlightSeekIDs.count)', 'nativeOutstanding=\\(nativeSeekOutstandingCount)')
s = s.replace('outstanding=\\(self.inFlightSeekIDs.count)', 'nativeOutstanding=\\(self.nativeSeekOutstandingCount)')
s = s.replace('''        pendingSeekResume = nil
        inFlightSeekIDs.removeAll()
        if let player {
''', '''        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        if let player {
''')
p.write_text(s)
Path(__file__).unlink()
