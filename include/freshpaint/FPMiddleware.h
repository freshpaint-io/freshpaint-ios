//
//  FPMiddleware.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FPContext.h"

typedef void (^FPMiddlewareNext)(FPContext *_Nullable newContext);

NS_SWIFT_NAME(Middleware)
@protocol FPMiddleware
@required

// NOTE: If you want to hold onto references of context AFTER passing it through to the next
// middleware, you should explicitly create a copy via `[context copy]` to guarantee
// that it does not get changed from underneath you because contexts can be implemented
// as mutable objects under the hood for performance optimization.
// The behavior of keeping reference to a context AFTER passing it to the next middleware
// is strictly undefined.

// Middleware should **always** call `next`. If the intention is to explicitly filter out
// events from downstream, call `next` with `nil` as the param.
// It's ok to save next callback until a more convenient time, but it should always always be done.
// We'll probably actually add tests to sure it is so.
// TODO: Should we add error as second param to next?
- (void)context:(FPContext *_Nonnull)context next:(FPMiddlewareNext _Nonnull)next;

@end

typedef void (^FPMiddlewareBlock)(FPContext *_Nonnull context, FPMiddlewareNext _Nonnull next);


NS_SWIFT_NAME(BlockMiddleware)
@interface FPBlockMiddleware : NSObject <FPMiddleware>

@property (nonnull, nonatomic, readonly) FPMiddlewareBlock block;

- (instancetype _Nonnull)initWithBlock:(FPMiddlewareBlock _Nonnull)block;

@end


typedef void (^RunMiddlewaresCallback)(BOOL earlyExit, NSArray<id<FPMiddleware>> *_Nonnull remainingMiddlewares);

// XXX TODO: Add some tests for FPMiddlewareRunner
NS_SWIFT_NAME(MiddlewareRunner)
@interface FPMiddlewareRunner : NSObject

// While it is certainly technically possible to change middlewares dynamically on the fly. we're explicitly NOT
// gonna support that for now to keep things simple. If there is a real need later we'll see then.
@property (nonnull, nonatomic, readonly) NSArray<id<FPMiddleware>> *middlewares;

- (FPContext * _Nonnull)run:(FPContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback;

- (instancetype _Nonnull)initWithMiddleware:(NSArray<id<FPMiddleware>> *_Nonnull)middlewares;

@end

// Container object for middlewares for a specific destination.
NS_SWIFT_NAME(DestinationMiddleware)
@interface FPDestinationMiddleware : NSObject
@property (nonatomic, strong, nonnull, readonly) NSString *integrationKey;
@property (nonatomic, strong, nullable, readonly) NSArray<id<FPMiddleware>> *middleware;
- (instancetype _Nonnull)initWithKey:(NSString * _Nonnull)integrationKey middleware:(NSArray<id<FPMiddleware>> * _Nonnull)middleware;
@end

NS_SWIFT_NAME(EdgeFunctionMiddleware)
@protocol FPEdgeFunctionMiddleware
@required
@property (nonatomic, readonly, nullable) NSArray<id<FPMiddleware>> *sourceMiddleware;
@property (nonatomic, readonly, nullable) NSArray<FPDestinationMiddleware *> *destinationMiddleware;
- (void)setEdgeFunctionData:(NSDictionary *_Nullable)data;
@end

