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
#import "FPAdClickIds.h"

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
        NSString *attStatusStr = FPATTStatusToString(attStatus);

        NSMutableDictionary *installProps = [NSMutableDictionary dictionary];
        installProps[@"install_timestamp"] = iso8601FormattedString([NSDate date]);
        installProps[@"device_id"]         = [FPStableDeviceId deviceId];
        installProps[@"idfv"]              = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"";
        installProps[@"att_status"]        = attStatusStr;
        installProps[@"os_version"]        = [[UIDevice currentDevice] systemVersion] ?: @"";
        installProps[@"app_version"]       = currentVersion ?: @"";

        if (attStatus == kFPATTStatusAuthorized && self.oneTimeConfiguration.adSupportBlock != nil) {
            NSString *idfa = self.oneTimeConfiguration.adSupportBlock();
            if (idfa.length > 0 && ![idfa isEqualToString:kFPInstallZeroedIDFA]) {
                installProps[@"idfa"] = idfa;
            }
        }

        // If the app was launched via a URL (e.g. deferred deep link at first-open),
        // extract attribution from it and persist before merging into install payload.
        // UIKit guarantees UIApplicationDelegate callbacks on the main thread.
        // If somehow called off-main (e.g. a unit test), dispatch to main to avoid a
        // potential deadlock: mergeClickIds: posts a barrier write to _stateQueue and
        // activeClickIdsFlattened below uses dispatch_sync on the same queue — both are
        // safe from any non-_stateQueue thread, including main, but not from _stateQueue.
        if (!NSThread.isMainThread) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _applicationDidFinishLaunchingWithOptions:launchOptions];
            });
            return;
        }
        [self _processAttributionFromURL:launchOptions[UIApplicationLaunchOptionsURLKey]];

        // Merge any stored click IDs and active UTM params into the install payload.
        // activeClickIdsFlattened uses dispatch_sync, which drains any pending barrier
        // (from the _processAttributionFromURL: call above) before reading — GCD guarantee.
        NSDictionary *storedClickIds = [[FPState sharedInstance] activeClickIdsFlattened];
        NSDictionary *storedUTM      = [[FPState sharedInstance] activeUTMParams];
        if (storedClickIds.count > 0) {
            [installProps addEntriesFromDictionary:storedClickIds];
        }
        if (storedUTM.count > 0) {
            [installProps addEntriesFromDictionary:storedUTM];
        }

        // Apple Ads attribution token (AdServices.framework — runtime-only, opt-in).
        // attributionToken: throws ObjC exceptions when the app was not installed via
        // Apple Search Ads — @try/@catch is required per Apple documentation.
        @try {
            NSString *(^tokenProvider)(void) = objc_getAssociatedObject(
                self, @selector(fp_appleAdsTokenProvider));
            NSString *appleAdsToken = nil;
            if (tokenProvider) {
                appleAdsToken = tokenProvider();
            } else {
                Class aaClass = NSClassFromString(@"AAAttribution");
                SEL tokenSel = NSSelectorFromString(@"attributionToken:");
                if (aaClass && [aaClass respondsToSelector:tokenSel]) {
                    NSString *(*tokenIMP)(id, SEL, NSError **) =
                        (NSString *(*)(id, SEL, NSError **))[aaClass methodForSelector:tokenSel];
                    NSError *tokenError = nil;
                    CFAbsoluteTime tokenStart = CFAbsoluteTimeGetCurrent();
                    appleAdsToken = tokenIMP(aaClass, tokenSel, &tokenError);
                    CFAbsoluteTime tokenDuration = CFAbsoluteTimeGetCurrent() - tokenStart;
                    if (tokenDuration > 0.1) {
                        FPLog(@"Apple Ads token retrieval took %.2f seconds", tokenDuration);
                    }
                    if (tokenError) {
                        FPLog(@"Apple Ads token unavailable: %@", tokenError.localizedDescription);
                        [self track:@"apple_ads_token_error" properties:@{
                            @"error_domain": tokenError.domain ?: @"unknown",
                            @"error_code": @(tokenError.code),
                        }];
                    }
                }
            }
            if (appleAdsToken.length > 0) {
                installProps[@"apple_ads_token"] = appleAdsToken;
            }
        } @catch (NSException *e) {
            FPLog(@"Apple Ads token exception (non-fatal): %@", e);
        }

        [self track:@"app_install" properties:[installProps copy]];

        // SKAdNetwork conversion value registration (StoreKit — runtime-only, opt-in).
        // Only fires when skanConversionValue is in the valid range (1-63).
        NSInteger skanValue = self.oneTimeConfiguration.skanConversionValue;
        if (skanValue > 0 && skanValue <= 63) {
            [self fp_registerSKANConversionValue:skanValue];
        }
