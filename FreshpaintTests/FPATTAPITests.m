//
//  FPATTAPITests.m
//  FreshpaintTests
//
//  Tests for FPAnalytics ATT public API (AC 1, 3) and auto-request logic (AC 4–8).
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FPAnalytics.h"
#import "FPAnalyticsConfiguration.h"

// ---------------------------------------------------------------------------
#pragma mark - Test-only extension
// ---------------------------------------------------------------------------

/// Expose private instance properties and the auto-request helper for testing.
/// These are declared in FPAnalytics.m's private @interface — this category
/// lets tests access them without modifying the public header.
@interface FPAnalytics (FPATTTesting)
@property (nonatomic, copy, nullable) NSUInteger (^fp_attStatusProvider)(void);
@property (nonatomic, copy, nullable) void (^fp_attRequestInterceptor)(void(^_Nullable)(NSUInteger));
- (void)_handleDidBecomeActiveForATT;
@end

// ---------------------------------------------------------------------------
#pragma mark - ATT status constants
// ---------------------------------------------------------------------------

static const NSUInteger kATTNotDetermined = 0;
static const NSUInteger kATTRestricted    = 1;
static const NSUInteger kATTDenied        = 2;
static const NSUInteger kATTAuthorized    = 3;

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPATTAPITests : XCTestCase
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) FPAnalytics              *analytics;
@end

@implementation FPATTAPITests

- (void)setUp
{
    [super setUp];
    self.configuration = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    // application = nil so no UIApplication notifications are registered;
    // tests drive _handleDidBecomeActiveForATT directly.
    self.configuration.application = nil;
    self.analytics = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
}

- (void)tearDown
{
    self.analytics     = nil;
    self.configuration = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
#pragma mark - AC 4/5/6: Auto-request logic
// ---------------------------------------------------------------------------

/// AC 4 — When autoRequestATT=YES and status=notDetermined, the ATT prompt is triggered.
- (void)testAutoRequestCallsPromptWhenNotDetermined
{
#if TARGET_OS_IOS
    self.configuration.autoRequestATT = YES;
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    __block BOOL requestCalled = NO;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCalled = YES;
    };

    [self.analytics _handleDidBecomeActiveForATT];

    XCTAssertTrue(requestCalled, @"ATT prompt must be triggered when status is notDetermined");
#endif
}

/// AC 5 — When autoRequestATT=YES and status=restricted, no prompt is triggered.
- (void)testAutoRequestSkipsPromptWhenRestricted
{
#if TARGET_OS_IOS
    self.configuration.autoRequestATT = YES;
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTRestricted; };

    __block BOOL requestCalled = NO;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCalled = YES;
    };

    [self.analytics _handleDidBecomeActiveForATT];

    XCTAssertFalse(requestCalled, @"ATT prompt must NOT be triggered when status is restricted");
#endif
}

/// AC 5 — When autoRequestATT=YES and status=denied, no prompt is triggered.
- (void)testAutoRequestSkipsPromptWhenDenied
{
#if TARGET_OS_IOS
    self.configuration.autoRequestATT = YES;
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTDenied; };

    __block BOOL requestCalled = NO;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCalled = YES;
    };

    [self.analytics _handleDidBecomeActiveForATT];

    XCTAssertFalse(requestCalled, @"ATT prompt must NOT be triggered when status is denied");
#endif
}

/// AC 5 — When autoRequestATT=YES and status=authorized, no prompt is triggered.
- (void)testAutoRequestSkipsPromptWhenAuthorized
{
#if TARGET_OS_IOS
    self.configuration.autoRequestATT = YES;
    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    __block BOOL requestCalled = NO;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCalled = YES;
    };

    [self.analytics _handleDidBecomeActiveForATT];

    XCTAssertFalse(requestCalled, @"ATT prompt must NOT be triggered when status is authorized");
#endif
}

/// AC 6 — When autoRequestATT=NO (default), no prompt is triggered regardless of ATT status.
- (void)testAutoRequestDisabledByDefault
{
#if TARGET_OS_IOS
    // autoRequestATT defaults to NO — do not set it.
    XCTAssertFalse(self.configuration.autoRequestATT, @"autoRequestATT must default to NO");

    self.analytics.fp_attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    __block BOOL requestCalled = NO;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCalled = YES;
    };

    [self.analytics _handleDidBecomeActiveForATT];

    XCTAssertFalse(requestCalled, @"ATT prompt must NOT be triggered when autoRequestATT is NO");
