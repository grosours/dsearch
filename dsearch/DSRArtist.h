//
//  DSRArtist.h
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSRObject.h"

@class DSRRequestManager;

@interface DSRArtist : DSRObject
- (void)pictureWithRequestManager:(DSRRequestManager*)manager callback:(void(^)(UIImage* picture))callback;
@end
