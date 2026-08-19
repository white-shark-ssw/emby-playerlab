from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"anchor missing: {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


# Transport logs are playback diagnostics, never App lifecycle logs.
for path in ["Sources/Transport/UnifiedMediaTransportSession.swift", "Sources/Transport/TransportHTTPServer.swift"]:
    p = Path(path)
    text = p.read_text().replace("DiagnosticsLogger.shared.log(", "DiagnosticsLogger.shared.playback(")
    p.write_text(text)

# Aggregate speculative scheduler hints instead of logging every demux HTTP Range.
p = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = p.read_text()
field_anchor = "    private var lastMetricsLogAt = Date.distantPast\n"
fields = field_anchor + "    private var schedulerHintWindowStartedAt = Date.distantPast\n    private var schedulerHintCount = 0\n    private var schedulerHintLastRange: Range<Int64>?\n    private var schedulerHintLastReason = \"\"\n"
if "schedulerHintWindowStartedAt" not in text:
    if field_anchor not in text: raise SystemExit("UnifiedMediaTransportSession metrics field anchor missing")
    text = text.replace(field_anchor, fields, 1)
old_hint = '''            DiagnosticsLogger.shared.playback("UnifiedSchedulerV2", "hint-only request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason) action=keep-bulk")\n            scheduleSlots(reason: "hint-only")\n'''
new_hint = '''            recordSchedulerHint(range: range, reason: reason)\n            scheduleSlots(reason: "hint-only")\n'''
if new_hint not in text:
    if old_hint not in text: raise SystemExit("UnifiedMediaTransportSession hint-only anchor missing")
    text = text.replace(old_hint, new_hint, 1)
helper_anchor = "    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {\n"
helper = '''    private func recordSchedulerHint(range: Range<Int64>, reason: String) {\n        let now = Date()\n        if schedulerHintWindowStartedAt == .distantPast { schedulerHintWindowStartedAt = now }\n        schedulerHintCount += 1\n        schedulerHintLastRange = range\n        schedulerHintLastReason = reason\n        let elapsed = now.timeIntervalSince(schedulerHintWindowStartedAt)\n        guard elapsed >= 1 else { return }\n        let last = schedulerHintLastRange\n        DiagnosticsLogger.shared.playback("UnifiedSchedulerActivity", "windowMs=\\(Int(elapsed * 1000)) hints=\\(schedulerHintCount) rate=\\(String(format: \"%.1f\", Double(schedulerHintCount) / max(elapsed, 0.001)))/s last=\\(last?.lowerBound ?? -1)-\\(last?.upperBound ?? -1) reason=\\(schedulerHintLastReason) action=keep-bulk")\n        schedulerHintWindowStartedAt = now\n        schedulerHintCount = 0\n        schedulerHintLastRange = nil\n        schedulerHintLastReason = \"\"\n    }\n\n'''
if "private func recordSchedulerHint" not in text:
    if helper_anchor not in text: raise SystemExit("UnifiedMediaTransportSession installUrgent anchor missing")
    text = text.replace(helper_anchor, helper + helper_anchor, 1)
p.write_text(text)

# A far-from-end EOF on a UnifiedTransport engine is never permission to recursively rebuild it.
replace_once(
    "Sources/Player/PlaybackOrchestrator.swift",
    '''        if farFromEnd && transportStarved {\n            return .recoverTransport(message: "网络/缓存供给不足时出现提前 EOF，保持当前引擎并恢复当前位置数据，不重建播放器")\n        }\n        return .reloadCurrent(reason: "疑似提前结束：\\(reason)；传输未显示饥饿，受控重载当前引擎")\n''',
    '''        let unifiedKinds: Set<PlayerEngineKind> = [.resourceLoaderAVPlayer, .transportAVPlayer, .mpv, .ksAVIO]\n        if farFromEnd && unifiedKinds.contains(kind) {\n            let detail = transportStarved ? "当前传输存在饥饿/失败" : "当前传输仍健康，按异常媒体 EOF 处理"\n            return .recoverTransport(message: "提前 EOF：\\(detail)；保持当前引擎原地恢复，不允许递归重建")\n        }\n        if farFromEnd && transportStarved { return .recoverTransport(message: "网络/缓存供给不足时出现提前 EOF，保持当前引擎恢复当前位置数据") }\n        return .reloadCurrent(reason: "疑似提前结束：\\(reason)；仅非 UnifiedTransport 引擎允许受控重载")\n'''
)

