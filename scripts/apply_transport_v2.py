from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, count))


# Stable 115Browser UA for both Emby/OneStrm resolution and redirected CDN bytes.
path = "Sources/Cache/EPLKTVCacheBridge.m"
replace(path, '#import <KTVHTTPCache/KTVHTTPCache.h>\n', '#import <KTVHTTPCache/KTVHTTPCache.h>\n\nstatic NSString * const EPLKTV115UserAgent = @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 115Browser/36.0.0 Chromium/125.0";\n')
replace(path, '''        NSMutableDictionary<NSString *, NSString *> *requestHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        requestHeaders[@"Accept-Encoding"] = @"identity";
        requestHeaders[@"Connection"] = @"keep-alive";
''', '''        NSMutableDictionary<NSString *, NSString *> *requestHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        [@[@"Authorization", @"X-Emby-Token", @"X-MediaBrowser-Token", @"Cookie", @"Set-Cookie"] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) { [requestHeaders removeObjectForKey:key]; }];
        requestHeaders[@"User-Agent"] = EPLKTV115UserAgent;
        requestHeaders[@"Accept-Encoding"] = @"identity";
        requestHeaders[@"Connection"] = @"keep-alive";
''')
replace(path, '''    [KTVHTTPCache downloadSetTimeoutInterval:45];

    NSMutableOrderedSet<NSString *> *keys''', '''    [KTVHTTPCache downloadSetTimeoutInterval:45];
    [KTVHTTPCache downloadSetAdditionalHeaders:@{
        @"User-Agent": EPLKTV115UserAgent,
        @"Accept-Encoding": @"identity",
        @"Connection": @"keep-alive"
    }];

    NSMutableOrderedSet<NSString *> *keys''')

# KTV long-range scheduler. Keep primary connection warm; only lane B yields to foreground starvation.
path = "Sources/Cache/KTVCachePlaybackSession.swift"
replace(path, '    private let segmentBytes: Int64 = 32 * 1_048_576\n', '    private let segmentBytes: Int64 = 512 * 1_048_576\n')
replace(path, '    private let singleBaselineSeconds: TimeInterval = 10\n', '    private let singleBaselineSeconds: TimeInterval = 0.75\n')
replace(path, '''            "proxy started originalHost=\\(source.url.host ?? "unknown") proxyPort=\\(proxyURL.port ?? 0) cacheBudget=\\(cacheBytes)B target=\\(targetCacheBytes)B segment=\\(segmentBytes)B scheduler=contiguous-frontier-1x2 metadataWarmup=\\(openWarmupEnabled) \\(NetworkPathMonitor.shared.diagnosticSummary)"
''', '''            "proxy started originalHost=\\(source.url.host ?? "unknown") proxyPort=\\(proxyURL.port ?? 0) cacheBudget=\\(cacheBytes)B target=\\(targetCacheBytes)B segment=\\(segmentBytes)B scheduler=transport-v2-long-range-1x2 uaProfile=115Browser/36.0.0 metadataWarmup=\\(openWarmupEnabled) \\(NetworkPathMonitor.shared.diagnosticSummary)"
''')
replace(path, '''        if shouldWarmLargeMP4Metadata {
            startLargeMP4StartupWarmup()
        } else {
            startInitialPreloadOnce()
            finishPlaybackPreparation()
        }
''', '''        if shouldWarmLargeMP4Metadata {
            startLargeMP4StartupWarmup()
        } else {
            // Open the localhost player first. Starting the preload loader a fraction later avoids
            // racing two fresh KTV requests for the same initial bytes while still warming the
            // long-lived background connection almost immediately.
            finishPlaybackPreparation()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.startInitialPreloadOnce() }
        }
''')
replace(path, '''    private func pauseBackgroundForPlaybackDemand() {
        lock.lock()
        primaryLane.generation &+= 1
        secondaryLane.generation &+= 1
        let primary = primaryLane.loader
        let secondary = secondaryLane.loader
        primaryLane.loader = nil
        secondaryLane.loader = nil
        primaryLane.active = false
        secondaryLane.active = false
        rangeMap.clearDownloading(lane: LaneID.primary.rawValue)
        rangeMap.clearDownloading(lane: LaneID.secondary.rawValue)
        lock.unlock()
        primary?.close()
        secondary?.close()
    }
''', '''    private func pauseBackgroundForPlaybackDemand() {
        // Keep the warmed primary 115/CDN connection alive. Repeatedly closing lane A destroys
        // connection reuse and CDN/TCP warm-up; foreground playback only asks lane B to yield.
        stopSecondaryLane(reason: "playback-priority-yield-secondary")
    }
''')

# Native AVPlayer talks only to localhost; KTV owns all remote request headers.
replace("Sources/Player/KTVAVPlayerEngine.swift", '''                    headers: headers,
                    preferredForwardBuffer: preferredForwardBuffer,
''', '''                    headers: [:],
                    preferredForwardBuffer: preferredForwardBuffer,
''')

