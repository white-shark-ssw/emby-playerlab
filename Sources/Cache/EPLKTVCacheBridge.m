#import "EPLKTVCacheBridge.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface EPLKTVPreloadHandle () <KTVHCDataLoaderDelegate>
@property (nonatomic, strong) KTVHCDataLoader *loader;
@property (nonatomic, copy, nullable) EPLKTVPreloadProgressHandler progressHandler;
@property (nonatomic, copy, nullable) EPLKTVPreloadCompletionHandler completionHandler;
@property (nonatomic, assign) BOOL completionDelivered;
@end

@implementation EPLKTVPreloadHandle

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary<NSString *, NSString *> *)headers startOffset:(long long)startOffset endOffset:(long long)endOffset progress:(EPLKTVPreloadProgressHandler)progress completion:(EPLKTVPreloadCompletionHandler)completion {
    self = [super init];
    if (self) {
        NSMutableDictionary<NSString *, NSString *> *requestHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        requestHeaders[@"Accept-Encoding"] = @"identity";
        requestHeaders[@"Connection"] = @"keep-alive";
        if (endOffset >= startOffset && endOffset >= 0) requestHeaders[@"Range"] = [NSString stringWithFormat:@"bytes=%lld-%lld", MAX(0, startOffset), endOffset];
        else requestHeaders[@"Range"] = [NSString stringWithFormat:@"bytes=%lld-", MAX(0, startOffset)];

        KTVHCDataRequest *request = [[KTVHCDataRequest alloc] initWithURL:URL headers:requestHeaders];
        _loader = [KTVHTTPCache cacheLoaderWithRequest:request];
        _loader.delegate = self;
        _progressHandler = [progress copy];
        _completionHandler = [completion copy];
        [_loader prepare];
    }
    return self;
}

- (long long)loadedLength { return self.loader.loadedLength; }
- (double)progress { return self.loader.progress; }
- (BOOL)isFinished { return self.loader.isFinished; }

- (void)close {
    self.loader.delegate = nil;
    [self.loader close];
    self.progressHandler = nil;
    self.completionHandler = nil;
}

- (void)ktv_loaderDidFinish:(KTVHCDataLoader *)loader {
    if (self.completionDelivered) return;
    self.completionDelivered = YES;
    if (self.progressHandler) self.progressHandler(loader.loadedLength, loader.progress);
    if (self.completionHandler) self.completionHandler(nil);
}

- (void)ktv_loader:(KTVHCDataLoader *)loader didFailWithError:(NSError *)error {
    if (self.completionDelivered) return;
    self.completionDelivered = YES;
    if (self.completionHandler) self.completionHandler(error);
}

- (void)ktv_loader:(KTVHCDataLoader *)loader didChangeProgress:(double)progress {
    if (self.progressHandler) self.progressHandler(loader.loadedLength, progress);
}

@end

@implementation EPLKTVCacheBridge

+ (NSError *)startWithMaxCacheLength:(long long)maxCacheLength allowedHeaderKeys:(NSArray<NSString *> *)allowedHeaderKeys {
    long long safeLength = MAX(64LL * 1024LL * 1024LL, maxCacheLength);
    [KTVHTTPCache cacheSetMaxCacheLength:safeLength];
    [KTVHTTPCache downloadSetTimeoutInterval:45];

    NSMutableOrderedSet<NSString *> *keys = [NSMutableOrderedSet orderedSetWithArray:@[
        @"User-Agent", @"Connection", @"Accept", @"Accept-Encoding", @"Accept-Language", @"Range", @"Referer", @"Origin"
    ]];
    for (NSString *key in allowedHeaderKeys) {
        NSString *lower = key.lowercaseString;
        if ([lower isEqualToString:@"authorization"] || [lower isEqualToString:@"cookie"] || [lower isEqualToString:@"x-emby-token"] || [lower isEqualToString:@"x-mediabrowser-token"]) continue;
        [keys addObject:key];
    }
    [KTVHTTPCache downloadSetWhitelistHeaderKeys:keys.array];
    [KTVHTTPCache downloadSetAcceptableContentTypes:@[
        @"video/mp4", @"video/quicktime", @"video/x-matroska", @"video/x-msvideo", @"video/mp2t",
        @"audio/mpeg", @"audio/mp4", @"audio/aac", @"application/mp4", @"application/octet-stream", @"application/force-download", @"application/download", @"binary/octet-stream", @"application/x-mpegURL", @"application/vnd.apple.mpegurl"
    ]];
    [KTVHTTPCache downloadSetUnacceptableContentTypeDisposer:^BOOL(NSURL *URL, NSString *contentType) {
        NSString *lower = contentType.lowercaseString;
        return [lower hasPrefix:@"video/"] || [lower hasPrefix:@"audio/"] || [lower isEqualToString:@"application/octet-stream"] || [lower isEqualToString:@"application/force-download"] || [lower isEqualToString:@"application/download"];
    }];
    [KTVHTTPCache encodeSetURLConverter:^NSURL *(NSURL *URL) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
        if (!components) return URL;
        NSSet<NSString *> *volatileKeys = [NSSet setWithArray:@[@"api_key", @"playsessionid", @"deviceid"]];
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
        for (NSURLQueryItem *item in components.queryItems ?: @[]) {
            if (![volatileKeys containsObject:item.name.lowercaseString]) [items addObject:item];
        }
        components.queryItems = items.count > 0 ? items : nil;
        return components.URL ?: URL;
    }];
    [KTVHTTPCache logSetConsoleLogEnable:NO];
    [KTVHTTPCache logSetRecordLogEnable:NO];

    if ([KTVHTTPCache proxyIsRunning]) return nil;
    NSError *error = nil;
    BOOL started = [KTVHTTPCache proxyStart:&error];
    if (started) return nil;
    return error ?: [NSError errorWithDomain:@"EmbyPlayerLab.KTVHTTPCache" code:1 userInfo:@{NSLocalizedDescriptionKey: @"KTVHTTPCache local proxy failed to start."}];
}

+ (NSURL *)proxyURLForOriginalURL:(NSURL *)URL { return [KTVHTTPCache proxyURLWithOriginalURL:URL]; }

+ (EPLKTVPreloadHandle *)preloadURL:(NSURL *)URL headers:(NSDictionary<NSString *,NSString *> *)headers startOffset:(long long)startOffset endOffset:(long long)endOffset progress:(EPLKTVPreloadProgressHandler)progress completion:(EPLKTVPreloadCompletionHandler)completion {
    return [[EPLKTVPreloadHandle alloc] initWithURL:URL headers:headers startOffset:startOffset endOffset:endOffset progress:progress completion:completion];
}

+ (long long)totalCacheLength { return [KTVHTTPCache cacheTotalCacheLength]; }
+ (long long)cacheLengthForOriginalURL:(NSURL *)URL { return [KTVHTTPCache cacheCacheItemWithURL:URL].cacheLength; }
+ (long long)resourceLengthForOriginalURL:(NSURL *)URL { return [KTVHTTPCache cacheCacheItemWithURL:URL].totalLength; }
+ (NSURL *)completeFileURLForOriginalURL:(NSURL *)URL { return [KTVHTTPCache cacheCompleteFileURLWithURL:URL]; }
+ (void)deleteCacheForOriginalURL:(NSURL *)URL { [KTVHTTPCache cacheDeleteCacheWithURL:URL]; }
+ (NSURL *)recordLogFileURL { return [KTVHTTPCache logRecordLogFileURL]; }
+ (void)clearAllCaches { [KTVHTTPCache cacheDeleteAllCaches]; }

@end
