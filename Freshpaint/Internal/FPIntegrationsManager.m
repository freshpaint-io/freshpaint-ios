//
//  FPIntegrationsManager.m
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#import <objc/runtime.h>
#import "FPAnalyticsUtils.h"
#import "FPAnalytics.h"
#import "FPIntegrationFactory.h"
#import "FPIntegration.h"
#import "FPHTTPClient.h"
#import "FPStorage.h"
#import "FPFileStorage.h"
#import "FPUserDefaultsStorage.h"
#import "FPIntegrationsManager.h"
#import "FPFreshpaintIntegrationFactory.h"
#import "FPPayload.h"
#import "FPIdentifyPayload.h"
#import "FPTrackPayload.h"
#import "FPGroupPayload.h"
#import "FPScreenPayload.h"
#import "FPAliasPayload.h"
#import "FPUtils.h"
#import "FPState.h"

NSString *FPAnalyticsIntegrationDidStart = @"io.freshpaint.analytics.integration.did.start";
NSString *const FPAnonymousIdKey = @"FPAnonymousId";
NSString *const kFPAnonymousIdFilename = @"freshpaint.anonymousId";
NSString *const kFPCachedSettingsFilename = @"freshpaint.settings.v2.plist";


@interface FPIdentifyPayload (AnonymousId)
@property (nonatomic, readwrite, nullable) NSString *anonymousId;
@end


@interface FPPayload (Options)
@property (readonly) NSDictionary *options;
@end
@implementation FPPayload (Options)
// Combine context and integrations to form options
- (NSDictionary *)options
{
    return @{
        @"context" : self.context ?: @{},
        @"integrations" : self.integrations ?: @{}
    };
}
@end


@interface FPAnalyticsConfiguration (Private)
@property (nonatomic, strong) NSArray *factories;
@end


@interface FPIntegrationsManager ()

@property (nonatomic, strong) FPAnalytics *analytics;
@property (nonatomic, strong) NSDictionary *cachedSettings;
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) NSArray *factories;
@property (nonatomic, strong) NSMutableDictionary *integrations;
@property (nonatomic, strong) NSMutableDictionary *registeredIntegrations;
@property (nonatomic, strong) NSMutableDictionary *integrationMiddleware;
@property (nonatomic) volatile BOOL initialized;
@property (nonatomic, copy) NSString *cachedAnonymousId;
@property (nonatomic, strong) FPHTTPClient *httpClient;
@property (nonatomic, strong) NSURLSessionDataTask *settingsRequest;
@property (nonatomic, strong) id<FPStorage> userDefaultsStorage;
@property (nonatomic, strong) id<FPStorage> fileStorage;

@end

@interface FPAnalytics ()
@property (nullable, nonatomic, strong, readonly) FPAnalyticsConfiguration *oneTimeConfiguration;
@end


@implementation FPIntegrationsManager

@dynamic cachedAnonymousId;
@synthesize cachedSettings = _cachedSettings;

