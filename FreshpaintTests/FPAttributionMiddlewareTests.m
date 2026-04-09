//
//  FPAttributionMiddlewareTests.m
//  FreshpaintTests
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "FPAttributionMiddleware+Testing.h"
#import "FPAnalyticsConfiguration.h"
#import "FPAnalytics.h"
#import "FPContext.h"
#import "FPTrackPayload.h"
#import "FPIdentifyPayload.h"
#import "FPPayload.h"
#import "FPATTTestConstants.h"

// ---------------------------------------------------------------------------
#pragma mark - Test seam implementation
// ---------------------------------------------------------------------------

/// Backs FPAttributionMiddleware (FPTesting) with associated objects so no ivar
/// storage is added to the production class. The selector string used as key must
/// match the one used in FPAttributionMiddleware.m's currentATTStatus.
@implementation FPAttributionMiddleware (FPTesting)

- (void)setAttStatusProvider:(NSUInteger (^)(void))attStatusProvider {
    objc_setAssociatedObject(self,
        @selector(attStatusProvider),
        attStatusProvider,
        OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSUInteger (^)(void))attStatusProvider {
    return objc_getAssociatedObject(self, @selector(attStatusProvider));
}

@end

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

static NSString *const kValidIDFA        = @"12345678-1234-1234-1234-123456789ABC";
static NSString *const kZeroedIDFA       = @"00000000-0000-0000-0000-000000000000";

// ---------------------------------------------------------------------------
#pragma mark - Test class
// ---------------------------------------------------------------------------

@interface FPAttributionMiddlewareTests : XCTestCase
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@property (nonatomic, strong) FPAnalytics              *analytics;
@end

@implementation FPAttributionMiddlewareTests

- (void)setUp
{
    [super setUp];
    self.configuration = [FPAnalyticsConfiguration configurationWithWriteKey:@"TEST_WRITE_KEY"];
    self.analytics     = [[FPAnalytics alloc] initWithConfiguration:self.configuration];
}

- (void)tearDown
{
    self.analytics     = nil;
    self.configuration = nil;
    [super tearDown];
}

// Builds a context wrapping a simple track payload.
- (FPContext *)makeContextWithPayload:(FPPayload *)payload
{
    return [[[FPContext alloc] initWithAnalytics:self.analytics] modify:^(id<FPMutableContext> ctx) {
        ctx.eventType = FPEventTypeTrack;
        ctx.payload   = payload;
    }];
}

- (FPTrackPayload *)makeTrackPayload
{
    return [[FPTrackPayload alloc] initWithEvent:@"Test Event"
                                      properties:nil
                                         context:@{}
                                    integrations:@{}];
}

// Runs the middleware synchronously and returns the context passed to next.
- (FPContext *)runMiddleware:(FPAttributionMiddleware *)middleware
                 withContext:(FPContext *)context
{
    __block FPContext *captured = nil;
    [middleware context:context next:^(FPContext *newCtx) {
        captured = newCtx;
    }];
    return captured;
}

// ---------------------------------------------------------------------------
#pragma mark - ATT status string mapping (AC #10)
// ---------------------------------------------------------------------------

- (void)testATTStatusStringNotDetermined
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
#if TARGET_OS_IPHONE
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"att_status"], @"notDetermined");
#else
    XCTAssertNotNil(result, @"next should always be called");
#endif
}

- (void)testATTStatusStringRestricted
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTRestricted; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
#if TARGET_OS_IPHONE
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"att_status"], @"restricted");
#else
    XCTAssertNotNil(result);
#endif
}

- (void)testATTStatusStringDenied
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTDenied; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
#if TARGET_OS_IPHONE
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"att_status"], @"denied");
#else
    XCTAssertNotNil(result);
#endif
}

- (void)testATTStatusStringAuthorized
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
#if TARGET_OS_IPHONE
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"att_status"], @"authorized");
#else
    XCTAssertNotNil(result);
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - att_status present on every event (AC #2)
// ---------------------------------------------------------------------------

- (void)testAttStatusEnrichedOnTrackEvent
{
#if TARGET_OS_IPHONE
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNotNil(device[@"att_status"], @"att_status must be present on every event");
#endif
}

- (void)testAttStatusEnrichedOnIdentifyEvent
{
#if TARGET_OS_IPHONE
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTDenied; };

    FPIdentifyPayload *payload = [[FPIdentifyPayload alloc] initWithUserId:@"u1"
                                                                anonymousId:nil
                                                                     traits:@{}
                                                                    context:@{}
                                                               integrations:@{}];
    FPContext *ctx = [[[FPContext alloc] initWithAnalytics:self.analytics] modify:^(id<FPMutableContext> c) {
        c.eventType = FPEventTypeIdentify;
        c.payload   = payload;
    }];
    FPContext *result = [self runMiddleware:mw withContext:ctx];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"att_status"], @"denied");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - IDFA behavior (AC #3, #4, #11)
// ---------------------------------------------------------------------------

- (void)testIDFAPresentWhenAuthorizedWithValidAdSupportBlock
{
#if TARGET_OS_IPHONE
    self.configuration.adSupportBlock = ^NSString *{ return kValidIDFA; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"idfa"], kValidIDFA, @"IDFA must be present when authorized");
#endif
}

