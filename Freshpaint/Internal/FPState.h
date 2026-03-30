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
/// Persisted flat map of @"$clickIdKey" → value and @"$clickIdKey_creation_time" → NSNumber.
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *clickIds;
/// In-memory map of active UTM parameters (utm_source, utm_medium, etc.).
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *utmParams;
/// Unix timestamp (seconds) when the stored UTM params expire (now + 86400 s).
@property (nonatomic, assign) NSTimeInterval utmExpiryTimestamp;
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

/// Merges extracted click IDs into stored state, deduplicating by value.
- (void)mergeClickIds:(NSDictionary<NSString *, id> *)extracted;

/// Returns the stored click IDs as a flat dict suitable for event properties.
/// Returns an empty dict (never nil) when no IDs are stored.
- (NSDictionary<NSString *, id> *)activeClickIdsFlattened;

/// Stores UTM parameters with a 24-hour expiry.
- (void)setUTMParams:(NSDictionary<NSString *, NSString *> *)params;

/// Returns the stored UTM params if not yet expired; nil if expired or absent.
- (NSDictionary<NSString *, NSString *> * _Nullable)activeUTMParams;

@end

NS_ASSUME_NONNULL_END
