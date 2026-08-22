from pathlib import Path

path = Path('Sources/Player/MPVPlayerEngine.swift')
text = path.read_text()

required = [
    'let experimentArm = "nearest-session-index"',
    'private var keyframeObservationTask: Task<Void, Never>?',
    'private var nearestPreflightBusy = false',
    'private static let nearestKeyframePreflightBudgetMs: Double = 20',
    'private func logKeyframeIndexObservation',
    'private func startKeyframeIndexDiagnostics',
    'private func attemptKeyframeIndexDiagnostics',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f'Build143 cleanup missing expected marker: {marker}')

# Remove the Build141/142 experiment-arm plumbing without changing seek behavior.
text = text.replace('        let experimentArm: String\n', '')
text = text.replace('        let experimentArm = "nearest-session-index"\n', '')
text = text.replace(', experimentArm: "startup"', '')
text = text.replace(', experimentArm: experimentArm', '')
text = text.replace(' experimentArm=\\(experimentArm)', '')
text = text.replace(' experimentArm=\\(pending.experimentArm)', '')

# Promote experiment terminology to production terminology.
renames = {
    'keyframeObservationTask': 'keyframeBackfillTask',
    'nearestPreflightBusy': 'keyframeLookupBusy',
    'nearestKeyframePreflightBudgetMs': 'keyframeLookupBudgetMs',
    'NearestPreflightRaceResult': 'KeyframeLookupRaceResult',
    'NearestPreflightGate': 'KeyframeLookupGate',
    'claimNearestPreflightIndex': 'claimKeyframeLookupIndex',
    'runNearestPreflight': 'runKeyframeLookup',
    'preflightMs': 'keyframeLookupMs',
    'preflightAction': 'keyframeAction',
    'MPVNearestSeek': 'MPVFastSeek',
    'startKeyframeIndexDiagnostics': 'startKeyframeIndexSupport',
    'attemptKeyframeIndexDiagnostics': 'attemptKeyframeIndexBuild',
}
for old, new in renames.items():
    text = text.replace(old, new)

# The current seek already owns the probe result; record it after releasing the
# user-visible race so session-map bookkeeping cannot add to the 20 ms budget.
old_probe = '''            Task { [weak self] in\n                let result = await index.neighbors(around: target)\n                if case .ready(let neighbors) = result, let self {\n                    let gapCount = self.sessionKeyframeMap.record(neighbors)\n                    DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex", "phase=record source=preflight target=\\(String(format: "%.3f", target)) gapCount=\\(gapCount)")\n                }\n                gate.finish(.probe(result))\n                self?.queue.async { [weak self] in self?.keyframeLookupBusy = false }\n            }\n'''
new_probe = '''            Task { [weak self] in\n                let result = await index.neighbors(around: target)\n                gate.finish(.probe(result))\n                if case .ready(let neighbors) = result, let self { _ = self.sessionKeyframeMap.record(neighbors) }\n                self?.queue.async { [weak self] in self?.keyframeLookupBusy = false }\n            }\n'''
if old_probe not in text:
    raise SystemExit('Build143 cleanup could not locate keyframe lookup task')
text = text.replace(old_probe, new_probe, 1)

# Session-map record/hit chatter was useful for A/B analysis but is redundant in
# the production path; MPVFastSeek already logs the chosen action and neighbors.
text = '\n'.join(line for line in text.split('\n') if 'DiagnosticsLogger.shared.log("MPVSessionKeyframeIndex"' not in line)

# Replace the Build140 observation report with a quiet post-landing backfill.
start = text.find('    private func logKeyframeIndexObservation')
end = text.find('    private func refreshProperty', start)
if start < 0 or end < 0:
    raise SystemExit('Build143 cleanup could not locate keyframe backfill block')
backfill = '''    private func backfillKeyframeGapAfterLanding(seekID: UInt64, target: Double) {\n        guard let index = keyframeIndex, keyframeBackfillTask == nil, !keyframeLookupBusy else { return }\n        keyframeBackfillTask = Task { [weak self] in\n            let result = await index.neighbors(around: target)\n            guard !Task.isCancelled else { return }\n            self?.queue.async { [weak self] in\n                guard let self, !self.isStopping else { return }\n                self.keyframeBackfillTask = nil\n                switch result {\n                case .ready(let neighbors):\n                    let gapCount = self.sessionKeyframeMap.record(neighbors)\n                    DiagnosticsLogger.shared.log("MPVKeyframeBackfill", "id=\\(seekID) target=\\(String(format: "%.3f", target)) result=recorded gapCount=\\(gapCount)")\n                case .unavailable(let reason):\n                    DiagnosticsLogger.shared.log("MPVKeyframeBackfill", "id=\\(seekID) target=\\(String(format: "%.3f", target)) result=unavailable reason=\\(reason)")\n                }\n            }\n        }\n    }\n\n'''
text = text[:start] + backfill + text[end:]
text = text.replace('self.logKeyframeIndexObservation(seekID: pending.id, target: pending.target, actual: actualPosition)', 'self.backfillKeyframeGapAfterLanding(seekID: pending.id, target: pending.target)')

# Lifecycle logs now describe a live fast-seek support service, not an observation experiment.
text = text.replace('mode=cache-only-observe', 'mode=cache-only')
text = text.replace('action=observe-only', 'action=fast-seek-support')

for forbidden in ['experimentArm', 'MPVNearestSeek', 'logKeyframeIndexObservation', 'keyframeObservationTask', 'nearestPreflightBusy', 'NearestPreflightRaceResult', 'NearestPreflightGate', 'startKeyframeIndexDiagnostics', 'attemptKeyframeIndexDiagnostics']:
    if forbidden in text:
        raise SystemExit(f'Build143 cleanup left experimental symbol: {forbidden}')

for required_final in ['private static let keyframeLookupBudgetMs: Double = 20', 'private let sessionKeyframeMap = OnePlayerSessionKeyframeMap()', 'MPVFastSeek', 'backfillKeyframeGapAfterLanding', 'phase=mpv-event-seek owner=claimed', 'reason=no-latest-seek-event-owner']:
    if required_final not in text:
        raise SystemExit(f'Build143 cleanup missing production contract: {required_final}')

path.write_text(text)
print('Build143 production keyframe fast-seek cleanup applied')
