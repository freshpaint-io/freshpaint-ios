//
//  FPState.m
//  Analytics
//
//  Created by Brandon Sneed on 6/9/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import "FPState.h"
#import "FPAnalytics.h"
#import "FPAnalyticsUtils.h"
#import "FPReachability.h"
#import "FPUtils.h"

typedef void (^FPStateSetBlock)(void);
typedef _Nullable id (^FPStateGetBlock)(void);


@interface FPState()
// State Objects
@property (nonatomic, nonnull) FPUserInfo *userInfo;
@property (nonatomic, nonnull) FPPayloadContext *context;
// State Accessors
- (void)setValueWithBlock:(FPStateSetBlock)block;
- (id)valueWithBlock:(FPStateGetBlock)block;
@end


@protocol FPStateObject
@property (nonatomic, weak) FPState *state;
- (instancetype)initWithState:(FPState *)state;
@end


@interface FPUserInfo () <FPStateObject> {
    @public
    NSString *_sessionId;
    NSTimeInterval _lastSessionTimestamp;
    BOOL _isFirstEventInSession;
    NSDictionary<NSString *, id> *_clickIds;
    NSDictionary<NSString *, NSString *> *_utmParams;
    NSTimeInterval _utmExpiryTimestamp;
}
@end

@interface FPPayloadContext () <FPStateObject>
@property (nonatomic, strong) FPReachability *reachability;
@property (nonatomic, strong) NSDictionary *cachedStaticContext;
@end

#pragma mark - FPUserInfo

@implementation FPUserInfo

@synthesize state;

@synthesize anonymousId = _anonymousId;
@synthesize userId = _userId;
@synthesize traits = _traits;
@synthesize sessionId = _sessionId;
@synthesize lastSessionTimestamp = _lastSessionTimestamp;
@synthesize isFirstEventInSession = _isFirstEventInSession;
@synthesize clickIds = _clickIds;
@synthesize utmParams = _utmParams;
@synthesize utmExpiryTimestamp = _utmExpiryTimestamp;

- (instancetype)initWithState:(FPState *)state
{
    if (self = [super init]) {
        self.state = state;
    }
    return self;
}

- (NSString *)anonymousId
{
    return [state valueWithBlock: ^id{
        return self->_anonymousId;
    }];
}

- (void)setAnonymousId:(NSString *)anonymousId
{
    [state setValueWithBlock: ^{
        self->_anonymousId = [anonymousId copy];
    }];
}

- (NSString *)userId
{
    return [state valueWithBlock: ^id{
        return self->_userId;
    }];
}

- (void)setUserId:(NSString *)userId
{
    [state setValueWithBlock: ^{
        self->_userId = [userId copy];
    }];
}

- (NSDictionary *)traits
{
    return [state valueWithBlock:^id{
        return self->_traits;
    }];
}

- (void)setTraits:(NSDictionary *)traits
{
    [state setValueWithBlock: ^{
        self->_traits = [traits serializableDeepCopy];
    }];
}

- (NSString *)sessionId
{
    return [state valueWithBlock:^id{
        return self->_sessionId;
    }];
}

- (void)setSessionId:(NSString *)sessionId
{
    [state setValueWithBlock: ^{
        self->_sessionId = [sessionId copy];
    }];
}

- (NSTimeInterval)lastSessionTimestamp
{
    return [[state valueWithBlock:^id{
        return @(self->_lastSessionTimestamp);
    }] doubleValue];
}

- (void)setLastSessionTimestamp:(NSTimeInterval)lastSessionTimestamp
{
    [state setValueWithBlock: ^{
        self->_lastSessionTimestamp = lastSessionTimestamp;
    }];
}

- (BOOL)isFirstEventInSession
{
    return [[state valueWithBlock:^id{
        return @(self->_isFirstEventInSession);
    }] boolValue];
}

- (void)setIsFirstEventInSession:(BOOL)isFirstEventInSession
{
    [state setValueWithBlock: ^{
        self->_isFirstEventInSession = isFirstEventInSession;
    }];
}

- (NSDictionary<NSString *, id> *)clickIds
{
    return [state valueWithBlock:^id{
        return self->_clickIds;
    }];
}

- (void)setClickIds:(NSDictionary<NSString *, id> *)clickIds
{
    [state setValueWithBlock: ^{
        self->_clickIds = [clickIds copy];
    }];
}

