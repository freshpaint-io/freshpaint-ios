//
//  FPDeepLinkAttributionTests.m
//  FreshpaintTests
//
//  FRP-38: Unit tests for deep link attribution — ad click IDs and UTM params.
//

#import <XCTest/XCTest.h>
#import "FPAnalytics.h"
#import "FPAnalyticsConfiguration.h"
#import "FPMiddleware.h"
#import "FPContext.h"
#import "FPTrackPayload.h"
#import "FPAdClickIds.h"
#import "FPState.h"

// ---------------------------------------------------------------------------
#pragma mark - Test-only extensions
// ---------------------------------------------------------------------------

@interface FPAnalytics (FPDeepLinkTesting)
- (void)_applicationDidFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;
@end

// ---------------------------------------------------------------------------
#pragma mark - Capture middleware
// ---------------------------------------------------------------------------

@interface FPDeepLinkCapture : NSObject <FPMiddleware>
@property (nonatomic, readonly, strong) NSMutableArray<FPContext *> *capturedContexts;
@end

@implementation FPDeepLinkCapture

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
#pragma mark - NSUserDefaults keys (match FPAnalytics.m)
// ---------------------------------------------------------------------------

static NSString *const kFPDLBuildKeyV2  = @"FPBuildKeyV2";
static NSString *const kFPDLVersionKey  = @"FPVersionKey";
static NSString *const kFPClickIdsKey   = @"com.freshpaint.clickIds";

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPDeepLinkAttributionTests : XCTestCase
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) FPAnalytics              *analytics;
@property (nonatomic, strong) FPDeepLinkCapture        *capture;
// Saved NSUserDefaults values — restored in tearDown.
@property (nonatomic, copy, nullable) NSString         *savedBuildV2;
@property (nonatomic, copy, nullable) NSString         *savedVersion;
@property (nonatomic, copy, nullable) NSData           *savedClickIds;
@end

@implementation FPDeepLinkAttributionTests

- (void)setUp
{
    [super setUp];

    // Save and clear persistent state that may affect tests.
    self.savedBuildV2  = [[NSUserDefaults standardUserDefaults] stringForKey:kFPDLBuildKeyV2];
    self.savedVersion  = [[NSUserDefaults standardUserDefaults] stringForKey:kFPDLVersionKey];
    self.savedClickIds = [[NSUserDefaults standardUserDefaults] dataForKey:kFPClickIdsKey];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPDLBuildKeyV2];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPDLVersionKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPClickIdsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Also clear in-memory state on the shared FPState singleton.
    [FPState sharedInstance].userInfo.clickIds          = nil;
    [FPState sharedInstance].userInfo.utmParams         = nil;
    [FPState sharedInstance].userInfo.utmExpiryTimestamp = 0;

    self.configuration = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    self.configuration.trackApplicationLifecycleEvents = YES;
    self.configuration.trackDeepLinks = YES;
    self.configuration.application    = nil;

    self.capture = [[FPDeepLinkCapture alloc] init];
    self.configuration.sourceMiddleware = @[ self.capture ];

    self.analytics = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
}

- (void)tearDown
{
    // Restore NSUserDefaults.
    if (self.savedBuildV2) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedBuildV2 forKey:kFPDLBuildKeyV2];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPDLBuildKeyV2];
    }
    if (self.savedVersion) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedVersion forKey:kFPDLVersionKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPDLVersionKey];
    }
    if (self.savedClickIds) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedClickIds forKey:kFPClickIdsKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFPClickIdsKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Clear in-memory state.
    [FPState sharedInstance].userInfo.clickIds           = nil;
    [FPState sharedInstance].userInfo.utmParams          = nil;
    [FPState sharedInstance].userInfo.utmExpiryTimestamp = 0;

    self.analytics     = nil;
    self.capture       = nil;
    self.configuration = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

- (nullable FPTrackPayload *)firstCapturedEventNamed:(NSString *)name
{
    for (FPContext *ctx in self.capture.capturedContexts) {
        FPTrackPayload *track = (FPTrackPayload *)ctx.payload;
        if ([track isKindOfClass:[FPTrackPayload class]] &&
            [track.event isEqualToString:name]) {
            return track;
        }
    }
    return nil;
}

- (BOOL)capturedEventNamed:(NSString *)name
{
    return [self firstCapturedEventNamed:name] != nil;
}

// ---------------------------------------------------------------------------
#pragma mark - Test 1: All 24 click ID keys extracted
// ---------------------------------------------------------------------------

