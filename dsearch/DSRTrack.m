//
//  DSRTrack.m
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRTrack.h"

@implementation DSRTrack
- (NSSet *)supportedKeys
{
    return [[super supportedKeys]
            setByAddingObjectsFromArray:@[@"readable", @"title", @"isrc", @"link",
                                          @"duration", @"track_position", @"disk_number",
                                          @"rank", @"explicit_lyrics", @"preview",
                                          @"bpm", @"gain", @"available_countries",
                                          @"artist", @"album"]];
}

- (NSString *)infoURL
{
    return [NSString stringWithFormat:@"http://api.deezer.com/track/%@", [self valueForKeyPath:@"info.id"]];
}

#pragma mark Parsing

- (id)parseArtist:(NSDictionary*)JSON
{
    return [DSRObject objectFromJSON:JSON];
}
@end
