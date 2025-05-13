#include <sys/sysctl.h>

#import "FPAnalytics.h"
#import "FPUtils.h"
#import "FPFreshpaintIntegration.h"
#import "FPReachability.h"
#import "FPHTTPClient.h"
#import "FPStorage.h"
#import "FPMacros.h"
#import "FPState.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_IOS
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

NSString *const FPFreshpaintDidSendRequest = @"FreshpaintDidSendRequest";
NSString *const FPFreshpaintRequestDidSucceedNotification = @"FreshpaintRequestDidSucceed";
NSString *const FPFreshpaintRequestDidFailNotification = @"FreshpaintRequestDidFail";

NSString *const FPUserIdKey = @"FPUserId";
NSString *const FPQueueKey = @"FPQueue";
NSString *const FPTraitsKey = @"FPTraits";

NSString *const kFPUserIdFilename = @"freshpaintio.userId";
NSString *const kFPQueueFilename = @"freshpaintio.queue.plist";
NSString *const kFPTraitsFilename = @"freshpaintio.traits.plist";

// Equiv to UIBackgroundTaskInvalid.
NSUInteger const kFPBackgroundTaskInvalid = 0;

@interface FPFreshpaintIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, strong) FPReachability *reachability;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;
@property (nonatomic, strong) NSDictionary *traits;
@property (nonatomic, assign) FPAnalytics *analytics;
@property (nonatomic, assign) FPAnalyticsConfiguration *configuration;
@property (atomic, copy) NSDictionary *referrer;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, strong) NSURL *apiURL;
@property (nonatomic, strong) FPHTTPClient *httpClient;
@property (nonatomic, strong) id<FPStorage> fileStorage;
@property (nonatomic, strong) id<FPStorage> userDefaultsStorage;

#if TARGET_OS_IPHONE
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
#else
@property (nonatomic, assign) NSUInteger flushTaskID;
#endif

@end

@interface FPAnalytics ()
@property (nonatomic, strong, readonly) FPAnalyticsConfiguration *oneTimeConfiguration;
@end

@implementation FPFreshpaintIntegration

- (id)initWithAnalytics:(FPAnalytics *)analytics httpClient:(FPHTTPClient *)httpClient fileStorage:(id<FPStorage>)fileStorage userDefaultsStorage:(id<FPStorage>)userDefaultsStorage;
{
    if (self = [super init]) {
        self.analytics = analytics;
        self.configuration = analytics.oneTimeConfiguration;
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = analytics.oneTimeConfiguration.httpSessionDelegate;
        self.fileStorage = fileStorage;
        self.userDefaultsStorage = userDefaultsStorage;
        self.apiURL = [FRESHPAINT_API_BASE URLByAppendingPathComponent:@"import"];
        self.reachability = [FPReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.serialQueue = seg_dispatch_queue_create_specific("io.freshpaint.analytics.freshpaintio", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = seg_dispatch_queue_create_specific("io.freshpaint.analytics.backgroundTask", DISPATCH_QUEUE_SERIAL);
#if TARGET_OS_IPHONE
        self.flushTaskID = UIBackgroundTaskInvalid;
#else
        self.flushTaskID = 0; // the actual value of UIBackgroundTaskInvalid
#endif
        
        // load traits & user from disk.
        [self loadUserId];
        [self loadTraits];

        [self dispatchBackground:^{
            // Check for previous queue data in NSUserDefaults and remove if present.
            if ([[NSUserDefaults standardUserDefaults] objectForKey:FPQueueKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPQueueKey];
            }
#if !TARGET_OS_TV
            // Check for previous track data in NSUserDefaults and remove if present (Traits still exist in NSUserDefaults on tvOS)
            if ([[NSUserDefaults standardUserDefaults] objectForKey:FPTraitsKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPTraitsKey];
            }
#endif
        }];

        self.flushTimer = [NSTimer timerWithTimeInterval:self.configuration.flushInterval
                                                  target:self
                                                selector:@selector(flush)
                                                userInfo:nil
                                                 repeats:YES];
        
        [NSRunLoop.mainRunLoop addTimer:self.flushTimer
                                forMode:NSDefaultRunLoopMode];        
    }
    return self;
}

- (void)dispatchBackground:(void (^)(void))block
{
    seg_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    seg_dispatch_specific_sync(_serialQueue, block);
}

- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    seg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        
        id<FPApplicationProtocol> application = [self.analytics oneTimeConfiguration].application;
        if (application && [application respondsToSelector:@selector(seg_beginBackgroundTaskWithName:expirationHandler:)]) {
            self.flushTaskID = [application seg_beginBackgroundTaskWithName:@"Freshpaintio.Flush"
                                                          expirationHandler:^{
                                                              [self endBackgroundTask];
                                                          }];
        }
    });
}

