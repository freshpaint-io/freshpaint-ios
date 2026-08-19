#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kFPReachabilityChangedNotification;

@class FPReachability;

typedef void (^FPNetworkReachable)(FPReachability *reachability);
typedef void (^FPNetworkUnreachable)(FPReachability *reachability);

NS_SWIFT_NAME(Reachability)
@interface FPReachability : NSObject

@property (nonatomic, copy, nullable) FPNetworkReachable reachableBlock;
@property (nonatomic, copy, nullable) FPNetworkUnreachable unreachableBlock;
@property (nonatomic, assign) BOOL reachableOnWWAN;

+ (FPReachability *_Nullable)reachabilityWithHostname:(NSString *)hostname;
+ (FPReachability *_Nullable)reachabilityForInternetConnection;
+ (FPReachability *_Nullable)reachabilityForLocalWiFi;

- (BOOL)startNotifier;
- (void)stopNotifier;

@property (nonatomic, readonly) BOOL isReachable;
@property (nonatomic, readonly) BOOL isReachableViaWWAN;
@property (nonatomic, readonly) BOOL isReachableViaWiFi;

@end

NS_ASSUME_NONNULL_END