# Automatic route uses KTV localhost proxy as the common transport.
path = "Sources/Player/PlaybackOrchestrator.swift"
replace(path, '            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=MPV+UnifiedTransport reason=\\(reason)")\n', '            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=MPV+KTVProxyTransportV2 reason=\\(reason)")\n')
replace(path, '''        } else if preference.isAutomatic {
            self.currentKind = .resourceLoaderAVPlayer
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=AVPlayerResourceLoader+UnifiedTransport reason=native-friendly")
''', '''        } else if preference.isAutomatic {
            self.currentKind = .ktvAVPlayer
            DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=AVPlayer+KTVProxyTransportV2 reason=native-friendly")
''')

replace("Sources/Player/PlayerEngine.swift", '''                return .resourceLoaderAVPlayer
            }
            return .mpv
''', '''                return .ktvAVPlayer
            }
            return .mpv
''')

# MPV supports a normal HTTP URL when no UnifiedTransport session is supplied. This is used only
# with the localhost KTV proxy in automatic mode.
path = "Sources/Player/MPVPlayerEngine.swift"
replace(path, '''        prepareUnifiedStreamAndLoad(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            startPosition: startPosition,
            compatibilityMode: false
        )
''', '''        if sharedTransportSession == nil {
            DiagnosticsLogger.shared.log("MPVStream", "load direct HTTP transport=KTVProxyTransportV2 host=\\(url.host ?? "unknown")")
            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: false)
            return
        }
        prepareUnifiedStreamAndLoad(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            startPosition: startPosition,
            compatibilityMode: false
        )
''')
replace(path, '        if streamBridge != nil {\n            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: true)\n', '        if sharedTransportSession == nil || streamBridge != nil {\n            load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, compatibilityMode: true)\n')
replace(path, '''            // libmpv never talks to 115 directly in v0.9. All bytes come from MPVUnifiedStreamBridge.
            self.updateHTTPHeaders(handle: handle, headers: [:])
''', '''            // Automatic Transport v2 points libmpv at KTV's localhost proxy. No Emby/115
            // credentials are forwarded to libmpv; KTV owns the remote request headers.
            self.updateHTTPHeaders(handle: handle, headers: self.streamBridge == nil ? headers : [:])
''')
replace(path, '            let target = self.streamBridge == nil && url.isFileURL ? url.path : "embyunified://media"\n', '''            let target: String
            if self.streamBridge != nil { target = "embyunified://media" }
            else if url.isFileURL { target = url.path }
            else { target = url.absoluteString }
''')

# Controller creates UnifiedTransport only for explicit legacy diagnostic engines and exposes the
# wrapped MPV Metal layer to the existing SwiftUI surface.
path = "Sources/Player/PlayerController.swift"
replace(path, '''    var mpvDisplayLayer: CAMetalLayer? {
        (engine as? MPVPlayerEngine)?.displayLayer
    }
''', '''    var mpvDisplayLayer: CAMetalLayer? {
        if let engine = engine as? MPVPlayerEngine { return engine.displayLayer }
        if let engine = engine as? KTVMPVPlayerEngine { return engine.displayLayer }
        return nil
    }
''')
replace(path, '''        let configuration = MediaTransportConfiguration.current()
        // v0.9 keeps one unified byte source alive for the whole playback session so
        // AVPlayer and mpv can switch consumers without opening a second 115 pipeline.
        let transportContext: PlaybackTransportContext? = PlaybackTransportContext(source: source, client: client, configuration: configuration)
''', '''        let configuration = MediaTransportConfiguration.current()
        // Transport v2 automatic engines use the KTV localhost proxy. Build UnifiedTransport only
        // for explicit diagnostic engines so it cannot open or cancel 115 connections in parallel.
        let usesUnifiedTransport = initialKind == .resourceLoaderAVPlayer || initialKind == .transportAVPlayer || initialKind == .ksAVIO
        let transportContext: PlaybackTransportContext? = usesUnifiedTransport ? PlaybackTransportContext(source: source, client: client, configuration: configuration) : nil
''')
replace(path, '''        case .mpv:
            return MPVPlayerEngine(sharedTransportSession: transportContext?.session)
''', '''        case .mpv:
            return KTVMPVPlayerEngine(source: source, configuration: configuration)
''')

# v0.10.0 / Build 53.
replace("Sources/Core/AppIdentity.swift", '    static let sourceVersion = "0.9.6"\n', '    static let sourceVersion = "0.10.0"\n')
replace("Sources/Core/AppIdentity.swift", '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.6"\n', '    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.10.0"\n')
replace("Config/Info.plist", '<key>CFBundleShortVersionString</key>\n\t<string>0.9.6</string>', '<key>CFBundleShortVersionString</key>\n\t<string>0.10.0</string>')
replace("Config/Info.plist", '<key>CFBundleVersion</key>\n\t<string>52</string>', '<key>CFBundleVersion</key>\n\t<string>53</string>')

p = Path("project.yml")
text = p.read_text()
new = text.replace('MARKETING_VERSION: "0.9.6"', 'MARKETING_VERSION: "0.10.0"').replace('CURRENT_PROJECT_VERSION: "52"', 'CURRENT_PROJECT_VERSION: "53"')
if new == text and 'MARKETING_VERSION: "0.10.0"' not in text:
    raise SystemExit("project version markers not found")
p.write_text(new)
