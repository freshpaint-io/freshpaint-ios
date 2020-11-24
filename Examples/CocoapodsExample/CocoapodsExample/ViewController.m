//
//  ViewController.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Freshpaint/FPAnalytics.h>
#import "ViewController.h"


@interface ViewController ()

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    userActivity.webpageURL = [NSURL URLWithString:@"http://www.segment.com"];
    [[FPAnalytics sharedAnalytics] continueUserActivity:userActivity];
    [[FPAnalytics sharedAnalytics] track:@"test"];
    [[FPAnalytics sharedAnalytics] flush];
}

- (IBAction)fireEvent:(id)sender
{
    [[FPAnalytics sharedAnalytics] track:@"Cocoapods Example Button"];
    [[FPAnalytics sharedAnalytics] flush];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
