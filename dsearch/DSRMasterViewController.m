//
//  DSRMasterViewController.m
//  dsearch
//
//  Created by guillaume faure on 14/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRMasterViewController.h"

#import "DSRDetailViewController.h"
#import "DSRDeezerSearch.h"
#import "DSRRequestManager.h"
#import "DSRObject.h"
#import "DSRArtist.h"
#import "DSRAlbum.h"
#import "DSRTrack.h"

@interface DSRArtistSearchDelegate : NSObject<UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDelegate, UITableViewDataSource> {
    IBOutlet UISearchDisplayController *searchDisplayController;
    IBOutlet DSRMasterViewController *mainController;
    
    NSArray *_artists;
}
@property (nonatomic, weak) DSRJSONRequest *searchRequest;
@property (nonatomic, strong) NSMapTable *imageCache;
@property (nonatomic, strong) DSRRequestManager *imageCachingManager;
@end


@interface DSRArtistCell : UITableViewCell
+ (NSString*)reuseIdentifier;
- (id)initWithManager:(DSRRequestManager*)manager;
@property (nonatomic, strong) DSRArtist *artist;
@property (nonatomic, strong) DSRRequestManager *manager;
@property (nonatomic, strong) DSRArtistSearchDelegate *searchDelegate;
@end

@interface DSRMasterViewController () <UITableViewDelegate, UITableViewDataSource>{
    IBOutlet DSRArtistSearchDelegate *searchDelegate;
    IBOutlet UITableView *albumTableView;
    NSArray *_albums;
}
@property (nonatomic, strong) DSRRequestManager *manager;
- (void)setAlbums:(NSArray*)albums;
@end


@implementation DSRArtistCell
+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (id)initWithManager:(DSRRequestManager *)manager
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[self class] reuseIdentifier]];
    if (self) {
        self.manager = manager;
        self.backgroundColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    return self;
}

@end


@implementation DSRArtistSearchDelegate
- (id)init
{
    self = [super init];
    if (self) {
        self.imageCache = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

#pragma mark - SearchDisplayDelegate
- (void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)searchDisplayController:(UISearchDisplayController *)controller willShowSearchResultsTableView:(UITableView *)tableView {
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(keyboardWillHide)
     name:UIKeyboardWillHideNotification object:nil];
}

- (void) keyboardWillHide {
    UITableView *tableView = searchDisplayController.searchResultsTableView;
    [tableView setContentInset:UIEdgeInsetsZero];
    [tableView setScrollIndicatorInsets:UIEdgeInsetsZero];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    if (searchString.length > 2) {
        [self searchArtist:searchString];
    }
    else {
        _artists = @[];
        [searchDisplayController.searchResultsTableView reloadData];
    }
    return NO;
}

- (void)setSearchRequest:(DSRJSONRequest *)searchRequest
{
    if (_searchRequest != searchRequest) {
        [_searchRequest cancel];
        _searchRequest = searchRequest;
    }
}

- (void)searchArtist:(NSString*)artist
{
    // On devrait très certainement debounce la recherche pour ne pas flooder le serveur.
    NSString *URLString = [DSRDeezerSearch searchFor:DSRDeezerSearchTypeArtist withQuery:artist];
    DSRJSONRequest * req = [[DSRJSONRequest alloc] initWithURLString:URLString];
    req.JSONCompletionBlock = ^(NSDictionary* artists, NSError *error) {
        self.searchRequest = nil;
        _artists = [DSRObject objectsFromJSON:artists];
        [searchDisplayController.searchResultsTableView reloadData];
        [self cacheImages];
    };
    req.priority = DSRRequestPriorityHigh;
    [mainController.manager addRequest:req];
}

- (void)setImageCachingManager:(DSRRequestManager *)imageCachingManager
{
    if (_imageCachingManager != imageCachingManager) {
        [_imageCachingManager cancel];
        _imageCachingManager = imageCachingManager;
    }
}

- (void)cacheImages
{
    DSRRequestManager *manager = [mainController.manager groupingManger];
    self.imageCachingManager = manager;
    for (DSRArtist *artist in _artists) {
        if ([self.imageCache objectForKey:artist] == nil) {
            [artist
             getValueForKey:@"picture"
             withRequestManager:manager
             callback:^(NSString *artistImage) {
                 if (artistImage) {
                     DSRImageRequest * req = [[DSRImageRequest alloc] initWithURLString:artistImage];
                     req.priority = DSRRequestPriorityLow;
                     req.imageCompletionBlock = ^(UIImage* image, NSError* error) {
                         if (error == nil && image != nil) {
                             [self.imageCache setObject:image forKey:artist];
                         }
                     };
                     [manager addRequest:req];
                 }
             }];
        }
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self searchArtist:searchBar.text];
}

#pragma mark ScrollView

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.imageCachingManager = nil;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    for (DSRArtistCell *cell in searchDisplayController.searchResultsTableView.visibleCells) {
        cell.imageView.image =  cell.imageView.image = [self.imageCache objectForKey:cell.artist];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _artists.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DSRArtistCell *cell = [tableView dequeueReusableCellWithIdentifier:[DSRArtistCell reuseIdentifier]];
    if (!cell) {
        cell = [[DSRArtistCell alloc] initWithManager:mainController.manager];
    }
    
    DSRArtist *artist = _artists[indexPath.row];
    cell.searchDelegate = self;
    cell.artist = artist;
    cell.textLabel.text = [artist valueForKeyPath:@"info.name"];
//    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    if (tableView.isDragging || tableView.isDecelerating) {
        cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    }
    else {
        cell.imageView.image = [self.imageCache objectForKey:artist];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DSRArtist *artist = _artists[indexPath.row];
    [artist getValueForKey:@"albums" withRequestManager:mainController.manager callback:^(NSArray* albums) {
        [mainController setAlbums:albums];
    }];
    [searchDisplayController setActive:NO animated:YES];
}
@end

@implementation DSRMasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.manager = [[DSRRequestManager sharedManager] groupingManger];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma Utilities

- (void)setAlbums:(NSArray *)albums
{
    _albums = albums;
    [albumTableView reloadData];
    [_albums enumerateObjectsUsingBlock:^(DSRAlbum *album, NSUInteger idx, BOOL *stop) {
        [album getValueForKey:@"tracks" withRequestManager:self.manager callback:^(NSArray *tracks) {
            [albumTableView reloadSections:[NSIndexSet indexSetWithIndex:idx]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
    }];
}

#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _albums.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_albums[section] valueForKeyPath:@"info.tracks.@count"] integerValue];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_albums[section] valueForKeyPath:@"info.title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = [[[_albums[indexPath.section] valueForKeyPath:@"info.tracks"] objectAtIndex:indexPath.row]
                           valueForKeyPath:@"info.title"];
    return cell;
}

//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
//{
//    if ([[segue identifier] isEqualToString:@"showDetail"]) {
//        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
//        NSDate *object = _objects[indexPath.row];
//        [[segue destinationViewController] setDetailItem:object];
//    }
//}
@end
