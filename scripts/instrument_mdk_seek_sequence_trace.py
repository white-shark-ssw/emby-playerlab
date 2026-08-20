from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"

# Build101 follow-up diagnostics only. Do not alter seek scheduling, fallback,
# cache behavior, renderer ownership, or the iOS deployment target.
replace_once(
    path,
    '''        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request generation=\\(currentPlayerGeneration) nativeOutstanding=\\(nativeSeekOutstandingCount) unifiedTransport=\\(sharedTransportSession != nil) direction=\\(String(describing: direction))")\n''',
    '''        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request generation=\\(currentPlayerGeneration) nativeOutstanding=\\(nativeSeekOutstandingCount) unifiedTransport=\\(sharedTransportSession != nil) direction=\\(String(describing: direction))")\n        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=seek-request seekID=\\(seekID) target=\\(String(format: \"%.3f\", target)) position=\\(String(format: \"%.3f\", lastNativePosition)) generation=\\(currentPlayerGeneration) frameSerial=\\(renderedFrameSerial) raw=0x\\(String(lastNativeStatus, radix: 16))")\n'''
)

replace_once(
    path,
    '''        activeNativeSeek = dispatchedIntent\n        seekBufferingGraceStartedAt = nativeStartedAt\n''',
    '''        activeNativeSeek = dispatchedIntent\n        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=seek-native-start seekID=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) position=\\(String(format: \"%.3f\", lastNativePosition)) retry=\\(dispatchedIntent.retryCount) frameSerial=\\(renderedFrameSerial) raw=0x\\(String(lastNativeStatus, radix: 16))")\n        seekBufferingGraceStartedAt = nativeStartedAt\n'''
)

replace_once(
    path,
    '''                    self.activeNativeSeek = nil\n                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id\n                    if actualMs >= 0 {\n''',
    '''                    self.activeNativeSeek = nil\n                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id\n                    DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(self.inputTraceSession) source=\\(self.inputTraceSource) event=seek-callback seekID=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) resultMs=\\(actualMs) requestMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) current=\\(isCurrent) position=\\(String(format: \"%.3f\", self.lastNativePosition)) frameSerial=\\(self.renderedFrameSerial) raw=0x\\(String(self.lastNativeStatus, radix: 16))")\n                    if actualMs >= 0 {\n'''
)

replace_once(
    path,
    '''        DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) renderTimestamp=\\(String(format: \"%.6f\", renderResult)) renderPosition=\\(playerPosition.map { String(format: \"%.3f\", $0) } ?? \"unknown\") totalMs=\\(String(format: \"%.1f\", totalLatency)) afterCallbackMs=\\(String(format: \"%.1f\", afterCallback)) frameSerial=\\(renderedFrameSerial) action=visual-seek-complete")\n        onSeekCompleted?''',
    '''        DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) renderTimestamp=\\(String(format: \"%.6f\", renderResult)) renderPosition=\\(playerPosition.map { String(format: \"%.3f\", $0) } ?? \"unknown\") totalMs=\\(String(format: \"%.1f\", totalLatency)) afterCallbackMs=\\(String(format: \"%.1f\", afterCallback)) frameSerial=\\(renderedFrameSerial) action=visual-seek-complete")\n        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\\(inputTraceSession) source=\\(inputTraceSource) event=seek-first-frame seekID=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) position=\\(playerPosition.map { String(format: \"%.3f\", $0) } ?? \"unknown\") renderValue=\\(String(format: \"%.6f\", renderResult)) totalMs=\\(String(format: \"%.1f\", totalLatency)) afterCallbackMs=\\(String(format: \"%.1f\", afterCallback)) frameSerial=\\(renderedFrameSerial) raw=0x\\(String(lastNativeStatus, radix: 16))")\n        onSeekCompleted?'''
)

print("MDK seek sequence trace instrumentation applied")
