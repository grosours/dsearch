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
+ (NSCache*)objectsCache
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 10000;
    });
    return cache;
}

+ (DSRObject*)objectFromJSON:(NSDictionary*)JSON
{
    NSAssert([JSON objectForKey:@"id"] != nil, @"An Object should alway have an ID");
    NSAssert([JSON objectForKey:@"type"] != nil, @"An object should always have a type");
    Class c = [@{DSR_OBJECT_CLASS(DSR_OBJECT_CLASS_AS_NSDICTIONARY)} objectForKey:[JSON objectForKey:@"type"]];
    NSAssert(c != NULL, @"Unknown key");
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@-%@", [JSON objectForKey:@"type"], [JSON objectForKey:@"id"]];
    DSRObject *object = [[self objectsCache] objectForKey:cacheKey];
    if (!object) {
        object = [[c alloc] initFromJSON:JSON];
        [[self objectsCache] setObject:object forKey:cacheKey];
    }
    return object;
}

+ (NSArray *)objectsFromJSON:(NSDictionary *)JSON
{
    if (JSON == nil) {
        return nil;
    }
    
    NSArray *data = [JSON objectForKey:@"data"];
    NSAssert(data != nil && [data isKindOfClass:[NSArray class]], @"");
    
    NSMutableArray *objects = [NSMutableArray array];
    [data enumerateObjectsUsingBlock:^(NSDictionary *JSON, NSUInteger idx, BOOL *stop) {
        DSRObject * object = (DSRAlbum*)[DSRObject objectFromJSON:JSON];
        [objects addObject:object];
    }];
    
    return [NSArray arrayWithArray:objects];
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
            NSString *selectorString = [NSString stringWithFormat:@"parse%@:", [key capitalizedString]];
            SEL selector = NSSelectorFromString(selectorString);
            if ([self respondsToSelector:selector]) {
                object = ((id(*)(id, SEL, id))[self methodForSelector:selector])(self, selector, object);
            }
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
                callback([self.info objectForKey:key]);
            }
            else {
                callback(nil);
            }
        };
        [manager addRequest:req];
    }
}

- (NSString*)URLForMethod:(NSString*)methodName
{
    return [[self infoURL] stringByAppendingPathComponent:methodName];
}

- (void)getMethodForKey:(NSString *)key withRequestManager:(DSRRequestManager *)manager callback:(void (^)(id))callback
{
    id object = [self.info objectForKey:key];
    if (object) {
        callback(object);
    }
    else {
        DSRJSONRequest * req = [[DSRJSONRequest alloc] initWithURLString:[self URLForMethod:key]];
        req.JSONCompletionBlock = ^(NSDictionary* JSON, NSError* error) {
            if (error == nil) {
                NSString *selectorString = [NSString stringWithFormat:@"parse%@:", [key capitalizedString]];
                SEL selector = NSSelectorFromString(selectorString);
                id object;
                if ([self respondsToSelector:selector]) {
                    object = ((id(*)(id, SEL, id))[self methodForSelector:selector])(self, selector, JSON);
                }
                else {
                    object = JSON;
                }
                [self.info setObject:object forKey:key];
                callback(object);
            }
            else {
                callback(nil);
            }
        };
        [manager addRequest:req];
    }

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

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass([self class]), [self.info objectForKey:@"id"]];
}
@end