# PlayerController owns the EOF incident state. One in-place attempt, then quarantine until real progress/user action.
p = Path("Sources/Player/PlayerController.swift")
text = p.read_text()
field = "    private var eofRetryCount = 0\n"
if "private var prematureEOFRecovery = PrematureEOFRecoveryCoordinator()" not in text:
    if field not in text: raise SystemExit("PlayerController eof field anchor missing")
    text = text.replace(field, field + "    private var prematureEOFRecovery = PrematureEOFRecoveryCoordinator()\n", 1)
start_anchor = "        displayedPosition = position\n        initialResumeConfirmationPending = position > 0.5\n"
if "prematureEOFRecovery.reset()\n        initialResumeConfirmationPending" not in text:
    if start_anchor not in text: raise SystemExit("PlayerController startEngine anchor missing")
    text = text.replace(start_anchor, "        displayedPosition = position\n        prematureEOFRecovery.reset()\n        initialResumeConfirmationPending = position > 0.5\n", 1)
stop_anchor = "        initialResumePlaybackBaseline = nil\n        lastTransportPlaybackReportPosition = -1\n"
if "prematureEOFRecovery.reset()\n        lastTransportPlaybackReportPosition" not in text:
    if stop_anchor not in text: raise SystemExit("PlayerController stop anchor missing")
    text = text.replace(stop_anchor, "        initialResumePlaybackBaseline = nil\n        prematureEOFRecovery.reset()\n        lastTransportPlaybackReportPosition = -1\n", 1)
snapshot_anchor = "                self.snapshot = value\n                if value.position > 0.25 { self.hasPlaybackAdvanced = true }\n"
if "prematureEOFRecovery.observe(snapshot: value)" not in text:
    if snapshot_anchor not in text: raise SystemExit("PlayerController snapshot anchor missing")
    text = text.replace(snapshot_anchor, "                self.snapshot = value\n                self.prematureEOFRecovery.observe(snapshot: value)\n                if value.position > 0.25 { self.hasPlaybackAdvanced = true }\n", 1)
seek_anchor = "                guard generation == self.engineGeneration else { return }\n                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {\n"
if "self.prematureEOFRecovery.reset()\n                if let pending" not in text:
    if seek_anchor not in text: raise SystemExit("PlayerController seek completion anchor missing")
    text = text.replace(seek_anchor, "                guard generation == self.engineGeneration else { return }\n                self.prematureEOFRecovery.reset()\n                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {\n", 1)
