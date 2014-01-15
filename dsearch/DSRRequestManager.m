//
//  DSRRequestManager.m
//  dsearch
//
//  Created by guillaume faure on 14/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRRequestManager.h"

#pragma mark - DSRRequestOperation

@interface DSRRequestOperation : NSOperation <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (atomic, assign) BOOL running;
@property (atomic, assign) BOOL cancelled;
@property (atomic, assign) BOOL finished;

@property (nonatomic, strong) NSMutableSet* requests;
@property (nonatomic, strong) NSMutableData *data;

@property (nonatomic, strong) NSURLConnection *connection;
- (id)initWithURL:(NSURL*)URL andPriority:(NSOperationQueuePriority)priority;
- (void)failWithError:(NSError*)error;
- (void)succeedWithData:(NSData*)data;
- (void)attachRequest:(DSRRequest*)request withPriority:(NSOperationQueuePriority)priority;
- (void)detachRequest:(DSRRequest*)request;
@end

@interface DSRRequest ()
@property (nonatomic, strong) DSRRequestOperation *operation;
- (void)operationDidSucceed:(NSData*)data;
- (void)operationDidFail:(NSError*)error;
@end

@implementation DSRRequestOperation

- (id)initWithURL:(NSURL *)URL andPriority:(NSOperationQueuePriority)priority
{
    self = [super init];
    if (self) {
        self.cancelled = NO;
        self.running = NO;
        self.finished = NO;
        
        self.requests = [NSMutableSet set];
        
        [self setQueuePriority:priority];
        self.connection = [[NSURLConnection alloc]
                           initWithRequest:[NSURLRequest requestWithURL:URL]
                           delegate:self startImmediately:NO];
    }
    return self;
}

- (void)cancel
{
    [self willChangeValueForKey:@"isCancelled"];
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    // state management
    self.cancelled = YES;
    self.running = NO;
    self.finished = YES;
    
    // Cancel the NSURLConnection
    [self.connection cancel];
    self.connection = nil;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isCancelled"];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isCancelled
{
    return self.cancelled;
}

- (BOOL)isRunning
{
    return self.running;
}

- (BOOL)isReady
{
    return YES;
}

- (BOOL)isFinished
{
    return self.finished;
}

- (void)start
{
    if ([self isCancelled])
    {
        // Must move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark Managing associated requests

- (void)attachRequest:(DSRRequest *)request withPriority:(NSOperationQueuePriority)priority
{
    @synchronized(self.requests) {
        [self.requests addObject:request];
        request.operation = self;
        if (priority > [self queuePriority]) [self setQueuePriority:priority];
    }
}

- (void)detachRequest:(DSRRequest *)request
{
    @synchronized(self.requests) {
        [self.requests removeObject:request];
        if (self.requests.count == 0) {
            [self cancel];
        }
    }
}

#pragma mark Completion handlers

- (void)failWithError:(NSError *)error
{
    [self completeWithBlock:^(DSRRequest *request) {
        [request operationDidFail:error];
    }];
}

- (void)succeedWithData:(NSData *)data
{
    [self completeWithBlock:^(DSRRequest *request) {
        [request operationDidSucceed:data];
    }];
}

- (void)completeWithBlock:(void(^)(DSRRequest* request))block
{
    @synchronized(self.requests) {
        [self.requests enumerateObjectsUsingBlock:^(DSRRequest *request, BOOL *stop) {
            block(request);
            request.operation = nil;
        }];
        [self.requests removeAllObjects];
    }
    self.requests = nil;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.running = NO;
    self.finished = YES;
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    [self failWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse * r = (NSHTTPURLResponse*)response;
    if ((r.statusCode / 200) != 1) {
        [self connection:connection
        didFailWithError:[NSError
                          errorWithDomain:@"HTTP"
                          code:r.statusCode
                          userInfo:@{NSLocalizedDescriptionKey: [NSHTTPURLResponse
                                                                 localizedStringForStatusCode:r.statusCode]}]];
        [self cancel];
    }
    else {
        NSString *length = [[r.allHeaderFields objectsForKeys:@[@"Content-Length"] notFoundMarker:@"4096"] firstObject];
        self.data = length ? [NSMutableData dataWithCapacity:[length integerValue]] : [NSMutableData data];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.running = NO;
    self.finished = YES;
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
    [self succeedWithData:self.data];
}
@end

#pragma mark - DSRequest

@implementation DSRRequest
- (id)initWithURLString:(NSString *)urlString
{
    return [self initWitURL:[NSURL URLWithString:urlString]];
}

- (id)initWitURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        self.URL = URL;
    }
    return self;
}

- (void)cancel
{
    [self.operation cancel];
}

- (void)operationDidSucceed:(NSData *)data
{
    if (!self.dataCompletionBlock) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dataCompletionBlock(data, nil);
    });
}

- (void)operationDidFail:(NSError *)error
{
    if (!self.dataCompletionBlock) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dataCompletionBlock(nil, error);
    });
}

