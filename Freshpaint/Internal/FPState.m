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


@interface FPUserInfo () <FPStateObject>
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
        self.userInfo.lastSessionTimestamp = [[NSDate date] timeIntervalSince1970];
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
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval currentSessionDuration = now - self.userInfo.lastSessionTimestamp;

    NSLog(@"[Session] now=%.0f, last=%.0f, currentSessionDuration=%.0f s, timeout=%.0f s",
          now, self.userInfo.lastSessionTimestamp, currentSessionDuration, timeout);

    if (currentSessionDuration > timeout) {
        self.userInfo.sessionId = GenerateUUIDString();
        self.userInfo.lastSessionTimestamp = now;
    }
}

@end
