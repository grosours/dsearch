//
//  DSRArtist.m
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRArtist.h"
#import "DSRAlbum.h"
#import "DSRRequestManager.h"

@implementation DSRArtist

- (NSSet *)supportedKeys
{
    return [[super supportedKeys]
            setByAddingObjectsFromArray:@[@"name", @"link", @"picture"]];
}

- (NSSet *)supportedMethods
{
    return [[super supportedMethods] setByAddingObjectsFromArray:@[@"albums"]];
}

- (NSString *)infoURL
{
    return [NSString stringWithFormat:@"http://api.deezer.com/artist/%@", [self valueForKeyPath:@"info.id"]];
}

- (void)pictureWithRequestManager:(DSRRequestManager *)manager callback:(void (^)(UIImage *))callback
{
    [self getValueForKey:@"picture" withRequestManager:manager callback:^(NSString *pictureURL) {
        if (pictureURL) {
            DSRImageRequest * req = [[DSRImageRequest alloc] initWithURLString:pictureURL];
            req.imageCompletionBlock = ^(UIImage* picture, NSError *error) {
                if (error) {
                    callback(nil);
                }
                else {
                    callback(picture);
                }
            };
            [manager addRequest:req];
        }
        else {
            callback(nil);
        }
    }];
}

- (NSArray*)parseAlbums:(NSDictionary*)JSON
{
    NSArray *albumsJSONs = [JSON objectForKey:@"data"];
    NSAssert(albumsJSONs != nil && [albumsJSONs isKindOfClass:[NSArray class]], @"");
    
    NSMutableArray *albums = [NSMutableArray array];
    [albumsJSONs enumerateObjectsUsingBlock:^(NSDictionary *JSON, NSUInteger idx, BOOL *stop) {
        DSRAlbum * album = (DSRAlbum*)[DSRObject objectFromJSON:JSON];
        [albums addObject:album];
    }];
    
    return [NSArray arrayWithArray:albums];
}
@end
