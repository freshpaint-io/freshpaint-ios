//
//  FPAppInstallEventTests.m
//  FreshpaintTests
//
//  Unit tests for FRP-37: enhanced app_install lifecycle event with MMP attribution payload.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FPAnalytics.h"
#import "FPAnalyticsConfiguration.h"
#import "FPMiddleware.h"
#import "FPContext.h"
#import "FPTrackPayload.h"
#import "FPATTTestConstants.h"
#import "FPStableDeviceId.h"

// NSUserDefaults keys — defined in FPAnalytics.m, declared here for test access.
extern NSString *const FPVersionKey;
extern NSString *const FPBuildKeyV2;

// Expose NSUserDefaults test helpers from FPStableDeviceId.
@interface FPStableDeviceId (Testing)
+ (void)fp_resetUserDefaultsForTesting;
@end

// ---------------------------------------------------------------------------
#pragma mark - Test-only extensions
// ---------------------------------------------------------------------------

/// Exposes private lifecycle handlers and the ATT status injectable.
@interface FPAnalytics (FPInstallTesting)
@property (atomic, copy, nullable) NSUInteger (^fp_attStatusProvider)(void);
- (void)_applicationDidFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
- (void)fp_handleDelayedLaunch:(NSNotification *)note;
@end

@implementation FPAnalytics (FPInstallTesting)

- (void)setFp_attStatusProvider:(NSUInteger (^)(void))fp_attStatusProvider {
    objc_setAssociatedObject(self,
        @selector(fp_attStatusProvider),
        fp_attStatusProvider,
        OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSUInteger (^)(void))fp_attStatusProvider {
    return objc_getAssociatedObject(self, @selector(fp_attStatusProvider));
}

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
#pragma mark - Test IDFA fixtures
// ---------------------------------------------------------------------------

static NSString *const kFPValidIDFA  = @"12345678-1234-1234-1234-123456789ABC";
static NSString *const kFPZeroIDFA   = @"00000000-0000-0000-0000-000000000000";

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
    self.savedBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:FPBuildKeyV2];
    self.savedVersion = [[NSUserDefaults standardUserDefaults] stringForKey:FPVersionKey];

    // Simulate a fresh install by removing the guard flag.
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPVersionKey];

    // Start with no persistent device ID so each test gets a fresh UUID.
    [FPStableDeviceId fp_resetUserDefaultsForTesting];

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
        [[NSUserDefaults standardUserDefaults] setObject:self.savedBuildV2 forKey:FPBuildKeyV2];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPBuildKeyV2];
    }
    if (self.savedVersion) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedVersion forKey:FPVersionKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:FPVersionKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    [FPStableDeviceId fp_resetUserDefaultsForTesting];

    self.analytics     = nil;
    self.capture       = nil;
    self.configuration = nil;
    [super tearDown];
}

