//
//  DSRObject.m
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRObject.h"

#import "DSRRequestManager.h"

#import "DSRArtist.h"
#import "DSRAlbum.h"
#import "DSRTrack.h"


#define DSR_OBJECT_CLASS_AS_NSDICTIONARY(c,s) s: [c class],
#define DSR_OBJECT_CLASS(ENTRY)     \
ENTRY(DSRArtist, @"artist")         \
ENTRY(DSRAlbum, @"album")           \
ENTRY(DSRTrack, @"track")

@interface DSRObject ()
@property (nonatomic, strong) NSMutableDictionary *info;
- (void)getInfoForKey:(NSString*)key withRequestManager:(DSRRequestManager*)manager callback:(void(^)(id))callback;
- (void)getMethodForKey:(NSString*)key withRequestManager:(DSRRequestManager*)manager callback:(void(^)(id))callback;
@end

@implementation DSRObject
+ (DSRObject*)objectFromJSON:(NSDictionary*)JSON
{
    NSAssert([JSON objectForKey:@"id"] != nil, @"An Object should alway have an ID");
    NSAssert([JSON objectForKey:@"type"] != nil, @"An object should always have a type");
    Class c = [@{DSR_OBJECT_CLASS(DSR_OBJECT_CLASS_AS_NSDICTIONARY)} objectForKey:[JSON objectForKey:@"type"]];
    NSAssert(c != NULL, @"Unknown key");
    return [[c alloc] initFromJSON:JSON];
}

- (id)initFromJSON:(NSDictionary *)JSON
{
    self = [super init];
    if (self) {
        self.info = [NSMutableDictionary dictionary];
        [self copySupportedKeysFromInfo:JSON];
    }
    return self;
}

- (void)copySupportedKeysFromInfo:(NSDictionary*)info
{
    [[self supportedKeys] enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
        id object = [info objectForKey:key];
        if (object) {
            [self.info setObject:object forKey:key];
        }
    }];
}

- (void)getValueForKey:(NSString*)key withRequestManager:(DSRRequestManager *)manager callback:(void (^)(id))callback
{
    if ([self.supportedKeys containsObject:key]) {
        [self getInfoForKey:key withRequestManager:manager callback:callback];
    }
    else if ([self.supportedMethods containsObject:key]) {
        [self getMethodForKey:key withRequestManager:manager callback:callback];
    }
    else {
        callback(nil);
    }
}

- (void)getInfoForKey:(NSString *)key withRequestManager:(DSRRequestManager *)manager callback:(void (^)(id))callback
{
    id object = [self.info objectForKey:key];
    if (object) {
        callback(object);
    }
    else {
        DSRJSONRequest * req = [[DSRJSONRequest alloc] initWithURLString:[self infoURL]];
        req.JSONCompletionBlock = ^(NSDictionary* info, NSError* error) {
            if (error == nil) {
                [self copySupportedKeysFromInfo:info];
                callback([info objectForKey:key]);
            }
            else {
                callback(nil);
            }
        };
        [manager addRequest:req];
    }
}

- (void)getMethodForKey:(NSString *)key withRequestManager:(DSRRequestManager *)manager callback:(void (^)(id))callback
{
    
}

- (NSSet *)supportedKeys
{
    return [NSSet setWithObjects:@"id", @"type", nil];
}

- (NSSet *)supportedMethods
{
    return [NSSet set];
}

- (NSString *)infoURL
{
    return nil;
}
@end
