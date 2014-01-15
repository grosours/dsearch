//
//  DSRRequestManager.h
//  dsearch
//
//  Created by guillaume faure on 14/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DSRRequestPriorityLow = -4,
    DSRRequestPriorityNormal = 0,
    DSRRequestPriorityHigh = 4
} DSRRequestPriority;

@interface DSRRequest : NSObject
@property (nonatomic, copy) void(^dataCompletionBlock)(NSData* response, NSError* error);
@property (nonatomic, assign) DSRRequestPriority priority;
@property (readonly) NSURL *URL;

- (id)initWithURLString:(NSString*)urlString;
- (id)initWitURL:(NSURL*)URL;

- (void)cancel;
@end

@interface DSRJSONRequest : DSRRequest
@property (nonatomic, copy) void(^JSONCompletionBlock)(NSDictionary* JSON, NSError* error);
@end

@interface DSRImageRequest : DSRRequest
@property (nonatomic, copy) void(^imageCompletionBlock)(UIImage* image, NSError* error);
@end

@interface DSRRequestGroup : NSObject
- (void)cancel;
@end

@interface DSRRequestManager : NSObject
+ (instancetype)sharedManager;
+ (instancetype)groupingManger;
- (DSRRequestGroup*)groupRequests:(void(^)(DSRRequestManager* requestManager))groupTransaction;
- (void)addRequest:(DSRRequest*)request;
- (void)cancel;
@end
