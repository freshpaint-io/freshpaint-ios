//
//  FPAttributionMiddleware.h
//  Analytics
//
//  Enriches every event with ATT consent status (att_status) and
//  conditionally includes IDFA (only when ATT status is authorized).
//  Uses runtime-only access — never imports AppTrackingTransparency
//  or AdSupport directly.
//

#import <Foundation/Foundation.h>
#import "FPMiddleware.h"
#import "FPAnalyticsConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Provider block used exclusively for unit-test injection of ATT status.
 * Values mirror ATTrackingManager.ATTrackingAuthorizationStatus:
 *   0 = notDetermined, 1 = restricted, 2 = denied, 3 = authorized.
 * Do NOT set this in production code.
 */
typedef NSUInteger (^FPATTStatusProvider)(void);

NS_SWIFT_NAME(AttributionMiddleware)
@interface FPAttributionMiddleware : NSObject <FPMiddleware>

/**
 * Designated initializer.
 * @param configuration The analytics configuration. Used to access adSupportBlock.
 */
- (instancetype)initWithConfiguration:(FPAnalyticsConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/**
 * Inject a fake ATT status for unit tests only.
 * When nil (default), the live ATTrackingManager is queried at runtime.
 */
@property (nonatomic, copy, nullable) FPATTStatusProvider attStatusProvider;

@end

NS_ASSUME_NONNULL_END
