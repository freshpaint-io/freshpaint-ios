//
//  FPStableDeviceId.h
//  Freshpaint
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides a stable device identifier backed by NSUserDefaults.
 * The identifier is stored under the key `io.freshpaint.persistentDeviceId`.
 * Falls back to IDFV if NSUserDefaults write fails.
 *
 * NOTE: Unlike Keychain storage, NSUserDefaults values do NOT survive app uninstall.
 * The identifier is stable for the lifetime of the app installation on the device,
 * which is the intended and accepted trade-off.
 */
@interface FPStableDeviceId : NSObject

/**
 * Returns a stable device UUID. On first call, generates a UUID and persists it to
 * NSUserDefaults under key `io.freshpaint.persistentDeviceId`. On subsequent calls,
 * returns the cached or NSUserDefaults-persisted UUID.
 * Falls back to IDFV when NSUserDefaults write fails; retries write on the next call.
 */
+ (NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END

#if DEBUG
/**
 * Test helpers — not for production use.
 */
@interface FPStableDeviceId (Testing)
+ (void)fp_resetCachedIdForTesting;
+ (void)fp_resetUserDefaultsForTesting;
+ (BOOL)fp_writeToUserDefaults:(NSString *)value;
+ (nullable NSString *)fp_readFromUserDefaults;
+ (NSString *)fp_idfvFallback;
@end
#endif
