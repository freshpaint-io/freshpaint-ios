//
//  FPAttributionMiddleware+Testing.h
//  Freshpaint
//
//  Test seam for FPAttributionMiddleware. Import this header in unit tests only.
//  Do NOT import from production code or include in the SDK's public headers.
//

#import "FPAttributionMiddleware.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Provider block for unit-test injection of ATT status.
 * Values mirror ATTrackingManager.ATTrackingAuthorizationStatus:
 *   0 = notDetermined, 1 = restricted, 2 = denied, 3 = authorized.
 */
typedef NSUInteger (^FPATTStatusProvider)(void);

@interface FPAttributionMiddleware (FPTesting)

/**
 * Inject a fake ATT status for unit tests only.
 * When nil (default), the live ATTrackingManager is queried at runtime.
 * Do NOT set this in production code.
 */
@property (nonatomic, copy, nullable) FPATTStatusProvider attStatusProvider;

@end

NS_ASSUME_NONNULL_END
