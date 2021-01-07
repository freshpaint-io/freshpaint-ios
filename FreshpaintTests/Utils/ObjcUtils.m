//
//  ObjcUtils.m
//  AnalyticsTests
//
//  Created by Brandon Sneed on 7/13/20.
//  Copyright © 2020 Freshpaint. All rights reserved.
//

#import "ObjcUtils.h"

// This can cause leaks if self is referenced in block.  DO NOT USE IN PRODUCTION.
// But ... for tests, it's ok.
NSException * _Nullable objc_tryCatch(void (^ _Nonnull block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
