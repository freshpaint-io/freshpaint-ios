#import <objc/runtime.h>
#import "FPAnalyticsUtils.h"
#import "FPAnalytics.h"
#import "FPIntegrationFactory.h"
#import "FPIntegration.h"
#import "FPFreshpaintIntegrationFactory.h"
#import "UIViewController+FPScreen.h"
#import "NSViewController+FPScreen.h"
#import "FPStoreKitTracker.h"
#import "FPHTTPClient.h"
#import "FPStorage.h"
#import "FPFileStorage.h"
#import "FPUserDefaultsStorage.h"
#import "FPMiddleware.h"
#import "FPContext.h"
#import "FPIntegrationsManager.h"
#import "FPState.h"
#import "FPUtils.h"

static FPAnalytics *__sharedInstance = nil;


@interface FPAnalytics ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) FPAnalyticsConfiguration *oneTimeConfiguration;
@property (nonatomic, strong) FPStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) FPIntegrationsManager *integrationsManager;
@property (nonatomic, strong) FPMiddlewareRunner *runner;
@property (nonatomic, strong) FPState *state;
@end


@implementation FPAnalytics

+ (void)setupWithConfiguration:(FPAnalyticsConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(FPAnalyticsConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.state = [FPState sharedInstance];

        self.oneTimeConfiguration = configuration;
        self.enabled = YES;

        // In swift this would not have been OK... But hey.. It's objc
        // TODO: Figure out if this is really the best way to do things here.
        self.integrationsManager = [[FPIntegrationsManager alloc] initWithAnalytics:self];
        
        if (configuration.edgeFunctionMiddleware) {
            configuration.sourceMiddleware = @[[configuration.edgeFunctionMiddleware sourceMiddleware]];
            configuration.destinationMiddleware = @[[configuration.edgeFunctionMiddleware destinationMiddleware]];
        }

        self.runner = [[FPMiddlewareRunner alloc] initWithMiddleware:
                                                       [configuration.sourceMiddleware ?: @[] arrayByAddingObject:self.integrationsManager]];

        // Pass through for application state change events
        id<FPApplicationProtocol> application = configuration.application;
        if (application) {
#if TARGET_OS_IPHONE
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification,
                                      UIApplicationDidFinishLaunchingNotification,
                                      UIApplicationWillEnterForegroundNotification,
                                      UIApplicationWillTerminateNotification,
                                      UIApplicationWillResignActiveNotification,
                                      UIApplicationDidBecomeActiveNotification ]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
#elif TARGET_OS_OSX
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            for (NSString *name in @[ NSApplicationDidResignActiveNotification,
                                      NSApplicationDidFinishLaunchingNotification,
                                      NSApplicationWillBecomeActiveNotification,
                                      NSApplicationWillTerminateNotification,
                                      NSApplicationWillResignActiveNotification,
                                      NSApplicationDidBecomeActiveNotification]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
#endif
        }

#if TARGET_OS_IPHONE
        if (configuration.recordScreenViews) {
            [UIViewController seg_swizzleViewDidAppear];
        }
#elif TARGET_OS_OSX
        if (configuration.recordScreenViews) {
            [NSViewController seg_swizzleViewDidAppear];
        }
#endif
        if (configuration.trackInAppPurchases) {
            _storeKitTracker = [FPStoreKitTracker trackTransactionsForAnalytics:self];
        }

#if !TARGET_OS_TV
        if (configuration.trackPushNotifications && configuration.launchOptions) {
#if TARGET_OS_IOS
            NSDictionary *remoteNotification = configuration.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
#else
            NSDictionary *remoteNotification = configuration.launchOptions[NSApplicationLaunchUserNotificationKey];
#endif
            if (remoteNotification) {
                [self trackPushNotification:remoteNotification fromLaunch:YES];
            }
        }
#endif
        
        [FPState sharedInstance].configuration = configuration;
        [[FPState sharedInstance].context updateStaticContext];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

NSString *const FPVersionKey = @"FPVersionKey";
NSString *const FPBuildKeyV1 = @"FPBuildKey";
NSString *const FPBuildKeyV2 = @"FPBuildKeyV2";

#if TARGET_OS_IPHONE
- (void)handleAppStateNotification:(NSNotification *)note
{
    FPApplicationLifecyclePayload *payload = [[FPApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:FPEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:UIApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#elif TARGET_OS_OSX
- (void)handleAppStateNotification:(NSNotification *)note
{
    FPApplicationLifecyclePayload *payload = [[FPApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:FPEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:NSApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:NSApplicationWillBecomeActiveNotification]) {
        [self _applicationWillEnterForeground];
    } else if ([note.name isEqualToString:NSApplicationDidResignActiveNotification]) {
      [self _applicationDidEnterBackground];
    }
}
#endif

- (void)_applicationDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
        return;
    }
    // Previously FPBuildKey was stored an integer. This was incorrect because the CFBundleVersion
    // can be a string. This migrates FPBuildKey to be stored as a string.
    NSInteger previousBuildV1 = [[NSUserDefaults standardUserDefaults] integerForKey:FPBuildKeyV1];
    if (previousBuildV1) {
        [[NSUserDefaults standardUserDefaults] setObject:[@(previousBuildV1) stringValue] forKey:FPBuildKeyV2];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPBuildKeyV1];
    }

    NSString *previousVersion = [[NSUserDefaults standardUserDefaults] stringForKey:FPVersionKey];
    NSString *previousBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:FPBuildKeyV2];

    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];

    if (!previousBuildV2) {
        [self track:@"Application Installed" properties:@{
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    } else if (![currentBuild isEqualToString:previousBuildV2]) {
        [self track:@"Application Updated" properties:@{
            @"previous_version" : previousVersion ?: @"",
            @"previous_build" : previousBuildV2 ?: @"",
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    }

#if TARGET_OS_IPHONE
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"referring_application" : launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] ?: @"",
        @"url" : launchOptions[UIApplicationLaunchOptionsURLKey] ?: @"",
    }];
#elif TARGET_OS_OSX
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"default_launch" : launchOptions[NSApplicationLaunchIsDefaultLaunchKey] ?: @(YES),
    }];