// Returns the first captured Application Installed track payload, or nil if absent.
- (nullable FPTrackPayload *)capturedInstallPayload
{
    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]] &&
            [track.event isEqualToString:@"Application Installed"]) {
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
#pragma mark - AC 1: Event name is Application Installed (AC #8: fires once on first install)
// ---------------------------------------------------------------------------

/// On the very first launch (FPBuildKeyV2 absent), Application Installed must be tracked.
- (void)testFiresAppInstallOnFirstLaunch
{
#if TARGET_OS_IOS
    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    XCTAssertTrue([self capturedEventNamed:@"Application Installed"],
                  @"Application Installed must fire when FPBuildKeyV2 is absent (first install)");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 8 (returning device): fires exactly once per install
// ---------------------------------------------------------------------------

/// On a returning launch (FPBuildKeyV2 already present), Application Installed must NOT fire.
- (void)testDoesNotFireOnReturningDevice
{
#if TARGET_OS_IOS
    // Seed the guard flag to simulate a returning user.
    [[NSUserDefaults standardUserDefaults] setObject:@"1.0" forKey:FPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:FPVersionKey];

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    XCTAssertFalse([self capturedEventNamed:@"Application Installed"],
                   @"Application Installed must NOT fire when FPBuildKeyV2 is already set");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 2/3/4/5/7: Payload field validation
// ---------------------------------------------------------------------------

/// install_timestamp, device_id, idfv, att_status, os_version, and version
/// must all be present and non-empty in the Application Installed payload.
- (void)testPayloadContainsRequiredFields
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"Application Installed payload must be captured");

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

    // device_id — must equal the analytics anonymousId
    NSString *deviceId = props[@"device_id"];
    XCTAssertNotNil(deviceId, @"device_id must be present");
    XCTAssertEqualObjects(deviceId, [self.analytics getAnonymousId],
                          @"device_id must equal the SDK anonymousId");

    // persistent_device_id — must be present and a valid UUID
    NSString *persistentDeviceId = props[@"persistent_device_id"];
    XCTAssertNotNil(persistentDeviceId, @"persistent_device_id must be present");
    XCTAssertNotNil([[NSUUID alloc] initWithUUIDString:persistentDeviceId],
                    @"persistent_device_id must be a valid UUID, got: %@", persistentDeviceId);

    // device_id and persistent_device_id must be independent values
    XCTAssertNotEqualObjects(deviceId, persistentDeviceId,
                             @"device_id and persistent_device_id must be different values");

    // idfv — non-empty string (or empty string on simulators without IDFV)
    XCTAssertNotNil(props[@"idfv"], @"idfv key must be present");

    // att_status — always present
    XCTAssertNotNil(props[@"att_status"], @"att_status must be present");
    XCTAssertGreaterThan(((NSString *)props[@"att_status"]).length, 0u);

    // os_version — non-empty
    NSString *osVersion = props[@"os_version"];
    XCTAssertNotNil(osVersion, @"os_version must be present");
    XCTAssertGreaterThan(osVersion.length, 0u);

    // version — non-nil (may be empty in test bundle)
    XCTAssertNotNil(props[@"version"], @"version key must be present");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 6: idfa conditional on ATT authorization
// ---------------------------------------------------------------------------

/// idfa must appear in the payload when ATT is authorized and adSupportBlock is set.
- (void)testIDFAIncludedWhenATTAuthorized
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTAuthorized; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPValidIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"Application Installed payload must be captured");
    XCTAssertEqualObjects(payload.properties[@"idfa"], kFPValidIDFA,
                          @"idfa must be present and match when ATT is authorized");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

/// idfa must NOT appear when ATT is not authorized (denied).
- (void)testIDFAAbsentWhenATTNotAuthorized
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTDenied; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPValidIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"Application Installed payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when ATT status is not authorized");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

/// idfa must NOT appear when ATT is authorized but adSupportBlock is nil.
- (void)testIDFAAbsentWhenAdSupportBlockNil
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTAuthorized; };
    // adSupportBlock intentionally not set — remains nil

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"Application Installed payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when adSupportBlock is nil even if ATT is authorized");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

