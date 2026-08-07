from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, count))


path = "Sources/Cache/EPLKTVCacheBridge.m"
p = Path(path)
text = p.read_text()
ua_line = 'static NSString * const EPLKTV115UserAgent = @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 115Browser/36.0.0 Chromium/125.0";\n'
while text.count(ua_line) > 1:
    text = text.replace(ua_line + "\n" + ua_line, ua_line, 1)
p.write_text(text)

replace(path, '''        NSMutableDictionary<NSString *, NSString *> *requestHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        [@[@"Authorization", @"X-Emby-Token", @"X-MediaBrowser-Token", @"Cookie", @"Set-Cookie"] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) { [requestHeaders removeObjectForKey:key]; }];
        requestHeaders[@"User-Agent"] = EPLKTV115UserAgent;
''', '''        NSMutableDictionary<NSString *, NSString *> *requestHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        NSSet<NSString *> *sensitiveHeaderKeys = [NSSet setWithArray:@[@"authorization", @"x-emby-token", @"x-mediabrowser-token", @"cookie", @"set-cookie"]];
        for (NSString *key in requestHeaders.allKeys.copy) {
            if ([sensitiveHeaderKeys containsObject:key.lowercaseString]) [requestHeaders removeObjectForKey:key];
        }
        requestHeaders[@"User-Agent"] = EPLKTV115UserAgent;
''')
replace(path, '''    NSMutableOrderedSet<NSString *> *keys = [NSMutableOrderedSet orderedSetWithArray:@[
        @"User-Agent", @"Connection", @"Accept", @"Accept-Encoding", @"Accept-Language", @"Range", @"Referer", @"Origin"
    ]];
''', '''    NSMutableOrderedSet<NSString *> *keys = [NSMutableOrderedSet orderedSetWithArray:@[
        @"Connection", @"Accept", @"Accept-Encoding", @"Accept-Language", @"Range", @"Referer", @"Origin"
    ]];
''')
replace(path, '''        if ([lower isEqualToString:@"authorization"] || [lower isEqualToString:@"cookie"] || [lower isEqualToString:@"x-emby-token"] || [lower isEqualToString:@"x-mediabrowser-token"]) continue;
        [keys addObject:key];
''', '''        if ([lower isEqualToString:@"authorization"] || [lower isEqualToString:@"cookie"] || [lower isEqualToString:@"x-emby-token"] || [lower isEqualToString:@"x-mediabrowser-token"] || [lower isEqualToString:@"user-agent"]) continue;
        [keys addObject:key];
''')

replace("Sources/Cache/KTVCachePlaybackSession.swift", '''        probeOriginInBackground()
        if shouldWarmLargeMP4Metadata {
''', '''        DiagnosticsLogger.shared.log("KTVOrigin", "probe skipped transport-v2 reason=avoid-second-UA-bound-115-link")
        if shouldWarmLargeMP4Metadata {
''')

replace("Sources/Cache/KTVCachePlaybackSession.swift", '''    func prioritizeSeek(position: Double, duration: Double) {
        lock.lock()
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        lastSeekAt = Date()
        let frontier = rangeMap.contiguousFrontier(from: schedulerAnchorByte)
        lock.unlock()
        DiagnosticsLogger.shared.log(
            "BufferAnchor",
            "reason=user-seek position=\\(position) byteGuess=disabled schedulerAnchor=\\(schedulerAnchorByte) frontier=\\(frontier) action=keep-sequential-preload waitingForRealProxyDemand=true"
        )
        ensurePreloadActive(reason: "seek keeps contiguous frontier")
    }
''', '''    func prioritizeSeek(position: Double, duration: Double) {
        let now = Date()
        lock.lock()
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        lastSeekAt = now
        playbackPriorityUntil = max(playbackPriorityUntil, now.addingTimeInterval(1.0))
        let frontier = rangeMap.contiguousFrontier(from: schedulerAnchorByte)
        lock.unlock()
        stopSecondaryLane(reason: "user-seek-yield-secondary")
        DiagnosticsLogger.shared.log(
            "BufferAnchor",
            "reason=user-seek position=\\(position) byteGuess=disabled schedulerAnchor=\\(schedulerAnchorByte) frontier=\\(frontier) action=keep-primary-yield-secondary waitingForRealProxyDemand=true"
        )
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.05) { [weak self] in self?.scheduleAvailableWorkers(reason: "user-seek-priority-ended") }
    }
''')

controller = "Sources/Player/PlayerController.swift"
replace(controller, '''        // Transport v2 automatic engines use the KTV localhost proxy. Build UnifiedTransport only
        // for explicit diagnostic engines so it cannot open or cancel 115 connections in parallel.
        let usesUnifiedTransport = initialKind == .resourceLoaderAVPlayer || initialKind == .transportAVPlayer || initialKind == .ksAVIO
        let transportContext: PlaybackTransportContext? = usesUnifiedTransport ? PlaybackTransportContext(source: source, client: client, configuration: configuration) : nil
''', '''        // Keep the diagnostic UnifiedTransport context lazy and available for manual engine switches.
        // Construction performs no network I/O; automatic KTV/MPV Transport v2 does not consume it.
        let transportContext: PlaybackTransportContext? = PlaybackTransportContext(source: source, client: client, configuration: configuration)
''')

replace(controller, '''        previousEngine.onSnapshot = nil
        previousEngine.onSeekCompleted = nil
        engine = SuspendedPlayerEngine(kind: previousKind)
''', '''        previousEngine.onSnapshot = nil
        previousEngine.onSeekCompleted = nil
        let ktvCacheHandoff: KTVCachePlaybackSession?
        if kind == .ktvAVPlayer || kind == .mpv {
            if let previous = previousEngine as? KTVAVPlayerEngine { ktvCacheHandoff = previous.takeCacheSessionForHandoff() }
            else if let previous = previousEngine as? KTVMPVPlayerEngine { ktvCacheHandoff = previous.takeCacheSessionForHandoff() }
            else { ktvCacheHandoff = nil }
        } else {
            ktvCacheHandoff = nil
        }
        engine = SuspendedPlayerEngine(kind: previousKind)
''')

replace(controller, '''            let nextEngine = Self.makeEngine(kind: kind, source: self.source, client: self.client, transportContext: self.transportContext)
''', '''            let nextEngine = Self.makeEngine(kind: kind, source: self.source, client: self.client, transportContext: self.transportContext, ktvCacheSession: ktvCacheHandoff)
''')

replace(controller, '''        client: EmbyAPIClient,
        transportContext: PlaybackTransportContext?
    ) -> PlayerEngine {
''', '''        client: EmbyAPIClient,
        transportContext: PlaybackTransportContext?,
        ktvCacheSession: KTVCachePlaybackSession? = nil
    ) -> PlayerEngine {
''')
replace(controller, '''        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: configuration, cacheSession: nil)
''', '''        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: configuration, cacheSession: ktvCacheSession)
''')
replace(controller, '''        case .mpv:
            return KTVMPVPlayerEngine(source: source, configuration: configuration)
''', '''        case .mpv:
            return KTVMPVPlayerEngine(source: source, configuration: configuration, cacheSession: ktvCacheSession)
''')
