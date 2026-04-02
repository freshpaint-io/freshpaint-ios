//
//  FPAdClickIds.h
//  Freshpaint
//
//  FRP-38: Extracts ad click IDs and UTM parameters from deep link URLs.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Utilities for extracting ad platform click IDs and UTM parameters from URLs.
@interface FPAdClickIds : NSObject

/// Returns the list of all supported click ID parameter names (24 entries).
+ (NSArray<NSString *> *)supportedClickIdKeys;

/// Extracts click IDs and UTM params from a URL after applying payload filters.
///
/// Click IDs are stored without an expiry by design -- they represent one-time
/// attribution signals that remain valid for the lifetime of the install. A TTL
/// may be introduced if product requirements change. UTM parameters, by contrast,
/// expire after 24 hours.
///
/// @param url             The deep link URL to inspect.
/// @param filters         Payload filter patterns (regex -> replacement) -- applied to the URL
///                        string before query parameter extraction.
///
/// @return A dictionary with two keys:
///   - @"clickIds"  : NSDictionary<NSString*, id> -- flat map of @"$key" -> value and
///                    @"$key_creation_time" -> NSNumber (Unix timestamp in milliseconds).
///                    Google gacid and Facebook extras are also included here.
///                    Empty dict when no click IDs are present.
///   - @"utmParams" : NSDictionary<NSString*, NSString*> -- map of utm_* param -> value.
///                    Empty dict when no UTM params are present.
+ (NSDictionary<NSString *, id> *)extractFromURL:(NSURL *)url
                                  payloadFilters:(NSDictionary<NSString *, NSString *> *)filters;

@end

NS_ASSUME_NONNULL_END