- (NSDictionary<NSString *, NSString *> *)utmParams
{
    return [state valueWithBlock:^id{
        return self->_utmParams;
    }];
}

- (void)setUtmParams:(NSDictionary<NSString *, NSString *> *)utmParams
{
    [state setValueWithBlock: ^{
        self->_utmParams = [utmParams copy];
    }];
}

- (NSTimeInterval)utmExpiryTimestamp
{
    return [[state valueWithBlock:^id{
        return @(self->_utmExpiryTimestamp);
    }] doubleValue];
}

- (void)setUtmExpiryTimestamp:(NSTimeInterval)utmExpiryTimestamp
{
    [state setValueWithBlock: ^{
        self->_utmExpiryTimestamp = utmExpiryTimestamp;
    }];
}

@end


#pragma mark - FPPayloadContext

@implementation FPPayloadContext

@synthesize state;
@synthesize reachability;

@synthesize referrer = _referrer;
@synthesize cachedStaticContext = _cachedStaticContext;
@synthesize deviceToken = _deviceToken;

- (instancetype)initWithState:(FPState *)state
{
    if (self = [super init]) {
        self.state = state;
        self.reachability = [FPReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
    }
    return self;
}

- (void)updateStaticContext
{
    self.cachedStaticContext = getStaticContext(state.configuration, self.deviceToken);
}

- (NSDictionary *)payload
{
    NSMutableDictionary *result = [self.cachedStaticContext mutableCopy];
    [result addEntriesFromDictionary:getLiveContext(self.reachability, self.referrer, state.userInfo.traits)];
    return result;
}

- (NSDictionary *)referrer
{
    return [state valueWithBlock:^id{
        return self->_referrer;
    }];
}

- (void)setReferrer:(NSDictionary *)referrer
{
    [state setValueWithBlock: ^{
        self->_referrer = [referrer serializableDeepCopy];
    }];
}

- (NSString *)deviceToken
{
    return [state valueWithBlock:^id{
        return self->_deviceToken;
    }];
}

- (void)setDeviceToken:(NSString *)deviceToken
{
    [state setValueWithBlock: ^{
        self->_deviceToken = [deviceToken copy];
    }];
    [self updateStaticContext];
}

@end


#pragma mark - FPState

@implementation FPState {
    dispatch_queue_t _stateQueue;
}

// TODO: Make this not a singleton.. :(
+ (instancetype)sharedInstance
{
    static FPState *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _stateQueue = dispatch_queue_create("com.freshpaint.state.queue", DISPATCH_QUEUE_CONCURRENT);
        self.userInfo = [[FPUserInfo alloc] initWithState:self];
        self.context = [[FPPayloadContext alloc] initWithState:self];
        self.userInfo.sessionId = GenerateUUIDString();
        self.userInfo.lastSessionTimestamp = 0;
        self.userInfo.isFirstEventInSession = NO;

        // Restore persisted click IDs from NSUserDefaults.
        NSData *clickIdsData = [[NSUserDefaults standardUserDefaults] dataForKey:@"com.freshpaint.clickIds"];
        if (clickIdsData) {
            NSError *error = nil;
            id plist = [NSPropertyListSerialization propertyListWithData:clickIdsData
                                                                 options:NSPropertyListImmutable
                                                                  format:nil
                                                                   error:&error];
            if (!error && [plist isKindOfClass:[NSDictionary class]]) {
                self.userInfo.clickIds = (NSDictionary *)plist;
            }
        }

        // Restore persisted UTM params from NSUserDefaults if they have not expired.
        // UTM params carry a 24h expiry; they are persisted so they survive app kills
        // within the same attribution window (e.g. deep link → background → foreground).
        NSData *utmData = [[NSUserDefaults standardUserDefaults] dataForKey:@"com.freshpaint.utmParams"];
        NSTimeInterval utmExpiry = [[NSUserDefaults standardUserDefaults] doubleForKey:@"com.freshpaint.utmExpiry"];
        if (utmData && utmExpiry > [[NSDate date] timeIntervalSince1970]) {
            NSError *utmError = nil;
            id utmPlist = [NSPropertyListSerialization propertyListWithData:utmData
                                                                    options:NSPropertyListImmutable
                                                                     format:nil
                                                                      error:&utmError];
            if (!utmError && [utmPlist isKindOfClass:[NSDictionary class]]) {
                self.userInfo.utmParams = (NSDictionary *)utmPlist;
                self.userInfo.utmExpiryTimestamp = utmExpiry;
            }
        }
    }
    return self;
}

