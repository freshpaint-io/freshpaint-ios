//
//  FPAppInstallEventTests.m
//  FreshpaintTests
//
//  Unit tests for FRP-37: enhanced app_install lifecycle event with MMP attribution payload.
//

#import <XCTest/XCTest.h>
#import "FPAnalytics.h"
#import "FPAnalyticsConfiguration.h"
#import "FPMiddleware.h"
#import "FPContext.h"
#import "FPTrackPayload.h"

// ---------------------------------------------------------------------------
#pragma mark - Test-only extensions
// ---------------------------------------------------------------------------

/// Exposes the private lifecycle handler and the DEBUG ATT status injectable.
@interface FPAnalytics (FPInstallTesting)
#ifdef DEBUG
@property (nonatomic, copy, nullable) NSUInteger (^fp_attStatusProvider)(void);
#endif
- (void)_applicationDidFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
@end

// ---------------------------------------------------------------------------
#pragma mark - Capture middleware
// ---------------------------------------------------------------------------

/// Captures every context that flows through the middleware pipeline.
@interface FPInstallEventCapture : NSObject <FPMiddleware>
@property (nonatomic, readonly, strong) NSMutableArray<FPContext *> *capturedContexts;
@end

@implementation FPInstallEventCapture

- (instancetype)init
{
    if (self = [super init]) {
        _capturedContexts = [NSMutableArray array];
    }
    return self;
}

- (void)context:(FPContext *)context next:(FPMiddlewareNext)next
{
    [_capturedContexts addObject:context];
    next(context);
}

@end

// ---------------------------------------------------------------------------
#pragma mark - ATT status constants
// ---------------------------------------------------------------------------

static const NSUInteger kFPATTNotDetermined = 0;
static const NSUInteger kFPATTDenied        = 2;
static const NSUInteger kFPATTAuthorized    = 3;

static NSString *const kFPValidIDFA  = @"12345678-1234-1234-1234-123456789ABC";
static NSString *const kFPZeroIDFA   = @"00000000-0000-0000-0000-000000000000";

// NSUserDefaults keys (match the constants defined in FPAnalytics.m)
static NSString *const kFPBuildKeyV2  = @"FPBuildKeyV2";
static NSString *const kFPVersionKey  = @"FPVersionKey";

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPAppInstallEventTests : XCTestCase
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) FPAnalytics              *analytics;
@property (nonatomic, strong) FPInstallEventCapture    *capture;
// Saved NSUserDefaults values — restored in tearDown.
@property (nonatomic, copy, nullable) NSString         *savedBuildV2;
@property (nonatomic, copy, nullable) NSString         *savedVersion;
@end

@implementation FPAppInstallEventTests

- (void)setUp
{
    [super setUp];

    // Persist original NSUserDefaults state so tearDown can restore it exactly.
    self.savedBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:kFPBuildKeyV2];
    self.savedVersion = [[NSUserDefaults standardUserDefaults] stringForKey:kFPVersionKey];

    // Simulate a fresh install by removing the guard flag.
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPVersionKey];

    // Build a configuration that fires lifecycle events but does NOT hook into
    // UIApplication (no notifications registered — tests drive the method directly).
    self.configuration = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    self.configuration.trackApplicationLifecycleEvents = YES;
    self.configuration.application = nil;

    self.capture = [[FPInstallEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ self.capture ];

    self.analytics = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
}

- (void)tearDown
{
    // Restore NSUserDefaults to the state before this test.
    if (self.savedBuildV2) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedBuildV2 forKey:kFPBuildKeyV2];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPBuildKeyV2];
    }
    if (self.savedVersion) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedVersion forKey:kFPVersionKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPVersionKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.analytics     = nil;
    self.capture       = nil;
    self.configuration = nil;
    [super tearDown];
}

// Returns the first captured app_install track payload, or nil if absent.
- (nullable FPTrackPayload *)capturedInstallPayload
{
    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]] &&
            [track.event isEqualToString:@"app_install"]) {
            return track;
        }
    }
    return nil;
}

