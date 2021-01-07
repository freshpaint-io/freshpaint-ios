//
//  FPUserDefaultsStorage.h
//  Analytics
//
//  Created by Tony Xiao on 8/24/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FPStorage.h"


NS_SWIFT_NAME(UserDefaultsStorage)
@interface FPUserDefaultsStorage : NSObject <FPStorage>

@property (nonatomic, strong, nullable) id<FPCrypto> crypto;
@property (nonnull, nonatomic, readonly) NSUserDefaults *defaults;
@property (nullable, nonatomic, readonly) NSString *namespacePrefix;

- (instancetype _Nonnull)initWithDefaults:(NSUserDefaults *_Nonnull)defaults namespacePrefix:(NSString *_Nullable)namespacePrefix crypto:(id<FPCrypto> _Nullable)crypto;

@end
