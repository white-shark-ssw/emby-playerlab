from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


# Build102 identity. Build101 instrumentation runs first in CI.
for _ in range(2):
    replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.34"', 'MARKETING_VERSION: "0.13.35"')
    replace_once("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "101"', 'CURRENT_PROJECT_VERSION: "102"')
replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.13.34"', 'static let sourceVersion = "0.13.35"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.34"', '?? "0.13.35"')

# Build101 proved per-512 KiB tracing can become a diagnostic hot path when MDK
# enters a cached HTTP read storm. Keep MDK/Range traces but remove per-read logs.
unified_path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
unified = unified_path.read_text()
unified_lines = unified.splitlines()
unified_lines = [line for line in unified_lines if 'DiagnosticsLogger.shared.playback("UnifiedReadTrace"' not in line]
unified = "\n".join(unified_lines) + ("\n" if unified.endswith("\n") else "")
unified_path.write_text(unified)

# Bound FFmpeg HTTP requests. Existing short_seek_size is already 2 MiB, matching
# FFmpeg guidance that short_seek_size should be >= request_size.
engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(
    engine_path,
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n",
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n    private let avioRequestSizeBytes = 2 * 1_048_576\n",
)
replace_once(
    engine_path,
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n''',
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n''',
)
replace_once(
    engine_path,
    '''            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost requestSize=unbounded transport=\\(transportMode)")\n''',
    '''            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 requestSize=\\(avioRequestSizeBytes) shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\\(transportMode)")\n''',
)

# Low-overhead localhost response lineage. One start + one terminal record per
# HTTP response replaces thousands of cached read records.
server_path = "Sources/Transport/TransportHTTPServer.swift"
replace_once(
    server_path,
    '''    private var httpActivityWindowStartedAt = Date.distantPast\n    private var stopped = false\n''',
    '''    private var httpActivityWindowStartedAt = Date.distantPast\n    private var httpResponseSequence: UInt64 = 0\n    private var activeResponseIDs: Set<UInt64> = []\n    private var stopped = false\n''',
)
replace_once(
    server_path,
    '''    private func serve(_ request: HTTPRequest, on connection: NWConnection) async -> Bool {\n        guard request.path == "/\\(token)/media.\\(fileExtension)" else {\n''',
    '''    private func serve(_ request: HTTPRequest, on connection: NWConnection) async -> Bool {\n        let responseID = nextHTTPResponseID()\n        let responseStartedAt = Date()\n        guard request.path == "/\\(token)/media.\\(fileExtension)" else {\n''',
)
replace_once(
    server_path,
    '''            let status = requestedRange == nil ? 200 : 206\n            let reason = status == 206 ? "Partial Content" : "OK"\n            let contentType = resource.contentType ?? "video/mp4"\n\n            var headers = "HTTP/1.1 \\(status) \\(reason)\\r\\n"\n''',
    '''            let status = requestedRange == nil ? 200 : 206\n            let reason = status == 206 ? "Partial Content" : "OK"\n            let contentType = resource.contentType ?? "video/mp4"\n            let activeResponses = beginHTTPResponse(responseID)\n            defer { endHTTPResponse(responseID) }\n            DiagnosticsLogger.shared.playback("TransportHTTPLineage", "server=\\(logID) id=\\(responseID) phase=start method=\\(request.method) status=\\(status) start=\\(responseRange.lowerBound) end=\\(responseRange.upperBound) length=\\(responseRange.length) active=\\(activeResponses) keepAlive=\\(keepAlive)")\n\n            var headers = "HTTP/1.1 \\(status) \\(reason)\\r\\n"\n''',
)
replace_once(
    server_path,
    '''            let sentBytes = max(0, cursor - responseRange.lowerBound)\n            if sentBytes < responseRange.length {\n''',
    '''            let sentBytes = max(0, cursor - responseRange.lowerBound)\n            let elapsedMs = Int(Date().timeIntervalSince(responseStartedAt) * 1_000)\n            DiagnosticsLogger.shared.playback("TransportHTTPLineage", "server=\\(logID) id=\\(responseID) phase=finish start=\\(responseRange.lowerBound) expected=\\(responseRange.length) sent=\\(sentBytes) reason=\\(terminationReason) elapsedMs=\\(elapsedMs) reusable=\\(keepAlive && sentBytes == responseRange.length)")\n            if sentBytes < responseRange.length {\n''',
)
replace_once(
    server_path,
    '''        } catch is CancellationError {\n            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }\n            return false\n        } catch {\n            if isClientDisconnect(error) {\n                return false\n            }\n''',
    '''        } catch is CancellationError {\n            let elapsedMs = Int(Date().timeIntervalSince(responseStartedAt) * 1_000)\n            DiagnosticsLogger.shared.playback("TransportHTTPLineage", "server=\\(logID) id=\\(responseID) phase=cancel elapsedMs=\\(elapsedMs) reason=task-cancelled")\n            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }\n            return false\n        } catch {\n            if isClientDisconnect(error) {\n                let elapsedMs = Int(Date().timeIntervalSince(responseStartedAt) * 1_000)\n                DiagnosticsLogger.shared.playback("TransportHTTPLineage", "server=\\(logID) id=\\(responseID) phase=disconnect elapsedMs=\\(elapsedMs) error=\\(error.localizedDescription)")\n                return false\n            }\n''',
)
replace_once(
    server_path,
    '''    private func recordHTTPActivity(requestStart: Int64?, cancelled: Bool) -> Bool {\n''',
    '''    private func nextHTTPResponseID() -> UInt64 {\n        lock.lock()\n        httpResponseSequence &+= 1\n        let value = httpResponseSequence\n        lock.unlock()\n        return value\n    }\n\n    private func beginHTTPResponse(_ id: UInt64) -> Int {\n        lock.lock()\n        activeResponseIDs.insert(id)\n        let count = activeResponseIDs.count\n        lock.unlock()\n        return count\n    }\n\n    private func endHTTPResponse(_ id: UInt64) {\n        lock.lock()\n        activeResponseIDs.remove(id)\n        lock.unlock()\n    }\n\n    private func recordHTTPActivity(requestStart: Int64?, cancelled: Bool) -> Bool {\n''',
)

# Static audit so a CI-green build cannot silently lose the intended A/B variable.
engine = Path(engine_path).read_text()
server = Path(server_path).read_text()
unified = unified_path.read_text()
assert 'player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))' in engine
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'action=preserve-existing-stream-before-native-seek' in engine
assert 'TransportHTTPLineage' in server
assert 'UnifiedReadTrace' not in unified
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build102 bounded AVIO request + low-overhead HTTP lineage materialized")
