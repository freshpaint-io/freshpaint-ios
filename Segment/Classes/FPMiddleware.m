//
//  FPMiddleware.m
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "FPUtils.h"
#import "FPMiddleware.h"


@implementation FPDestinationMiddleware
- (instancetype)initWithKey:(NSString *)integrationKey middleware:(NSArray<id<FPMiddleware>> *)middleware
{
    if (self = [super init]) {
        _integrationKey = integrationKey;
        _middleware = middleware;
    }
    return self;
}
@end

@implementation FPBlockMiddleware

- (instancetype)initWithBlock:(FPMiddlewareBlock)block
{
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (void)context:(FPContext *)context next:(FPMiddlewareNext)next
{
    self.block(context, next);
}

@end


@implementation FPMiddlewareRunner

- (instancetype)initWithMiddleware:(NSArray<id<FPMiddleware>> *_Nonnull)middlewares
{
    if (self = [super init]) {
        _middlewares = middlewares;
    }
    return self;
}

- (FPContext *)run:(FPContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback
{
    return [self runMiddlewares:self.middlewares context:context callback:callback];
}

// TODO: Maybe rename FPContext to FPEvent to be a bit more clear?
// We could also use some sanity check / other types of logging here.
- (FPContext *)runMiddlewares:(NSArray<id<FPMiddleware>> *_Nonnull)middlewares
               context:(FPContext *_Nonnull)context
              callback:(RunMiddlewaresCallback _Nullable)callback
{
    __block FPContext * _Nonnull result = context;

    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return context;
    }
    
    [middlewares[0] context:result next:^(FPContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        result = [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
    
    return result;
}

@end