- (instancetype _Nonnull)initWithAnalytics:(FPAnalytics *_Nonnull)analytics
{
    FPAnalyticsConfiguration *configuration = analytics.oneTimeConfiguration;
    NSCParameterAssert(configuration != nil);

    if (self = [super init]) {
        self.analytics = analytics;
        self.configuration = configuration;
        self.serialQueue = seg_dispatch_queue_create_specific("io.freshpaint.analytics", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        self.httpClient = [[FPHTTPClient alloc] initWithRequestFactory:configuration.requestFactory];
        
        self.userDefaultsStorage = [[FPUserDefaultsStorage alloc] initWithDefaults:[NSUserDefaults standardUserDefaults] namespacePrefix:nil crypto:configuration.crypto];
        #if TARGET_OS_TV
            self.fileStorage = [[FPFileStorage alloc] initWithFolder:[FPFileStorage cachesDirectoryURL] crypto:configuration.crypto];
        #else
            self.fileStorage = [[FPFileStorage alloc] initWithFolder:[FPFileStorage applicationSupportDirectoryURL] crypto:configuration.crypto];
        #endif

        self.cachedAnonymousId = [self loadOrGenerateAnonymousID:NO];
        NSMutableArray *factories = [[configuration factories] mutableCopy];
        [factories addObject:[[FPFreshpaintIntegrationFactory alloc] initWithHTTPClient:self.httpClient fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage]];
        self.factories = [factories copy];
        self.integrations = [NSMutableDictionary dictionaryWithCapacity:factories.count];
        self.registeredIntegrations = [NSMutableDictionary dictionaryWithCapacity:factories.count];
        self.integrationMiddleware = [NSMutableDictionary dictionaryWithCapacity:factories.count];

        // Update settings on each integration immediately
        [self refreshSettings];

        // Update settings on foreground
        id<FPApplicationProtocol> application = configuration.application;
        if (application) {
            // Attach to application state change hooks
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IPHONE
            [nc addObserver:self selector:@selector(onAppForeground:) name:UIApplicationWillEnterForegroundNotification object:application];
#elif TARGET_OS_OSX
            [nc addObserver:self selector:@selector(onAppForeground:) name:NSApplicationWillBecomeActiveNotification object:application];
#endif
        }
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setCachedAnonymousId:(NSString *)cachedAnonymousId
{
    [FPState sharedInstance].userInfo.anonymousId = cachedAnonymousId;
}

- (NSString *)cachedAnonymousId
{
    NSString *value = [FPState sharedInstance].userInfo.anonymousId;
    return value;
}

- (void)onAppForeground:(NSNotification *)note
{
    [self refreshSettings];
}

- (void)handleAppStateNotification:(NSString *)notificationName
{
    FPLog(@"Application state change notification: %@", notificationName);
    static NSDictionary *selectorMapping;
    static dispatch_once_t selectorMappingOnce;
    dispatch_once(&selectorMappingOnce, ^{
#if TARGET_OS_IPHONE

        selectorMapping = @{
            UIApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            UIApplicationDidEnterBackgroundNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            UIApplicationWillEnterForegroundNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            UIApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
            UIApplicationWillResignActiveNotification :
                NSStringFromSelector(@selector(applicationWillResignActive)),
            UIApplicationDidBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationDidBecomeActive))
        };
#elif TARGET_OS_OSX
        selectorMapping = @{
            NSApplicationDidFinishLaunchingNotification :
                NSStringFromSelector(@selector(applicationDidFinishLaunching:)),
            NSApplicationDidResignActiveNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            NSApplicationWillBecomeActiveNotification :
                NSStringFromSelector(@selector(applicationWillEnterForeground)),
            NSApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
        };
#endif

    });
    SEL selector = NSSelectorFromString(selectorMapping[notificationName]);
    if (selector) {
        [self callIntegrationsWithSelector:selector arguments:nil options:nil sync:true];
    }
}

#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - Analytics API

- (void)identify:(FPIdentifyPayload *)payload
{
    NSCAssert2(payload.userId.length > 0 || payload.traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", payload.userId, payload.traits);

    NSString *anonymousId = payload.anonymousId;
    NSString *existingAnonymousId = self.cachedAnonymousId;
    
    if (anonymousId == nil) {
        payload.anonymousId = anonymousId;
    } else if (![anonymousId isEqualToString:existingAnonymousId]) {
        [self saveAnonymousId:anonymousId];
    }

    [self callIntegrationsWithSelector:NSSelectorFromString(@"identify:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Track

- (void)track:(FPTrackPayload *)payload
{
    NSCAssert1(payload.event.length > 0, @"event (%@) must not be empty.", payload.event);

    [self callIntegrationsWithSelector:NSSelectorFromString(@"track:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Screen

- (void)screen:(FPScreenPayload *)payload
{
    NSCAssert1(payload.name.length > 0, @"screen name (%@) must not be empty.", payload.name);

    [self callIntegrationsWithSelector:NSSelectorFromString(@"screen:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Group

- (void)group:(FPGroupPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"group:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

#pragma mark - Alias

- (void)alias:(FPAliasPayload *)payload
{
    [self callIntegrationsWithSelector:NSSelectorFromString(@"alias:")
                             arguments:@[ payload ]
                               options:payload.options
                                  sync:false];
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ userInfo ] options:nil sync:true];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ error ] options:nil sync:true];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);

    [self callIntegrationsWithSelector:_cmd arguments:@[ deviceToken ] options:nil sync:true];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ identifier, userInfo ] options:nil sync:true];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ activity ] options:nil sync:true];
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    [self callIntegrationsWithSelector:_cmd arguments:@[ url, options ] options:nil sync:true];
}

- (void)reset
{
    [self resetAnonymousId];
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

- (void)resetAnonymousId
{
    self.cachedAnonymousId = [self loadOrGenerateAnonymousID:YES];
}

- (NSString *)getAnonymousId;
{
    return self.cachedAnonymousId;
}

- (NSString *)loadOrGenerateAnonymousID:(BOOL)reset
{
#if TARGET_OS_TV
    NSString *anonymousId = [self.userDefaultsStorage stringForKey:FPAnonymousIdKey];
#else
    NSString *anonymousId = [self.fileStorage stringForKey:kFPAnonymousIdFilename];
#endif

    if (!anonymousId || reset) {
        // We've chosen to generate a UUID rather than use the UDID (deprecated in iOS 5),
        // identifierForVendor (iOS6 and later, can't be changed on logout),
        // or MAC address (blocked in iOS 7). For more info see https://segment.io/libraries/ios#ids
        anonymousId = GenerateUUIDString();
        FPLog(@"New anonymousId: %@", anonymousId);
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:anonymousId forKey:FPAnonymousIdKey];
#else
        [self.fileStorage setString:anonymousId forKey:kFPAnonymousIdFilename];
#endif
    }
    
    return anonymousId;
}

- (void)saveAnonymousId:(NSString *)anonymousId
{
    self.cachedAnonymousId = anonymousId;
#if TARGET_OS_TV
    [self.userDefaultsStorage setString:anonymousId forKey:FPAnonymousIdKey];
#else
    [self.fileStorage setString:anonymousId forKey:kFPAnonymousIdFilename];
#endif
}

- (void)flush
{
    [self callIntegrationsWithSelector:_cmd arguments:nil options:nil sync:false];
}

#pragma mark - Analytics Settings

- (NSDictionary *)cachedSettings
{
    if (!_cachedSettings) {
#if TARGET_OS_TV
        _cachedSettings = [self.userDefaultsStorage dictionaryForKey:kFPCachedSettingsFilename] ?: @{};
#else
        _cachedSettings = [self.fileStorage dictionaryForKey:kFPCachedSettingsFilename] ?: @{};
#endif
    }
    
    return _cachedSettings;
}

- (void)setCachedSettings:(NSDictionary *)settings
{
    _cachedSettings = [settings copy];
    if (!_cachedSettings) {
        // [@{} writeToURL:settingsURL atomically:YES];
        return;
    }
    
#if TARGET_OS_TV
    [self.userDefaultsStorage setDictionary:_cachedSettings forKey:kFPCachedSettingsFilename];
#else
    [self.fileStorage setDictionary:_cachedSettings forKey:kFPCachedSettingsFilename];
#endif

    [self updateIntegrationsWithSettings:settings[@"integrations"]];
}

- (nonnull NSArray<id<FPMiddleware>> *)middlewareForIntegrationKey:(NSString *)key
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (FPDestinationMiddleware *container in self.configuration.destinationMiddleware) {
        if ([container.integrationKey isEqualToString:key]) {
            [result addObjectsFromArray:container.middleware];
        }
    }
    return result;
}

- (void)updateIntegrationsWithSettings:(NSDictionary *)projectSettings
{
    seg_dispatch_specific_sync(_serialQueue, ^{
        if (self.initialized) {
            return;
        }
        for (id<FPIntegrationFactory> factory in self.factories) {
            NSString *key = [factory key];
            NSDictionary *integrationSettings = [projectSettings objectForKey:key];
            if (isUnitTesting()) {
                integrationSettings = @{};
            }
            if (integrationSettings || [key hasPrefix:@"webhook_"]) {
                id<FPIntegration> integration = [factory createWithSettings:integrationSettings forAnalytics:self.analytics];
                if (integration != nil) {
                    self.integrations[key] = integration;
                    self.registeredIntegrations[key] = @NO;
                    
                    // setup integration middleware
                    NSArray<id<FPMiddleware>> *middleware = [self middlewareForIntegrationKey:key];
                    self.integrationMiddleware[key] = [[FPMiddlewareRunner alloc] initWithMiddleware:middleware];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:FPAnalyticsIntegrationDidStart object:key userInfo:nil];
            } else {
                FPLog(@"No settings for %@. Skipping.", key);
            }
        }
        [self flushMessageQueue];
        self.initialized = true;
    });
}

- (void)configureEdgeFunctions:(NSDictionary *)settings
{
    if (self.configuration.edgeFunctionMiddleware) {
        NSDictionary *edgeFnSettings = settings[@"edgeFunction"];
        if (edgeFnSettings != nil && edgeFnSettings.count > 0) {
            [self.configuration.edgeFunctionMiddleware setEdgeFunctionData:settings[@"edgeFunction"]];
        }
    }
}

- (NSDictionary *)defaultSettings
{
    NSDictionary *freshpaint = [self freshpaintSettings];
    NSDictionary *result = @{
        @"integrations" : @{
            @"Freshpaint.io" : freshpaint
        },
        @"plan" : @{
            @"track" : @{}
        }
    };
    return result;
}

- (NSDictionary *)freshpaintSettings
{
    NSDictionary *result = @{
        @"apiKey" : self.configuration.writeKey,
    };
    return result;
}

- (void)refreshSettings
{
    seg_dispatch_specific_async(_serialQueue, ^{
        if (self.configuration.defaultSettings != nil) {
            NSMutableDictionary *newSettings = [self.configuration.defaultSettings serializableMutableDeepCopy];
            NSMutableDictionary *integrations = newSettings[@"integrations"];
            if (integrations != nil) {
                integrations[@"Freshpaint.io"] = [self freshpaintSettings];
            } else {
                newSettings[@"integrations"] = @{@"Freshpaint.io": [self freshpaintSettings]};
            }
            NSLog(@"Hit default configured: %@", newSettings);
            [self setCachedSettings:newSettings];
        } else {
            NSLog(@"Hit default: %@", [self defaultSettings]);
            [self setCachedSettings:[self defaultSettings]];
        }
    });
}

#pragma mark - Private

+ (BOOL)isIntegration:(NSString *)key enabledInOptions:(NSDictionary *)options
{
    // If the event is in the tracking plan, it should always be sent to api.freshpaint.io.
    if ([@"Freshpaint.io" isEqualToString:key]) {
        return YES;
    }
    if (options[key]) {
        id value = options[key];
        
        // it's been observed that customers sometimes override this with
        // value's that aren't bool types.
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *numberValue = (NSNumber *)value;
            return [numberValue boolValue];
        } if ([value isKindOfClass:[NSDictionary class]]) {
            return YES;
        } else {
            NSString *msg = [NSString stringWithFormat: @"Value for `%@` in integration options is supposed to be a boolean or dictionary and it is not!"
                             "This is likely due to a user-added value in `integrations` that overwrites a value received from the server", key];
            FPLog(msg);
            NSAssert(NO, msg);
        }
    } else if (options[@"All"]) {
        return [options[@"All"] boolValue];
    } else if (options[@"all"]) {
        return [options[@"all"] boolValue];
    }
    return YES;
}

+ (BOOL)isTrackEvent:(NSString *)event enabledForIntegration:(NSString *)key inPlan:(NSDictionary *)plan
{
    // Whether the event is enabled or disabled, it should always be sent to api.freshpaint.io.
    if ([key isEqualToString:@"Freshpaint.io"]) {
        return YES;
    }

    if (plan[@"track"][event]) {
        if ([plan[@"track"][event][@"enabled"] boolValue]) {
            return [self isIntegration:key enabledInOptions:plan[@"track"][event][@"integrations"]];
        } else {
            return NO;
        }
    } else if (plan[@"track"][@"__default"]) {
        return [plan[@"track"][@"__default"][@"enabled"] boolValue];
    }

    return YES;
}

- (void)forwardSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    [self.integrations enumerateKeysAndObjectsUsingBlock:^(NSString *key, id<FPIntegration> integration, BOOL *stop) {
        [self invokeIntegration:integration key:key selector:selector arguments:arguments options:options];
    }];
}

