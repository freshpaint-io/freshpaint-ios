//
//  FPContext.m
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "FPContext.h"


@interface FPContext () <FPMutableContext>

@property (nonatomic) FPEventType eventType;
@property (nonatomic, nullable) NSString *userId;
@property (nonatomic, nullable) NSString *anonymousId;
@property (nonatomic, nullable) FPPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end


@implementation FPContext

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Bad Initialization"
                                   reason:@"Please use initWithAnalytics:"
                                 userInfo:nil];
}

- (instancetype)initWithAnalytics:(FPAnalytics *)analytics
{
    if (self = [super init]) {
        __analytics = analytics;
// TODO: Have some other way of indicating the debug flag is on too.
// Also, for logging it'd be damn nice to implement a logging protocol
// such as CocoalumberJack and allow developers to pipe logs to wherever they want
// Of course we wouldn't us depend on it. it'd be like a soft dependency where
// analytics-ios would totally work without it but works even better with it!
#ifdef DEBUG
        _debug = YES;
#endif
    }
    return self;
}

- (FPContext *_Nonnull)modify:(void (^_Nonnull)(id<FPMutableContext> _Nonnull ctx))modify
{
    // We're also being a bit clever here by implementing FPContext actually as a mutable
    // object but hiding that implementation detail from consumer of the API.
    // In production also instead of copying self we simply just return self
    // because the net effect is the same anyways. In the end we get a lot of the benefits
    // of immutable data structure without the cost of having to allocate and reallocate
    // objects over and over again.
    FPContext *context = self.debug ? [self copy] : self;
    NSString *originalTimestamp = context.payload.timestamp;
    modify(context);
    if (originalTimestamp) {
        context.payload.timestamp = originalTimestamp;
    }
    
    // TODO: We could probably add some validation here that the newly modified context
    // is actualy valid. For example, `eventType` should match `paylaod` class.
    // or anonymousId should never be null.
    return context;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    FPContext *ctx = [[FPContext allocWithZone:zone] initWithAnalytics:self._analytics];
    ctx.eventType = self.eventType;
    ctx.payload = self.payload;
    ctx.error = self.error;
    ctx.debug = self.debug;
    return ctx;
}

@end
