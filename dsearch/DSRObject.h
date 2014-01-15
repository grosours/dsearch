//
//  DSRObject.h
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DSRRequestManager;

@interface DSRObject : NSObject
@property (nonatomic, strong) NSString* identifier;

+ (DSRObject*)objectFromJSON:(NSDictionary*)JSON;
+ (NSArray*)objectsFromJSON:(NSDictionary*)JSON;

- (id)initFromJSON:(NSDictionary*)JSON;
- (void)getValueForKey:(NSString*)key withRequestManager:(DSRRequestManager*)manager callback:(void(^)(id value))callback;
- (NSString*)infoURL;
- (NSSet*)supportedKeys;
- (NSSet*)supportedMethods;
@end
