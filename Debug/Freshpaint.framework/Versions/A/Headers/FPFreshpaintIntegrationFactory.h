#import <Foundation/Foundation.h>
#import "FPIntegrationFactory.h"
#import "FPHTTPClient.h"
#import "FPStorage.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(FreshpaintIntegrationFactory)
@interface FPFreshpaintIntegrationFactory : NSObject <FPIntegrationFactory>

@property (nonatomic, strong) FPHTTPClient *client;
@property (nonatomic, strong) id<FPStorage> userDefaultsStorage;
@property (nonatomic, strong) id<FPStorage> fileStorage;

- (instancetype)initWithHTTPClient:(FPHTTPClient *)client fileStorage:(id<FPStorage>)fileStorage userDefaultsStorage:(id<FPStorage>)userDefaultsStorage;

@end

NS_ASSUME_NONNULL_END
