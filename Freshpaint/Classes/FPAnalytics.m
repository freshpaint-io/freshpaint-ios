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
#import "FPStableDeviceId.h"
#import "FPATTRuntime.h"
#import "FPAttributionMiddleware.h"

static FPAnalytics *__sharedInstance = nil;

// All-zeros IDFA value returned when the advertising identifier is not available.
static NSString *const kFPInstallZeroedIDFA = @"00000000-0000-0000-0000-000000000000";


@interface FPAnalytics ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) FPAnalyticsConfiguration *oneTimeConfiguration;
@property (nonatomic, strong) FPStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) FPIntegrationsManager *integrationsManager;
@property (nonatomic, strong) FPMiddlewareRunner *runner;
@property (nonatomic, strong) FPState *state;

- (void)_handleDidBecomeActiveForATT;

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

        FPAttributionMiddleware *attributionMiddleware = [[FPAttributionMiddleware alloc] initWithConfiguration:configuration];
        NSArray *sourceMiddlewares = [@[attributionMiddleware] arrayByAddingObjectsFromArray:configuration.sourceMiddleware ?: @[]];
        self.runner = [[FPMiddlewareRunner alloc] initWithMiddleware:[sourceMiddlewares arrayByAddingObject:self.integrationsManager]];

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
    } else if ([note.name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
        [self _handleDidBecomeActiveForATT];
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
#if TARGET_OS_IPHONE
        // ATT status — same associated-objects pattern as _handleDidBecomeActiveForATT.
        // In test builds a provider is injected via objc_setAssociatedObject; in
        // production the getter returns nil and we fall through to the real ATT query.
        NSUInteger (^statusProvider)(void) = objc_getAssociatedObject(
            self, @selector(fp_attStatusProvider));
        NSUInteger attStatus = statusProvider ? statusProvider() : [FPAnalytics trackingAuthorizationStatus];
        NSString *attStatusStr;
        switch (attStatus) {
            case 1:  attStatusStr = @"restricted";    break;
            case 2:  attStatusStr = @"denied";        break;
            case 3:  attStatusStr = @"authorized";    break;
            default: attStatusStr = @"notDetermined"; break;
        }

        NSMutableDictionary *installProps = [NSMutableDictionary dictionary];
        installProps[@"install_timestamp"] = iso8601FormattedString([NSDate date]);
        installProps[@"device_id"]         = [FPStableDeviceId deviceId];
        installProps[@"idfv"]              = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"";
        installProps[@"att_status"]        = attStatusStr;
        installProps[@"os_version"]        = [[UIDevice currentDevice] systemVersion] ?: @"";
        installProps[@"app_version"]       = currentVersion ?: @"";

        if (attStatus == 3 && self.oneTimeConfiguration.adSupportBlock != nil) {
            NSString *idfa = self.oneTimeConfiguration.adSupportBlock();
            if (idfa.length > 0 && ![idfa isEqualToString:kFPInstallZeroedIDFA]) {
                installProps[@"idfa"] = idfa;
            }
        }

        [self track:@"app_install" properties:[installProps copy]];
#else
        // Non-iOS platforms (macOS): include the fields available without iOS APIs.
        // idfv, att_status, and idfa require UIDevice/ATT and are intentionally omitted.
        [self track:@"app_install" properties:@{
            @"install_timestamp" : iso8601FormattedString([NSDate date]),
            @"os_version"        : [NSProcessInfo processInfo].operatingSystemVersionString ?: @"",
            @"app_version"       : currentVersion ?: @"",
        }];
#endif
        // Guard: write the install flag immediately after enqueue so a subsequent
        // cold launch after app-kill does not re-fire the event.
        [[NSUserDefaults standardUserDefaults] setObject:currentVersion ?: @"" forKey:FPVersionKey];
        [[NSUserDefaults standardUserDefaults] setObject:currentBuild ?: @"" forKey:FPBuildKeyV2];
    } else {
        // Returning user — fire Application Updated if the build changed.
        if (![currentBuild isEqualToString:previousBuildV2]) {
            [self track:@"Application Updated" properties:@{
                @"previous_version" : previousVersion ?: @"",
                @"previous_build" : previousBuildV2 ?: @"",
                @"version" : currentVersion ?: @"",
                @"build" : currentBuild ?: @"",
            }];
        }
        // Write version keys for returning users. Fresh install already wrote these
        // above (guard write immediately after app_install enqueue).
        [[NSUserDefaults standardUserDefaults] setObject:currentVersion ?: @"" forKey:FPVersionKey];
        [[NSUserDefaults standardUserDefaults] setObject:currentBuild ?: @"" forKey:FPBuildKeyV2];
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
    return @"0.4.1";
}

#pragma mark - ATT (App Tracking Transparency)

+ (NSUInteger)trackingAuthorizationStatus
{
    // Uses the shared FPATTRuntime helper. Maps kFPATTStatusUnavailable → 0 so
    // callers always receive a value in the documented range [0, 3].
    // Note: 0 here means either "notDetermined" or "framework absent". Use the
    // att_status field in event device context (set by FPAttributionMiddleware)
    // to distinguish the two — it reports "unavailable" when the framework is absent.
    NSUInteger status = FPATTGetCurrentStatus();
    return (status == kFPATTStatusUnavailable) ? 0 : status;
}

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger))completion
{
#if TARGET_OS_IOS
    Class attManagerClass = NSClassFromString(@"ATTrackingManager");
    if (!attManagerClass) {
        if (completion) completion(kFPATTStatusUnavailable);
        return;
    }
    SEL requestSel = NSSelectorFromString(@"requestTrackingAuthorizationWithCompletionHandler:");
    if (![attManagerClass respondsToSelector:requestSel]) {
        if (completion) completion(kFPATTStatusUnavailable);
        return;
    }
    void (*requestIMP)(id, SEL, void(^)(NSUInteger)) =
        (void (*)(id, SEL, void(^)(NSUInteger)))[attManagerClass methodForSelector:requestSel];
    dispatch_async(dispatch_get_main_queue(), ^{
        requestIMP(attManagerClass, requestSel, completion ?: ^(NSUInteger __unused s){});
    });
#else
    if (completion) completion(0);
#endif
}

