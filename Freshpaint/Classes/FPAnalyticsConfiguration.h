//
//  FPIntegrationsManager.h
//  Analytics
//
//  Created by Tony Xiao on 9/20/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

NS_SWIFT_NAME(ApplicationProtocol)
@protocol FPApplicationProtocol <NSObject>

#if TARGET_OS_IPHONE
@property (nullable, nonatomic, assign) id<UIApplicationDelegate> delegate;
#elif TARGET_OS_OSX
@property (nullable, nonatomic, assign) id<NSApplicationDelegate> delegate;
#endif
- (NSUInteger)seg_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler;
- (void)seg_endBackgroundTask:(NSUInteger)identifier;
@end

#if TARGET_OS_IOS
@interface UIApplication (FPApplicationProtocol) <FPApplicationProtocol>
@end
#elif TARGET_OS_OSX
@interface NSApplication (FPApplicationProtocol) <FPApplicationProtocol>
@end
#endif


typedef NSMutableURLRequest *_Nonnull (^FPRequestFactory)(NSURL *_Nonnull);
typedef NSString *_Nonnull (^FPAdSupportBlock)(void);

@protocol FPIntegrationFactory;
@protocol FPCrypto;
@protocol FPMiddleware;
@protocol FPEdgeFunctionMiddleware;

@class FPAnalyticsExperimental;
@class FPDestinationMiddleware;

/**
 * This object provides a set of properties to control various policies of the analytics client. Other than `writeKey`, these properties can be changed at any time.
 */
NS_SWIFT_NAME(FreshpaintConfiguration)
@interface FPAnalyticsConfiguration : NSObject

/**
 * Creates and returns a configuration with default settings and the given write key.
 *
 * @param writeKey Your project's write key from freshpaint.io.
 */
+ (_Nonnull instancetype)configurationWithWriteKey:(NSString *_Nonnull)writeKey;

/**
 * Your project's write key from freshpaint.io.
 *
 * @see +configurationWithWriteKey:
 */
@property (nonatomic, copy, readonly, nonnull) NSString *writeKey;

/**
 * Whether the analytics client should use location services.
 * If `YES` and the host app hasn't asked for permission to use location services then the user will be presented with an alert view asking to do so. `NO` by default.
 * If `YES`, please make sure to add a description for `NSLocationAlwaysUsageDescription` in your `Info.plist` explaining why your app is accessing Location APIs.
 */
@property (nonatomic, assign) BOOL shouldUseLocationServices;

/**
 * Whether the analytics client should track advertisting info. `YES` by default.
 */
@property (nonatomic, assign) BOOL enableAdvertisingTracking;

/**
 * The number of queued events that the analytics client should flush at. Setting this to `1` will not queue any events and will use more battery. `20` by default.
 */
@property (nonatomic, assign) NSUInteger flushAt;

/**
 * The amount of time to wait before each tick of the flush timer.
 * Smaller values will make events delivered in a more real-time manner and also use more battery.
 * A value smaller than 10 seconds will seriously degrade overall performance.
 * 30 seconds by default.
 */
@property (nonatomic, assign) NSTimeInterval flushInterval;

/**
 * The maximum number of items to queue before starting to drop old ones. This should be a value greater than zero, the behaviour is undefined otherwise. `1000` by default.
 */
@property (nonatomic, assign) NSUInteger maxQueueSize;

/**
 * Whether the analytics client should automatically make a track call for application lifecycle events, such as "Application Installed", "Application Updated" and "Application Opened".
 */
@property (nonatomic, assign) BOOL trackApplicationLifecycleEvents;


/**
 * Whether the analytics client should record bluetooth information. If `YES`, please make sure to add a description for `NSBluetoothPeripheralUsageDescription` in your `Info.plist` explaining explaining why your app is accessing Bluetooth APIs. `NO` by default.
 */
@property (nonatomic, assign) BOOL shouldUseBluetooth;

/**
 * Whether the analytics client should automatically make a screen call when a view controller is added to a view hierarchy. Because the underlying implementation uses method swizzling, we recommend initializing the analytics client as early as possible (before any screens are displayed), ideally during the Application delegate's applicationDidFinishLaunching method.
 */
@property (nonatomic, assign) BOOL recordScreenViews;

/**
 * Whether the analytics client should automatically track in-app purchases from the App Store.
 */
@property (nonatomic, assign) BOOL trackInAppPurchases;

/**
 * Whether the analytics client should automatically track push notifications.
 */
@property (nonatomic, assign) BOOL trackPushNotifications;

/**
 * Whether the analytics client should automatically track deep links. You'll still need to call the continueUserActivity and openURL methods on the analytics client.
 */
@property (nonatomic, assign) BOOL trackDeepLinks;

/**
 * Dictionary indicating the options the app was launched with.
 */
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

/**
 * Set a custom request factory.
 */
@property (nonatomic, strong, nullable) FPRequestFactory requestFactory;

/**
 * Set a custom crypto
 */