/*
 This kind of sucks, but we wrote ourselves into a corner here.  A larger refactor will need to happen.
 I also opted to not put this as a utility function because we shouldn't be doing this in the first place,
 so consider it a one-off.  If you find yourself needing to do this again, lets talk about a refactor.
 */
- (FPEventType)eventTypeFromSelector:(SEL)selector
{
    NSString *selectorString = NSStringFromSelector(selector);
    FPEventType result = FPEventTypeUndefined;
    
    if ([selectorString hasPrefix:@"identify"]) {
        result = FPEventTypeIdentify;
    } else if ([selectorString hasPrefix:@"track"]) {
        result = FPEventTypeTrack;
    } else if ([selectorString hasPrefix:@"screen"]) {
        result = FPEventTypeScreen;
    } else if ([selectorString hasPrefix:@"group"]) {
        result = FPEventTypeGroup;
    } else if ([selectorString hasPrefix:@"alias"]) {
        result = FPEventTypeAlias;
    } else if ([selectorString hasPrefix:@"reset"]) {
        result = FPEventTypeReset;
    } else if ([selectorString hasPrefix:@"flush"]) {
        result = FPEventTypeFlush;
    } else if ([selectorString hasPrefix:@"receivedRemoteNotification"]) {
        result = FPEventTypeReceivedRemoteNotification;
    } else if ([selectorString hasPrefix:@"failedToRegisterForRemoteNotificationsWithError"]) {
        result = FPEventTypeFailedToRegisterForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"registeredForRemoteNotificationsWithDeviceToken"]) {
        result = FPEventTypeRegisteredForRemoteNotifications;
    } else if ([selectorString hasPrefix:@"handleActionWithIdentifier"]) {
        result = FPEventTypeHandleActionWithForRemoteNotification;
    } else if ([selectorString hasPrefix:@"continueUserActivity"]) {
        result = FPEventTypeContinueUserActivity;
    } else if ([selectorString hasPrefix:@"openURL"]) {
        result = FPEventTypeOpenURL;
    } else if ([selectorString hasPrefix:@"application"]) {
        result = FPEventTypeApplicationLifecycle;
    }

    return result;
}

