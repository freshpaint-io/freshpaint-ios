#import <Foundation/Foundation.h>
#import "FPIdentifyPayload.h"
#import "FPTrackPayload.h"
#import "FPScreenPayload.h"
#import "FPAliasPayload.h"
#import "FPIdentifyPayload.h"
#import "FPGroupPayload.h"
#import "FPContext.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Integration)
@protocol FPIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[FPAnalytics sharedInstance] identify:someUserId];
// 2. [[FPAnalytics sharedInstance] identify:someUserId traits:someTraits];
// 3. [[FPAnalytics sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(FPIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[FPAnalytics sharedInstance] track:someEvent];
// 2. [[FPAnalytics sharedInstance] track:someEvent properties:someProperties];
// 3. [[FPAnalytics sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(FPTrackPayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[FPAnalytics sharedInstance] screen:someEvent];
// 2. [[FPAnalytics sharedInstance] screen:someEvent properties:someProperties];
// 3. [[FPAnalytics sharedInstance] screen:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/screen/
- (void)screen:(FPScreenPayload *)payload;

// Group will be called when the user calls either of the following:
// 1. [[FPAnalytics sharedInstance] group:someGroupId];
// 2. [[FPAnalytics sharedInstance] group:someGroupId traits:];
// 3. [[FPAnalytics sharedInstance] group:someGroupId traits:someGroupTraits options:someOptions];
// @see https://segment.com/docs/spec/group/
- (void)group:(FPGroupPayload *)payload;

// Alias will be called when the user calls either of the following:
// 1. [[FPAnalytics sharedInstance] alias:someNewId];
// 2. [[FPAnalytics sharedInstance] alias:someNewId options:someOptions];
// @see https://segment.com/docs/spec/alias/
- (void)alias:(FPAliasPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// App Delegate Callbacks

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
