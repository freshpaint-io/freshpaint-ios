//
//  FPStableDeviceId.m
//  Freshpaint
//

#import "FPStableDeviceId.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static NSString *const kFPStableDeviceIdUserDefaultsKey = @"io.freshpaint.persistentDeviceId";

// Access to this variable is serialized via fp_queue (dispatch_sync).
static NSString *_fpCachedDeviceId = nil;

@implementation FPStableDeviceId

+ (dispatch_queue_t)fp_queue
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.freshpaint.sdk.device_id.queue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

+ (NSString *)deviceId
{
    __block NSString *result = nil;
    dispatch_sync([self fp_queue], ^{
        // Return in-memory cached value if available.
        if (_fpCachedDeviceId) {
            result = _fpCachedDeviceId;
            return;
        }

        // Try to read a previously persisted UUID from NSUserDefaults.
        NSString *stored = [self fp_readFromUserDefaults];
        if (stored) {
            _fpCachedDeviceId = stored;
            result = stored;
            return;
        }

        // Nothing persisted — generate a new UUID and write it.
        NSString *newId = [[NSUUID UUID] UUIDString];
        [self fp_writeToUserDefaults:newId];
        _fpCachedDeviceId = newId;
        result = newId;
    });

    if (result) {
        return result;
    }
    // Graceful fallback when NSUserDefaults is completely unavailable.
    return [self fp_idfvFallback];
}

+ (nullable NSString *)fp_readFromUserDefaults
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kFPStableDeviceIdUserDefaultsKey];
}

+ (BOOL)fp_writeToUserDefaults:(NSString *)value
{
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:kFPStableDeviceIdUserDefaultsKey];
    return YES;
}

+ (NSString *)fp_idfvFallback
{
#if TARGET_OS_IPHONE
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (idfv) {
        return idfv;
    }
#endif
    // Last resort: generate a random UUID (not stable across launches).
    return [[NSUUID UUID] UUIDString];
}

#if DEBUG
// Test helpers — not for production use.

+ (void)fp_resetCachedIdForTesting
{
    dispatch_sync([self fp_queue], ^{
        _fpCachedDeviceId = nil;
    });
}

+ (void)fp_resetUserDefaultsForTesting
{
    dispatch_sync([self fp_queue], ^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPStableDeviceIdUserDefaultsKey];
        _fpCachedDeviceId = nil;
    });
}

#endif

@end
