from pathlib import Path

path = Path('Sources/Transport/UnifiedMediaTransportSession.swift')
text = path.read_text()
marker = 'func readCachedMetadata(offset: Int64, length: Int) async -> Data?'
if marker in text:
    if 'KeyframeCacheRead' not in text or 'cache-only-no-network' not in text:
        raise SystemExit('Build139 reader exists but contract marker is incomplete')
    raise SystemExit(0)

anchor = '    func prioritizeSeek(position: Double, duration: Double) async {'
if anchor not in text:
    raise SystemExit('prioritizeSeek insertion anchor missing')

reader = '''    func readCachedMetadata(offset: Int64, length: Int) async -> Data? {
        guard !stopped, length > 0, offset >= 0 else { return nil }
        guard let resolved = resource, let store else {
            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(length) result=miss reason=resource-not-ready mode=cache-only-no-network")
            return nil
        }
        guard offset < resolved.contentLength else { return Data() }
        let requested = min(length, Int(resolved.contentLength - offset))
        guard requested > 0 else { return Data() }
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        guard available > 0 else {
            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=0 result=miss mode=cache-only-no-network")
            return nil
        }
        let count = min(requested, Int(available))
        guard let data = try? await store.readWhenAvailable(offset: offset, maximumLength: count, timeout: 0), !data.isEmpty else {
            DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=\\(available) result=miss reason=store-read-unavailable mode=cache-only-no-network")
            return nil
        }
        DiagnosticsLogger.shared.playback("KeyframeCacheRead", "offset=\\(offset) requested=\\(requested) available=\\(available) returned=\\(data.count) result=hit mode=cache-only-no-network")
        return data
    }

'''
text = text.replace(anchor, reader + anchor, 1)

if text.count(marker) != 1:
    raise SystemExit(f'expected one Build139 reader, found {text.count(marker)}')
if 'resolve()' in reader or 'acceptRealDemand' in reader or 'installUrgent' in reader or 'scheduleSlots' in reader or 'prioritize' in reader:
    raise SystemExit('Build139 cache-only reader accidentally contains network/scheduler path')

path.write_text(text)
