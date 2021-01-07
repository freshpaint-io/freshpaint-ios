#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "FPAnalytics.h"

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(StoreKitTracker)
@interface FPStoreKitTracker : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)trackTransactionsForAnalytics:(FPAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END
