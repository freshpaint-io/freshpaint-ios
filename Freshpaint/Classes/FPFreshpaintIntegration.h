#import <Foundation/Foundation.h>
#import "FPIntegration.h"
#import "FPHTTPClient.h"
#import "FPStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FPFreshpaintDidSendRequest;
extern NSString *const FPFreshpaintRequestDidSucceedNotification;
extern NSString *const FPFreshpaintRequestDidFailNotification;

/**
 * Filenames of "Application Support" files where essential data is stored.
 */
extern NSString *const kFPUserIdFilename;
extern NSString *const kFPQueueFilename;
extern NSString *const kFPTraitsFilename;


NS_SWIFT_NAME(FreshpaintIntegration)
@interface FPFreshpaintIntegration : NSObject <FPIntegration>

- (id)initWithAnalytics:(FPAnalytics *)analytics httpClient:(FPHTTPClient *)httpClient fileStorage:(id<FPStorage>)fileStorage userDefaultsStorage:(id<FPStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
