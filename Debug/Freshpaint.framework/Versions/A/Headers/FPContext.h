//
//  FPContext.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FPIntegration.h"

typedef NS_ENUM(NSInteger, FPEventType) {
    // Should not happen, but default state
    FPEventTypeUndefined,
    // Core Tracking Methods
    FPEventTypeIdentify,
    FPEventTypeTrack,
    FPEventTypeScreen,
    FPEventTypeGroup,
    FPEventTypeAlias,

    // General utility
    FPEventTypeReset,
    FPEventTypeFlush,

    // Remote Notification
    FPEventTypeReceivedRemoteNotification,
    FPEventTypeFailedToRegisterForRemoteNotifications,
    FPEventTypeRegisteredForRemoteNotifications,
    FPEventTypeHandleActionWithForRemoteNotification,

    // Application Lifecycle
    FPEventTypeApplicationLifecycle,
    //    DidFinishLaunching,
    //    FPEventTypeApplicationDidEnterBackground,
    //    FPEventTypeApplicationWillEnterForeground,
    //    FPEventTypeApplicationWillTerminate,
    //    FPEventTypeApplicationWillResignActive,
    //    FPEventTypeApplicationDidBecomeActive,

    // Misc.
    FPEventTypeContinueUserActivity,
    FPEventTypeOpenURL,

} NS_SWIFT_NAME(EventType);

@class FPAnalytics;
@protocol FPMutableContext;


NS_SWIFT_NAME(Context)
@interface FPContext : NSObject <NSCopying>

// Loopback reference to the top level FPAnalytics object.
// Not sure if it's a good idea to keep this around in the context.
// since we don't really want people to use it due to the circular
// reference and logic (Thus prefixing with underscore). But
// Right now it is required for integrations to work so I guess we'll leave it in.
@property (nonatomic, readonly, nonnull) FPAnalytics *_analytics;
@property (nonatomic, readonly) FPEventType eventType;

@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) FPPayload *payload;
@property (nonatomic, readonly) BOOL debug;

- (instancetype _Nonnull)initWithAnalytics:(FPAnalytics *_Nonnull)analytics;

- (FPContext *_Nonnull)modify:(void (^_Nonnull)(id<FPMutableContext> _Nonnull ctx))modify;

@end

@protocol FPMutableContext <NSObject>

@property (nonatomic) FPEventType eventType;
@property (nonatomic, nullable) FPPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end
