from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


# Diagnostic package identity only. Source baseline remains unchanged outside this CI branch.
replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.30"', 'MARKETING_VERSION: "0.13.33"')
replace_once("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "97"', 'CURRENT_PROJECT_VERSION: "100"')
replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.30"', 'MARKETING_VERSION: "0.13.33"')
replace_once("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "97"', 'CURRENT_PROJECT_VERSION: "100"')
replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.13.30"', 'static let sourceVersion = "0.13.33"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.30"', '?? "0.13.33"')

# Trace the exact byte reads requested by the localhost bridge/engine from UnifiedTransport.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        metricsValue.bytesServed += Int64(requested)\n''',
    '''        let available = store.availableLength(from: offset, maximumLength: Int64(requested))\n        DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=request offset=\\(offset) requested=\\(requested) available=\\(available) total=\\(resolved.contentLength) tailMetadata=\\(concreteTailMetadata) pendingSeek=\\(Date() <= pendingUserSeekUntil) anchor=\\(playbackAnchor) center=\\(cacheWindowCenter)")\n        metricsValue.bytesServed += Int64(requested)\n'''
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)\n            refreshMetrics(resource: resolved)\n            return data\n''',
    '''            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)\n            refreshMetrics(resource: resolved)\n            let next = offset + Int64(data.count)\n            DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=return offset=\\(offset) requested=\\(requested) returned=\\(data.count) next=\\(next) total=\\(resolved.contentLength) short=\\(data.count < requested) eof=\\(next >= resolved.contentLength)")\n            return data\n'''
)
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''            return try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)\n''',
    '''            let retryData = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)\n            let retryNext = offset + Int64(retryData.count)\n            DiagnosticsLogger.shared.playback("UnifiedReadTrace", "phase=retry-return offset=\\(offset) requested=\\(requested) returned=\\(retryData.count) next=\\(retryNext) total=\\(resolved.contentLength) short=\\(retryData.count < requested) eof=\\(retryNext >= resolved.contentLength)")\n            return retryData\n'''
)

# Trace actual upstream 115/CDN Range semantics including Content-Range and any short body.
replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''        guard http.statusCode == 206 else { throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode) }\n\n        let expected = Int(range.upperBound - range.lowerBound)\n        guard data.count == expected else { throw MediaTransportError.shortRead(expected: expected, actual: data.count) }\n''',
    '''        guard http.statusCode == 206 else {\n            DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) end=\\(range.upperBound - 1) status=\\(http.statusCode) contentRange=\\(http.value(forHTTPHeaderField: \"Content-Range\") ?? \"nil\") contentLength=\\(http.value(forHTTPHeaderField: \"Content-Length\") ?? \"nil\") actual=\\(data.count) action=reject-non206")\n            throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode)\n        }\n\n        let expected = Int(range.upperBound - range.lowerBound)\n        DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) end=\\(range.upperBound - 1) status=206 expected=\\(expected) actual=\\(data.count) contentRange=\\(http.value(forHTTPHeaderField: \"Content-Range\") ?? \"nil\") contentLength=\\(http.value(forHTTPHeaderField: \"Content-Length\") ?? \"nil\") redirects=\\(delegate.redirects.count)")\n        guard data.count == expected else {\n            DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane.label) start=\\(range.lowerBound) expected=\\(expected) actual=\\(data.count) action=short-read-error")\n            throw MediaTransportError.shortRead(expected: expected, actual: data.count)\n        }\n'''
)
replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''        lock.lock()\n        states[dataTask.taskIdentifier]?.acceptedResponse = true\n        lock.unlock()\n        completionHandler(.allow)\n''',
    '''        DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(lane) task=\\(dataTask.taskIdentifier) status=206 contentRange=\\(http.value(forHTTPHeaderField: \"Content-Range\") ?? \"nil\") contentLength=\\(http.value(forHTTPHeaderField: \"Content-Length\") ?? \"nil\") redirects=\\(redirects) mode=stream")\n        lock.lock()\n        states[dataTask.taskIdentifier]?.acceptedResponse = true\n        lock.unlock()\n        completionHandler(.allow)\n'''
)
replace_once(
    "Sources/Transport/RangeHTTPClient.swift",
    '''        guard received == expected else {\n            state.continuation.finish(throwing: MediaTransportError.shortRead(expected: expected, actual: received))\n            return\n        }\n''',
    '''        guard received == expected else {\n            DiagnosticsLogger.shared.log("TransportRangeTrace", "lane=\\(state.lane.label) task=\\(task.taskIdentifier) start=\\(state.range.lowerBound) expected=\\(expected) actual=\\(received) redirects=\\(redirects) action=stream-short-read-error")\n            state.continuation.finish(throwing: MediaTransportError.shortRead(expected: expected, actual: received))\n            return\n        }\n'''
)

print("MDK online-input diagnostic instrumentation applied")
