//
//  FPAttributionMiddleware.m
//  Analytics
//

#import "FPAttributionMiddleware.h"
#import "FPContext.h"
#import "FPPayload.h"
#import "FPPayload+FPAttributionEnrichment.h"

#if TARGET_OS_IPHONE
#import <objc/message.h>
#endif

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
    // Test injection takes priority.
    if (self.attStatusProvider) {
        return self.attStatusProvider();
    }

#if TARGET_OS_IPHONE
    Class cls = NSClassFromString(@"ATTrackingManager");
    if (cls) {
        SEL sel = NSSelectorFromString(@"trackingAuthorizationStatus");
        if ([cls respondsToSelector:sel]) {
            // Cast to avoid undefined behavior from variadic objc_msgSend.
            typedef NSUInteger (*ATTStatusIMP)(id, SEL);
            ATTStatusIMP imp = (ATTStatusIMP)[cls methodForSelector:sel];
            if (imp) {
                return imp(cls, sel);
            }
        }
    }
#endif

    // ATT unavailable (tvOS, macOS, old iOS without ATT framework linked).
    return 0; // notDetermined
}

- (NSString *)attStatusStringForStatus:(NSUInteger)status
{
    switch (status) {
        case 1:  return @"restricted";
        case 2:  return @"denied";
        case 3:  return @"authorized";
        default: return @"notDetermined";
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
        if (status == 3 && self.configuration.adSupportBlock != nil) {
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
