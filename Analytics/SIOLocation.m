//
//  SIOLocation.m
//  Analytics
//
//  Created by Travis Jeffery on 4/25/14.
//  Copyright (c) 2014 Segment.io. All rights reserved.
//

#import "SIOLocation.h"

#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@interface SIOLocation () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLPlacemark *currentPlacemark;
@property (nonatomic, strong) CLGeocoder *geocoder;

@end

@implementation SIOLocation

- (id)init {
    if (self = [super init]) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        _geocoder = [[CLGeocoder alloc] init];
        // need to start updating location at some point
    }
    return self;
}

- (NSString *)state {
    return self.currentPlacemark.administrativeArea;
}

- (NSString *)country {
    return self.currentPlacemark.country;
}

- (NSString *)city {
    return self.currentPlacemark.locality;
}

- (NSString *)postalCode {
    return self.currentPlacemark.postalCode;
}

- (NSString *)street {
    return self.currentPlacemark.thoroughfare;
}

- (BOOL)hasKnownLocation {
    return self.currentPlacemark != nil;
}

- (NSNumber *)latitude {
    return @(self.currentPlacemark.location.coordinate.latitude);
}

- (NSNumber *)longitude {
    return @(self.currentPlacemark.location.coordinate.longitude);
}

- (NSNumber *)speed {
    return @(self.currentPlacemark.location.speed);
}


- (NSDictionary *)locationDictionary {
    return [self dictionaryWithValuesForKeys:@[ @"city", @"country", @"latitude", @"longitude", @"speed" ]];
}

- (NSDictionary *)addressDictionary {
    return [self dictionaryWithValuesForKeys:@[ @"city", @"country", @"postalCode", @"state", @"street" ]];
}

- (NSDictionary *)dictionary {
    if (!_dictionary) {
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(self.class, &count);
        _dictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id propertyValue = [self valueForKey:propertyName];
            if ([propertyValue isKindOfClass:[NSString class]] || [propertyValue isKindOfClass:[NSNumber class]]) {
                _dictionary[propertyName] = propertyValue;
            }
        }
    }
    return _dictionary;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (!locations.count) return;
    
    __weak typeof(self) weakSelf = self;
    [self.geocoder reverseGeocodeLocation:locations.firstObject completionHandler:^(NSArray *placemarks, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.dictionary = nil;
        strongSelf.currentPlacemark = placemarks.firstObject;
    }];
}

@end
