//
//  FPATTTestConstants.h
//  FreshpaintTests
//
//  Shared ATT status constants for unit tests. Import in test files only.
//  Values mirror ATTrackingManager.ATTrackingAuthorizationStatus.
//

#pragma once
#import <Foundation/Foundation.h>

static const NSUInteger kATTNotDetermined = 0;
static const NSUInteger kATTRestricted    = 1;
static const NSUInteger kATTDenied        = 2;
static const NSUInteger kATTAuthorized    = 3;
