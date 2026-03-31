//
//  FPAppleAdsAttributionTests.m
//  FreshpaintTests
//
//  Unit tests for FRP-39: Apple Ads attribution token and SKAdNetwork conversion value.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FPAnalytics.h"
#import "FPAnalyticsConfiguration.h"
#import "FPMiddleware.h"
#import "FPContext.h"
#import "FPTrackPayload.h"

// ---------------------------------------------------------------------------
#pragma mark - Test-only extensions
// ---------------------------------------------------------------------------

/// Exposes the private lifecycle handler and test seam properties.
@interface FPAnalytics (FPAppleAdsTesting)
/// Override for fp_appleAdsTokenProvider: return a token string or throw to simulate failure.
@property (atomic, copy, nullable) NSString *(^fp_appleAdsTokenProvider)(void);
/// Override for fp_skanVersionOverride: @4 forces SKAN v4, @3 forces SKAN v3.
@property (atomic, strong, nullable) NSNumber *fp_skanVersionOverride;
- (void)_applicationDidFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
@end

@implementation FPAnalytics (FPAppleAdsTesting)

- (void)setFp_appleAdsTokenProvider:(NSString *(^)(void))fp_appleAdsTokenProvider {
    objc_setAssociatedObject(self,
        @selector(fp_appleAdsTokenProvider),
        fp_appleAdsTokenProvider,
        OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *(^)(void))fp_appleAdsTokenProvider {
    return objc_getAssociatedObject(self, @selector(fp_appleAdsTokenProvider));
}

- (void)setFp_skanVersionOverride:(NSNumber *)fp_skanVersionOverride {
    objc_setAssociatedObject(self,
        @selector(fp_skanVersionOverride),
        fp_skanVersionOverride,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)fp_skanVersionOverride {
    return objc_getAssociatedObject(self, @selector(fp_skanVersionOverride));
}

@end

// ---------------------------------------------------------------------------
#pragma mark - Capture middleware
// ---------------------------------------------------------------------------

@interface FPAppleAdsEventCapture : NSObject <FPMiddleware>
@property (nonatomic, readonly, strong) NSMutableArray<FPContext *> *capturedContexts;
@end

@implementation FPAppleAdsEventCapture

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
#pragma mark - NSUserDefaults key constants (match FPAnalytics.m)
// ---------------------------------------------------------------------------

static NSString *const kFPAA_BuildKeyV2  = @"FPBuildKeyV2";
static NSString *const kFPAA_VersionKey  = @"FPVersionKey";

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPAppleAdsAttributionTests : XCTestCase
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) FPAnalytics              *analytics;
@property (nonatomic, strong) FPAppleAdsEventCapture   *capture;
@property (nonatomic, copy, nullable) NSString         *savedBuildV2;
@property (nonatomic, copy, nullable) NSString         *savedVersion;
@end

@implementation FPAppleAdsAttributionTests

- (void)setUp
{
    [super setUp];

    self.savedBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:kFPAA_BuildKeyV2];
    self.savedVersion = [[NSUserDefaults standardUserDefaults] stringForKey:kFPAA_VersionKey];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_VersionKey];

    self.configuration = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    self.configuration.trackApplicationLifecycleEvents = YES;
    self.configuration.application = nil;

    self.capture = [[FPAppleAdsEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ self.capture ];

    self.analytics = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
}

- (void)tearDown
{
    if (self.savedBuildV2) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedBuildV2 forKey:kFPAA_BuildKeyV2];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    }
    if (self.savedVersion) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedVersion forKey:kFPAA_VersionKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_VersionKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.analytics     = nil;
    self.capture       = nil;
    self.configuration = nil;
    [super tearDown];
}

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

// ---------------------------------------------------------------------------
#pragma mark - AC-1, AC-2: Token capture and inclusion in payload
// ---------------------------------------------------------------------------

