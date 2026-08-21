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
settings_path = "Sources/UI/PlayerSettings.swift"
settings_view_path = "Sources/UI/PlayerSettingsView.swift"

# Build112 identity. Build111 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.44"', 'sourceVersion = "0.13.45"')

# Preserve Build111 by default, but allow a new MDK session to omit only the
# Build102 avio.request_size=2 MiB property. short_seek_size stays frozen at 2 MiB.
replace_once(
    engine_path,
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n    private let avioRequestSizeBytes = 2 * 1_048_576\n",
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n    private let avioRequestSizeBytes = 2 * 1_048_576\n    private var avioRequestSize2MiBEnabled: Bool { UserDefaults.standard.object(forKey: PlayerPreferenceKeys.mdkAVIORequestSize2MiBEnabled) as? Bool ?? true }\n",
)
replace_once(
    engine_path,
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 requestSize=\\(avioRequestSizeBytes) shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\\(transportMode)")\n''',
    '''            let boundedRequest2MiB = avioRequestSize2MiBEnabled\n            player.setProperty(name: "avio.multiple_requests", value: "1")\n            if boundedRequest2MiB { player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes)) }\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            let requestSizeLabel = boundedRequest2MiB ? String(avioRequestSizeBytes) : "unbounded"\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 requestSize=\\(requestSizeLabel) shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\\(transportMode)")\n            DiagnosticsLogger.shared.playback("MDKAVIOExperiment", "generation=\\(currentGeneration) boundedRequest2MiB=\\(boundedRequest2MiB) shortSeekSize=\\(avioShortSeekSizeBytes) appliesToNewSession=true")\n''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
settings = Path(settings_path).read_text()
settings_view = Path(settings_view_path).read_text()
assert 'private var avioRequestSize2MiBEnabled: Bool' in engine
assert 'if boundedRequest2MiB { player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes)) }' in engine
assert 'requestSizeLabel = boundedRequest2MiB ? String(avioRequestSizeBytes) : "unbounded"' in engine
assert 'MDKAVIOExperiment' in engine
assert 'static let mdkAVIORequestSize2MiBEnabled = "player.mdkAVIORequestSize2MiBEnabled"' in settings
assert '@AppStorage(PlayerPreferenceKeys.mdkAVIORequestSize2MiBEnabled)' in settings_view
assert 'Toggle("2 MiB AVIO 请求限制", isOn: $mdkAVIORequestSize2MiBEnabled)' in settings_view
assert 'private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55' in engine
assert 'fast-keyframe-preview' in engine
assert 'sourceVersion = "0.13.45"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build112 MDK 2 MiB AVIO request-size A/B toggle materialized")
