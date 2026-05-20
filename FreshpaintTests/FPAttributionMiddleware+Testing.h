//
//  FPAttributionMiddleware+Testing.h
//  Freshpaint
//
//  Test seam for FPAttributionMiddleware. Import this header in unit tests only.
//  Do NOT import from production code or include in the SDK's public headers.
//

#import "FPAttributionMiddleware.h"

NS_ASSUME_NONNULL_BEGIN

@interface FPAttributionMiddleware (FPTesting)

/**
 * Inject a fake ATT status for unit tests only (DEBUG builds).
 * When nil (default), the live ATTrackingManager is queried at runtime.
 * Do NOT set this in production code.
 */
@property (nonatomic, copy, nullable) NSUInteger (^attStatusProvider)(void);

@end

NS_ASSUME_NONNULL_END
