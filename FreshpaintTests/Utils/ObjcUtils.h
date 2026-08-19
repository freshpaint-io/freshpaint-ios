//
//  ObjcUtils.h
//  AnalyticsTests
//
//  Created by Brandon Sneed on 7/13/20.
//  Copyright © 2020 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Freshpaint/FPReachability.h>

NSException * _Nullable objc_tryCatch(void (^ _Nonnull block)(void));

NS_ASSUME_NONNULL_BEGIN

/// Test stub that returns fixed reachability values without a real NWPathMonitor.
@interface FPStubReachability : FPReachability
@property (nonatomic) BOOL stubReachable;
@property (nonatomic) BOOL stubWifi;
@property (nonatomic) BOOL stubCellular;

+ (instancetype)wifiReachable;
+ (instancetype)cellularReachable;
+ (instancetype)notReachable;
@end

NS_ASSUME_NONNULL_END
