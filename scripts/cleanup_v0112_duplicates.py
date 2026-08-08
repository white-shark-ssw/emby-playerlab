from pathlib import Path

path = Path("Sources/Player/PlayerController.swift")
text = path.read_text()

block = '''    private func promoteFullCacheRangeIfNeeded(_ metrics: TransportMetricsSnapshot) {
        guard metrics.resourceBytes > 0, metrics.cacheHoleCount == 0, metrics.cacheBytes >= metrics.resourceBytes else { return }
        let duration = effectiveDuration
        guard duration > 0 else { return }
        let fullRange = 0...duration
        guard verifiedBufferedRanges != [fullRange] else { return }
        verifiedBufferedRanges = [fullRange]
        DiagnosticsLogger.shared.log("BufferHistory", "transport cache complete bytes=\\(metrics.cacheBytes)/\\(metrics.resourceBytes) action=promote-full-duration duration=\\(String(format: \"%.3f\", duration))")
    }

'''

count = text.count(block)
if count < 1:
    raise SystemExit("full-cache promotion block missing")
while block + block in text:
    text = text.replace(block + block, block)

call = '                    self.promoteFullCacheRangeIfNeeded(metrics)\n'
call_count = text.count(call)
if call_count < 1:
    raise SystemExit("full-cache promotion call missing")
while call + call in text:
    text = text.replace(call + call, call)

path.write_text(text)
print(f"collapsed promotion blocks {count}->1 and calls {call_count}->1")
