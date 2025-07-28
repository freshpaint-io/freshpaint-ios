#import "UIViewController+FPScreen.h"
#import <objc/runtime.h>
#import "FPAnalytics.h"
#import "FPAnalyticsUtils.h"
#import "FPScreenReporting.h"

// Deduplication tracking
static NSMutableDictionary *lastScreenEventTimes;
static const NSTimeInterval SCREEN_EVENT_DEDUPLICATION_WINDOW = 0.5; // 500ms window


#if TARGET_OS_IPHONE
@implementation UIViewController (FPScreen)

+ (void)seg_swizzleViewDidAppear
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Initialize deduplication dictionary
        lastScreenEventTimes = [[NSMutableDictionary alloc] init];
        
        Class class = [self class];

        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(seg_viewDidAppear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class,
                            originalSelector,
                            method_getImplementation(swizzledMethod),
                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


+ (UIViewController *)seg_rootViewControllerFromView:(UIView *)view
{
    UIViewController *root = view.window.rootViewController;
    return [self seg_topViewController:root];
}

+ (UIViewController *)seg_topViewController:(UIViewController *)rootViewController
{
    UIViewController *nextRootViewController = [self seg_nextRootViewController:rootViewController];
    if (nextRootViewController) {
        return [self seg_topViewController:nextRootViewController];
    }

    return rootViewController;
}

+ (UIViewController *)seg_nextRootViewController:(UIViewController *)rootViewController
{
    UIViewController *presentedViewController = rootViewController.presentedViewController;
    if (presentedViewController != nil) {
        return presentedViewController;
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *lastViewController = ((UINavigationController *)rootViewController).viewControllers.lastObject;
        return lastViewController;
    }

    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        __auto_type *currentTabViewController = ((UITabBarController*)rootViewController).selectedViewController;
        if (currentTabViewController != nil) {
            return currentTabViewController;
        }
    }

    if (rootViewController.childViewControllers.count > 0) {
        if ([rootViewController conformsToProtocol:@protocol(FPScreenReporting)] && [rootViewController respondsToSelector:@selector(seg_mainViewController)]) {
            __auto_type screenReporting = (UIViewController<FPScreenReporting>*)rootViewController;
            return screenReporting.seg_mainViewController;
        }

        // fall back on first child UIViewController as a "best guess" assumption
        __auto_type *firstChildViewController = rootViewController.childViewControllers.firstObject;
        if (firstChildViewController != nil) {
            return firstChildViewController;
        }
    }

    return nil;
}


+ (NSString *)seg_improveScreenNameForSwiftUI:(NSString *)name fromViewController:(UIViewController *)viewController
{
    // Handle SwiftUI UIHostingController names
    if ([name containsString:@"UIHostingController"] || 
        [name containsString:@"_TtGC7SwiftUI"] || 
        [name hasPrefix:@"_Tt"]) {
        
        // Try to get a better name from the view controller's title
        if (viewController.title && viewController.title.length > 0) {
            return viewController.title;
        }
        
        // Try to get name from navigation item
        if (viewController.navigationItem.title && viewController.navigationItem.title.length > 0) {
            return viewController.navigationItem.title;
        }
        
        // Try to get name from tab bar item
        if (viewController.tabBarItem.title && viewController.tabBarItem.title.length > 0) {
            return viewController.tabBarItem.title;
        }
        
        // Check if this is inside a navigation controller
        if (viewController.navigationController) {
            UINavigationController *navController = viewController.navigationController;
            if (navController.viewControllers.count > 0) {
                UIViewController *topVC = navController.topViewController;
                if (topVC.title && topVC.title.length > 0) {
                    return topVC.title;
                }
            }
        }
        
        // Check if this is inside a tab bar controller
        if (viewController.tabBarController) {
            UITabBarController *tabController = viewController.tabBarController;
            NSInteger selectedIndex = tabController.selectedIndex;
            if (selectedIndex != NSNotFound && selectedIndex < tabController.tabBar.items.count) {
                UITabBarItem *selectedItem = tabController.tabBar.items[selectedIndex];
                if (selectedItem.title && selectedItem.title.length > 0) {
                    return [NSString stringWithFormat:@"%@ Tab", selectedItem.title];
                }
            }
        }
        
        // Default fallback for SwiftUI screens
        return @"SwiftUI Screen";
    }
    
    return name;
}

+ (BOOL)seg_shouldTrackScreenEvent:(NSString *)screenName
{
    NSString *currentTime = [NSString stringWithFormat:@"%.3f", [[NSDate date] timeIntervalSince1970]];
    NSString *lastEventTime = lastScreenEventTimes[screenName];
    
    if (lastEventTime) {
        NSTimeInterval timeDiff = [currentTime doubleValue] - [lastEventTime doubleValue];
        if (timeDiff < SCREEN_EVENT_DEDUPLICATION_WINDOW) {
            // Too recent, skip this event
            return NO;
        }
    }
    
    // Update the last event time
    lastScreenEventTimes[screenName] = currentTime;
    
    // Clean up old entries (keep only last 10 screen names to prevent memory growth)
    if (lastScreenEventTimes.count > 10) {
        NSArray *sortedKeys = [[lastScreenEventTimes allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
            double time1 = [lastScreenEventTimes[key1] doubleValue];
            double time2 = [lastScreenEventTimes[key2] doubleValue];
            return time1 < time2 ? NSOrderedAscending : (time1 > time2 ? NSOrderedDescending : NSOrderedSame);
        }];
        
        // Remove oldest entries
        NSInteger entriesToRemove = lastScreenEventTimes.count - 5;
        for (NSInteger i = 0; i < entriesToRemove; i++) {
            [lastScreenEventTimes removeObjectForKey:sortedKeys[i]];
        }
    }
    
    return YES;
}

- (void)seg_viewDidAppear:(BOOL)animated
{
    UIViewController *top = [[self class] seg_rootViewControllerFromView:self.view];
    if (!top) {
        FPLog(@"Could not infer screen.");
        [self seg_viewDidAppear:animated];
        return;
    }

    // Get the original class name for screen_class
    NSString *screenClass = [[top class] description];
    
    // Get the processed name for screen_name
    NSString *screenName = [screenClass stringByReplacingOccurrencesOfString:@"ViewController" withString:@""];
    
    if (!screenName || screenName.length == 0) {
        // if no class description found, try view controller's title.
        screenName = [top title];
        // Class name could be just "ViewController".
        if (screenName.length == 0) {
            FPLog(@"Could not infer screen name.");
            screenName = @"Unknown";
        }
    }
    
    // Improve screen names for SwiftUI
    screenName = [[self class] seg_improveScreenNameForSwiftUI:screenName fromViewController:top];
    
    // Check for deduplication
    if (![[self class] seg_shouldTrackScreenEvent:screenName]) {
        [self seg_viewDidAppear:animated];
        return;
    }


    if ([top conformsToProtocol:@protocol(FPScreenReporting)] && [top respondsToSelector:@selector(seg_trackScreen:name:)]) {
        __auto_type screenReporting = (UIViewController<FPScreenReporting>*)top;
        [screenReporting seg_trackScreen:top name:screenName];
        [self seg_viewDidAppear:animated];
        return;
    }

    [[FPAnalytics sharedAnalytics] screen:screenName properties:nil options:nil];

    [self seg_viewDidAppear:animated];
}

@end
#endif
