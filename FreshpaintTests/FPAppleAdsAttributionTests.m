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
/// Interceptor called instead of the real SKAN API. Args: (conversionValue, apiVersion).
@property (atomic, copy, nullable) void (^fp_skanCallInterceptor)(NSInteger, NSString *);
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

- (void)setFp_skanCallInterceptor:(void (^)(NSInteger, NSString *))fp_skanCallInterceptor {
    objc_setAssociatedObject(self,
        @selector(fp_skanCallInterceptor),
        fp_skanCallInterceptor,
        OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(NSInteger, NSString *))fp_skanCallInterceptor {
    return objc_getAssociatedObject(self, @selector(fp_skanCallInterceptor));
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

/// Creates a fresh FPAnalytics instance with the current configuration and a new capture middleware.
/// Clears the install guard so the fresh-install path fires.
- (FPAnalytics *)freshAnalyticsWithCapture:(FPAppleAdsEventCapture **)outCapture
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_BuildKeyV2];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPAA_VersionKey];
    FPAppleAdsEventCapture *cap = [[FPAppleAdsEventCapture alloc] init];
    self.configuration.sourceMiddleware = @[ cap ];
    if (outCapture) *outCapture = cap;
    return [[FPAnalytics alloc] initWithConfiguration:self.configuration];
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
    XCTAssertEqual(self.configuration.skanConversionValue, 0,
        @"skanConversionValue default must be 0");

    __block BOOL skanCalled = NO;
    self.analytics.fp_skanVersionOverride = @4;
    self.analytics.fp_skanCallInterceptor = ^(NSInteger value, NSString *version) {
        skanCalled = YES;
    };

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    XCTAssertFalse(skanCalled, @"SKAN must not be called when skanConversionValue is 0");
    FPTrackPayload *install = [self capturedInstallPayload];
    XCTAssertNotNil(install, @"app_install must still fire when SKAN is skipped");
#endif
}

/// skanConversionValue < 0 → SKAN registration skipped.
- (void)testSKANSkippedWhenValueIsNegative
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = -1;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];

    __block BOOL skanCalled = NO;
    analytics2.fp_skanCallInterceptor = ^(NSInteger value, NSString *version) {
        skanCalled = YES;
    };

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"Negative skanConversionValue must not crash");
    XCTAssertFalse(skanCalled, @"SKAN must not be called when skanConversionValue is negative");
    analytics2 = nil;
#endif
}

/// skanConversionValue > 63 → SKAN registration skipped (out of valid range).
- (void)testSKANSkippedWhenValueExceedsMaximum
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 64;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];

    __block BOOL skanCalled = NO;
    analytics2.fp_skanVersionOverride = @4;
    analytics2.fp_skanCallInterceptor = ^(NSInteger value, NSString *version) {
        skanCalled = YES;
    };

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"skanConversionValue > 63 must not crash");
    XCTAssertFalse(skanCalled, @"SKAN must not be called when skanConversionValue > 63");
    analytics2 = nil;
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-7, AC-8: SKAN v4 on iOS 16.1+
// ---------------------------------------------------------------------------

/// skanConversionValue > 0 with v4 override → SKAdNetwork v4 called with correct value.
- (void)testSKANv4CalledWithConfiguredValue
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 7;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];
    analytics2.fp_skanVersionOverride = @4;

    __block NSInteger capturedValue = -1;
    __block NSString *capturedVersion = nil;
    analytics2.fp_skanCallInterceptor = ^(NSInteger value, NSString *version) {
        capturedValue = value;
        capturedVersion = version;
    };

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"SKAN v4 registration must not crash when skanConversionValue > 0");
    XCTAssertEqual(capturedValue, 7, @"SKAN must receive the configured conversion value");
    XCTAssertEqualObjects(capturedVersion, @"v4", @"SKAN must use v4 API when override is @4");
    analytics2 = nil;
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - AC-9: SKAN v3 fallback
// ---------------------------------------------------------------------------

/// skanConversionValue > 0 with v3 override → SKAdNetwork v3 called with correct value.
- (void)testSKANv3FallbackCalledWithConfiguredValue
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 5;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];
    analytics2.fp_skanVersionOverride = @3;

    __block NSInteger capturedValue = -1;
    __block NSString *capturedVersion = nil;
    analytics2.fp_skanCallInterceptor = ^(NSInteger value, NSString *version) {
        capturedValue = value;
        capturedVersion = version;
    };

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"SKAN v3 registration must not crash when skanConversionValue > 0");
    XCTAssertEqual(capturedValue, 5, @"SKAN must receive the configured conversion value");
    XCTAssertEqualObjects(capturedVersion, @"v3", @"SKAN must use v3 API when override is @3");
    analytics2 = nil;
#endif
}

/// Exercises the real NSInvocation code path (no interceptor) to verify retainArguments
/// prevents dangling block pointers. SKAdNetwork may not be available in the test
/// environment, so this only asserts no crash -- the SKAN call silently no-ops when
/// the framework is absent.
- (void)testSKANRealInvocationPathNoCrash
{
#if TARGET_OS_IPHONE
    self.configuration.skanConversionValue = 10;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];
    analytics2.fp_skanVersionOverride = @4;
    // No interceptor -- exercises the real fp_skanInvocation + fp_skanSetCompletionHandler path.

    XCTAssertNoThrow([analytics2 _applicationDidFinishLaunchingWithOptions:nil],
        @"Real SKAN NSInvocation path must not crash");
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
    self.configuration.skanConversionValue = 5;
    FPAppleAdsEventCapture *cap = nil;
    FPAnalytics *analytics2 = [self freshAnalyticsWithCapture:&cap];
    analytics2.fp_appleAdsTokenProvider = ^NSString * { return @"some_token"; };

    [analytics2 _applicationDidFinishLaunchingWithOptions:nil];

    for (FPContext *ctx in cap.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]]) {
            XCTAssertNil(track.properties[@"skadnetwork_id"],
                @"skadnetwork_id must never appear in any event payload (event: %@)", track.event);
        }
    }
    analytics2 = nil;
#endif
}

@end
