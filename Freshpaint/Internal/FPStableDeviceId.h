//
//  FPStableDeviceId.h
//  Freshpaint
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides a stable device identifier that persists across app reinstalls via Keychain.
 * Falls back to IDFV if Keychain operations fail.
 */
@interface FPStableDeviceId : NSObject

/**
 * Returns a stable device UUID. On first call, generates a UUID and persists it to Keychain
 * (service: com.freshpaint.sdk.device_id, accessibility: kSecAttrAccessibleAfterFirstUnlock).
 * On subsequent calls, returns the cached or Keychain-persisted UUID.
 * Falls back to IDFV when Keychain write fails; retries write on the next call.
 */
+ (NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END
