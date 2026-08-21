from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:240]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build110 identity. Build109 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.42"', 'sourceVersion = "0.13.43"')

# Build109 used a 280ms precise-settle delay while the burst classifier itself used 450ms.
# Real double-tap cadence is commonly ~275-325ms, so accurate settles were firing *inside* an
# active continuous-seek session and fighting the fast keyframe previews. Keep the 450ms burst
# classifier, but require a full 550ms of input silence before performing the one final accurate
# correction. This does not debounce user input: every tap is still dispatched immediately.
replace_once(
    engine_path,
    '    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.28\n',
    '    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55\n',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'private let continuousSeekBurstThresholdSeconds: TimeInterval = 0.45' in engine
assert 'private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55' in engine
assert 'fast-keyframe-preview' in engine
assert 'MDKSeekPrecisionSettle' in engine
assert 'action=native-latest-wins' in engine
assert 'action=preview-ignored-no-retry' in engine
assert 'sourceVersion = "0.13.43"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build110 continuous-seek session settle window materialized")
