from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

old = '''        guard !range.isEmpty, let store else { return }
        let metadata = isMetadataProbe(range, resource: resource)
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = !metadata && (reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset")
        var reanchored = false
'''
new = '''        guard !range.isEmpty, let store else { return }
        let concreteReason = reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"
        // Size/distance metadata heuristics are valid only for speculative Range hints. Once the
        // player actually reads an offset it is a real demux dependency; poorly interleaved audio/video
        // tracks can legitimately issue tiny reads hundreds of MiB apart.
        let metadata = concreteReason ? false : isMetadataProbe(range, resource: resource)
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason
        var reanchored = false
'''
if old not in text:
    raise SystemExit("concrete read classification target not found")
text = text.replace(old, new, 1)

old = '''        // A post-seek player request is authoritative even when every requested byte is already cached.
        // Re-anchor first so background preload follows the new playback position instead of an old frontier.
        if store.contains(normalized) {
'''
new = '''        // Range requests are scheduler hints only. During a pending seek, the actual read() callback
        // is authoritative because AVFoundation may still issue cached/stale requests from the old timeline.
        if store.contains(normalized) {
'''
if old not in text:
    raise SystemExit("noteDemand comment target not found")
text = text.replace(old, new, 1)

path.write_text(text)
print("v0.11.1 concrete read classification refined")