+ (nullable NSString *)advertisingIdentifier
{
#if TARGET_OS_IOS
    if (FPATTGetCurrentStatus() != kFPATTStatusAuthorized) {
        return nil;
    }
    Class asimClass = NSClassFromString(@"ASIdentifierManager");
    if (!asimClass) {
        return nil;
    }
    SEL sharedSel = NSSelectorFromString(@"sharedManager");
    if (![asimClass respondsToSelector:sharedSel]) {
        return nil;
    }
    id (*sharedIMP)(id, SEL) = (id (*)(id, SEL))[asimClass methodForSelector:sharedSel];
    id manager = sharedIMP(asimClass, sharedSel);
    if (!manager) {
        return nil;
    }
    SEL idSel = NSSelectorFromString(@"advertisingIdentifier");
    if (![manager respondsToSelector:idSel]) {
        return nil;
    }
    id (*idIMP)(id, SEL) = (id (*)(id, SEL))[manager methodForSelector:idSel];
    id nsuuid = idIMP(manager, idSel);
    if (!nsuuid) {
        return nil;
    }
    SEL uuidStrSel = NSSelectorFromString(@"UUIDString");
    if (![nsuuid respondsToSelector:uuidStrSel]) {
        return nil;
    }
    id (*uuidStrIMP)(id, SEL) = (id (*)(id, SEL))[nsuuid methodForSelector:uuidStrSel];
    return uuidStrIMP(nsuuid, uuidStrSel);
#else
    return nil;
#endif
}

+ (NSString *)stableDeviceId
{
    return [FPStableDeviceId deviceId];
}

- (void)_handleDidBecomeActiveForATT
{
#if TARGET_OS_IOS
    if (!self.oneTimeConfiguration.autoRequestATT) return;

    // In test builds, FPAnalytics+ATTTesting.h injects a provider via associated
    // objects. In production, objc_getAssociatedObject returns nil here.
    NSUInteger (^statusProvider)(void) = objc_getAssociatedObject(
        self, @selector(fp_attStatusProvider));
    NSUInteger status = statusProvider ? statusProvider() : FPATTGetCurrentStatus();

    // Guard: only prompt when status is exactly notDetermined (0).
    // kFPATTStatusUnavailable (NSUIntegerMax) and any determined status (1–3) all
    // satisfy status != kFPATTStatusNotDetermined, so a single check is sufficient.
    if (status != kFPATTStatusNotDetermined) return;

    void (^requestInterceptor)(void(^_Nullable)(NSUInteger)) = objc_getAssociatedObject(
        self, @selector(fp_attRequestInterceptor));
    if (requestInterceptor) {
        requestInterceptor(nil);
    } else {
        [FPAnalytics requestTrackingAuthorizationWithCompletionHandler:nil];
    }
#endif
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

- (NSDictionary<NSString *, id> *)sessionInfoForAction:(NSString *)action {
    NSTimeInterval timeout = self.state.configuration.sessionTimeout;

    // Only validate/renew session for engagement events (track, screen)
    // Not for metadata events (identify, group, alias)
    BOOL isEngagementEvent = [action isEqualToString:@"track"] || [action isEqualToString:@"screen"];

    if (isEngagementEvent) {
        [self.state validateOrRenewSessionWithTimeout:timeout];
    }

    NSString *sessionId = self.state.userInfo.sessionId;
    BOOL isFirstEvent   = isEngagementEvent ? self.state.userInfo.isFirstEventInSession : NO;

    return @{
      @"sessionId": sessionId,
      @"isFirstEventInSession": @(isFirstEvent)
    };
}

@end