- (void)invokeIntegration:(id<FPIntegration>)integration key:(NSString *)key selector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    if (![integration respondsToSelector:selector]) {
        FPLog(@"Not sending call to %@ because it doesn't respond to %@.", key, NSStringFromSelector(selector));
        return;
    }

    if (![[self class] isIntegration:key enabledInOptions:options[@"integrations"]]) {
        FPLog(@"Not sending call to %@ because it is disabled in options.", key);
        return;
    }
    
    FPEventType eventType = [self eventTypeFromSelector:selector];
    if (eventType == FPEventTypeTrack) {
        FPTrackPayload *eventPayload = arguments[0];
        BOOL enabled = [[self class] isTrackEvent:eventPayload.event enabledForIntegration:key inPlan:self.cachedSettings[@"plan"]];
        if (!enabled) {
            FPLog(@"Not sending call to %@ because it is disabled in plan.", key);
            return;
        }
    }

    NSMutableArray *newArguments = [arguments mutableCopy];

    if (eventType != FPEventTypeUndefined) {
        FPMiddlewareRunner *runner = self.integrationMiddleware[key];
        if (runner.middlewares.count > 0) {
            FPPayload *payload = nil;
            // things like flush have no args.
            if (arguments.count > 0) {
                payload = arguments[0];
            }
            FPContext *context = [[[FPContext alloc] initWithAnalytics:self.analytics] modify:^(id<FPMutableContext> _Nonnull ctx) {
                ctx.eventType = eventType;
                ctx.payload = payload;
            }];

            context = [runner run:context callback:nil];
            // if we weren't given args, don't set them.
            if (arguments.count > 0) {
                newArguments[0] = context.payload;
            }
        }
    }
    
    FPLog(@"Running: %@ with arguments %@ on integration: %@", NSStringFromSelector(selector), newArguments, key);
    NSInvocation *invocation = [self invocationForSelector:selector arguments:newArguments];
    [invocation invokeWithTarget:integration];
}