old_eof_switch = '''        switch orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason, snapshot: snapshot, metrics: lastTransportMetrics) {\n        case .switchEngine(let next, let reason): prematureEOFMessage = "\\(decision.reason)；App 正在自动切换到 \\(next.title)。"; switchEngine(to: next, reason: reason)\n        case .reloadCurrent(let reason): prematureEOFMessage = reason; engine.reload(at: snapshot.position); engine.play()\n        case .recoverTransport(let message), .wait(let message): prematureEOFMessage = message; engine.recoverStall(position: snapshot.position, duration: effectiveDuration)\n        }\n'''
new_eof_switch = '''        switch prematureEOFRecovery.begin(position: snapshot.position) {\n        case .recoverInPlace:\n            let action = orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason, snapshot: snapshot, metrics: lastTransportMetrics)\n            switch action {\n            case .recoverTransport(let message), .wait(let message):\n                prematureEOFMessage = message\n                DiagnosticsLogger.shared.playback("EOFRecovery", "state=recovering engine=\\(engineKind.title) position=\\(String(format: \"%.3f\", snapshot.position)) action=in-place")\n                engine.recoverStall(position: snapshot.position, duration: effectiveDuration)\n            case .reloadCurrent(let reason):\n                prematureEOFMessage = reason\n                DiagnosticsLogger.shared.playback("EOFRecovery", "state=recovering engine=\\(engineKind.title) action=blocked-recursive-reload reason=\\(reason)")\n                engine.recoverStall(position: snapshot.position, duration: effectiveDuration)\n            case .switchEngine(let next, let reason):\n                prematureEOFMessage = "\\(decision.reason)；自动切换被恢复隔离层阻止，请手动选择 \\(next.title)。"\n                DiagnosticsLogger.shared.playback("EOFRecovery", "state=recovering action=blocked-runtime-switch next=\\(next.title) reason=\\(reason)")\n            }\n        case .waitForCurrentRecovery:\n            DiagnosticsLogger.shared.playback("EOFRecovery", "state=recovering action=ignore-duplicate position=\\(String(format: \"%.3f\", snapshot.position))")\n        case .quarantine:\n            prematureEOFMessage = "该媒体连续触发异常 EOF，MDK 已停止自动恢复以保护 App。可手动切换到 MPV高兼容引擎继续测试。"\n            DiagnosticsLogger.shared.playback("EOFRecovery", "state=quarantined engine=\\(engineKind.title) position=\\(String(format: \"%.3f\", snapshot.position)) action=no-rebuild")\n        }\n'''
if new_eof_switch not in text:
    if old_eof_switch not in text: raise SystemExit("PlayerController premature EOF switch anchor missing")
    text = text.replace(old_eof_switch, new_eof_switch, 1)
p.write_text(text)

# MDK recovery is separate from user Seek: keep media loaded at EOS and re-prepare the same player instance.
p = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
text = p.read_text()
field_anchor = "    private var didInstallLogHandler = false\n"
if "private var prematureEOFRecoveryActive = false" not in text:
    if field_anchor not in text: raise SystemExit("MDK recovery field anchor missing")
    text = text.replace(field_anchor, field_anchor + "    private var prematureEOFRecoveryActive = false\n", 1)
prepare_reset = "        didLogSeekBufferingGraceID = nil\n        installMDKLoggingIfNeeded()\n"
if "prematureEOFRecoveryActive = false\n        installMDKLoggingIfNeeded" not in text:
    if prepare_reset not in text: raise SystemExit("MDK prepare reset anchor missing")
    text = text.replace(prepare_reset, "        didLogSeekBufferingGraceID = nil\n        prematureEOFRecoveryActive = false\n        installMDKLoggingIfNeeded()\n", 1)