- (void)endBackgroundTask
{
    // endBackgroundTask and beginBackgroundTask can be called from main thread
    // We should not dispatch to the same queue we use to flush events because it can cause deadlock
    // inside @synchronized(self) block for FPIntegrationsManager as both events queue and main queue
    // attempt to call forwardSelector:arguments:options:
    // See https://github.com/segmentio/analytics-ios/issues/683
    seg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        if (self.flushTaskID != kFPBackgroundTaskInvalid) {
            id<FPApplicationProtocol> application = [self.analytics oneTimeConfiguration].application;
            if (application && [application respondsToSelector:@selector(seg_endBackgroundTask:)]) {
                [application seg_endBackgroundTask:self.flushTaskID];
            }

            self.flushTaskID = kFPBackgroundTaskInvalid;
        }
    });
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.writeKey];
}

- (NSString *)userId
{
    return [FPState sharedInstance].userInfo.userId;
}

- (void)setUserId:(NSString *)userId
{
    [self dispatchBackground:^{
        [FPState sharedInstance].userInfo.userId = userId;
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:userId forKey:FPUserIdKey];
#else
        [self.fileStorage setString:userId forKey:kFPUserIdFilename];
#endif
    }];
}

- (NSDictionary *)traits
{
    return [FPState sharedInstance].userInfo.traits;
}

- (void)setTraits:(NSDictionary *)traits
{
    [self dispatchBackground:^{
        [FPState sharedInstance].userInfo.traits = traits;
#if TARGET_OS_TV
        [self.userDefaultsStorage setDictionary:[self.traits copy] forKey:FPTraitsKey];
#else
        [self.fileStorage setDictionary:[self.traits copy] forKey:kFPTraitsFilename];
#endif
    }];
}

#pragma mark - Analytics API

- (void)identify:(FPIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        self.userId = payload.userId;
        self.traits = payload.traits;
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
    [self enqueueAction:@"identify" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)track:(FPTrackPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"event"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];
    [self enqueueAction:@"track" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)screen:(FPScreenPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.name forKey:@"name"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"screen" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)group:(FPGroupPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.groupId forKey:@"groupId"];
    [dictionary setValue:payload.traits forKey:@"traits"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"group" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)alias:(FPAliasPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.theNewId forKey:@"userId"];
    [dictionary setValue:self.userId ?: [self.analytics getAnonymousId] forKey:@"previousId"];
    [dictionary setValue:payload.timestamp forKey:@"timestamp"];
    [dictionary setValue:payload.messageId forKey:@"messageId"];

    [self enqueueAction:@"alias" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

#pragma mark - Queueing

// Merges user provided integration options with bundled integrations.
- (NSDictionary *)integrationsDictionary:(NSDictionary *)integrations
{
    NSMutableDictionary *dict = [integrations ?: @{} mutableCopy];
    for (NSString *integration in self.analytics.bundledIntegrations) {
        // Don't record Freshpaint.io in the dictionary. It is always enabled.
        if ([integration isEqualToString:@"Freshpaint.io"]) {
            continue;
        }
        dict[integration] = @NO;
    }
    return [dict copy];
}

- (void)enqueueAction:(NSString *)action dictionary:(NSMutableDictionary *)payload context:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    // attach these parts of the payload outside since they are all synchronous
    payload[@"type"] = action;

    [self dispatchBackground:^{
        // attach userId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        // Do not override the userId for an 'alias' action. This value is set in [alias:] already.
        if (![action isEqualToString:@"alias"]) {
            [payload setValue:[FPState sharedInstance].userInfo.userId forKey:@"userId"];
        }
        [payload setValue:[self.analytics getAnonymousId] forKey:@"anonymousId"];

        [payload setValue:[self integrationsDictionary:integrations] forKey:@"integrations"];

        [payload setValue:[context copy] forKey:@"context"];

        FPLog(@"%@ Enqueueing action: %@", self, payload);
        
        NSDictionary *queuePayload = [payload copy];
        
        if (self.configuration.experimental.rawFreshpaintModificationBlock != nil) {
            NSDictionary *tempPayload = self.configuration.experimental.rawFreshpaintModificationBlock(queuePayload);
            if (tempPayload == nil) {
                FPLog(@"rawFreshpaintModificationBlock cannot be used to drop events!");
            } else {
                // prevent anything else from modifying it at this point.
                queuePayload = [tempPayload copy];
            }
        }
        [self queuePayload:queuePayload];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
        // Trim the queue to maxQueueSize - 1 before we add a new element.
        trimQueue(self.queue, self.analytics.oneTimeConfiguration.maxQueueSize - 1);
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];
    }
    @catch (NSException *exception) {
        FPLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    void (^startBatch)(void) = ^{
        NSArray *batch;
        if ([self.queue count] >= maxBatchSize) {
            batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
        } else {
            batch = [NSArray arrayWithArray:self.queue];
        }
        [self sendData:batch];
    };
    
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            FPLog(@"%@ No queued API calls to flush.", self);
            [self endBackgroundTask];
            return;
        }
        if (self.batchRequest != nil) {
            FPLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        }
        // here
        startBatch();
    }];
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        FPLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.batchRequest == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
#if TARGET_OS_TV
        [self.userDefaultsStorage removeKey:FPUserIdKey];
        [self.userDefaultsStorage removeKey:FPTraitsKey];
