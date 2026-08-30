from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift").read_text()
cache = Path("Sources/UI/EmbyPagePersistentCache.swift").read_text()
native = Path("Sources/UI/EmbyNativePosterCollectionView.swift").read_text()
for value in ['static let sourceVersion = "0.15.11"', '?? "0.15.11"']:
    assert value in identity, f"missing Build278 identity: {value}"
for value in ['event=library-snapshot', 'library_items=', 'tab_items=', 'object_ms=', 'total_ms=', 'event=store', 'serialization_ms=', 'write_ms=', 'ProcessInfo.processInfo.systemUptime', 'try data.write(to: url, options: .atomic)']:
    assert value in cache, f"missing persistence diagnostic: {value}"
for value in ['event=display-gap', 'insert_events=', 'reconfigure_events=', 'display_interval_p95_ms=', 'event=reverse']:
    assert value in native, f"Build276 native diagnostic inheritance missing: {value}"
for forbidden in ['DispatchQueue.global', 'Task.detached', 'decelerationRate =', 'targetTime / duration', 'fileSize']:
    assert forbidden not in cache, f"forbidden persistence behavior change: {forbidden}"
print("Build278 persistence frame-tail checker: PASS")