- (void)testIDFAAbsentWhenAuthorizedButAdSupportBlockIsNil
{
#if TARGET_OS_IPHONE
    // adSupportBlock is nil by default
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"IDFA must not appear without adSupportBlock");
#endif
}

- (void)testIDFAAbsentWhenAuthorizedButIDFAIsZeroed
{
#if TARGET_OS_IPHONE
    self.configuration.adSupportBlock = ^NSString *{ return kZeroedIDFA; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"Zeroed IDFA must not be set");
#endif
}

- (void)testIDFAAbsentWhenAuthorizedButAdSupportBlockReturnsNil
{
#if TARGET_OS_IPHONE
    // adSupportBlock is set but returns nil — must not crash or set idfa
    self.configuration.adSupportBlock = ^NSString *{ return nil; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTAuthorized; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"Nil IDFA from adSupportBlock must not be set");
#endif
}

- (void)testAdSupportBlockNeverCalledWhenDenied
{
#if TARGET_OS_IPHONE
    __block NSInteger callCount = 0;
    self.configuration.adSupportBlock = ^NSString *{
        callCount++;
        return kValidIDFA;
    };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTDenied; };

    [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    XCTAssertEqual(callCount, 0, @"adSupportBlock must not be called when denied");
#endif
}

- (void)testAdSupportBlockNeverCalledWhenRestricted
{
#if TARGET_OS_IPHONE
    __block NSInteger callCount = 0;
    self.configuration.adSupportBlock = ^NSString *{
        callCount++;
        return kValidIDFA;
    };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTRestricted; };

    [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    XCTAssertEqual(callCount, 0, @"adSupportBlock must not be called when restricted");
#endif
}

- (void)testAdSupportBlockNeverCalledWhenNotDetermined
{
#if TARGET_OS_IPHONE
    __block NSInteger callCount = 0;
    self.configuration.adSupportBlock = ^NSString *{
        callCount++;
        return kValidIDFA;
    };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    XCTAssertEqual(callCount, 0, @"adSupportBlock must not be called when notDetermined");
#endif
}

- (void)testIDFAAbsentForDenied
{
#if TARGET_OS_IPHONE
    self.configuration.adSupportBlock = ^NSString *{ return kValidIDFA; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTDenied; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"IDFA must be absent when denied");
#endif
}

- (void)testIDFAAbsentForRestricted
{
#if TARGET_OS_IPHONE
    self.configuration.adSupportBlock = ^NSString *{ return kValidIDFA; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTRestricted; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"IDFA must be absent when restricted");
#endif
}

- (void)testIDFAAbsentForNotDetermined
{
#if TARGET_OS_IPHONE
    self.configuration.adSupportBlock = ^NSString *{ return kValidIDFA; };
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:[self makeTrackPayload]]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertNil(device[@"idfa"], @"IDFA must be absent when notDetermined");
#endif
}

// ---------------------------------------------------------------------------
#pragma mark - next always called (AC #1 — middleware protocol)
// ---------------------------------------------------------------------------

- (void)testNextCalledWhenPayloadIsPresent
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    __block BOOL nextCalled = NO;
    FPContext *ctx = [self makeContextWithPayload:[self makeTrackPayload]];
    [mw context:ctx next:^(FPContext *newCtx) {
        nextCalled = YES;
    }];
    XCTAssertTrue(nextCalled, @"next must always be called");
}

- (void)testNextCalledWhenPayloadIsNil
{
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    // Lifecycle events (flush, reset) can have a nil payload.
    FPContext *ctx = [[[FPContext alloc] initWithAnalytics:self.analytics] modify:^(id<FPMutableContext> c) {
        c.eventType = FPEventTypeFlush;
        c.payload   = nil;
    }];

    __block BOOL nextCalled = NO;
    [mw context:ctx next:^(FPContext *newCtx) {
        nextCalled = YES;
    }];
    XCTAssertTrue(nextCalled, @"next must be called even when payload is nil");
}

// ---------------------------------------------------------------------------
#pragma mark - Existing device fields preserved (AC #5 — IDFV not clobbered)
// ---------------------------------------------------------------------------

- (void)testExistingDeviceFieldsPreserved
{
#if TARGET_OS_IPHONE
    // Explicitly seed an idfv in the payload context so the test does not rely
    // on FPState having it populated in a test environment.
    FPAttributionMiddleware *mw = [[FPAttributionMiddleware alloc] initWithConfiguration:self.configuration];
    mw.attStatusProvider = ^NSUInteger { return kATTNotDetermined; };

    FPTrackPayload *payload = [[FPTrackPayload alloc] initWithEvent:@"Test Event"
                                                         properties:nil
                                                            context:@{@"device": @{@"idfv": @"FAKE-IDFV-1234"}}
                                                       integrations:@{}];
    FPContext *result = [self runMiddleware:mw withContext:[self makeContextWithPayload:payload]];
    NSDictionary *device = result.payload.context[@"device"];
    XCTAssertEqualObjects(device[@"idfv"], @"FAKE-IDFV-1234", @"idfv must not be clobbered by attribution middleware");
#endif
}

@end
