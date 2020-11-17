#import <Foundation/Foundation.h>
#import "FPIntegration.h"
#import "FPAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

@class FPAnalytics;

@protocol FPIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<FPIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(FPAnalytics *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

NS_ASSUME_NONNULL_END
