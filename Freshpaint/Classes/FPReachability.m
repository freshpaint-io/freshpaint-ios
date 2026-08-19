#import "FPReachability.h"
#import <Network/Network.h>

NSString *const kFPReachabilityChangedNotification = @"kFPReachabilityChangedNotification";

@interface FPReachability () {
    nw_path_monitor_t _monitor;
    // Written on _monitorQueue, read from any thread. Atomic BOOL read/write on
    // aligned storage is guaranteed on all Apple platforms, so no lock is needed
    // for these single-word flags.
    volatile BOOL _isReachable;
    volatile BOOL _isWiFi;
    volatile BOOL _isCellular;
}
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@end

@implementation FPReachability

+ (FPReachability *_Nullable)reachabilityWithHostname:(NSString *)hostname {
    // NWPathMonitor monitors general connectivity rather than a specific host,
    // which is correct for SDK use: we care whether any internet path exists.
    return [[self alloc] init];
}

+ (FPReachability *_Nullable)reachabilityForInternetConnection {
    return [[self alloc] init];
}

+ (FPReachability *_Nullable)reachabilityForLocalWiFi {
    return [[self alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        _reachableOnWWAN = YES;
        _isReachable = NO;
        _isWiFi = NO;
        _isCellular = NO;
        _monitorQueue = dispatch_queue_create("com.freshpaint.reachability", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stopNotifier];
}

- (BOOL)startNotifier {
    if (_monitor) return YES;

    _monitor = nw_path_monitor_create();
    if (!_monitor) return NO;

    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(_monitor, ^(nw_path_t path) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        BOOL reachable = nw_path_get_status(path) == nw_path_status_satisfied;
        BOOL wifi      = reachable && nw_path_uses_interface_type(path, nw_interface_type_wifi);
        BOOL cellular  = reachable && nw_path_uses_interface_type(path, nw_interface_type_cellular);

        strongSelf->_isReachable = reachable;
        strongSelf->_isWiFi      = wifi;
        strongSelf->_isCellular  = cellular;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) s = weakSelf;
            if (!s) return;
            if (reachable) {
                if (s->_reachableBlock) s->_reachableBlock(s);
            } else {
                if (s->_unreachableBlock) s->_unreachableBlock(s);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kFPReachabilityChangedNotification
                                                                object:s];
        });
    });

    nw_path_monitor_set_queue(_monitor, _monitorQueue);
    nw_path_monitor_start(_monitor);
    return YES;
}

- (void)stopNotifier {
    if (_monitor) {
        nw_path_monitor_cancel(_monitor);
        _monitor = nil;
    }
}

- (BOOL)isReachable {
    return _isReachable;
}

- (BOOL)isReachableViaWiFi {
    return _isWiFi;
}

- (BOOL)isReachableViaWWAN {
    return _isCellular && _reachableOnWWAN;
}

@end