@property (nonatomic, strong, nullable) id<FPCrypto> crypto;


/**
 * Set the default settings to use if Segment.com cannot be reached. 
 * An example configuration can be found here, using your write key:  https://cdn-settings.freshpaint.com/v1/projects/YOUR_WRITE_KEY/settings
 */
@property (nonatomic, strong, nullable) NSDictionary *defaultSettings;

/**
 * Set custom middlewares. Will be run before all integrations.
 *  This property is deprecated in favor of the `sourceMiddleware` property.
 */
@property (nonatomic, strong, nullable) NSArray<id<FPMiddleware>> *middlewares DEPRECATED_MSG_ATTRIBUTE("Use .sourceMiddleware instead.");

/**
 * Set custom source middleware. Will be run before all integrations
 */
@property (nonatomic, strong, nullable) NSArray<id<FPMiddleware>> *sourceMiddleware;

/**
 * Set custom destination middleware. Will be run before the associated integration for a destination.
 */
@property (nonatomic, strong, nullable) NSArray<FPDestinationMiddleware *> *destinationMiddleware;

/**
 * Sets edge function middleware.  This takes precendence over native middlewares.  Any middleware set via `sourceMiddleware`
 * or `destinationMiddleware` will be removed.
 */
@property (nonatomic, strong, nullable) id<FPEdgeFunctionMiddleware> edgeFunctionMiddleware;

/**
 * Register a factory that can be used to create an integration.
 */
- (void)use:(id<FPIntegrationFactory> _Nonnull)factory;

/**
 * Leave this nil for iOS extensions, otherwise set to UIApplication.sharedApplication.
 */
@property (nonatomic, strong, nullable) id<FPApplicationProtocol> application;

/**
 * A dictionary of filters to redact payloads before they are sent.
 * This is an experimental feature that currently only applies to Deep Links.
 * It is subject to change to allow for more flexible customizations in the future.
 *
 * The key of this dictionary should be a regular expression string pattern,
 * and the value should be a regular expression substitution template.
 *
 * By default, this contains a Facebook auth token filter, configured as such:
 * @code
 * @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
 * @endcode
 *
 * This will replace any matching occurences to a redacted version:
 * @code
 * "fb123456789://authorize#access_token=secretsecretsecretsecret&some=data"
 * @endcode
 *
 * Becomes:
 * @code
 * "fb123456789://authorize#access_token=((redacted/fb-auth-token))"
 * @endcode
 *
 */
@property (nonatomic, strong, nonnull) NSDictionary<NSString*, NSString*>* payloadFilters;

/**
 * An optional delegate that handles NSURLSessionDelegate callbacks
 */
@property (nonatomic, strong, nullable) id<NSURLSessionDelegate> httpSessionDelegate;

/**
 * Sets a block to be called when IDFA / AdSupport identifier is created.
 * This is to allow for apps that do not want ad tracking to pass App Store guidelines in certain categories while
 * still allowing apps that do ad tracking to continue to function.
 *
 * Example:
 *      configuration.adSupportBlock = ^{
 *          return [[ASIdentifierManager sharedManager] advertisingIdentifier];
 *      }
 */
@property (nonatomic, strong, nullable) FPAdSupportBlock adSupportBlock;

/**
 Enable experimental features within the Freshpaint Analytics-iOS library.
 */
@property (nonatomic, readonly, nonnull) FPAnalyticsExperimental *experimental;

/**
 * The maximum duration of a user session before it expires and is renewed.
 * Measured in seconds. Default value is 30 minutes (1800 seconds).
 * Session timeout interval, expressed in seconds.
 * For example, a value of 1800 represents 30 minutes.
 */
@property (nonatomic, assign) NSTimeInterval sessionTimeout;

@end

#pragma mark - Experimental

typedef  NSDictionary * _Nonnull (^FPRawModificationBlock)( NSDictionary * _Nonnull rawPayload);

NS_SWIFT_NAME(FreshpaintExperimental)
@interface FPAnalyticsExperimental : NSObject
/**
 Experimental support for nanosecond timestamps.  While the freshpaint pipeline doesn't support this yet
 it can be useful where sub-milisecond precision is needed.  An example of this is at startup, when many events
 fire at the same time and end up with the same timestamp.  The format is "yyyy-MM-ddTHH:mm:ss.SSSSSSSSS:Z".
 
 This will show up only on the originalTimestamp value as seen in the freshpaint debugger.  To properly sort this, one
 will need to sort by originalTimestamp as well as timestamp.  This should display events in the exact order they were
 received.
 */
@property (nonatomic, assign) BOOL nanosecondTimestamps;
/**
 Experimental support for transformation of raw dictionaries prior to being sent to freshpaint.
 This should generally NOT be used, but is a current stop-gap measure for some customers who need to filter
 payload data prior to being received by freshpaint.com.  This property will go away in future versions when context
 object data is made available earlier in the event pipeline.
 */
@property (nonatomic, strong, nullable) FPRawModificationBlock rawFreshpaintModificationBlock;

@end
