from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Transport v3 refinement target not found: {path}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''        if !Self.sameOrigin(sourceURL, target) && !Self.same115Family(sourceURL, target) {
            for key in sanitized.allHTTPHeaderFields?.keys ?? [] where isSensitiveTransportHeader(key) { sanitized.setValue(nil, forHTTPHeaderField: key) }
        }
''',
    '''        if !Self.sameOrigin(sourceURL, target) && !Self.same115Family(sourceURL, target), let keys = sanitized.allHTTPHeaderFields?.keys {
            for key in keys where isSensitiveTransportHeader(key) { sanitized.setValue(nil, forHTTPHeaderField: key) }
        }
'''
)

replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''        // A concrete playback read must never wait for an entire background sequential block.
        // If Slot 0 owns the requested byte as a sequential claim, promote that same byte range
        // to the streaming urgent lane so the first 1 MiB becomes visible immediately. Any active
        // Slot 1 background claim yields instead of overlapping the urgent playback range.
''',
    '''        // Transport v3 exposes every received MiB immediately. If the requested byte already belongs
        // to Slot 0's active sequential stream, keep that warmed task alive and wait for its progressive
        // chunk instead of cancelling/reopening the same CDN connection as an urgent Range.
'''
)

replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''final class RangeHTTPClient {
    private let sessions: [URLSession]
    private let streamLanes: [PersistentRangeStreamLane]
''',
    '''final class RangeHTTPClient {
    private let sessions: [URLSession]
    private let streamLanes: [PersistentRangeStreamLane]
    private let lifecycleLock = NSLock()
    private var invalidated = false
'''
)

replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''    deinit {
        sessions.forEach { $0.invalidateAndCancel() }
        streamLanes.forEach { $0.invalidate() }
    }

    func fetch''',
    '''    deinit { invalidate() }

    func invalidate() {
        lifecycleLock.lock()
        guard !invalidated else { lifecycleLock.unlock(); return }
        invalidated = true
        lifecycleLock.unlock()
        sessions.forEach { $0.invalidateAndCancel() }
        streamLanes.forEach { $0.invalidate() }
        DiagnosticsLogger.shared.log("TransportV3", "persistent range pool invalidated")
    }

    func fetch'''
)

replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        DiagnosticsLogger.shared.log("UnifiedTransport", "stopped item=\\(source.itemId)")
''',
    '''        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        client.invalidate()
        DiagnosticsLogger.shared.log("UnifiedTransport", "stopped item=\\(source.itemId)")
'''
)

replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
''',
    '''    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let metric = metrics.transactionMetrics.last else { return }
        lock.lock()
        let state = states[task.taskIdentifier]
        let lane = state?.lane.label ?? "preload-\\(index)"
        let redirects = state?.redirectCount ?? 0
        lock.unlock()
        let connectMs: Int
        if let start = metric.connectStartDate, let end = metric.connectEndDate { connectMs = Int(max(0, end.timeIntervalSince(start)) * 1000) }
        else { connectMs = 0 }
        DiagnosticsLogger.shared.log("TransportV3Metric", "lane=\\(lane) task=\\(task.taskIdentifier) reused=\\(metric.isReusedConnection) protocol=\\(metric.networkProtocolName ?? "unknown") connectMs=\\(connectMs) redirects=\\(redirects)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
'''
)

print("Transport v3 refinements applied")