#endif
}

/// AC 8 — Duplicate-prompt prevention: if status transitions to non-zero before the second
/// call, no second prompt is shown.
- (void)testDuplicatePromptPrevention
{
#if TARGET_OS_IOS
    self.configuration.autoRequestATT = YES;

    __block NSUInteger simulatedStatus = kATTNotDetermined;
    self.analytics.fp_attStatusProvider = ^NSUInteger { return simulatedStatus; };

    __block NSInteger requestCount = 0;
    self.analytics.fp_attRequestInterceptor = ^(void(^_Nullable completion)(NSUInteger)) {
        requestCount++;
        // After the first request, simulate the user granting authorization.
        simulatedStatus = kATTAuthorized;
    };

    // First didBecomeActive — status is notDetermined, prompt fires.
    [self.analytics _handleDidBecomeActiveForATT];
    XCTAssertEqual(requestCount, 1, @"Prompt must fire once on first didBecomeActive");

    // Second didBecomeActive — status is now authorized, no second prompt.
    [self.analytics _handleDidBecomeActiveForATT];
    XCTAssertEqual(requestCount, 1, @"Prompt must NOT fire again once status is determined");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC 1: +trackingAuthorizationStatus
// ---------------------------------------------------------------------------

/// AC 1 — +trackingAuthorizationStatus returns a valid ATT status value without crashing.
/// In the test environment the value will be 0 (notDetermined) on iOS Simulator,
/// or 0 on macOS/tvOS because of the TARGET_OS_IOS guard.
- (void)testTrackingAuthorizationStatusReturnsValidValue
{
    NSUInteger status = [FPAnalytics trackingAuthorizationStatus];
    XCTAssertTrue(status <= 3, @"trackingAuthorizationStatus must return a value in [0,3], got %lu", (unsigned long)status);
}

// ---------------------------------------------------------------------------
#pragma mark - AC 3: +advertisingIdentifier
// ---------------------------------------------------------------------------

/// AC 3 — +advertisingIdentifier returns nil when ATT is not authorized (status != 3).
/// In the standard test environment ATT status is 0, so this is always nil.
- (void)testAdvertisingIdentifierNilWhenNotAuthorized
{
#if TARGET_OS_IOS
    // Ensure status is not authorized by checking current status first.
    // On the Simulator (and in CI), ATT status is always notDetermined (0).
    if ([FPAnalytics trackingAuthorizationStatus] == kATTAuthorized) {
        XCTSkip(@"This test requires ATT status to be not authorized");
    }
    NSString *idfa = [FPAnalytics advertisingIdentifier];
    XCTAssertNil(idfa, @"advertisingIdentifier must return nil when ATT is not authorized");
#endif
}

/// AC 3 — +advertisingIdentifier does not crash when ATT is authorized.
/// Uses method swizzling to stub +trackingAuthorizationStatus to return 3.
/// When AdSupport is not linked in the test target the result is nil — that
/// is the expected safe fallback. The test verifies no crash and a valid return type.
- (void)testAdvertisingIdentifierDoesNotCrashWhenAuthorized
{
#if TARGET_OS_IOS
    Method origMethod = class_getClassMethod([FPAnalytics class],
                                             @selector(trackingAuthorizationStatus));
    Method stubMethod = class_getClassMethod([FPATTAPITests class],
                                             @selector(fp_stubbedTrackingAuthorizationStatusAuthorized));
    method_exchangeImplementations(origMethod, stubMethod);

    NSString *idfa = [FPAnalytics advertisingIdentifier];

    // Restore original implementation.
    method_exchangeImplementations(origMethod, stubMethod);

    // AdSupport is not linked in this test target, so idfa will be nil.
    // The invariant: must be nil or a valid UUID string — no crash.
    XCTAssertTrue(idfa == nil || idfa.length > 0,
                  @"advertisingIdentifier must return nil or a non-empty UUID string");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - Swizzle stub
// ---------------------------------------------------------------------------

/// Returns 3 (authorized) — used only as a swizzle target in tests.
+ (NSUInteger)fp_stubbedTrackingAuthorizationStatusAuthorized
{
    return kATTAuthorized;
}

@end