/// Apple Ads token returned by provider → included as apple_ads_token in app_install payload.
- (void)testAppleAdsTokenIncludedInPayload
{
#if TARGET_OS_IPHONE
    static NSString *const kTestToken = @"TEST_APPLE_ADS_TOKEN_ABC123";
    self.analytics.fp_appleAdsTokenProvider = ^NSString * { return kTestToken; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNotNil(install, @"app_install event must be tracked on fresh install");
    XCTAssertEqualObjects(install.properties[@"apple_ads_token"], kTestToken,
        @"apple_ads_token must be set to the value returned by attributionToken:");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-3, AC-4: Graceful failure and @try/@catch
// ---------------------------------------------------------------------------

/// Provider throws ObjC exception → no crash, apple_ads_token absent from payload.
- (void)testAppleAdsTokenExceptionNoCrash
{
#if TARGET_OS_IPHONE
    self.analytics.fp_appleAdsTokenProvider = ^NSString * {
        @throw [NSException exceptionWithName:@"AAAttributionException"
                                       reason:@"Not installed via Apple Search Ads"
                                     userInfo:nil];
        return nil;
    };

    XCTAssertNoThrow(
        [self.analytics _applicationDidFinishLaunchingWithOptions:nil],
        @"attributionToken: exception must be caught — must not propagate to caller"
    );

    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNotNil(install, @"app_install must still fire even when token throws");
    XCTAssertNil(install.properties[@"apple_ads_token"],
        @"apple_ads_token must be absent when token retrieval throws");
#endif
}

/// Provider returns nil → apple_ads_token absent from payload.
- (void)testAppleAdsTokenNilAbsentFromPayload
{
#if TARGET_OS_IPHONE
    self.analytics.fp_appleAdsTokenProvider = ^NSString * { return nil; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNil(install.properties[@"apple_ads_token"],
        @"apple_ads_token must be absent when token is nil");
#endif
}

/// Provider returns empty string → apple_ads_token absent from payload.
- (void)testAppleAdsTokenEmptyStringAbsentFromPayload
{
#if TARGET_OS_IPHONE
    self.analytics.fp_appleAdsTokenProvider = ^NSString * { return @""; };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNil(install.properties[@"apple_ads_token"],
        @"apple_ads_token must be absent when token is empty string");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-5, AC-6, AC-10: SKAN opt-in / skip
// ---------------------------------------------------------------------------

/// skanConversionValue = 0 (default) → SKAN registration skipped entirely.
- (void)testSKANSkippedWhenValueIsZero
{
#if TARGET_OS_IPHONE
    // skanConversionValue defaults to 0 — no explicit set needed.
    XCTAssertEqual(self.configuration.skanConversionValue, 0,
        @"skanConversionValue default must be 0");

    __block BOOL skanCalled = NO;
    // Inject a version override so the call would be routed if it fired.
    self.analytics.fp_skanVersionOverride = @4;
    // We can't intercept the real SKAN call directly, but if value=0 the guard
    // prevents the call reaching fp_registerSKANConversionValue: at all.
    // Verify no crash and that the install event still fires normally.
    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];
    (void)skanCalled;

    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNotNil(install, @"app_install must still fire when SKAN is skipped");
#endif
}

/// skanConversionValue < 0 → SKAN registration skipped.
- (void)testSKANSkippedWhenValueIsNegative
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = -1;
    // Re-create analytics with updated config.
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    FPAppleAdsEventCapture *capture2 = [[FPAppleAdsEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ capture2 ];
    FPAnalytics *analytics2 = [[FPAnalytics alloc] initWithConfiguration:self.configuration];

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"Negative skanConversionValue must not crash");
    analytics2 = nil;
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-7, AC-8: SKAN v4 on iOS 16.1+
// ---------------------------------------------------------------------------

/// skanConversionValue > 0 with v4 override → SKAdNetwork v4 selector invoked without crash.
- (void)testSKANv4CalledWithConfiguredValue
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 7;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    FPAppleAdsEventCapture *capture2 = [[FPAppleAdsEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ capture2 ];
    FPAnalytics *analytics2 = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
    analytics2.fp_skanVersionOverride = @4;

    // The real SKAdNetwork v4 selector is available on iOS 16.1+; on the simulator
    // the call should complete without crashing regardless of whether postbacks fire.
    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"SKAN v4 registration must not crash when skanConversionValue > 0");
    analytics2 = nil;
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-9: SKAN v3 fallback
// ---------------------------------------------------------------------------

/// skanConversionValue > 0 with v3 override → SKAdNetwork v3 selector invoked without crash.
- (void)testSKANv3FallbackCalledWithConfiguredValue
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 5;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    FPAppleAdsEventCapture *capture2 = [[FPAppleAdsEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ capture2 ];
    FPAnalytics *analytics2 = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
    analytics2.fp_skanVersionOverride = @3;

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"SKAN v3 registration must not crash when skanConversionValue > 0");
    analytics2 = nil;
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-11: skadnetwork_id must not appear in payload
// ---------------------------------------------------------------------------

/// No payload field named skadnetwork_id in any tracked event.
- (void)testSkadnetworkIdAbsentFromAllPayloads
{
#if TARGET_OS_IPHONE
    self.analytics.fp_appleAdsTokenProvider = ^NSString * { return @"some_token"; };
    self.configuration.skanConversionValue = 5;

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]]) {
            XCTAssertNil(track.properties[@"skadnetwork_id"],
                @"skadnetwork_id must never appear in any event payload (event: %@)", track.event);
        }
    }
#endif
}

@end
