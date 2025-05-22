//
//  FPState.h
//  Analytics
//
//  Created by Brandon Sneed on 6/9/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FPAnalyticsConfiguration;

@interface FPUserInfo: NSObject
@property (nonatomic, strong) NSString *anonymousId;
@property (nonatomic, strong, nullable) NSString *userId;
@property (nonatomic, strong, nullable) NSDictionary *traits;
@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, assign) NSTimeInterval lastSessionTimestamp;
@property (nonatomic, assign) BOOL isFirstEventInSession;
@end

@interface FPPayloadContext: NSObject
@property (nonatomic, readonly) NSDictionary *payload;
@property (nonatomic, strong, nullable) NSDictionary *referrer;
@property (nonatomic, strong, nullable) NSString *deviceToken;

- (void)updateStaticContext;

@end



@interface FPState : NSObject

@property (nonatomic, readonly) FPUserInfo *userInfo;
@property (nonatomic, readonly) FPPayloadContext *context;

@property (nonatomic, strong, nullable) FPAnalyticsConfiguration *configuration;

+ (instancetype)sharedInstance;
- (instancetype)init __unavailable;

- (void)setUserInfo:(FPUserInfo *)userInfo;
- (void)validateOrRenewSessionWithTimeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
