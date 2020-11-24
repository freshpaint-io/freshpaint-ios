//
//  AppDelegate.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Freshpaint/FPAnalytics.h>
#import "AppDelegate.h"


@interface AppDelegate ()

@end

// https://segment.com/segment-mobile/sources/ios_cocoapods_example/overview
NSString *const FPMENT_WRITE_KEY = @"82ef97c4-8367-4d61-b0be-261498e9dd13";


@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FPAnalytics debug:YES];
    FPAnalyticsConfiguration *configuration = [FPAnalyticsConfiguration configurationWithWriteKey:FPMENT_WRITE_KEY];
    configuration.trackApplicationLifecycleEvents = YES;
    configuration.flushAt = 1;
    [FPAnalytics setupWithConfiguration:configuration];
    [[FPAnalytics sharedAnalytics] identify:@"Prateek" traits:nil options: @{
                                                                              @"anonymousId":@"test_anonymousId"
                                                                              }];
    [[FPAnalytics sharedAnalytics] track:@"Cocoapods Example Launched"];

    [[FPAnalytics sharedAnalytics] flush];
    NSLog(@"application:didFinishLaunchingWithOptions: %@", launchOptions);
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"applicationWillResignActive:");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground:");
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground:");
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive:");
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"applicationWillTerminate:");
}

@end
