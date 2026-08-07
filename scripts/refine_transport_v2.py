from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"Expected text not found in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, count))


# KTV remote User-Agent must come only from the stable additional header. Do not allow AVPlayer/MPV
# localhost request headers to override it, and strip sensitive headers case-insensitively.
path = "Sources/Cache/EPLKTVCacheBridge.m"
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

# Avoid opening a second wrong-UA diagnostic 302/CDN request beside KTV's real transport.
replace("Sources/Cache/KTVCachePlaybackSession.swift", '''        probeOriginInBackground()
        if shouldWarmLargeMP4Metadata {
''', '''        DiagnosticsLogger.shared.log("KTVOrigin", "probe skipped transport-v2 reason=avoid-second-UA-bound-115-link")
        if shouldWarmLargeMP4Metadata {
''')

# Keep the lazy UnifiedTransport context available for explicit diagnostic engine switches. Merely
# constructing it does not open the network; automatic KTV/MPV never consume the session.
replace("Sources/Player/PlayerController.swift", '''        // Transport v2 automatic engines use the KTV localhost proxy. Build UnifiedTransport only
        // for explicit diagnostic engines so it cannot open or cancel 115 connections in parallel.
        let usesUnifiedTransport = initialKind == .resourceLoaderAVPlayer || initialKind == .transportAVPlayer || initialKind == .ksAVIO
        let transportContext: PlaybackTransportContext? = usesUnifiedTransport ? PlaybackTransportContext(source: source, client: client, configuration: configuration) : nil
''', '''        // Keep the diagnostic UnifiedTransport context lazy and available for manual engine switches.
        // Construction performs no network I/O; automatic KTV/MPV Transport v2 does not consume it.
        let transportContext: PlaybackTransportContext? = PlaybackTransportContext(source: source, client: client, configuration: configuration)
''')
