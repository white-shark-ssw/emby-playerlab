from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.2 retained regression failed: {message}")

for needle in [
    "liveLaneSampleWindowSeconds: TimeInterval = 1.0",
    "sampleWindowStartedAt",
    "sampleWindowStartedBytes",
    "let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)",
    "foreground active-gap slot=",
    "active.role == .urgentPlayback",
    "gap > progressiveUrgentGapBytes",
]:
    require(needle in unified, f"missing retained v0.12.2 fix: {needle}")
require("let chunkBps = Double(bytes) / interval" not in unified, "callback-interarrival estimator must not return")
print("v0.12.2 retained regressions: OK")
