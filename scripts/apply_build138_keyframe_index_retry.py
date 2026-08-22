from pathlib import Path

path = Path('Sources/Player/MPVPlayerEngine.swift')
text = path.read_text()

if 'private static let keyframeIndexRetryDelays: [TimeInterval] = [1, 2, 4, 8, 16]' in text:
    required = ['status=retry-pending', 'status=unavailable-final', 'mode = "absolute+keyframes"', 'phase=mpv-event-seek owner=claimed']
    missing = [marker for marker in required if marker not in text]
    if missing:
        raise SystemExit(f'Build138 materialized source incomplete: {missing}')
    if 'absolute+exact' in text:
        raise SystemExit('Build138 must not introduce exact seek')
    print('Build138 source already materialized; contract verified.')
    raise SystemExit(0)

old_props = '''    private var keyframeIndexGeneration: UInt64 = 0
    private var keyframeIndexTask: Task<Void, Never>?
    private var keyframeIndex: OnePlayerKeyframeIndex?
    private let sharedTransportSession: TransportDataSession?
'''
new_props = '''    private var keyframeIndexGeneration: UInt64 = 0
    private var keyframeIndexTask: Task<Void, Never>?
    private var keyframeIndexRetryWorkItem: DispatchWorkItem?
    private var keyframeIndexRetryAttempt = 0
    private var keyframeIndexRetrySession: TransportDataSession?
    private var keyframeIndexRetryContentLength: Int64 = 0
    private var keyframeIndex: OnePlayerKeyframeIndex?
    private static let keyframeIndexRetryDelays: [TimeInterval] = [1, 2, 4, 8, 16]
    private let sharedTransportSession: TransportDataSession?
'''
if old_props not in text:
    raise SystemExit('property insertion anchor missing')
text = text.replace(old_props, new_props, 1)

old_stop = '''        keyframeIndexGeneration &+= 1
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndex = nil
        pendingRendererLayout = nil
'''
new_stop = '''        keyframeIndexGeneration &+= 1
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt = 0
        keyframeIndexRetrySession = nil
        keyframeIndexRetryContentLength = 0
        keyframeIndex = nil
        pendingRendererLayout = nil
'''
if old_stop not in text:
    raise SystemExit('stop cleanup anchor missing')
text = text.replace(old_stop, new_stop, 1)

start = text.find('    private func startKeyframeIndexDiagnostics(session: TransportDataSession, contentLength: Int64) {')
end = text.find('    private func logKeyframeIndexObservation(seekID: UInt64, target: Double) {', start)
if start < 0 or end < 0:
    raise SystemExit('keyframe diagnostics function anchors missing')

replacement = '''    private func startKeyframeIndexDiagnostics(session: TransportDataSession, contentLength: Int64) {
        keyframeIndexGeneration &+= 1
        let generation = keyframeIndexGeneration
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt = 0
        keyframeIndexRetrySession = session
        keyframeIndexRetryContentLength = contentLength
        keyframeIndex = nil
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=scheduled generation=\\(generation) attempt=1 delayMs=0 bytes=\\(contentLength) mode=cache-only-observe")
        attemptKeyframeIndexDiagnostics(generation: generation)
    }

    private func attemptKeyframeIndexDiagnostics(generation: UInt64) {
        guard !isStopping, keyframeIndexGeneration == generation, keyframeIndex == nil, keyframeIndexTask == nil,
              let session = keyframeIndexRetrySession, keyframeIndexRetryContentLength > 0 else { return }
        keyframeIndexRetryWorkItem?.cancel()
        keyframeIndexRetryWorkItem = nil
        keyframeIndexRetryAttempt += 1
        let attempt = keyframeIndexRetryAttempt
        let contentLength = keyframeIndexRetryContentLength
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=starting generation=\\(generation) attempt=\\(attempt) bytes=\\(contentLength) mode=cache-only-observe")
        keyframeIndexTask = Task { [weak self] in
            let result = await OnePlayerKeyframeIndexProbe.buildIndex(session: session, contentLength: contentLength)
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                guard let self, !self.isStopping, self.keyframeIndexGeneration == generation else { return }
                self.keyframeIndexTask = nil
                switch result {
                case .ready(let index):
                    self.keyframeIndex = index
                    self.keyframeIndexRetryWorkItem?.cancel()
                    self.keyframeIndexRetryWorkItem = nil
                    self.keyframeIndexRetrySession = nil
                    self.keyframeIndexRetryContentLength = 0
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=ready generation=\\(generation) attempt=\\(attempt) entries=\\(index.keyframes.count) stream=\\(index.videoStreamIndex) timeBase=\\(String(format: \"%.9f\", index.timeBaseSeconds)) streamStart=\\(String(format: \"%.3f\", index.streamStartSeconds)) action=observe-only")
                case .unavailable(let reason):
                    self.keyframeIndex = nil
                    guard attempt <= Self.keyframeIndexRetryDelays.count else {
                        self.keyframeIndexRetrySession = nil
                        self.keyframeIndexRetryContentLength = 0
                        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=unavailable-final generation=\\(generation) attempts=\\(attempt) reason=\\(reason) action=observe-only")
                        return
                    }
                    let delay = Self.keyframeIndexRetryDelays[attempt - 1]
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=retry-pending generation=\\(generation) attempt=\\(attempt) nextAttempt=\\(attempt + 1) delayMs=\\(Int(delay * 1000)) reason=\\(reason) action=observe-only")
                    let work = DispatchWorkItem { [weak self] in self?.attemptKeyframeIndexDiagnostics(generation: generation) }
                    self.keyframeIndexRetryWorkItem = work
                    self.queue.asyncAfter(deadline: .now() + delay, execute: work)
                }
            }
        }
    }

'''
text = text[:start] + replacement + text[end:]

if 'absolute+exact' in text:
    raise SystemExit('Build138 must not introduce exact seek')
if 'mode = "absolute+keyframes"' not in text:
    raise SystemExit('fast seek contract missing')
if 'status=retry-pending' not in text or 'keyframeIndexRetryDelays' not in text:
    raise SystemExit('retry contract missing')

path.write_text(text)
