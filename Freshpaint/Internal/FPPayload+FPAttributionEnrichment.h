//
//  FPPayload+FPAttributionEnrichment.h
//  Freshpaint
//
//  Internal-only category. Exposes device-context mutation for
//  FPAttributionMiddleware. Do NOT import from public-facing files.
//

#import "FPPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface FPPayload (FPAttributionEnrichment)

/**
 * Merges @a additions into the existing `device` dict inside the payload's
 * JSON context. If no `device` dict exists yet, one is created.
 * Existing keys in `device` that are not in @a additions are preserved.
 */
- (void)fp_mergeDeviceContextValues:(NSDictionary *)additions;

@end

NS_ASSUME_NONNULL_END