- (NSInvocation *)invocationForSelector:(SEL)selector arguments:(NSArray *)arguments
{
    struct objc_method_description description = protocol_getMethodDescription(@protocol(FPIntegration), selector, NO, YES);

    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:description.types];

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    for (int i = 0; i < arguments.count; i++) {
        id argument = (arguments[i] == [NSNull null]) ? nil : arguments[i];
        [invocation setArgument:&argument atIndex:i + 2];
    }
    return invocation;
}

- (void)queueSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSArray *obj = @[ NSStringFromSelector(selector), arguments ?: @[], options ?: @{} ];
    FPLog(@"Queueing: %@", obj);
    [_messageQueue addObject:obj];
}

- (void)flushMessageQueue
{
    if (_messageQueue.count != 0) {
        for (NSArray *arr in _messageQueue)
            [self forwardSelector:NSSelectorFromString(arr[0]) arguments:arr[1] options:arr[2]];
        [_messageQueue removeAllObjects];
    }
}

- (void)callIntegrationsWithSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options sync:(BOOL)sync
{
    // TODO: Currently we ignore the `sync` argument and queue the event asynchronously.
    // For integrations that need events to be on the main thread, they'll have to do so
    // manually and hop back on to the main thread.
    // Eventually we should figure out a way to handle this in analytics-ios itself.
    seg_dispatch_specific_async(_serialQueue, ^{
        if (self.initialized) {
            [self flushMessageQueue];
            [self forwardSelector:selector arguments:arguments options:options];
        } else {
            [self queueSelector:selector arguments:arguments options:options];
        }
    });
}

