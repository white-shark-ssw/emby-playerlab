#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^EPLKTVPreloadProgressHandler)(long long loadedLength, double progress);
typedef void (^EPLKTVPreloadCompletionHandler)(NSError * _Nullable error);

@interface EPLKTVPreloadHandle : NSObject

@property (nonatomic, readonly) long long loadedLength;
@property (nonatomic, readonly) double progress;
@property (nonatomic, readonly, getter=isFinished) BOOL finished;

- (void)close;

@end

@interface EPLKTVCacheBridge : NSObject

+ (NSError * _Nullable)startWithMaxCacheLength:(long long)maxCacheLength allowedHeaderKeys:(NSArray<NSString *> *)allowedHeaderKeys NS_SWIFT_NAME(start(maxCacheLength:allowedHeaderKeys:));
+ (NSURL *)proxyURLForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(proxyURL(for:));
+ (EPLKTVPreloadHandle *)preloadURL:(NSURL *)URL headers:(NSDictionary<NSString *, NSString *> *)headers startOffset:(long long)startOffset endOffset:(long long)endOffset progress:(EPLKTVPreloadProgressHandler _Nullable)progress completion:(EPLKTVPreloadCompletionHandler _Nullable)completion NS_SWIFT_NAME(preload(url:headers:startOffset:endOffset:progress:completion:));
+ (long long)totalCacheLength NS_SWIFT_NAME(totalCacheLength());
+ (long long)cacheLengthForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(cacheLength(for:));
+ (long long)resourceLengthForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(resourceLength(for:));
+ (NSInteger)cacheZoneCountForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(cacheZoneCount(for:));
+ (NSURL * _Nullable)completeFileURLForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(completeFileURL(for:));
+ (void)deleteCacheForOriginalURL:(NSURL *)URL NS_SWIFT_NAME(deleteCache(for:));
+ (NSURL * _Nullable)recordLogFileURL NS_SWIFT_NAME(recordLogFileURL());
+ (void)clearAllCaches NS_SWIFT_NAME(clearAllCaches());

@end

NS_ASSUME_NONNULL_END
