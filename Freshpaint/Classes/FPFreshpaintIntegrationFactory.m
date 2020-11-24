#import "FPFreshpaintIntegrationFactory.h"
#import "FPFreshpaintIntegration.h"


@implementation FPFreshpaintIntegrationFactory

- (id)initWithHTTPClient:(FPHTTPClient *)client fileStorage:(id<FPStorage>)fileStorage userDefaultsStorage:(id<FPStorage>)userDefaultsStorage
{
    if (self = [super init]) {
        _client = client;
        _userDefaultsStorage = userDefaultsStorage;
        _fileStorage = fileStorage;
    }
    return self;
}

- (id<FPIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(FPAnalytics *)analytics
{
    return [[FPFreshpaintIntegration alloc] initWithAnalytics:analytics httpClient:self.client fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage];
}

- (NSString *)key
{
    return @"Freshpaint.io";
}

@end
