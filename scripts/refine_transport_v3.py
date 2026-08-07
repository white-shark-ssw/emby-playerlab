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

print("Transport v3 refinements applied")
