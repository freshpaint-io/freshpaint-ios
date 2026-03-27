//
//  Analytics.h
//  Analytics
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Analytics.
FOUNDATION_EXPORT double FreshpaintVersionNumber;

//! Project version string for Analytics.
FOUNDATION_EXPORT const unsigned char FreshpaintVersionString[];

#import "FPAnalytics.h"
#import "FPFreshpaintIntegration.h"
#import "FPFreshpaintIntegrationFactory.h"
#import "FPContext.h"
#import "FPMiddleware.h"
#import "FPScreenReporting.h"
#import "FPAnalyticsUtils.h"
#import "FPWebhookIntegration.h"
