from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


transport_path = "Sources/Transport/UnifiedMediaTransportSession.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build111 identity. Build110 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.43"', 'sourceVersion = "0.13.44"')

# Keep the normal playback progressive wait window unchanged at 2 MiB, but during an
# explicit user seek allow only 512 KiB of linear catch-up before borrowing the other
# upstream lane for an exact urgent Range. This is driven by real byte demand only.
replace_once(
    transport_path,
    "    private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576\n",
    "    private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576\n    private let seekProgressiveUrgentGapBytes: Int64 = 512 * 1024\n",
)

# A zero-byte urgent request is already a user-visible seek stall. Hedge earlier while
# preserving the two-slot invariant; the loser is still cancelled/reset by the existing race logic.
replace_once(
    transport_path,
    "    private let urgentFirstByteHedgeSeconds: TimeInterval = 0.65\n",
    "    private let urgentFirstByteHedgeSeconds: TimeInterval = 0.35\n",
)

replace_once(
    transport_path,
    "        let pendingUserSeek = Date() <= pendingUserSeekUntil\n        let concretePlaybackDemand = concreteReason && !metadata\n",
    "        let pendingUserSeek = Date() <= pendingUserSeekUntil\n        let progressiveGapLimit = pendingUserSeek ? seekProgressiveUrgentGapBytes : progressiveUrgentGapBytes\n        let concretePlaybackDemand = concreteReason && !metadata\n",
)

replace_once(
    transport_path,
    "                if gap > progressiveUrgentGapBytes {\n                    DiagnosticsLogger.shared.playback(\"UnifiedDemand\", \"foreground active-gap slot=\\(activeSlot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(active.range.lowerBound)-\\(active.range.upperBound) head=\\(streamHead) gap=\\(gap) action=parallel-urgent\")\n",
    "                if gap > progressiveGapLimit {\n                    DiagnosticsLogger.shared.playback(\"UnifiedDemand\", \"foreground active-gap slot=\\(activeSlot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(active.range.lowerBound)-\\(active.range.upperBound) head=\\(streamHead) gap=\\(gap) gapLimit=\\(progressiveGapLimit) userSeek=\\(pendingUserSeek) action=parallel-urgent\")\n",
)

replace_once(
    transport_path,
    "            if gap <= progressiveUrgentGapBytes {\n                DiagnosticsLogger.shared.playback(\"UnifiedDemand\", \"reuse active sequential stream slot=\\(slot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(claim.range.lowerBound)-\\(claim.range.upperBound) head=\\(streamHead) gap=\\(gap) reason=\\(reason) action=wait-progressive-chunk\")\n",
    "            if gap <= progressiveGapLimit {\n                DiagnosticsLogger.shared.playback(\"UnifiedDemand\", \"reuse active sequential stream slot=\\(slot) request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(claim.range.lowerBound)-\\(claim.range.upperBound) head=\\(streamHead) gap=\\(gap) gapLimit=\\(progressiveGapLimit) userSeek=\\(pendingUserSeek) reason=\\(reason) action=wait-progressive-chunk\")\n",
)

transport = Path(transport_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576' in transport
assert 'private let seekProgressiveUrgentGapBytes: Int64 = 512 * 1024' in transport
assert 'private let urgentFirstByteHedgeSeconds: TimeInterval = 0.35' in transport
assert 'let progressiveGapLimit = pendingUserSeek ? seekProgressiveUrgentGapBytes : progressiveUrgentGapBytes' in transport
assert 'gapLimit=\\(progressiveGapLimit) userSeek=\\(pendingUserSeek) action=parallel-urgent' in transport
assert 'gapLimit=\\(progressiveGapLimit) userSeek=\\(pendingUserSeek) reason=\\(reason) action=wait-progressive-chunk' in transport
assert 'sourceVersion = "0.13.44"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build111 seek transport tail-latency experiment materialized")
