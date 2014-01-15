//
//  DSRDeezerSearch.h
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import <Foundation/Foundation.h>

// XMacro
#define DSR_DEEZER_SEARCH_TYPES_AS_ENUM(t,s) t,
#define DSR_DEEZER_SEARCH_TYPES_AS_STRING_ARRAY(t,s) s,
#define DSR_DEEZER_SEARCH_TYPES(ENTRY)                  \
ENTRY(DSRDeezerSearchTypeArtist, @"artist")             \
ENTRY(DSRDeezerSearchTypeAlbum, @"album")               \
ENTRY(DSRDeezerSearchTypeUser, @"user")                 \
ENTRY(DSRDeezerSearchTypeAutocomplete, @"autocomplete")

typedef enum {
    DSR_DEEZER_SEARCH_TYPES(DSR_DEEZER_SEARCH_TYPES_AS_ENUM)
} DSRDeezerSearchType;

@interface DSRDeezerSearch : NSObject
+ (NSString*)searchFor:(DSRDeezerSearchType)type withQuery:(NSString*)query;
@end