#else
        // Non-iOS platforms (macOS): include the fields available without iOS APIs.
        // idfv, att_status, and idfa require UIDevice/ATT and are intentionally omitted.
        [self track:@"app_install" properties:@{
            @"install_timestamp" : iso8601FormattedString([NSDate date]),
            @"device_id"         : [FPStableDeviceId deviceId],
            @"os_version"        : [NSProcessInfo processInfo].operatingSystemVersionString ?: @"",
            @"app_version"       : currentVersion ?: @"",
        }];
#endif
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
    }

    // Persist version/build for both fresh-install and returning-user paths.
    // For fresh installs this acts as the guard flag so a subsequent cold launch
    // after app-kill does not re-fire app_install. For returning users it keeps
    // the stored values current for the next Application Updated comparison.
    [[NSUserDefaults standardUserDefaults] setObject:currentVersion ?: @"" forKey:FPVersionKey];
    [[NSUserDefaults standardUserDefaults] setObject:currentBuild ?: @"" forKey:FPBuildKeyV2];

#if TARGET_OS_IPHONE
    // UIApplicationLaunchOptionsURLKey is an NSURL — convert to string so the payload
    // remains JSON-serializable (NSJSONSerialization rejects raw NSURL values).
    NSURL *launchURL = launchOptions[UIApplicationLaunchOptionsURLKey];
    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"referring_application" : launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] ?: @"",
        @"url" : launchURL.absoluteString ?: @"",
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

        // Extract and store click IDs / UTM params from the universal link URL.
        [self _processAttributionFromURL:activity.webpageURL];
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

    // Extract and store click IDs / UTM params from the deep link URL.
    [self _processAttributionFromURL:url];
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
        // Framework absent — return 0 (same as trackingAuthorizationStatus for unavailable).
        if (completion) completion(0);
        return;
    }
    SEL requestSel = NSSelectorFromString(@"requestTrackingAuthorizationWithCompletionHandler:");
    if (![attManagerClass respondsToSelector:requestSel]) {
        // Selector absent — return 0 to stay consistent with trackingAuthorizationStatus.
        if (completion) completion(0);
        return;
    }
    void (*requestIMP)(id, SEL, void(^)(NSUInteger)) =
        (void (*)(id, SEL, void(^)(NSUInteger)))[attManagerClass methodForSelector:requestSel];
    dispatch_async(dispatch_get_main_queue(), ^{
        requestIMP(attManagerClass, requestSel, completion ?: ^(NSUInteger __unused s){});
    });
#else
    // Non-iOS platforms have no ATT framework — return 0 (unavailable), same as trackingAuthorizationStatus.
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

#pragma mark - SKAdNetwork

/// Creates an NSInvocation for a SKAdNetwork class method with the conversion value
/// set at argument index 2. Returns nil if the class does not respond to the selector.
static NSInvocation *fp_skanInvocation(Class skanClass, SEL sel, NSInteger value)
{
    if (![skanClass respondsToSelector:sel]) return nil;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:
        [skanClass methodSignatureForSelector:sel]];
    [inv setSelector:sel];
    [inv setTarget:skanClass];
    [inv setArgument:&value atIndex:2];
    return inv;
}

