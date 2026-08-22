from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build116 identity. Build115 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.48"', 'sourceVersion = "0.13.49"')

# Build107 rejected any post-callback frame farther than 1 second from the user-requested target.
# That is valid for an accurate seek, but wrong for keyframe/Fast seeks where MDK legitimately
# reports a callback landing several seconds away from the requested timestamp. Validate the
# rendered frame against MDK's callbackPosition instead. This preserves stale-frame protection
# while accepting the actual native seek landing returned by MDK.
replace_once(
    engine_path,
    '''        guard abs(renderResult - pending.target) <= 1.0 else {\n            DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) renderTimestamp=\\(String(format: \"%.6f\", renderResult)) action=discard-superseded-frame")\n            return\n        }\n''',
    '''        let expectedLanding = pending.callbackPosition ?? pending.target\n        guard abs(renderResult - expectedLanding) <= 1.0 else {\n            DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) callbackLanding=\\(String(format: \"%.3f\", expectedLanding)) renderTimestamp=\\(String(format: \"%.6f\", renderResult)) action=discard-superseded-frame")\n            return\n        }\n''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'let expectedLanding = pending.callbackPosition ?? pending.target' in engine
assert 'callbackLanding=' in engine
assert 'guard abs(renderResult - expectedLanding) <= 1.0 else' in engine
assert 'guard abs(renderResult - pending.target) <= 1.0 else' not in engine
assert 'mode=\\(fastPreview ? "relative-fast-only" : "absolute-accurate")' in engine
assert 'preciseSettle=disabled' in engine
assert 'MDKSeekPrecisionSettle' not in engine
assert 'boundedRequest2MiB=true source=build115-forced' in engine
assert 'sourceVersion = "0.13.49"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build116 MDK seek frame callback-landing validation materialized")
