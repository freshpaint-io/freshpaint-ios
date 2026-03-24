//
//  FPStableDeviceIdTests.m
//  FreshpaintTests
//

#import <XCTest/XCTest.h>
#import "FPStableDeviceId.h"
#import "FPAnalyticsConfiguration.h"
#import "FPUtils.h"

// Expose private/debug methods for testing.
@interface FPStableDeviceId (Testing)
+ (void)fp_resetCachedIdForTesting;
+ (void)fp_deleteKeychainItemForTesting;
+ (NSString *)fp_idfvFallback;
+ (nullable NSString *)fp_readFromKeychain;
+ (BOOL)fp_writeToKeychain:(NSString *)value;
@end

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPStableDeviceIdTests : XCTestCase
@end

@implementation FPStableDeviceIdTests

- (void)setUp
{
    [super setUp];
    // Start each test with a clean slate: no cached value, no Keychain item.
    [FPStableDeviceId fp_resetCachedIdForTesting];
    [FPStableDeviceId fp_deleteKeychainItemForTesting];
}

- (void)tearDown
{
    [FPStableDeviceId fp_resetCachedIdForTesting];
    [FPStableDeviceId fp_deleteKeychainItemForTesting];
    [super tearDown];
}

// ---------------------------------------------------------------------------
#pragma mark - Configuration property defaults
// ---------------------------------------------------------------------------

- (void)testAutoRequestATTDefaultIsNO
{
    FPAnalyticsConfiguration *config = [FPAnalyticsConfiguration configurationWithWriteKey:@"test"];
    XCTAssertFalse(config.autoRequestATT, @"autoRequestATT should default to NO");
}

- (void)testSkanConversionValueDefaultIsZero
{
    FPAnalyticsConfiguration *config = [FPAnalyticsConfiguration configurationWithWriteKey:@"test"];
    XCTAssertEqual(config.skanConversionValue, 0, @"skanConversionValue should default to 0");
}

- (void)testAutoTrackFirstOpenDefaultIsYES
{
    FPAnalyticsConfiguration *config = [FPAnalyticsConfiguration configurationWithWriteKey:@"test"];
    XCTAssertTrue(config.autoTrackFirstOpen, @"autoTrackFirstOpen should default to YES");
}

- (void)testConfigurationPropertiesAreWritable
{
    FPAnalyticsConfiguration *config = [FPAnalyticsConfiguration configurationWithWriteKey:@"test"];
    config.autoRequestATT = YES;
    config.skanConversionValue = 42;
    config.autoTrackFirstOpen = NO;

    XCTAssertTrue(config.autoRequestATT);
    XCTAssertEqual(config.skanConversionValue, 42);
    XCTAssertFalse(config.autoTrackFirstOpen);
}

// ---------------------------------------------------------------------------
#pragma mark - FPStableDeviceId — happy path
// ---------------------------------------------------------------------------

- (void)testDeviceIdReturnsNonNilString
{
    NSString *deviceId = [FPStableDeviceId deviceId];
    XCTAssertNotNil(deviceId);
    XCTAssertGreaterThan(deviceId.length, 0u);
}

- (void)testDeviceIdReturnsValidUUIDFormat
{
    NSString *deviceId = [FPStableDeviceId deviceId];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:deviceId];
    XCTAssertNotNil(uuid, @"deviceId should be a valid UUID string, got: %@", deviceId);
}

- (void)testDeviceIdReturnsSameValueOnSubsequentCalls
{
    NSString *first  = [FPStableDeviceId deviceId];
    NSString *second = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(first, second,
                          @"deviceId should be stable across calls within the same launch");
}

