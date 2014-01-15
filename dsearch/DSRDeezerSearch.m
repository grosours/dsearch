//
//  DSRDeezerSearch.m
//  dsearch
//
//  Created by guillaume faure on 15/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRDeezerSearch.h"

@implementation DSRDeezerSearch
+ (NSString*)searchFor:(DSRDeezerSearchType)type withQuery:(NSString*)query
{
    static NSString* subpath[] = {
        DSR_DEEZER_SEARCH_TYPES(DSR_DEEZER_SEARCH_TYPES_AS_STRING_ARRAY)
    };
    
    return [[[NSString stringWithFormat:@"http://api.deezer.com/search"]
            stringByAppendingPathComponent:subpath[type]]
            stringByAppendingFormat:@"?q=%@", [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}
@end
