//
//  DSRMasterViewController.m
//  dsearch
//
//  Created by guillaume faure on 14/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import "DSRMasterViewController.h"
#import <AVFoundation/AVFoundation.h>

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
    
    DSRRequestManager *manager;
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
    DSRArtist *_artist;
    NSArray *_albums;
}
@property (nonatomic, strong) DSRRequestManager *manager;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSIndexPath *selectedPath;
@property (nonatomic, strong) UIProgressView *playbackProgress;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic, strong) UIActivityIndicatorView *throbber;
@property (nonatomic, strong) UIButton *stopButton;
- (void)setArtist:(DSRArtist*)artist;
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
    [manager cancel];
    manager = nil;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller willShowSearchResultsTableView:(UITableView *)tableView {
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(keyboardWillHide)
     name:UIKeyboardWillHideNotification object:nil];
    manager = [mainController.manager groupingManger];
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
        _artists = [DSRObject objectsFromJSON:artists];
        [searchDisplayController.searchResultsTableView reloadData];
        [self cacheImages];
    };
    req.priority = DSRRequestPriorityHigh;
    [manager addRequest:req];
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
    DSRRequestManager *imageCachingManager = [manager groupingManger];
    self.imageCachingManager = imageCachingManager;
    for (DSRArtist *artist in _artists) {
        if ([self.imageCache objectForKey:artist] == nil) {
            [artist
             getValueForKey:@"picture"
             withRequestManager:imageCachingManager
             callback:^(NSString *artistImage) {
                 if (artistImage) {
                     DSRImageRequest * req = [[DSRImageRequest alloc] initWithURLString:artistImage];
                     req.priority = DSRRequestPriorityLow;
                     req.imageCompletionBlock = ^(UIImage* image, NSError* error) {
                         if (error == nil && image != nil) {
                             [self.imageCache setObject:image forKey:artist];
                         }
                     };
                     [imageCachingManager addRequest:req];
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
        UIImage *i = [self.imageCache objectForKey:cell.artist];
        cell.imageView.image  =  i ? i : [UIImage imageNamed:@"placeholder"];
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
        cell = [[DSRArtistCell alloc] initWithManager:manager];
    }
    
    DSRArtist *artist = _artists[indexPath.row];
    cell.searchDelegate = self;
    cell.artist = artist;
    cell.textLabel.text = [artist valueForKeyPath:@"info.name"];
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    if (tableView.isDragging || tableView.isDecelerating) {
        cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    }
    else {
        UIImage *i = [self.imageCache objectForKey:artist];
        cell.imageView.image =  i ? i : [UIImage imageNamed:@"placeholder"];
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
    [mainController setArtist:artist];
    [searchDisplayController setActive:NO animated:YES];
}
@end

@implementation DSRMasterViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    self.throbber = [[UIActivityIndicatorView alloc]
                     initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.throbber startAnimating];
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"\u25A0" forState:UIControlStateNormal];
    self.stopButton.titleLabel.font = [UIFont systemFontOfSize: 22];
    [self.stopButton setTintColor:[UIColor blackColor]];
    [self.stopButton sizeToFit];
    [self.stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    self.playbackProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.playbackProgress.tintColor = [UIColor colorWithWhite:.5 alpha:1];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(stop)
     name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
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

- (void)setArtist:(DSRArtist *)artist
{
    _artist = artist;
    [artist getValueForKey:@"albums" withRequestManager:self.manager callback:^(NSArray* albums) {
        _albums = albums;
        [albumTableView reloadData];
        [_albums enumerateObjectsUsingBlock:^(DSRAlbum *album, NSUInteger idx, BOOL *stop) {
            [album getValueForKey:@"tracks" withRequestManager:self.manager callback:^(NSArray *tracks) {
                [albumTableView reloadSections:[NSIndexSet indexSetWithIndex:idx]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
            }];
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
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    DSRTrack * t = [self trackForIndexPath:indexPath];
    cell.textLabel.text = [t valueForKeyPath:@"info.title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [t valueForKeyPath:@"info.artist.info.name"]];
    cell.backgroundView = nil;
    cell.accessoryView = nil;

    if ([indexPath isEqual:self.selectedPath]) {
        cell.backgroundView = self.playbackProgress;
        cell.accessoryView = self.accessoryView;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedPath = indexPath;
    self.accessoryView = self.throbber;
    [self configureSelectedCell];
    DSRTrack * t = [self trackForIndexPath:indexPath];
    [t getValueForKey:@"preview" withRequestManager:self.manager callback:^(NSString* previewURLString) {
        [self play:previewURLString];
    }];
}

- (void)setSelectedPath:(NSIndexPath *)selectedPath
{
    if (_selectedPath != selectedPath) {
        UITableViewCell * cell = [albumTableView cellForRowAtIndexPath:_selectedPath];
        cell.backgroundView = nil;
        cell.accessoryView = nil;
        _selectedPath = selectedPath;
    }
}

- (void)configureSelectedCell
{
    UITableViewCell* cell = [albumTableView cellForRowAtIndexPath:self.selectedPath];
    cell.backgroundView = self.playbackProgress;
    cell.accessoryView = self.accessoryView;
}

- (DSRTrack*)trackForIndexPath:(NSIndexPath*)indexPath
{
    return [[_albums[indexPath.section] valueForKeyPath:@"info.tracks"] objectAtIndex:indexPath.row];
}

- (void)play:(NSString*)URLString
{
    if (URLString == nil) return;
    
    self.player = [AVPlayer playerWithURL:[NSURL URLWithString:URLString]];
    [self.player play];
}

- (void)stop
{
    [self.player pause];
    self.player = nil;
    UITableViewCell* cell = [albumTableView cellForRowAtIndexPath:self.selectedPath];
    cell.backgroundView = nil;
    cell.accessoryView = nil;
    self.accessoryView = nil;
    [self.playbackProgress setProgress:0.0];
    self.selectedPath = nil;
}

- (void)setPlayer:(AVPlayer *)player
{
    if (_player != player) {
        [_player removeTimeObserver:self.timeObserver];
        _player = player;
        if (player) {
            _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
            self.accessoryView = self.stopButton;
            UIProgressView * p = self.playbackProgress;
            [p setProgress:0.0];
            self.timeObserver = [_player
                                 addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(.01, 1000)
                                 queue:nil
                                 usingBlock:^(CMTime time) {
                                     [p setProgress:(CMTimeGetSeconds(time) / 30.0) animated:YES];
                                 }];
        }
        [self configureSelectedCell];
    }
}

@end
