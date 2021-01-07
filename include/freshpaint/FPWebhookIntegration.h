#import "FPIntegration.h"
#import "FPIntegrationFactory.h"
#import "FPHTTPClient.h"

NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_NAME(WebhookIntegrationFactory)
@interface FPWebhookIntegrationFactory : NSObject <FPIntegrationFactory>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *webhookUrl;

- (instancetype)initWithName:(NSString *)name webhookUrl:(NSString *)webhookUrl;

@end

NS_ASSUME_NONNULL_END
