from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"missing patch anchor: {label}")
    return text.replace(old, new, 1)

project_path = Path("project.yml")
project = project_path.read_text()
project = project.replace('MARKETING_VERSION: "0.13.3"', 'MARKETING_VERSION: "0.13.7"')
project = project.replace('CURRENT_PROJECT_VERSION: "69"', 'CURRENT_PROJECT_VERSION: "74"')
project_path.write_text(project)

identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text()
identity = identity.replace('static let sourceVersion = "0.13.6"', 'static let sourceVersion = "0.13.7"')
identity = identity.replace('?? "0.13.6"', '?? "0.13.7"')
identity_path.write_text(identity)

path = Path("Sources/Player/MPVPlayerEngine.swift")
text = path.read_text()

text = replace_once(
    text,
    '    private var playbackRateGeneration: UInt64 = 0\n',
    '    private var playbackRateGeneration: UInt64 = 0\n    private var seekGeneration: UInt64 = 0\n',
    'seek generation storage',
)

text = replace_once(
    text,
    '    private struct PendingSeek {\n        let requestedAt: TimeInterval\n        let target: Double\n        let bufferHit: Bool\n    }\n',
    '    private struct PendingSeek {\n        let id: UInt64\n        let requestedAt: TimeInterval\n        let target: Double\n        let bufferHit: Bool\n    }\n',
    'pending seek id',
)

old_seek = '''    func seek(to seconds: Double, direction: SeekDirection) {\n        let duration = snapshot.duration\n        let target = min(max(0, seconds), duration > 0 ? duration : seconds)\n        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })\n        pendingSeek = PendingSeek(requestedAt: CACurrentMediaTime(), target: target, bufferHit: bufferHit)\n        // Never overwrite time-pos with the requested target. MPV may land on an\n        // earlier keyframe, especially for malformed remote MP4 files.\n        snapshot.didReachEnd = false\n        snapshot.isBuffering = true\n        snapshot.waitingReason = "MPV seek"\n        emitOnMain()\n\n        Task { [weak self] in\n            guard let self else { return }\n            if let session = self.sharedTransportSession { await session.prioritizeSeek(position: target, duration: duration) }\n            self.queue.async { [weak self] in\n                guard let self, let handle = self.mpv else { return }\n                let mode = "absolute+keyframes"\n                DiagnosticsLogger.shared.log(\n                    "MPVSeekRequest",\n                    "target=\\(target) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(self.snapshot.position) unified=true"\n                )\n                self.command(handle, ["seek", String(format: "%.3f", target), mode])\n            }\n        }\n    }\n'''
new_seek = '''    func seek(to seconds: Double, direction: SeekDirection) {\n        let duration = snapshot.duration\n        let target = min(max(0, seconds), duration > 0 ? duration : seconds)\n        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })\n        seekGeneration &+= 1\n        let seekID = seekGeneration\n        let requestedAt = CACurrentMediaTime()\n        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit)\n        DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", snapshot.position)) direction=\\(String(describing: direction))")\n        // Never overwrite time-pos with the requested target. MPV may land on an\n        // earlier keyframe, especially for malformed remote MP4 files.\n        snapshot.didReachEnd = false\n        snapshot.isBuffering = true\n        snapshot.waitingReason = "MPV seek"\n        emitOnMain()\n\n        Task { [weak self] in\n            guard let self else { return }\n            if let session = self.sharedTransportSession { await session.prioritizeSeek(position: target, duration: duration) }\n            let prioritizedAt = CACurrentMediaTime()\n            self.queue.async { [weak self] in\n                guard let self, let handle = self.mpv else { return }\n                let mode = "absolute+keyframes"\n                let dispatchAt = CACurrentMediaTime()\n                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")\n                self.command(handle, ["seek", String(format: "%.3f", target), mode])\n            }\n        }\n    }\n'''
text = replace_once(text, old_seek, new_seek, 'seek telemetry')

text = replace_once(
    text,
    '        pendingSeek = startPosition > 0 ? PendingSeek(requestedAt: CACurrentMediaTime(), target: startPosition, bufferHit: false) : nil\n',
    '        pendingSeek = startPosition > 0 ? PendingSeek(id: 0, requestedAt: CACurrentMediaTime(), target: startPosition, bufferHit: false) : nil\n',
    'initial pending seek id',
)

old_event = '''        case MPV_EVENT_SEEK:\n            snapshot.isBuffering = true\n            snapshot.waitingReason = "MPV seek"\n            emitOnMain()\n        case MPV_EVENT_PLAYBACK_RESTART:\n            snapshot.isBuffering = false\n            snapshot.waitingReason = nil\n\n            var actualPosition = snapshot.position\n            var queriedPosition = Double(0)\n            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite {\n                actualPosition = queriedPosition\n                snapshot.position = queriedPosition\n            }\n\n            if let pending = pendingSeek {\n                pendingSeek = nil\n                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000\n                DiagnosticsLogger.shared.log("MPVSeekLanding", "target=\\(pending.target) actual=\\(actualPosition) delta=\\(actualPosition - pending.target)")\n                DispatchQueue.main.async { [weak self] in\n                    self?.onSeekCompleted?(SeekResult(\n                        requestedAt: pending.requestedAt,\n                        target: pending.target,\n                        actualPosition: actualPosition,\n                        bufferHit: pending.bufferHit,\n                        completionLatencyMs: latency,\n                        measurement: "MPV 恢复播放"\n                    ))\n                }\n            }\n            emitOnMain()\n'''
new_event = '''        case MPV_EVENT_SEEK:\n            snapshot.isBuffering = true\n            snapshot.waitingReason = "MPV seek"\n            let pendingText = pendingSeek.map { "id=\\($0.id) latestTarget=\\(String(format: \"%.3f\", $0.target))" } ?? "id=none latestTarget=none"\n            DiagnosticsLogger.shared.log("MPVSeekEvent", "\\(pendingText) position=\\(String(format: \"%.3f\", snapshot.position)) event=seek")\n            emitOnMain()\n        case MPV_EVENT_PLAYBACK_RESTART:\n            snapshot.isBuffering = false\n            snapshot.waitingReason = nil\n\n            var actualPosition = snapshot.position\n            var queriedPosition = Double(0)\n            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite {\n                actualPosition = queriedPosition\n                snapshot.position = queriedPosition\n            }\n\n            if let pending = pendingSeek {\n                pendingSeek = nil\n                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000\n                let delta = actualPosition - pending.target\n                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) event=playback-restart")\n                DispatchQueue.main.async { [weak self] in\n                    self?.onSeekCompleted?(SeekResult(\n                        requestedAt: pending.requestedAt,\n                        target: pending.target,\n                        actualPosition: actualPosition,\n                        bufferHit: pending.bufferHit,\n                        completionLatencyMs: latency,\n                        measurement: "MPV playback-restart after latest seek"\n                    ))\n                }\n            } else {\n                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending")\n            }\n            emitOnMain()\n'''
text = replace_once(text, old_event, new_event, 'MPV event telemetry')

path.write_text(text)
print("MPV 0.13.7 comparison patch applied")