- (void)setPriority:(DSRRequestPriority)priority
{
    [self.operation setQueuePriority:(NSOperationQueuePriority)priority];
}

- (DSRRequestPriority)priority
{
    return (DSRRequestPriority)[self.operation queuePriority];
}
@end

@implementation DSRJSONRequest

- (void)operationDidSucceed:(NSData *)data
{
    [super operationDidSucceed:data];
    if (!self.JSONCompletionBlock) return;
    NSError *JSONError = nil;
    NSDictionary *JSON = nil;
    if (data) {
        JSON = [NSJSONSerialization
                JSONObjectWithData:data
                options:0 error:&JSONError];
    }
    else {
        JSONError = [NSError
                     errorWithDomain:@"JSON"
                     code:0
                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No data", nil)}];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.JSONCompletionBlock(JSON, JSONError);
    });
}

- (void)operationDidFail:(NSError *)error
{
    [super operationDidFail:error];
    if (!self.JSONCompletionBlock) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.JSONCompletionBlock(nil, error);
    });
}

@end

@implementation DSRImageRequest

- (void)operationDidSucceed:(NSData *)data
{
    [super operationDidSucceed:data];
    if (!self.imageCompletionBlock) return;
    UIImage* image = [UIImage imageWithData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCompletionBlock(image, nil);
    });
}

- (void)operationDidFail:(NSError *)error
{
    [super operationDidFail:error];
    if (!self.imageCompletionBlock) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCompletionBlock(nil, error);
    });
}

@end

#pragma mark - DSRRequestGroup

@interface DSRRequestGroup () {
    BOOL _canceled;
}
@property (nonatomic, strong) NSMutableArray *cancelables;
- (void)addCancelable:(NSObject<DSRCancelable>*)cancelable;
@end

@implementation DSRRequestGroup
- (id)init
{
    self = [super init];
    if (self) {
        _canceled = NO;
        self.cancelables = [NSMutableArray array];
    }
    return self;
}

- (void)cancel
{
    _canceled = YES;
    [self.cancelables enumerateObjectsUsingBlock:^(DSRRequest *request, NSUInteger idx, BOOL *stop) {
        [request cancel];
    }];
    self.cancelables = nil;
}

- (void)addCancelable:(NSObject<DSRCancelable> *)cancelable
{
    if (_canceled) {
        [cancelable cancel];
    }
    else {
        [self.cancelables addObject:cancelable];
    }
}
@end

#pragma mark - DSRRequestManager

@interface DSRRequestManager ()
@property (atomic, strong) NSMapTable *operations;
@property (atomic, strong) NSOperationQueue *queue;
- (id)initWithQueue:(NSOperationQueue*)queue;
@end

@interface DSRGroupingRequetsManager : DSRRequestManager
@property (nonatomic, strong) DSRRequestGroup* group;
@property (nonatomic, strong) DSRRequestManager *parent;
- (id)initWithParent:(DSRRequestManager*)parent;
@end

@implementation DSRGroupingRequetsManager

- (DSRRequestManager *)groupingManger
{
    DSRGroupingRequetsManager* manager = [[DSRGroupingRequetsManager alloc] initWithParent:self.parent];
    [manager.group addCancelable:self.group];
    return manager;
}

- (id)initWithParent:(DSRRequestManager *)parent
{
    self = [super initWithQueue:parent.queue];
    if (self) {
        self.parent = parent;
    }
    return self;
}

- (void)addRequest:(DSRRequest *)request
{
    [super addRequest:request];
    [self.group addCancelable:request];
}

- (void)cancel
{
    [self.group cancel];
}
@end

@implementation DSRRequestManager
+ (instancetype)sharedManager
{
    static DSRRequestManager* shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (DSRRequestManager*)groupingManger
{
    return [[DSRGroupingRequetsManager alloc] initWithParent:self];
}

- (id)init {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:3];
    return [self initWithQueue:queue];
}

- (id)initWithQueue:(NSOperationQueue *)queue
{
    self = [super init];
    if (self) {
        self.queue = queue;
        self.operations = [NSMapTable weakToWeakObjectsMapTable];
    }
    return self;
}

- (void)dealloc
{
    [self cancel];
    self.queue = nil;
}


- (void)addRequest:(DSRRequest *)request
{
    DSRRequestOperation *operation = [self.operations objectForKey:request.URL.absoluteString];
    if (!operation) {
        operation = [[DSRRequestOperation alloc]
                     initWithURL:request.URL
                     andPriority:(NSOperationQueuePriority)request.priority];
        [self.operations setObject:operation forKey:request.URL.absoluteString];
        [self.queue addOperation:operation];
    }
    [operation attachRequest:request
                withPriority:(NSOperationQueuePriority)request.priority];
}

- (DSRRequestGroup *)groupRequests:(void (^)(DSRRequestManager *))groupTransaction
{
    DSRGroupingRequetsManager* manager = [[DSRGroupingRequetsManager alloc] initWithParent:self];
    groupTransaction(manager);
    return manager.group;
}

- (void)cancel
{
    [self.queue cancelAllOperations];
}
@end
