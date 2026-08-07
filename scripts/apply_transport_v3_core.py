from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Transport v3 patch target not found: {path}")
    p.write_text(text.replace(old, new, 1))


# 1) Keep an already-streaming sequential task alive when real playback demand lands inside it.
replace_once(
    "Sources/Transport/UnifiedMediaTransportSession.swift",
    '''        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) {
            if concretePlaybackDemand, slot0.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedDemand", "promote slot0 sequential->urgent request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) reason=\\(reason)")
                installUrgent(range: range, metadata: metadata, reason: "promote-\\(reason)")
                cancelSlot(0, reason: "promote-current-demand")
                scheduleSlots(reason: "promote-current-demand")
            }
            return
        }
''',
    '''        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) {
            if concretePlaybackDemand, slot0.role == .sequential {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream request=\\(range.lowerBound)-\\(range.upperBound) claim=\\(slot0.range.lowerBound)-\\(slot0.range.upperBound) reason=\\(reason) action=wait-progressive-chunk")
            }
            return
        }
'''
)

# 2) Automatic routing: native -> ResourceLoader AVPlayer; compatibility -> MPV, both sharing Unified Transport v3.
replace_once(
    "Sources/Player/PlaybackOrchestrator.swift",
    '''        if preference.isAutomatic, storedCompatibility || largeIndexedMP4 || !nativeFriendly {
            self.currentKind = .mpv
            let reason = storedCompatibility ? "stored-media-compatibility" : (largeIndexedMP4 ? "large-indexed-mp4" : "non-native-container-or-codec")
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=MPV+KTVProxyTransportV2 reason=\\(reason)")
        } else if preference.isAutomatic {
            self.currentKind = .ktvAVPlayer
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=AVPlayer+KTVProxyTransportV2 reason=native-friendly")
        } else {
''',
    '''        if preference.isAutomatic, storedCompatibility || largeIndexedMP4 || !nativeFriendly {
            self.currentKind = .mpv
            let reason = storedCompatibility ? "stored-media-compatibility" : (largeIndexedMP4 ? "large-indexed-mp4" : "non-native-container-or-codec")
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=MPV+UnifiedTransportV3 reason=\\(reason)")
        } else if preference.isAutomatic {
            self.currentKind = .resourceLoaderAVPlayer
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=AVPlayerResourceLoader+UnifiedTransportV3 reason=native-friendly")
        } else {
'''
)

replace_once(
    "Sources/Player/PlayerEngine.swift",
    '''            if nativeContainers.contains(source.normalizedContainer),
               video.isEmpty || nativeVideo.contains(video),
               audio.isEmpty || nativeAudio.contains(audio) {
                return .ktvAVPlayer
            }
            return .mpv
''',
    '''            if nativeContainers.contains(source.normalizedContainer),
               video.isEmpty || nativeVideo.contains(video),
               audio.isEmpty || nativeAudio.contains(audio) {
                return .resourceLoaderAVPlayer
            }
            return .mpv
'''
)

# 3) Engine switching no longer hands a KTV proxy session into automatic MPV.
replace_once(
    "Sources/Player/PlayerController.swift",
    '''        let ktvCacheHandoff: KTVCachePlaybackSession?
        if kind == .ktvAVPlayer || kind == .mpv {
            if let previous = previousEngine as? KTVAVPlayerEngine { ktvCacheHandoff = previous.takeCacheSessionForHandoff() }
            else if let previous = previousEngine as? KTVMPVPlayerEngine { ktvCacheHandoff = previous.takeCacheSessionForHandoff() }
            else { ktvCacheHandoff = nil }
        } else {
            ktvCacheHandoff = nil
        }
''',
    ''''''
)
replace_once(
    "Sources/Player/PlayerController.swift",
    '''            let nextEngine = Self.makeEngine(kind: kind, source: self.source, client: self.client, transportContext: self.transportContext, ktvCacheSession: ktvCacheHandoff)
''',
    '''            let nextEngine = Self.makeEngine(kind: kind, source: self.source, client: self.client, transportContext: self.transportContext)
'''
)
replace_once(
    "Sources/Player/PlayerController.swift",
    '''        transportContext: PlaybackTransportContext?,
        ktvCacheSession: KTVCachePlaybackSession? = nil
''',
    '''        transportContext: PlaybackTransportContext?
'''
)
replace_once(
    "Sources/Player/PlayerController.swift",
    '''        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: configuration, cacheSession: ktvCacheSession)
''',
    '''        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: configuration, cacheSession: nil)
'''
)
replace_once(
    "Sources/Player/PlayerController.swift",
    '''        case .mpv:
            return KTVMPVPlayerEngine(source: source, configuration: configuration, cacheSession: ktvCacheSession)
''',
    '''        case .mpv:
            return MPVPlayerEngine(sharedTransportSession: transportContext?.session)
'''
)

# 4) Remove duplicated v0.10 direct-MPV fallback blocks left by iterative patching.
mpv = Path("Sources/Player/MPVPlayerEngine.swift")
text = mpv.read_text()
block = '''        if sharedTransportSession == nil {
            DiagnosticsLogger.shared.log("MPVStream", "load direct HTTP transport=KTVProxyTransportV2 host=\\(url.host ?? "unknown")")
            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: false)
            return
        }
'''
count = text.count(block)
if count == 3:
    replacement = '''        if sharedTransportSession == nil {
            DiagnosticsLogger.shared.log("MPVStream", "load direct HTTP transport=direct-fallback host=\\(url.host ?? "unknown")")
            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: false)
            return
        }
'''
    text = text.replace(block, "")
    marker = '''        prepareUnifiedStreamAndLoad(
'''
    idx = text.index(marker, text.index("func prepare("))
    text = text[:idx] + replacement + text[idx:]
    mpv.write_text(text)
elif count != 0:
    if "transport=direct-fallback" not in text:
        raise SystemExit(f"Unexpected duplicated MPV direct blocks: {count}")

# 5) Version bump.
replace_once("project.yml", 'MARKETING_VERSION: "0.10.0"', 'MARKETING_VERSION: "0.11.0"')
replace_once("project.yml", 'CURRENT_PROJECT_VERSION: "53"', 'CURRENT_PROJECT_VERSION: "54"')
replace_once("project.yml", 'MARKETING_VERSION: "0.10.0"', 'MARKETING_VERSION: "0.11.0"')
replace_once("project.yml", 'CURRENT_PROJECT_VERSION: "53"', 'CURRENT_PROJECT_VERSION: "54"')
replace_once("Config/Info.plist", '<string>0.10.0</string>', '<string>0.11.0</string>')
replace_once("Config/Info.plist", '<string>53</string>', '<string>54</string>')
replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.10.0"', 'static let sourceVersion = "0.11.0"')
replace_once("Sources/Core/AppIdentity.swift", 'as? String ?? "0.10.0"', 'as? String ?? "0.11.0"')

print("Transport v3 core migration applied")
