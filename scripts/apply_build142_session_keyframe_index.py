from pathlib import Path

path = Path('Sources/Player/MPVPlayerEngine.swift')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    text = text.replace(old, new, 1)

replace_once(
'''    private var nearestPreflightBusy = false\n    private var keyframeIndexRetryWorkItem: DispatchWorkItem?\n''',
'''    private var nearestPreflightBusy = false\n    private let sessionKeyframeMap = OnePlayerSessionKeyframeMap()\n    private var keyframeIndexRetryWorkItem: DispatchWorkItem?\n''',
'session keyframe map state'
)

replace_once(
'''        let experimentArm = seekID.isMultiple(of: 2) ? "nearest" : "control"\n        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode, experimentArm: experimentArm, dispatchTarget: target, preflightMs: 0, preflightAction: experimentArm == "control" ? "control-baseline" : "pending", previousKeyframe: nil, nextKeyframe: nil, nearestKeyframe: nil)\n''',
'''        let experimentArm = "nearest-session-index"\n        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode, experimentArm: experimentArm, dispatchTarget: target, preflightMs: 0, preflightAction: "pending", previousKeyframe: nil, nextKeyframe: nil, nearestKeyframe: nil)\n''',
'all-seek nearest arm'
)

old_preflight = '''            var preflightAction = experimentArm == "control" ? "control-baseline" : "fallback-index-not-ready-or-busy"\n            var previousKeyframe: Double?\n            var nextKeyframe: Double?\n            var nearestKeyframe: Double?\n            var preflightMs = Double(0)\n\n            if experimentArm == "nearest" {\n                if !bufferHit {\n                    preflightAction = "fallback-buffer-miss"\n                } else if let index = self.claimNearestPreflightIndex() {\n                    let preflightStartedAt = CACurrentMediaTime()\n                    let race = await self.runNearestPreflight(index: index, target: target)\n                    preflightMs = (CACurrentMediaTime() - preflightStartedAt) * 1000\n                    switch race {\n                    case .timeout:\n                        preflightAction = "fallback-time-budget"\n                    case .probe(.unavailable(let reason)):\n                        preflightAction = "fallback-probe-unavailable:\\(reason)"\n                    case .probe(.ready(let neighbors)):\n                        previousKeyframe = neighbors.previous\n                        nextKeyframe = neighbors.next\n                        nearestKeyframe = neighbors.nearest\n                        if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {\n                            dispatchTarget = next\n                            preflightAction = "nearest-next"\n                        } else if neighbors.previous != nil, neighbors.next != nil {\n                            preflightAction = "nearest-previous-no-change"\n                        } else {\n                            preflightAction = "fallback-incomplete-neighbors"\n                        }\n                    }\n                }\n            }\n'''
new_preflight = '''            var preflightAction = "fallback-index-not-ready-or-busy"\n            var previousKeyframe: Double?\n            var nextKeyframe: Double?\n            var nearestKeyframe: Double?\n            var preflightMs = Double(0)\n\n            if let cached = self.sessionKeyframeMap.neighbors(around: target) {\n                let neighbors = cached.neighbors\n                previousKeyframe = neighbors.previous\n                nextKeyframe = neighbors.next\n                nearestKeyframe = neighbors.nearest\n                if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {\n                    dispatchTarget = next\n                    preflightAction = "session-gap-nearest-next"\n                } else {\n                    preflightAction = "session-gap-nearest-previous-no-change"\n                }\n                DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex", "id=\\(seekID) phase=hit target=\\(String(format: "%.3f", target)) previous=\\(String(format: "%.3f", cached.gap.previous)) next=\\(String(format: "%.3f", cached.gap.next)) gapCount=\\(cached.count) action=\\(preflightAction)")\n            } else if let index = self.claimNearestPreflightIndex() {\n                let preflightStartedAt = CACurrentMediaTime()\n                let race = await self.runNearestPreflight(index: index, target: target)\n                preflightMs = (CACurrentMediaTime() - preflightStartedAt) * 1000\n                switch race {\n                case .timeout:\n                    preflightAction = "fallback-time-budget"\n                case .probe(.unavailable(let reason)):\n                    preflightAction = "fallback-probe-unavailable:\\(reason)"\n                case .probe(.ready(let neighbors)):\n                    previousKeyframe = neighbors.previous\n                    nextKeyframe = neighbors.next\n                    nearestKeyframe = neighbors.nearest\n                    if let previous = neighbors.previous, let next = neighbors.next, let nearest = neighbors.nearest, abs(nearest - next) < 0.0005, abs(next - target) < abs(target - previous) {\n                        dispatchTarget = next\n                        preflightAction = "probe-nearest-next"\n                    } else if neighbors.previous != nil, neighbors.next != nil {\n                        preflightAction = "probe-nearest-previous-no-change"\n                    } else {\n                        preflightAction = "fallback-incomplete-neighbors"\n                    }\n                }\n            }\n'''
replace_once(old_preflight, new_preflight, 'nearest preflight')

replace_once(
'''            Task { [weak self] in\n                let result = await index.neighbors(around: target)\n                gate.finish(.probe(result))\n                self?.queue.async { [weak self] in self?.nearestPreflightBusy = false }\n            }\n''',
'''            Task { [weak self] in\n                let result = await index.neighbors(around: target)\n                if case .ready(let neighbors) = result, let self {\n                    let gapCount = self.sessionKeyframeMap.record(neighbors)\n                    DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex", "phase=record source=preflight target=\\(String(format: "%.3f", target)) gapCount=\\(gapCount)")\n                }\n                gate.finish(.probe(result))\n                self?.queue.async { [weak self] in self?.nearestPreflightBusy = false }\n            }\n''',
'preflight records verified gap'
)

replace_once(
'''        keyframeIndexRetryAttempt = 0\n        keyframeIndexRetrySession = session\n''',
'''        keyframeIndexRetryAttempt = 0\n        sessionKeyframeMap.clear()\n        DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex", "phase=clear reason=new-media")\n        keyframeIndexRetrySession = session\n''',
'clear map on new media'
)

replace_once(
'''                case .ready(let neighbors):\n                    let previous = neighbors.previous.map { String(format: "%.3f", $0) } ?? "none"\n''',
'''                case .ready(let neighbors):\n                    let gapCount = self.sessionKeyframeMap.record(neighbors)\n                    DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex", "id=\\(seekID) phase=record source=post-landing target=\\(String(format: "%.3f", target)) gapCount=\\(gapCount)")\n                    let previous = neighbors.previous.map { String(format: "%.3f", $0) } ?? "none"\n''',
'post landing records verified gap'
)

replace_once(
'''                if pending.experimentArm == "control" { self.logKeyframeIndexObservation(seekID: pending.id, target: pending.target, actual: actualPosition) }\n''',
'''                if pending.previousKeyframe == nil || pending.nextKeyframe == nil { self.logKeyframeIndexObservation(seekID: pending.id, target: pending.target, actual: actualPosition) }\n''',
'fallback post-landing enrichment'
)

replace_once(
'''        nearestPreflightBusy = false\n        keyframeIndexRetryWorkItem?.cancel()\n''',
'''        nearestPreflightBusy = false\n        sessionKeyframeMap.clear()\n        keyframeIndexRetryWorkItem?.cancel()\n''',
'clear map on stop'
)

path.write_text(text)
print('Build142 ephemeral session keyframe index migration applied')