/// Appends an error-logging completion handler at the given argument index and calls
/// retainArguments to ensure the block is copied to the heap before invocation.
static void fp_skanSetCompletionHandler(NSInvocation *inv, NSUInteger argIndex, NSString *label)
{
    void (^handler)(NSError *) = ^(NSError *error) {
        if (error) {
            FPLog(@"SKAN %@ registration error: %@", label, error.localizedDescription);
        }
    };
    [inv setArgument:&handler atIndex:argIndex];
    // retainArguments copies all arguments (including the block) to the heap.
    // Without this the block pointer becomes dangling when this function returns,
    // causing a crash when SKAdNetwork invokes the handler asynchronously.
    [inv retainArguments];
}

/// Registers a SKAdNetwork conversion value using the best available API.
/// v4 (iOS 16.1+): coarseValue = "medium", lockWindow = NO.
/// v3 (iOS 15.4+): fine conversion value only.
/// Both APIs accessed via runtime reflection — StoreKit is never imported directly.
/// Uses fp_skanVersionOverride (NSNumber) associated object to force a specific
/// API version in tests; nil = auto-detect from OS version at runtime.
/// Uses fp_skanCallInterceptor associated object to capture call arguments in tests.
- (void)fp_registerSKANConversionValue:(NSInteger)value
{
#if TARGET_OS_IPHONE
    // Test seam: if an interceptor is set, call it instead of the real SKAN API.
    void (^interceptor)(NSInteger, NSString *) = objc_getAssociatedObject(
        self, @selector(fp_skanCallInterceptor));
    if (interceptor) {
        NSNumber *versionOverride = objc_getAssociatedObject(self, @selector(fp_skanVersionOverride));
        NSString *version = (versionOverride && [versionOverride integerValue] >= 4) ? @"v4" : @"v3";
        interceptor(value, version);
        return;
    }

    Class skanClass = NSClassFromString(@"SKAdNetwork");
    if (!skanClass) return;

    // Allow tests to force a specific API version (4 or 3).
    NSNumber *versionOverride = objc_getAssociatedObject(self, @selector(fp_skanVersionOverride));
    BOOL useV4 = NO;

    if (versionOverride) {
        useV4 = ([versionOverride integerValue] >= 4);
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 160100
        if (@available(iOS 16.1, *)) {
            useV4 = YES;
        }
#endif
    }

    if (useV4) {
        SEL v4Sel = NSSelectorFromString(
            @"updatePostbackConversionValue:coarseValue:lockWindow:completionHandler:");
        NSInvocation *inv = fp_skanInvocation(skanClass, v4Sel, value);
        if (inv) {
            NSString *coarseValue = @"medium";
            [inv setArgument:&coarseValue atIndex:3];
            BOOL lockWindow = NO;
            [inv setArgument:&lockWindow atIndex:4];
            fp_skanSetCompletionHandler(inv, 5, @"v4");
            [inv invoke];
            return;
        }
    }

    // SKAN v3 fallback: updatePostbackConversionValue:completionHandler: (iOS 15.4+)
    SEL v3Sel = NSSelectorFromString(@"updatePostbackConversionValue:completionHandler:");
    NSInvocation *inv = fp_skanInvocation(skanClass, v3Sel, value);
    if (inv) {
        fp_skanSetCompletionHandler(inv, 3, @"v3");
        [inv invoke];
    }
    // If neither selector is available (iOS < 15.4) — silently no-op.
#endif
}

#pragma mark - Attribution helpers

/// Extracts click IDs and UTM params from a URL and persists them via FPState.
/// No-op when url is nil. Shared by openURL:options:, continueUserActivity:,
/// and the launch-URL path in _applicationDidFinishLaunchingWithOptions:.
- (void)_processAttributionFromURL:(nullable NSURL *)url
{
    if (!url) return;
    NSDictionary *attribution = [FPAdClickIds extractFromURL:url
                                              payloadFilters:self.oneTimeConfiguration.payloadFilters];
    if ([attribution[@"clickIds"] count] > 0) {
        [[FPState sharedInstance] mergeClickIds:attribution[@"clickIds"]];
    }
    if ([attribution[@"utmParams"] count] > 0) {
        [[FPState sharedInstance] setUTMParams:attribution[@"utmParams"]];
    }
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
