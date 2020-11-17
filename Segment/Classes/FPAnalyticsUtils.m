#import "FPAnalyticsUtils.h"
#import "FPAnalytics.h"
#import "FPUtils.h"

static BOOL kAnalyticsLoggerShowLogs = NO;

#pragma mark - Logging

void FPSetShowDebugLogs(BOOL showDebugLogs)
{
    kAnalyticsLoggerShowLogs = showDebugLogs;
}

void FPLog(NSString *format, ...)
{
    if (!kAnalyticsLoggerShowLogs)
        return;

    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
}

#pragma mark - Serialization Extensions

@interface NSDate(FPSerializable)<FPSerializable>
- (id)serializeToAppropriateType;
@end

@implementation NSDate(FPSerializable)
- (id)serializeToAppropriateType
{
    return iso8601FormattedString(self);
}
@end

@interface NSURL(FPSerializable)<FPSerializable>
- (id)serializeToAppropriateType;
@end

@implementation NSURL(FPSerializable)
- (id)serializeToAppropriateType
{
    return [self absoluteString];
}
@end


