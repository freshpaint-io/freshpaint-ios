#import "FPAliasPayload.h"


@implementation FPAliasPayload

- (instancetype)initWithNewId:(NSString *)newId
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _theNewId = [newId copy];
    }
    return self;
}

@end