#endif


    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:FPVersionKey];
    [[NSUserDefaults standardUserDefaults] setObject:currentBuild forKey:FPBuildKeyV2];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_applicationWillEnterForeground
{
    if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
        return;
    }
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    [self track:@"Application Opened" properties:@{
        @"from_background" : @YES,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
    }];
    
    [[FPState sharedInstance].context updateStaticContext];
}

- (void)_applicationDidEnterBackground
{
  if (!self.oneTimeConfiguration.trackApplicationLifecycleEvents) {
    return;
  }
  [self track: @"Application Backgrounded"];
}


#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

- (nullable FPAnalyticsConfiguration *)configuration
{
    // Remove deprecated configuration on 4.2+
    return nil;
}

#pragma mark - Identify

- (void)identify:(NSString *)userId
{
    [self identify:userId traits:nil options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits
{
    [self identify:userId traits:traits options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    NSCAssert2(userId.length > 0 || traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", userId, traits);
    
    // this is done here to match functionality on android where these are inserted BEFORE being spread out amongst destinations.
    // it will be set globally later when it runs through FPIntegrationManager.identify.
    NSString *anonId = [options objectForKey:@"anonymousId"];
    if (anonId == nil) {
        anonId = [self getAnonymousId];
    }
    // configure traits to match what is seen on android.
    NSMutableDictionary *existingTraitsCopy = [[FPState sharedInstance].userInfo.traits mutableCopy];
    NSMutableDictionary *traitsCopy = [traits mutableCopy];
    // if no traits were passed in, need to create.
    if (existingTraitsCopy == nil) {
        existingTraitsCopy = [[NSMutableDictionary alloc] init];
    }
    if (traitsCopy == nil) {
        traitsCopy = [[NSMutableDictionary alloc] init];
    }
    traitsCopy[@"anonymousId"] = anonId;
    if (userId != nil) {
        traitsCopy[@"userId"] = userId;
        [FPState sharedInstance].userInfo.userId = userId;
    }
    // merge w/ existing traits and set them.
    [existingTraitsCopy addEntriesFromDictionary:traits];
    [FPState sharedInstance].userInfo.traits = existingTraitsCopy;
    
    [self run:FPEventTypeIdentify payload:
                                       [[FPIdentifyPayload alloc] initWithUserId:userId
                                                                      anonymousId:anonId
                                                                           traits:FPCoerceDictionary(existingTraitsCopy)
                                                                          context:FPCoerceDictionary([options objectForKey:@"context"])
                                                                     integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Track

- (void)track:(NSString *)event
{
    [self track:event properties:nil options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self track:event properties:properties options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(event.length > 0, @"event (%@) must not be empty.", event);
    [self run:FPEventTypeTrack payload:
                                    [[FPTrackPayload alloc] initWithEvent:event
                                                                properties:FPCoerceDictionary(properties)
                                                                   context:FPCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Screen

- (void)screen:(NSString *)screenTitle
{
    [self screen:screenTitle properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties
{
    [self screen:screenTitle properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(screenTitle.length > 0, @"screen name (%@) must not be empty.", screenTitle);

    [self run:FPEventTypeScreen payload:
                                     [[FPScreenPayload alloc] initWithName:screenTitle
                                                                 properties:FPCoerceDictionary(properties)
                                                                    context:FPCoerceDictionary([options objectForKey:@"context"])
                                                               integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Group

- (void)group:(NSString *)groupId
{
    [self group:groupId traits:nil options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits
{
    [self group:groupId traits:traits options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    [self run:FPEventTypeGroup payload:
                                    [[FPGroupPayload alloc] initWithGroupId:groupId
                                                                      traits:FPCoerceDictionary(traits)
                                                                     context:FPCoerceDictionary([options objectForKey:@"context"])
                                                                integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Alias

- (void)alias:(NSString *)newId
{
    [self alias:newId options:nil];
}

- (void)alias:(NSString *)newId options:(NSDictionary *)options
{
    [self run:FPEventTypeAlias payload:
                                    [[FPAliasPayload alloc] initWithNewId:newId
                                                                   context:FPCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

- (void)trackPushNotification:(NSDictionary *)properties fromLaunch:(BOOL)launch
{
    if (launch) {
        [self track:@"Push Notification Tapped" properties:properties];
    } else {
        [self track:@"Push Notification Received" properties:properties];
    }
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    if (self.oneTimeConfiguration.trackPushNotifications) {
        [self trackPushNotification:userInfo fromLaunch:NO];
    }
    FPRemoteNotificationPayload *payload = [[FPRemoteNotificationPayload alloc] init];
    payload.userInfo = userInfo;
    [self run:FPEventTypeReceivedRemoteNotification payload:payload];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    FPRemoteNotificationPayload *payload = [[FPRemoteNotificationPayload alloc] init];
    payload.error = error;
    [self run:FPEventTypeFailedToRegisterForRemoteNotifications payload:payload];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    FPRemoteNotificationPayload *payload = [[FPRemoteNotificationPayload alloc] init];
    payload.deviceToken = deviceToken;
    [FPState sharedInstance].context.deviceToken = deviceTokenToString(deviceToken);
    [self run:FPEventTypeRegisteredForRemoteNotifications payload:payload];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    FPRemoteNotificationPayload *payload = [[FPRemoteNotificationPayload alloc] init];
    payload.actionIdentifier = identifier;
    payload.userInfo = userInfo;
    [self run:FPEventTypeHandleActionWithForRemoteNotification payload:payload];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    FPContinueUserActivityPayload *payload = [[FPContinueUserActivityPayload alloc] init];
    payload.activity = activity;
    [self run:FPEventTypeContinueUserActivity payload:payload];

    if (!self.oneTimeConfiguration.trackDeepLinks) {
        return;
    }

    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSString *urlString = activity.webpageURL.absoluteString;
        [FPState sharedInstance].context.referrer = @{
            @"url" : urlString,
        };

        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:activity.userInfo.count + 2];
        [properties addEntriesFromDictionary:activity.userInfo];
        properties[@"url"] = urlString;
        properties[@"title"] = activity.title ?: @"";
        properties = [FPUtils traverseJSON:properties
                      andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters];
        [self track:@"Deep Link Opened" properties:[properties copy]];
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    FPOpenURLPayload *payload = [[FPOpenURLPayload alloc] init];
    payload.url = [NSURL URLWithString:[FPUtils traverseJSON:url.absoluteString
                                        andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters]];
    payload.options = options;
    [self run:FPEventTypeOpenURL payload:payload];

    if (!self.oneTimeConfiguration.trackDeepLinks) {
        return;
    }
    
    NSString *urlString = url.absoluteString;
    [FPState sharedInstance].context.referrer = @{
        @"url" : urlString,
    };

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:options.count + 2];
    [properties addEntriesFromDictionary:options];
    properties[@"url"] = urlString;
    properties = [FPUtils traverseJSON:properties
                  andReplaceWithFilters:self.oneTimeConfiguration.payloadFilters];
    [self track:@"Deep Link Opened" properties:[properties copy]];
}

- (void)reset
{
    [self run:FPEventTypeReset payload:nil];
}

- (void)flush
{
    [self run:FPEventTypeFlush payload:nil];
}

- (void)enable
{
    _enabled = YES;
}

- (void)disable
{
    _enabled = NO;
}

- (NSString *)getAnonymousId
{
    return [FPState sharedInstance].userInfo.anonymousId;
}

- (NSString *)getDeviceToken
{
    return [FPState sharedInstance].context.deviceToken;
}

- (NSDictionary *)bundledIntegrations
{
    return [self.integrationsManager.registeredIntegrations copy];
}

#pragma mark - Class Methods

+ (instancetype)sharedAnalytics
{
    NSCAssert(__sharedInstance != nil, @"library must be initialized before calling this method.");
    return __sharedInstance;
}

+ (void)debug:(BOOL)showDebugLogs
{
    FPSetShowDebugLogs(showDebugLogs);
}

+ (NSString *)version
{
    // this has to match the actual version, NOT what's in info.plist
    // because Apple only accepts X.X.X as versions in the review process.
    return @"0.4.0";
}

#pragma mark - Helpers

- (void)run:(FPEventType)eventType payload:(FPPayload *)payload
{
    if (!self.enabled) {
        return;
    }
    
    if (self.oneTimeConfiguration.experimental.nanosecondTimestamps) {
        payload.timestamp = iso8601NanoFormattedString([NSDate date]);
    } else {
        payload.timestamp = iso8601FormattedString([NSDate date]);
    }
    
    FPContext *context = [[[FPContext alloc] initWithAnalytics:self] modify:^(id<FPMutableContext> _Nonnull ctx) {
        ctx.eventType = eventType;
        ctx.payload = payload;
        ctx.payload.messageId = GenerateUUIDString();
        if (ctx.payload.userId == nil) {
            ctx.payload.userId = [FPState sharedInstance].userInfo.userId;
        }
        if (ctx.payload.anonymousId == nil) {
            ctx.payload.anonymousId = [FPState sharedInstance].userInfo.anonymousId;
        }
    }];
    
    // Could probably do more things with callback later, but we don't use it yet.
    [self.runner run:context callback:nil];
}

- (NSDictionary<NSString *, id> *)sessionInfo {
    NSTimeInterval timeout = self.state.configuration.sessionTimeout;
    [self.state validateOrRenewSessionWithTimeout:timeout];

    NSString *sessionId = self.state.userInfo.sessionId;
    BOOL isFirstEvent   = self.state.userInfo.isFirstEventInSession;

    return @{
      @"sessionId": sessionId,
      @"isFirstEventInSession": @(isFirstEvent)
    };
}

@end
