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
 *
 * NOTE: The Keychain item uses kSecAttrAccessibleAfterFirstUnlock, which means it is
 * unavailable until after the first device unlock following a reboot. Events fired
 * before first unlock will use the IDFV fallback.
 *
 * NOTE: Keychain items persist across app uninstall/reinstall on the same device —
 * this is intentional and is what makes device_id stable across reinstalls.
 */
+ (NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END