- (void)testDeviceIdPersistedToKeychain
{
    // Verify Keychain is available in this environment before asserting.
    NSString *probe = [[NSUUID UUID] UUIDString];
    BOOL available  = [FPStableDeviceId fp_writeToKeychain:probe];
    if (!available) {
        // Keychain unavailable on this simulator/environment — skip.
        [FPStableDeviceId fp_deleteKeychainItemForTesting];
        return;
    }
    [FPStableDeviceId fp_deleteKeychainItemForTesting];

    NSString *deviceId = [FPStableDeviceId deviceId];
    NSString *stored   = [FPStableDeviceId fp_readFromKeychain];
    XCTAssertEqualObjects(deviceId, stored,
                          @"deviceId should be persisted to Keychain");
}

- (void)testDeviceIdRestoredFromKeychainAfterCacheReset
{
    // Generate and persist on first call.
    NSString *first = [FPStableDeviceId deviceId];

    // Clear in-memory cache to simulate a new launch.
    [FPStableDeviceId fp_resetCachedIdForTesting];

    // Second call should read from Keychain and return the same UUID.
    NSString *second = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(first, second,
                          @"deviceId should survive a cache reset (Keychain persistence)");
}

- (void)testPreSeededKeychainValueIsReturned
{
    NSString *knownId = @"DEADBEEF-0000-0000-0000-123456789ABC";
    BOOL written = [FPStableDeviceId fp_writeToKeychain:knownId];
    if (!written) {
        // Keychain unavailable on this simulator/environment — skip.
        return;
    }

    NSString *result = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(result, knownId,
                          @"deviceId should return a pre-seeded Keychain value");
}

// ---------------------------------------------------------------------------
#pragma mark - FPStableDeviceId — IDFV fallback
// ---------------------------------------------------------------------------

- (void)testIdfvFallbackReturnsNonNilString
{
    NSString *fallback = [FPStableDeviceId fp_idfvFallback];
    XCTAssertNotNil(fallback);
    XCTAssertGreaterThan(fallback.length, 0u);
}

- (void)testIdfvFallbackReturnsValidUUID
{
    NSString *fallback = [FPStableDeviceId fp_idfvFallback];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:fallback];
    XCTAssertNotNil(uuid, @"idfvFallback should be a valid UUID string");
}

// ---------------------------------------------------------------------------
#pragma mark - FPStableDeviceId — Keychain helpers
// ---------------------------------------------------------------------------

- (void)testWriteAndReadRoundTrip
{
    NSString *value   = [[NSUUID UUID] UUIDString];
    BOOL      written = [FPStableDeviceId fp_writeToKeychain:value];
    if (!written) {
        // Keychain unavailable on this simulator/environment — skip.
        return;
    }

    NSString *read = [FPStableDeviceId fp_readFromKeychain];
    XCTAssertEqualObjects(value, read);
}

- (void)testReadFromEmptyKeychainReturnsNil
{
    NSString *result = [FPStableDeviceId fp_readFromKeychain];
    XCTAssertNil(result, @"Reading from an empty Keychain slot should return nil");
}

// ---------------------------------------------------------------------------
#pragma mark - Device context dict integration (ACs #7 and #8)
// ---------------------------------------------------------------------------

- (void)testDeviceContextContainsDeviceIdAndIdfv
{
#if TARGET_OS_IPHONE
    // device_id and idfv are only populated inside mobileSpecifications(),
    // which is itself guarded with #if TARGET_OS_IPHONE — skip on macOS.
    FPAnalyticsConfiguration *config = [FPAnalyticsConfiguration configurationWithWriteKey:@"test"];
    NSDictionary *context = getStaticContext(config, nil);
    NSDictionary *device  = context[@"device"];

    XCTAssertNotNil(device[@"device_id"], @"device_id should be present in device context");
    XCTAssertNotNil(device[@"idfv"],      @"idfv should be present in device context");
    XCTAssertNotNil(device[@"id"],        @"id (backward compat) should still be present");

    // device_id should be a valid UUID
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:device[@"device_id"]];
    XCTAssertNotNil(uuid, @"device_id should be a valid UUID, got: %@", device[@"device_id"]);
#endif
}

@end
