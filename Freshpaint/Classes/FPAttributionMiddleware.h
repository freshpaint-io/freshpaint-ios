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

NS_SWIFT_NAME(AttributionMiddleware)
@interface FPAttributionMiddleware : NSObject <FPMiddleware>

/**
 * Designated initializer.
 * @param configuration The analytics configuration. Used to access adSupportBlock.
 */
- (instancetype)initWithConfiguration:(FPAnalyticsConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
