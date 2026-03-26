//
//  FPStableDeviceId.m
//  Freshpaint
//

#import "FPStableDeviceId.h"
#import <Security/Security.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static NSString *const kFPStableDeviceIdService = @"com.freshpaint.sdk.device_id";
static NSString *const kFPStableDeviceIdAccount = @"device_id";

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

        // Try to read a previously persisted UUID from Keychain.
        NSString *stored = [self fp_readFromKeychain];
        if (stored) {
            _fpCachedDeviceId = stored;
            result = stored;
            return;
        }

        // Nothing persisted — generate a new UUID and try to write it.
        NSString *newId = [[NSUUID UUID] UUIDString];
        BOOL written = [self fp_writeToKeychain:newId];
        if (written) {
            // fp_writeToKeychain may have set _fpCachedDeviceId to a
            // pre-existing Keychain value (errSecDuplicateItem path).
            // Only assign newId if the cache wasn't already populated.
            if (!_fpCachedDeviceId) {
                _fpCachedDeviceId = newId;
            }
            result = _fpCachedDeviceId;
        }
        // If write failed: result remains nil here.
        // The caller falls back to IDFV and we do NOT cache,
        // so the next call will retry the Keychain write.
    });

    if (result) {
        return result;
    }
    // Graceful fallback when Keychain is completely unavailable.
    return [self fp_idfvFallback];
}

+ (nullable NSString *)fp_readFromKeychain
{
    NSDictionary *query = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kFPStableDeviceIdService,
        (__bridge id)kSecAttrAccount: kFPStableDeviceIdAccount,
        (__bridge id)kSecReturnData:  @YES,
        (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef dataRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataRef);

    if (status == errSecSuccess && dataRef != NULL) {
        NSData *data = (__bridge_transfer NSData *)dataRef;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+ (BOOL)fp_writeToKeychain:(NSString *)value
{
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass:          (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:    kFPStableDeviceIdService,
        (__bridge id)kSecAttrAccount:    kFPStableDeviceIdAccount,
        (__bridge id)kSecValueData:      data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock
    };

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status == errSecSuccess) {
        return YES;
    }
    if (status == errSecDuplicateItem) {
        // An item already exists (e.g. restored backup, MDM-provisioned device,
        // or a partial write from a previous launch). Read it back so the caller
        // can populate the cache rather than falling back to IDFV permanently.
        NSString *existing = [self fp_readFromKeychain];
        if (existing) {
            _fpCachedDeviceId = existing;
        }
        return (existing != nil);
    }
    return NO;
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

+ (void)fp_deleteKeychainItemForTesting
{
    NSDictionary *query = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kFPStableDeviceIdService,
        (__bridge id)kSecAttrAccount: kFPStableDeviceIdAccount
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#endif

@end
