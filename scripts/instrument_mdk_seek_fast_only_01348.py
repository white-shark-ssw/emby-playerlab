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

# Build115 identity. Build114 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.47"', 'sourceVersion = "0.13.48"')

# +/- step seeks are the user-interaction hot path: dispatch keyframe/Fast immediately and
# never schedule a delayed accurate correction. Absolute timeline/screen scrubs remain accurate.
replace_once(
    engine_path,
    '''        let previousUserSeekAt = lastUserSeekRequestedAt\n        let fastPreview = true\n        lastUserSeekRequestedAt = requestedAt\n        seekGeneration &+= 1\n        let seekID = seekGeneration\n        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)\n        intent.fastPreview = fastPreview\n        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)\n        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=fast-first-keyframe previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) settleIdleMs=\\(Int(continuousSeekPreciseSettleSeconds * 1_000))")\n        scheduleContinuousSeekPreciseSettle(intent: intent, player: player)\n''',
    '''        let previousUserSeekAt = lastUserSeekRequestedAt\n        let fastPreview: Bool\n        switch direction {\n        case .forward, .backward: fastPreview = true\n        case .absolute: fastPreview = false\n        }\n        lastUserSeekRequestedAt = requestedAt\n        seekGeneration &+= 1\n        let seekID = seekGeneration\n        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)\n        intent.fastPreview = fastPreview\n        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)\n        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=\\(fastPreview ? \"relative-fast-only\" : \"absolute-accurate\") previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) preciseSettle=disabled")\n''',
)

# Remove the now-unused idle precise-settle machinery completely so a relative seek cannot
# silently start another native accurate seek after the visible Fast result.
replace_once(engine_path, '    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55\n', '')
replace_once(
    engine_path,
    '''    private func scheduleContinuousSeekPreciseSettle(intent: NativeSeekIntent, player: swift_mdk.Player) {\n        DispatchQueue.main.asyncAfter(deadline: .now() + continuousSeekPreciseSettleSeconds) { [weak self, weak player] in\n            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.pendingSeekResume?.id == intent.id, self.seekGeneration == intent.id else { return }\n            let now = Date().timeIntervalSince1970\n            guard let lastUserSeekRequestedAt = self.lastUserSeekRequestedAt, abs(lastUserSeekRequestedAt - intent.requestedAt) < 0.001 else { return }\n            self.seekGeneration &+= 1\n            let preciseID = self.seekGeneration\n            var precise = NativeSeekIntent(id: preciseID, target: intent.target, duration: intent.duration, requestedAt: now, direction: intent.direction, playerGeneration: intent.playerGeneration)\n            precise.fastPreview = false\n            self.pendingSeekResume = PendingSeekResume(id: preciseID, target: intent.target, requestedAt: now, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)\n            let superseded = self.activeNativeSeek?.id\n            self.queuedLatestSeek = nil\n            DiagnosticsLogger.shared.playback("MDKSeekPrecisionSettle", "previewID=\\(intent.id) preciseID=\\(preciseID) target=\\(String(format: \"%.3f\", intent.target)) idleMs=\\(Int((now - intent.requestedAt) * 1_000)) superseded=\\(superseded.map { String($0) } ?? \"none\") action=accurate-final-settle")\n            self.dispatchNativeSeek(precise, player: player)\n        }\n    }\n\n''',
    '',
)

# The unbounded request A/B repeatedly reproduced giant 13+ GiB localhost responses and MDK
# native seek wedges. Build115 freezes the stable 2 MiB bounded request path and removes the UI.
replace_once(
    engine_path,
    '    private var avioRequestSize2MiBEnabled: Bool { UserDefaults.standard.object(forKey: PlayerPreferenceKeys.mdkAVIORequestSize2MiBEnabled) as? Bool ?? true }\n',
    '',
)
replace_once(
    engine_path,
    '''            let boundedRequest2MiB = avioRequestSize2MiBEnabled\n            player.setProperty(name: "avio.multiple_requests", value: "1")\n            if boundedRequest2MiB { player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes)) }\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            let requestSizeLabel = boundedRequest2MiB ? String(avioRequestSizeBytes) : "unbounded"\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 requestSize=\\(requestSizeLabel) shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\\(transportMode)")\n            DiagnosticsLogger.shared.playback("MDKAVIOExperiment", "generation=\\(currentGeneration) boundedRequest2MiB=\\(boundedRequest2MiB) shortSeekSize=\\(avioShortSeekSizeBytes) appliesToNewSession=true")\n''',
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 requestSize=\\(avioRequestSizeBytes) shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\\(transportMode)")\n            DiagnosticsLogger.shared.playback("MDKAVIOExperiment", "generation=\\(currentGeneration) boundedRequest2MiB=true source=build115-forced shortSeekSize=\\(avioShortSeekSizeBytes)")\n''',
)

replace_once(settings_path, '    static let mdkAVIORequestSize2MiBEnabled = "player.mdkAVIORequestSize2MiBEnabled"\n', '')
replace_once(settings_view_path, '    @AppStorage(PlayerPreferenceKeys.mdkAVIORequestSize2MiBEnabled) private var mdkAVIORequestSize2MiBEnabled = true\n', '')
replace_once(
    settings_view_path,
    '''                Section(header: Text("MDK 实验"), footer: Text("临时 A/B 开关，仅影响新建 MDK 播放会话。开启时保持 Build111 的 avio.request_size=2 MiB；关闭时恢复 Build102 之前的 unbounded request_size。short_seek_size 仍保持 2 MiB，其它 Seek、缓存和恢复逻辑不变。")) {\n                    Toggle("2 MiB AVIO 请求限制", isOn: $mdkAVIORequestSize2MiBEnabled)\n                }\n\n''',
    '',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
settings = Path(settings_path).read_text()
settings_view = Path(settings_view_path).read_text()
assert 'mode=\\(fastPreview ? "relative-fast-only" : "absolute-accurate")' in engine
assert 'preciseSettle=disabled' in engine
assert 'case .forward, .backward: fastPreview = true' in engine
assert 'case .absolute: fastPreview = false' in engine
assert 'MDKSeekPrecisionSettle' not in engine
assert 'scheduleContinuousSeekPreciseSettle' not in engine
assert 'continuousSeekPreciseSettleSeconds' not in engine
assert 'action=native-latest-wins' in engine
assert 'action=preview-ignored-no-retry' in engine
assert 'player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))' in engine
assert 'boundedRequest2MiB=true source=build115-forced' in engine
assert 'avioRequestSize2MiBEnabled' not in engine
assert 'mdkAVIORequestSize2MiBEnabled' not in settings
assert 'mdkAVIORequestSize2MiBEnabled' not in settings_view
assert '2 MiB AVIO 请求限制' not in settings_view
assert 'sourceVersion = "0.13.48"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build115 MDK relative fast-only seek + absolute accurate scrub materialized")
