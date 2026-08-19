from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


# Build90 restores UnifiedTransport as the MDK media-byte authority.
replace_once(
    "Sources/Player/PlayerController.swift",
    '''    private var mdkDirectHTTPABActive: Bool {
        #if MDK_LAB
        return engineKind == .ksAVIO
        #else
        return false
        #endif
    }''',
    '''    private var mdkDirectHTTPABActive: Bool { false }'''
)

replace_once(
    "Sources/Player/PlayerController.swift",
    '''            DiagnosticsLogger.shared.playback("MDKDirectAB", "mode=direct-http302 sharedTransportPassed=false unifiedTransportReservedForFallback=true nasMediaProxy=false")
            return KSAVIOPlayerEngine(source: source, client: client, configuration: configuration, sharedTransportSession: nil, ktvCacheSession: nil)''',
    '''            DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost-v2 sharedTransportPassed=true highSpeedCache=true nasMediaProxy=false")
            return KSAVIOPlayerEngine(source: source, client: client, configuration: configuration, sharedTransportSession: transportContext?.session, ktvCacheSession: nil)'''
)

# Keep recovery diagnostics but do not show transient red/orange recovery banners to users.
replace_once(
    "Sources/UI/PlayerScreen.swift",
    '''            if let message = controller.stallMessage { statusBanner(title: "播放停滞恢复", message: message, color: .orange) }''',
    '''            // Stall recovery stays diagnostic-only; automatic recovery/fallback remains active.'''
)

server_path = Path("Sources/Transport/TransportHTTPServer.swift")
server = server_path.read_text()

# HTTP/1.1 bridge v2: do not advertise forced close for normal media responses.
server = server.replace(
    '''            headers += "Cache-Control: no-store\\r\\n"\n            headers += "Connection: close\\r\\n"''',
    '''            headers += "Cache-Control: no-store\\r\\n"\n            let keepAlive = request.headers["connection"]?.lowercased() != "close"\n            headers += keepAlive ? "Connection: keep-alive\\r\\nKeep-Alive: timeout=30, max=100\\r\\n" : "Connection: close\\r\\n"''',
    1,
)

# Network.framework TCP is a byte stream. Avoid marking every header/body chunk as a complete message.
server = server.replace('''                isComplete: true,''', '''                isComplete: false,''', 1)

# Keep a completed HTTP/1.1 connection alive for a subsequent GET/HEAD instead of always cancelling it.
old_task = '''                    let task = Task { [weak self, weak connection] in
                        guard let self, let connection else { return }
                        await self.serve(request, on: connection)
                        self.removeConnection(identifier, matching: connection)?.cancel()
                        connection.cancel()
                    }
                    self.storeTask(task, for: identifier, matching: connection)'''
new_task = '''                    let remainder = accumulated.subdata(in: headerEnd.upperBound..<accumulated.endIndex)
                    let task = Task { [weak self, weak connection] in
                        guard let self, let connection else { return }
                        let reusable = await self.serve(request, on: connection)
                        guard !Task.isCancelled, reusable, !self.isStopped else {
                            self.removeConnection(identifier, matching: connection)?.cancel()
                            connection.cancel()
                            return
                        }
                        self.receiveHeaders(on: connection, buffer: remainder)
                    }
                    self.storeTask(task, for: identifier, matching: connection)'''
if new_task not in server:
    if old_task not in server:
        raise SystemExit("missing TransportHTTP receive task anchor")
    server = server.replace(old_task, new_task, 1)

# serve() reports whether the HTTP/1.1 connection is reusable after the response.
start = server.find("    private func serve(_ request: HTTPRequest, on connection: NWConnection) async {")
end = server.find("    private func recordHTTPActivity", start)
if start < 0 or end < 0:
    raise SystemExit("missing TransportHTTP serve function")
old_serve = server[start:end]
if "async -> Bool" not in old_serve:
    new_serve = old_serve.replace(
        "    private func serve(_ request: HTTPRequest, on connection: NWConnection) async {",
        "    private func serve(_ request: HTTPRequest, on connection: NWConnection) async -> Bool {",
        1,
    )
    new_serve = new_serve.replace(
        '''            await sendError(status: 404, reason: "Not Found", on: connection)\n            return''',
        '''            await sendError(status: 404, reason: "Not Found", on: connection)\n            return false''',
        1,
    )
    new_serve = new_serve.replace(
        '''            await sendError(status: 405, reason: "Method Not Allowed", on: connection)\n            return''',
        '''            await sendError(status: 405, reason: "Method Not Allowed", on: connection)\n            return false''',
        1,
    )
    new_serve = new_serve.replace('''            guard request.method == "GET" else { return }''', '''            guard request.method == "GET" else { return keepAlive }''', 1)
    completion_anchor = '''            if logRequest || sentBytes >= 8 * 1_048_576 {
                DiagnosticsLogger.shared.playback(
                    "TransportHTTP",
                    "server=\\(logID) response finished start=\\(responseRange.lowerBound) sent=\\(sentBytes)"
                )
            }
        } catch is CancellationError {'''
    completion_replacement = '''            if logRequest || sentBytes >= 8 * 1_048_576 {
                DiagnosticsLogger.shared.playback(
                    "TransportHTTP",
                    "server=\\(logID) response finished start=\\(responseRange.lowerBound) sent=\\(sentBytes) keepAlive=\\(keepAlive)"
                )
            }
            return keepAlive && sentBytes == responseRange.length
        } catch is CancellationError {'''
    if completion_anchor not in new_serve:
        raise SystemExit("missing TransportHTTP completion anchor")
    new_serve = new_serve.replace(completion_anchor, completion_replacement, 1)
    new_serve = new_serve.replace(
        '''        } catch is CancellationError {
            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }
        } catch error:''',
        '''        } catch is CancellationError {
            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }
            return false
        } catch error:''',
        1,
    )
    # The actual source uses `catch {`, not `catch error:`. Handle it explicitly.
    new_serve = new_serve.replace(
        '''        } catch is CancellationError {
            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }
        } catch {''',
        '''        } catch is CancellationError {
            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }
            return false
        } catch {''',
        1,
    )
    error_tail = '''            if !responseStarted {
                await sendError(status: 502, reason: "Bad Gateway", on: connection)
            }
        }
    }

'''
    error_tail_new = '''            if !responseStarted {
                await sendError(status: 502, reason: "Bad Gateway", on: connection)
            }
            return false
        }
    }

'''
    if error_tail not in new_serve:
        raise SystemExit("missing TransportHTTP error tail")
    new_serve = new_serve.replace(error_tail, error_tail_new, 1)
    server = server[:start] + new_serve + server[end:]

server_path.write_text(server)

# Version/build identity. Keep the deployment target at iOS 15.0.
replace_once("project.mdklab.yml", 'MARKETING_VERSION: "0.13.22"', 'MARKETING_VERSION: "0.13.23"')
replace_once("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "89"', 'CURRENT_PROJECT_VERSION: "90"')
replace_once("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.13.22"', 'sourceVersion = "0.13.23"')

print("Build90 materialized: UnifiedTransport MDK bridge v2 + silent recovery UI")
