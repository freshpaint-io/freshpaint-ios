//
//  NSData+FPGUNZIPP.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Freshpaint. All rights reserved.
//
// https://github.com/nicklockwood/GZIP/blob/master/GZIP/NSData%2BGZIP.m

#import <Foundation/Foundation.h>


@interface NSData (FPGUNZIPP)

- (NSData *_Nullable)seg_gunzippedData;

@end
