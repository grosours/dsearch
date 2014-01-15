//
//  DSRAlbum.m
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRAlbum.h"
#import "DSRObject.h"

@implementation DSRAlbum
- (NSSet *)supportedKeys
{
    return [[super supportedKeys]
            setByAddingObjectsFromArray:@[@"title", @"upc", @"link", @"cover",
                                          @"genre_id", @"label", @"nb_tracks",
                                          @"duration", @"fans", @"rating", @"release_date",
                                          @"available", @"artist", @"tracks"]];
}

- (NSSet*)supportedMethods
{
    return [[super supportedMethods]
            setByAddingObjectsFromArray:@[@"tracks"]];
}

- (NSString *)infoURL
{
    return [NSString stringWithFormat:@"http://api.deezer.com/album/%@", [self valueForKeyPath:@"info.id"]];
}

#pragma mark Parsing

- (id)parseArtist:(NSDictionary*)JSON
{
    return [DSRObject objectFromJSON:JSON];
}

- (id)parseTracks:(NSDictionary*)JSON
{
    return [DSRObject objectsFromJSON:JSON];
}
@end
