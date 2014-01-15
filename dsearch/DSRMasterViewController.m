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

@interface DSRArtistCell : UITableViewCell
+ (NSString*)reuseIdentifier;
- (id)initWithManager:(DSRRequestManager*)manager;
@property (nonatomic, strong) DSRArtist *artist;
@property (nonatomic, strong) DSRRequestManager *manager;
@end

@interface DSRArtistSearchDelegate : NSObject<UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDelegate, UITableViewDataSource> {
    IBOutlet UISearchDisplayController *searchDisplayController;
    IBOutlet DSRMasterViewController *mainController;
    
    NSArray *_artists;
}
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
//        self.tintColor = [UIColor colorWithWhite:.2 alpha:1.0];
    }
    return self;
}

- (void)setArtist:(DSRArtist *)artist
{
    if (_artist != artist) {
        _artist = artist;
        [_artist getValueForKey:@"name" withRequestManager:self.manager callback:^(NSString *name) {
            self.textLabel.text = name;
        }];
    }
}
@end


@implementation DSRArtistSearchDelegate
#pragma mark - SearchDisplayDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self searchArtist:searchString];
    return NO;
}

- (void)searchArtist:(NSString*)artist
{
    NSString *URLString = [DSRDeezerSearch searchFor:DSRDeezerSearchTypeArtist withQuery:artist];
    DSRJSONRequest *req = [[DSRJSONRequest alloc] initWithURLString:URLString];
    req.JSONCompletionBlock = ^(NSDictionary* albums, NSError *error) {
        _artists = [DSRObject objectsFromJSON:albums];
        [searchDisplayController.searchResultsTableView reloadData];
    };
    req.priority = DSRRequestPriorityHigh;
    [mainController.manager addRequest:req];
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
    cell.artist = artist;
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