// Returns YES if an event with the given name was captured.
- (BOOL)capturedEventNamed:(NSString *)name
{
    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]] &&
            [track.event isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

// ---------------------------------------------------------------------------
#pragma mark - AC 1: Event name is app_install (AC #8: fires once on first install)
// ---------------------------------------------------------------------------

/// On the very first launch (FPBuildKeyV2 absent), app_install must be tracked.
- (void)testFiresAppInstallOnFirstLaunch
{
#if TARGET_OS_IOS
    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    XCTAssertTrue([self capturedEventNamed:@"app_install"],
                  @"app_install must fire when FPBuildKeyV2 is absent (first install)");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 8 (returning device): fires exactly once per install
// ---------------------------------------------------------------------------

/// On a returning launch (FPBuildKeyV2 already present), app_install must NOT fire.
- (void)testDoesNotFireOnReturningDevice
{
#if TARGET_OS_IOS
    // Seed the guard flag to simulate a returning user.
    [[NSUserDefaults standardUserDefaults] setObject:@"1.0" forKey:kFPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:kFPVersionKey];

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    XCTAssertFalse([self capturedEventNamed:@"app_install"],
                   @"app_install must NOT fire when FPBuildKeyV2 is already set");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 2/3/4/5/7: Payload field validation
// ---------------------------------------------------------------------------

/// install_timestamp, device_id, idfv, att_status, os_version, and app_version
/// must all be present and non-empty in the app_install payload.
- (void)testPayloadContainsRequiredFields
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kFPATTNotDetermined; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"app_install payload must be captured");

    NSDictionary *props = payload.properties;

    // install_timestamp — non-empty string parseable as a date
    NSString *timestamp = props[@"install_timestamp"];
    XCTAssertNotNil(timestamp, @"install_timestamp must be present");
    XCTAssertGreaterThan(timestamp.length, 0u);
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.locale     = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    df.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'";
    XCTAssertNotNil([df dateFromString:timestamp],
                    @"install_timestamp must be a valid ISO 8601 date string, got: %@", timestamp);

    // device_id — non-empty UUID string
    NSString *deviceId = props[@"device_id"];
    XCTAssertNotNil(deviceId, @"device_id must be present");
    XCTAssertNotNil([[NSUUID alloc] initWithUUIDString:deviceId],
                    @"device_id must be a valid UUID, got: %@", deviceId);

    // idfv — non-empty string (or empty string on simulators without IDFV)
    XCTAssertNotNil(props[@"idfv"], @"idfv key must be present");

    // att_status — always present
    XCTAssertNotNil(props[@"att_status"], @"att_status must be present");
    XCTAssertGreaterThan(((NSString *)props[@"att_status"]).length, 0u);

    // os_version — non-empty
    NSString *osVersion = props[@"os_version"];
    XCTAssertNotNil(osVersion, @"os_version must be present");
    XCTAssertGreaterThan(osVersion.length, 0u);

    // app_version — non-nil (may be empty in test bundle)
    XCTAssertNotNil(props[@"app_version"], @"app_version key must be present");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 6: idfa conditional on ATT authorization
// ---------------------------------------------------------------------------

/// idfa must appear in the payload when ATT is authorized and adSupportBlock is set.
- (void)testIDFAIncludedWhenATTAuthorized
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kFPATTAuthorized; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPValidIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"app_install payload must be captured");
    XCTAssertEqualObjects(payload.properties[@"idfa"], kFPValidIDFA,
                          @"idfa must be present and match when ATT is authorized");
#endif
}

/// idfa must NOT appear when ATT is not authorized (denied).
- (void)testIDFAAbsentWhenATTNotAuthorized
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kFPATTDenied; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPValidIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"app_install payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when ATT status is not authorized");
#endif
}

/// idfa must NOT appear when ATT is authorized but adSupportBlock is nil.
- (void)testIDFAAbsentWhenAdSupportBlockNil
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kFPATTAuthorized; };
    // adSupportBlock intentionally not set — remains nil

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"app_install payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when adSupportBlock is nil even if ATT is authorized");
#endif
}

/// idfa must NOT appear when ATT is authorized but adSupportBlock returns zeroed IDFA.
- (void)testIDFAAbsentWhenZeroedIDFA
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kFPATTAuthorized; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPZeroIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"app_install payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when adSupportBlock returns all-zeros IDFA");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 9: Flag set after enqueue, not after flush
// ---------------------------------------------------------------------------

/// FPBuildKeyV2 must be written synchronously after the app_install event is
/// enqueued — without waiting for a flush call.
- (void)testFlagSetAfterEnqueue
{
#if TARGET_OS_IOS
    // Guard: key must be absent before the call.
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:kFPBuildKeyV2],
                 @"Pre-condition: FPBuildKeyV2 must be nil before first launch");

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    // No flush called — flag must already be set.
    NSString *storedBuild = [[NSUserDefaults standardUserDefaults] stringForKey:kFPBuildKeyV2];
    XCTAssertNotNil(storedBuild,
                    @"FPBuildKeyV2 must be written immediately after app_install is enqueued, not deferred to flush");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 10: Existing lifecycle events unaffected
// ---------------------------------------------------------------------------

/// Application Updated and Application Opened must retain their original event names.
- (void)testExistingLifecycleEventNamesUnchanged
{
#if TARGET_OS_IOS
    // Seed guard flag so this looks like a returning launch with an updated build.
    [[NSUserDefaults standardUserDefaults] setObject:@"0.9" forKey:kFPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:kFPVersionKey];

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    // Application Updated should fire (different build stored vs. current).
    // We can't guarantee a build mismatch in the test bundle, so we just verify
    // Application Opened always fires and app_install does NOT.
    XCTAssertFalse([self capturedEventNamed:@"app_install"],
                   @"app_install must not fire on a returning launch");
    XCTAssertTrue([self capturedEventNamed:@"Application Opened"],
                  @"Application Opened must still fire on every launch");
    XCTAssertFalse([self capturedEventNamed:@"Application Installed"],
                   @"The old Application Installed event name must never fire");
#endif
}

@end