- (void)setValueWithBlock:(FPStateSetBlock)block
{
    dispatch_barrier_async(_stateQueue, block);
}

- (id)valueWithBlock:(FPStateGetBlock)block
{
    __block id value = nil;
    dispatch_sync(_stateQueue, ^{
        value = block();
    });
    return value;
}

- (void)validateOrRenewSessionWithTimeout:(NSTimeInterval)timeout {
    // Wrap all session validation logic in a single atomic operation to prevent race conditions
    [self setValueWithBlock:^{
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval lastSessionTimestamp = self->_userInfo->_lastSessionTimestamp;
        NSTimeInterval currentSessionDuration = now - lastSessionTimestamp;

        NSLog(@"[Session] now=%.3f, last=%.3f, currentSessionDuration=%.3f s, timeout=%.0f s",
              now, lastSessionTimestamp, currentSessionDuration, timeout);

        if (lastSessionTimestamp == 0 || currentSessionDuration > timeout) {
            // Start new session
            self->_userInfo->_sessionId = GenerateUUIDString();
            self->_userInfo->_lastSessionTimestamp = now;
            self->_userInfo->_isFirstEventInSession = YES;
        } else {
            // Continue existing session
            self->_userInfo->_isFirstEventInSession = NO;
        }
    }];
}

// ---------------------------------------------------------------------------
#pragma mark - Click ID & UTM management
// ---------------------------------------------------------------------------

- (void)mergeClickIds:(NSDictionary<NSString *, id> *)extracted
{
    if (!extracted.count) return;

    dispatch_barrier_async(_stateQueue, ^{
        NSMutableDictionary<NSString *, id> *current =
            [self->_userInfo->_clickIds mutableCopy] ?: [NSMutableDictionary dictionary];

        for (NSString *key in extracted) {
            // Skip _creation_time entries — they are handled alongside their value key.
            if ([key hasSuffix:@"_creation_time"]) continue;

            id newValue = extracted[key];
            id existingValue = current[key];

            if (existingValue && [existingValue isEqual:newValue]) {
                // Same value already stored — skip to preserve original creation_time.
                continue;
            }

            // New or changed value — store value and update creation_time.
            current[key] = newValue;
            NSString *creationTimeKey = [key stringByAppendingString:@"_creation_time"];
            id creationTime = extracted[creationTimeKey];
            if (creationTime) {
                current[creationTimeKey] = creationTime;
            }
        }

        self->_userInfo->_clickIds = [current copy];

        // Persist to NSUserDefaults.
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:current
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:&error];
        if (!error && data) {
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"com.freshpaint.clickIds"];
        }
    });
}

- (NSDictionary<NSString *, id> *)activeClickIdsFlattened
{
    __block NSDictionary<NSString *, id> *result = nil;
    dispatch_sync(_stateQueue, ^{
        result = self->_userInfo->_clickIds;
    });
    return result ?: @{};
}

- (void)setUTMParams:(NSDictionary<NSString *, NSString *> *)params
{
    dispatch_barrier_async(_stateQueue, ^{
        self->_userInfo->_utmParams = [params copy];
        self->_userInfo->_utmExpiryTimestamp = [[NSDate date] timeIntervalSince1970] + 86400.0;

        // Persist to NSUserDefaults so UTM params survive app kills within the 24h window.
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:params ?: @{}
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:&error];
        if (!error && data) {
            [[NSUserDefaults standardUserDefaults] setObject:data
                                                      forKey:@"com.freshpaint.utmParams"];
            [[NSUserDefaults standardUserDefaults] setDouble:self->_userInfo->_utmExpiryTimestamp
                                                      forKey:@"com.freshpaint.utmExpiry"];
        }
    });
}

- (NSDictionary<NSString *, NSString *> *)activeUTMParams
{
    __block NSDictionary<NSString *, NSString *> *result = nil;
    dispatch_sync(_stateQueue, ^{
        NSTimeInterval expiry = self->_userInfo->_utmExpiryTimestamp;
        NSTimeInterval now    = [[NSDate date] timeIntervalSince1970];
        if (expiry > 0 && now < expiry) {
            result = self->_userInfo->_utmParams;
        }
    });
    return result;
}

@end
