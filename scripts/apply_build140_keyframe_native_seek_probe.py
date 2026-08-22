from pathlib import Path

path = Path('Sources/Player/MPVPlayerEngine.swift')
text = path.read_text()

if 'private var keyframeObservationTask: Task<Void, Never>?' not in text:
    anchor = '    private var keyframeIndexTask: Task<Void, Never>?\n'
    if anchor not in text: raise SystemExit('keyframe task property anchor missing')
    text = text.replace(anchor, anchor + '    private var keyframeObservationTask: Task<Void, Never>?\n', 1)

stop_anchor = '''        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndexRetryWorkItem?.cancel()
'''
stop_replacement = '''        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeObservationTask?.cancel()
        keyframeObservationTask = nil
        keyframeIndexRetryWorkItem?.cancel()
'''
if stop_anchor in text:
    text = text.replace(stop_anchor, stop_replacement, 1)
elif 'keyframeObservationTask?.cancel()' not in text:
    raise SystemExit('stop cleanup anchor missing')

old_dispatch = '                self.logKeyframeIndexObservation(seekID: seekID, target: target)\n'
if old_dispatch in text:
    text = text.replace(old_dispatch, '', 1)

landing_anchor = '''                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: "%.3f", pending.target)) actual=\\(String(format: "%.3f", actualPosition)) delta=\\(String(format: "%.3f", delta)) completionMs=\\(String(format: "%.1f", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
'''
landing_replacement = landing_anchor + '                self.logKeyframeIndexObservation(seekID: pending.id, target: pending.target, actual: actualPosition)\n'
if landing_anchor in text and 'self.logKeyframeIndexObservation(seekID: pending.id, target: pending.target, actual: actualPosition)' not in text:
    text = text.replace(landing_anchor, landing_replacement, 1)

old_ready = '                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=ready generation=\\(generation) attempt=\\(attempt) entries=\\(index.keyframes.count) stream=\\(index.videoStreamIndex) timeBase=\\(String(format: "%.9f", index.timeBaseSeconds)) streamStart=\\(String(format: "%.3f", index.streamStartSeconds)) action=observe-only")\n'
new_ready = '                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=ready generation=\\(generation) attempt=\\(attempt) mode=\\(index.mode) stream=\\(index.videoStreamIndex) timeBase=\\(String(format: "%.9f", index.timeBaseSeconds)) streamStart=\\(String(format: "%.3f", index.streamStartSeconds)) action=observe-only")\n'
if old_ready in text:
    text = text.replace(old_ready, new_ready, 1)
elif 'mode=\\(index.mode)' not in text:
    raise SystemExit('ready log anchor missing')

start = text.find('    private func logKeyframeIndexObservation(seekID: UInt64, target: Double) {')
end = text.find('    private func refreshProperty(name: String, handle: OpaquePointer) {', start)
if start >= 0 and end > start:
    replacement = '''    private func logKeyframeIndexObservation(seekID: UInt64, target: Double, actual: Double) {
        guard let index = keyframeIndex else {
            DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: "%.3f", target)) actual=\\(String(format: "%.3f", actual)) status=not-ready action=observe-only")
            return
        }
        guard keyframeObservationTask == nil else {
            DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: "%.3f", target)) actual=\\(String(format: "%.3f", actual)) status=probe-busy action=observe-only")
            return
        }
        keyframeObservationTask = Task { [weak self] in
            let result = await index.neighbors(around: target)
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                guard let self, !self.isStopping else { return }
                self.keyframeObservationTask = nil
                switch result {
                case .ready(let neighbors):
                    let previous = neighbors.previous.map { String(format: "%.3f", $0) } ?? "none"
                    let next = neighbors.next.map { String(format: "%.3f", $0) } ?? "none"
                    let nearest = neighbors.nearest.map { String(format: "%.3f", $0) } ?? "none"
                    let previousDelta = neighbors.previous.map { String(format: "%.3f", $0 - target) } ?? "none"
                    let nextDelta = neighbors.next.map { String(format: "%.3f", $0 - target) } ?? "none"
                    let nearestDelta = neighbors.nearest.map { String(format: "%.3f", $0 - target) } ?? "none"
                    let mpvDelta = actual - target
                    let theoreticalGain = neighbors.nearest.map { abs(mpvDelta) - abs($0 - target) }
                    let gainText = theoreticalGain.map { String(format: "%.3f", $0) } ?? "none"
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: "%.3f", target)) actual=\\(String(format: "%.3f", actual)) mpvDelta=\\(String(format: "%.3f", mpvDelta)) previous=\\(previous) previousDelta=\\(previousDelta) previousStatus=\\(neighbors.previousStatus) next=\\(next) nextDelta=\\(nextDelta) nextStatus=\\(neighbors.nextStatus) nearest=\\(nearest) nearestDelta=\\(nearestDelta) theoreticalGain=\\(gainText) mode=native-seek-cache-only action=observe-only")
                case .unavailable(let reason):
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: "%.3f", target)) actual=\\(String(format: "%.3f", actual)) status=probe-unavailable reason=\\(reason) mode=native-seek-cache-only action=observe-only")
                }
            }
        }
    }

'''
    text = text[:start] + replacement + text[end:]
elif 'private func logKeyframeIndexObservation(seekID: UInt64, target: Double, actual: Double)' not in text:
    raise SystemExit('observation function anchor missing')

if 'absolute+exact' in text: raise SystemExit('Build140 must not introduce exact seek')
if text.count('mode = "absolute+keyframes"') < 2: raise SystemExit('fast seek contract missing')
for required in ['phase=mpv-event-seek owner=claimed', 'reason=no-latest-seek-event-owner', 'mode=native-seek-cache-only', 'theoreticalGain=']:
    if required not in text: raise SystemExit(f'missing Build140 contract: {required}')

path.write_text(text)