old_recover = '''    func recoverStall(position: Double, duration: Double) {\n        guard let player else { return }\n        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }\n        let status = player.mediaStatus.rawValue\n        let prematureEnd = hasStatus(status, bit: 6) && duration > 0 && position + max(3, duration * 0.005) < duration\n        if prematureEnd, shouldPlay {\n            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) state=\\(String(describing: player.state)) status=0x\\(String(status, radix: 16)) unifiedTransport=\\(sharedTransportSession != nil) action=native-seek-current-after-network-eof")\n            seek(to: position, direction: .absolute)\n            return\n        }\n        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) state=\\(String(describing: player.state)) status=0x\\(String(status, radix: 16)) unifiedTransport=\\(sharedTransportSession != nil) action=prioritize-and-play")\n        if shouldPlay { player.state = .Playing }\n    }\n'''
new_recover = '''    func recoverStall(position: Double, duration: Double) {\n        guard let player else { return }\n        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }\n        let status = player.mediaStatus.rawValue\n        let prematureEnd = hasStatus(status, bit: 6) && duration > 0 && position + max(3, duration * 0.005) < duration\n        if prematureEnd, shouldPlay {\n            guard !prematureEOFRecoveryActive else {\n                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) action=wait-existing-eof-recovery")\n                return\n            }\n            prematureEOFRecoveryActive = true\n            transportHTTPServer?.resetClientStreams(reason: "mdk-premature-eof-reprepare")\n            let recoveryGeneration = generation\n            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) state=\\(String(describing: player.state)) status=0x\\(String(status, radix: 16)) unifiedTransport=\\(sharedTransportSession != nil) action=reprepare-same-player")\n            player.prepare(from: milliseconds(position), complete: { [weak self, weak player] preparedAtMs, boost in\n                guard let self, let player, recoveryGeneration == self.generation, self.player === player else { return false }\n                boost = true\n                DispatchQueue.main.async { [weak self, weak player] in\n                    guard let self, let player, recoveryGeneration == self.generation, self.player === player else { return }\n                    if preparedAtMs < 0 {\n                        self.prematureEOFRecoveryActive = false\n                        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) preparedAtMs=\\(preparedAtMs) action=reprepare-failed-no-rebuild")\n                        return\n                    }\n                    if self.shouldPlay { player.state = .Playing }\n                    DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) preparedAtMs=\\(preparedAtMs) action=reprepare-ready-await-frame")\n                }\n                return true\n            })\n            return\n        }\n        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) state=\\(String(describing: player.state)) status=0x\\(String(status, radix: 16)) unifiedTransport=\\(sharedTransportSession != nil) action=prioritize-and-play")\n        if shouldPlay { player.state = .Playing }\n    }\n'''
if new_recover not in text:
    if old_recover not in text: raise SystemExit("MDK recoverStall anchor missing")
    text = text.replace(old_recover, new_recover, 1)
media_anchor = "        view.bind(player)\n        player.media = url.absoluteString\n"
if 'player.setProperty(name: "keep_open", value: "1")' not in text:
    if media_anchor not in text: raise SystemExit("MDK media anchor missing")
    text = text.replace(media_anchor, '        view.bind(player)\n        player.setProperty(name: "keep_open", value: "1")\n        player.media = url.absoluteString\n', 1)
log_anchor = '''            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)\n            guard !trimmed.isEmpty else { return }\n            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")\n'''
log_new = '''            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)\n            guard !trimmed.isEmpty else { return }\n            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }\n            DiagnosticsLogger.shared.playback("MDKNative", "level=\\(String(describing: level)) \\(trimmed)")\n'''
if log_new not in text:
    if log_anchor not in text: raise SystemExit("MDK native logger anchor missing")
    text = text.replace(log_anchor, log_new, 1)
record_anchor = "    private func recordRenderedFrame(_ renderResult: Double) {\n"
record_new = '''    private func recordRenderedFrame(_ renderResult: Double) {\n        if prematureEOFRecoveryActive, renderResult.isFinite, renderResult >= 0 {\n            prematureEOFRecoveryActive = false\n            DiagnosticsLogger.shared.playback("MDKRecovery", "action=reprepare-first-frame recoveryComplete=true")\n        }\n'''
if record_new not in text:
    if record_anchor not in text: raise SystemExit("MDK recordRenderedFrame anchor missing")
    text = text.replace(record_anchor, record_new, 1)
stop_anchor = "        rateGeneration &+= 1\n        stopPlayerOnly()\n"
if "prematureEOFRecoveryActive = false\n        stopPlayerOnly" not in text:
    if stop_anchor not in text: raise SystemExit("MDK stop anchor missing")
    text = text.replace(stop_anchor, "        rateGeneration &+= 1\n        prematureEOFRecoveryActive = false\n        stopPlayerOnly()\n", 1)
p.write_text(text)

# Version.
p = Path("project.mdklab.yml")
text = p.read_text().replace('MARKETING_VERSION: "0.13.16"', 'MARKETING_VERSION: "0.13.17"').replace('CURRENT_PROJECT_VERSION: "83"', 'CURRENT_PROJECT_VERSION: "84"')
p.write_text(text)

print("Build84 recovery isolation materialized")
