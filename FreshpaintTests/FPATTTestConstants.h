//
//  FPATTTestConstants.h
//  FreshpaintTests
//
//  Shared ATT status constants for unit tests. Import in test files only.
//  Aliases over the canonical kFPATTStatus* constants from FPATTRuntime.h so
//  test code remains readable without duplicating the definitions.
//

#pragma once
#import "FPATTRuntime.h"

// Aliases for test readability — map to canonical production constants.
#define kATTNotDetermined kFPATTStatusNotDetermined
#define kATTRestricted    kFPATTStatusRestricted
#define kATTDenied        kFPATTStatusDenied
#define kATTAuthorized    kFPATTStatusAuthorized