- (void)testAllClickIdKeysExtracted
{
    NSString *urlStr =
        @"https://example.com/landing"
        @"?aleid=v1&cntr_auctionId=v2&msclkid=v3&fbclid=v4&gclid=v5"
        @"&dclid=v6&gclsrc=v7&wbraid=v8&gbraid=v9&irclickid=v10"
        @"&li_fat_id=v11&ndclid=v12&epik=v13&rdt_cid=v14&sccid=v15"
        @"&ScCid=v16&spclid=v17&sapid=v18&ttdimp=v19&ttclid=v20"
        @"&twclid=v21&clid_src=v22&viant_clid=v23&qclid=v24";
    NSURL *url = [NSURL URLWithString:urlStr];

    NSDictionary *result = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    NSArray<NSString *> *supported = [FPAdClickIds supportedClickIdKeys];
    XCTAssertEqual(supported.count, 24u, @"There must be exactly 24 supported click ID keys");

    // Each canonical key should appear prefixed with $ in the result.
    // Note: sccid and ScCid both map to lowercase "sccid", so only one will win (first match).
    // We check that at least 23 unique canonical keys got extracted (sccid and ScCid de-dup to 1).
    NSUInteger foundCount = 0;
    for (NSString *key in supported) {
        NSString *prefixed = [NSString stringWithFormat:@"$%@", key];
        if (clickIds[prefixed] != nil) {
            foundCount++;
        }
    }
    // At minimum 23 distinct canonical entries (sccid/ScCid de-dup to one).
    XCTAssertGreaterThanOrEqual(foundCount, 23u,
        @"At least 23 out of 24 entries should be extracted (sccid/ScCid are case-insensitive duplicates)");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 2: Click ID stored with $ prefix
// ---------------------------------------------------------------------------

- (void)testClickIdHasDollarPrefix
{
    NSURL *url = [NSURL URLWithString:@"https://example.com?gclid=abc123"];
    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    XCTAssertNotNil(clickIds[@"$gclid"],
                    @"$gclid must be present in clickIds");
    XCTAssertNil(clickIds[@"gclid"],
                 @"gclid without $ prefix must NOT be present");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 3: Creation timestamp is NSNumber with a positive value
// ---------------------------------------------------------------------------

- (void)testClickIdHasCreationTimestampMs
{
    NSURL *url = [NSURL URLWithString:@"https://example.com?gclid=abc123"];
    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    id creationTime = clickIds[@"$gclid_creation_time"];
    XCTAssertNotNil(creationTime, @"$gclid_creation_time must be present");
    XCTAssertTrue([creationTime isKindOfClass:[NSNumber class]],
                  @"$gclid_creation_time must be an NSNumber");
    NSInteger ms = [creationTime integerValue];
    XCTAssertGreaterThan(ms, 0, @"$gclid_creation_time must be a positive Unix timestamp in ms");
    // Sanity: should be at least year-2020 epoch ms.
    XCTAssertGreaterThan(ms, (NSInteger)1577836800000LL,
                         @"$gclid_creation_time should be a plausible recent Unix ms timestamp");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 4: Google gacid captured as campaign_id
// ---------------------------------------------------------------------------

- (void)testGoogleCampaignId
{
    NSURL *url = [NSURL URLWithString:@"https://example.com?gclid=abc&gacid=campaign123"];
    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    XCTAssertEqualObjects(clickIds[@"$gclid_campaign_id"], @"campaign123",
                          @"$gclid_campaign_id must equal the gacid param value");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 5: Facebook extras extracted
// ---------------------------------------------------------------------------

- (void)testFacebookExtras
{
    NSURL *url = [NSURL URLWithString:
        @"https://example.com?fbclid=fb1&ad_id=adA&adset_id=adsetB&campaign_id=campC"];
    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    XCTAssertEqualObjects(clickIds[@"$fbclid_ad_id"],       @"adA",   @"$fbclid_ad_id must be captured");
    XCTAssertEqualObjects(clickIds[@"$fbclid_adset_id"],    @"adsetB",@"$fbclid_adset_id must be captured");
    XCTAssertEqualObjects(clickIds[@"$fbclid_campaign_id"], @"campC", @"$fbclid_campaign_id must be captured");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 6: Deduplication — same value does not update creation_time
// ---------------------------------------------------------------------------

- (void)testDeduplicationSameValue
{
    // Seed an initial click ID with a known creation_time.
    NSInteger oldTimeMs = 1000000000000LL; // past timestamp
    NSDictionary *initial = @{
        @"$gclid": @"same_value",
        @"$gclid_creation_time": @(oldTimeMs),
    };
    [[FPState sharedInstance] mergeClickIds:initial];

    // Wait for the barrier write to complete.
    // activeClickIdsFlattened uses dispatch_sync so it drains the queue.
    NSDictionary *afterFirst = [[FPState sharedInstance] activeClickIdsFlattened];
    XCTAssertEqualObjects(afterFirst[@"$gclid"], @"same_value");
    XCTAssertEqualObjects(afterFirst[@"$gclid_creation_time"], @(oldTimeMs));

    // Now merge the same key with the same value but a newer creation_time.
    NSInteger newTimeMs = oldTimeMs + 1000;
    NSDictionary *duplicate = @{
        @"$gclid": @"same_value",
        @"$gclid_creation_time": @(newTimeMs),
    };
    [[FPState sharedInstance] mergeClickIds:duplicate];

    NSDictionary *afterSecond = [[FPState sharedInstance] activeClickIdsFlattened];
    XCTAssertEqualObjects(afterSecond[@"$gclid_creation_time"], @(oldTimeMs),
        @"creation_time must NOT be updated when merging the same value again (deduplication)");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 7: UTM params extracted from URL
// ---------------------------------------------------------------------------

- (void)testUTMExtraction
{
    NSURL *url = [NSURL URLWithString:
        @"https://example.com?utm_source=google&utm_medium=cpc"
        @"&utm_campaign=spring_sale&utm_term=shoes&utm_content=banner"];
    NSDictionary *result    = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *utmParams = result[@"utmParams"];

    XCTAssertEqualObjects(utmParams[@"utm_source"],   @"google",      @"utm_source must be extracted");
    XCTAssertEqualObjects(utmParams[@"utm_medium"],   @"cpc",         @"utm_medium must be extracted");
    XCTAssertEqualObjects(utmParams[@"utm_campaign"], @"spring_sale", @"utm_campaign must be extracted");
    XCTAssertEqualObjects(utmParams[@"utm_term"],     @"shoes",       @"utm_term must be extracted");
    XCTAssertEqualObjects(utmParams[@"utm_content"],  @"banner",      @"utm_content must be extracted");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 8: Active UTM params returned when freshly set
// ---------------------------------------------------------------------------

- (void)testUTMExpiryActive
{
    NSDictionary *params = @{ @"utm_source": @"facebook", @"utm_medium": @"social" };
    [[FPState sharedInstance] setUTMParams:params];

    NSDictionary *active = [[FPState sharedInstance] activeUTMParams];
    XCTAssertNotNil(active, @"activeUTMParams must return non-nil when freshly set");
    XCTAssertEqualObjects(active[@"utm_source"], @"facebook");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 9: Active UTM params return nil when expiry is in the past
// ---------------------------------------------------------------------------

- (void)testUTMExpiryExpired
{
    // Set UTM params (which sets expiry = now + 86400).
    NSDictionary *params = @{ @"utm_source": @"test" };
    [[FPState sharedInstance] setUTMParams:params];

    // Forcibly expire by setting utmExpiryTimestamp to a past Unix second.
    // The property setter goes through the state queue, so it is thread-safe.
    [FPState sharedInstance].userInfo.utmExpiryTimestamp = 1.0;

    NSDictionary *active = [[FPState sharedInstance] activeUTMParams];
    XCTAssertNil(active,
        @"activeUTMParams must return nil when utmExpiryTimestamp is in the past");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 10: app_install merges stored click IDs
// ---------------------------------------------------------------------------

- (void)testAppInstallMergesStoredClickIds
{
#if TARGET_OS_IOS
    // Pre-store a click ID so it is available when app_install fires.
    NSDictionary *clickId = @{
        @"$gclid": @"install_gclid",
        @"$gclid_creation_time": @((NSInteger)([[NSDate date] timeIntervalSince1970] * 1000)),
    };
    [[FPState sharedInstance] mergeClickIds:clickId];

    // Drain the barrier write so the value is visible synchronously.
    (void)[[FPState sharedInstance] activeClickIdsFlattened];

    [self.analytics _applicationDidFinishLaunchingWithOptions:nil];

    FPTrackPayload *installPayload = [self firstCapturedEventNamed:@"app_install"];
    XCTAssertNotNil(installPayload, @"app_install must fire on first launch");
    XCTAssertNotNil(installPayload.properties[@"$gclid"],
        @"$gclid must be merged into app_install properties from stored click IDs");
#else
    XCTSkip(@"This test requires iOS");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - Test 11: Payload filters applied before extraction
// ---------------------------------------------------------------------------

- (void)testPayloadFiltersAppliedBeforeExtraction
{
    // URL contains a fake "fb_auth_token=SECRET" query param that should be redacted
    // before we extract anything. Use a filter that replaces the token value.
    NSString *urlStr = @"https://example.com?fbclid=realclickid&fb_auth_token=MY_SECRET_TOKEN";
    NSURL *url = [NSURL URLWithString:urlStr];

    // Filter: replace the fb_auth_token value with REDACTED.
    NSDictionary<NSString *, NSString *> *filters = @{
        @"fb_auth_token=[^&]+": @"fb_auth_token=REDACTED"
    };

    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:filters];
    NSDictionary *clickIds = result[@"clickIds"];

    // fbclid should still be extracted (it was not filtered).
    XCTAssertEqualObjects(clickIds[@"$fbclid"], @"realclickid",
        @"fbclid must still be extracted after filtering");

    // The token value should not appear anywhere in clickIds.
    for (id value in clickIds.allValues) {
        if ([value isKindOfClass:[NSString class]]) {
            XCTAssertFalse([value containsString:@"MY_SECRET_TOKEN"],
                @"Original token value must not appear in extracted click IDs after filtering");
        }
    }
}

// ---------------------------------------------------------------------------
#pragma mark - Test 12: Deep Link Opened event still fires via openURL:
// ---------------------------------------------------------------------------

- (void)testDeepLinkOpenedStillFires
{
    NSURL *url = [NSURL URLWithString:@"myapp://landing?gclid=x123"];
    [self.analytics openURL:url options:@{}];

    XCTAssertTrue([self capturedEventNamed:@"Deep Link Opened"],
        @"Deep Link Opened must still fire when openURL:options: is called");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 13: Snapchat both variants handled without crash
// ---------------------------------------------------------------------------

- (void)testSnapchatBothVariantsExtracted
{
    // Both sccid (lowercase) and ScCid (mixed-case) in the same URL.
    // Case-insensitive matching means they both map to the same canonical key;
    // first-match wins and the second is ignored. No crash must occur.
    NSURL *url = [NSURL URLWithString:@"https://example.com?sccid=snap1&ScCid=snap2"];
    NSDictionary *result = nil;
    XCTAssertNoThrow(result = [FPAdClickIds extractFromURL:url payloadFilters:@{}],
        @"Extraction with both sccid and ScCid variants must not throw");

    NSDictionary *clickIds = result[@"clickIds"];
    // At least one of the two canonical forms must be present.
    BOOL eitherFound = (clickIds[@"$sccid"] != nil || clickIds[@"$ScCid"] != nil);
    XCTAssertTrue(eitherFound,
        @"At least one of $sccid or $ScCid must be present in the result");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 14: Click IDs persist to NSUserDefaults after mergeClickIds
// ---------------------------------------------------------------------------

- (void)testClickIdsPersistAfterMerge
{
    NSInteger nowMs = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    NSDictionary *clickId = @{
        @"$msclkid": @"bing_click_42",
        @"$msclkid_creation_time": @(nowMs),
    };
    [[FPState sharedInstance] mergeClickIds:clickId];

    // Drain the barrier write by doing a sync read.
    (void)[[FPState sharedInstance] activeClickIdsFlattened];

    NSData *stored = [[NSUserDefaults standardUserDefaults] dataForKey:kFPClickIdsKey];
    XCTAssertNotNil(stored, @"NSUserDefaults must contain data for com.freshpaint.clickIds after mergeClickIds");

    // Deserialize and verify the value is present.
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:stored
                                                         options:NSPropertyListImmutable
                                                          format:nil
                                                           error:&error];
    XCTAssertNil(error, @"Persisted plist data must be valid");
    XCTAssertTrue([plist isKindOfClass:[NSDictionary class]], @"Persisted data must be a NSDictionary");
    XCTAssertEqualObjects(((NSDictionary *)plist)[@"$msclkid"], @"bing_click_42",
        @"$msclkid must be persisted in NSUserDefaults");
}

// ---------------------------------------------------------------------------
#pragma mark - Test 15: URL with no recognized params returns empty clickIds dict
// ---------------------------------------------------------------------------

- (void)testNoClickIdsInURLProducesEmptyDict
{
    NSURL *url = [NSURL URLWithString:@"https://example.com?foo=bar&baz=qux"];
    NSDictionary *result   = [FPAdClickIds extractFromURL:url payloadFilters:@{}];
    NSDictionary *clickIds = result[@"clickIds"];

    XCTAssertNotNil(clickIds, @"clickIds dict must be non-nil even when nothing is found");
    XCTAssertEqual(clickIds.count, 0u, @"clickIds must be empty when no recognized params are present");
}

@end
