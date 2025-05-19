//
//  AppDelegate.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "FPAnalytics.h"
#import "AppDelegate.h"


@interface AppDelegate ()

@end

// Mobile (iOS): Production env.
NSString *const FPMENT_WRITE_KEY = @"5bd86532-4cc1-4b18-8392-880be8eb0e3d";


@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FPAnalytics debug:YES];
    FPAnalyticsConfiguration *configuration = [FPAnalyticsConfiguration configurationWithWriteKey:FPMENT_WRITE_KEY];
    configuration.trackApplicationLifecycleEvents = YES;
    configuration.flushAt = 1;
    configuration.sessionTimeout = 120; 
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