#else
        [self.fileStorage removeKey:kFPUserIdFilename];
        [self.fileStorage removeKey:kFPTraitsFilename];
#endif
        self.userId = nil;
        self.traits = [NSMutableDictionary dictionary];
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:userInfo];
        FPLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSArray *)batch
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setObject:iso8601FormattedString([NSDate date]) forKey:@"sentAt"];
    [payload setObject:batch forKey:@"batch"];

    [self.state validateOrRenewSessionWithTimeout:self.configuration.sessionTimeout ?: 1800];
    NSString *sessionParameter = [NSString stringWithFormat:@"$%@", self.state.userInfo.sessionId];

    [payload setObject:sessionParameter forKey:@"$session_id"];

    FPLog(@"%@ Flushing %lu of %lu queued API calls.", self, (unsigned long)batch.count, (unsigned long)self.queue.count);
    FPLog(@"Flushing batch %@.", payload);

    self.batchRequest = [self.httpClient upload:payload forWriteKey:self.configuration.writeKey completionHandler:^(BOOL retry) {
        void (^completion)(void) = ^{
            if (retry) {
                [self notifyForName:FPFreshpaintRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                [self endBackgroundTask];
                return;
            }

            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:FPFreshpaintRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
            [self endBackgroundTask];
        };
        
        [self dispatchBackground:completion];
    }];

    [self notifyForName:FPFreshpaintDidSendRequest userInfo:batch];
}

- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)
            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
        _queue = [[self.fileStorage arrayForKey:kFPQueueFilename] ?: @[] mutableCopy];
    }

    return _queue;
}

- (void)loadTraits
{
    if (![FPState sharedInstance].userInfo.traits) {
        NSDictionary *traits = nil;
#if TARGET_OS_TV
        traits = [[self.userDefaultsStorage dictionaryForKey:FPTraitsKey] ?: @{} mutableCopy];
#else
        traits = [[self.fileStorage dictionaryForKey:kFPTraitsFilename] ?: @{} mutableCopy];
#endif
        [FPState sharedInstance].userInfo.traits = traits;
    }
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (void)loadUserId
{
    NSString *result = nil;
#if TARGET_OS_TV
    result = [[NSUserDefaults standardUserDefaults] valueForKey:FPUserIdKey];
#else
    result = [self.fileStorage stringForKey:kFPUserIdFilename];
#endif
    [FPState sharedInstance].userInfo.userId = result;
}

- (void)persistQueue
{
    [self.fileStorage setArray:[self.queue copy] forKey:kFPQueueFilename];
}

@end
