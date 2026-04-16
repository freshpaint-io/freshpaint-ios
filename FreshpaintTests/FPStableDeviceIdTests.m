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
+ (void)fp_resetUserDefaultsForTesting;
+ (BOOL)fp_writeToUserDefaults:(NSString *)value;
+ (nullable NSString *)fp_readFromUserDefaults;
+ (NSString *)fp_idfvFallback;
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
    // Start each test with a clean slate: no cached value, no NSUserDefaults entry.
    [FPStableDeviceId fp_resetUserDefaultsForTesting];
}

- (void)tearDown
{
    [FPStableDeviceId fp_resetUserDefaultsForTesting];
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

- (void)testDeviceIdPersistedToUserDefaults
{
    NSString *deviceId = [FPStableDeviceId deviceId];
    NSString *stored   = [FPStableDeviceId fp_readFromUserDefaults];
    XCTAssertEqualObjects(deviceId, stored,
                          @"deviceId should be persisted to NSUserDefaults");
}

- (void)testDeviceIdRestoredFromUserDefaultsAfterCacheReset
{
    // Generate and persist on first call.
    NSString *first = [FPStableDeviceId deviceId];

    // Clear in-memory cache to simulate a new launch.
    [FPStableDeviceId fp_resetCachedIdForTesting];

    // Second call should read from NSUserDefaults and return the same UUID.
    NSString *second = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(first, second,
                          @"deviceId should survive a cache reset (NSUserDefaults persistence)");
}

- (void)testPreSeededUserDefaultsValueIsReturned
{
    NSString *knownId = @"DEADBEEF-0000-0000-0000-123456789ABC";
    [FPStableDeviceId fp_writeToUserDefaults:knownId];

    NSString *result = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(result, knownId,
                          @"deviceId should return a pre-seeded NSUserDefaults value");
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
#pragma mark - FPStableDeviceId — NSUserDefaults helpers
// ---------------------------------------------------------------------------

- (void)testWriteAndReadRoundTrip
{
    NSString *value  = [[NSUUID UUID] UUIDString];
    BOOL      written = [FPStableDeviceId fp_writeToUserDefaults:value];
    XCTAssertTrue(written, @"fp_writeToUserDefaults should always return YES");

    NSString *read = [FPStableDeviceId fp_readFromUserDefaults];
    XCTAssertEqualObjects(value, read);
}

- (void)testExistingUserDefaultsValueIsReturnedNotOverwritten
{
    // Seed an original value into NSUserDefaults.
    NSString *originalId = @"AABBCCDD-0000-0000-0000-112233445566";
    [FPStableDeviceId fp_writeToUserDefaults:originalId];

    // Reset cache to simulate a new launch, then call deviceId.
    // It must read and return the seeded value, not generate a new one.
    [FPStableDeviceId fp_resetCachedIdForTesting];
    NSString *deviceId = [FPStableDeviceId deviceId];
    XCTAssertEqualObjects(deviceId, originalId,
        @"deviceId must return the existing NSUserDefaults value, not generate a new one");
}

- (void)testReadFromEmptyUserDefaultsReturnsNil
{
    NSString *result = [FPStableDeviceId fp_readFromUserDefaults];
    XCTAssertNil(result, @"Reading from an empty NSUserDefaults slot should return nil");
}

// ---------------------------------------------------------------------------
#pragma mark - Device context dict integration
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