@end


@implementation FPIntegrationsManager (FPMiddleware)

- (void)context:(FPContext *)context next:(void (^_Nonnull)(FPContext *_Nullable))next
{
    switch (context.eventType) {
        case FPEventTypeIdentify: {
            FPIdentifyPayload *p = (FPIdentifyPayload *)context.payload;
            [self identify:p];
            break;
        }
        case FPEventTypeTrack: {
            FPTrackPayload *p = (FPTrackPayload *)context.payload;
            [self track:p];
            break;
        }
        case FPEventTypeScreen: {
            FPScreenPayload *p = (FPScreenPayload *)context.payload;
            [self screen:p];
            break;
        }
        case FPEventTypeGroup: {
            FPGroupPayload *p = (FPGroupPayload *)context.payload;
            [self group:p];
            break;
        }
        case FPEventTypeAlias: {
            FPAliasPayload *p = (FPAliasPayload *)context.payload;
            [self alias:p];
            break;
        }
        case FPEventTypeReset:
            [self reset];
            break;
        case FPEventTypeFlush:
            [self flush];
            break;
        case FPEventTypeReceivedRemoteNotification:
            [self receivedRemoteNotification:
                      [(FPRemoteNotificationPayload *)context.payload userInfo]];
            break;
        case FPEventTypeFailedToRegisterForRemoteNotifications:
            [self failedToRegisterForRemoteNotificationsWithError:
                      [(FPRemoteNotificationPayload *)context.payload error]];
            break;
        case FPEventTypeRegisteredForRemoteNotifications:
            [self registeredForRemoteNotificationsWithDeviceToken:
                      [(FPRemoteNotificationPayload *)context.payload deviceToken]];
            break;
        case FPEventTypeHandleActionWithForRemoteNotification: {
            FPRemoteNotificationPayload *payload = (FPRemoteNotificationPayload *)context.payload;
            [self handleActionWithIdentifier:payload.actionIdentifier
                       forRemoteNotification:payload.userInfo];
            break;
        }
        case FPEventTypeContinueUserActivity:
            [self continueUserActivity:
                      [(FPContinueUserActivityPayload *)context.payload activity]];
            break;
        case FPEventTypeOpenURL: {
            FPOpenURLPayload *payload = (FPOpenURLPayload *)context.payload;
            [self openURL:payload.url options:payload.options];
            break;
        }
        case FPEventTypeApplicationLifecycle:
            [self handleAppStateNotification:
                      [(FPApplicationLifecyclePayload *)context.payload notificationName]];
            break;
        default:
        case FPEventTypeUndefined:
            NSAssert(NO, @"Received context with undefined event type %@", context);
            FPLog(@"[ERROR]: Received context with undefined event type %@", context);
            break;
    }
    next(context);
}

@end
