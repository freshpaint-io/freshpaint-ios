//
//  FPAttributionMiddleware.m
//  Freshpaint
//

#import "FPAttributionMiddleware.h"
#import "FPContext.h"
#import "FPPayload.h"
#import "FPPayload+FPAttributionEnrichment.h"
#import "FPATTRuntime.h"
#import <objc/runtime.h>

static NSString *const kFPAllZerosIDFA = @"00000000-0000-0000-0000-000000000000";

@interface FPAttributionMiddleware ()
@property (nonatomic, strong) FPAnalyticsConfiguration *configuration;
@end


@implementation FPAttributionMiddleware

- (instancetype)initWithConfiguration:(FPAnalyticsConfiguration *)configuration
{
    if (self = [super init]) {
        _configuration = configuration;
    }
    return self;
}

#pragma mark - ATT status

- (NSUInteger)currentATTStatus
{
    // In tests, FPAttributionMiddleware+Testing.h injects a provider via associated
    // objects. In production, objc_getAssociatedObject returns nil here.
    NSUInteger (^provider)(void) = objc_getAssociatedObject(
        self, NSSelectorFromString(@"attStatusProvider"));
    if (provider) { return provider(); }
    // Shared runtime-only lookup (FPATTRuntime.h). Returns kFPATTStatusUnavailable
    // when AppTrackingTransparency is not linked.
    return FPATTGetCurrentStatus();
}

- (NSString *)attStatusStringForStatus:(NSUInteger)status
{
    if (status == kFPATTStatusUnavailable) return @"unavailable";
    switch (status) {
        case kFPATTStatusRestricted:    return @"restricted";
        case kFPATTStatusDenied:        return @"denied";
        case kFPATTStatusAuthorized:    return @"authorized";
        default:                        return @"notDetermined"; // kFPATTStatusNotDetermined (0)
    }
}

#pragma mark - FPMiddleware

- (void)context:(FPContext *)context next:(FPMiddlewareNext)next
{
#if TARGET_OS_IPHONE
    FPPayload *payload = context.payload;
    if (payload) {
        NSUInteger status = [self currentATTStatus];
        NSMutableDictionary *enrichment = [NSMutableDictionary dictionary];

        enrichment[@"att_status"] = [self attStatusStringForStatus:status];

        // Include IDFA only when fully authorized and adSupportBlock is set.
        if (status == kFPATTStatusAuthorized && self.configuration.adSupportBlock != nil) {
            NSString *idfa = self.configuration.adSupportBlock();
            if (idfa && idfa.length > 0 && ![idfa isEqualToString:kFPAllZerosIDFA]) {
                enrichment[@"advertisingId"] = idfa;
            }
        }

        [payload fp_mergeDeviceContextValues:[enrichment copy]];
    }
#endif

    next(context);
}

@end