/// idfa must NOT appear when ATT is authorized but adSupportBlock returns zeroed IDFA.
- (void)testIDFAAbsentWhenZeroedIDFA
{
#if TARGET_OS_IOS
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTAuthorized; };
    self.configuration.adSupportBlock   = ^NSString *{ return kFPZeroIDFA; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *payload = [self capturedInstallPayload];
    XCTAssertNotNil(payload, @"Application Installed payload must be captured");
    XCTAssertNil(payload.properties[@"idfa"],
                 @"idfa must be absent when adSupportBlock returns all-zeros IDFA");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 9: Flag set after enqueue, not after flush
// ---------------------------------------------------------------------------

/// FPBuildKeyV2 must be written synchronously after the Application Installed event is
/// enqueued — without waiting for a flush call.
- (void)testFlagSetAfterEnqueue
{
#if TARGET_OS_IOS
    // Guard: key must be absent before the call.
    XCTAssertNil([[NSUserDefaults standardUserDefaults] stringForKey:FPBuildKeyV2],
                 @"Pre-condition: FPBuildKeyV2 must be nil before first launch");

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    // No flush called — flag must already be set.
    NSString *storedBuild = [[NSUserDefaults standardUserDefaults] stringForKey:FPBuildKeyV2];
    XCTAssertNotNil(storedBuild,
                    @"FPBuildKeyV2 must be written immediately after Application Installed is enqueued, not deferred to flush");
#else
    XCTSkip(@"This test requires iOS");
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
    [[NSUserDefaults standardUserDefaults] setObject:@"0.9" forKey:FPBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:FPVersionKey];

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    // Application Updated should fire (different build stored vs. current).
    // We can't guarantee a build mismatch in the test bundle, so we just verify
    // Application Opened always fires and Application Installed does NOT on a returning launch.
    XCTAssertFalse([self capturedEventNamed:@"Application Installed"],
                   @"Application Installed must not fire on a returning launch");
    XCTAssertTrue([self capturedEventNamed:@"Application Opened"],
                  @"Application Opened must still fire on every launch");
    XCTAssertFalse([self capturedEventNamed:@"app_install"],
                   @"app_install must never fire — event name is Application Installed");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - autoTrackFirstOpen independent of trackApplicationLifecycleEvents
// ---------------------------------------------------------------------------

/// Application Installed must fire even when trackApplicationLifecycleEvents is NO,
/// as long as autoTrackFirstOpen is YES (the default). This is the primary
/// production path: clients who only want MMP attribution need not opt into
/// the full lifecycle event suite.
- (void)testAppInstallFiresWithoutLifecycleEventsEnabled
{
#if TARGET_OS_IOS
    // Build a fresh analytics instance with lifecycle events explicitly disabled
    // but autoTrackFirstOpen left at its default (YES).
    FPAnalyticsConfiguration *cfg = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    cfg.trackApplicationLifecycleEvents = NO;
    // autoTrackFirstOpen defaults to YES — not set here to verify the default.
    cfg.application = nil;

    FPInstallEventCapture *localCapture = [[FPInstallEventCapture alloc] init];
    cfg.sourceMiddleware = @[ localCapture ];

    FPAnalytics *analytics = [[FPAnalytics alloc] initWithConfiguration:cfg];

    [analytics _applicationDidFinishLaunchingWithOptions:nil];

    BOOL foundInstall = NO;
    BOOL foundOpened  = NO;
    for (FPContext *ctx in localCapture.capturedContexts) {
        FPTrackPayload *t = (FPTrackPayload *)ctx.payload;
        if (![t isKindOfClass:[FPTrackPayload class]]) continue;
        if ([t.event isEqualToString:@"Application Installed"]) foundInstall = YES;
        if ([t.event isEqualToString:@"Application Opened"])    foundOpened  = YES;
    }

    XCTAssertTrue(foundInstall,
                  @"Application Installed must fire when autoTrackFirstOpen is YES even if "
                  @"trackApplicationLifecycleEvents is NO");
    XCTAssertFalse(foundOpened,
                   @"Application Opened must NOT fire when trackApplicationLifecycleEvents is NO");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

/// When autoTrackFirstOpen is explicitly set to NO, Application Installed must not fire
/// even on a fresh install.
- (void)testAppInstallDoesNotFireWhenAutoTrackFirstOpenDisabled
{
#if TARGET_OS_IOS
    FPAnalyticsConfiguration *cfg = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    cfg.trackApplicationLifecycleEvents = NO;
    cfg.autoTrackFirstOpen = NO;
    cfg.application = nil;

    FPInstallEventCapture *localCapture = [[FPInstallEventCapture alloc] init];
    cfg.sourceMiddleware = @[ localCapture ];

    FPAnalytics *analytics = [[FPAnalytics alloc] initWithConfiguration:cfg];

    [analytics _applicationDidFinishLaunchingWithOptions:nil];

    BOOL foundInstall = NO;
    for (FPContext *ctx in localCapture.capturedContexts) {
        FPTrackPayload *t = (FPTrackPayload *)ctx.payload;
        if ([t isKindOfClass:[FPTrackPayload class]] &&
            [t.event isEqualToString:@"Application Installed"]) {
            foundInstall = YES;
        }
    }

    XCTAssertFalse(foundInstall,
                   @"Application Installed must NOT fire when autoTrackFirstOpen is explicitly NO");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - iOS 26 deferred launch path (fp_handleDelayedLaunch:)
// ---------------------------------------------------------------------------

/// Simulates the iOS 26 SwiftUI cold-start path: configuration.application is nil
/// so initWithConfiguration: cannot call _applicationDidFinishLaunchingWithOptions:
/// directly. fp_handleDelayedLaunch: is the deferred handler that UIKit would invoke
/// via UISceneDidActivateNotification; calling it directly here tests the full code
/// path without relying on the xctest process scene lifecycle.
- (void)testAppInstallFiresViaDelayedLaunchHandler
{
#if TARGET_OS_IOS
    // setUp already created self.analytics with application=nil. Invoke the deferred
    // handler as UIKit would — with a UISceneDidActivateNotification carrying nil object.
    NSNotification *sceneNote = [NSNotification notificationWithName:UISceneDidActivateNotification
                                                               object:nil];
    [self.analytics fp_handleDelayedLaunch:sceneNote];

    XCTAssertTrue([self capturedEventNamed:@"Application Installed"],
                  @"Application Installed must fire when fp_handleDelayedLaunch: is called after "
                  @"a nil-application init (iOS 26 SwiftUI path)");

    // Call the handler a second time to verify launchHandlerFired prevents double-firing.
    [self.analytics fp_handleDelayedLaunch:sceneNote];

    NSUInteger installCount = 0;
    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *t = (FPTrackPayload *)ctx.payload;
        if ([t isKindOfClass:[FPTrackPayload class]] &&
            [t.event isEqualToString:@"Application Installed"]) {
            installCount++;
        }
    }
    XCTAssertEqual(installCount, 1u,
                   @"Application Installed must fire exactly once — launchHandlerFired must "
                   @"prevent a second fire on repeated handler invocations");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

@end
