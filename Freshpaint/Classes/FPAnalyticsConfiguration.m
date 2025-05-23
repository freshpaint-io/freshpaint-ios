//
//  FPIntegrationsManager.h
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "FPAnalyticsConfiguration.h"
#import "FPAnalytics.h"
#import "FPCrypto.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

#if TARGET_OS_IPHONE
@implementation UIApplication (FPApplicationProtocol)

- (UIBackgroundTaskIdentifier)seg_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler
{
    return [self beginBackgroundTaskWithName:taskName expirationHandler:handler];
}

- (void)seg_endBackgroundTask:(UIBackgroundTaskIdentifier)identifier
{
    [self endBackgroundTask:identifier];
}

@end
#endif

static const NSTimeInterval DefaultSessionTimeout = 1800;

@implementation FPAnalyticsExperimental
@end

@interface FPAnalyticsConfiguration ()

@property (nonatomic, copy, readwrite) NSString *writeKey;
@property (nonatomic, strong, readonly) NSMutableArray *factories;
@property (nonatomic, strong) FPAnalyticsExperimental *experimental;

@end


@implementation FPAnalyticsConfiguration

+ (instancetype)configurationWithWriteKey:(NSString *)writeKey
{
    return [[FPAnalyticsConfiguration alloc] initWithWriteKey:writeKey];
}

- (instancetype)initWithWriteKey:(NSString *)writeKey
{
    if (self = [self init]) {
        self.writeKey = writeKey;
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.experimental = [[FPAnalyticsExperimental alloc] init];
        self.shouldUseLocationServices = NO;
        self.enableAdvertisingTracking = YES;
        self.shouldUseBluetooth = NO;
        self.flushAt = 20;
        self.flushInterval = 30;
        self.maxQueueSize = 1000;
        self.payloadFilters = @{
            @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
        };
        self.sessionTimeout = DefaultSessionTimeout;
        _factories = [NSMutableArray array];
#if TARGET_OS_IPHONE
        if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [UIApplication performSelector:@selector(sharedApplication)];
        }
#elif TARGET_OS_OSX
        if ([NSApplication respondsToSelector:@selector(sharedApplication)]) {
            _application = [NSApplication performSelector:@selector(sharedApplication)];
        }
#endif
    }
    return self;
}

- (void)use:(id<FPIntegrationFactory>)factory
{
    [self.factories addObject:factory];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"writeKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

// MARK: remove these when `middlewares` property is removed.

- (void)setMiddlewares:(NSArray<id<FPMiddleware>> *)middlewares
{
    self.sourceMiddleware = middlewares;
}

- (NSArray<id<FPMiddleware>> *)middlewares
{
    return self.sourceMiddleware;
}

@end
