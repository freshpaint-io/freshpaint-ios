#import "FPPayload.h"
#import "FPState.h"
#import "FPPayload+FPAttributionEnrichment.h"

// Redeclare context as readwrite for internal mutation by FPAttributionMiddleware.
@interface FPPayload ()
@property (nonatomic, readwrite) NSDictionary *context;
@end

@implementation FPPayload

@synthesize userId = _userId;
@synthesize anonymousId = _anonymousId;

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    if (self = [super init]) {
        // combine existing state with user supplied context.
        NSDictionary *internalContext = [FPState sharedInstance].context.payload;
        
        NSMutableDictionary *combinedContext = [[NSMutableDictionary alloc] init];
        [combinedContext addEntriesFromDictionary:internalContext];
        [combinedContext addEntriesFromDictionary:context];

        _context = [combinedContext copy];
        _integrations = [integrations copy];
        _messageId = nil;
        _userId = nil;
        _anonymousId = nil;
    }
    return self;
}

@end


@implementation FPApplicationLifecyclePayload
@end


@implementation FPRemoteNotificationPayload
@end


@implementation FPContinueUserActivityPayload
@end


@implementation FPOpenURLPayload
@end


#pragma mark - FPAttributionEnrichment category

@implementation FPPayload (FPAttributionEnrichment)

- (void)fp_mergeDeviceContextValues:(NSDictionary *)additions
{
    // The middleware pipeline runs on a serial analytics queue, so concurrent
    // access to the same payload is not expected in normal usage. The lock is
    // a defensive measure against custom middleware that dispatches off-queue.
    @synchronized(self) {
        NSMutableDictionary *ctx = [self.context mutableCopy] ?: [NSMutableDictionary dictionary];
        NSMutableDictionary *device = [ctx[@"device"] mutableCopy] ?: [NSMutableDictionary dictionary];
        [device addEntriesFromDictionary:additions];
        ctx[@"device"] = [device copy];
        self.context = [ctx copy];
    }
}

@end
