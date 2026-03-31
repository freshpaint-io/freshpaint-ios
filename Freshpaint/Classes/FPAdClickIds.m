//
//  FPAdClickIds.m
//  Freshpaint
//
//  FRP-38: Extracts ad click IDs and UTM parameters from deep link URLs.
//

#import "FPAdClickIds.h"
#import "FPUtils.h"

@implementation FPAdClickIds

+ (NSArray<NSString *> *)supportedClickIdKeys
{
    static NSArray<NSString *> *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"aleid",           // AppLovin
            @"cntr_auctionId",  // Basis
            @"msclkid",         // Bing
            @"fbclid",          // Facebook
            @"gclid",           // Google
            @"dclid",           // Google Display
            @"gclsrc",          // Google cross-account
            @"wbraid",          // Google iOS web-to-app
            @"gbraid",          // Google iOS app-to-web
            @"irclickid",       // impact.com
            @"li_fat_id",       // LinkedIn
            @"ndclid",          // Nextdoor
            @"epik",            // Pinterest
            @"rdt_cid",         // Reddit
            @"sccid",           // Snapchat (lowercase)
            @"ScCid",           // Snapchat (mixed-case variant)
            @"spclid",          // Spotify
            @"sapid",           // StackAdapt
            @"ttdimp",          // TheTradeDesk
            @"ttclid",          // TikTok
            @"twclid",          // Twitter/X
            @"clid_src",        // Twitter/X alternate
            @"viant_clid",      // Viant
            @"qclid",           // Quora
        ];
    });
    return keys;
}

+ (NSDictionary<NSString *, id> *)extractFromURL:(NSURL *)url
                                  payloadFilters:(NSDictionary<NSString *, NSString *> *)filters
{
    NSMutableDictionary<NSString *, id> *clickIds = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *utmParams = [NSMutableDictionary dictionary];

    if (!url) {
        return @{ @"clickIds": [clickIds copy], @"utmParams": [utmParams copy] };
    }

    // Apply payload filters to URL string first, then re-parse as NSURL.
    NSURL *filteredURL = url;
    if (filters.count > 0) {
        NSString *filteredString = [FPUtils traverseJSON:url.absoluteString
                                     andReplaceWithFilters:filters];
        NSURL *parsed = [NSURL URLWithString:filteredString];
        if (parsed) {
            filteredURL = parsed;
        }
    }

    // Build a case-insensitive lookup set for the 24 canonical parameter names.
    NSArray<NSString *> *supportedKeys = [self supportedClickIdKeys];
    // Map lowercase → canonical key name for case-insensitive matching.
    // When two keys share the same lowercase form (sccid / ScCid for Snapchat),
    // the later entry in supportedClickIdKeys wins and becomes the canonical key.
    // ScCid is listed after sccid, so $ScCid is always the stored form for Snapchat.
    NSMutableDictionary<NSString *, NSString *> *lowercaseToCanonical = [NSMutableDictionary dictionary];
    for (NSString *key in supportedKeys) {
        lowercaseToCanonical[key.lowercaseString] = key;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:filteredURL
                                             resolvingAgainstBaseURL:NO];

    // Build a plain param dict for easy lookup of gacid and Facebook extras.
    NSMutableDictionary<NSString *, NSString *> *allParams = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        if (item.name && item.value) {
            allParams[item.name] = item.value;
        }
    }

    // Creation timestamp (Unix ms) — int64_t to avoid 32-bit overflow (overflows Jan 2038).
    int64_t creationTimeMs = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000);

    // Google click ID names that trigger gacid capture.
    NSSet<NSString *> *googleClickIdKeys = [NSSet setWithArray:@[@"gclid", @"wbraid", @"gbraid"]];

    // Scan query items case-insensitively.
    NSMutableSet<NSString *> *matchedCanonicalKeys = [NSMutableSet set];

    for (NSURLQueryItem *item in components.queryItems) {
        if (!item.name || !item.value) continue;

        NSString *canonical = lowercaseToCanonical[item.name.lowercaseString];
        if (!canonical) continue;

        // Avoid double-processing if the same canonical name appears twice
        // (e.g., both sccid and ScCid present — first one wins).
        if ([matchedCanonicalKeys containsObject:canonical]) continue;
        [matchedCanonicalKeys addObject:canonical];

        NSString *prefixedKey = [NSString stringWithFormat:@"$%@", canonical];
        clickIds[prefixedKey] = item.value;
        clickIds[[NSString stringWithFormat:@"%@_creation_time", prefixedKey]] = @(creationTimeMs);

        // Google special handling: capture gacid as $<clickId>_campaign_id.
        if ([googleClickIdKeys containsObject:canonical]) {
            NSString *gacid = allParams[@"gacid"];
            if (gacid) {
                clickIds[[NSString stringWithFormat:@"%@_campaign_id", prefixedKey]] = gacid;
            }
        }

        // Facebook special handling: capture ad_id, adset_id, campaign_id.
        if ([canonical isEqualToString:@"fbclid"]) {
            NSString *adId = allParams[@"ad_id"];
            if (adId) clickIds[@"$fbclid_ad_id"] = adId;
            NSString *adsetId = allParams[@"adset_id"];
            if (adsetId) clickIds[@"$fbclid_adset_id"] = adsetId;
            NSString *campaignId = allParams[@"campaign_id"];
            if (campaignId) clickIds[@"$fbclid_campaign_id"] = campaignId;
        }
    }

    // Extract UTM parameters.
    NSArray<NSString *> *utmKeys = @[
        @"utm_source", @"utm_medium", @"utm_campaign", @"utm_term", @"utm_content"
    ];
    for (NSURLQueryItem *item in components.queryItems) {
        if (!item.name || !item.value) continue;
        if ([utmKeys containsObject:item.name]) {
            utmParams[item.name] = item.value;
        }
    }

    return @{
        @"clickIds":  [clickIds copy],
        @"utmParams": [utmParams copy],
    };
}

@end
