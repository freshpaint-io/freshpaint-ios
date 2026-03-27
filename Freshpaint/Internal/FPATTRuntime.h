//
//  FPATTRuntime.h
//  Freshpaint
//
//  Internal-only header. Shared runtime-only ATT status lookup used by both
//  FPAttributionMiddleware and FPAnalytics to eliminate duplicated IMP-dispatch
//  code. Import in .m files only; do NOT include in the public umbrella header.
//

#pragma once
#import <Foundation/Foundation.h>

/// Sentinel returned when the ATT framework is unavailable (macOS, or an iOS/tvOS
/// build that has not linked AppTrackingTransparency). Kept outside the
/// ATTrackingManager range (0–3) so callers can distinguish "user not yet prompted"
/// (notDetermined = 0) from "platform has no ATT framework".
static const NSUInteger kFPATTStatusUnavailable = NSUIntegerMax;

/// Returns the current ATT tracking authorization status via runtime-only lookup.
/// Never imports AppTrackingTransparency directly — safe for apps that omit it.
///
/// @return 0–3 on success (mirrors ATTrackingManager.ATTrackingAuthorizationStatus),
///         or kFPATTStatusUnavailable when the framework is absent.
static inline NSUInteger FPATTGetCurrentStatus(void)
{
#if TARGET_OS_IPHONE
    Class cls = NSClassFromString(@"ATTrackingManager");
    if (!cls) { return kFPATTStatusUnavailable; }
    SEL sel = NSSelectorFromString(@"trackingAuthorizationStatus");
    if (![cls respondsToSelector:sel]) { return kFPATTStatusUnavailable; }
    typedef NSUInteger (*ATTStatusIMP)(id, SEL);
    ATTStatusIMP imp = (ATTStatusIMP)[cls methodForSelector:sel];
    return imp ? imp(cls, sel) : kFPATTStatusUnavailable;
#else
    return kFPATTStatusUnavailable;
#endif
}
