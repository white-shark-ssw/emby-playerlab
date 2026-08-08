from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

old = '''        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = !metadata && (reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset")
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }
'''
new = '''        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = !metadata && (reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset")
        var reanchored = false
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }
'''
if old not in text:
    raise SystemExit("reanchor flag target not found")
text = text.replace(old, new, 1)

old = '''            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)"
            )
'''
new = '''            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)"
            )
'''
if old not in text:
    raise SystemExit("pending seek reanchor target not found")
text = text.replace(old, new, 1)

old = '''                let previous = playbackAnchor
                playbackAnchor = range.lowerBound
                DiagnosticsLogger.shared.log("UnifiedAnchor", "blocked-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)")
'''
new = '''                let previous = playbackAnchor
                playbackAnchor = range.lowerBound
                reanchored = true
                DiagnosticsLogger.shared.log("UnifiedAnchor", "blocked-demand reanchor previous=\\(previous) new=\\(playbackAnchor) request=\\(range.lowerBound)-\\(range.upperBound) reason=\\(reason)")
'''
if old not in text:
    raise SystemExit("blocked reanchor target not found")
text = text.replace(old, new, 1)

old = '''        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 { return }
'''
new = '''        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 {
            if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }
            return
        }
'''
if old not in text:
    raise SystemExit("cache-hit scheduling target not found")
text = text.replace(old, new, 1)

path.write_text(text)
print("v0.11.1 seek cache-hit scheduling refined")
